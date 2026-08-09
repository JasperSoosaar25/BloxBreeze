import AVKit
import SwiftUI

struct RemoteMediaImage: View {
    let url: URL
    var maxHeight: CGFloat = 430
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    image
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.bold())
                                .padding(10)
                                .background(.ultraThinMaterial, in: Circle())
                                .padding(10)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a full-screen image with pinch-to-zoom")
            } else {
                image
            }
        }
        .clipShape(.rect(cornerRadius: 22))
    }

    private var image: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
            case .failure:
                ContentUnavailableView("Image unavailable", systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: maxHeight)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: maxHeight)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .contentShape(.rect)
    }
}

struct InlineVideoView: View {
    let media: XPostMedia
    @State private var player: AVPlayer?

    var body: some View {
        Group {
            if let player {
                VideoPlayer(player: player)
            } else {
                Button {
                    let newPlayer = AVPlayer(url: media.url)
                    player = newPlayer
                    newPlayer.play()
                } label: {
                    ZStack {
                        if let previewURL = media.previewURL {
                            AsyncImage(url: previewURL) { phase in
                                if case let .success(image) = phase {
                                    image.resizable().scaledToFill()
                                } else {
                                    Color(uiColor: .secondarySystemBackground)
                                }
                            }
                        } else {
                            Color(uiColor: .secondarySystemBackground)
                        }

                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 68, height: 68)
                            .overlay {
                                Image(systemName: "play.fill")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)
                                    .offset(x: 2)
                            }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
            }
        }
        .aspectRatio(CGFloat(media.aspectRatio ?? (16.0 / 9.0)), contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 460)
        .background(.black)
        .clipShape(.rect(cornerRadius: 22))
        .onDisappear {
            player?.pause()
        }
    }
}

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let item: ZoomableImageItem

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: item.url) { phase in
                switch phase {
                case let .success(image):
                    ZoomableImage(image: image)
                case .failure:
                    ContentUnavailableView("Image unavailable", systemImage: "photo")
                        .foregroundStyle(.white)
                default:
                    ProgressView()
                        .tint(.white)
                }
            }

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.glass)
            .padding(18)
            .accessibilityLabel("Close image")
        }
        .statusBarHidden()
    }
}

private struct ZoomableImage: View {
    let image: Image
    @State private var scale: CGFloat = 1
    @State private var settledScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var settledOffset: CGSize = .zero

    var body: some View {
        image
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .contentShape(.rect)
            .gesture(
                MagnificationGesture()
                    .onChanged { value in
                        scale = min(max(settledScale * value, 1), 6)
                        if scale == 1 { offset = .zero }
                    }
                    .onEnded { _ in
                        settledScale = scale
                        if scale == 1 {
                            offset = .zero
                            settledOffset = .zero
                        }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > 1 else { return }
                        offset = CGSize(
                            width: settledOffset.width + value.translation.width,
                            height: settledOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in
                        settledOffset = offset
                    }
            )
            .simultaneousGesture(
                TapGesture(count: 2)
                    .onEnded {
                        withAnimation(.snappy) {
                            if scale > 1 {
                                scale = 1
                                settledScale = 1
                                offset = .zero
                                settledOffset = .zero
                            } else {
                                scale = 2.5
                                settledScale = 2.5
                            }
                        }
                    }
            )
            .accessibilityLabel("Zoomable story image")
            .accessibilityHint("Pinch or double tap to zoom")
    }
}
