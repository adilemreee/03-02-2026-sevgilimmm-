//
//  AddStoryView.swift
//  sevgilim
//

import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

struct AddStoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var videoPlayer: AVPlayer?
    @State private var selectedVideoDuration: Double?
    @State private var showingImagePicker = false
    @State private var showingCamera = false
    @State private var showingVideoPicker = false
    @State private var showingSourceOptions = false
    @State private var showingEditor = false
    @StateObject private var uploadState = UploadState(message: "Story yükleniyor...")
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.3),
                        themeManager.currentTheme.secondaryColor.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Header
                    HStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 24))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Story Ekle")
                                .font(.title3)
                                .fontWeight(.bold)
                            
                            Text("24 saat görünür olacak")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    // Image or Video Preview
                    if let image = selectedImage {
                        mediaPreview(image: image)
                        Spacer()
                        shareButton
                    } else if selectedVideoURL != nil {
                        mediaPreview(image: nil)
                        Spacer()
                        shareButton
                    } else {
                        Spacer()
                        
                        VStack(spacing: 20) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 80))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [
                                            themeManager.currentTheme.primaryColor,
                                            themeManager.currentTheme.secondaryColor
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .opacity(0.6)
                            
                            Text("Fotoğraf veya Video Seç")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Story olarak paylaşmak istediğin fotoğrafı ya da videoyu ekle")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            VStack(spacing: 12) {
                                HStack(spacing: 12) {
                                    Button(action: { showingCamera = true }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 24))
                                            Text("Kamera")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(themeManager.currentTheme.primaryColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                    
                                    Button(action: { showingImagePicker = true }) {
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 24))
                                            Text("Fotoğraf")
                                                .font(.subheadline)
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(themeManager.currentTheme.secondaryColor)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    }
                                }
                                
                                Button(action: { showingVideoPicker = true }) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 24))
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Video")
                                                .font(.subheadline)
                                                .fontWeight(.semibold)
                                            Text("Maksimum 50 MB")
                                                .font(.caption)
                                                .foregroundColor(.white.opacity(0.75))
                                        }
                                        Spacer()
                                    }
                                    .foregroundColor(.white)
                                    .padding(.vertical, 16)
                                    .padding(.horizontal, 20)
                                    .background(Color.purple.opacity(0.8))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                            .padding(.horizontal, 32)
                        }
                        
                        Spacer()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("İptal")
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .fullScreenCover(isPresented: $showingCamera) {
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    CameraPicker(image: $selectedImage)
                        .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showingVideoPicker) {
                VideoPicker(videoURL: $selectedVideoURL)
            }
            .confirmationDialog("Fotoğraf Seç", isPresented: $showingSourceOptions) {
                Button("Kamera") {
                    showingCamera = true
                }
                Button("Galeri") {
                    showingImagePicker = true
                }
                Button("İptal", role: .cancel) { }
            }
            .onChange(of: selectedImage) { _, newImage in
                if newImage != nil {
                    selectedVideoURL = nil
                    clearVideoSelection()
                }
            }
            .onChange(of: selectedVideoURL) { _, newURL in
                if let url = newURL {
                    selectedImage = nil
                    setupVideoSelection(with: url)
                } else {
                    clearVideoSelection()
                }
            }
            .overlay(UploadStatusOverlay(state: uploadState))
            .alert(
                "Hata",
                isPresented: Binding(
                    get: { uploadState.errorMessage != nil },
                    set: { if !$0 { uploadState.errorMessage = nil } }
                )
            ) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(uploadState.errorMessage ?? "")
            }
            // Editör sayfasını buradan açıyoruz
            .sheet(isPresented: $showingEditor) {
                if selectedImage != nil {
                    StoryEditorView(image: $selectedImage)
                }
            }
            .onDisappear {
                clearVideoSelection()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    @ViewBuilder
    private var shareButton: some View {
        Button(action: uploadStory) {
            HStack {
                if uploadState.isUploading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "paperplane.fill")
                    Text("Story'yi Paylaş")
                }
            }
            .frame(maxWidth: .infinity)
            .font(.headline)
            .foregroundColor(.white)
            .padding(.vertical, 14)
            .background(themeManager.currentTheme.primaryColor)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(uploadState.isUploading)
        .opacity(uploadState.isUploading ? 0.6 : 1.0)
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private func mediaPreview(image: UIImage?) -> some View {
        VStack(spacing: 16) {
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                } else if let player = videoPlayer {
                    VideoPlayer(player: player)
                        .frame(maxHeight: 500)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                        .onAppear {
                            player.seek(to: .zero)
                            player.play()
                        }
                } else {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.black.opacity(0.15))
                        .frame(maxHeight: 500)
                }
                
                // Overlay buttons
                VStack {
                    HStack(spacing: 12) {
                        Spacer()
                        
                        if image != nil {
                            Button(action: { showingSourceOptions = true }) {
                                Image(systemName: "photo.badge.plus")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .disabled(uploadState.isUploading)
                            
                            Button(action: { showingEditor = true }) {
                                Image(systemName: "pencil.and.outline")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .disabled(uploadState.isUploading)
                        } else {
                            Button(action: { showingVideoPicker = true }) {
                                Image(systemName: "arrow.triangle.2.circlepath.video")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .disabled(uploadState.isUploading)
                            
                            Button(action: {
                                selectedVideoURL = nil
                                clearVideoSelection()
                            }) {
                                Image(systemName: "trash")
                                    .font(.system(size: 18))
                                    .foregroundColor(.white)
                                    .frame(width: 40, height: 40)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .disabled(uploadState.isUploading)
                        }
                    }
                    .padding(.top, 12)
                    .padding(.trailing, 20)
                    
                    Spacer()
                    
                    if image == nil {
                        HStack {
                            Label("Video", systemImage: "video.fill")
                                .font(.footnote.bold())
                                .foregroundColor(.white)
                            
                            if let durationText = formattedVideoDuration {
                                Text(durationText)
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.85))
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(
                            LinearGradient(
                                colors: [.black.opacity(0.65), .clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    private func setupVideoSelection(with url: URL) {
        clearVideoSelection()
        videoPlayer = AVPlayer(url: url)
        videoPlayer?.actionAtItemEnd = .pause
        videoPlayer?.seek(to: .zero)
        selectedVideoDuration = videoDuration(for: url)
    }
    
    private func clearVideoSelection() {
        videoPlayer?.pause()
        videoPlayer = nil
        selectedVideoDuration = nil
    }
    
    private func videoDuration(for url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return duration.isFinite ? duration : nil
    }
    
    private var formattedVideoDuration: String? {
        guard let duration = selectedVideoDuration else { return nil }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    // MARK: - Upload Story
    private func uploadStory() {
        guard let currentUser = authService.currentUser,
              let userId = currentUser.id,
              let relationshipId = currentUser.relationshipId else {
            uploadState.fail(with: "Kullanıcı bilgileri alınamadı")
            return
        }
        
        if selectedImage == nil && selectedVideoURL == nil {
            uploadState.fail(with: "Lütfen bir fotoğraf veya video seçin.")
            return
        }
        
        if selectedImage != nil && selectedVideoURL != nil {
            uploadState.fail(with: "Aynı anda yalnızca bir medya seçebilirsin.")
            return
        }
        
        let isVideo = selectedVideoURL != nil
        uploadState.start(message: isVideo ? "Video story yükleniyor..." : "Story yükleniyor...")
        
        Task {
            do {
                _ = try await storyService.uploadStory(
                    relationshipId: relationshipId,
                    userId: userId,
                    userName: currentUser.name,
                    userPhotoURL: currentUser.profileImageURL,
                    image: selectedImage,
                    videoURL: selectedVideoURL
                )
                
                await MainActor.run {
                    uploadState.finish()
                    selectedImage = nil
                    selectedVideoURL = nil
                    clearVideoSelection()
                    dismiss()
                }
            } catch {
                let message: String
                if let storyError = error as? StoryService.StoryUploadError {
                    switch storyError {
                    case .invalidMedia:
                        message = "Medya seçimi geçersiz. Lütfen tekrar dene."
                    case .mediaTooLarge:
                        message = "Video 50 MB'den küçük olmalı."
                    }
                } else {
                    message = "Story yüklenirken hata oluştu: \(error.localizedDescription)"
                }
                
                await MainActor.run {
                    uploadState.fail(with: message)
                }
            }
        }
    }
}
