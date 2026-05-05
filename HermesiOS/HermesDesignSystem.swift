//
//  HermesDesignSystem.swift
//  HermesiOS
//
//  Instagram-inspired design system. See DESIGN.md.
//

import SwiftUI
import UIKit

// MARK: - Color Tokens

extension Color {
    // Canvas & surfaces
    static let igCanvasLight   = Color.white
    static let igCanvasDark    = Color.black
    static let igElevatedDark  = Color(red: 0.071, green: 0.071, blue: 0.071) // #121212
    static let igSurfaceInputL = Color(red: 0.937, green: 0.937, blue: 0.937) // #EFEFEF
    static let igSurfaceInputD = Color(red: 0.149, green: 0.149, blue: 0.149) // #262626
    static let igDividerLight  = Color(red: 0.859, green: 0.859, blue: 0.859) // #DBDBDB
    static let igDividerDark   = Color(red: 0.149, green: 0.149, blue: 0.149) // #262626

    // Text
    static let igTextSecondaryL = Color(red: 0.557, green: 0.557, blue: 0.557) // #8E8E8E
    static let igTextSecondaryD = Color(red: 0.659, green: 0.659, blue: 0.659) // #A8A8A8

    // Brand
    static let igActionBlue    = Color(red: 0.000, green: 0.584, blue: 0.965) // #0095F6
    static let igActionPressed = Color(red: 0.094, green: 0.467, blue: 0.949) // #1877F2
    static let igDestructive   = Color(red: 0.929, green: 0.286, blue: 0.337) // #ED4956
    static let igLinkLight     = Color(red: 0.000, green: 0.216, blue: 0.420) // #00376B
    static let igLinkDark      = Color(red: 0.878, green: 0.945, blue: 1.0)   // #E0F1FF

    // Gradient stops (10 total)
    static let igGradBlue        = Color(red: 0.251, green: 0.365, blue: 0.902) // #405DE6
    static let igGradPurpleBlue  = Color(red: 0.345, green: 0.318, blue: 0.859) // #5851DB
    static let igGradPurple      = Color(red: 0.514, green: 0.227, blue: 0.706) // #833AB4
    static let igGradPurpleRed   = Color(red: 0.757, green: 0.208, blue: 0.518) // #C13584
    static let igGradRose        = Color(red: 0.882, green: 0.188, blue: 0.424) // #E1306C
    static let igGradRed         = Color(red: 0.992, green: 0.114, blue: 0.114) // #FD1D1D
    static let igGradRedOrange   = Color(red: 0.961, green: 0.376, blue: 0.251) // #F56040
    static let igGradOrange      = Color(red: 0.969, green: 0.467, blue: 0.216) // #F77737
    static let igGradOrangeYellow = Color(red: 0.988, green: 0.686, blue: 0.271) // #FCAF45
    static let igGradYellow      = Color(red: 1.0, green: 0.863, blue: 0.502)   // #FFDC80

    // Status
    static let igOnlineGreen   = Color(red: 0.471, green: 0.871, blue: 0.271) // #78DE45
    static let igCloseFriends  = Color(red: 0.184, green: 0.722, blue: 0.145) // #2FB825

    // Dynamic helpers (light/dark resolved at render time)
    static let hermesCanvas       = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor.black : UIColor.white })
    static let hermesElevated     = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.071, green: 0.071, blue: 0.071, alpha: 1) : UIColor.white })
    static let hermesSurfaceInput = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.149, green: 0.149, blue: 0.149, alpha: 1) : UIColor(red: 0.937, green: 0.937, blue: 0.937, alpha: 1) })
    static let hermesDivider      = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.149, green: 0.149, blue: 0.149, alpha: 1) : UIColor(red: 0.859, green: 0.859, blue: 0.859, alpha: 1) })
    static let hermesSecondaryText = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.659, green: 0.659, blue: 0.659, alpha: 1) : UIColor(red: 0.557, green: 0.557, blue: 0.557, alpha: 1) })
    static let hermesLink         = Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(red: 0.878, green: 0.945, blue: 1.0, alpha: 1) : UIColor(red: 0.0, green: 0.216, blue: 0.420, alpha: 1) })
}

// Allow `.foregroundStyle(.hermesXxx)` and similar shorthand by exposing
// the dynamic colors on `ShapeStyle`.
extension ShapeStyle where Self == Color {
    static var hermesCanvas: Color        { Color.hermesCanvas }
    static var hermesElevated: Color      { Color.hermesElevated }
    static var hermesSurfaceInput: Color  { Color.hermesSurfaceInput }
    static var hermesDivider: Color       { Color.hermesDivider }
    static var hermesSecondaryText: Color { Color.hermesSecondaryText }
    static var hermesLink: Color          { Color.hermesLink }

