//
//  HermesWebsiteTypography.swift
//  HermesiOS
//

import CoreText
import SwiftUI

enum HermesWebsiteTypography {
    static func registerBundledFonts() {
        let urls = (Bundle.main.urls(forResourcesWithExtension: "woff2", subdirectory: "Fonts") ?? [])
            + (Bundle.main.urls(forResourcesWithExtension: "woff2", subdirectory: nil) ?? [])
        var registered = Set<URL>()
        for url in urls where registered.insert(url).inserted {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }
}

extension Font {
    static func hermesWebsiteTitle(size: CGFloat) -> Font {
        .custom("RulesExpanded-Bold", size: size)
    }

    static func hermesWebsiteSectionTitle(size: CGFloat) -> Font {
        .custom("RulesExpanded-Regular", size: size)
    }

    static func hermesWebsiteLabel(size: CGFloat) -> Font {
        .custom("Mondwest-Regular", size: size)
    }

    static func hermesWebsiteMono(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(weight == .bold || weight == .semibold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular", size: size)
    }
}

extension View {
    func hermesWebsiteTitleFont(size: CGFloat) -> some View {
        font(.hermesWebsiteTitle(size: size))
    }

    func hermesWebsiteSectionTitleFont(size: CGFloat) -> some View {
        font(.hermesWebsiteSectionTitle(size: size))
    }

    func hermesWebsiteLabelFont(size: CGFloat) -> some View {
        font(.hermesWebsiteLabel(size: size))
    }
}
