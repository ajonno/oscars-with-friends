import SwiftUI
import YouTubePlayerKit

struct TrailerPlayerView: View {
    let youTubeId: String
    var allowsDesktopFullscreenTransition: Bool = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var player: YouTubePlayer
    @State private var showDesktopFullscreen = false
    @State private var didRequestDesktopPlaybackQuality = false

    private static var usesDesktopFullscreenOption: Bool {
#if targetEnvironment(macCatalyst)
        true
#else
        ProcessInfo.processInfo.isiOSAppOnMac
#endif
    }

    private var showsDesktopFullscreenButton: Bool {
        Self.usesDesktopFullscreenOption && allowsDesktopFullscreenTransition
    }

    private var browserURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(youTubeId)")
    }

    init(youTubeId: String) {
        self.youTubeId = youTubeId
        self._player = State(
            initialValue: YouTubePlayer(
                source: .video(id: youTubeId),
                parameters: .init(autoPlay: true, showControls: true)
            )
        )
    }

    init(youTubeId: String, allowsDesktopFullscreenTransition: Bool) {
        self.youTubeId = youTubeId
        self.allowsDesktopFullscreenTransition = allowsDesktopFullscreenTransition
        self._player = State(
            initialValue: YouTubePlayer(
                source: .video(id: youTubeId),
                parameters: .init(autoPlay: true, showControls: true)
            )
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            YouTubePlayerView(player) { state in
                switch state {
                case .idle:
                    ProgressView()
                        .tint(.white)
                case .ready:
                    Color.clear
                        .task {
                            await requestBestDesktopPlaybackQualityIfNeeded()
                        }
                case .error:
                    Text("Failed to load trailer")
                        .foregroundStyle(.white)
                }
            }
            .ignoresSafeArea()

            HStack(spacing: 12) {
                if Self.usesDesktopFullscreenOption, let browserURL {
                    Button {
                        Task {
                            await player.pauseMediaPlayback()
                            await player.closeMediaPresentation()
                            openURL(browserURL)
                            dismiss()
                        }
                    } label: {
                        Label("Open in Browser", systemImage: "safari")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.7))
                }

                if showsDesktopFullscreenButton {
                    Button {
                        showDesktopFullscreen = true
                    } label: {
                        Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.black.opacity(0.7))
                }

                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
            }
            .padding()
        }
        .fullScreenCover(isPresented: $showDesktopFullscreen) {
            TrailerPlayerView(youTubeId: youTubeId)
        }
    }

    private func requestBestDesktopPlaybackQualityIfNeeded() async {
        guard Self.usesDesktopFullscreenOption, !didRequestDesktopPlaybackQuality else {
            return
        }

        didRequestDesktopPlaybackQuality = true

        // Let the YouTube player finish loading metadata before choosing a quality level.
        try? await Task.sleep(for: .milliseconds(400))

        guard let information = try? await player.getInformation() else {
            return
        }

        let preferredQualities: [YouTubePlayer.PlaybackQuality] = [
            .highResolution,
            .hd1080,
            .hd720,
            .large
        ]

        let selectedQuality =
            preferredQualities.first { information.availableQualityLevels.contains($0) }
            ?? information.availableQualityLevels.first

        guard let selectedQuality else {
            return
        }

        let javaScript = try? YouTubePlayer.JavaScript.youTubePlayer(
            functionName: "setPlaybackQuality",
            jsonParameter: selectedQuality.name
        )
        .ignoreReturnValue()

        guard let javaScript else {
            return
        }

        try? await player.evaluate(javaScript: javaScript)
    }
}