    static var igActionBlue: Color    { Color.igActionBlue }
    static var igActionPressed: Color { Color.igActionPressed }
    static var igDestructive: Color   { Color.igDestructive }
    static var igOnlineGreen: Color   { Color.igOnlineGreen }
    static var igCloseFriends: Color  { Color.igCloseFriends }
    static var igGradPurple: Color    { Color.igGradPurple }
    static var igGradOrange: Color    { Color.igGradOrange }
    static var igGradRose: Color      { Color.igGradRose }
    static var igGradBlue: Color      { Color.igGradBlue }
}

extension LinearGradient {
    /// The official Instagram story-ring gradient (10-stop sweep).
    static let instagramBrand = LinearGradient(
        gradient: Gradient(colors: [
            .igGradYellow, .igGradOrangeYellow, .igGradOrange, .igGradRedOrange,
            .igGradRed, .igGradRose, .igGradPurpleRed, .igGradPurple,
            .igGradPurpleBlue, .igGradBlue
        ]),
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )

    /// Short 3-stop version used in marketing surfaces.
    static let instagramBrandShort = LinearGradient(
        colors: [.igGradPurple, .igGradRed, .igGradOrangeYellow],
        startPoint: .bottomLeading,
        endPoint: .topTrailing
    )
}

extension AngularGradient {
    static let storyRing = AngularGradient(
        gradient: Gradient(colors: [
            .igGradYellow, .igGradOrangeYellow, .igGradOrange,
            .igGradRed, .igGradRose, .igGradPurple, .igGradYellow
        ]),
        center: .center
    )
}

// MARK: - Liquid Glass helpers

extension View {
    @ViewBuilder
    func hermesLiquidGlass(cornerRadius: CGFloat = 18, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(iOS 26.0, *) {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            let glass: Glass = {
                var configured = Glass.regular
                if let tint {
                    configured = configured.tint(tint)
                }
                if interactive {
                    configured = configured.interactive()
                }
                return configured
            }()

            self
                .glassEffect(glass, in: shape)
        } else {
            let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            self
                .background(.ultraThinMaterial, in: shape)
                .overlay {
                    shape
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8)
                }
        }
    }
}

struct HermesLiquidGlassBackground: View {
    var cornerRadius: CGFloat = 18
    var tint: Color? = nil
    var interactive: Bool = false

    var body: some View {
        Color.white.opacity(0.001)
            .hermesLiquidGlass(cornerRadius: cornerRadius, tint: tint, interactive: interactive)
    }
}

// MARK: - Typography

extension Font {
    static let igScreenTitle    = Font.system(size: 16, weight: .semibold, design: .default)
    static let igUsernameLarge  = Font.system(size: 20, weight: .bold,     design: .default)
    static let igUsername       = Font.system(size: 14, weight: .semibold, design: .default)
    static let igBio            = Font.system(size: 14, weight: .regular,  design: .default)
    static let igCaption        = Font.system(size: 14, weight: .regular,  design: .default)
    static let igComment        = Font.system(size: 14, weight: .regular,  design: .default)
    static let igSecondaryMeta  = Font.system(size: 12, weight: .regular,  design: .default)
    static let igButtonPrimary  = Font.system(size: 14, weight: .semibold, design: .default)
    static let igButtonSmall    = Font.system(size: 12, weight: .semibold, design: .default)
    static let igCounterLarge   = Font.system(size: 16, weight: .bold,     design: .default).monospacedDigit()
    static let igDMBubble       = Font.system(size: 16, weight: .regular,  design: .default)
    static let igBadge          = Font.system(size: 11, weight: .bold,     design: .default).monospacedDigit()
    static let igTimestamp      = Font.system(size: 11, weight: .regular,  design: .default)

    /// Logotype — falls back to a tightly tracked italic serif when Billabong is unavailable.
    static let igLogotype       = Font.custom("Billabong", size: 30).weight(.regular)
    static let hermesLogotype   = Font.system(size: 26, weight: .semibold, design: .serif).italic()
}

// MARK: - Button styles

struct IGPressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct IGPrimaryButton: View {
    enum Variant { case primary, secondary, destructive, outlined }

    let title: String
    var icon: String? = nil
    var variant: Variant = .primary
    var isLoading: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(fg)
                } else if let icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .font(.igButtonPrimary)
            }
            .foregroundStyle(fg)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(bg)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(strokeColor, lineWidth: 1)
            )
        }
        .buttonStyle(IGPressableStyle())
        .disabled(isLoading)
    }

    private var bg: Color {
        switch variant {
        case .primary:     return .igActionBlue
        case .secondary:   return .hermesSurfaceInput
        case .destructive: return .clear
        case .outlined:    return .clear
        }
    }

    private var fg: Color {
        switch variant {
        case .primary:     return .white
        case .secondary:   return .primary
        case .destructive: return .igDestructive
        case .outlined:    return .primary
        }
    }

    private var strokeColor: Color {
        switch variant {
        case .primary, .secondary, .destructive: return .clear
        case .outlined: return .hermesDivider
        }
    }
}

