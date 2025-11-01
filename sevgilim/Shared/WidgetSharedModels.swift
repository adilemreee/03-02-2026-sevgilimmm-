//
//  WidgetSharedModels.swift
//  sevgilim
//
//  Shared models/constants between the app target and WidgetKit extension.
//

import Foundation

public enum WidgetSharedConstants {
    /// Update this to match the App Group identifier configured in the project.
    public static let appGroupID = "group.com.example.sevgilim"
    
    /// Storage key used for the aggregated widget snapshot.
    public static let snapshotStorageKey = "widget.snapshot"
    
    /// Widget kinds used when reloading timelines.
    public static let moodWidgetKind = "MoodStatusWidget"
    public static let relationshipWidgetKind = "RelationshipCounterWidget"
    public static let surpriseWidgetKind = "SurpriseReminderWidget"
}

public struct WidgetSnapshot: Codable, Equatable {
    public let generatedAt: Date
    public var mood: WidgetMoodSnapshot?
    public var relationship: WidgetRelationshipSnapshot?
    public var surprise: WidgetSurpriseSnapshot?
    
    public init(
        generatedAt: Date = Date(),
        mood: WidgetMoodSnapshot? = nil,
        relationship: WidgetRelationshipSnapshot? = nil,
        surprise: WidgetSurpriseSnapshot? = nil
    ) {
        self.generatedAt = generatedAt
        self.mood = mood
        self.relationship = relationship
        self.surprise = surprise
    }
}

public struct WidgetMoodSnapshot: Codable, Equatable {
    public let userName: String
    public let userEmoji: String
    public let userMessage: String
    public let partnerName: String
    public let partnerEmoji: String
    public let partnerMessage: String
    
    public init(
        userName: String,
        userEmoji: String,
        userMessage: String,
        partnerName: String,
        partnerEmoji: String,
        partnerMessage: String
    ) {
        self.userName = userName
        self.userEmoji = userEmoji
        self.userMessage = userMessage
        self.partnerName = partnerName
        self.partnerEmoji = partnerEmoji
        self.partnerMessage = partnerMessage
    }
    
    public static let placeholder = WidgetMoodSnapshot(
        userName: "Sen",
        userEmoji: "🙂",
        userMessage: "Nasılım?",
        partnerName: "Partnerin",
        partnerEmoji: "🙂",
        partnerMessage: "Nasıl?"
    )
}

public struct WidgetRelationshipSnapshot: Codable, Equatable {
    public let coupleTitle: String
    public let daysTogether: Int
    public let startDate: Date
    public let nextSpecialDayTitle: String?
    public let nextSpecialDayDate: Date?
    public let nextSpecialDayDaysRemaining: Int?
    
    public init(
        coupleTitle: String,
        daysTogether: Int,
        startDate: Date,
        nextSpecialDayTitle: String?,
        nextSpecialDayDate: Date?,
        nextSpecialDayDaysRemaining: Int?
    ) {
        self.coupleTitle = coupleTitle
        self.daysTogether = daysTogether
        self.startDate = startDate
        self.nextSpecialDayTitle = nextSpecialDayTitle
        self.nextSpecialDayDate = nextSpecialDayDate
        self.nextSpecialDayDaysRemaining = nextSpecialDayDaysRemaining
    }
    
    public static let placeholder = WidgetRelationshipSnapshot(
        coupleTitle: "A & B",
        daysTogether: 365,
        startDate: Date().addingTimeInterval(-86400 * 365),
        nextSpecialDayTitle: "Yıldönümü",
        nextSpecialDayDate: Date().addingTimeInterval(86400 * 5),
        nextSpecialDayDaysRemaining: 5
    )
}

public struct WidgetSurpriseSnapshot: Codable, Equatable {
    public let surpriseID: String
    public let title: String
    public let isLocked: Bool
    public let revealDate: Date
    public let createdByName: String
    public let imageURL: String?
    
    public init(
        surpriseID: String,
        title: String,
        isLocked: Bool,
        revealDate: Date,
        createdByName: String,
        imageURL: String?
    ) {
        self.surpriseID = surpriseID
        self.title = title
        self.isLocked = isLocked
        self.revealDate = revealDate
        self.createdByName = createdByName
        self.imageURL = imageURL
    }
    
    public static let placeholder = WidgetSurpriseSnapshot(
        surpriseID: "preview",
        title: "Sürpriz hazır!",
        isLocked: true,
        revealDate: Date().addingTimeInterval(3600 * 12),
        createdByName: "Partnerin",
        imageURL: nil
    )
}
