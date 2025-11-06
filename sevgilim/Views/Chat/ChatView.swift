//
//  ChatView.swift
//  sevgilim
//

import SwiftUI
import UIKit
import UserNotifications
import PhotosUI
import UIKit

struct ChatView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var relationshipService: RelationshipService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var messageService: MessageService
    
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var imageToSend: UIImage?
    @State private var showImagePreview = false
    @State private var isLoadingImage = false
    @State private var showError = false
    @State private var errorMessage = ""
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedMessage: Message?
    @State private var showingDeleteConfirmation = false
    @State private var deleteScope: MessageService.MessageDeletionScope = .me
    @State private var showingClearConfirmation = false
    @State private var isPerformingAction = false
    @State private var scrollProxy: ScrollViewProxy?
    @State private var hasStartedListeners = false
    
    private let reactionOptions = ["❤️", "😂", "😍", "👍", "👏", "😢"]
    
    private var currentUserId: String? {
        authService.currentUser?.id
    }
    
    private var clearedDate: Date {
        guard
            let relationship = relationshipService.currentRelationship,
            let userId = currentUserId,
            let cleared = relationship.chatClearedAt?[userId]
        else {
            return .distantPast
        }
        return cleared
    }
    
    private var visibleMessages: [Message] {
        guard let userId = currentUserId else { return messageService.messages }
        return messageService.messages.filter { $0.isVisible(for: userId, clearedAfter: clearedDate) }
    }
    
    private var displayMessages: [ChatDisplayMessage] {
        let messages = visibleMessages
        return messages.enumerated().map { index, message in
            let previous = index > 0 ? messages[index - 1] : nil
            let fallbackId = message.id ?? "\(message.timestamp.timeIntervalSince1970)_\(index)"
            return ChatDisplayMessage(id: fallbackId, message: message, previousMessage: previous)
        }
    }
    
    private struct ChatDisplayMessage: Identifiable {
        let id: String
        let message: Message
        let previousMessage: Message?
        
        var showsDateHeader: Bool {
            guard let previous = previousMessage else { return true }
            return !Calendar.current.isDate(message.timestamp, inSameDayAs: previous.timestamp)
        }
    }
    
    var body: some View {
        mainContent
            .navigationTitle("💬 Sohbet")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear(perform: setupView)
            .onDisappear(perform: cleanupView)
            .onChange(of: authService.currentUser?.id) { _ in
                hasStartedListeners = false
                setupView()
            }
            .onChange(of: relationshipService.currentRelationship?.id) { _ in
                hasStartedListeners = false
                setupView()
            }
            .photosPicker(
                isPresented: $showImagePicker,
                selection: $selectedImage,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedImage) { oldValue, newValue in
                if newValue != nil && oldValue != newValue {
                    handleImageSelection(newValue)
                }
            }
            .sheet(isPresented: $showImagePreview) {
                imagePreviewSheet
            }
            .alert("Hata", isPresented: $showError) {
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            scrollToBottom()
                        } label: {
                            Label("En Alta Git", systemImage: "arrow.down.to.line")
                        }
                        
                        Button(role: .destructive) {
                            showingClearConfirmation = true
                        } label: {
                            Label("Sohbeti Temizle", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .overlay {
                if isLoadingImage {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text("Fotoğraf yükleniyor...")
                                .foregroundColor(.white)
                                .font(.headline)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial)
                        .cornerRadius(20)
                    }
                }
            }
            .confirmationDialog("Mesajı Sil", isPresented: $showingDeleteConfirmation, actions: {
                Button("Sil", role: .destructive) {
                    performDelete()
                }
                Button("İptal", role: .cancel) {
                    selectedMessage = nil
                    deleteScope = .me
                }
            }, message: {
                Text(deleteScope == .everyone ? "Bu mesaj her iki taraf için de silinecek." : "Bu mesaj sadece senin sohbetinden silinecek.")
            })
            .confirmationDialog("Sohbeti Temizle", isPresented: $showingClearConfirmation, titleVisibility: .visible) {
                Button("Temizle", role: .destructive) {
                    clearChatHistory()
                }
                Button("İptal", role: .cancel) { }
            } message: {
                Text("Sohbet geçmişi bu cihazda temizlenecek. Yeni mesajlar yine görünecek.")
            }
    }
    
    private var mainContent: some View {
        ZStack {
            AnimatedGradientBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                messagesListView
                inputBarView
            }
        }
    }
    
    private var messagesListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    let items = displayMessages
                    
                    if items.isEmpty {
                        EmptyChatPlaceholder()
                            .padding(.top, 80)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(items) { item in
                            if item.showsDateHeader {
                                MessageDayHeader(date: item.message.timestamp)
                                    .padding(.leading, 8)
                            }
                            
                            MessageBubble(
                                message: item.message,
                                isCurrentUser: item.message.senderId == currentUserId,
                                theme: themeManager.currentTheme,
                                currentUserId: currentUserId
                            )
                            .id(item.id)
                            .contextMenu {
                                messageContextMenu(for: item.message)
                            }
                        }
                    }
                    
                    if messageService.partnerIsTyping {
                        TypingIndicatorView()
                            .transition(.scale.combined(with: .opacity))
                            .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 20)
            }
            .background(Color.clear)
            .onTapGesture {
                isTextFieldFocused = false
            }
            .onAppear {
                scrollProxy = proxy
                markUnreadMessagesAsRead()
                scrollToBottom(animated: false)
            }
            .onChange(of: displayMessages.last?.id) { _, _ in
                scrollToBottom()
                markUnreadMessagesAsRead()
            }
            .onChange(of: relationshipService.currentRelationship?.chatClearedAt?[currentUserId ?? ""]) { _, _ in
                scrollToBottom(animated: false)
            }
        }
    }
    
    private var inputBarView: some View {
        InputBar(
            messageText: $messageText,
            imageToSend: $imageToSend,
            showImagePicker: $showImagePicker,
            showImagePreview: $showImagePreview,
            isTextFieldFocused: $isTextFieldFocused,
            theme: themeManager.currentTheme,
            onSend: sendMessage,
            onTextChanged: handleTextChanged
        )
    }
    
    @ViewBuilder
    private func messageContextMenu(for message: Message) -> some View {
        let isCurrentUserMessage = message.senderId == currentUserId
        
        let canReact = !message.isGloballyDeleted
        let canCopy = !message.isGloballyDeleted &&
            !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            message.text != "📷 Fotoğraf"
        
        if canReact {
            Menu("İfade bırak") {
                ForEach(reactionOptions, id: \.self) { emoji in
                    Button {
                        toggleReaction(emoji, for: message)
                    } label: {
                        HStack {
                            Text(emoji)
                            if let userId = currentUserId, message.userHasReaction(emoji, userId: userId) {
                                Spacer()
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
            
        }
        
        if canCopy {
            Button {
                copyMessageText(message)
            } label: {
                Label("Kopyala", systemImage: "doc.on.doc")
            }
        }
        
        if canReact || canCopy {
            Divider()
        }
        
        Button(role: .destructive) {
            presentDeleteConfirmation(for: message, scope: .me)
        } label: {
            Label("Benim İçin Sil", systemImage: "trash")
        }
        
        if isCurrentUserMessage && !message.isGloballyDeleted {
            Button(role: .destructive) {
                presentDeleteConfirmation(for: message, scope: .everyone)
            } label: {
                Label("Herkes İçin Sil", systemImage: "trash.slash")
            }
        }
    }

    private func toggleReaction(_ emoji: String, for message: Message) {
        guard let userId = currentUserId else { return }
        Task {
            do {
                try await messageService.toggleReaction(message: message, emoji: emoji, userId: userId)
            } catch {
                await MainActor.run {
                    showError("İfade eklenemedi: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func copyMessageText(_ message: Message) {
        UIPasteboard.general.string = message.text
    }
    
    private func presentDeleteConfirmation(for message: Message, scope: MessageService.MessageDeletionScope) {
        selectedMessage = message
        deleteScope = scope
        showingDeleteConfirmation = true
    }
    
    private func performDelete() {
        guard !isPerformingAction,
              let message = selectedMessage,
              let userId = currentUserId else { return }
        
        isPerformingAction = true
        Task {
            do {
                try await messageService.deleteMessage(message, scope: deleteScope, currentUserId: userId)
            } catch {
                await MainActor.run {
                    showError("Mesaj silinemedi: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                selectedMessage = nil
                deleteScope = .me
                showingDeleteConfirmation = false
                isPerformingAction = false
            }
        }
    }
    
    private func clearChatHistory() {
        guard !isPerformingAction,
              let relationshipId = relationshipService.currentRelationship?.id,
              let userId = currentUserId else { return }
        
        isPerformingAction = true
        Task {
            do {
                try await messageService.clearChat(relationshipId: relationshipId, userId: userId)
            } catch {
                await MainActor.run {
                    showError("Sohbet temizlenemedi: \(error.localizedDescription)")
                }
            }
            
            await MainActor.run {
                isPerformingAction = false
                showingClearConfirmation = false
            }
        }
    }
    
    private func scrollToBottom(animated: Bool = true) {
        guard let proxy = scrollProxy,
              let targetId = displayMessages.last?.id else { return }
        
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(targetId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(targetId, anchor: .bottom)
        }
    }
    
    private func showError(_ text: String) {
        errorMessage = text
        showError = true
    }
    
    @ViewBuilder
    private var imagePreviewSheet: some View {
        if let image = imageToSend {
            ImagePreviewSheet(
                image: image,
                messageText: $messageText,
                onSend: {
                    sendMessageWithImage()
                    showImagePreview = false
                },
                onCancel: {
                    imageToSend = nil
                    showImagePreview = false
                }
            )
        }
    }
    
    private func setupView() {
        guard !hasStartedListeners else { return }
        guard let relationshipId = relationshipService.currentRelationship?.id,
              let userId = authService.currentUser?.id else {
            return
        }
        
        messageService.listenToMessages(relationshipId: relationshipId, currentUserId: userId)
        messageService.listenToTypingIndicator(relationshipId: relationshipId, currentUserId: userId)
        markUnreadMessagesAsRead()
        hasStartedListeners = true
    }
    
    private func cleanupView() {
        defer { hasStartedListeners = false }
        
        guard let relationshipId = relationshipService.currentRelationship?.id,
              let userId = authService.currentUser?.id,
              let userName = authService.currentUser?.name else {
            return
        }
        
        messageService.stopTyping(relationshipId: relationshipId, userId: userId, userName: userName)
        scrollProxy = nil
    }
    
    private func handleImageSelection(_ newItem: PhotosPickerItem?) {
        guard let newItem = newItem else {
            print("⚠️ No image selected")
            return
        }
        
        isLoadingImage = true
        
        Task {
            do {
                // Try to load as Data first
                if let data = try await newItem.loadTransferable(type: Data.self) {
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            imageToSend = image
                            showImagePreview = true
                            isLoadingImage = false
                            // Reset selected image for next selection
                            selectedImage = nil
                        }
                        print("✅ Image loaded successfully")
                        return
                    }
                }
                
                // If Data loading failed, show error
                await MainActor.run {
                    errorMessage = "Fotoğraf yüklenemedi. Lütfen tekrar deneyin."
                    showError = true
                    isLoadingImage = false
                    selectedImage = nil
                }
                print("❌ Failed to convert data to UIImage")
                
            } catch {
                await MainActor.run {
                    errorMessage = "Fotoğraf yüklenirken hata oluştu: \(error.localizedDescription)"
                    showError = true
                    isLoadingImage = false
                    selectedImage = nil
                }
                print("❌ Error loading image: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let relationshipId = relationshipService.currentRelationship?.id,
              let senderId = authService.currentUser?.id,
              let senderName = authService.currentUser?.name else {
            return
        }
        
        messageText = ""
        
        Task {
            do {
                try await messageService.sendMessage(
                    relationshipId: relationshipId,
                    senderId: senderId,
                    senderName: senderName,
                    text: text
                )
            } catch {
                print("❌ Error sending message: \(error.localizedDescription)")
            }
        }
    }
    
    private func sendMessageWithImage() {
        guard let image = imageToSend,
              let relationshipId = relationshipService.currentRelationship?.id,
              let senderId = authService.currentUser?.id,
              let senderName = authService.currentUser?.name else {
            return
        }
        
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = ""
        imageToSend = nil
        isLoadingImage = true
        
        Task {
            do {
                try await messageService.sendMessageWithImage(
                    relationshipId: relationshipId,
                    senderId: senderId,
                    senderName: senderName,
                    text: text,
                    image: image
                )
                await MainActor.run {
                    isLoadingImage = false
                }
                print("✅ Message with image sent successfully")
            } catch {
                await MainActor.run {
                    isLoadingImage = false
                    errorMessage = "Fotoğraf gönderilemedi: \(error.localizedDescription)"
                    showError = true
                }
                print("❌ Error sending message with image: \(error.localizedDescription)")
            }
        }
    }
    
    private func handleTextChanged() {
        guard let relationshipId = relationshipService.currentRelationship?.id,
              let userId = authService.currentUser?.id,
              let userName = authService.currentUser?.name else {
            return
        }
        
        if !messageText.isEmpty {
            messageService.startTyping(relationshipId: relationshipId, userId: userId, userName: userName)
        } else {
            messageService.stopTyping(relationshipId: relationshipId, userId: userId, userName: userName)
        }
    }
    
    private func markUnreadMessagesAsRead() {
        guard let currentUserId = currentUserId else { return }
        let cleared = clearedDate
        
        Task {
            var markedAnyMessage = false
            for message in messageService.messages {
                guard !message.isRead,
                      message.senderId != currentUserId,
                      message.isVisible(for: currentUserId, clearedAfter: cleared),
                      !message.isGloballyDeleted,
                      let messageId = message.id else { continue }
                
                try? await messageService.markAsRead(messageId: messageId)
                markedAnyMessage = true
            }
            
            if markedAnyMessage {
                await MainActor.run {
                    UserDefaults.standard.set(0, forKey: "badgeCount")
                    if #available(iOS 17.0, *) {
                        UNUserNotificationCenter.current().setBadgeCount(0) { error in
                            if let error = error {
                                print("Rozet sıfırlama hatası (chat): \(error.localizedDescription)")
                            }
                        }
                    } else {
                        UIApplication.shared.applicationIconBadgeNumber = 0
                    }
                }
            }
        }
    }
}

// MARK: - Message Bubble
struct MessageBubble: View {
    let message: Message
    let isCurrentUser: Bool
    let theme: AppTheme
    let currentUserId: String?
    
    @State private var showTimestamp = false
    
    private var reactionEntries: [ReactionEntry] {
        message.reactionsSorted().map { ReactionEntry(emoji: $0.emoji, users: $0.users) }
    }
    
    private var textColor: Color {
        if message.isGloballyDeleted {
            return .secondary
        }
        return isCurrentUser ? .white : .primary
    }
    
    private var metadataColor: Color {
        isCurrentUser ? .white.opacity(0.7) : .secondary
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if message.isGloballyDeleted {
            Color(.systemGray4)
        } else if isCurrentUser {
            LinearGradient(
                colors: [theme.primaryColor, theme.secondaryColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color(.systemGray6)
        }
    }
    
    private var shouldShowText: Bool {
        !message.isGloballyDeleted &&
        !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        message.text != "📷 Fotoğraf"
    }
    
    private var deletedMessageText: String {
        isCurrentUser ? "Bu mesajı sildin" : "Mesaj silindi"
    }
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 8) {
                    if let storyImageURL = message.storyImageURL, !message.isGloballyDeleted {
                        storyPreview(url: storyImageURL)
                    }
                    
                    if let imageURL = message.imageURL, !message.isGloballyDeleted {
                        MessageImageView(imageURL: imageURL)
                    }
                    
                    if message.isGloballyDeleted {
                        Text(deletedMessageText)
                            .font(.callout)
                            .italic()
                            .foregroundColor(textColor)
                    } else if shouldShowText {
                        Text(message.text)
                            .font(.body)
                            .foregroundColor(textColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(bubbleBackground)
                .cornerRadius(18)
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                
                if !reactionEntries.isEmpty && !message.isGloballyDeleted {
                    HStack(spacing: 6) {
                        ForEach(reactionEntries) { entry in
                            reactionChip(for: entry)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                }
                
                HStack(spacing: 6) {
                    Text(message.timestamp, formatter: DateFormatter.timeFormat)
                        .font(.caption2)
                        .foregroundColor(metadataColor)
                        .padding(.leading, 2)
                    
                    if isCurrentUser {
                        Image(systemName: message.isRead ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.caption2)
                            .foregroundColor(message.isRead ? .green : metadataColor)
                    }
                }
                .opacity(message.isGloballyDeleted ? 0.6 : 1)
                .frame(maxWidth: .infinity, alignment: isCurrentUser ? .trailing : .leading)
                
                if showTimestamp {
                    Text(message.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            if !isCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                showTimestamp.toggle()
            }
        }
    }
    
    @ViewBuilder
    private func storyPreview(url: String) -> some View {
        HStack(spacing: 8) {
            CachedAsyncImage(url: url, thumbnail: true) { image, _ in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .cornerRadius(10)
            } placeholder: {
                ZStack {
                    Color.gray.opacity(0.2)
                    ProgressView().scaleEffect(0.7)
                }
                .frame(width: 48, height: 48)
                .cornerRadius(10)
            }
            
            Text("Story yanıtı")
                .font(.caption)
                .foregroundColor(textColor.opacity(0.8))
        }
    }
    
    private func reactionChip(for entry: ReactionEntry) -> some View {
        HStack(spacing: 4) {
            Text(entry.emoji)
            Text("\(entry.users.count)")
        }
        .font(.caption.bold())
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(chipBackground(for: entry))
        .clipShape(Capsule())
    }
    
    private func chipBackground(for entry: ReactionEntry) -> Color {
        let reacted = entry.contains(userId: currentUserId)
        if isCurrentUser {
            return reacted ? Color.white.opacity(0.28) : Color.white.opacity(0.18)
        } else {
            return reacted ? theme.primaryColor.opacity(0.18) : Color.gray.opacity(0.18)
        }
    }
    
    private struct ReactionEntry: Identifiable {
        let emoji: String
        let users: [String]
        var id: String { emoji }
        
        func contains(userId: String?) -> Bool {
            guard let userId else { return false }
            return users.contains(userId)
        }
    }
}

private struct MessageDayHeader: View {
    let date: Date
    
    var body: some View {
        HStack(spacing: 12) {
            DividerLine()
            Text(date, formatter: DateFormatter.chatDayFormat)
                .font(.caption.bold())
                .foregroundColor(.secondary)
            DividerLine()
        }
        .frame(maxWidth: .infinity)
    }
    
    private struct DividerLine: View {
        var body: some View {
            Rectangle()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 1)
        }
    }
}

private struct EmptyChatPlaceholder: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48, weight: .semibold))
                .foregroundColor(.secondary)
            Text("Henüz mesaj yok")
                .font(.headline)
                .foregroundColor(.primary)
            Text("İlk mesajı göndererek sohbeti başlat.")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
    }
}

// MARK: - Message Image View with Caching
struct MessageImageView: View {
    let imageURL: String
    @State private var loadedImage: UIImage?
    @State private var showFullScreen = false
    @State private var isLoadingFullImage = false
    
    var body: some View {
        ZStack {
            CachedAsyncImage(url: imageURL, thumbnail: true) { image, _ in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 200, maxHeight: 200)
                    .cornerRadius(12)
                    .onTapGesture {
                        loadFullImageAndShow()
                    }
            } placeholder: {
                ZStack {
                    Color.gray.opacity(0.2)
                    ProgressView()
                }
                .frame(width: 200, height: 200)
                .cornerRadius(12)
            }
            
            if isLoadingFullImage {
                ZStack {
                    Color.black.opacity(0.4)
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.2)
                }
                .frame(maxWidth: 200, maxHeight: 200)
                .cornerRadius(12)
            }
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let image = loadedImage {
                FullScreenImageView(image: image)
            } else {
                // Fallback if image fails to load
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.white)
                        Text("Fotoğraf yüklenemedi")
                            .foregroundColor(.white)
                            .font(.headline)
                        Button("Kapat") {
                            showFullScreen = false
                        }
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(10)
                    }
                }
            }
        }
    }
    
    private func loadFullImageAndShow() {
        isLoadingFullImage = true
        print("📸 Loading full resolution image: \(imageURL)")
        
        Task {
            do {
                if let fullImage = try await ImageCacheService.shared.loadImage(from: imageURL, thumbnail: false) {
                    await MainActor.run {
                        print("✅ Full image loaded successfully")
                        loadedImage = fullImage
                        isLoadingFullImage = false
                        showFullScreen = true
                    }
                } else {
                    await MainActor.run {
                        print("⚠️ Full image returned nil")
                        isLoadingFullImage = false
                        // Show the full screen cover even if image is nil to show error message
                        showFullScreen = true
                    }
                }
            } catch {
                await MainActor.run {
                    print("❌ Error loading full image: \(error.localizedDescription)")
                    isLoadingFullImage = false
                    showFullScreen = true
                }
            }
        }
    }
}

// MARK: - Full Screen Image View
struct FullScreenImageView: View {
    @Environment(\.dismiss) var dismiss
    let image: UIImage
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            let delta = value / lastScale
                            lastScale = value
                            scale = min(max(scale * delta, 1), 4)
                        }
                        .onEnded { _ in
                            lastScale = 1.0
                            if scale < 1 {
                                withAnimation {
                                    scale = 1
                                    offset = .zero
                                    lastOffset = .zero
                                }
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if scale > 1 {
                                offset = CGSize(
                                    width: lastOffset.width + value.translation.width,
                                    height: lastOffset.height + value.translation.height
                                )
                            }
                        }
                        .onEnded { _ in
                            if scale > 1 {
                                lastOffset = offset
                            }
                        }
                )
                .onTapGesture(count: 2) {
                    withAnimation {
                        if scale > 1 {
                            scale = 1
                            offset = .zero
                            lastOffset = .zero
                        } else {
                            scale = 2.5
                        }
                    }
                }
            
            // Close button
            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        ZStack {
                            Circle()
                                .fill(.ultraThinMaterial)
                                .frame(width: 44, height: 44)
                            Image(systemName: "xmark")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(20)
                    Spacer()
                }
                Spacer()
            }
        }
    }
}

// MARK: - Typing Indicator View
struct TypingIndicatorView: View {
    @State private var animateScale = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            HStack(spacing: 4) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.gray)
                        .frame(width: 8, height: 8)
                        .scaleEffect(animateScale ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animateScale
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(18)
            
            Spacer()
        }
        .onAppear {
            animateScale = true
        }
    }
}

