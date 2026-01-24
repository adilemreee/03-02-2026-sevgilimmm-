//
//  MockSimpleServices.swift
//  sevgilimTests
//
//  Simple mock services for Memory, Photo, Note, Plan, Surprise, SpecialDay, Message, Mood
//

import Foundation
import Combine
@testable import sevgilim

// MARK: - MockMemoryService

@MainActor
final class MockMemoryService: ObservableObject {
    @Published var memories: [Memory] = []
    @Published var isLoading = false
    
    func listenToMemories(relationshipId: String) {}
    func stopListening() {}
}

// MARK: - MockPhotoService

@MainActor
final class MockPhotoService: ObservableObject {
    @Published var photos: [Photo] = []
    @Published var isLoading = false
    
    func listenToPhotos(relationshipId: String) {}
    func stopListening() {}
}

// MARK: - MockNoteService

@MainActor
final class MockNoteService: ObservableObject {
    @Published var notes: [Note] = []
    @Published var isLoading = false
    
    func listenToNotes(relationshipId: String) {}
    func stopListening() {}
}

// MARK: - MockPlanService

@MainActor
final class MockPlanService: ObservableObject {
    @Published var plans: [Plan] = []
    @Published var isLoading = false
    
    func listenToPlans(relationshipId: String) {}
    func stopListening() {}
}

// MARK: - MockSurpriseService

@MainActor
final class MockSurpriseService: ObservableObject {
    @Published var surprises: [Surprise] = []
    @Published var isLoading = false
    
    func nextUpcomingSurpriseForUser(userId: String) -> Surprise? { nil }
    func listenToSurprises(relationshipId: String, userId: String) {}
    func stopListening() {}
    func markAsOpened(_ surprise: Surprise) async throws {}
}

// MARK: - MockSpecialDayService

@MainActor
final class MockSpecialDayService: ObservableObject {
    @Published var specialDays: [SpecialDay] = []
    
    private var mockNextSpecialDay: SpecialDay?
    
    init(nextSpecialDay: SpecialDay? = nil) {
        self.mockNextSpecialDay = nextSpecialDay
    }
    
    func nextSpecialDay() -> SpecialDay? { mockNextSpecialDay }
    func listenToSpecialDays(relationshipId: String) {}
    func stopListening() {}
}

// MARK: - MockMessageService

@MainActor
final class MockMessageService: ObservableObject {
    @Published var messages: [Message] = []
    @Published var partnerIsTyping = false
    @Published var unreadMessageCount = 0
    
    func listenToMessages(relationshipId: String) {}
    func listenToUnreadMessagesCount(relationshipId: String, currentUserId: String) {}
    func stopListening() {}
}

// MARK: - MockMoodService

@MainActor
final class MockMoodService: ObservableObject {
    @Published private(set) var moodsByUser: [String: MoodStatus] = [:]
    @Published var isLoading = false
    
    func mood(for userId: String) -> MoodStatus? { moodsByUser[userId] }
    func listenToMoodStatuses(relationshipId: String) {}
    func setMood(relationshipId: String, userId: String, mood: MoodFeeling) async throws {}
}
