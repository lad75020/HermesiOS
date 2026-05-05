//
//  HermesSplashView.swift
//  HermesiOS
//

import AVFoundation
import SwiftUI

struct HermesSplashView: View {
    private let resourceName = "HermesSplash"
    private let resourceExtension = "mp4"

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if let videoURL = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension) {
                HermesSplashPlayerView(url: videoURL)
                    .ignoresSafeArea()
            } else {
                VStack(spacing: 14) {
                    Image(systemName: "sparkles.tv")
                        .font(.system(size: 58, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Hermes")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

private struct HermesSplashPlayerView: UIViewRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> PlayerContainerView {
        let view = PlayerContainerView()
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.actionAtItemEnd = .none

        context.coordinator.player = player
        context.coordinator.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {
        uiView.playerLayer.videoGravity = .resizeAspectFill
        if uiView.playerLayer.player == nil {
            uiView.playerLayer.player = context.coordinator.player
        }
    }

    static func dismantleUIView(_ uiView: PlayerContainerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        uiView.playerLayer.player = nil
        if let endObserver = coordinator.endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        coordinator.endObserver = nil
        coordinator.player = nil
    }

    final class Coordinator {
        var player: AVPlayer?
        var endObserver: NSObjectProtocol?
    }
}

private final class PlayerContainerView: UIView {
    override class var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }
}
