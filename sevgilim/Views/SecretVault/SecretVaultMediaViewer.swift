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
    
    @State private var pageIndex: Int
    @State private var showControls = true
    @State private var hasDismissed = false
    
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
                    infoCapsule
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
    
    @ViewBuilder
    private var infoCapsule: some View {
        if let item = currentItem {
            VStack(alignment: .trailing, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                    Text(item.isVideo ? "Video" : "Fotoğraf")
                }
                if let size = item.formattedSize {
                    Text(size)
                }
                if itemsCount > 1 {
                    Text("\(clampedPageIndex + 1) / \(itemsCount)")
                }
            }
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.18), in: Capsule())
        }
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

private struct SecretVaultVideoViewerContent: View {
    let item: SecretVaultItem
    let isActive: Bool
    let onTap: () -> Void
    
    @State private var player: AVPlayer?
    @State private var loadedURL: URL?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let url = URL(string: item.downloadURL) {
                    VideoPlayer(player: player)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .background(Color.black)
                        .ignoresSafeArea()
                        .onAppear {
                            configurePlayer(with: url)
                            if isActive {
                                player?.play()
                            }
                        }
                        .onChange(of: isActive) { _, newValue in
                            if newValue {
                                player?.play()
                            } else {
                                player?.pause()
                            }
                        }
                        .onDisappear {
                            player?.pause()
                        }
                        .overlay(
                            Color.black.opacity(0.001)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onTap()
                                }
                        )
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 56))
                            .foregroundColor(.yellow)
                        Text("Video yüklenemedi")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding()
                }
            }
        }
    }
    
    private func configurePlayer(with url: URL) {
        guard loadedURL != url else { return }
        loadedURL = url
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .pause
        self.player = player
    }
}
