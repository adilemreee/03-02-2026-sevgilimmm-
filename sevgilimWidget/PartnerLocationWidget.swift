//
//  PartnerLocationWidget.swift
//  sevgilimWidget
//
//  Partner Location Widget - Sevgilinizin konumunu widget'tan görün
//

import WidgetKit
import SwiftUI
import CoreLocation

// MARK: - Data Provider
struct PartnerLocationProvider: TimelineProvider {
    
    private let appGroupId = "group.com.sevgilim.shared"
    
    private var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupId)
    }
    
    func placeholder(in context: Context) -> PartnerLocationEntry {
        PartnerLocationEntry(
            date: Date(),
            partnerName: "Sevgilin",
            lastLocationName: "Ev",
            distance: 2.5,
            lastUpdated: Date().addingTimeInterval(-300),
            isNearby: false,
            isMeeting: false,
            isSharing: true
        )
    }
    
    func getSnapshot(in context: Context, completion: @escaping (PartnerLocationEntry) -> Void) {
        let entry = createEntry()
        completion(entry)
    }
    
    func getTimeline(in context: Context, completion: @escaping (Timeline<PartnerLocationEntry>) -> Void) {
        let entry = createEntry()
        
        // Her 5 dakikada bir güncelle
        let updateDate = Date().addingTimeInterval(300)
        let timeline = Timeline(entries: [entry], policy: .after(updateDate))
        completion(timeline)
    }
    
    private func createEntry() -> PartnerLocationEntry {
        let defaults = sharedDefaults
        
        let partnerName = defaults?.string(forKey: "partner_name") ?? "Sevgilin"
        let lastLocationName = defaults?.string(forKey: "partner_location_name") ?? "Bilinmiyor"
        let distance = defaults?.double(forKey: "partner_distance") ?? 0
        let lastUpdated = defaults?.object(forKey: "partner_last_updated") as? Date ?? Date()
        let isNearby = defaults?.bool(forKey: "partner_is_nearby") ?? false
        let isMeeting = defaults?.bool(forKey: "is_meeting_active") ?? false
        let isSharing = defaults?.bool(forKey: "partner_is_sharing") ?? false
        
        return PartnerLocationEntry(
            date: Date(),
            partnerName: partnerName,
            lastLocationName: lastLocationName,
            distance: distance,
            lastUpdated: lastUpdated,
            isNearby: isNearby,
            isMeeting: isMeeting,
            isSharing: isSharing
        )
    }
}

// MARK: - Entry
struct PartnerLocationEntry: TimelineEntry {
    let date: Date
    let partnerName: String
    let lastLocationName: String
    let distance: Double // km cinsinden
    let lastUpdated: Date
    let isNearby: Bool
    let isMeeting: Bool
    let isSharing: Bool
    
    var distanceText: String {
        if distance < 1 {
            return String(format: "%.0f m", distance * 1000)
        } else {
            return String(format: "%.1f km", distance)
        }
    }
    
    var timeAgoText: String {
        let minutes = Int(Date().timeIntervalSince(lastUpdated) / 60)
        if minutes < 1 {
            return "Az önce"
        } else if minutes < 60 {
            return "\(minutes) dk önce"
        } else {
            let hours = minutes / 60
            return "\(hours) saat önce"
        }
    }
}

// MARK: - Widget View
struct PartnerLocationWidgetView: View {
    var entry: PartnerLocationEntry
    @Environment(\.widgetFamily) var family
    
