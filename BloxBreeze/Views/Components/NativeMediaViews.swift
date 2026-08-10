import AVKit
import SwiftUI
import UIKit

struct RemoteMediaImage: View {
    let url: URL
    var maxHeight: CGFloat = 340
    var onTap: (() -> Void)?

    var body: some View {
        Group {
            if let onTap {
                Button(action: onTap) {
                    image
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.caption.bold())
                                .frame(width: 38, height: 38)
                                .glassEffect(
                                    .regular.tint(.black.opacity(0.14)).interactive(),
                                    in: Circle()
                                )
                                .padding(10)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens a centered full-screen image viewer")
            } else {
                image
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 22))
        .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.035))
    }

    private var image: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case let .success(image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: maxHeight)
                    .padding(8)
            case .failure:
                ContentUnavailableView("Image unavailable", systemImage: "photo")
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: maxHeight)
            default:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: maxHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.clear)
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

                        Rectangle().fill(.black.opacity(0.18))

                        VStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.title2.bold())
                                .foregroundStyle(.white)
                                .offset(x: 2)
                                .frame(width: 64, height: 64)
                                .glassEffect(
                                    .regular.tint(.black.opacity(0.22)).interactive(),
                                    in: Circle()
                                )
                            Text("Play video")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Play video")
            }
        }
        .aspectRatio(CGFloat(media.aspectRatio ?? (16.0 / 9.0)), contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: 430)
        .background(.black)
        .clipShape(.rect(cornerRadius: 22))
        .onDisappear { player?.pause() }
    }
}

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let item: ZoomableImageItem
    @State private var loadedImage: UIImage?
    @State private var loadFailed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let loadedImage {
                ZoomingImageScrollView(image: loadedImage)
            } else if loadFailed {
                ContentUnavailableView("Image unavailable", systemImage: "photo")
                    .foregroundStyle(.white)
            } else {
                ProgressView()
                    .controlSize(.large)
                    .tint(.white)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            viewerToolbar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            Text("Drag after zooming to look around")
                .font(.caption)
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassEffect(.regular.tint(.black.opacity(0.20)), in: Capsule())
                .padding(.bottom, 6)
        }
        .task(id: item.id) { await loadImage() }
    }

    private var viewerToolbar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Image viewer")
                    .font(.headline)
                Text("Pinch or double tap to zoom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.bold())
                    .frame(width: 42, height: 42)
                    .glassEffect(
                        .regular.tint(.white.opacity(0.08)).interactive(),
                        in: Circle()
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close image")
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(.black.opacity(0.20)), in: .rect(cornerRadius: 24))
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }

    @MainActor
    private func loadImage() async {
        loadedImage = nil
        loadFailed = false
        do {
            var request = URLRequest(url: item.url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 30
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let image = UIImage(data: data) else {
                throw FeedError.invalidResponse
            }
            loadedImage = image
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }
}

private struct ZoomingImageScrollView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.isUserInteractionEnabled = true
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scrollView
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            let horizontal = max(0, (scrollView.bounds.width - scrollView.contentSize.width) / 2)
            let vertical = max(0, (scrollView.bounds.height - scrollView.contentSize.height) / 2)
            scrollView.contentInset = UIEdgeInsets(
                top: vertical,
                left: horizontal,
                bottom: vertical,
                right: horizontal
            )
        }

        @objc func handleDoubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scrollView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
                return
            }

            let targetScale: CGFloat = 2.5
            let location = recognizer.location(in: imageView)
            let width = scrollView.bounds.width / targetScale
            let height = scrollView.bounds.height / targetScale
            scrollView.zoom(
                to: CGRect(
                    x: location.x - width / 2,
                    y: location.y - height / 2,
                    width: width,
                    height: height
                ),
                animated: true
            )
        }
    }
}
