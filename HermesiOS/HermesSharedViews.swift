//
//  HermesSharedViews.swift
//  HermesiOS
//

import SwiftUI

struct HermesHeroCard: View {
    let title: String
    let detail: String
    let systemImage: String

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // A faint colored wash refracted by the glass, plus a soft
            // highlight blob to sell the liquid feel.
            LinearGradient(
                colors: [
                    Color.igGradPurple.opacity(0.18),
                    Color.igActionBlue.opacity(0.10),
                    Color.igGradOrangeYellow.opacity(0.10)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .blendMode(.plusLighter)

            Circle()
                .fill(.white.opacity(0.18))
                .frame(width: 180, height: 180)
                .blur(radius: 36)
                .offset(x: 140, y: -90)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.igActionBlue)
                        .frame(width: 32, height: 32)
                        .hermesLiquidGlass(cornerRadius: 10, tint: .igActionBlue.opacity(0.22), interactive: true)

                    Text(title)
                        .font(.igUsername)
                        .foregroundStyle(.primary)
                }

                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.hermesSecondaryText)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .bottomLeading)
        .hermesLiquidGlass(cornerRadius: 22, tint: .igActionBlue.opacity(0.08), interactive: true)
        .shadow(color: Color.black.opacity(0.08), radius: 18, y: 10)
    }
}

struct HermesTabHeader: View {
    let title: String
    let systemImage: String

    init(_ title: String, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 42, weight: .semibold))
                .foregroundStyle(.igActionBlue)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)

            Text(title)
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 4)
        .padding(.top, 4)
        .padding(.bottom, 2)
        .accessibilityElement(children: .combine)
    }
}

struct HermesSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(title.uppercased())
                    .font(.igSecondaryMeta.weight(.semibold))
                    .tracking(0.8)
                    .foregroundStyle(.hermesSecondaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 16)
            .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 22, tint: .white.opacity(0.04))
    }
}

struct HermesStatusRow: View {
    let items: [HermesStatusItem]

    var body: some View {
        ViewThatFits {
            HStack(spacing: 12) {
                ForEach(items) { item in
                    HermesStatusPill(item: item)
                }
            }

            VStack(spacing: 12) {
                ForEach(items) { item in
                    HermesStatusPill(item: item)
                }
            }
        }
    }
}

struct HermesStatusPill: View {
    let item: HermesStatusItem

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(item.accent)
                .frame(width: 4, height: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title.uppercased())
                    .font(.igBadge)
                    .tracking(0.6)
                    .foregroundStyle(.hermesSecondaryText)
                Text(item.value)
                    .font(.igUsername)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 18, tint: item.accent.opacity(0.08), interactive: false)
    }
}


struct HermesChatMessageCard: View {
    let message: HermesChatMessage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(message.role.capitalized)
                    .font(.headline)
                Spacer()
                Text(message.role == "user" ? "Prompt" : "Reply")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(roleColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .hermesLiquidGlass(cornerRadius: 999, tint: roleColor.opacity(0.18))
            }

            Text(message.content)
                .font(.subheadline)
                .foregroundStyle(.hermesSecondaryText)
                .textSelection(.enabled)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .hermesLiquidGlass(cornerRadius: 20, tint: roleColor.opacity(0.06))
    }

    private var roleColor: Color {
        message.role == "user" ? .igActionBlue : .igOnlineGreen
    }
}


struct HermesStatusItem: Identifiable {
    let id = UUID()
    let title: String
    let value: String
    let accent: Color
}
