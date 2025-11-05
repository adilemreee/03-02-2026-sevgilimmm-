//
//  LoveTreeView.swift
//  sevgilim
//
//  Created by Codex on 9.06.2024.
//

import SwiftUI
import Combine

struct LoveTreeView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    @EnvironmentObject private var treeService: TreeGrowthService
    @EnvironmentObject private var authService: AuthenticationService
    
    @State private var didStartListener = false
    @State private var showCelebration = false
    @State private var alertMessage: String?
    @State private var now = Date()
    
    private let calendar = Calendar.current
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.35),
                    themeManager.currentTheme.accentColor.opacity(0.25),
                    Color(.systemBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 28) {
                    headerView
                    
                    TreeAnimationView(stage: currentStage, progress: normalizedGrowth)
                        .frame(height: 320)
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 30)
                    
                    statusSection
                    
                    waterButton
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 32)
            }
            
            if showCelebration {
                CelebrationOverlay(theme: themeManager.currentTheme)
                    .transition(.opacity)
            }
        }
        .navigationTitle("Aşk Ağacı")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            startListenerIfNeeded()
        }
        .onReceive(timer) { value in
            now = value
        }
        .alert("Bilgi", isPresented: Binding(
            get: { alertMessage != nil },
            set: { value in
                if !value { alertMessage = nil }
            }
        )) {
            Button("Tamam", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }
    
    private var progress: TreeProgress? {
        treeService.treeProgress
    }
    
    private var currentStage: TreeStage {
        progress?.stage ?? .seedling
    }
    
    private var consecutiveDays: Int {
        progress?.consecutiveDays ?? 0
    }
    
    private var lastWateredAt: Date? {
        progress?.lastWateredAt
    }
    
    private var canWaterToday: Bool {
        guard let lastWateredAt else { return true }
        let nextAllowed = lastWateredAt.addingTimeInterval(24 * 60 * 60)
        return now >= nextAllowed
    }
    
    private var normalizedGrowth: CGFloat {
        let nextRequirement = TreeStage(rawValue: currentStage.rawValue + 1)?.requiredDays ?? max(consecutiveDays, 1)
        let currentRequirement = currentStage.requiredDays
        let span = max(nextRequirement - currentRequirement, 1)
        let progressValue = CGFloat(consecutiveDays - currentRequirement)
        return min(max(progressValue / CGFloat(span), 0), 1)
    }
    
    @ViewBuilder
    private var headerView: some View {
        VStack(spacing: 12) {
            Text(headerTitle)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(themeManager.currentTheme.primaryColor)
            
            Text(currentStage.description)
                .font(.system(size: 16, weight: .regular))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
    }
    
    @ViewBuilder
    private var statusSection: some View {
        VStack(spacing: 20) {
            StreakOverviewCard(
                theme: themeManager.currentTheme,
                streak: consecutiveDays,
                stage: currentStage,
                daysRemaining: progress?.daysUntilNextStage,
                growthProgress: normalizedGrowth
            )
            
            WateringCountdownCard(
                theme: themeManager.currentTheme,
                canWaterToday: canWaterToday,
                lastWateredText: lastWateredText,
                countdownText: countdownText,
                isFirstWatering: lastWateredAt == nil
            )
        }
    }
    
    private var lastWateredText: String {
        guard let lastWateredAt else {
            return "Henüz sulanmadı"
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "tr_TR")
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: lastWateredAt, relativeTo: now)
        return "Son sulama \(relative)"
    }
    
    @ViewBuilder
    private var waterButton: some View {
        Button {
            Task {
                await handleWatering()
            }
        } label: {
            HStack {
                if treeService.isWatering {
                    ProgressView()
                        .progressViewStyle(.circular)
                } else {
                    Image(systemName: "drop.circle.fill")
                }
                
                Text(buttonTitle)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
            }
            .foregroundColor(.white)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(canWaterToday ? themeManager.currentTheme.primaryColor : Color.gray)
                    .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.25), radius: 12, x: 0, y: 8)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canWaterToday || treeService.isWatering)
        .padding(.top, 10)
    }
    
    private var buttonTitle: String {
        if treeService.isWatering {
            return "Sulama yapılıyor..."
        }
        return canWaterToday ? "Bugün Sulayın" : "Bugün zaten sulandı"
    }
    
    private var headerTitle: String {
        currentStage == .seedling ? "Aşk Ağacı" : currentStage.title
    }
    
    private var countdownText: String? {
        guard !canWaterToday, let nextDate = nextWateringDate else { return nil }
        let remaining = max(nextDate.timeIntervalSince(now), 0)
        guard remaining > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.zeroFormattingBehavior = [.pad]
        return formatter.string(from: remaining)
    }
    
    private var nextWateringDate: Date? {
        guard let lastWateredAt else { return nil }
        return lastWateredAt.addingTimeInterval(24 * 60 * 60)
    }
    
    private func handleWatering() async {
        guard let relationshipId = authService.currentUser?.relationshipId,
              let userId = authService.currentUser?.id else {
            alertMessage = TreeWateringError.missingRelationship.localizedDescription
            return
        }
        
        do {
            try await treeService.waterTree(relationshipId: relationshipId, userId: userId)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showCelebration = true
                }
            }
            try? await Task.sleep(nanoseconds: 1_400_000_000)
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.5)) {
                    showCelebration = false
                }
            }
        } catch let error as TreeWateringError {
            await MainActor.run {
                alertMessage = error.localizedDescription
            }
        } catch {
            await MainActor.run {
                alertMessage = "Sulama işlemi tamamlanamadı. Lütfen tekrar deneyin."
            }
        }
    }
    
    private func startListenerIfNeeded() {
        guard !didStartListener else { return }
        guard let relationshipId = authService.currentUser?.relationshipId else {
            alertMessage = TreeWateringError.missingRelationship.localizedDescription
            return
        }
        didStartListener = true
        treeService.listenToTreeProgress(relationshipId: relationshipId)
    }
}

