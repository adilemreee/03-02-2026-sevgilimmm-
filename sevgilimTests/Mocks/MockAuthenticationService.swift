//
//  MockAuthenticationService.swift
//  sevgilimTests
//
//  AuthenticationService mock for testing
//

import Foundation
import Combine
@testable import sevgilim

@MainActor
final class MockAuthenticationService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var errorMessage: String?
    
    // Test kontrolü için
    var signInCalled = false
    var signOutCalled = false
    var lastSignInEmail: String?
    var shouldThrowError = false
    
    init(user: User? = nil) {
        self.currentUser = user
        self.isAuthenticated = user != nil
    }
    
    func signIn(email: String, password: String) async throws {
        signInCalled = true
        lastSignInEmail = email
        
        if shouldThrowError {
            throw NSError(domain: "TestError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Test auth error"])
        }
        
        currentUser = TestDataFactory.makeUser(email: email)
        isAuthenticated = true
    }
    
    func signOut() {
        signOutCalled = true
        currentUser = nil
        isAuthenticated = false
    }
    
    func checkAuthStatus() {
        // No-op for tests
    }
}
