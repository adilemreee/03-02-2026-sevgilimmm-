//
//  SpecialDay.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

struct SpecialDay: Identifiable, Codable {
    var id: String? = nil
    let relationshipId: String
    let title: String
    let date: Date
    let category: SpecialDayCategory
    let icon: String
    let color: String
    let notes: String?
    let isRecurring: Bool // Her yıl tekrarlanacak mı?
    let createdAt: Date
    let createdBy: String
    
    var daysUntil: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        // Eğer recurring ise, bu yılki tarihi hesapla
        var targetDate = date
        if isRecurring {
            let currentYear = calendar.component(.year, from: today)
            var components = calendar.dateComponents([.month, .day], from: date)
            components.year = currentYear
            
            if let thisYearDate = calendar.date(from: components) {
                // Eğer bu yılki tarih geçtiyse, gelecek yıl için hesapla
                if thisYearDate < today {
                    components.year = currentYear + 1
                    if let nextYearDate = calendar.date(from: components) {
                        targetDate = nextYearDate
                    }
                } else {
                    targetDate = thisYearDate
                }
            }
        }
        
        let targetDay = calendar.startOfDay(for: targetDate)
        let days = calendar.dateComponents([.day], from: today, to: targetDay).day ?? 0
        return max(0, days)
    }
    
    var isToday: Bool {
        let calendar = Calendar.current
        if isRecurring {
            let todayComponents = calendar.dateComponents([.month, .day], from: Date())
            let dateComponents = calendar.dateComponents([.month, .day], from: date)
            return todayComponents.month == dateComponents.month &&
                   todayComponents.day == dateComponents.day
        } else {
            return calendar.isDateInToday(date)
        }
    }
    
    var isPast: Bool {
        if isRecurring {
            return false // Recurring events are never past
        }
        return date < Date()
    }
    
    var displayDate: Date {
        if isRecurring {
            let calendar = Calendar.current
            let today = Date()
            let currentYear = calendar.component(.year, from: today)
            var components = calendar.dateComponents([.month, .day], from: date)
            components.year = currentYear
            
            if let thisYearDate = calendar.date(from: components) {
                if thisYearDate < today {
                    components.year = currentYear + 1
                    return calendar.date(from: components) ?? date
                }
                return thisYearDate
            }
        }
        return date
    }
}

enum SpecialDayCategory: String, Codable, CaseIterable {
    case anniversary = "Yıldönümü"
    case birthday = "Doğum Günü"
    case firstMeet = "İlk Buluşma"
    case firstKiss = "İlk Öpücük"
    case engagement = "Nişan"
    case wedding = "Düğün"
    case vacation = "Tatil"
    case achievement = "Başarı"
    case surprise = "Sürpriz"
    case other = "Diğer"
    
    var icon: String {
        switch self {
        case .anniversary: return "heart.circle.fill"
        case .birthday: return "gift.fill"
        case .firstMeet: return "eye.fill"
        case .firstKiss: return "mouth.fill"
        case .engagement: return "ring.circle.fill"
        case .wedding: return "heart.circle"
        case .vacation: return "airplane.circle.fill"
        case .achievement: return "star.circle.fill"
        case .surprise: return "sparkles"
        case .other: return "calendar.circle.fill"
        }
    }
    
    var defaultColor: String {
        switch self {
        case .anniversary: return "red"
        case .birthday: return "orange"
        case .firstMeet: return "pink"
        case .firstKiss: return "purple"
        case .engagement: return "blue"
        case .wedding: return "indigo"
        case .vacation: return "cyan"
        case .achievement: return "yellow"
        case .surprise: return "mint"
        case .other: return "gray"
        }
    }
}
