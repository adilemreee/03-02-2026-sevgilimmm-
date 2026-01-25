//
//  MeetingHistoryView.swift
//  sevgilim
//
//  Buluşma geçmişi listesi görünümü
//

import SwiftUI
import MapKit

struct MeetingHistoryView: View {
    @Environment(\.dismiss) private var dismiss
    
    let meetings: [MeetingEvent]
    let onDelete: (MeetingEvent) -> Void
    
    @State private var selectedMeeting: MeetingEvent?
    @State private var showMap = false
    @State private var searchText = ""
    
    var filteredMeetings: [MeetingEvent] {
        if searchText.isEmpty {
            return meetings
        }
        return meetings.filter { meeting in
            meeting.placeName?.localizedCaseInsensitiveContains(searchText) == true ||
            meeting.address?.localizedCaseInsensitiveContains(searchText) == true
        }
    }
    
    var groupedMeetings: [(String, [MeetingEvent])] {
        let grouped = Dictionary(grouping: filteredMeetings) { meeting in
            formatSectionDate(meeting.startTime)
        }
        return grouped.sorted { $0.key > $1.key }
    }
    
    // İstatistikler
    var totalDuration: TimeInterval {
        meetings.reduce(0) { $0 + $1.calculatedDuration }
    }
    
    var body: some View {
        NavigationView {
            Group {
                if meetings.isEmpty {
                    emptyStateView
                } else {
                    listContent
                }
            }
            .navigationTitle("Buluşma Geçmişi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Konum ara...")
            .sheet(item: $selectedMeeting) { meeting in
                MeetingDetailView(meeting: meeting)
            }
        }
    }
    
    // MARK: - List Content
    
    private var listContent: some View {
        List {
            // İstatistik kartı
            Section {
                statisticsCard
            }
            
            // Buluşmalar
            ForEach(groupedMeetings, id: \.0) { sectionTitle, sectionMeetings in
                Section(header: Text(sectionTitle)) {
                    ForEach(sectionMeetings) { meeting in
                        MeetingRowView(meeting: meeting)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                selectedMeeting = meeting
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    onDelete(meeting)
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }
    
    // MARK: - Statistics Card
    
    private var statisticsCard: some View {
        VStack(spacing: 16) {
            HStack(spacing: 20) {
                StatisticItem(
                    icon: "heart.fill",
                    value: "\(meetings.count)",
                    label: "Buluşma",
                    color: .pink
                )
                
                Divider()
                    .frame(height: 40)
                
                StatisticItem(
                    icon: "clock.fill",
                    value: formattedTotalDuration,
                    label: "Toplam Süre",
                    color: .blue
                )
                
                Divider()
                    .frame(height: 40)
                
                StatisticItem(
                    icon: "chart.bar.fill",
                    value: formattedAverageDuration,
                    label: "Ortalama",
                    color: .green
                )
            }
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "heart.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Henüz Buluşma Yok")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text("Sevgilinizle buluştuğunuzda burada görünecek")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - Helpers
    
    private func formatSectionDate(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Bugün"
        } else if calendar.isDateInYesterday(date) {
            return "Dün"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return "Bu Hafta"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .month) {
            return "Bu Ay"
        } else {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "tr_TR")
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }
    }
    
    private var formattedTotalDuration: String {
        let hours = Int(totalDuration / 3600)
        let minutes = Int((totalDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if hours > 0 {
            return "\(hours)sa \(minutes)dk"
        } else {
            return "\(minutes)dk"
        }
    }
    
    private var formattedAverageDuration: String {
        guard !meetings.isEmpty else { return "0dk" }
        
        let average = totalDuration / Double(meetings.count)
        let minutes = Int(average / 60)
        
        if minutes >= 60 {
            return "\(minutes / 60)sa \(minutes % 60)dk"
        } else {
            return "\(minutes)dk"
        }
    }
}

// MARK: - Meeting Row View
struct MeetingRowView: View {
    let meeting: MeetingEvent
    
    var body: some View {
        HStack(spacing: 12) {
            // Tarih ikonu
            VStack(spacing: 2) {
                Text(dayOfMonth)
                    .font(.title2)
                    .fontWeight(.bold)
                Text(monthAbbr)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(width: 44)
            
            // Dikey çizgi
            Rectangle()
                .fill(Color.pink.opacity(0.5))
                .frame(width: 3)
                .cornerRadius(1.5)
            
            // Detaylar
            VStack(alignment: .leading, spacing: 4) {
                // Konum adı
                Text(meeting.locationDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // Saat aralığı
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption2)
                    Text(timeRange)
                        .font(.caption)
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Süre
            VStack(alignment: .trailing, spacing: 2) {
                Text(meeting.shortFormattedDuration)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.pink)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var dayOfMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: meeting.startTime)
    }
    
    private var monthAbbr: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.dateFormat = "MMM"
        return formatter.string(from: meeting.startTime)
    }
    
    private var timeRange: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        
        let start = formatter.string(from: meeting.startTime)
        
        if let endTime = meeting.endTime {
            let end = formatter.string(from: endTime)
            return "\(start) - \(end)"
        }
        
        return start
    }
}

// MARK: - Statistic Item
struct StatisticItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text(value)
                .font(.headline)
                .fontWeight(.bold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Meeting Detail View
struct MeetingDetailView: View {
    @Environment(\.dismiss) private var dismiss
    
    let meeting: MeetingEvent
    
    @State private var mapRegion: MKCoordinateRegion
    
    init(meeting: MeetingEvent) {
        self.meeting = meeting
        self._mapRegion = State(initialValue: MKCoordinateRegion(
            center: meeting.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Harita
                    Map(coordinateRegion: $mapRegion, annotationItems: [meeting]) { item in
                        MapAnnotation(coordinate: item.coordinate) {
                            VStack(spacing: 0) {
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(8)
                                    .background(Color.pink)
                                    .clipShape(Circle())
                                
                                Triangle()
                                    .fill(Color.pink)
                                    .frame(width: 12, height: 8)
                                    .rotationEffect(.degrees(180))
                                    .offset(y: -2)
                            }
                        }
                    }
                    .frame(height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                    
                    // Detay kartları
                    VStack(spacing: 12) {
                        DetailCard(icon: "mappin.circle.fill", title: "Konum", value: meeting.locationDescription, color: .pink)
                        
                        if let address = meeting.address {
                            DetailCard(icon: "location.fill", title: "Adres", value: address, color: .blue)
                        }
                        
                        DetailCard(icon: "calendar", title: "Tarih", value: meeting.formattedStartDate, color: .orange)
                        
                        DetailCard(icon: "clock.fill", title: "Süre", value: meeting.formattedDuration, color: .green)
                        
                        if meeting.minDistance > 0 {
                            DetailCard(icon: "ruler", title: "Min Mesafe", value: "\(Int(meeting.minDistance))m", color: .purple)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Buluşma Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Detail Card
struct DetailCard: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview
#Preview {
    MeetingHistoryView(
        meetings: MeetingEvent.sampleData,
        onDelete: { _ in }
    )
}