// MARK: - Input Bar
struct InputBar: View {
    @Binding var messageText: String
    @Binding var imageToSend: UIImage?
    @Binding var showImagePicker: Bool
    @Binding var showImagePreview: Bool
    var isTextFieldFocused: FocusState<Bool>.Binding
    let theme: AppTheme
    let onSend: () -> Void
    let onTextChanged: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Photo Button with animation
            Button(action: { 
                print("📸 Photo button tapped")
                showImagePicker = true 
            }) {
                ZStack {
                    Circle()
                        .fill(theme.primaryColor.opacity(0.1))
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "photo.fill")
                        .font(.system(size: 20))
                        .foregroundColor(theme.primaryColor)
                }
            }
            .buttonStyle(.plain)
            
            // Text Field
            HStack(spacing: 8) {
                TextField("Mesaj yaz...", text: $messageText, axis: .vertical)
                    .lineLimit(1...5)
                    .focused(isTextFieldFocused)
                    .onChange(of: messageText) { _, _ in
                        onTextChanged()
                    }
                
                if !messageText.isEmpty {
                    Button(action: {
                        messageText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.systemGray6))
            .cornerRadius(20)
            
            // Send Button
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?
                                [Color.gray.opacity(0.3), Color.gray.opacity(0.3)] :
                                [theme.primaryColor, theme.secondaryColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: "arrow.up")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(.systemBackground).opacity(0.95))
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: -2)
    }
}

// MARK: - Image Preview Sheet
struct ImagePreviewSheet: View {
    let image: UIImage
    @Binding var messageText: String
    let onSend: () -> Void
    let onCancel: () -> Void
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Image Preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .cornerRadius(12)
                    .padding()
                
                // Caption TextField
                TextField("Başlık ekle (opsiyonel)", text: $messageText, axis: .vertical)
                    .lineLimit(1...3)
                    .focused($isTextFieldFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                    .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("Fotoğraf Gönder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Gönder") {
                        onSend()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Date Formatter Extensions
extension DateFormatter {
    static let timeFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }()
    
    static let chatDayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }()
}

#Preview {
    NavigationStack {
        ChatView()
            .environmentObject(AuthenticationService())
            .environmentObject(RelationshipService())
            .environmentObject(ThemeManager())
    }
}