// MARK: - Celebration Overlay

private struct CelebrationOverlay: View {
    let theme: AppTheme
    @State private var animate = false
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
            
            VStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(theme.primaryColor)
                    .scaleEffect(animate ? 1.1 : 0.9)
                
                Text("Aşk ağacı sulandı!")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .scaleEffect(animate ? 1 : 0.92)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(theme.primaryColor.opacity(0.85))
            )
            .shadow(color: theme.primaryColor.opacity(0.4), radius: 20, x: 0, y: 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

// MARK: - Streak Overview

private struct StreakOverviewCard: View {
    let theme: AppTheme
    let streak: Int
    let stage: TreeStage
    let daysRemaining: Int?
    let growthProgress: CGFloat
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Seri: \(streak) gün")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundStyle(LinearGradient(
                        colors: [theme.primaryColor, theme.accentColor],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                
                Spacer()
                
                Text(stageTitle)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(theme.accentColor.opacity(0.12))
                    .clipShape(Capsule())
            }
            
            Text(stageMessage)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            
            ProgressView(value: Double(min(max(growthProgress, 0), 1)))
                .progressViewStyle(.linear)
                .tint(theme.primaryColor)
                .frame(height: 6)
                .clipShape(Capsule())
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .stroke(theme.primaryColor.opacity(0.1), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.05), radius: 16, x: 0, y: 8)
    }
    
    private var stageTitle: String {
        stage == .seedling ? "Yolculuk Başlıyor" : stage.title
    }
    
    private var stageMessage: String {
        if let daysRemaining {
            return "\(daysRemaining) gün daha birlikte sulayın, bir sonraki aşama sizi bekliyor."
        } else {
            return "Aşk ağacınız en parlak halinde, ritmi korumaya devam edin."
        }
    }
}

private struct WateringCountdownCard: View {
    let theme: AppTheme
    let canWaterToday: Bool
    let lastWateredText: String
    let countdownText: String?
    let isFirstWatering: Bool
    
    @State private var pulse = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Günlük Ritüel", systemImage: "drop.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.primaryColor)
                
                Spacer()
                
                if let countdownText, !canWaterToday {
                    Text(countdownText)
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(theme.accentColor)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            
            Text(infoText)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.secondary)
            
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            theme.primaryColor.opacity(canWaterToday ? 0.6 : 0.25),
                            theme.accentColor.opacity(canWaterToday ? 0.45 : 0.2)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(height: 10)
                .overlay(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: canWaterToday ? (pulse ? 32 : 18) : 18, height: 10)
                        .padding(.horizontal, 4)
                        .offset(x: canWaterToday ? (pulse ? 4 : 0) : 0)
                        .animation(
                            canWaterToday ?
                                .easeInOut(duration: 1.6).repeatForever(autoreverses: true) :
                                .default,
                            value: pulse
                        )
                }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(theme.primaryColor.opacity(0.15), lineWidth: 1)
                )
        )
        .shadow(color: theme.primaryColor.opacity(0.08), radius: 18, x: 0, y: 12)
        .onAppear {
            if canWaterToday {
                pulse = true
            }
        }
    }
    
    private var infoText: String {
        if isFirstWatering {
            return "İlk sulamayı yapmak için hazırsınız. Aşk ağacınızı uyandırın!"
        } else if canWaterToday {
            return "24 saatlik bekleme doldu. Şimdi sulayın ve seriyi canlı tutun."
        } else {
            if let countdownText = countdownText {
                return "\(lastWateredText). Bir sonraki sulama \(countdownText) içinde açılacak."
            } else {
                return lastWateredText
            }
        }
    }
}
