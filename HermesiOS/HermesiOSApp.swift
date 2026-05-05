//
//  HermesiOSApp.swift
//  HermesiOS
//
//  Created by Laurent Dubertrand on 04/05/2026.
//

import SwiftUI

@main
struct HermesiOSApp: App {
    init() {
        HermesAppearance.configureGlobalAppearance()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .tint(.igActionBlue)
        }
    }
}
