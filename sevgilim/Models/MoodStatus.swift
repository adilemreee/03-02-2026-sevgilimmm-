//
//  MoodStatus.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

enum MoodFeeling: String, CaseIterable, Codable, Identifiable {
    case happy
    case missing
    case sad
    case excited
    case tired
    case love
    case horny

    var id: String { rawValue }

    var title: String {
        switch self {
        case .happy:
            return "Mutlu"
        case .missing:
            return "Özledim"
        case .sad:
            return "Üzgün"
        case .excited:
            return "Heyecanlı"
        case .tired:
            return "Yorgun"
        case .love:
            return "Aşık"
        case .horny:
            return "Azgıntılı"
        }
    }

    var emoji: String {
        switch self {
        case .happy:
            return "😊"
        case .missing:
            return "🥺"
        case .sad:
            return "😔"
        case .excited:
            return "🤩"
        case .tired:
            return "🥱"
        case .love:
            return "😍"
        case .horny:
            return "😈"
        }
    }
}

struct MoodStatus: Identifiable, Codable {
    var id: String? = nil
    var relationshipId: String
    var userId: String
    var moodRawValue: String
    var updatedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case relationshipId
        case userId
        case moodRawValue = "mood"
        case updatedAt
    }

    var mood: MoodFeeling? {
        MoodFeeling(rawValue: moodRawValue)
    }
}
