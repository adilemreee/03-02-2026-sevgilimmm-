//
//  TestDataFactory.swift
//  sevgilimTests
//
//  Test verilerini oluşturmak için factory helpers
//

import Foundation
@testable import sevgilim

enum TestDataFactory {
    
    // MARK: - User
    
    static func makeUser(
        id: String = "test-user-1",
        email: String = "test@example.com",
        name: String = "Test User",
        profileImageURL: String? = nil,
        relationshipId: String? = "test-relationship-1",
        createdAt: Date = Date()
    ) -> User {
        User(
            id: id,
            email: email,
            name: name,
            profileImageURL: profileImageURL,
            relationshipId: relationshipId,
            createdAt: createdAt,
            fcmTokens: nil
        )
    }
    
    // MARK: - Relationship
    
    static func makeRelationship(
        id: String = "test-relationship-1",
        user1Id: String = "user-1",
        user2Id: String = "user-2",
        user1Name: String = "Adil",
        user2Name: String = "Emre",
        startDate: Date = Date().addingTimeInterval(-86400 * 365) // 1 yıl önce
    ) -> Relationship {
        Relationship(
            id: id,
            user1Id: user1Id,
            user2Id: user2Id,
            user1Name: user1Name,
            user2Name: user2Name,
            startDate: startDate,
            createdAt: Date(),
            themeColor: nil,
            chatClearedAt: nil
        )
    }
    
    // MARK: - Plan
    
    static func makePlan(
        id: String = "test-plan-1",
        title: String = "Test Plan",
        isCompleted: Bool = false
    ) -> Plan {
        Plan(
            id: id,
            relationshipId: "test-relationship-1",
            title: title,
            description: "Test description",
            date: Date().addingTimeInterval(86400 * 7),
            isCompleted: isCompleted,
            reminderEnabled: false,
            createdBy: "user-1",
            createdAt: Date(),
            completedAt: nil
        )
    }
    
    // MARK: - Memory
    
    static func makeMemory(
        id: String = "test-memory-1",
        title: String = "Test Memory"
    ) -> Memory {
        Memory(
            id: id,
            relationshipId: "test-relationship-1",
            title: title,
            content: "Test content",
            date: Date(),
            photoURL: nil,
            location: nil,
            tags: nil,
            createdBy: "user-1",
            createdAt: Date(),
            likes: [],
            comments: []
        )
    }
    
    // MARK: - Photo
    
    static func makePhoto(
        id: String = "test-photo-1",
        title: String? = "Test Photo"
    ) -> Photo {
        Photo(
            id: id,
            relationshipId: "test-relationship-1",
            imageURL: "https://example.com/photo.jpg",
            thumbnailURL: nil,
            videoURL: nil,
            title: title,
            date: Date(),
            location: nil,
            tags: nil,
            uploadedBy: "user-1",
            createdAt: Date(),
            mediaType: .photo,
            duration: nil
        )
    }
}

