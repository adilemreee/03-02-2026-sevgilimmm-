//
//  PartnerLocationHomeCard.swift
//  sevgilim
//
//  Ana ekranda partner konumunu gösteren kart
//

import SwiftUI
import CoreLocation

struct PartnerLocationHomeCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @StateObject private var locationService = LocationService.shared
    
    let partnerName: String
    let onTap: () -> Void
    
    private var partnerLocation: UserLocation? {
        locationService.partnerLocation
    }
    
    private var distance: Double? {
        locationService.distanceToPartner
    }
    
    private var isMeeting: Bool {
        locationService.isMeetingActive
    }
    
    private var isSharing: Bool {
        partnerLocation?.isSharing ?? false
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Header
                HStack {
                    // Icon with glow
                    ZStack {
                        Circle()
                            .fill(isMeeting ? Color.green : Color.cyan)
                            .blur(radius: 10)
                            .opacity(0.4)
                            .frame(width: 40, height: 40)
                        
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: isMeeting ? [.green, .teal] : [.cyan, .blue],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 36, height: 36)
                        
                        Image(systemName: isMeeting ? "heart.fill" : "location.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(partnerName) Nerede?")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        
                        if isMeeting {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 10))
                                Text("Buluştunuz! 💕")
                                    .font(.system(size: 12, weight: .semibold))
                            }
                            .foregroundStyle(.green)
                        } else if isSharing {
                            Text("Konum paylaşıyor")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        } else {
                            Text("Konum kapalı")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Spacer()
                    
                    // Distance or Status
                    if isSharing, let distance = distance {
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(formatDistance(distance))
                                .font(.system(size: 20, weight: .heavy, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.cyan, .blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                            
                            Text("uzaklıkta")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
                
                // Location info
                if isSharing, let location = partnerLocation {
                    HStack(spacing: 8) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                        
                        Text(location.placeName ?? "Konum alınıyor...")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                        
                        Spacer()
                        
                        // Last updated
                        Text(timeAgo(from: location.lastUpdated))
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.black.opacity(0.3),
                                Color.black.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        isMeeting ? Color.green.opacity(0.5) : Color.cyan.opacity(0.3),
                                        Color.clear
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func formatDistance(_ meters: Double) -> String {
        if meters < 1000 {
            return String(format: "%.0f m", meters)
        } else {
            return String(format: "%.1f km", meters / 1000)
        }
    }
    
    private func timeAgo(from date: Date) -> String {
        let minutes = Int(Date().timeIntervalSince(date) / 60)
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

#Preview {
    ZStack {
        Color.black.opacity(0.9)
        
        VStack(spacing: 20) {
            PartnerLocationHomeCard(
                partnerName: "Ayça",
                onTap: {}
            )
            .environmentObject(ThemeManager())
        }
        .padding()
    }
}
