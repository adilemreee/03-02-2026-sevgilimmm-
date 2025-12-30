//
//  FloatingTabBarPreview.swift
//  sevgilim
//
//  Preview file - Modern Floating Tab Bar with Glassmorphism
//  NOT IMPLEMENTED - Just for visual preview
//

import SwiftUI

// MARK: - Preview Container
struct FloatingTabBarPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            // Sample background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.6, green: 0.3, blue: 0.8),
                    Color(red: 0.9, green: 0.4, blue: 0.6)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            // Sample content
            VStack {
                Text(tabTitle)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                
                Text("Tab \(selectedTab + 1) İçeriği")
                    .foregroundStyle(.white.opacity(0.7))
            }
            
            // Floating Tab Bar
            VStack {
                Spacer()
                FloatingTabBar(selectedTab: $selectedTab)
            }
        }
    }
    
    private var tabTitle: String {
        switch selectedTab {
        case 0: return "🏠 Anasayfa"
        case 1: return "❤️ Anılar"
        case 2: return "📷 Fotoğraflar"
        case 3: return "📝 Notlar"
        case 4: return "👤 Profil"
        default: return ""
        }
    }
}

// MARK: - Floating Tab Bar Component
struct FloatingTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var animation
    
    private let tabs: [(icon: String, selectedIcon: String, label: String)] = [
        ("house", "house.fill", "Ana"),
        ("heart.text.square", "heart.text.square.fill", "Anılar"),
        ("photo", "photo.fill", "Foto"),
        ("note.text", "note.text", "Notlar"),
        ("person", "person.fill", "Profil")
    ]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                TabBarItem(
                    icon: tabs[index].icon,
                    selectedIcon: tabs[index].selectedIcon,
                    label: tabs[index].label,
                    isSelected: selectedTab == index,
                    animation: animation
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 12)
        .background {
            // Glassmorphism background
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.15), radius: 20, x: 0, y: 10)
                .overlay {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.5), .white.opacity(0.1)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }
}

// MARK: - Tab Bar Item
private struct TabBarItem: View {
    let icon: String
    let selectedIcon: String
    let label: String
    let isSelected: Bool
    var animation: Namespace.ID
    
    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                if isSelected {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.8, green: 0.4, blue: 0.9),
                                    Color(red: 0.9, green: 0.5, blue: 0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .matchedGeometryEffect(id: "background", in: animation)
                        .shadow(color: Color(red: 0.8, green: 0.4, blue: 0.9).opacity(0.5), radius: 8, x: 0, y: 4)
                }
                
                Image(systemName: isSelected ? selectedIcon : icon)
                    .font(.system(size: 20, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.6))
                    .scaleEffect(isSelected ? 1.1 : 1.0)
            }
            .frame(width: 56, height: 48)
            
            Text(label)
                .font(.system(size: 10, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
    }
}

// MARK: - Alternative Style: Pill Tab Bar
struct PillTabBar: View {
    @Binding var selectedTab: Int
    @Namespace private var pillAnimation
    
    private let tabs: [(icon: String, label: String)] = [
        ("house.fill", "Ana"),
        ("heart.fill", "Anılar"),
        ("photo.fill", "Foto"),
        ("note.text", "Notlar"),
        ("person.fill", "Profil")
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<tabs.count, id: \.self) { index in
                let isSelected = selectedTab == index
                
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tabs[index].icon)
                            .font(.system(size: 16, weight: .semibold))
                        
                        if isSelected {
                            Text(tabs[index].label)
                                .font(.system(size: 13, weight: .semibold))
                        }
                    }
                    .foregroundStyle(isSelected ? .white : .primary.opacity(0.6))
                    .padding(.horizontal, isSelected ? 16 : 12)
                    .padding(.vertical, 12)
                    .background {
                        if isSelected {
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.8, green: 0.4, blue: 0.9),
                                            Color(red: 0.9, green: 0.5, blue: 0.7)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .matchedGeometryEffect(id: "pill", in: pillAnimation)
                                .shadow(color: Color(red: 0.8, green: 0.4, blue: 0.9).opacity(0.4), radius: 8, x: 0, y: 4)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.12), radius: 16, x: 0, y: 8)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }
}

// MARK: - Preview with Pill Style
struct PillTabBarPreview: View {
    @State private var selectedTab = 0
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.2, green: 0.5, blue: 0.8),
                    Color(red: 0.4, green: 0.7, blue: 0.9)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack {
                Spacer()
                PillTabBar(selectedTab: $selectedTab)
            }
        }
    }
}

// MARK: - Preview
#Preview("Floating Tab Bar") {
    FloatingTabBarPreview()
}

#Preview("Pill Style Tab Bar") {
    PillTabBarPreview()
}
