//
//  HermesSplashView.swift
//  HermesiOS
//

import SwiftUI

struct HermesSplashView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.02, green: 0.03, blue: 0.06),
                    Color(red: 0.04, green: 0.10, blue: 0.18),
                    Color(red: 0.01, green: 0.02, blue: 0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "sparkles.tv")
                    .font(.system(size: 58, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(22)
                    .hermesLiquidGlass(cornerRadius: 28, tint: Color.white.opacity(0.10))

                Text("Hermes")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("iOS Console")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(32)
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}