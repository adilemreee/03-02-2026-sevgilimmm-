//
//  SecretVaultMediaViewer.swift
//  sevgilim
//

import SwiftUI
import AVKit
import UIKit

struct SecretVaultMediaViewer: View {
    @Binding var items: [SecretVaultItem]
    @Binding var currentIndex: Int
    let onClose: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var secretVaultService: SecretVaultService
    
    @State private var pageIndex: Int
    @State private var showControls = true
    @State private var hasDismissed = false
    @State private var showShareSheet = false
    @State private var showDeleteAlert = false
    @State private var shareItems: [Any]?
    @State private var isPreparingShare = false
    
    init(items: Binding<[SecretVaultItem]>, currentIndex: Binding<Int>, onClose: @escaping () -> Void) {
        _items = items
        _currentIndex = currentIndex
        self.onClose = onClose
        _pageIndex = State(initialValue: currentIndex.wrappedValue)
    }
    
    private var itemsCount: Int {
        items.count
    }
    
    private var clampedPageIndex: Int {
        guard itemsCount > 0 else { return 0 }
        return min(max(pageIndex, 0), itemsCount - 1)
    }
    
    private var currentItem: SecretVaultItem? {
        guard itemsCount > 0 else { return nil }
        return items[clampedPageIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if itemsCount == 0 {
                viewerEmptyState
                    .onAppear {
                        closeViewer()
                    }
            } else {
                carousel
                overlayControls
            }
        }
        .statusBar(hidden: itemsCount > 0 ? !showControls : false)
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
        .alert("Medyayı Sil", isPresented: $showDeleteAlert) {
            Button("İptal", role: .cancel) {}
            Button("Sil", role: .destructive) {
                deleteCurrentItem()
            }
        } message: {
            Text("Bu medyayı silmek istediğinizden emin misiniz?")
        }
        .onAppear {
            syncPageIndex()
            if itemsCount == 0 {
                closeViewer()
            }
        }
        .onChange(of: itemsCount) { _, _ in
            guard itemsCount > 0 else {
                closeViewer()
                return
            }
            syncPageIndex()
        }
        .onChange(of: pageIndex) { _, _ in
            guard itemsCount > 0 else { return }
            let clamped = clampedPageIndex
            if pageIndex != clamped {
                pageIndex = clamped
            }
            if currentIndex != clamped {
                currentIndex = clamped
            }
            withAnimation(.easeInOut(duration: 0.2)) {
                showControls = true
            }
        }
        .onDisappear {
            if !hasDismissed {
                onClose()
            }
        }
    }
    
