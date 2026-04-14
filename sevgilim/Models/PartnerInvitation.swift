//
//  PartnerInvitation.swift
//  sevgilim
//

import Foundation

struct PartnerInvitation: Identifiable, Codable {
    var id: String? = nil
    var senderUserId: String
    var senderName: String
    var senderEmail: String
    var receiverEmail: String
    var relationshipStartDate: Date
    var status: InvitationStatus
    var createdAt: Date
    var respondedAt: Date?
    
    enum InvitationStatus: String, Codable {
        case pending
        case accepted
        case rejected
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case senderUserId
        case senderName
        case senderEmail
        case receiverEmail
        case relationshipStartDate
        case status
        case createdAt
        case respondedAt
    }
}