// MARK: - Story ring (used as session/thread avatar)

struct StoryRing: View {
    var systemImage: String
    var isActive: Bool = true
    var size: CGFloat = 56
    var tint: Color = .igActionBlue

    var body: some View {
        ZStack {
            if isActive {
                Circle()
                    .strokeBorder(AngularGradient.storyRing, lineWidth: 2.5)
            } else {
                Circle()
                    .strokeBorder(Color.hermesDivider, lineWidth: 1)
            }
            Circle()
                .fill(Color.hermesElevated)
                .padding(4)
            Image(systemName: systemImage)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(tint)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Hairline divider (IG style)

struct IGHairline: View {
    var body: some View {
        Rectangle()
            .fill(Color.hermesDivider)
            .frame(height: 0.5)
    }
}

// MARK: - Top brand bar

struct HermesBrandBar: View {
    let title: String
    var trailing: AnyView? = nil

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.hermesLogotype)
                .foregroundStyle(.primary)
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color.hermesCanvas)
        .overlay(alignment: .bottom) { IGHairline() }
    }
}

// MARK: - Section header (IG-style: caps, tracked, tiny)

struct IGSectionHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.igSecondaryMeta.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.hermesSecondaryText)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.igTimestamp)
                    .foregroundStyle(.hermesSecondaryText)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

// MARK: - Card surface (subtle, IG-flat)

struct IGCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.hermesElevated)
        .overlay(alignment: .top) { IGHairline() }
        .overlay(alignment: .bottom) { IGHairline() }
    }
}

// MARK: - Status pill (online/offline-style)

struct IGStatusPill: View {
    let label: String
    let value: String
    var tint: Color = .igActionBlue

    var body: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint)
                .frame(width: 4, height: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label.uppercased())
                    .font(.igBadge)
                    .tracking(0.6)
                    .foregroundStyle(.hermesSecondaryText)
                Text(value)
                    .font(.igUsername)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .hermesLiquidGlass(cornerRadius: 16, tint: tint.opacity(0.08), interactive: false)
    }
}

// MARK: - Chat-style message bubble (IG DM)

struct IGChatBubble: View {
    let text: String
    let isFromUser: Bool
    var timestamp: String? = nil

    var body: some View {
        HStack {
            if isFromUser { Spacer(minLength: 40) }
            VStack(alignment: isFromUser ? .trailing : .leading, spacing: 4) {
                Text(text)
                    .font(.igDMBubble)
                    .foregroundStyle(isFromUser ? Color.white : Color.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(isFromUser ? Color.igActionBlue : Color.hermesSurfaceInput)
                    )
                    .textSelection(.enabled)
                if let timestamp {
                    Text(timestamp.uppercased())
                        .font(.igTimestamp)
                        .tracking(0.5)
                        .foregroundStyle(.hermesSecondaryText)
                        .padding(.horizontal, 6)
                }
            }
            if !isFromUser { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Brand hero (uses Instagram gradient)

struct IGBrandHero: View {
    let title: String
    let subtitle: String
    var systemImage: String = "sparkles"

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient.instagramBrand
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: systemImage)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 38, height: 38)
                        .hermesLiquidGlass(cornerRadius: 12, tint: .white.opacity(0.16), interactive: true)
                    Text(title)
                        .font(.igUsernameLarge)
                        .foregroundStyle(.white)
                }
                Text(subtitle)
                    .font(.igBio)
                    .foregroundStyle(.white.opacity(0.92))
            }
            .padding(20)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .bottomLeading)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}

// MARK: - IG-styled icon button (action bar)

struct IGIconButton: View {
    let systemImage: String
    var size: CGFloat = 22
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .regular))
                .foregroundStyle(tint)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(IGPressableStyle())
    }
}

// MARK: - Tab bar appearance helper

enum HermesAppearance {
    static func configureGlobalAppearance() {
        // Tab bar — liquid-glass inspired translucency with a soft separator.
        let tab = UITabBarAppearance()
        tab.configureWithTransparentBackground()
        tab.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        tab.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.34)
        tab.shadowColor = UIColor.separator.withAlphaComponent(0.28)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab

        // Nav bar — translucent, modern, and visually aligned with the tab bar.
        let nav = UINavigationBarAppearance()
        nav.configureWithTransparentBackground()
        nav.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterial)
        nav.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.28)
        nav.shadowColor = UIColor.separator.withAlphaComponent(0.22)
        nav.titleTextAttributes = [
            .font: UIFont.systemFont(ofSize: 16, weight: .semibold)
        ]
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav
    }
}

// MARK: - Generic IG-styled text-field background

struct IGFieldBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.hermesSurfaceInput)
            )
    }
}

extension View {
    func igFieldBackground() -> some View { modifier(IGFieldBackground()) }
}
