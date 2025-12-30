//
//  SecretVaultPINManager.swift
//  sevgilim
//

import Foundation
import Combine
import CryptoKit
import FirebaseFirestore

@MainActor
final class SecretVaultPINManager: ObservableObject {
    static let shared = SecretVaultPINManager()
    
    @Published private(set) var hasPIN: Bool = false
    @Published private(set) var isLoading: Bool = true
    @Published private(set) var isReady: Bool = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var currentRelationshipId: String?
    
    private init() {}
    
    // MARK: - Listen to PIN
    
    func listenToPIN(relationshipId: String) {
        // Aynı relationship için zaten dinliyorsak ve hazırsak, tekrar başlatma
        if currentRelationshipId == relationshipId && isReady {
            return
        }
        
        listener?.remove()
        currentRelationshipId = relationshipId
        isLoading = true
        isReady = false
        
        print("🔐 SecretVault: Starting PIN listener for relationship \(relationshipId)")
        
        listener = db.collection("relationships")
            .document(relationshipId)
            .addSnapshotListener { [weak self] snapshot, error in
                Task { @MainActor in
                    guard let self = self else { return }
                    
                    if let error = error {
                        print("❌ SecretVault PIN listener error: \(error.localizedDescription)")
                        self.isLoading = false
                        self.isReady = true
                        self.hasPIN = false
                        return
                    }
                    
                    if let data = snapshot?.data() {
                        let pinHash = data["secretVaultPINHash"] as? String
                        let pinExists = pinHash != nil
                        print("🔐 SecretVault: PIN exists = \(pinExists), hash = \(pinHash ?? "nil")")
                        self.hasPIN = pinExists
                    } else {
                        print("🔐 SecretVault: No data found in relationship document")
                        self.hasPIN = false
                    }
                    
                    self.isLoading = false
                    self.isReady = true
                }
            }
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
        currentRelationshipId = nil
        hasPIN = false
        isReady = false
    }
    
    // MARK: - Set PIN
    
    func setPIN(_ pin: String, relationshipId: String) async throws {
        let pinHash = hash(pin)
        
        print("🔐 SecretVault: Saving PIN hash to Firebase...")
        print("🔐 SecretVault: Relationship ID = \(relationshipId)")
        print("🔐 SecretVault: PIN Hash = \(pinHash)")
        
        do {
            // setData with merge:true ensures field is added even if it doesn't exist
            try await db.collection("relationships")
                .document(relationshipId)
                .setData([
                    "secretVaultPINHash": pinHash
                ], merge: true)
            
            print("✅ SecretVault: PIN saved successfully to Firebase!")
            
            // Manually update local state
            self.hasPIN = true
        } catch {
            print("❌ SecretVault: Failed to save PIN - \(error.localizedDescription)")
            print("❌ SecretVault: Full error - \(error)")
            throw error
        }
    }
    
    // MARK: - Validate PIN
    
    func validate(pin: String, relationshipId: String) async -> Bool {
        print("🔐 SecretVault: Validating PIN for relationship \(relationshipId)")
        
        do {
            let document = try await db.collection("relationships")
                .document(relationshipId)
                .getDocument()
            
            guard let data = document.data(),
                  let storedHash = data["secretVaultPINHash"] as? String else {
                print("❌ SecretVault: No PIN hash found in database")
                return false
            }
            
            let inputHash = hash(pin)
            let isValid = inputHash == storedHash
            print("🔐 SecretVault: PIN validation - stored=\(storedHash.prefix(8))..., input=\(inputHash.prefix(8))..., valid=\(isValid)")
            return isValid
        } catch {
            print("❌ SecretVault PIN validation error: \(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - Change PIN
    
    func changePIN(oldPIN: String, newPIN: String, relationshipId: String) async throws -> Bool {
        // Validate old PIN first
        let isValid = await validate(pin: oldPIN, relationshipId: relationshipId)
        
        guard isValid else {
            return false
        }
        
        // Set new PIN
        try await setPIN(newPIN, relationshipId: relationshipId)
        return true
    }
    
    // MARK: - Clear PIN (for admin/debug purposes)
    
    func clearPIN(relationshipId: String) async throws {
        try await db.collection("relationships")
            .document(relationshipId)
            .updateData([
                "secretVaultPINHash": FieldValue.delete()
            ])
        
        self.hasPIN = false
    }
    
    // MARK: - Hash
    
    private func hash(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
