import SwiftUI

@main
struct FocusFeedApp: App {
    private let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

    var body: some Scene {
        WindowGroup {
            if isUnitTesting {
                Color.clear
            } else {
                RootView()
            }
        }
    }
}
