//
//  LoopingVideoView.swift
//  Universal Search App
//
//  A muted, seamlessly looping, non-interactive video played from a bundled
//  resource. AVPlayerLooper + AVQueuePlayer gives a gapless loop; the player is
//  torn down when the view leaves the tree.
//

import SwiftUI
import AVFoundation

struct LoopingVideoView: UIViewRepresentable {
    let resource: String
    var ext: String = "mp4"
    var gravity: AVLayerVideoGravity = .resizeAspect
    var backgroundColor: Color = .black

    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.backgroundColor = UIColor(backgroundColor)
        view.playerLayer.videoGravity = gravity
        guard let url = Bundle.main.url(forResource: resource, withExtension: ext) else {
            #if DEBUG
            print("⚠️ [LoopingVideoView] missing resource: \(resource).\(ext)")
            #endif
            return view
        }
        let player = AVQueuePlayer()
        player.isMuted = true
        player.actionAtItemEnd = .none
        // Retain the looper on the coordinator; it drives the gapless repeat.
        context.coordinator.looper = AVPlayerLooper(player: player,
                                                    templateItem: AVPlayerItem(url: url))
        context.coordinator.player = player
        view.playerLayer.player = player
        player.play()
        return view
    }

    func updateUIView(_ uiView: PlayerView, context: Context) {
        uiView.backgroundColor = UIColor(backgroundColor)
        uiView.playerLayer.videoGravity = gravity
        context.coordinator.player?.play()
    }

    static func dismantleUIView(_ uiView: PlayerView, coordinator: Coordinator) {
        coordinator.player?.pause()
        uiView.playerLayer.player = nil
        coordinator.looper = nil
        coordinator.player = nil
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
    }

    /// A UIView whose backing layer IS the AVPlayerLayer, so it resizes with the
    /// view automatically (no manual frame bookkeeping).
    final class PlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
