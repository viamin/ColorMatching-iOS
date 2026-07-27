import AVFoundation
import ColorMatchingLPSAppCore
import Foundation
import MeasurementCore
#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class CameraController: NSObject, ObservableObject {
    @Published var authorizationDenied = false
    @Published var lastMetadata: CaptureMetadata?
    @Published var isRunning = false
    @Published var isCapturing = false

    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private var device: AVCaptureDevice?
    private var continuation: CheckedContinuation<CapturedPhoto, Error>?

    func configure() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else {
            authorizationDenied = true
            throw CameraError.notAuthorized
        }

        session.beginConfiguration()
        session.sessionPreset = .photo
        defer { session.commitConfiguration() }

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraError.noWideCamera
        }

        let input = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(input), session.canAddOutput(photoOutput) else {
            throw CameraError.configurationFailed
        }

        session.addInput(input)
        session.addOutput(photoOutput)
        photoOutput.maxPhotoQualityPrioritization = .quality
        device = camera
    }

    func start() async {
        await Task.detached { [session] in
            if !session.isRunning {
                session.startRunning()
            }
        }.value
        isRunning = session.isRunning
    }

    func lockCameraSettings() throws {
        guard let device else { throw CameraError.configurationFailed }
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }

        if device.isFocusModeSupported(.locked) {
            device.focusMode = .locked
        }

        #if os(iOS)
        if device.isExposureModeSupported(.custom) {
            let duration = device.exposureDuration
            let iso = min(max(device.iso, device.activeFormat.minISO), device.activeFormat.maxISO)
            device.setExposureModeCustom(duration: duration, iso: iso)
        }
        #endif

        if device.isWhiteBalanceModeSupported(.locked) {
            device.whiteBalanceMode = .locked
        }
    }

    func capturePhoto() async throws -> CapturedPhoto {
        guard isRunning else { throw CameraError.sessionNotRunning }
        guard continuation == nil, !isCapturing else { throw CameraError.captureInProgress }
        isCapturing = true

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let settings = AVCapturePhotoSettings()
            settings.photoQualityPrioritization = .quality
            photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    private func metadata(imageWidth: Int?, imageHeight: Int?) -> CaptureMetadata {
        #if os(iOS)
        let gains = device?.deviceWhiteBalanceGains
        let exposureDuration = device.map { CMTimeGetSeconds($0.exposureDuration) }
        let iso = device?.iso
        let lensPosition = device?.lensPosition
        let whiteBalanceGains = gains.map { WhiteBalanceGains(red: $0.redGain, green: $0.greenGain, blue: $0.blueGain) }
        #else
        let exposureDuration: Double? = nil
        let iso: Float? = nil
        let lensPosition: Float? = nil
        let whiteBalanceGains: WhiteBalanceGains? = nil
        #endif

        return CaptureMetadata(
            deviceModel: platformDeviceModel(),
            lens: device?.localizedName ?? "built_in_wide_angle",
            exposureDurationSeconds: exposureDuration,
            iso: iso,
            focusLensPosition: lensPosition,
            whiteBalanceGains: whiteBalanceGains,
            imageWidth: imageWidth,
            imageHeight: imageHeight,
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.0",
            timestamp: Date()
        )
    }

    private func platformDeviceModel() -> String {
        #if canImport(UIKit)
        UIDevice.current.model
        #else
        "macOS"
        #endif
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        Task { @MainActor in
            if let error {
                continuation?.resume(throwing: error)
                continuation = nil
                isCapturing = false
                return
            }

            #if canImport(UIKit)
            guard let data = photo.fileDataRepresentation(),
                  let image = UIImage(data: data),
                  let cgImage = image.uprightCGImage,
                  let linearImage = LinearImage(cgImage: cgImage) else {
                continuation?.resume(throwing: CameraError.captureFailed)
                continuation = nil
                isCapturing = false
                return
            }

            let metadata = metadata(
                imageWidth: cgImage.width,
                imageHeight: cgImage.height
            )
            lastMetadata = metadata
            continuation?.resume(returning: CapturedPhoto(linearImage: linearImage, metadata: metadata))
            continuation = nil
            isCapturing = false
            #else
            let metadata = metadata(imageWidth: nil, imageHeight: nil)
            lastMetadata = metadata
            continuation?.resume(throwing: CameraError.captureFailed)
            continuation = nil
            isCapturing = false
            #endif
        }
    }
}

struct CapturedPhoto {
    var linearImage: LinearImage
    var metadata: CaptureMetadata
}

enum CameraError: Error {
    case notAuthorized
    case noWideCamera
    case configurationFailed
    case captureFailed
    case captureInProgress
    case sessionNotRunning
}

#if canImport(UIKit)
private extension UIImage {
    var uprightCGImage: CGImage? {
        if imageOrientation == .up {
            return cgImage
        }

        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }.cgImage
    }
}
#endif
