import ColorMatchingLPSAppCore
import MeasurementCore
#if canImport(Security)
import Security
#endif
import SwiftUI

struct ContentView: View {
    @StateObject private var camera = CameraController()
    @AppStorage("settings.manifestURL") private var manifestURL = "http://localhost:4000/api/v1/test_sheets/example/manifest"
    @AppStorage("settings.baseURL") private var baseURL = "http://localhost:4000"
    @AppStorage("settings.sheetCode") private var sheetCode = ""
    @State private var apiToken = ""
    @State private var manifest: SheetManifest?
    @State private var recentSheets: [RecentSheet] = []
    @State private var analysis: SheetAnalysis?
    @State private var status = "Enter or scan a manifest URL."
    @State private var captureID: String?
    @State private var selectedJudgments: [String: String] = [:]

    var body: some View {
        NavigationStack {
            Form {
                Section("Manifest") {
                    manifestURLField
                    baseURLField
                    sheetCodeField
                    SecureField("API token", text: $apiToken)
                    Button("Fetch Manifest", systemImage: "qrcode.viewfinder") {
                        Task { await fetchManifest() }
                    }
                    Button("Fetch Sheet Code", systemImage: "number") {
                        Task { await fetchManifestByCode() }
                    }
                    Button("Load Recent Sheets", systemImage: "clock.arrow.circlepath") {
                        Task { await loadRecentSheets() }
                    }

                    if !recentSheets.isEmpty {
                        Picker("Recent Sheet", selection: recentSheetBinding) {
                            Text("Select").tag("")
                            ForEach(recentSheets) { sheet in
                                Text(sheet.title ?? sheet.sheetID).tag(sheet.manifestURL.absoluteString)
                            }
                        }
                    }
                }

                if let manifest {
                    Section("Capture") {
                        Text("Sheet \(manifest.sheetID)")
                        Button("Configure Camera", systemImage: "camera.aperture") {
                            Task { await configureCamera() }
                        }
                        Button("Lock and Capture", systemImage: "camera") {
                            Task { await captureAndAnalyze() }
                        }
                        .disabled(!camera.isRunning || camera.isCapturing)
                    }

                    if let analysis {
                        Section("Capture Quality") {
                            LabeledContent("Markers", value: "\(analysis.quality.detectedMarkerCount)/\(manifest.registrationMarkers.count)")
                            LabeledContent("Blur", value: analysis.quality.blurScore.formatted(.number.precision(.fractionLength(3))))
                            if analysis.quality.rejections.isEmpty {
                                Text("Accepted")
                            } else {
                                ForEach(analysis.quality.rejections, id: \.self) { rejection in
                                    Text(rejection.rawValue)
                                }
                            }
                            SampleOverlayView(regions: analysis.sampleRegions)
                                .frame(height: 180)
                        }
                    }

                    Section("Ranked Pairs") {
                        ForEach(analysis?.scores ?? []) { score in
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(score.pairID)
                                    Spacer()
                                    Text(score.distance, format: .number.precision(.fractionLength(4)))
                                        .monospacedDigit()
                                }
                                Picker("Judgment", selection: judgmentBinding(for: score.pairID)) {
                                    Text("Unlabeled").tag("")
                                    Text("Match").tag("match")
                                    Text("Near").tag("near_match")
                                    Text("No").tag("no_match")
                                }
                                .pickerStyle(.segmented)
                            }
                        }
                    }

                    Section("Upload") {
                        Button("Upload Capture", systemImage: "arrow.up.doc") {
                            Task { await uploadCapture() }
                        }
                        .disabled(analysis == nil)

                        Button("Upload Labels", systemImage: "checkmark.circle") {
                            Task { await uploadLabels() }
                        }
                        .disabled(captureID == nil || selectedJudgments.values.allSatisfy(\.isEmpty))

                        if let captureID {
                            Text("Capture \(captureID)")
                        }
                    }
                }

                Section("Status") {
                    Text(status)
                }
            }
            .navigationTitle("LPS Matcher")
        }
        .onAppear {
            apiToken = APISettingsStore.loadAPIToken()
        }
        .onChange(of: apiToken) { _, newValue in
            APISettingsStore.saveAPIToken(newValue)
        }
    }

    private var manifestURLField: some View {
        #if os(iOS)
        TextField("Manifest URL", text: $manifestURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        #else
        TextField("Manifest URL", text: $manifestURL)
        #endif
    }

    private var baseURLField: some View {
        #if os(iOS)
        TextField("Server base URL", text: $baseURL)
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        #else
        TextField("Server base URL", text: $baseURL)
        #endif
    }

    private var sheetCodeField: some View {
        #if os(iOS)
        TextField("Short sheet code", text: $sheetCode)
            .textInputAutocapitalization(.never)
        #else
        TextField("Short sheet code", text: $sheetCode)
        #endif
    }

    private var recentSheetBinding: Binding<String> {
        Binding(
            get: { "" },
            set: { value in
                guard !value.isEmpty, value != manifestURL else { return }
                manifestURL = value
                Task { await fetchManifest() }
            }
        )
    }

    private func fetchManifest() async {
        do {
            guard let url = URL(string: manifestURL) else { throw URLError(.badURL) }
            manifest = try await APIClient(token: apiToken).fetchManifest(from: url)
            baseURL = url.originString
            resetCaptureState()
            status = "Fetched manifest."
        } catch {
            status = "Manifest fetch failed: \(error)"
        }
    }

    private func fetchManifestByCode() async {
        do {
            guard let url = URL(string: baseURL), !sheetCode.isEmpty else { throw URLError(.badURL) }
            manifest = try await APIClient(token: apiToken).fetchManifest(baseURL: url, sheetCode: sheetCode)
            manifestURL = manifest?.manifestURL.absoluteString ?? manifestURL
            resetCaptureState()
            status = "Fetched manifest for \(sheetCode)."
        } catch {
            status = "Sheet code fetch failed: \(error)"
        }
    }

    private func loadRecentSheets() async {
        do {
            guard let url = URL(string: baseURL) else { throw URLError(.badURL) }
            recentSheets = try await APIClient(token: apiToken).fetchRecentSheets(baseURL: url)
            status = "Loaded \(recentSheets.count) recent sheets."
        } catch {
            status = "Recent sheet lookup failed: \(error)"
        }
    }

    private func configureCamera() async {
        do {
            try await camera.configure()
            await camera.start()
            status = "Camera configured with rear wide-angle camera."
        } catch {
            status = "Camera setup failed: \(error)"
        }
    }

    private func captureAndAnalyze() async {
        guard let manifest else { return }

        do {
            try camera.lockCameraSettings()
            let photo = try await camera.capturePhoto()
            let result = SheetAnalyzer.analyze(image: photo.linearImage, manifest: manifest)
            analysis = result
            captureID = nil

            if result.quality.rejections.isEmpty {
                status = "Captured and ranked \(result.scores.count) pairs."
            } else {
                status = "Capture rejected: \(result.quality.rejections.map(\.rawValue).joined(separator: ", ")). Recapture after alignment/lighting fixes."
            }
        } catch {
            status = "Capture failed: \(error)"
        }
    }

    private func uploadCapture() async {
        guard let manifest, let analysis, let base = resolvedManifestBaseURL, let metadata = camera.lastMetadata else { return }

        do {
            let client = APIClient(token: apiToken)
            let activeCaptureID: String
            if let captureID {
                activeCaptureID = captureID
            } else {
                let capture = try await client.createCapture(sheetID: manifest.sheetID, baseURL: base, metadata: metadata, quality: analysis.quality)
                captureID = capture.captureID
                activeCaptureID = capture.captureID
            }
            try await client.uploadMeasurements(captureID: activeCaptureID, baseURL: base, measurements: analysis.normalizedMeasurements, scores: analysis.scores)
            status = "Uploaded capture, measurements, and scores."
        } catch {
            status = "Upload failed: \(error)"
        }
    }

    private func uploadLabels() async {
        guard let captureID, let base = resolvedManifestBaseURL else { return }
        let judgments = selectedJudgments
            .filter { !$0.value.isEmpty }
            .map { PairJudgment(pairID: $0.key, judgment: $0.value) }

        do {
            try await APIClient(token: apiToken).uploadJudgments(captureID: captureID, baseURL: base, judgments: judgments)
            status = "Uploaded \(judgments.count) labels."
        } catch {
            status = "Label upload failed: \(error)"
        }
    }

    private func judgmentBinding(for pairID: String) -> Binding<String> {
        Binding(
            get: { selectedJudgments[pairID] ?? "" },
            set: { selectedJudgments[pairID] = $0 }
        )
    }

    private func resetCaptureState() {
        analysis = nil
        captureID = nil
        selectedJudgments = [:]
    }

    private var resolvedManifestBaseURL: URL? {
        guard let manifest else { return URL(string: baseURL) }
        return URL(string: manifest.manifestURL.originString)
    }
}

