//
//  NotificationHistoryService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class NotificationHistoryService: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentUserId: String?
    private var remoteNotificationObserver: AnyCancellable?
    
    init() {
        remoteNotificationObserver = NotificationCenter.default
            .publisher(for: .didReceiveRemoteNotification)
            .sink { [weak self] notification in
                guard let self = self else { return }
                Task { @MainActor in
                    await self.markMatchingNotificationAsRead(from: notification.userInfo)
                }
            }
    }
    
    var unreadCount: Int {
        notifications.filter { !$0.isRead }.count
    }
    
    func listenToNotifications(userId: String) {
        guard !userId.isEmpty else { return }
        if currentUserId == userId, listener != nil {
            return
        }
        
        stopListening()
        currentUserId = userId
        isLoading = true
        
        listener = db.collection("users")
            .document(userId)
            .collection("notifications")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to notifications: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                let items = snapshot?.documents.compactMap { document in
                    try? document.data(as: AppNotification.self)
                } ?? []
                
                Task { @MainActor in
                    self.notifications = items
                    self.isLoading = false
                }
            }
    }
    
    func markAsRead(_ notification: AppNotification) async {
        guard
            let id = notification.id,
            let userId = currentUserId,
            !notification.isRead
        else { return }
        
        do {
            try await notificationRef(userId: userId, notificationId: id)
                .updateData([
                    "isRead": true,
                    "readAt": Timestamp(date: Date())
                ])
        } catch {
            print("❌ Error marking notification as read: \(error.localizedDescription)")
        }
    }
    
    func markAllAsRead() async {
        guard let userId = currentUserId else { return }
        
        do {
            let snapshot = try await db.collection("users")
                .document(userId)
                .collection("notifications")
                .whereField("isRead", isEqualTo: false)
                .getDocuments()
            
            guard !snapshot.documents.isEmpty else { return }
            
            for chunk in snapshot.documents.chunked(into: 400) {
                let batch = db.batch()
                chunk.forEach { document in
                    batch.updateData([
                        "isRead": true,
                        "readAt": Timestamp(date: Date())
                    ], forDocument: document.reference)
                }
                try await batch.commit()
            }
        } catch {
            print("❌ Error marking all notifications as read: \(error.localizedDescription)")
        }
    }
    
    func deleteNotification(_ notification: AppNotification) async {
        guard
            let id = notification.id,
            let userId = currentUserId
        else { return }
        
        do {
            try await notificationRef(userId: userId, notificationId: id).delete()
        } catch {
            print("❌ Error deleting notification: \(error.localizedDescription)")
        }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        currentUserId = nil
        notifications = []
        isLoading = false
    }
    
    private func markMatchingNotificationAsRead(from userInfo: [AnyHashable: Any]?) async {
        guard let userInfo, let type = notificationType(from: userInfo)?.lowercased() else {
            return
        }
        
        let keys = [
            "messageId",
            "memoryId",
            "photoId",
            "noteId",
            "planId",
            "specialDayId",
            "surpriseId",
            "songId",
            "movieId",
            "placeId",
            "itemId",
            "storyId",
            "relationshipId"
        ]
        
        let matchingNotification = notifications.first { notification in
            guard !notification.isRead, notification.normalizedType == type else {
                return false
            }
            
            for key in keys {
                if let payloadValue = stringValue(for: key, in: userInfo) {
                    if key == "relationshipId" {
                        return notification.relationshipId == payloadValue ||
                            notification.metadata[key] == payloadValue
                    }
                    return notification.metadata[key] == payloadValue
                }
            }
            
            return true
        }
        
        guard let matchingNotification else { return }
        await markAsRead(matchingNotification)
    }
    
    private func notificationType(from userInfo: [AnyHashable: Any]) -> String? {
        if let type = userInfo["type"] as? String {
            return type
        }
        if let data = userInfo["data"] as? [String: Any],
           let type = data["type"] as? String {
            return type
        }
        if let type = userInfo["gcm.notification.type"] as? String {
            return type
        }
        return nil
    }
    
    private func stringValue(for key: String, in userInfo: [AnyHashable: Any]) -> String? {
        if let value = userInfo[key] as? String {
            return value
        }
        if let data = userInfo["data"] as? [String: Any],
           let value = data[key] as? String {
            return value
        }
        if let value = userInfo["gcm.notification.\(key)"] as? String {
            return value
        }
        return nil
    }
    
    private func notificationRef(userId: String, notificationId: String) -> DocumentReference {
        db.collection("users")
            .document(userId)
            .collection("notifications")
            .document(notificationId)
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return isEmpty ? [] : [self] }
        
        var chunks: [[Element]] = []
        var index = startIndex
        
        while index < endIndex {
            let end = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            chunks.append(Array(self[index..<end]))
            index = end
        }
        
        return chunks
    }
}
