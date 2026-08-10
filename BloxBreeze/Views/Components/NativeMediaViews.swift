import AVKit
import SwiftUI
import UIKit

struct RemoteMediaImage: View {
    let url: URL
    var maxHeight: CGFloat = 340
    var onTap: (() -> Void)?
    @State private var reloadID = 0

    var body: some View {
        HighQualityAsyncImage(url: url, reloadID: reloadID) { phase in
            switch phase {
            case let .success(image):
                loadedImage(image)
            case .failure:
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title2)
                    Text("Image couldn't load")
                        .font(.subheadline.weight(.semibold))
                    Button("Try again") { reloadID += 1 }
                        .buttonStyle(.glass)
                }
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 170, maxHeight: maxHeight)
            case .empty:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, minHeight: 170, maxHeight: maxHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: 22))
        .breezeGlass(cornerRadius: 22, tint: Color.breezeLavender.opacity(0.035))
    }

    @ViewBuilder
    private func loadedImage(_ image: UIImage) -> some View {
        let rendered = NativeUIImageView(image: image, contentMode: .scaleAspectFit)
            .aspectRatio(imageAspectRatio(image), contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: maxHeight)
            .padding(8)
            .contentShape(.rect)

        if let onTap {
            Button(action: onTap) {
                rendered
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
            rendered
        }
    }

    private func imageAspectRatio(_ image: UIImage) -> CGFloat {
        guard image.size.height > 0 else { return 16.0 / 9.0 }
        return image.size.width / image.size.height
    }
}

struct InlineVideoView: View {
    let media: XPostMedia
    @State private var player: AVPlayer?
    @State private var isFullScreen = false

    var body: some View {
        VStack(alignment: .trailing, spacing: 10) {
            playbackSurface
                .aspectRatio(CGFloat(media.aspectRatio ?? (16.0 / 9.0)), contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: 430)
                .background(.black)
                .clipShape(.rect(cornerRadius: 22))

            Button(action: presentFullScreen) {
                Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .frame(minHeight: 46)
                    .glassEffect(
                        .regular.tint(Color.breezeLavender.opacity(0.10)).interactive(),
                        in: Capsule()
                    )
            }
            .buttonStyle(.plain)
            .contentShape(Capsule())
            .accessibilityLabel("Play video full screen")
        }
        .fullScreenCover(isPresented: $isFullScreen) {
            if let player {
                FullScreenVideoPlayer(player: player)
            }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder
    private var playbackSurface: some View {
        if let player {
            VideoPlayer(player: player)
        } else {
            Button(action: startPlayback) {
                ZStack {
                    if let previewURL = media.previewURL {
                        HighQualityAsyncImage(url: previewURL) { phase in
                            if case let .success(image) = phase {
                                NativeUIImageView(image: image, contentMode: .scaleAspectFill)
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

    private func startPlayback() {
        activePlayer().play()
    }

    private func presentFullScreen() {
        activePlayer().play()
        isFullScreen = true
    }

    private func activePlayer() -> AVPlayer {
        if let player { return player }
        let newPlayer = AVPlayer(url: media.url)
        player = newPlayer
        return newPlayer
    }
}

private struct FullScreenVideoPlayer: View {
    @Environment(\.dismiss) private var dismiss
    let player: AVPlayer

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VideoPlayer(player: player)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                Label("Full-screen video", systemImage: "video.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Label("Close", systemImage: "xmark")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .glassEffect(
                            .regular.tint(.black.opacity(0.24)).interactive(),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .contentShape(Capsule())
                .accessibilityLabel("Close full-screen video")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .glassEffect(
                .regular.tint(.black.opacity(0.22)),
                in: .rect(cornerRadius: 24)
            )
            .padding(.horizontal, 10)
        }
        .statusBarHidden(true)
        .onAppear { player.play() }
    }
}

struct FullScreenImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let item: ZoomableImageItem
    @State private var loadedImage: UIImage?
    @State private var loadFailed = false
    @State private var reloadID = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let loadedImage {
                ZoomingImageScrollView(image: loadedImage)
            } else if loadFailed {
                VStack(spacing: 14) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.largeTitle)
                    Text("Image couldn't load")
                        .font(.headline)
                    Button("Try again") { reloadID += 1 }
                        .buttonStyle(.glass)
                }
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
        .task(id: "\(item.id)#\(reloadID)") { await loadImage() }
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
            loadedImage = try await MediaImagePipeline.shared.image(for: item.url)
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }
}

enum HighQualityImagePhase {
    case empty
    case success(UIImage)
    case failure
}

struct HighQualityAsyncImage<Content: View>: View {
    let url: URL
    let reloadID: Int
    let content: (HighQualityImagePhase) -> Content

    @State private var phase = HighQualityImagePhase.empty

    init(
        url: URL,
        reloadID: Int = 0,
        @ViewBuilder content: @escaping (HighQualityImagePhase) -> Content
    ) {
        self.url = url
        self.reloadID = reloadID
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: "\(url.absoluteString)#\(reloadID)") {
                phase = .empty
                do {
                    phase = .success(try await MediaImagePipeline.shared.image(for: url))
                } catch is CancellationError {
                    return
                } catch {
                    phase = .failure
                }
            }
    }
}

struct NativeUIImageView: UIViewRepresentable {
    let image: UIImage
    let contentMode: UIView.ContentMode

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.clipsToBounds = true
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {
        view.contentMode = contentMode
        if view.image !== image {
            view.image = image
        }
        if image.images != nil {
            view.startAnimating()
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
