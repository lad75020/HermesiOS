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
    static func hermesWebsiteTitle(size: CGFloat, relativeTo textStyle: Font.TextStyle = .title2) -> Font {
        .custom("RulesExpanded-Bold", size: size, relativeTo: textStyle)
    }

    static func hermesWebsiteSectionTitle(size: CGFloat, relativeTo textStyle: Font.TextStyle = .headline) -> Font {
        .custom("RulesExpanded-Regular", size: size, relativeTo: textStyle)
    }

    static func hermesWebsiteLabel(size: CGFloat, relativeTo textStyle: Font.TextStyle = .body) -> Font {
        .custom("Mondwest-Regular", size: size, relativeTo: textStyle)
    }

    static func hermesWebsiteMono(
        size: CGFloat,
        weight: Font.Weight = .regular,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> Font {
        .custom(
            weight == .bold || weight == .semibold ? "JetBrainsMono-Bold" : "JetBrainsMono-Regular",
            size: size,
            relativeTo: textStyle
        )
    }
}

extension View {
    func hermesWebsiteTitleFont(size: CGFloat) -> some View {
        font(.hermesWebsiteTitle(size: size, relativeTo: .title2))
    }

    func hermesWebsiteSectionTitleFont(size: CGFloat) -> some View {
        font(.hermesWebsiteSectionTitle(size: size, relativeTo: .headline))
    }

    func hermesWebsiteLabelFont(size: CGFloat) -> some View {
        font(.hermesWebsiteLabel(size: size, relativeTo: .body))
    }
}
