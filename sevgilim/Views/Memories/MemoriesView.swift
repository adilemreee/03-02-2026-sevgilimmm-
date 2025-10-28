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
            if let relationshipId = authService.currentUser?.relationshipId {
                memoryService.listenToMemories(relationshipId: relationshipId)
            }
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
            if let photoURL = memory.photoURL {
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
    
    @State private var showingDeleteAlert = false
    @State private var showingComments = false
    @State private var commentText = ""
    @State private var isSubmittingComment = false
    @State private var commentError: String?
    @State private var isShowingPhotoViewer = false
    @State private var photoViewerIndex = 0
    @StateObject private var singlePhotoService = PhotoService()
    
    // Get current memory from service for live updates
    private var currentMemory: Memory {
        memoryService.memories.first(where: { $0.id == memory.id }) ?? memory
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Photo
                    if let photoURL = currentMemory.photoURL {
                        GeometryReader { geometry in
                            Button {
                                let photo = Photo(
                                    id: currentMemory.id,
                                    relationshipId: currentMemory.relationshipId,
                                    imageURL: photoURL,
                                    thumbnailURL: photoURL,
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
                                singlePhotoService.photos = [photo]
                                photoViewerIndex = 0
                                isShowingPhotoViewer = true
                            } label: {
                                CachedAsyncImage(url: photoURL, thumbnail: false) { image, _ in
                                    image
                                        .resizable()
                                        .scaledToFit()
                                        .frame(maxWidth: geometry.size.width)
                                        .frame(height: min(geometry.size.width * 0.75, 360))
                                        .clipped()
                                } placeholder: {
                                    ZStack {
                                        Color.gray.opacity(0.1)
                                        ProgressView()
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: min(geometry.size.width * 0.75, 360))
                                .background(Color.black.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: UIScreen.main.bounds.width * 0.75)
                    }
                    
                    // Title
                    Text(currentMemory.title)
                        .font(.title.bold())
                    
                    // Date and Location
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Image(systemName: "calendar")
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
                            
                            if let commentError {
                                Text(commentError)
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            if currentMemory.comments.isEmpty {
                                Text("Henüz yorum yok")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            } else {
                                ForEach(currentMemory.comments) { comment in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(spacing: 8) {
                                            Text(comment.userName)
                                                .font(.caption.bold())
                                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                            Text(comment.createdAt.timeAgo())
                                                .font(.caption2)
                                                .foregroundColor(.secondary)
                                        }
                                        Text(comment.text)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                    }
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(themeManager.currentTheme.primaryColor.opacity(0.08))
                                    )
                                }
                            }
                            
                            // Add Comment
                            HStack(spacing: 12) {
                                TextField("Yorum ekle...", text: $commentText, axis: .vertical)
                                    .lineLimit(1...4)
                                    .textFieldStyle(.roundedBorder)
                                    .submitLabel(.send)
                                    .onSubmit(addComment)
                                
                                Button(action: addComment) {
                                    if isSubmittingComment {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                            .font(.title3)
                                            .foregroundStyle(themeManager.currentTheme.primaryColor)
                                    }
                                }
                                .buttonStyle(.plain)
                                .disabled(isSubmittingComment || trimmedCommentText().isEmpty)
                            }
                            .padding(.top, 4)
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
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
        }
        .onDisappear {
            singlePhotoService.photos = []
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
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
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
            ImagePicker(image: $selectedImage)
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
                var photoURL: String? = nil
                if let image = selectedImage {
                    photoURL = try await StorageService.shared.uploadMemoryPhoto(image, relationshipId: relationshipId)
                }
                
                try await memoryService.addMemory(
                    relationshipId: relationshipId,
                    title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                    content: content.trimmingCharacters(in: .whitespacesAndNewlines),
                    date: date,
                    photoURL: photoURL,
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
            Text("Fotoğraf")
                .font(.headline)
            Text("Anıyı daha özel kılmak için bir fotoğraf ekleyebilirsin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 230)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Fotoğrafı Değiştir", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.16))
                            )
                    }
                    
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedImage = nil
                        }
                    } label: {
                        Label("Kaldır", systemImage: "trash")
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.12))
                            )
                    }
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
            } else {
                Button {
                    showingImagePicker = true
                } label: {
                    VStack(spacing: 16) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 44, weight: .medium))
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        Text("Fotoğraf eklemek için dokun")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
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
