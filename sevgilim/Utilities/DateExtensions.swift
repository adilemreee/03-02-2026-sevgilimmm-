//
//  DateExtensions.swift
//  sevgilim
//

import Foundation

extension Date {
    func timeAgo() -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: self, to: now)
        
        if let year = components.year, year > 0 {
            return year == 1 ? "1 yıl önce" : "\(year) yıl önce"
        }
        
        if let month = components.month, month > 0 {
            return month == 1 ? "1 ay önce" : "\(month) ay önce"
        }
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Dün" : "\(day) gün önce"
        }
        
        if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 saat önce" : "\(hour) saat önce"
        }
        
        if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 dakika önce" : "\(minute) dakika önce"
        }
        
        return "Az önce"
    }
    
    // Kısa zaman metni (story görülme durumu için)
    var timeAgoShort: String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .minute], from: self, to: now)
        
        if let hour = components.hour, hour > 0 {
            return "\(hour)s"
        }
        
        if let minute = components.minute, minute > 0 {
            return "\(minute)dk"
        }
        
        return "şimdi"
    }
    
    func daysBetween(_ endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self, to: endDate)
        return components.day ?? 0
    }
    
    func formattedDifference(from startDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: startDate, to: self)
        
        var parts: [String] = []
        
        if let years = components.year, years > 0 {
            parts.append("\(years) yıl")
        }
        
        if let months = components.month, months > 0 {
            parts.append("\(months) ay")
        }
        
        if let days = components.day, days > 0 {
            parts.append("\(days) gün")
        }
        
        return parts.isEmpty ? "Bugün" : parts.joined(separator: " ")
    }
}

extension DateFormatter {
    static let displayFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }()
    
    static let fullFormat: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "tr_TR")
        return formatter
    }()
}

