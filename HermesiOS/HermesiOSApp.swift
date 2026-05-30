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
        HermesWebsiteTypography.registerBundledFonts()

        #if DEBUG
        StateServer.shared.start()
        #if canImport(UIKit)
        DebugBridgeUIWiring.installAll()
        #endif
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
