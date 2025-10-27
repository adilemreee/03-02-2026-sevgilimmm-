//
//  SecretVaultPINManager.swift
//  sevgilim
//

import Foundation
import CryptoKit

final class SecretVaultPINManager {
    static let shared = SecretVaultPINManager()
    
    private let pinKey = "secretVaultPINHash"
    private let defaults: UserDefaults
    
    private init(userDefaults: UserDefaults = .standard) {
        self.defaults = userDefaults
    }
    
    func hasPIN() -> Bool {
        defaults.string(forKey: pinKey) != nil
    }
    
    func setPIN(_ pin: String) {
        defaults.set(hash(pin), forKey: pinKey)
    }
    
    func validate(pin: String) -> Bool {
        guard let storedHash = defaults.string(forKey: pinKey) else {
            return false
        }
        return hash(pin) == storedHash
    }
    
    func clearPIN() {
        defaults.removeObject(forKey: pinKey)
    }
    
    private func hash(_ pin: String) -> String {
        let data = Data(pin.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }
}
