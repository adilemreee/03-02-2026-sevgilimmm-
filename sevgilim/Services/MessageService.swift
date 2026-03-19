//
//  MessageService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage


@MainActor
class MessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var partnerIsTyping: Bool = false
    @Published var unreadMessageCount: Int = 0
    
    private let messagesLimit = 100
    
    enum MessageDeletionScope {
        case me
        case everyone
    }
    
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var messagesListener: ListenerRegistration?
    private var typingListener: ListenerRegistration?
    private var unreadCountListener: ListenerRegistration?
    private var typingTimer: Timer?
    
    // MARK: - Listen to Messages (Optimized)
    func listenToMessages(relationshipId: String , currentUserId : String) {
        // Remove existing listener if any
        messagesListener?.remove()

        let baseQuery = db.collection("messages")
            .whereField("relationshipId", isEqualTo: relationshipId)
        
        let orderedQuery = baseQuery
            .order(by: "timestamp")
            .limit(toLast: messagesLimit)
        
        startMessagesListener(primaryQuery: orderedQuery, fallbackQuery: baseQuery, allowFallback: true)
    }
    
    // MARK: - Listen to Typing Indicator
    func listenToTypingIndicator(relationshipId: String, currentUserId: String) {
        print("⌨️ Starting to listen to typing indicator")
        
        typingListener?.remove()
        
        typingListener = db.collection("relationships")
            .document(relationshipId)
            .collection("typing")
            .document("current")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to typing: \(error.localizedDescription)")
                    return
                }
                
                guard let data = snapshot?.data(),
                      let userId = data["userId"] as? String,
                      let isTyping = data["isTyping"] as? Bool,
                      let timestamp = data["timestamp"] as? Timestamp else {
                    self.partnerIsTyping = false
                    return
                }
                
                // Convert Firestore Timestamp to Date
                let date = timestamp.dateValue()
                
                // Only show typing if it's not the current user and was updated recently (within 3 seconds)
                let isRecent = Date().timeIntervalSince(date) < 3
                self.partnerIsTyping = userId != currentUserId && isTyping && isRecent
                
                print("⌨️ Partner typing: \(self.partnerIsTyping)")
            }
    }
    
    // MARK: - Send Message
    func sendMessage(relationshipId: String, senderId: String, senderName: String, text: String, storyImageURL: String? = nil) async throws {
        print("💬 Sending message: \(text)")
        
        let message = Message(
            relationshipId: relationshipId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            imageURL: nil,
            storyImageURL: storyImageURL,
            timestamp: Date(),
            isRead: false,
            readAt: nil
        )
        
        do {
            let _ = try db.collection("messages").addDocument(from: message)
            print("✅ Message sent successfully")
            
            // Clear typing indicator
            try await setTypingIndicator(relationshipId: relationshipId, userId: senderId, userName: senderName, isTyping: false)
        } catch {
            print("❌ Error sending message: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Send Message with Image
    func sendMessageWithImage(relationshipId: String, senderId: String, senderName: String, text: String, image: UIImage) async throws {
        print("📸 Uploading image for message")
        
        do {
            // Use optimized StorageService for upload
            let imagePath = "relationships/\(relationshipId)/messages/\(UUID().uuidString).jpg"
            let imageURL = try await StorageService.shared.uploadImage(image, path: imagePath, quality: 0.7)
            
            print("✅ Image uploaded: \(imageURL)")
            
            // Send message with image URL
            let message = Message(
                relationshipId: relationshipId,
                senderId: senderId,
                senderName: senderName,
                text: text.isEmpty ? "📷 Fotoğraf" : text,
                imageURL: imageURL,
                timestamp: Date(),
                isRead: false,
                readAt: nil
            )
            
            let _ = try db.collection("messages").addDocument(from: message)
            print("✅ Message with image sent successfully")
            
            // Clear typing indicator
            try await setTypingIndicator(relationshipId: relationshipId, userId: senderId, userName: senderName, isTyping: false)
        } catch {
            print("❌ Error sending message with image: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Toggle Reaction
    func toggleReaction(message: Message, emoji: String, userId: String) async throws {
        guard let messageId = message.id else { return }
        let messageRef = db.collection("messages").document(messageId)
        
        var reactions = message.reactions ?? [:]
        var users = Set(reactions[emoji] ?? [])
        
        if users.contains(userId) {
            users.remove(userId)
        } else {
            users.insert(userId)
        }
        
        if users.isEmpty {
            reactions.removeValue(forKey: emoji)
        } else {
            reactions[emoji] = Array(users)
        }
        
        if reactions.isEmpty {
            try await messageRef.updateData([
                "reactions": FieldValue.delete()
            ])
        } else {
            try await messageRef.updateData([
                "reactions": reactions
            ])
        }
    }
    
    // MARK: - Delete Message
    func deleteMessage(_ message: Message, scope: MessageDeletionScope, currentUserId: String) async throws {
        guard let messageId = message.id else { return }
        let messageRef = db.collection("messages").document(messageId)
        
        switch scope {
        case .me:
            var deletedFor = Set(message.deletedForUserIds ?? [])
            if deletedFor.contains(currentUserId) {
                return
            }
            deletedFor.insert(currentUserId)
            try await messageRef.updateData([
                "deletedForUserIds": Array(deletedFor)
            ])
        case .everyone:
            var updates: [String: Any] = [
                "isDeletedForEveryone": true,
                "deletedAt": FieldValue.serverTimestamp(),
                "reactions": FieldValue.delete()
            ]
            
            if !message.text.isEmpty {
                updates["text"] = ""
            }
            
            if message.imageURL != nil {
                updates["imageURL"] = FieldValue.delete()
            }
            
            if message.storyImageURL != nil {
                updates["storyImageURL"] = FieldValue.delete()
            }
            
            try await messageRef.updateData(updates)
            
            if let imageURL = message.imageURL {
                removeImageFromStorage(urlString: imageURL)
            }
        }
    }
    
    // MARK: - Clear Chat
    func clearChat(relationshipId: String, userId: String) async throws {
        let relationshipRef = db.collection("relationships").document(relationshipId)
        try await relationshipRef.updateData([
            "chatClearedAt.\(userId)": FieldValue.serverTimestamp()
        ])
    }
    
    private func removeImageFromStorage(urlString: String) {
        let reference = storage.reference(forURL: urlString)
        reference.delete { error in
            if let error = error {
                print("❌ Failed to delete message image: \(error.localizedDescription)")
            } else {
                print("🗑️ Message image removed from storage")
            }
        }
    }
    
    // MARK: - Mark as Read
    func markAsRead(messageId: String) async throws {
        print("✓ Marking message as read: \(messageId)")
        
        do {
            try await db.collection("messages").document(messageId).updateData([
                "isRead": true,
                "readAt": FieldValue.serverTimestamp()
            ])
            print("✅ Message marked as read")
        } catch {
            print("❌ Error marking message as read: \(error.localizedDescription)")
            throw error
        }
    }
    
    // MARK: - Set Typing Indicator
    func setTypingIndicator(relationshipId: String, userId: String, userName: String, isTyping: Bool) async throws {
        let data: [String: Any] = [
            "userId": userId,
            "userName": userName,
            "isTyping": isTyping,
            "timestamp": FieldValue.serverTimestamp()
        ]
        
        do {
            try await db.collection("relationships")
                .document(relationshipId)
                .collection("typing")
                .document("current")
                .setData(data)
        } catch {
            print("❌ Error setting typing indicator: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Listen to Unread Messages Count (YENİ FONKSİYON)
    func listenToUnreadMessagesCount(relationshipId: String, currentUserId: String) {
        // Mevcut dinleyiciyi kaldır
        unreadCountListener?.remove()

        // Sadece karşı tarafın gönderdiği ve okunmamış mesajları dinle
        unreadCountListener = db.collection("messages")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .whereField("isRead", isEqualTo: false)
            .whereField("senderId", isNotEqualTo: currentUserId) // <-- ÖNEMLİ: Kendi mesajlarımızı saymamak için
            .order(by: "senderId")
            .addSnapshotListener { [weak self] snapshot, error in
                if let error = error {
                    print("❌ Error listening to unread message count: \(error.localizedDescription)")
                    return
                }

                guard let count = snapshot?.documents.count else {
                    self?.unreadMessageCount = 0
                    return
                }

                print(" okunmamış mesaj sayısı: \(count)")
                self?.unreadMessageCount = count
            }
    }
    
    
    // MARK: - Start Typing
    func startTyping(relationshipId: String, userId: String, userName: String) {
        Task {
            try? await setTypingIndicator(relationshipId: relationshipId, userId: userId, userName: userName, isTyping: true)
        }
        
        // Auto-clear typing after 3 seconds
        typingTimer?.invalidate()
        typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                try? await self?.setTypingIndicator(relationshipId: relationshipId, userId: userId, userName: userName, isTyping: false)
            }
        }
    }
    
    // MARK: - Stop Typing
    func stopTyping(relationshipId: String, userId: String, userName: String) {
        typingTimer?.invalidate()
        Task {
            try? await setTypingIndicator(relationshipId: relationshipId, userId: userId, userName: userName, isTyping: false)
        }
    }
    
    // MARK: - Cleanup
    func cleanup() {
        print("🧹 Cleaning up MessageService")
        messagesListener?.remove()
        typingListener?.remove()
        unreadCountListener?.remove()
        typingTimer?.invalidate()
    }
    
    nonisolated deinit {
        // Cancel listeners synchronously (safe in deinit)
        messagesListener?.remove()
        typingListener?.remove()
        unreadCountListener?.remove()
        typingTimer?.invalidate()
    }

    // MARK: - Private Helpers
    private func startMessagesListener(primaryQuery: Query, fallbackQuery: Query?, allowFallback: Bool) {
        messagesListener = primaryQuery.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                if allowFallback,
                   let fallbackQuery,
                   let nsError = error as NSError?,
                   nsError.domain == FirestoreErrorDomain,
                   nsError.code == FirestoreErrorCode.failedPrecondition.rawValue {
                    print("⚠️ Mesaj sorgusu için Firestore index eksik: \(error.localizedDescription). Yedek sorguya geçiliyor.")
                    self.messagesListener?.remove()
                    self.startMessagesListener(primaryQuery: fallbackQuery, fallbackQuery: nil, allowFallback: false)
                } else {
                    print("❌ Error listening to messages: \(error.localizedDescription)")
                }
                return
            }

            guard let documents = snapshot?.documents else {
                return
            }

            var fetchedMessages = documents.compactMap { document in
                try? document.data(as: Message.self)
            }

            fetchedMessages.sort { $0.timestamp < $1.timestamp }

            if fetchedMessages.count > self.messagesLimit {
                fetchedMessages = Array(fetchedMessages.suffix(self.messagesLimit))
            }

            self.messages = fetchedMessages
        }
    }
}
