//
//  MoodStatusWidget.swift
//  sevgilim
//

import SwiftUI

struct MoodStatusWidget: View {
    let theme: AppTheme
    let currentUserName: String
    let partnerName: String?
    let currentMoodStatus: MoodStatus?
    let partnerMoodStatus: MoodStatus?
    let isUpdating: Bool
    let onMoodSelected: (MoodFeeling) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Ruh Hali", systemImage: "face.smiling")
                .font(.subheadline.weight(.semibold))
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                MoodStatusChip(
                    title: currentUserName,
                    subtitle: "Sen",
                    mood: currentMoodStatus?.mood,
                    updatedAt: currentMoodStatus?.updatedAt,
                    highlightColor: theme.primaryColor,
                    isCurrentUser: true,
                    isUpdating: isUpdating
                )
                
                MoodStatusChip(
                    title: partnerName ?? "Aşkınn",
                    subtitle: "Aşkınn",
                    mood: partnerMoodStatus?.mood,
                    updatedAt: partnerMoodStatus?.updatedAt,
                    highlightColor: theme.accentColor,
                    isCurrentUser: false,
                    isUpdating: false
                )
            }
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(MoodFeeling.allCases) { mood in
                        MoodSelectionButton(
                            mood: mood,
                            isSelected: currentMoodStatus?.mood == mood,
                            theme: theme,
                            action: { onMoodSelected(mood) }
                        )
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.primaryColor.opacity(0.12), lineWidth: 0.8)
        )
    }
}

// MARK: - Mood Status Chip

private struct MoodStatusChip: View {
    let title: String
    let subtitle: String
    let mood: MoodFeeling?
    let updatedAt: Date?
    let highlightColor: Color
    let isCurrentUser: Bool
    let isUpdating: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(subtitle.uppercased())
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                if isCurrentUser, isUpdating {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.6)
                }
            }
            
            if let mood {
                HStack(spacing: 6) {
                    Text(mood.emoji)
                        .font(.system(size: 20))
                    Text(mood.title)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.primary)
                }
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(highlightColor.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(highlightColor.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Mood Selection Button

private struct MoodSelectionButton: View {
    let mood: MoodFeeling
    let isSelected: Bool
    let theme: AppTheme
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(mood.emoji)
                    .font(.system(size: 18))
                Text(mood.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? theme.primaryColor.opacity(0.22) : Color.clear)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isSelected ? theme.primaryColor : Color(.systemGray4).opacity(0.6),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }
}
