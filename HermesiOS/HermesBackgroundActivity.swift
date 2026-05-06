//
//  HermesBackgroundActivity.swift
//  HermesiOS
//

import UIKit

@MainActor
enum HermesBackgroundActivity {
    static func run<T>(named name: String, operation: () async throws -> T) async throws -> T {
        var identifier: UIBackgroundTaskIdentifier = .invalid
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) {
            if identifier != .invalid {
                UIApplication.shared.endBackgroundTask(identifier)
                identifier = .invalid
            }
        }

        defer {
            if identifier != .invalid {
                UIApplication.shared.endBackgroundTask(identifier)
                identifier = .invalid
            }
        }

        return try await operation()
    }
}
