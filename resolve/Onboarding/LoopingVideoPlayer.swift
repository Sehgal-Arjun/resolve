import SwiftUI
import AVKit

/// SwiftUI wrapper around `AVPlayerLayer` for playing a video on
/// repeat with no controls, no audio, no chrome — just the picture.
/// Used by the onboarding "Ask Resolve" demo step to show the gesture
/// in motion. Aspect-fits the video into the proposed frame.
struct LoopingVideoPlayer: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> LoopingVideoView {
        LoopingVideoView(url: url)
    }

    func updateNSView(_ nsView: LoopingVideoView, context: Context) {
        // URL is fixed at construction; nothing to update.
    }
}

/// Hosts an `AVPlayerLayer` and listens for end-of-playback to loop.
/// `AVPlayer.actionAtItemEnd = .none` keeps the player from
/// auto-pausing at the end; the notification observer rewinds and
/// plays again, giving us a seamless loop.
final class LoopingVideoView: NSView {
    private let player: AVPlayer
    private let playerLayer: AVPlayerLayer
    private var loopObserver: NSObjectProtocol?

    init(url: URL) {
        self.player = AVPlayer(url: url)
        self.player.isMuted = true
        self.player.actionAtItemEnd = .none

        self.playerLayer = AVPlayerLayer(player: self.player)
        self.playerLayer.videoGravity = .resizeAspect

        super.init(frame: .zero)
        wantsLayer = true
        layer = CALayer()
        layer?.addSublayer(self.playerLayer)

        loopObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }

        player.play()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) unavailable — use init(url:)")
    }

    override func layout() {
        super.layout()
        playerLayer.frame = bounds
    }

    deinit {
        if let observer = loopObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        player.pause()
    }
}
