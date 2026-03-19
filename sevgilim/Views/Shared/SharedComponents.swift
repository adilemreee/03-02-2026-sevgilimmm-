//
//  SharedComponents.swift
//  sevgilim
//
//  Optimized shared UI components for better performance

import SwiftUI

// MARK: - Gradient Background (Static)
struct AnimatedGradientBackground: View {
    let theme: AppTheme
    
    var body: some View {
        LinearGradient(
            colors: [
                theme.primaryColor,
                theme.primaryColor.opacity(0.85),
                theme.secondaryColor.opacity(0.75)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

struct SectionHeroHeader: View {
    let systemImage: String
    let iconColors: [Color]
    let title: String
    let subtitle: String
    let countValue: String
    let countTint: Color
    var countLabel: String = "Toplam"
    var trailingContent: AnyView? = nil
    
    private var resolvedIconColors: [Color] {
        if iconColors.isEmpty {
            return [countTint, countTint.opacity(0.8)]
        }
        if iconColors.count == 1 {
            return [iconColors[0], iconColors[0].opacity(0.82)]
        }
        return iconColors
    }
    
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: resolvedIconColors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)
                
                Image(systemName: systemImage)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                
                Text(subtitle)
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
            
            Spacer()
            
            if let trailingContent {
                trailingContent
            } else {
                HStack(spacing: 6) {
                    Text(countValue)
                        .font(.headline.bold())
                        .foregroundColor(countTint)
                    Text(countLabel)
                        .font(.caption.weight(.semibold))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.secondarySystemBackground), in: Capsule())
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }
}

struct SectionRoundIconButton: View {
    let systemImage: String
    let tint: Color
    var emphasized: Bool = false
    
    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(emphasized ? .white : tint)
            .frame(width: 42, height: 42)
            .background(
                Circle()
                    .fill(emphasized ? tint : Color(.secondarySystemBackground))
            )
            .overlay(
                Circle()
                    .stroke(tint.opacity(emphasized ? 0 : 0.12), lineWidth: 1)
            )
    }
}

struct SectionControlChip: View {
    let title: String
    let systemImage: String
    let tint: Color
    var emphasized: Bool = false
    
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
            Text(title)
                .font(.callout.weight(.semibold))
        }
        .foregroundColor(emphasized ? .white : .primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(emphasized ? tint : Color(.secondarySystemBackground))
        )
        .fixedSize(horizontal: true, vertical: false)
    }
}
