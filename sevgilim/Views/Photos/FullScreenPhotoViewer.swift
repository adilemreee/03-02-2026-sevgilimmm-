//
//  FullScreenPhotoViewer.swift
//  sevgilim
//

import SwiftUI
import UIKit
import AVKit
import AVFoundation

struct FullScreenPhotoViewer: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var photoService: PhotoService
    
    @Binding private var currentIndex: Int
    private let onClose: () -> Void
    
    @State private var pageIndex: Int
    @State private var showControls = true
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var shareItems: [Any]?
    @State private var hasDismissed = false
    
    private var photos: [Photo] { photoService.photos }
    private var photoCount: Int { photos.count }
    
    private var clampedPageIndex: Int {
        guard photoCount > 0 else { return 0 }
        return min(max(pageIndex, 0), photoCount - 1)
    }
    
    private var currentPhoto: Photo? {
        guard photoCount > 0 else { return nil }
        return photos[clampedPageIndex]
    }
    
    init(currentIndex: Binding<Int>, onClose: @escaping () -> Void) {
        _currentIndex = currentIndex
        self.onClose = onClose
        _pageIndex = State(initialValue: currentIndex.wrappedValue)
    }
    
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            if photoCount == 0 {
                VStack(spacing: 20) {
                    Image(systemName: "photo.fill.on.rectangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Fotoğraf bulunamadı")
                        .foregroundColor(.white)
                        .font(.headline)
                }
                .onAppear {
                    closeViewer()
                }
            } else {
                carousel
                overlayControls
            }
        }
        .statusBar(hidden: photoCount > 0 ? !showControls : false)
        .sheet(isPresented: Binding(
            get: { showShareSheet && shareItems != nil },
            set: { newValue in
                if !newValue {
                    showShareSheet = false
                    shareItems = nil
                }
            }
        )) {
            if let items = shareItems {
                ShareSheet(items: items)
            }
        }
        .alert("Fotoğrafı Sil", isPresented: $showDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                deleteCurrentPhoto()
            }
        } message: {
            Text("Bu fotoğrafı silmek istediğinizden emin misiniz?")
        }
        .onAppear {
            syncPageIndex()
        }
        .onChange(of: photoService.photos.count) { _, _ in
            guard photoCount > 0 else {
                closeViewer()
                return
            }
            syncPageIndex()
        }
        .onChange(of: currentIndex) { _, _ in
            syncPageIndex()
        }
        .onChange(of: pageIndex) { _, newValue in
            guard photoCount > 0 else { return }
            let clamped = min(max(newValue, 0), photoCount - 1)
            if clamped != newValue {
                pageIndex = clamped
            }
            if currentIndex != clamped {
                currentIndex = clamped
            }
            withAnimation {
                showControls = true
            }
        }
        .onDisappear {
            if !hasDismissed {
                onClose()
            }
        }
    }
    
    private var carousel: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                PhotoViewerContent(photo: photo) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showControls.toggle()
                    }
                }
                .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }
    
    private var overlayControls: some View {
        VStack(spacing: 0) {
            if showControls {
                HStack(alignment: .top) {
                    Button(action: closeViewer) {
                        Circle()
                            .fill(.ultraThinMaterial)
                            .frame(width: 40, height: 40)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        quickInfoChip
                        HStack(spacing: 10) {
                            actionButton(systemImage: "square.and.arrow.up") {
                                shareCurrentPhoto()
                            }
                            actionButton(systemImage: "trash", color: .red) {
                                showDeleteAlert = true
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer()
        }
    }
    
    private var quickInfoChip: some View {
        HStack(spacing: 10) {
            if currentPhoto?.isVideo == true {
                HStack(spacing: 6) {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                    if let duration = currentPhoto?.duration {
                        Text(videoDurationText(from: duration))
                            .font(.caption.bold())
                    } else {
                        Text("Video")
                            .font(.caption.bold())
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.18), in: Capsule())
            }
            
            if let photo = currentPhoto, let location = photo.location, !location.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.caption2)
                    Text(location)
                        .font(.caption.bold())
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.18), in: Capsule())
            }
            
            if photoCount > 1 {
                Text("\(clampedPageIndex + 1) / \(photoCount)")
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.18), in: Capsule())
            }
        }
        .foregroundColor(.white)
    }
    
    private func videoDurationText(from duration: Double) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func actionButton(systemImage: String, color: Color = .white, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(.ultraThinMaterial)
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(color)
                )
        }
    }
    
    private func shareCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        Task {
            do {
                if photo.isVideo, let videoURL = photo.videoURL {
                    let localURL = try await VideoCacheService.shared.cachedURL(for: videoURL)
                    await MainActor.run {
                        shareItems = [localURL]
                        showShareSheet = true
                    }
                } else if let url = URL(string: photo.imageURL) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            shareItems = [image]
                            showShareSheet = true
                        }
                    }
                }
            } catch {
                print("❌ Share error: \(error.localizedDescription)")
            }
        }
    }
    
    private func deleteCurrentPhoto() {
        guard let photo = currentPhoto else { return }
        Task {
            do {
                try await photoService.deletePhoto(photo)
                await MainActor.run {
                    let updatedCount = photoService.photos.count
                    if updatedCount == 0 {
                        closeViewer()
                    } else {
                        let newIndex = max(0, min(pageIndex, updatedCount - 1))
                        pageIndex = newIndex
                        currentIndex = newIndex
                    }
                }
            } catch {
                print("❌ Delete error: \(error.localizedDescription)")
            }
        }
    }
    
    private func closeViewer() {
        guard !hasDismissed else { return }
        hasDismissed = true
        onClose()
        dismiss()
    }
    
    private func syncPageIndex() {
        guard photoCount > 0 else { return }
        let clamped = min(max(currentIndex, 0), photoCount - 1)
        if pageIndex != clamped {
            pageIndex = clamped
        }
        if currentIndex != clamped {
            currentIndex = clamped
        }
    }
}


