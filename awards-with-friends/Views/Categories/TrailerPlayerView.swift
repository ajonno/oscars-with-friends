import SwiftUI
import YouTubePlayerKit

struct TrailerPlayerView: View {
    let youTubeId: String
    @Environment(\.dismiss) private var dismiss

    @State private var player: YouTubePlayer

    init(youTubeId: String) {
        self.youTubeId = youTubeId
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
                    EmptyView()
                case .error:
                    Text("Failed to load trailer")
                        .foregroundStyle(.white)
                }
            }
            .ignoresSafeArea()

            Button(action: { dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding()
        }
    }
}
