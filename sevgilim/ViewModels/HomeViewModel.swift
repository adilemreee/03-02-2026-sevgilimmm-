//
//  HomeViewModel.swift
//  sevgilim
//

import Foundation
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    private let authService: AuthenticationService
    private let relationshipService: RelationshipService
    private let memoryService: MemoryService
    private let photoService: PhotoService
    private let noteService: NoteService
    private let planService: PlanService
    private let surpriseService: SurpriseService
    private let specialDayService: SpecialDayService
    private let messageServiceRef: MessageService
    private let moodService: MoodService
    
    private var cancellables: Set<AnyCancellable> = []
    
    init(
        authService: AuthenticationService,
        relationshipService: RelationshipService,
        memoryService: MemoryService,
        photoService: PhotoService,
        noteService: NoteService,
        planService: PlanService,
        surpriseService: SurpriseService,
        specialDayService: SpecialDayService,
        messageService: MessageService,
        moodService: MoodService
    ) {
        self.authService = authService
        self.relationshipService = relationshipService
        self.memoryService = memoryService
        self.photoService = photoService
        self.noteService = noteService
        self.planService = planService
        self.surpriseService = surpriseService
        self.specialDayService = specialDayService
        self.messageServiceRef = messageService
        self.moodService = moodService
        
        observeServices()
    }
    
    var currentUser: User? {
        authService.currentUser
    }
    
    var relationship: Relationship? {
        relationshipService.currentRelationship
    }
    
    var photosCount: Int {
        photoService.photos.count
    }
    
    var memoriesCount: Int {
        memoryService.memories.count
    }
    
    var notesCount: Int {
        noteService.notes.count
    }
    
    var plansCount: Int {
        planService.plans.count
    }
    
    var activePlans: [Plan] {
        planService.plans.filter { !$0.isCompleted }
    }
    
    var completedPlans: [Plan] {
        planService.plans.filter { $0.isCompleted }
    }
    
    var recentMemories: [Memory] {
        Array(memoryService.memories.prefix(3))
    }
    
    var nextSpecialDay: SpecialDay? {
        specialDayService.nextSpecialDay()
    }
    
    func nextUpcomingSurprise(for userId: String) -> Surprise? {
        surpriseService.nextUpcomingSurpriseForUser(userId: userId)
    }
    
    var messageService: MessageService {
        messageServiceRef
    }

    var currentMoodStatus: MoodStatus? {
        guard let userId = currentUser?.id else { return nil }
        return moodService.mood(for: userId)
    }
    
    var partnerMoodStatus: MoodStatus? {
        guard let userId = currentUser?.id,
              let relationship = relationship else { return nil }
        let partnerId = relationship.partnerId(for: userId)
        return moodService.mood(for: partnerId)
    }
    
    func updateMood(to mood: MoodFeeling) async {
        guard let relationshipId = authService.currentUser?.relationshipId,
              let userId = authService.currentUser?.id else {
            return
        }
        
        do {
            try await moodService.setMood(relationshipId: relationshipId, userId: userId, mood: mood)
        } catch {
            print("❌ Mood update failed: \(error.localizedDescription)")
        }
    }
    
    func markSurpriseAsOpened(_ surprise: Surprise) async throws {
        try await surpriseService.markAsOpened(surprise)
    }
    
    func startListeners() {
        guard let relationshipId = authService.currentUser?.relationshipId,
              let userId = authService.currentUser?.id else {
            return
        }
        
        relationshipService.listenToRelationship(relationshipId: relationshipId)
        specialDayService.listenToSpecialDays(relationshipId: relationshipId)
        messageServiceRef.listenToUnreadMessagesCount(relationshipId: relationshipId, currentUserId: userId)
        moodService.listenToMoodStatuses(relationshipId: relationshipId)
    }
    
    private func observeServices() {
        [
            authService.objectWillChange,
            relationshipService.objectWillChange,
            memoryService.objectWillChange,
            photoService.objectWillChange,
            noteService.objectWillChange,
            planService.objectWillChange,
            surpriseService.objectWillChange,
            specialDayService.objectWillChange,
            messageServiceRef.objectWillChange,
            moodService.objectWillChange
        ].forEach { publisher in
            publisher
                .receive(on: RunLoop.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        }
    }
}
