//
//  ChatViewModel.swift
//  sevgilim
//
//  ViewModel for ChatView - extracts business logic from view
//

import Foundation
import Combine
import UIKit

@MainActor
final class ChatViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var messageText: String = ""
    @Published var imageToSend: UIImage?
    @Published var isLoadingImage: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""
    @Published var showImagePreview: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var selectedMessage: Message?
    @Published var showingDeleteConfirmation: Bool = false
    @Published var deleteScope: MessageService.MessageDeletionScope = .me
    @Published var showingClearConfirmation: Bool = false
    @Published private var isPerformingAction: Bool = false
    @Published private var hasStartedListeners: Bool = false
    
    // MARK: - Dependencies
    private let messageService: MessageService
    private let authService: AuthenticationService
    private let relationshipService: RelationshipService
    
    // MARK: - Constants
    let reactionOptions = ["❤️", "😂", "😍", "👍", "👏", "😢"]
    
    // MARK: - Computed Properties
    var currentUserId: String? {
        authService.currentUser?.id
    }
    
    var currentUserName: String? {
        authService.currentUser?.name
    }
    
    var relationshipId: String? {
        relationshipService.currentRelationship?.id
    }
    
    var clearedDate: Date {
        guard let relationship = relationshipService.currentRelationship,
              let userId = currentUserId,
              let cleared = relationship.chatClearedAt?[userId] else {
            return .distantPast
        }
        return cleared
    }
    
    var visibleMessages: [Message] {
        guard let userId = currentUserId else { return messageService.messages }
        return messageService.messages.filter { $0.isVisible(for: userId, clearedAfter: clearedDate) }
    }
    
    var partnerIsTyping: Bool {
        messageService.partnerIsTyping
    }
    
    var messages: [Message] {
        messageService.messages
    }
    
    // MARK: - Initialization
    init(messageService: MessageService, authService: AuthenticationService, relationshipService: RelationshipService) {
        self.messageService = messageService
        self.authService = authService
        self.relationshipService = relationshipService
    }
    
    // MARK: - Lifecycle
    func setupListeners() {
        guard !hasStartedListeners,
              let relationshipId = relationshipId,
              let userId = currentUserId else { return }
        
        messageService.listenToMessages(relationshipId: relationshipId, currentUserId: userId)
        messageService.listenToTypingIndicator(relationshipId: relationshipId, currentUserId: userId)
        markUnreadMessagesAsRead()
        hasStartedListeners = true
    }
    
    func cleanup() {
        defer { hasStartedListeners = false }
        
        guard let relationshipId = relationshipId,
              let userId = currentUserId,
              let userName = currentUserName else { return }
        
        messageService.stopTyping(relationshipId: relationshipId, userId: userId, userName: userName)
    }
    
    // MARK: - Message Actions
    func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty,
              let relationshipId = relationshipId,
              let senderId = currentUserId,
              let senderName = currentUserName else { return }
        
        messageText = ""
        HapticManager.shared.lightImpact()
        
        Task {
            do {
                try await messageService.sendMessage(
                    relationshipId: relationshipId,
                    senderId: senderId,
                    senderName: senderName,
                    text: text
                )
            } catch {
                showError("Mesaj gönderilemedi: \(error.localizedDescription)")
            }
        }
    }
    
    func sendMessageWithImage() {
        guard let image = imageToSend,
              let relationshipId = relationshipId,
              let senderId = currentUserId,
              let senderName = currentUserName else { return }
        
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
                isLoadingImage = false
            } catch {
                isLoadingImage = false
                showError("Fotoğraf gönderilemedi: \(error.localizedDescription)")
            }
        }
    }
    
    func toggleReaction(_ emoji: String, for message: Message) {
        guard let userId = currentUserId else { return }
        
        Task {
            do {
                try await messageService.toggleReaction(message: message, emoji: emoji, userId: userId)
            } catch {
                showError("İfade eklenemedi: \(error.localizedDescription)")
            }
        }
    }
    
    func deleteMessage() {
        guard !isPerformingAction,
              let message = selectedMessage,
              let userId = currentUserId else { return }
        
        isPerformingAction = true
        
        Task {
            do {
                try await messageService.deleteMessage(message, scope: deleteScope, currentUserId: userId)
            } catch {
                showError("Mesaj silinemedi: \(error.localizedDescription)")
            }
            
            selectedMessage = nil
            deleteScope = .me
            showingDeleteConfirmation = false
            isPerformingAction = false
        }
    }
    
    func clearChatHistory() {
        guard !isPerformingAction,
              let relationshipId = relationshipId,
              let userId = currentUserId else { return }
        
        isPerformingAction = true
        
        Task {
            do {
                try await messageService.clearChat(relationshipId: relationshipId, userId: userId)
            } catch {
                showError("Sohbet temizlenemedi: \(error.localizedDescription)")
            }
            
            isPerformingAction = false
            showingClearConfirmation = false
        }
    }
    
    func markAsRead(messageId: String) async {
        try? await messageService.markAsRead(messageId: messageId)
    }
    
    // MARK: - Typing Indicator
    func handleTextChanged() {
        guard let relationshipId = relationshipId,
              let userId = currentUserId,
              let userName = currentUserName else { return }
        
        if !messageText.isEmpty {
            messageService.startTyping(relationshipId: relationshipId, userId: userId, userName: userName)
        } else {
            messageService.stopTyping(relationshipId: relationshipId, userId: userId, userName: userName)
        }
    }
    
    // MARK: - Helpers
    func presentDeleteConfirmation(for message: Message, scope: MessageService.MessageDeletionScope) {
        selectedMessage = message
        deleteScope = scope
        showingDeleteConfirmation = true
    }
    
    func copyMessageText(_ message: Message) {
        UIPasteboard.general.string = message.text
    }
    
    func markUnreadMessagesAsRead() {
        guard let currentUserId = currentUserId else { return }
        let cleared = clearedDate
        
        Task {
            for message in messages {
                guard !message.isRead,
                      message.senderId != currentUserId,
                      message.isVisible(for: currentUserId, clearedAfter: cleared),
                      !message.isGloballyDeleted,
                      let messageId = message.id else { continue }
                
                try? await messageService.markAsRead(messageId: messageId)
            }
        }
    }
    
    private func showError(_ text: String) {
        errorMessage = text
        showError = true
    }
}
