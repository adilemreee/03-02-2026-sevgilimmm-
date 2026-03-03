//
//  StoryCircles.swift
//  sevgilim
//

import SwiftUI

struct StoryCircles: View {
    @EnvironmentObject var storyService: StoryService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var relationshipService: RelationshipService
    
    @State private var storyPresentation: StoryPresentation?
    @State private var showingAddStory = false
    
    struct StoryPresentation: Identifiable {
        let id = UUID()
        let stories: [Story]
        let startIndex: Int
    }
    
    // İlk izlenmemiş story'nin index'ini bul
    private func getStartIndex(for stories: [Story], userId: String) -> Int {
        if let firstUnviewed = stories.firstIndex(where: { !$0.isViewedBy(userId: userId) }) {
            return firstUnviewed
        }
        return 0
    }
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 18) {
                if let currentUser = authService.currentUser,
                   let userId = currentUser.id {
                    let userStories = storyService.userStories
                    let hasStories = !userStories.isEmpty
                    let allViewed = hasStories ? userStories.allSatisfy { $0.isViewedBy(userId: userId) } : true
                    let userActiveColors: [Color] = [
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor,
                        .pink,
                        .purple
                    ]
                    let mutedColors: [Color] = [
                        Color.white.opacity(0.25),
                        Color.white.opacity(0.1)
                    ]
                    
                    VStack(spacing: 8) {
                        StoryRing(
                            size: 78,
                            imageURL: nil,
                            fallbackURL: currentUser.profileImageURL,
                            placeholderSystemImage: "person.fill",
                            gradientColors: hasStories ? userActiveColors : mutedColors,
                            isDimmed: allViewed || !hasStories,
                            badgeCount: (hasStories && !allViewed)
                                ? userStories.filter { !$0.isViewedBy(userId: userId) }.count
                                : nil,
                            plusColor: themeManager.currentTheme.primaryColor,
                            showUnreadIndicator: false,
                            unreadGradientColors: []
                        )
                        .onTapGesture {
                            if hasStories {
                                let index = getStartIndex(for: userStories, userId: userId)
                                storyPresentation = StoryPresentation(stories: userStories, startIndex: index)
                            } else {
                                showingAddStory = true
                            }
                        }
                        
                        Text("Hikayem")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                
                if let currentUserId = authService.currentUser?.id,
                   let firstPartnerStory = storyService.partnerStories.first {
                    let partnerStories = storyService.partnerStories
                    let latestPartnerStory = partnerStories.last ?? firstPartnerStory
                    let allViewed = partnerStories.allSatisfy { $0.isViewedBy(userId: currentUserId) }
                    let partnerActiveColors: [Color] = [
                        .pink,
                        themeManager.currentTheme.primaryColor,
                        themeManager.currentTheme.secondaryColor,
                        .purple
                    ]
                    let mutedColors: [Color] = [
                        Color.gray.opacity(0.55),
                        Color.gray.opacity(0.3)
                    ]
                    
                    VStack(spacing: 8) {
                        StoryRing(
                            size: 78,
                            imageURL: nil,
                            fallbackURL: latestPartnerStory.createdByPhotoURL,
                            placeholderSystemImage: "person.fill",
                            gradientColors: allViewed ? mutedColors : partnerActiveColors,
                            isDimmed: allViewed,
                            badgeCount: allViewed
                                ? nil
                                : partnerStories.filter { !$0.isViewedBy(userId: currentUserId) }.count,
                            plusColor: nil,
                            showUnreadIndicator: !allViewed,
                            unreadGradientColors: partnerActiveColors
                        )
                        .onTapGesture {
                            let index = getStartIndex(for: partnerStories, userId: currentUserId)
                            storyPresentation = StoryPresentation(stories: partnerStories, startIndex: index)
                        }
                        
                        Text(latestPartnerStory.createdByName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
        .fullScreenCover(item: $storyPresentation) { presentation in
            StoryViewer(stories: presentation.stories, startIndex: presentation.startIndex)
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
                .environmentObject(relationshipService)
        }
        .sheet(isPresented: $showingAddStory) {
            AddStoryView()
                .environmentObject(storyService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Story Ring

private struct StoryRing: View {
    let size: CGFloat
    let imageURL: String?
    let fallbackURL: String?
    let placeholderSystemImage: String
    let gradientColors: [Color]
    let isDimmed: Bool
    let badgeCount: Int?
    let plusColor: Color?
    let showUnreadIndicator: Bool
    let unreadGradientColors: [Color]
    
    @State private var isAnimatingRing = false
    
    var body: some View {
        let ringWidth: CGFloat = 4
        let innerSize = size - ringWidth * 2.6
        let shouldAnimateRing = showUnreadIndicator && !isDimmed
        let activeGradientColors = (showUnreadIndicator && !unreadGradientColors.isEmpty) ? unreadGradientColors : gradientColors
        
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.04))
                .frame(width: size, height: size)
                .overlay(
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                gradient: Gradient(colors: activeGradientColors),
                                center: .center
                            ),
                            lineWidth: ringWidth
                        )
                        .opacity(isDimmed ? 0.45 : 1.0)
                        .rotationEffect(.degrees(isAnimatingRing ? 360 : 0))
                        .animation(
                            shouldAnimateRing
                                ? .linear(duration: 5).repeatForever(autoreverses: false)
                                : .easeOut(duration: 0.35),
                            value: isAnimatingRing
                        )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
                )
            
            StoryImageView(
                imageURL: imageURL,
                fallbackURL: fallbackURL,
                placeholderSystemImage: placeholderSystemImage
            )
            .frame(width: innerSize, height: innerSize)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .stroke(Color.white.opacity(0.75), lineWidth: 1.4)
            )
            .shadow(color: .black.opacity(0.15), radius: 6, x: 0, y: 4)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .bottomTrailing) {
            if let plusColor = plusColor {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [plusColor, plusColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 22, height: 22)
                    .overlay {
                        Image(systemName: "plus")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                    }
                    .shadow(color: plusColor.opacity(0.4), radius: 6, x: 0, y: 4)
                    .offset(x: 6, y: 6)
            }
        }
        .overlay(alignment: .topTrailing) {
            if let badgeCount = badgeCount, badgeCount > 0 {
                Text("\(badgeCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.55))
                    )
                    .overlay {
                        Capsule(style: .continuous)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    }
                    .offset(x: 6, y: -6)
            }
        }
        .onAppear {
            isAnimatingRing = shouldAnimateRing
        }
        .onChange(of: shouldAnimateRing) { _, newValue in
            isAnimatingRing = newValue
        }
    }
}

// MARK: - Story Image

private struct StoryImageView: View {
    let imageURL: String?
    let fallbackURL: String?
    let placeholderSystemImage: String
    
    var body: some View {
        if let urlString = imageURL ?? fallbackURL {
            CachedAsyncImage(url: urlString, thumbnail: true) { image, _ in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                placeholder
            }
        } else {
            placeholder
        }
    }
    
    private var placeholder: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.25))
            Image(systemName: placeholderSystemImage)
                .font(.system(size: 26, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