    private var viewerEmptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock")
                .font(.system(size: 56))
                .foregroundColor(.white.opacity(0.6))
            Text("Görüntülenecek medya bulunamadı")
                .foregroundColor(.white)
                .font(.headline)
        }
    }
    
    private var carousel: some View {
        TabView(selection: $pageIndex) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Group {
                    if item.isVideo {
                        SecretVaultVideoViewerContent(item: item, isActive: pageIndex == index) {
                            toggleControls()
                        }
                    } else {
                        SecretVaultPhotoViewerContent(item: item) {
                            toggleControls()
                        }
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
                            .frame(width: 42, height: 42)
                            .overlay(
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                            )
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 10) {
                        infoCapsule
                        HStack(spacing: 10) {
                            // Share button
                            actionButton(systemImage: isPreparingShare ? "ellipsis" : "square.and.arrow.up") {
                                shareCurrentItem()
                            }
                            .disabled(isPreparingShare)
                            
                            // Delete button
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
            
            if showControls {
                noteOverlay
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showControls)
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
    
    @ViewBuilder
    private var infoCapsule: some View {
        if let item = currentItem {
            HStack(spacing: 6) {
                // Video/Photo icon
                Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                    .font(.caption2)
                
                // Metadata in one line with separators
                Text(buildMetadataString(for: item))
            }
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
        }
    }
    
    private func buildMetadataString(for item: SecretVaultItem) -> String {
        var parts: [String] = []
        
        // Duration for videos
        if item.isVideo, let duration = item.duration {
            parts.append(videoDurationText(from: duration))
        }
        
        // File size
        if let size = item.formattedSize {
            parts.append(size)
        }
        
        // Page indicator
        if itemsCount > 1 {
            parts.append("\(clampedPageIndex + 1)/\(itemsCount)")
        }
        
        return parts.joined(separator: " • ")
    }
    
    private func videoDurationText(from duration: Double) -> String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    @ViewBuilder
    private var noteOverlay: some View {
        if let item = currentItem,
           let note = item.note,
           !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Text(note)
                .font(.footnote)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 24)
                .padding(.bottom, 28)
        }
    }
    
    private func toggleControls() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showControls.toggle()
        }
    }
    
    private func closeViewer() {
        guard !hasDismissed else { return }
        hasDismissed = true
        onClose()
        dismiss()
    }
    
    private func syncPageIndex() {
        let clamped = clampedPageIndex
        if pageIndex != clamped {
            pageIndex = clamped
        }
        if currentIndex != clamped {
            currentIndex = clamped
        }
    }
    
    // MARK: - Share
    
    private func shareCurrentItem() {
        guard let item = currentItem else { return }
        isPreparingShare = true
        
        Task {
            do {
                if item.isVideo {
                    // Video için cache'den veya doğrudan URL'den indir
                    let localURL = try await VideoCacheService.shared.cachedURL(for: item.downloadURL)
                    await MainActor.run {
                        isPreparingShare = false
                        shareItems = [localURL]
                        showShareSheet = true
                    }
                } else {
                    // Fotoğraf için indir
                    if let url = URL(string: item.downloadURL) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            await MainActor.run {
                                isPreparingShare = false
                                shareItems = [image]
                                showShareSheet = true
                            }
                        } else {
                            throw NSError(domain: "SecretVault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Görsel okunamadı"])
                        }
                    }
                }
            } catch {
                print("❌ SecretVault Share error: \(error.localizedDescription)")
                await MainActor.run {
                    isPreparingShare = false
                }
            }
        }
    }
    
    // MARK: - Delete
    
    private func deleteCurrentItem() {
        guard let item = currentItem else { return }
        Task {
            do {
                try await secretVaultService.delete(item)
                await MainActor.run {
                    // items binding'i otomatik güncellenecek
                    if itemsCount == 0 {
                        closeViewer()
                    } else {
                        let newIndex = max(0, min(pageIndex, itemsCount - 1))
                        pageIndex = newIndex
                        currentIndex = newIndex
                    }
                }
            } catch {
                print("❌ SecretVault Delete error: \(error.localizedDescription)")
            }
        }
    }
}

private struct SecretVaultPhotoViewerContent: View {
    let item: SecretVaultItem
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
                Color.black.ignoresSafeArea()
                
