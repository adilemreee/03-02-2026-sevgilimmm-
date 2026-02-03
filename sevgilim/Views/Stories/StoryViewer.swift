//
//  StoryViewer.swift
//  sevgilim
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct StoryViewer: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    let stories: [Story] // Görüntülenecek story'ler (user + partner)
    let startIndex: Int
    
    @State private var currentIndex: Int
    @State private var progress: CGFloat = 0
    @State private var timer: Timer?
    @State private var isPaused = false
    @State private var cachedImage: UIImage?
    @State private var isLoading = true
    @State private var videoPlayer: AVPlayer?
    @State private var videoTimeObserver: Any?
    @State private var videoEndObserver: NSObjectProtocol?
    @State private var dragOffset: CGFloat = 0
    @State private var showingDeleteAlert = false
    @State private var showingAddStory = false
    @State private var showingMessageInput = false
    @State private var messageText = ""
    @State private var isVideoReady = false
    @State private var showVideoPlaceholder = false
    @State private var videoPlaceholderTask: Task<Void, Never>?
    @State private var videoLoadStartTime: Date? = nil
    
    private let photoDuration: TimeInterval = 5 // Fotoğraflar için 5 saniye
    
    private var currentMediaDuration: TimeInterval {
        guard let story = currentStory else { return photoDuration }
        
        if story.isVideo {
            if let duration = story.duration, duration.isFinite, duration > 0 {
                return min(max(duration, 3), 60)
            }
            
            if let player = videoPlayer,
               let item = player.currentItem {
                let duration = CMTimeGetSeconds(item.duration)
                if duration.isFinite, duration > 0 {
                    return min(max(duration, 3), 60)
                }
            }
            
            return 10 // Varsayılan video süresi
        } else {
            return photoDuration
        }
    }
    
    init(stories: [Story], startIndex: Int = 0) {
        self.stories = stories
        self.startIndex = startIndex
        _currentIndex = State(initialValue: startIndex)
    }
    
    var currentStory: Story? {
        guard currentIndex < stories.count else { return nil }
        let storyId = stories[currentIndex].id
        
        // StoryService'ten güncel story'yi al (beğeni güncellemeleri için)
        let allStories = storyService.userStories + storyService.partnerStories
        if let updatedStory = allStories.first(where: { $0.id == storyId }) {
            return updatedStory
        }
        
        // Bulunamazsa orijinal story'yi döndür
        return stories[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if stories.isEmpty {
                // Hiç story yok
                VStack(spacing: 20) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("Story bulunamadı")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Button("Kapat") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                }
            } else if let story = currentStory {
                // Story Content
                ZStack {
                    if story.isVideo {
                        ZStack {
                            Color.black
                            
                            if let player = videoPlayer {
                                StoryVideoPlayer(player: player)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .opacity(isVideoReady ? 1 : 0)
                                    .onAppear {
                                        if !isPaused {
                                            player.play()
                                        }
                                    }
                                    .onDisappear {
                                        player.pause()
                                    }
                            }
                            
                            if let image = cachedImage, showVideoPlaceholder {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                        }
                    } else if let image = cachedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if isLoading {
                        Color.black
                    } else {
                        Color.black
                    }
                    
                    if isLoading {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.5)
                    }
                    
                    // Gradient Overlay (üst ve alt)
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [.black.opacity(0.6), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 150)
                        
                        Spacer()
                        
                        LinearGradient(
                            colors: [.clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                    }
                    .allowsHitTesting(false)
                    
                    // Top Content (Progress + Header)
                    VStack(spacing: 8) {
                        // Progress Bars
                        HStack(spacing: 4) {
                            ForEach(0..<stories.count, id: \.self) { index in
                                GeometryReader { geometry in
                                    ZStack(alignment: .leading) {
                                        // Background
                                        Rectangle()
                                            .fill(.white.opacity(0.3))
                                        
                                        // Progress
                                        Rectangle()
                                            .fill(.white)
                                            .frame(width: progressWidth(for: index, geometry: geometry))
                                    }
                                }
                                .frame(height: 2)
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        
                        // Header (Avatar + Name + Time)
                        HStack(spacing: 12) {
                            // Avatar - Cached
                            CachedAvatarView(photoURL: story.createdByPhotoURL, size: 36)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(story.createdByName)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Text(story.timeAgoText)
                                    .font(.system(size: 12))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            Spacer()
                            
                            // Beğeni Göstergesi (kendi story'inde partner beğendiyse)
                            if story.createdBy == authService.currentUser?.id,
                               let likedBy = story.likedBy, !likedBy.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.red)
                                    Text("\(likedBy.count)")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.ultraThinMaterial)
                                .clipShape(Capsule())
                            }
                            
                            // Add Story Button (only for own stories)
                            if story.createdBy == authService.currentUser?.id {
                                Button(action: { 
                                    showingAddStory = true
                                }) {
                                    Image(systemName: "plus.circle.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Delete Button (only for own stories)
                            if story.createdBy == authService.currentUser?.id {
                                Button(action: { 
                                    showingDeleteAlert = true
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 32, height: 32)
                                        .background(.ultraThinMaterial)
                                        .clipShape(Circle())
                                }
                            }
                            
                            // Close Button
                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(width: 32, height: 32)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                        }
                        .padding(.horizontal, 16)
                        
                        Spacer()
                    }
                    .zIndex(1) // Butonlar en üstte
                    
                    // Bottom Content (Beğeni Butonları)
                    VStack {
                        Spacer()
                        
                        // Alt Bar - Instagram tarzı
                        if story.createdBy != authService.currentUser?.id {
                            HStack(spacing: 12) {
                                // Mesaj Input (Aktif)
                                Button(action: {
                                    showingMessageInput = true
                                    pauseTimer()
                                }) {
                                    HStack {
                                        Text("Mesaj gönder")
                                            .foregroundColor(.white.opacity(0.7))
                                            .font(.system(size: 15))
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(25)
                                }
                                
                                // Beğeni Butonu
                                Button(action: {
                                    handleLikeToggle()
                                }) {
                                    Image(systemName: story.isLikedBy(userId: authService.currentUser?.id ?? "") ? "heart.fill" : "heart")
                                        .font(.system(size: 28, weight: .regular))
                                        .foregroundColor(story.isLikedBy(userId: authService.currentUser?.id ?? "") ? .red : .white)
                                }
                                
                                // Paylaş Butonu (Devre dışı)
                                Image(systemName: "paperplane")
                                    .font(.system(size: 26, weight: .regular))
                                    .foregroundColor(.white.opacity(0.4))
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20) // SafeArea için daha az padding
                        } else {
                            // Kendi Story'miz için Footer (Görüldü Göstergesi)
                            HStack(spacing: 16) {
                                // Görülme Durumu Göstergesi
                                let partnerId = storyService.partnerStories.first?.createdBy ?? ""
                                HStack(spacing: 6) {
                                    Image(systemName: story.isViewedByPartner(partnerId: partnerId) ? "eye.fill" : "eye.slash")
                                        .font(.system(size: 18))
                                        .foregroundColor(story.isViewedByPartner(partnerId: partnerId) ? .white : .white.opacity(0.5))
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        if story.isViewedByPartner(partnerId: partnerId) {
                                            if let viewTime = story.viewedAtTime(userId: partnerId) {
                                                Text("Görüldü")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                                Text(viewTime.timeAgoShort + " önce")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.7))
                                            } else {
                                                Text("Görüldü")
                                                    .font(.system(size: 14, weight: .medium))
                                                    .foregroundColor(.white)
                                            }
                                        } else {
                                            Text("Henüz görülmedi")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white.opacity(0.6))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(.ultraThinMaterial)
                                .cornerRadius(20)
                                
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 20)
                        }
                    }
                    .zIndex(1)
                    
                    // Tap Areas (Left = Previous, Right = Next) - Sadece orta alanda
                    VStack(spacing: 0) {
                        // Üst kısım boş (butonların alanı)
                        Color.clear
                            .frame(height: 100)
                            .allowsHitTesting(false)
                        
                        // Orta kısım - Tap Areas
                        HStack(spacing: 0) {
                            // Left Tap Area (Previous)
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    previousStory()
                                }
                                .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                                    if pressing {
                                        pauseTimer()
                                    } else {
                                        resumeTimer()
                                    }
                                }, perform: {})
                            
                            // Right Tap Area (Next)
                            Rectangle()
                                .fill(.clear)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    nextStory()
                                }
                                .onLongPressGesture(minimumDuration: 0.2, pressing: { pressing in
                                    if pressing {
                                        pauseTimer()
                                    } else {
                                        resumeTimer()
                                    }
                                }, perform: {})
                        }
                        
                        // Alt kısım boş (beğeni butonunun alanı)
                        Color.clear
                            .frame(height: 100)
                            .allowsHitTesting(false)
                    }
                }
                .offset(x: dragOffset)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            // Eğer çok az hareket varsa (10 piksel altı), long press olarak say
                            if abs(value.translation.width) < 10 && abs(value.translation.height) < 10 {
                                pauseTimer()
                            } else {
                                // Normal drag
                                dragOffset = value.translation.width
                                pauseTimer()
                            }
                        }
                        .onEnded { value in
                            if value.translation.width < -100 {
                                nextStory()
                            } else if value.translation.width > 100 {
                                previousStory()
                            }
                            dragOffset = 0
                            resumeTimer()
                        }
                )
            } else {
                // currentStory nil - bu olmamalı
                VStack(spacing: 20) {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                    
                    Text("Story yükleniyor...")
                        .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            prepareForCurrentStory()
            markAsViewed()
        }
        .onDisappear {
            stopTimer()
            resetVideoPlayer()
        }
        .onChange(of: currentIndex) { _, _ in
            prepareForCurrentStory()
            markAsViewed()
        }
        .alert("Story'yi Sil", isPresented: $showingDeleteAlert) {
            Button("İptal", role: .cancel) { }
            Button("Sil", role: .destructive) {
                deleteCurrentStory()
            }
        } message: {
            Text("Bu story'yi silmek istediğinizden emin misiniz?")
        }
        .sheet(isPresented: $showingAddStory) {
            AddStoryView()
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .onChange(of: showingAddStory) { _, newValue in
            if newValue {
                pauseTimer()
            } else {
                resumeTimer()
            }
        }
        .sheet(isPresented: $showingMessageInput) {
            MessageReplySheet(
                storyOwnerName: currentStory?.createdByName ?? "Kullanıcı",
                messageText: $messageText,
                onSend: {
                    sendMessageToChat()
                    showingMessageInput = false
                    resumeTimer()
                },
                onCancel: {
                    showingMessageInput = false
                    messageText = ""
                    resumeTimer()
                }
            )
            .presentationDetents([.height(200)])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showingDeleteAlert) { _, newValue in
            if newValue {
                pauseTimer()
            } else {
                resumeTimer()
            }
        }
        .statusBar(hidden: true)
    }
    
    // MARK: - Preparation
    private func prepareForCurrentStory() {
        stopTimer()
        resetVideoPlayer()
        isPaused = false
        progress = 0
        isVideoReady = false
        showVideoPlaceholder = false
        videoPlaceholderTask?.cancel()
        videoPlaceholderTask = nil
        videoLoadStartTime = nil
        loadCurrentStory()
    }
    
    // MARK: - Progress Width
    private func progressWidth(for index: Int, geometry: GeometryProxy) -> CGFloat {
        if index < currentIndex {
            return geometry.size.width // Completed
        } else if index == currentIndex {
            return geometry.size.width * progress // Current
        } else {
            return 0 // Not started
        }
    }
    
    // MARK: - Send Message to Chat
    private func sendMessageToChat() {
        guard let story = currentStory,
              let currentUser = authService.currentUser,
              let relationshipId = currentUser.relationshipId,
              let senderId = currentUser.id,
              !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        let trimmedMessage = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        let storyContext = "📸 Story'ye yanıt verdi"
        let fullMessage = "\(storyContext)\n\(trimmedMessage)"
        
        Task {
            do {
                // MessageService kullanarak mesaj gönder (story thumbnail ile)
                let messageService = MessageService()
                try await messageService.sendMessage(
                    relationshipId: relationshipId,
                    senderId: senderId,
                    senderName: currentUser.name,
                    text: fullMessage,
                    storyImageURL: story.thumbnailURL
                )
                
                await MainActor.run {
                    messageText = ""
                }
            } catch {
                print("❌ Story yanıtı gönderilemedi: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Timer Functions
    private func startTimer() {
        if isLoading && currentStory?.isVideo != true { return }
        stopTimer()
        
        if currentStory?.isVideo == true {
            startVideoProgress()
            return
        }
        
        timer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            if !isPaused {
                let duration = max(currentMediaDuration, 0.1)
                progress += 0.05 / duration
                
                if progress >= 1.0 {
                    nextStory()
                }
            }
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        removeVideoObservers()
    }
    
    private func pauseTimer() {
        isPaused = true
        videoPlayer?.pause()
    }
    
    private func resumeTimer() {
        isPaused = false
        if currentStory?.isVideo == true {
            videoPlayer?.play()
        }
    }
    
    // MARK: - Navigation
    private func nextStory() {
        if currentIndex < stories.count - 1 {
            currentIndex += 1
            progress = 0
        } else {
            dismiss()
        }
    }
    
    private func previousStory() {
        if currentIndex > 0 {
            currentIndex -= 1
            progress = 0
        }
    }
    
    // MARK: - Load Story
    private func loadCurrentStory() {
        guard let story = currentStory else {
            cachedImage = nil
            isLoading = false
            showVideoPlaceholder = false
            videoPlaceholderTask?.cancel()
            videoPlaceholderTask = nil
            videoLoadStartTime = nil
            return
        }
        
        isLoading = true
        cachedImage = nil
        let targetStoryId = story.id
        
        if story.isVideo {
            isVideoReady = false
            showVideoPlaceholder = false
            videoPlaceholderTask?.cancel()
            videoLoadStartTime = Date()
            let placeholderStoryId = targetStoryId
            videoPlaceholderTask = Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                if Task.isCancelled { return }
                await MainActor.run {
                    guard placeholderStoryId == currentStory?.id else { return }
                    guard !isVideoReady else { return }
                    if let start = videoLoadStartTime, Date().timeIntervalSince(start) >= 0.5 {
                        showVideoPlaceholder = true
                    }
                    videoPlaceholderTask = nil
                }
            }
            if let thumbnailURL = story.thumbnailURL {
                Task {
                    if let image = try? await ImageCacheService.shared.loadImage(from: thumbnailURL, thumbnail: false) {
                        await MainActor.run {
                            guard targetStoryId == currentStory?.id else { return }
                            cachedImage = image
                        }
                    }
                }
            }
            
            Task {
                var playbackURL: URL?
                
                do {
                    playbackURL = try await VideoCacheService.shared.cachedURL(for: story.photoURL)
                } catch {
                    print("❌ Video önbelleğe alınamadı: \(error.localizedDescription)")
                    playbackURL = URL(string: story.photoURL)
                }
                
                guard let preparedURL = playbackURL else {
                    await MainActor.run {
                        guard targetStoryId == currentStory?.id else { return }
                        isLoading = false
                        isVideoReady = false
                        showVideoPlaceholder = false
                        videoPlaceholderTask?.cancel()
                        videoPlaceholderTask = nil
                        videoLoadStartTime = nil
                    }
                    return
                }
                
                let needsThumbnail = await MainActor.run {
                    cachedImage == nil
                }
                
                if needsThumbnail {
                    if let generatedThumbnail = await generateLocalThumbnail(for: preparedURL) {
                        await MainActor.run {
                            guard targetStoryId == currentStory?.id else { return }
                            cachedImage = generatedThumbnail
                        }
                    }
                }
                
                let asset = AVURLAsset(url: preparedURL)
                let playerItem = AVPlayerItem(asset: asset)
                playerItem.preferredForwardBufferDuration = 0
                let player = AVPlayer(playerItem: playerItem)
                player.actionAtItemEnd = .pause
                player.automaticallyWaitsToMinimizeStalling = false
                if #available(iOS 17.0, *) {
                    _ = await player.seek(to: .zero)
                } else {
                    await player.seek(to: .zero)
                }
                
                await MainActor.run {
                    guard targetStoryId == currentStory?.id else { return }
                    videoPlayer = player
                    progress = 0
                    startTimer()
                }
            }
        } else {
            showVideoPlaceholder = false
            videoPlaceholderTask?.cancel()
            videoPlaceholderTask = nil
            videoLoadStartTime = nil
            Task {
                do {
                    let image = try await ImageCacheService.shared.loadImage(from: story.photoURL, thumbnail: false)
                    await MainActor.run {
                        guard targetStoryId == currentStory?.id else { return }
                        cachedImage = image
                        isLoading = false
                        isVideoReady = false
                        progress = 0
                        startTimer()
                    }
                } catch {
                    print("❌ Story resmi yüklenemedi: \(error.localizedDescription)")
                    await MainActor.run {
                        guard targetStoryId == currentStory?.id else { return }
                        cachedImage = nil
                        isLoading = false
                        isVideoReady = false
                        progress = 0
                        startTimer()
                    }
                }
            }
        }
    }
    
    private func startVideoProgress() {
        guard let player = videoPlayer else { return }
        
        removeVideoObservers()
        progress = 0
        
        if player.currentItem?.status == .readyToPlay && !isVideoReady {
            videoPlaceholderTask?.cancel()
            videoPlaceholderTask = nil
            showVideoPlaceholder = false
            isVideoReady = true
            isLoading = false
            videoLoadStartTime = nil
        }
        
        let duration = max(currentMediaDuration, 0.1)
        let interval = CMTime(seconds: 0.05, preferredTimescale: 600)
        
        videoTimeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            if self.isPaused { return }
            
            let elapsed = CMTimeGetSeconds(time)
            if elapsed.isFinite, duration > 0 {
                if !self.isVideoReady {
                    self.videoPlaceholderTask?.cancel()
                    self.videoPlaceholderTask = nil
                    self.showVideoPlaceholder = false
                    self.isVideoReady = true
                    self.isLoading = false
                    self.videoLoadStartTime = nil
                }
                self.progress = CGFloat(min(elapsed / duration, 1.0))
            }
        }
        
        videoEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            self.videoLoadStartTime = nil
            self.progress = 1.0
            self.nextStory()
        }
        
        if !isPaused {
            player.play()
        }
    }
    
    private func generateLocalThumbnail(for url: URL) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let image = UIImage(cgImage: cgImage)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func removeVideoObservers() {
        if let observer = videoTimeObserver, let player = videoPlayer {
            player.removeTimeObserver(observer)
            videoTimeObserver = nil
        }
        
        if let endObserver = videoEndObserver {
            NotificationCenter.default.removeObserver(endObserver)
            videoEndObserver = nil
        }
    }
    
    private func resetVideoPlayer() {
        if let player = videoPlayer {
            player.pause()
        }
        removeVideoObservers()
        videoPlayer = nil
        isVideoReady = false
        showVideoPlaceholder = false
        videoPlaceholderTask?.cancel()
        videoPlaceholderTask = nil
        videoLoadStartTime = nil
    }
    
    // MARK: - Mark as Viewed
    private func markAsViewed() {
        guard let story = currentStory,
              let userId = authService.currentUser?.id,
              let storyId = story.id,
              !story.isViewedBy(userId: userId) else {
            return
        }
        
        Task {
            try? await storyService.markStoryAsViewed(storyId: storyId, userId: userId)
        }
    }
    
    // MARK: - Delete Story
    private func deleteCurrentStory() {
        guard let story = currentStory,
              let storyId = story.id else {
            return
        }
        
        Task {
            do {
                try await storyService.deleteStory(storyId: storyId)
                
                await MainActor.run {
                    // Eğer başka story varsa ona geç, yoksa kapat
                    if stories.count > 1 {
                        if currentIndex < stories.count - 1 {
                            // Sonraki story'ye geç
                            nextStory()
                        } else if currentIndex > 0 {
                            // Önceki story'ye geç
                            previousStory()
                        } else {
                            // Tek story vardı, kapat
                            dismiss()
                        }
                    } else {
                        // Son story'ydi, kapat
                        dismiss()
                    }
                }
            } catch {
                print("❌ Story silinemedi: \(error.localizedDescription)")
            }
        }
    }
    
    // Beğeni Toggle (Butondan)
    private func handleLikeToggle() {
        guard let story = currentStory,
              let userId = authService.currentUser?.id else { return }
        
        // Firebase'de beğeni durumunu değiştir
        Task {
            do {
                try await storyService.toggleLike(storyId: story.id ?? "", userId: userId)
            } catch {
                print("❌ Beğeni güncellenemedi: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Cached Avatar View
struct CachedAvatarView: View {
    let photoURL: String?
    let size: CGFloat
    
    @State private var cachedImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: size, height: size)
                    .overlay {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .font(.system(size: size * 0.5))
                        }
                    }
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let photoURL = photoURL else {
            isLoading = false
            return
        }
        
        Task {
            do {
                let image = try await ImageCacheService.shared.loadImage(from: photoURL, thumbnail: true)
                await MainActor.run {
                    cachedImage = image
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                }
            }
        }
    }
}

// MARK: - Story Video Player (No Controls)
private struct StoryVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerView {
        let view = PlayerView()
        view.playerLayer.player = player
        view.isUserInteractionEnabled = false
        return view
    }
    
    func updateUIView(_ uiView: PlayerView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.playerLayer.player = player
        }
    }
    
    final class PlayerView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        
        var playerLayer: AVPlayerLayer {
            layer as! AVPlayerLayer
        }
        
        override init(frame: CGRect) {
            super.init(frame: frame)
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
            isUserInteractionEnabled = false
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            playerLayer.videoGravity = .resizeAspect
            playerLayer.backgroundColor = UIColor.black.cgColor
            isUserInteractionEnabled = false
        }
    }
}

// MARK: - Message Reply Sheet
struct MessageReplySheet: View {
    let storyOwnerName: String
    @Binding var messageText: String
    let onSend: () -> Void
    let onCancel: () -> Void
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("\(storyOwnerName)'e yanıt ver")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            // Message Input
            HStack(spacing: 12) {
                TextField("Mesajınızı yazın...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    .focused($isTextFieldFocused)
                    .lineLimit(3)
                
                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .font(.title2)
                        .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
}
