//
//  MemoriesView.swift
//  sevgilim
//

import SwiftUI

struct MemoriesView: View {
    @EnvironmentObject var memoryService: MemoryService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddMemory = false
    @State private var selectedMemory: Memory?
    @State private var sortOption: MemorySortOption = .newest
    
    enum MemorySortOption: String, CaseIterable {
        case newest = "En Yeni"
        case oldest = "En Eski"
        case alphabetical = "A-Z"
    }
    
    private var sortedMemories: [Memory] {
        switch sortOption {
        case .newest:
            return memoryService.memories.sorted { $0.date > $1.date }
        case .oldest:
            return memoryService.memories.sorted { $0.date < $1.date }
        case .alphabetical:
            return memoryService.memories.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.3),
                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Compact Header
                HStack(spacing: 12) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Anılarımız")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Birlikte yaşadığımız güzel anlar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                
                Picker("", selection: $sortOption) {
                    ForEach(MemorySortOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                
                // Content
                if memoryService.memories.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("Henüz anı yok")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Güzel anlarınızı kaydetmeye başlayın")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: { showingAddMemory = true }) {
                            Label("İlk Anıyı Ekle", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(themeManager.currentTheme.primaryColor)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(sortedMemories) { memory in
                                MemoryCardModern(memory: memory)
                                    .onTapGesture {
                                        selectedMemory = memory
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .overlay(alignment: .top) {
                        if memoryService.isLoading {
                            ProgressView()
                                .padding()
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddMemory = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(themeManager.currentTheme.primaryColor)
                            .clipShape(Circle())
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingAddMemory) {
            AddMemoryView()
        }
        .sheet(item: $selectedMemory) { memory in
            MemoryDetailView(memory: memory)
        }
        .onAppear {
            // Listener is handled by MainTabView
        }
    }
}


// Modern Memory Card
struct MemoryCardModern: View {
    let memory: Memory
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var memoryService: MemoryService
    
    @State private var isProcessingLike = false
    
    private var isLiked: Bool {
        guard let userId = authService.currentUser?.id else { return false }
        return memory.likes.contains(userId)
    }
    
    private var likeCountText: String {
        memory.likes.count == 0 ? "Beğeni yok" : "\(memory.likes.count)"
    }
    
    private var commentCountText: String {
        memory.comments.count == 0 ? "Yorum yok" : "\(memory.comments.count)"
    }
    
    private func toggleLike() {
        guard !isProcessingLike,
              let userId = authService.currentUser?.id else { return }
        
        isProcessingLike = true
        Task {
            defer { Task { @MainActor in self.isProcessingLike = false } }
            do {
                try await memoryService.toggleLike(memory: memory, userId: userId)
            } catch {
                print("❌ Memory like toggle failed: \(error.localizedDescription)")
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundStyle(themeManager.currentTheme.primaryColor)
                    .frame(width: 44, height: 44)
                    .background(themeManager.currentTheme.primaryColor.opacity(0.1))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(memory.date, formatter: DateFormatter.displayFormat)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if let location = memory.location {
                            Text("•")
                                .foregroundColor(.secondary)
                            Label(location, systemImage: "location.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Photo with Caching (Thumbnail)
            if let photoURL = memory.firstPhotoURL {
                CachedAsyncImage(url: photoURL, thumbnail: true) { image, _ in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 200)
                        .clipped()
                        .cornerRadius(12)
                } placeholder: {
                    ZStack {
                        Color.gray.opacity(0.1)
                            .frame(height: 200)
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: themeManager.currentTheme.primaryColor))
                    }
                    .cornerRadius(12)
                }
            }
            
            // Content Preview
            Text(memory.content)
                .font(.body)
                .foregroundColor(.primary)
                .lineLimit(3)
            
            // Tags Preview
            if let tags = memory.tags, !tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(tags.prefix(3), id: \.self) { tag in
                            Text("#\(tag)")
                                .font(.caption)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .cornerRadius(8)
                        }
                        if tags.count > 3 {
                            Text("+\(tags.count - 3)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            // Quick Stats
            HStack(spacing: 24) {
                Button(action: toggleLike) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.subheadline)
                            .foregroundStyle(isLiked ? themeManager.currentTheme.primaryColor : .secondary)
                        Text(likeCountText)
                            .font(.caption)
                            .foregroundStyle(isLiked ? themeManager.currentTheme.primaryColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isProcessingLike)
                
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(commentCountText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            if let firstComment = memory.comments.first {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(firstComment.userName)
                            .font(.caption.bold())
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text(firstComment.createdAt.timeAgo())
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(firstComment.text)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.08))
                )
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

// Memory Detail View
struct MemoryDetailView: View {
    let memory: Memory
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var memoryService: MemoryService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var relationshipService: RelationshipService
    
    @State private var showingDeleteAlert = false
    @State private var showingEditMemory = false
    @State private var showingComments = false
    @State private var commentText = ""
    @State private var isSubmittingComment = false
    @State private var commentError: String?
    @State private var isShowingPhotoViewer = false
    @State private var photoViewerIndex = 0
    @State private var commentToDelete: Comment?
    @State private var isDeletingComment = false
    @State private var partnerUser: User?
    @StateObject private var singlePhotoService = PhotoService()
    
    // Get current memory from service for live updates
    private var currentMemory: Memory {
        memoryService.memories.first(where: { $0.id == memory.id }) ?? memory
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photos Carousel
                    if !currentMemory.allPhotoURLs.isEmpty {
                        TabView {
                            ForEach(Array(currentMemory.allPhotoURLs.enumerated()), id: \.offset) { index, photoURL in
                                Button {
                                    let photos = currentMemory.allPhotoURLs.map { url in
                                        Photo(
                                            id: "\(currentMemory.id ?? "")_\(url.hashValue)",
                                            relationshipId: currentMemory.relationshipId,
                                            imageURL: url,
                                            thumbnailURL: url,
                                            videoURL: nil,
                                            title: currentMemory.title,
                                            date: currentMemory.date,
                                            location: currentMemory.location,
                                            tags: currentMemory.tags,
                                            uploadedBy: currentMemory.createdBy,
                                            createdAt: currentMemory.createdAt,
                                            mediaType: .photo,
                                            duration: nil
                                        )
                                    }
                                    singlePhotoService.photos = photos
                                    photoViewerIndex = index
                                    isShowingPhotoViewer = true
                                } label: {
                                    CachedAsyncImage(url: photoURL, thumbnail: false) { image, _ in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(height: 300)
                                            .clipped()
                                    } placeholder: {
                                        ZStack {
                                            Color.gray.opacity(0.1)
                                            ProgressView()
                                        }
                                        .frame(height: 300)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: currentMemory.allPhotoURLs.count > 1 ? .automatic : .never))
                        .frame(height: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            // Fotoğraf sayısı göstergesi
                            currentMemory.allPhotoURLs.count > 1 ?
                            Text("\(currentMemory.allPhotoURLs.count) fotoğraf")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                                .padding(8)
                            : nil,
                            alignment: .topTrailing
                        )
                    }
                    
                    // Title
                    Text(currentMemory.title)
                        .font(.title.bold())
                    
                    // Date and Location
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "calendar")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Text(currentMemory.date, formatter: DateFormatter.displayFormat)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        if let location = currentMemory.location {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Tags
                    if let tags = currentMemory.tags, !tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(tags, id: \.self) { tag in
                                    Text("#\(tag)")
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                        .cornerRadius(8)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    // Content
                    Text(currentMemory.content)
                        .font(.body)
                    
                    Divider()
                    
                    // Actions
                    HStack(spacing: 30) {
                        Button(action: toggleLike) {
                            VStack {
                                Image(systemName: isLiked ? "heart.fill" : "heart")
                                    .font(.title2)
                                    .foregroundStyle(isLiked ? themeManager.currentTheme.primaryColor : .secondary)
                                Text("\(currentMemory.likes.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button(action: { showingComments.toggle() }) {
                            VStack {
                                Image(systemName: "bubble.left")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                                Text("\(currentMemory.comments.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    
                    // Comments Section
                    if showingComments {
                        VStack(alignment: .leading, spacing: 15) {
                            Text("Yorumlar")
                                .font(.headline)
                                .padding(.horizontal, 4)
                            
                            if let commentError {
                                Text(commentError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 4)
                            }
                            
                            VStack(spacing: 12) {
                                if currentMemory.comments.isEmpty {
                                    Text("Henüz yorum yok")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .center)
                                        .padding(.vertical, 20)
                                } else {
                                    ForEach(currentMemory.comments) { comment in
                                        let isCurrentUser = comment.userId == authService.currentUser?.id
                                        ModernCommentRow(
                                            comment: comment,
                                            isCurrentUser: isCurrentUser,
                                            profileImageURL: isCurrentUser ? 
                                                authService.currentUser?.profileImageURL : 
                                                partnerUser?.profileImageURL,
                                            onDelete: { commentToDelete = comment },
                                            canDelete: canDeleteComment(comment)
                                        )
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: currentMemory.comments.count)
                            
                            // Add Comment
                            ModernCommentInput(
                                text: $commentText,
                                isSubmitting: $isSubmittingComment,
                                onSubmit: addComment
                            )
                            .padding(.top, 8)
                        }
                    }
                }
                .padding()
        }
        .navigationTitle("Anı Detayı")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Kapat") {
                    dismiss()
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                Button {
                    showingEditMemory = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(themeManager.currentTheme.primaryColor)
                }
                
                Button(role: .destructive) {
                    showingDeleteAlert = true
                } label: {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .sheet(isPresented: $showingEditMemory) {
            EditMemoryView(memory: currentMemory)
        }
        .onDisappear {
            singlePhotoService.photos = []
        }
        .task {
            // Fetch partner profile on load if not already loaded
            if partnerUser == nil, 
               let currentUserId = authService.currentUser?.id,
               let relationship = relationshipService.currentRelationship {
                let partnerId = relationship.user1Id == currentUserId ? relationship.user2Id : relationship.user1Id
                if !partnerId.isEmpty {
                    do {
                        partnerUser = try await authService.getUserProfile(userId: partnerId)
                    } catch {
                        print("Failed to fetch partner profile: \(error)")
                    }
                }
            }
        }
        // ... (Keep confirmation dialog and full screen cover)
        .confirmationDialog(
            "Yorumu Sil",
            isPresented: Binding(
                get: { commentToDelete != nil },
                set: { newValue in
                    if !newValue {
                        commentToDelete = nil
                    }
                }
            ),
            titleVisibility: .visible
        ) {
            Button("Yorumu Sil", role: .destructive) {
                guard let comment = commentToDelete else { return }
                commentToDelete = nil
                deleteComment(comment)
            }
            Button("İptal", role: .cancel) {
                commentToDelete = nil
            }
        } message: {
            Text("Bu yorumu silmek istediğinizden emin misiniz?")
        }
        .fullScreenCover(isPresented: $isShowingPhotoViewer) {
            FullScreenPhotoViewer(currentIndex: $photoViewerIndex) {
                isShowingPhotoViewer = false
            }
            .environmentObject(singlePhotoService)
                .environmentObject(authService)
                .environmentObject(themeManager)
            }
            .alert("Anıyı Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    deleteMemory()
                }
            } message: {
                Text("Bu anıyı silmek istediğinizden emin misiniz? Bu işlem geri alınamaz.")
            }
        }
    }
    
    private var isLiked: Bool {
        guard let userId = authService.currentUser?.id else { return false }
        return currentMemory.likes.contains(userId)
    }
    
    private func canDeleteComment(_ comment: Comment) -> Bool {
        guard let userId = authService.currentUser?.id else { return false }
        return comment.userId == userId || currentMemory.createdBy == userId
    }
    
    private func toggleLike() {
        guard let userId = authService.currentUser?.id else { return }
        Task {
            try? await memoryService.toggleLike(memory: currentMemory, userId: userId)
        }
    }
    
    private func trimmedCommentText() -> String {
        commentText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private func addComment() {
        let text = trimmedCommentText()
        guard !text.isEmpty else {
            commentError = "Yorum boş bırakılamaz."
            return
        }
        
        guard !isSubmittingComment,
              !isDeletingComment,
              let userId = authService.currentUser?.id,
              let userName = authService.currentUser?.name else { return }
        
        let comment = Comment(
            userId: userId,
            userName: userName,
            text: text,
            createdAt: Date()
        )
        
        Task {
            await MainActor.run {
                isSubmittingComment = true
                commentError = nil
            }
            
            do {
                try await memoryService.addComment(memory: currentMemory, comment: comment)
                await MainActor.run {
                    commentText = ""
                }
            } catch {
                await MainActor.run {
                    commentError = "Yorum eklenemedi: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isSubmittingComment = false
            }
        }
    }
    
    private func deleteComment(_ comment: Comment) {
        guard !isDeletingComment else { return }
        
        Task {
            await MainActor.run {
                isDeletingComment = true
                commentError = nil
            }
            
            do {
                try await memoryService.deleteComment(memory: currentMemory, comment: comment)
            } catch {
                await MainActor.run {
                    commentError = "Yorum silinemedi: \(error.localizedDescription)"
                }
            }
            
            await MainActor.run {
                isDeletingComment = false
            }
        }
    }
    
    private func deleteMemory() {
        Task {
            do {
                try await memoryService.deleteMemory(currentMemory)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("❌ Error deleting memory: \(error.localizedDescription)")
            }
        }
    }
}

struct AddMemoryView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var memoryService: MemoryService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var date = Date()
    @State private var location = ""
    @State private var selectedImages: [UIImage] = []  // Çoklu fotoğraf desteği
    @State private var showingImagePicker = false
    @State private var isLoadingPhotos = false  // Fotoğraf yükleme durumu
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @StateObject private var uploadState = UploadState(message: "Anı kaydediliyor...")
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.25),
                        themeManager.currentTheme.secondaryColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        imagePickerSection
                        detailsSection
                        tagsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Yeni Anı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveMemory()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              uploadState.isUploading)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            MultiImagePicker(selectedImages: $selectedImages, maxSelection: 10 - selectedImages.count, isLoadingImages: $isLoadingPhotos)
        }
        .overlay(UploadStatusOverlay(state: uploadState))
        .overlay {
            // Fotoğraf yükleme overlay
            if isLoadingPhotos {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Fotoğraflar yükleniyor...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(radius: 12)
                }
            }
        }
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
    }
    
    private func saveMemory() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else {
            uploadState.fail(with: "Kullanıcı bilgileri alınamadı")
            return
        }
        
        uploadState.start(message: "Anı kaydediliyor...")
        Task {
            do {
                var photoURLs: [String] = []
                
                // Upload all selected images
                for (index, image) in selectedImages.enumerated() {
                    uploadState.update(message: "Fotoğraf yükleniyor (\(index + 1)/\(selectedImages.count))...")
                    let url = try await StorageService.shared.uploadMemoryPhoto(image, relationshipId: relationshipId)
                    photoURLs.append(url)
                }
                
                uploadState.update(message: "Anı kaydediliyor...")
                try await memoryService.addMemory(
                    relationshipId: relationshipId,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    date: date,
                    photoURLs: photoURLs,
                    location: location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : location,
                    tags: tags.isEmpty ? nil : tags,
                    userId: userId
                )
                
                await MainActor.run {
                    uploadState.finish()
                    dismiss()
                }
            } catch {
                print("Error saving memory: \(error)")
                await MainActor.run {
                    uploadState.fail(with: "Anı kaydedilirken hata oluştu: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        tagInput = ""
    }
    
    @ViewBuilder
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Fotoğraflar")
                    .font(.headline)
                Spacer()
                if !selectedImages.isEmpty {
                    Text("\(selectedImages.count)/10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("Anıyı daha özel kılmak için fotoğraflar ekleyebilirsin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if !selectedImages.isEmpty {
                // Seçilen fotoğraflar grid görünümü
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            // Silme butonu
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    _ = selectedImages.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                    
                    // Daha fazla fotoğraf ekle butonu
                    if selectedImages.count < 10 {
                        Button {
                            showingImagePicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                Text("Ekle")
                                    .font(.caption)
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .frame(width: 100, height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            )
                        }
                    }
                }
            } else {
                Button {
                    showingImagePicker = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Fotoğraf eklemek için dokun")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("En fazla 10 fotoğraf")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemBackground).opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                themeManager.currentTheme.primaryColor.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.4, dash: [8, 6])
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Anı Detayları")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Başlık")
                TextField("", text: $title, prompt: Text("Örneğin: İlk konser gecemiz"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Anı")
                ZStack(alignment: .topLeading) {
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Anını tüm detaylarıyla yaz...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                    }
                    contentEditor
                        .frame(minHeight: 160)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Tarih")
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Konum (isteğe bağlı)")
                TextField("", text: $location, prompt: Text("Örneğin: Moda Sahnesi"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Etiketler")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TextField("", text: $tagInput, prompt: Text("Etiket ekle"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                        )
                        .onSubmit(addTag)
                    
                    Button(action: addTag) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryColor)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                if !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                            )
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                } else {
                    Text("Etiketler, anıları kategorize etmenize yardımcı olur. Örneğin: tatil, kutlama, yıldönümü.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var contentEditor: some View {
        if #available(iOS 16.0, *) {
            TextEditor(text: $content)
                .scrollContentBackground(.hidden)
        } else {
            TextEditor(text: $content)
        }
    }
    
    private func detailFieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }
}

struct EditMemoryView: View {
    let memory: Memory
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var memoryService: MemoryService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var title: String
    @State private var content: String
    @State private var date: Date
    @State private var location: String
    @State private var tagInput = ""
    @State private var tags: [String]
    
    // Çoklu fotoğraf desteği
    @State private var existingPhotoURLs: [String]  // Mevcut fotoğraflar (sunucuda)
    @State private var newImages: [UIImage] = []     // Yeni eklenen fotoğraflar
    @State private var removedURLs: [String] = []    // Silinen fotoğrafların URL'leri
    @State private var showingImagePicker = false
    @State private var isLoadingPhotos = false       // Fotoğraf yükleme durumu
    
    private let originalPhotoURLs: [String]
    @StateObject private var uploadState = UploadState(message: "Anı güncelleniyor...")
    
    init(memory: Memory) {
        self.memory = memory
        _title = State(initialValue: memory.title)
        _content = State(initialValue: memory.content)
        _date = State(initialValue: memory.date)
        _location = State(initialValue: memory.location ?? "")
        _tags = State(initialValue: memory.tags ?? [])
        _existingPhotoURLs = State(initialValue: memory.allPhotoURLs)
        self.originalPhotoURLs = memory.allPhotoURLs
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.25),
                        themeManager.currentTheme.secondaryColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        imagePickerSection
                        detailsSection
                        tagsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Anıyı Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Vazgeç") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Güncelle") {
                        saveChanges()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                              uploadState.isUploading)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            MultiImagePicker(selectedImages: $newImages, maxSelection: 10 - existingPhotoURLs.count - newImages.count, isLoadingImages: $isLoadingPhotos)
        }
        .overlay(UploadStatusOverlay(state: uploadState))
        .overlay {
            // Fotoğraf yükleme overlay
            if isLoadingPhotos {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text("Fotoğraflar yükleniyor...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(radius: 12)
                }
            }
        }
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
    }
    
    private func saveChanges() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLocation = location.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedTitle.isEmpty else {
            uploadState.fail(with: "Başlık boş olamaz.")
            return
        }
        
        guard !trimmedContent.isEmpty else {
            uploadState.fail(with: "Anı içeriği boş olamaz.")
            return
        }
        
        uploadState.start(message: "Anı güncelleniyor...")
        
        Task {
            var uploadedNewURLs: [String] = []
            do {
                // 1. Yeni fotoğrafları yükle
                for (index, image) in newImages.enumerated() {
                    uploadState.update(message: "Fotoğraf yükleniyor (\(index + 1)/\(newImages.count))...")
                    let url = try await StorageService.shared.uploadMemoryPhoto(image, relationshipId: memory.relationshipId)
                    uploadedNewURLs.append(url)
                }
                
                // 2. Final URL listesi: mevcut (silinmemiş) + yeni yüklenen
                let finalPhotoURLs = existingPhotoURLs + uploadedNewURLs
                
                let cleanedTags = tags
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                
                uploadState.update(message: "Anı kaydediliyor...")
                try await memoryService.updateMemory(
                    memory,
                    title: trimmedTitle,
                    content: trimmedContent,
                    date: date,
                    photoURLs: finalPhotoURLs,
                    removeAllPhotos: finalPhotoURLs.isEmpty,
                    location: trimmedLocation.isEmpty ? nil : trimmedLocation,
                    tags: cleanedTags.isEmpty ? nil : cleanedTags
                )
                
                // 3. Silinen fotoğrafları arka planda sil
                if !removedURLs.isEmpty {
                    Task.detached(priority: .background) {
                        for url in removedURLs {
                            try? await StorageService.shared.deleteImage(url: url)
                        }
                    }
                }
                
                await MainActor.run {
                    uploadState.finish()
                    dismiss()
                }
            } catch {
                // Hata durumunda yüklenen yeni fotoğrafları sil
                if !uploadedNewURLs.isEmpty {
                    Task.detached(priority: .background) {
                        for url in uploadedNewURLs {
                            try? await StorageService.shared.deleteImage(url: url)
                        }
                    }
                }
                
                await MainActor.run {
                    uploadState.fail(with: "Anı güncellenemedi: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        tagInput = ""
    }
    
    @ViewBuilder
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("Fotoğraflar")
                    .font(.headline)
                Spacer()
                let totalCount = existingPhotoURLs.count + newImages.count
                if totalCount > 0 {
                    Text("\(totalCount)/10")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Text("Fotoğraf ekleyebilir veya mevcut fotoğrafları kaldırabilirsin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            let totalPhotos = existingPhotoURLs.count + newImages.count
            
            if totalPhotos > 0 {
                // Grid görünümü
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                    // Mevcut fotoğraflar (sunucudan)
                    ForEach(Array(existingPhotoURLs.enumerated()), id: \.element) { index, url in
                        ZStack(alignment: .topTrailing) {
                            CachedAsyncImage(url: url, thumbnail: true) { image, _ in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            } placeholder: {
                                ZStack {
                                    Color.gray.opacity(0.1)
                                    ProgressView()
                                }
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Silme butonu
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    removedURLs.append(url)
                                    existingPhotoURLs.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                    
                    // Yeni eklenen fotoğraflar (henüz yüklenmemiş)
                    ForEach(Array(newImages.enumerated()), id: \.offset) { index, image in
                        ZStack(alignment: .topTrailing) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 100, height: 100)
                                .clipped()
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    // "Yeni" badge
                                    Text("Yeni")
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(themeManager.currentTheme.primaryColor)
                                        .foregroundColor(.white)
                                        .cornerRadius(6)
                                        .padding(4),
                                    alignment: .bottomLeading
                                )
                            
                            // Silme butonu
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    _ = newImages.remove(at: index)
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .background(Circle().fill(Color.black.opacity(0.5)))
                            }
                            .padding(4)
                        }
                    }
                    
                    // Daha fazla fotoğraf ekle butonu
                    if totalPhotos < 10 {
                        Button {
                            showingImagePicker = true
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus")
                                    .font(.title2)
                                Text("Ekle")
                                    .font(.caption)
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .frame(width: 100, height: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                            )
                        }
                    }
                }
            } else {
                // Boş durum - ilk fotoğrafı ekle
                Button {
                    showingImagePicker = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Fotoğraf eklemek için dokun")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Text("En fazla 10 fotoğraf")
                            .font(.caption)
                            .foregroundColor(.secondary.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemBackground).opacity(0.65))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .strokeBorder(
                                themeManager.currentTheme.primaryColor.opacity(0.35),
                                style: StrokeStyle(lineWidth: 1.4, dash: [8, 6])
                            )
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Anı Detayları")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Başlık")
                TextField("", text: $title, prompt: Text("Örneğin: İlk konser gecemiz"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Anı")
                ZStack(alignment: .topLeading) {
                    if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Anını tüm detaylarıyla yaz...")
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 18)
                    }
                    contentEditor
                        .frame(minHeight: 160)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Tarih")
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Konum (isteğe bağlı)")
                TextField("", text: $location, prompt: Text("Örneğin: Moda Sahnesi"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Etiketler")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TextField("", text: $tagInput, prompt: Text("Etiket ekle"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                        )
                        .onSubmit(addTag)
                    
                    Button(action: addTag) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryColor)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                if !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                            )
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                } else {
                    Text("Etiketler, anıları kategorize etmenize yardımcı olur. Örneğin: tatil, kutlama, yıldönümü.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    @ViewBuilder
    private var contentEditor: some View {
        if #available(iOS 16.0, *) {
            TextEditor(text: $content)
                .scrollContentBackground(.hidden)
        } else {
            TextEditor(text: $content)
        }
    }
    
    private func detailFieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }
}