                if isLoading {
                    loadingState
                } else if let error = loadError {
                    errorState(error: error)
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
                        .onTapGesture {
                            onTap()
                        }
                }
            }
            .onAppear {
                loadImage()
            }
        }
    }
    
    private var loadingState: some View {
        VStack(spacing: 18) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(2)
            Text("Yükleniyor...")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }
    
    private func errorState(error: Error) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            Text("Medya yüklenemedi")
                .font(.headline)
                .foregroundColor(.white)
            Text(error.localizedDescription)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal)
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
                } else {
                    lastOffset = offset
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
                if let image = try await ImageCacheService.shared.loadImage(from: item.downloadURL, thumbnail: false) {
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                } else {
                    throw NSError(domain: "SecretVaultPhotoViewer", code: -1, userInfo: [NSLocalizedDescriptionKey: "Görüntü verisi okunamadı"])
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

// MARK: - Video Viewer with Native Controls

private struct SecretVaultVideoViewerContent: View {
    let item: SecretVaultItem
    let isActive: Bool
    let onTap: () -> Void
    
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var showPlaceholder = true
    @State private var loadError: Error?
    @State private var timeObserver: Any?
    @State private var endObserver: NSObjectProtocol?
    @State private var hasStarted = false
    @State private var hasPrepared = false
    @State private var loadedURL: String?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                // Placeholder thumbnail
                if showPlaceholder {
                    if let thumbnailURL = item.thumbnailURL {
                        CachedAsyncImage(url: thumbnailURL, thumbnail: false) { image, _ in
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: geometry.size.width, height: geometry.size.height)
                        } placeholder: {
                            Color.black.opacity(0.2)
                        }
                    } else {
                        // Thumbnail yoksa siyah arka plan
                        Color.black
                    }
                }
                
                // Video player with native controls
                if let player = player, loadError == nil {
                    SecretVaultVideoPlayerController(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .opacity(showPlaceholder ? 0 : 1)
                        .contentShape(Rectangle())
                        .simultaneousGesture(
                            TapGesture().onEnded {
                                onTap()
                            }
                        )
                }
                
                // Loading indicator
                if isLoading && loadError == nil {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.8)
                }
                
                // Error state with retry button
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
                        
                        Button {
                            retryLoading()
                        } label: {
                            Label("Tekrar Dene", systemImage: "arrow.clockwise")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .onAppear {
                if isActive && !hasPrepared {
                    prepareVideo()
                }
            }
            .onChange(of: isActive) { _, newValue in
                if newValue {
                    if player == nil && !hasPrepared {
                        prepareVideo()
                    } else if let player = player {
                        player.play()
                    }
                } else {
                    player?.pause()
                }
            }
            .onDisappear {
                cleanup()
            }
        }
    }
    
    private func retryLoading() {
        cleanup()
        hasPrepared = false
        loadError = nil
        prepareVideo()
    }
    
    private func prepareVideo() {
        // Zaten hazırlanıyorsa veya aynı URL için hazırlanmışsa tekrar hazırlama
        guard !hasPrepared || loadedURL != item.downloadURL else {
            if let player = player {
                player.play()
            }
            return
        }
        
        hasPrepared = true
        loadedURL = item.downloadURL
        isLoading = true
        loadError = nil
        
        Task {
            do {
                // Video'yu cache'le ve local URL al
                let localURL = try await VideoCacheService.shared.cachedURL(for: item.downloadURL)
                
                // URL'nin geçerli olduğunu kontrol et
                guard FileManager.default.fileExists(atPath: localURL.path) else {
                    throw NSError(domain: "SecretVault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Video dosyası bulunamadı"])
                }
                
                let asset = AVURLAsset(url: localURL)
                
                // Asset'in oynatılabilir olduğunu kontrol et
                let isPlayable = try await asset.load(.isPlayable)
                guard isPlayable else {
                    throw NSError(domain: "SecretVault", code: -2, userInfo: [NSLocalizedDescriptionKey: "Video oynatılamıyor"])
                }
                
                let playerItem = AVPlayerItem(asset: asset)
                let newPlayer = AVPlayer(playerItem: playerItem)
                newPlayer.actionAtItemEnd = .pause
                newPlayer.automaticallyWaitsToMinimizeStalling = false
                
                await MainActor.run {
                    // Eski player'ı temizle
                    cleanupPlayer()
                    
                    self.player = newPlayer
                    self.addObservers(to: newPlayer)
                    self.isLoading = false
                    
                    if isActive {
                        newPlayer.play()
                    }
                }
            } catch {
                await MainActor.run {
                    self.loadError = error
                    self.isLoading = false
                    self.hasPrepared = false // Tekrar denenebilsin
                    print("❌ SecretVault Video Error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func addObservers(to player: AVPlayer) {
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [self] time in
            let elapsed = CMTimeGetSeconds(time)
            if elapsed.isFinite, elapsed > 0.1, !hasStarted {
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
            // Loop video
            player.seek(to: .zero)
            player.play()
        }
    }
    
    private func cleanupPlayer() {
        if let observer = timeObserver, let player = player {
            player.removeTimeObserver(observer)
            timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player?.pause()
        player = nil
    }
    
    private func cleanup() {
        cleanupPlayer()
        hasStarted = false
        isLoading = false
        showPlaceholder = true
        hasPrepared = false
        loadedURL = nil
    }
}

// MARK: - Native Video Player Controller (AVPlayerViewController)

private struct SecretVaultVideoPlayerController: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true  // Native kontroller açık
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