    // Dark radial gradient
    private var bgGradient: RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                Color(red: 0.1, green: 0.15, blue: 0.25),
                Color(red: 0.05, green: 0.08, blue: 0.15),
                Color.black
            ]),
            center: .center,
            startRadius: 5,
            endRadius: family == .systemSmall ? 120 : 200
        )
    }
    
    var body: some View {
        ZStack {
            bgGradient
            
            if family == .systemSmall {
                smallWidgetContent
            } else {
                mediumWidgetContent
            }
        }
    }
    
    // MARK: - Small Widget
    private var smallWidgetContent: some View {
        VStack(spacing: 6) {
            // Partner Avatar & Status
            ZStack {
                // Glow effect
                Circle()
                    .fill(entry.isMeeting ? Color.green : (entry.isNearby ? Color.cyan : Color.blue))
                    .blur(radius: 15)
                    .opacity(0.5)
                    .frame(width: 50, height: 50)
                
                // Avatar circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: entry.isMeeting ? [.green, .teal] :
                                   (entry.isNearby ? [.cyan, .blue] : [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 44, height: 44)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: entry.isMeeting ? .green.opacity(0.5) : .blue.opacity(0.5), radius: 8)
                
                // Location icon
                Image(systemName: entry.isMeeting ? "heart.fill" : "location.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            
            // Partner name
            Text(entry.partnerName)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            
            // Status
            if entry.isMeeting {
                meetingBadge
            } else if entry.isSharing {
                VStack(spacing: 2) {
                    // Distance
                    Text(entry.distanceText)
                        .font(.system(size: 18, weight: .heavy, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                        )
                    
                    // Location name
                    Text(entry.lastLocationName)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            } else {
                notSharingBadge
            }
            
            // Last updated
            if entry.isSharing && !entry.isMeeting {
                Text(entry.timeAgoText)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(10)
    }
    
    // MARK: - Medium Widget
    private var mediumWidgetContent: some View {
        HStack(spacing: 16) {
            // LEFT: Avatar with glow
            ZStack {
                // Outer glow
                Circle()
                    .fill(entry.isMeeting ? Color.green : (entry.isNearby ? Color.cyan : Color.blue))
                    .blur(radius: 25)
                    .opacity(0.4)
                    .frame(width: 80, height: 80)
                
                // Avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: entry.isMeeting ? [.green, .teal] :
                                   (entry.isNearby ? [.cyan, .blue] : [.blue, .purple]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 60, height: 60)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: entry.isMeeting ? .green.opacity(0.5) : .blue.opacity(0.5), radius: 10)
                
                Image(systemName: entry.isMeeting ? "heart.fill" : "location.fill")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(.white)
                
                // Pulse animation for meeting
                if entry.isMeeting {
                    Circle()
                        .stroke(Color.green, lineWidth: 2)
                        .frame(width: 70, height: 70)
                        .opacity(0.5)
                }
            }
            .frame(maxWidth: .infinity)
            
            // RIGHT: Info
            VStack(alignment: .leading, spacing: 6) {
                // Partner name
                Text(entry.partnerName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                
                if entry.isMeeting {
                    // Meeting status
                    HStack(spacing: 4) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.green)
                        Text("Buluştunuz!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.green)
                    }
                    
                    Text(entry.lastLocationName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                    
                } else if entry.isSharing {
                    // Distance with neon effect
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.swap")
                            .font(.system(size: 12))
                            .foregroundStyle(.cyan)
                        
                        Text(entry.distanceText)
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.cyan, .blue], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                    
                    // Location
                    HStack(spacing: 4) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                        Text(entry.lastLocationName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    
                    // Last updated
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                        Text(entry.timeAgoText)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.5))
                    
                } else {
                    // Not sharing
                    notSharingBadge
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
    
    // MARK: - Meeting Badge
    private var meetingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 10))
            Text("Buluştunuz!")
                .font(.system(size: 10, weight: .bold))
        }
        .foregroundStyle(.green)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.green.opacity(0.2))
                .overlay(
                    Capsule()
                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                )
        )
    }
    
    // MARK: - Not Sharing Badge
    private var notSharingBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: "location.slash")
                .font(.system(size: 10))
            Text("Konum kapalı")
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(.white.opacity(0.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.1))
        )
    }
}

// MARK: - Widget Configuration
struct PartnerLocationWidget: Widget {
    let kind: String = "PartnerLocationWidget"
    
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PartnerLocationProvider()) { entry in
            if #available(iOS 17.0, *) {
                PartnerLocationWidgetView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.black
                    }
            } else {
                PartnerLocationWidgetView(entry: entry)
            }
        }
        .configurationDisplayName("Sevgilin Nerede? 📍")
        .description("Sevgilinizin konumunu ve mesafesini görün")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

// MARK: - Preview
#Preview(as: .systemSmall) {
    PartnerLocationWidget()
} timeline: {
    PartnerLocationEntry(
        date: .now,
        partnerName: "Ayça",
        lastLocationName: "Ofis",
        distance: 2.5,
        lastUpdated: Date().addingTimeInterval(-180),
        isNearby: false,
        isMeeting: false,
        isSharing: true
    )
    PartnerLocationEntry(
        date: .now,
        partnerName: "Ayça",
        lastLocationName: "Kafe",
        distance: 0.05,
        lastUpdated: Date(),
        isNearby: true,
        isMeeting: true,
        isSharing: true
    )
}

#Preview(as: .systemMedium) {
    PartnerLocationWidget()
} timeline: {
    PartnerLocationEntry(
        date: .now,
        partnerName: "Ayça",
        lastLocationName: "Ev",
        distance: 5.2,
        lastUpdated: Date().addingTimeInterval(-600),
        isNearby: false,
        isMeeting: false,
        isSharing: true
    )
    PartnerLocationEntry(
        date: .now,
        partnerName: "Ayça",
        lastLocationName: "Starbucks",
        distance: 0.02,
        lastUpdated: Date(),
        isNearby: true,
        isMeeting: true,
        isSharing: true
    )
}