private struct SampleOverlayView: View {
    var regions: [SampleOverlayRegion]

    var body: some View {
        Canvas { context, size in
            guard let bounds = Rect.bounding(regions.flatMap(\.corners)), bounds.width > 0, bounds.height > 0 else {
                return
            }

            let scale = min(size.width / bounds.width, size.height / bounds.height) * 0.92
            let offsetX = (size.width - bounds.width * scale) / 2
            let offsetY = (size.height - bounds.height * scale) / 2

            for region in regions {
                var path = Path()
                for (index, point) in region.corners.enumerated() {
                    let canvasPoint = CGPoint(
                        x: offsetX + (point.x - bounds.x) * scale,
                        y: offsetY + (point.y - bounds.y) * scale
                    )
                    if index == 0 {
                        path.move(to: canvasPoint)
                    } else {
                        path.addLine(to: canvasPoint)
                    }
                }
                path.closeSubpath()
                context.stroke(path, with: .color(.yellow), lineWidth: 1.5)
            }
        }
        .background(.black.opacity(0.85))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension URL {
    var originString: String {
        guard let scheme, let host else { return absoluteString }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        components.port = port
        return components.url?.absoluteString ?? absoluteString
    }
}

private enum APISettingsStore {
    private static let tokenDefaultsKey = "settings.apiToken"

    static func loadAPIToken() -> String {
        #if canImport(Security)
        var query = tokenKeychainQuery
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return UserDefaults.standard.string(forKey: tokenDefaultsKey) ?? ""
        }

        return token
        #else
        return UserDefaults.standard.string(forKey: tokenDefaultsKey) ?? ""
        #endif
    }

    static func saveAPIToken(_ token: String) {
        #if canImport(Security)
        let data = Data(token.utf8)
        let query = tokenKeychainQuery

        if token.isEmpty {
            SecItemDelete(query as CFDictionary)
            UserDefaults.standard.removeObject(forKey: tokenDefaultsKey)
            return
        }

        let attributes = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            SecItemAdd(item as CFDictionary, nil)
        } else if status != errSecSuccess {
            UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        }
        #else
        if token.isEmpty {
            UserDefaults.standard.removeObject(forKey: tokenDefaultsKey)
        } else {
            UserDefaults.standard.set(token, forKey: tokenDefaultsKey)
        }
        #endif
    }

    #if canImport(Security)
    private static var tokenKeychainQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.viamin.ColorMatchingLPS",
            kSecAttrAccount as String: "apiToken"
        ]
    }
    #endif
}
