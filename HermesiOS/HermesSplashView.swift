//
//  HermesSplashView.swift
//  HermesiOS
//

import AVFoundation
import Combine
import SwiftUI
import UIKit

struct HermesSplashView: View {
    @StateObject private var playerModel = HermesSplashPlayerModel()

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = playerModel.player {
                HermesSplashVideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        playerModel.playFromBeginning()
                    }
                    .onDisappear {
                        playerModel.stop()
                    }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

@MainActor
private final class HermesSplashPlayerModel: ObservableObject {
    let player: AVPlayer?

    init() {
        guard let videoURL = Bundle.main.url(forResource: "HermesSplash", withExtension: "mp4")
            ?? Bundle.main.url(forResource: "HermesSplash", withExtension: "mp4", subdirectory: "Resources")
        else {
            player = nil
            return
        }

        let player = AVPlayer(url: videoURL)
        player.isMuted = true
        player.actionAtItemEnd = .pause
        self.player = player
    }

    func playFromBeginning() {
        player?.seek(to: .zero)
        player?.play()
    }

    func stop() {
        player?.pause()
    }
}

private struct HermesSplashVideoPlayer: UIViewRepresentable {
    let player: AVPlayer

    func makeUIView(context: Context) -> HermesSplashVideoPlayerView {
        let view = HermesSplashVideoPlayerView()
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: HermesSplashVideoPlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
}

private final class HermesSplashVideoPlayerView: UIView {
    override static var layerClass: AnyClass {
        AVPlayerLayer.self
    }

    var playerLayer: AVPlayerLayer {
        layer as! AVPlayerLayer
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .black
        playerLayer.videoGravity = .resizeAspectFill
    }
}