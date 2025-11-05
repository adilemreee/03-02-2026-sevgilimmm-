//
//  LoveTreePreviewCard.swift
//  sevgilim
//
//  Created by Codex on 9.06.2024.
//

import SwiftUI

struct LoveTreePreviewCard: View {
    var progress: TreeProgress?
    let theme: AppTheme
    var onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 18) {
                HStack(spacing: 12) {
                    Label("Aşk Ağacı", systemImage: "leaf.fill")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .symbolRenderingMode(.hierarchical)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 12) {
                MetricView(
                    title: "Seri",
                    value: "\(consecutiveDays) gün"
                )
                
                MetricView(
                    title: "Sayaç",
                    value: countdownText ?? "Hazır",
                    showsLock: countdownText != nil
                )
            }
        }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(maxWidth: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(cardStrokeGradient, lineWidth: 1.2)
                    .blendMode(.overlay)
            )
            .shadow(color: theme.primaryColor.opacity(0.2), radius: 18, x: 0, y: 12)
        }
        .buttonStyle(.plain)
    }
    
    private var consecutiveDays: Int {
        progress?.consecutiveDays ?? 0
    }
    
    private var countdownText: String? {
        guard let lastWatered = progress?.lastWateredAt else { return nil }
        let elapsed = Date().timeIntervalSince(lastWatered)
        let minimumInterval: TimeInterval = 24 * 60 * 60
        guard elapsed < minimumInterval else { return nil }
        
        let remaining = minimumInterval - elapsed
        guard remaining > 0 else { return nil }
        
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: remaining)
    }
    
    private var cardStrokeGradient: LinearGradient {
        LinearGradient(
            colors: [
                theme.primaryColor.opacity(0.6),
                theme.accentColor.opacity(0.35),
                Color.white.opacity(0.2)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
}

// MARK: - Helpers

private struct MetricView: View {
    let title: String
    let value: String
    var showsLock: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title.uppercased())
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .tracking(1)
                
                if showsLock {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.75))
                }
            }
            
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 4)
    }
}