private struct PhotoViewerContent: View {
    let photo: Photo
    let onTap: () -> Void
    
    var body: some View {
        if photo.isVideo {
            PhotoVideoViewerContent(photo: photo, onTap: onTap)
        } else {
            PhotoImageViewerContent(photo: photo, onTap: onTap)
        }
    }
}

private struct PhotoImageViewerContent: View {
    let photo: Photo
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(2)
                        Text("Yükleniyor...")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        Text("Fotoğraf yüklenemedi")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                } else if let image = loadedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(scale)
                        .offset(offset)
                        .simultaneousGesture(magnificationGesture(in: geometry))
                        .simultaneousGesture(dragGesture(in: geometry))
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if scale > 1 {
                                    resetTransform()
                                } else {
                                    scale = 2.5
                                }
                            }
                        }
                        .onTapGesture(count: 1) {
                            onTap()
                        }
                }
            }
            .onAppear { loadImage() }
        }
    }
    
    private func magnificationGesture(in geometry: GeometryProxy) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let delta = value / lastScale
                lastScale = value
                let newScale = scale * delta
                scale = min(max(newScale, 1), 4)
                offset = clamped(offset, in: geometry)
            }
            .onEnded { _ in
                lastScale = 1
                if scale < 1 {
                    withAnimation(.spring()) {
                        resetTransform()
                    }
                }
            }
    }
    
    private func dragGesture(in geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: scale > 1 ? 0 : .infinity)
            .onChanged { value in
                guard scale > 1 else { return }
                let proposed = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
                offset = clamped(proposed, in: geometry)
            }
            .onEnded { _ in
                if scale > 1 {
                    lastOffset = offset
                } else {
                    withAnimation(.spring()) {
                        resetTransform()
                    }
                }
            }
    }
    
    private func resetTransform() {
        scale = 1
        offset = .zero
        lastOffset = .zero
    }

    private func clamped(_ proposed: CGSize, in geometry: GeometryProxy) -> CGSize {
        guard let image = loadedImage else { return .zero }
        let container = geometry.size
        let baseScale = min(container.width / image.size.width, container.height / image.size.height)
        let fittedSize = CGSize(width: image.size.width * baseScale, height: image.size.height * baseScale)
        let scaledSize = CGSize(width: fittedSize.width * scale, height: fittedSize.height * scale)
        let maxX = max(0, (scaledSize.width - container.width) / 2)
        let maxY = max(0, (scaledSize.height - container.height) / 2)
        let clampedX = max(-maxX, min(proposed.width, maxX))
        let clampedY = max(-maxY, min(proposed.height, maxY))
        return CGSize(width: clampedX, height: clampedY)
    }
    
    private func loadImage() {
        isLoading = true
        loadError = nil
        Task {
            do {
                if let image = try await ImageCacheService.shared.loadImage(from: photo.imageURL, thumbnail: false) {
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                } else {
                    throw NSError(domain: "PhotoViewer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Görüntü verisi okunamadı"])
                }
            } catch {
                await MainActor.run {
                    loadError = error
                    isLoading = false
                }
            }
        }
    }
}

private struct PhotoVideoViewerContent: View {
    let photo: Photo
    let onTap: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var showPlaceholder = true
    @State private var loadError: Error?
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?
    @State private var hasStarted = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                if showPlaceholder {
                    CachedAsyncImage(url: photo.displayThumbnailURL, thumbnail: false) { image, _ in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width, height: geometry.size.height)
                    } placeholder: {
                        Color.black.opacity(0.2)
                    }
                }
                
                if let player = player {
                    PhotoVideoPlayerController(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(showPlaceholder ? 0 : 1)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                onTap()
                            }
                        )
                }
                
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.8)
                }
                
                if let error = loadError {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.yellow)
                        Text("Video yüklenemedi")
                            .font(.headline)
                            .foregroundColor(.white)
                        Text(error.localizedDescription)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
            }
            .onAppear {
                prepareVideo()
            }
            .onDisappear {
                cleanup()
            }
        }
    }
    
    private func prepareVideo() {
        guard player == nil else { return }
        Task {
            guard let videoURLString = photo.videoURL else {
                await MainActor.run {
                    self.loadError = NSError(domain: "PhotoViewer", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video bulunamadı"])
                    self.isLoading = false
                }
                return
            }
            
            do {
                let localURL = try await VideoCacheService.shared.cachedURL(for: videoURLString)
                let asset = AVURLAsset(url: localURL)
                let playerItem = AVPlayerItem(asset: asset)
                let player = AVPlayer(playerItem: playerItem)
                player.actionAtItemEnd = .pause
                player.automaticallyWaitsToMinimizeStalling = false
                if #available(iOS 17.0, *) {
                    _ = await player.seek(to: .zero)
                } else {
                    await player.seek(to: .zero)
                }
                
                await MainActor.run {
                    self.player = player
                    self.addObservers(to: player)
                    self.isLoading = false
                    player.play()
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                }
            }
        }
    }
    
    private func addObservers(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let elapsed = CMTimeGetSeconds(time)
            if elapsed.isFinite, elapsed > 0.05, !hasStarted {
                hasStarted = true
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPlaceholder = false
                }
            }
        }
        
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func cleanup() {
        player?.pause()
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player = nil
        hasStarted = false
        isLoading = false
        showPlaceholder = true
    }
}

private struct PhotoVideoPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.videoGravity = .resizeAspect
        controller.view.backgroundColor = .black
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
