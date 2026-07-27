import SwiftUI

@main
struct ColorMatchingLPSApp: App {
    var body: some Scene {
        WindowGroup {
            if ProcessInfo.processInfo.isRunningXCTest {
                EmptyView()
            } else {
                ContentView()
            }
        }
    }
}

private extension ProcessInfo {
    var isRunningXCTest: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
