//
//  SpecialDaysView.swift
//  sevgilim
//

import SwiftUI

struct SpecialDaysView: View {
    @EnvironmentObject var specialDayService: SpecialDayService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddSpecialDay = false
    @State private var searchText = ""
    @State private var selectedSpecialDay: SpecialDay?
    
    var filteredDays: [SpecialDay] {
        if searchText.isEmpty {
            return specialDayService.specialDays
        } else {
            return specialDayService.specialDays.filter { day in
                day.title.localizedCaseInsensitiveContains(searchText) ||
                day.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                (day.notes?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var upcomingDays: [SpecialDay] {
        filteredDays.filter { !$0.isPast }.sorted { $0.daysUntil < $1.daysUntil }
    }
    
    var pastDays: [SpecialDay] {
        filteredDays.filter { $0.isPast && !$0.isRecurring }.sorted { $0.date > $1.date }
    }
    
    private var headerSubtitle: String {
        searchText.isEmpty ?
        "Takviminizde sakladığınız tarihler" :
        "Aradığın özel günü daha hızlı bul"
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.3),
                        themeManager.currentTheme.secondaryColor.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    SectionHeroHeader(
                        systemImage: "calendar.badge.clock",
                        iconColors: [.pink, .purple],
                        title: "Özel Günler",
                        subtitle: headerSubtitle,
                        countValue: "\(upcomingDays.count)",
                        countTint: .pink,
                        countLabel: "Yaklaşan"
                    )
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Özel gün ara...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)
                    
                    // Content
                    if specialDayService.specialDays.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Henüz özel gün eklenmemiş")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("İlk özel gününüzü ekleyin")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: { showingAddSpecialDay = true }) {
                                Label("İlk Özel Günü Ekle", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(themeManager.currentTheme.primaryColor)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                // Today's Special Days
                                if !filteredDays.filter({ $0.isToday }).isEmpty {
                                    SDSectionHeader(title: "Bugün 🎉", icon: "star.fill")
                                    
                                    ForEach(filteredDays.filter { $0.isToday }) { day in
                                        SDSpecialDayCard(specialDay: day) {
                                            selectedSpecialDay = day
                                        }
                                    }
                                }
                                
                                // Upcoming Days
                                if !upcomingDays.isEmpty {
                                    SDSectionHeader(title: "Yaklaşan", icon: "calendar")
                                    
                                    ForEach(upcomingDays) { day in
                                        SDSpecialDayCard(specialDay: day) {
                                            selectedSpecialDay = day
                                        }
                                    }
                                }
                                
                                // Past Days
                                if !pastDays.isEmpty {
                                    SDSectionHeader(title: "Geçmiş", icon: "clock")
                                    
                                    ForEach(pastDays) { day in
                                        SDSpecialDayCard(specialDay: day) {
                                            selectedSpecialDay = day
                                        }
                                        .opacity(0.6)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddSpecialDay = true }) {
                            Image(systemName: "plus")
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .frame(width: 60, height: 60)
                                .background(themeManager.currentTheme.primaryColor)
                                .clipShape(Circle())
                                .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .padding(.trailing, 20)
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingAddSpecialDay) {
            AddSpecialDayView()
                .environmentObject(specialDayService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .sheet(item: $selectedSpecialDay) { day in
            SpecialDayDetailView(specialDay: day)
                .environmentObject(specialDayService)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Section Header
private struct SDSectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Special Day Card
private struct SDSpecialDayCard: View {
    let specialDay: SpecialDay
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    private var cardColor: Color {
        switch specialDay.color {
        case "red": return .red
        case "orange": return .orange
        case "pink": return .pink
        case "purple": return .purple
        case "blue": return .blue
        case "indigo": return .indigo
        case "cyan": return .cyan
        case "yellow": return .yellow
        case "mint": return .mint
        default: return .gray
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Icon
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: specialDay.icon)
                        .font(.title3)
                        .foregroundColor(cardColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(specialDay.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(specialDay.category.rawValue)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        if !specialDay.isPast {
                            Text("\(specialDay.daysUntil) gün kaldı")
                                .font(.caption)
                                .foregroundColor(cardColor)
                        } else {
                            Text(specialDay.displayDate, style: .date)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if specialDay.isRecurring {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        SpecialDaysView()
            .environmentObject(SpecialDayService())
            .environmentObject(AuthenticationService())
            .environmentObject(ThemeManager())
    }
}
