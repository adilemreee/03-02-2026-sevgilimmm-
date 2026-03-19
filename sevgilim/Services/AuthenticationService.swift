//
//  AuthenticationService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var observedUserId: String?
    
    private nonisolated static func makeUser(from data: [String: Any], userId: String) -> User {
        let preferencesData = data["notificationPreferences"] as? [String: Any] ?? [:]
        return User(
            id: userId,
            email: data["email"] as? String ?? "",
            name: data["name"] as? String ?? "",
            profileImageURL: data["profileImageURL"] as? String,
            relationshipId: data["relationshipId"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date(),
            fcmTokens: data["fcmTokens"] as? [String],
            notificationPreferences: NotificationPreferences(dictionary: preferencesData),
            unreadNotificationCount: data["unreadNotificationCount"] as? Int ?? 0
        )
    }
    
    init() {
        checkAuthStatus()
    }
    
    func checkAuthStatus() {
        if let firebaseUser = Auth.auth().currentUser {
            fetchUserData(userId: firebaseUser.uid)
        }
    }
    
    func signUp(email: String, password: String, name: String) async throws {
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            
            let newUser = User(
                id: result.user.uid,
                email: email,
                name: name,
                profileImageURL: nil,
                relationshipId: nil,
                createdAt: Date(),
                fcmTokens: [],
                notificationPreferences: .default,
                unreadNotificationCount: 0
            )
            
            try await db.collection("users").document(result.user.uid).setData([
                "email": email,
                "name": name,
                "createdAt": Timestamp(date: Date()),
                "fcmTokens": [],
                "notificationPreferences": NotificationPreferences.default.firestoreData,
                "unreadNotificationCount": 0
            ])
            
            await MainActor.run {
                self.currentUser = newUser
                self.isAuthenticated = true
                PushNotificationManager.shared.syncTokenWithCurrentUser()
            }
            fetchUserData(userId: result.user.uid)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func signIn(email: String, password: String) async throws {
        do {
            let result = try await Auth.auth().signIn(withEmail: email, password: password)
            fetchUserData(userId: result.user.uid)
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func signOut() {
        do {
            PushNotificationManager.shared.unregisterCurrentToken()
            try Auth.auth().signOut()
            stopUserListener()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func sendPasswordReset(email: String) async throws {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            await MainActor.run {
                self.errorMessage = nil
            }
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
            }
            throw error
        }
    }
    
    func fetchUserData(userId: String) {
        guard !userId.isEmpty else { return }
        if observedUserId == userId, userListener != nil {
            return
        }
        
        stopUserListener()
        observedUserId = userId
        
        userListener = db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            
            if let error = error {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
                return
            }
            
            guard let snapshot, let data = snapshot.data() else { return }
            let user = Self.makeUser(from: data, userId: userId)
            
            Task { @MainActor in
                self.currentUser = user
                self.isAuthenticated = true
                PushNotificationManager.shared.syncTokenWithCurrentUser()
            }
        }
    }
    
    func updateUserProfile(name: String?, profileImageURL: String?) async throws {
        guard let userId = currentUser?.id else { return }
        
        var updates: [String: Any] = [:]
        if let name = name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updates["name"] = name
        }
        if let profileImageURL = profileImageURL {
            updates["profileImageURL"] = profileImageURL
        }
        
        try await db.collection("users").document(userId).updateData(updates)
        
        if let relationshipId = currentUser?.relationshipId,
           let name = name,
           !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let relationshipRef = db.collection("relationships").document(relationshipId)
            let snapshot = try await relationshipRef.getDocument()
            if snapshot.exists {
                var relationshipUpdates: [String: Any] = [:]
                let data = snapshot.data() ?? [:]
                if let user1Id = data["user1Id"] as? String, user1Id == userId {
                    relationshipUpdates["user1Name"] = name
                }
                if let user2Id = data["user2Id"] as? String, user2Id == userId {
                    relationshipUpdates["user2Name"] = name
                }
                
                if !relationshipUpdates.isEmpty {
                    try await relationshipRef.updateData(relationshipUpdates)
                }
            }
        }
        
        fetchUserData(userId: userId)
    }
    
    func getUserProfile(userId: String) async throws -> User {
        let snapshot = try await db.collection("users").document(userId).getDocument()
        guard let data = snapshot.data() else {
            throw NSError(domain: "AuthenticationService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
        }
        
        return Self.makeUser(from: data, userId: userId)
    }
    
    func updateRelationshipId(_ relationshipId: String) async throws {
        guard let userId = currentUser?.id else { return }
        
        try await db.collection("users").document(userId).updateData([
            "relationshipId": relationshipId
        ])
        
        fetchUserData(userId: userId)
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws {
        guard let userId = currentUser?.id else { return }
        
        try await db.collection("users").document(userId).updateData([
            "notificationPreferences": preferences.firestoreData
        ])
        
        currentUser?.notificationPreferences = preferences
    }
    
    func deleteAccount() async throws {
        guard let userId = currentUser?.id,
              let user = Auth.auth().currentUser else { return }
        
        // 1. Delete user data from Firestore
        try await db.collection("users").document(userId).delete()
        
        // 2. Delete user from Firebase Auth
        try await user.delete()
        
        await MainActor.run {
            self.stopUserListener()
            self.currentUser = nil
            self.isAuthenticated = false
        }
    }
    
    private func stopUserListener() {
        userListener?.remove()
        userListener = nil
        observedUserId = nil
    }
}
