//
//  MeetingBannerView.swift
//  sevgilim
//
//  Buluşma bildirimi banner - Animasyonlu, buluşma süresi göstergesi
//

import SwiftUI

struct MeetingBannerView: View {
    let meeting: MeetingEvent?
    let duration: TimeInterval
    let distance: Double?
    let onDismiss: () -> Void
    let onEndMeeting: () -> Void
    
    @State private var isAnimating = false
    @State private var showConfirmEnd = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Ana banner
            HStack(spacing: 12) {
                // Animasyonlu kalp ikonu
                ZStack {
                    // Pulse animasyonu
                    ForEach(0..<3) { index in
                        Circle()
                            .stroke(Color.pink.opacity(0.3), lineWidth: 2)
                            .frame(width: 50, height: 50)
                            .scaleEffect(isAnimating ? 1.5 + Double(index) * 0.3 : 1)
                            .opacity(isAnimating ? 0 : 0.5)
                            .animation(
                                .easeOut(duration: 1.5)
                                .repeatForever(autoreverses: false)
                                .delay(Double(index) * 0.3),
                                value: isAnimating
                            )
                    }
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.pink, .red],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "heart.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white)
                        .scaleEffect(isAnimating ? 1.1 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true),
                            value: isAnimating
                        )
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Buluştunuz! 💕")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    // Konum adı
                    if let placeName = meeting?.placeName {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.caption)
                            Text(placeName)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    }
                    
                    // Süre ve mesafe
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "clock.fill")
                                .font(.caption)
                            Text(formattedDuration)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.pink)
                        
                        if let dist = distance {
                            HStack(spacing: 4) {
                                Image(systemName: "ruler")
                                    .font(.caption)
                                Text(formattedDistance(dist))
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Kapatma butonu
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(.ultraThinMaterial, in: Circle())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .pink.opacity(0.3), radius: 10, x: 0, y: 5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        LinearGradient(
                            colors: [.pink.opacity(0.5), .red.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            
            // Buluşmayı bitir butonu
            if showConfirmEnd {
                Button {
                    onEndMeeting()
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Buluşmayı Bitir")
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(.red, in: Capsule())
                }
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            isAnimating = true
        }
        .onTapGesture {
            withAnimation(.spring()) {
                showConfirmEnd.toggle()
            }
        }
    }
    
    // MARK: - Helpers
    
    private var formattedDuration: String {
        let hours = Int(duration / 3600)
        let minutes = Int((duration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
    
    private func formattedDistance(_ distance: Double) -> String {
        if distance < 1000 {
            return "\(Int(distance))m"
        } else {
            return String(format: "%.1f km", distance / 1000)
        }
    }
}

// MARK: - Compact Meeting Banner (Widget için)
struct CompactMeetingBannerView: View {
    let isInMeeting: Bool
    let duration: TimeInterval
    let partnerName: String
    
    var body: some View {
        if isInMeeting {
            HStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .foregroundColor(.pink)
                
                Text("\(partnerName) ile birliktesiniz")
                    .font(.caption)
                
                Text("•")
                    .foregroundColor(.secondary)
                
                Text(formattedDuration)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.pink)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.pink.opacity(0.1), in: Capsule())
        }
    }
    
    private var formattedDuration: String {
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)dk"
        } else {
            let hours = minutes / 60
            let mins = minutes % 60
            return "\(hours)sa \(mins)dk"
        }
    }
}

// MARK: - Preview
#Preview("Meeting Banner") {
    VStack {
        MeetingBannerView(
            meeting: MeetingEvent(
                id: "1",
                relationshipId: "rel1",
                user1Id: "user1",
                user2Id: "user2",
                latitude: 41.0082,
                longitude: 28.9784,
                placeName: "Starbucks Kadıköy",
                address: "Kadıköy, İstanbul"
            ),
            duration: 3725,
            distance: 15,
            onDismiss: {},
            onEndMeeting: {}
        )
        .padding()
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}

#Preview("Compact Banner") {
    CompactMeetingBannerView(
        isInMeeting: true,
        duration: 1800,
        partnerName: "Ayşe"
    )
}
