//
//  CoupleHeaderCard.swift
//  sevgilim
//
//  Created by refactoring HomeView
//  Modern couple header with animated hearts

import SwiftUI

struct CoupleHeaderCard: View {
    let user1Name: String
    let user2Name: String
    
    @State private var tapAnimations: [TapHeartAnimation] = []
    private let floatingSeeds = FloatingHeartSeed.defaults
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Sevgilimmm")
                .font(.system(size: 45, weight: .thin, design: .rounded))
                .foregroundColor(.white)
            
            HStack(spacing: 25) {
                Text(user1Name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                ZStack {
                    HeartPulseView()
                    
                    FloatingHeartsField(seeds: floatingSeeds)
                    
                    // Tıklama animasyonları
                    ForEach(tapAnimations) { animation in
                        TapHeartView(animation: animation)
                    }
                }
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
                .onTapGesture {
                    createTapAnimation()
                }
                
                Text(user2Name)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
    
    private static let impactFeedback: UIImpactFeedbackGenerator = {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        return generator
    }()
    
    private func createTapAnimation() {
        // Haptic feedback (reuse prepared generator)
        Self.impactFeedback.impactOccurred()
        
        let heartCount = 9
        let baseAngle = Double.random(in: 0..<360)
        
        for index in 0..<heartCount {
            let wobble = Double.random(in: -14...14)
            let angle = baseAngle + (Double(index) / Double(heartCount)) * 360.0 + wobble
            let animation = TapHeartAnimation(
                id: UUID(),
                angle: angle,
                color: [Color.red, Color.pink, Color.purple, Color.orange].randomElement() ?? .red,
                distance: CGFloat.random(in: 55...85),
                baseScale: CGFloat.random(in: 0.45...0.7),
                spin: Double.random(in: -160...160),
                duration: Double.random(in: 0.95...1.25),
                delay: Double.random(in: 0...0.14)
            )
            tapAnimations.append(animation)
            let animationId = animation.id
            let cleanupDelay = animation.delay + animation.duration + 0.25
            DispatchQueue.main.asyncAfter(deadline: .now() + cleanupDelay) {
                tapAnimations.removeAll { $0.id == animationId }
            }
        }
    }
}

// MARK: - Supporting Types

struct TapHeartAnimation: Identifiable {
    let id: UUID
    let angle: Double
    let color: Color
    let distance: CGFloat
    let baseScale: CGFloat
    let spin: Double
    let duration: Double
    let delay: Double
}

struct TapHeartView: View {
    let animation: TapHeartAnimation
    @State private var progress: Double = 0
    @State private var hasStarted = false
    
    var body: some View {
        let angleInRadians = animation.angle * .pi / 180
        let eased = easeOut(progress)
        let travel = animation.distance * eased
        let xOffset = CGFloat(cos(angleInRadians)) * travel
        let yOffset = CGFloat(-sin(angleInRadians)) * travel * 0.95
        let scale = animation.baseScale + CGFloat(eased) * 0.7
        let opacity = max(0, 1 - progress * 1.1)
        
        Image(systemName: "heart.fill")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(
                LinearGradient(
                    colors: [animation.color, animation.color.opacity(0.5)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .shadow(color: animation.color.opacity(0.4), radius: 6, x: 0, y: 0)
            .scaleEffect(scale)
            .rotationEffect(.degrees(animation.spin * progress))
            .opacity(opacity)
            .offset(x: xOffset, y: yOffset)
            .blur(radius: CGFloat(progress) * 2.4)
            .compositingGroup()
            .onAppear {
                guard !hasStarted else { return }
                hasStarted = true
                DispatchQueue.main.asyncAfter(deadline: .now() + animation.delay) {
                    withAnimation(.easeOut(duration: animation.duration)) {
                        progress = 1
                    }
                }
            }
    }
    
    private func easeOut(_ t: Double) -> Double {
        1 - pow(1 - t, 2.2)
    }
}

// MARK: - Persistent Heart Animations (Optimized - no TimelineView)

private struct HeartPulseView: View {
    @State private var isPulsing = false
    @State private var isRotating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.3))
                .blur(radius: 14)
                .scaleEffect(isPulsing ? 1.6 : 1.36)
                .opacity(isPulsing ? 0.65 : 0.3)
            
            Image(systemName: "heart.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .red, Color.purple.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .red.opacity(0.45), radius: 12, x: 0, y: 0)
                .scaleEffect(isPulsing ? 1.04 : 0.88)
                .rotationEffect(.degrees(isRotating ? 4 : -4))
        }
        .frame(width: 60, height: 60)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                isPulsing = true
            }
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isRotating = true
            }
        }
    }
}

private struct FloatingHeartsField: View {
    let seeds: [FloatingHeartSeed]
    
    var body: some View {
        ZStack {
            ForEach(seeds) { seed in
                FloatingHeartItem(seed: seed)
            }
        }
    }
}

/// Individual floating heart with its own lightweight animation cycle
private struct FloatingHeartItem: View {
    let seed: FloatingHeartSeed
    @State private var isFloating = false
    
    var body: some View {
        Image(systemName: "heart.fill")
            .font(.caption)
            .foregroundColor(seed.color.opacity(0.75))
            .offset(
                x: seed.horizontal + (isFloating ? 6 : -6),
                y: isFloating ? -46 : 0
            )
            .scaleEffect(isFloating ? seed.baseScale + 0.22 : seed.baseScale)
            .opacity(isFloating ? 0 : 0.75)
            .onAppear {
                withAnimation(
                    .easeOut(duration: seed.cycleDuration)
                    .repeatForever(autoreverses: false)
                    .delay(seed.phaseOffset.truncatingRemainder(dividingBy: seed.cycleDuration))
                ) {
                    isFloating = true
                }
            }
    }
}

private struct FloatingHeartSeed: Identifiable {
    let id = UUID()
    let horizontal: CGFloat
    let baseScale: CGFloat
    let cycleDuration: Double
    let phaseOffset: Double
    let color: Color
    
    static let defaults: [FloatingHeartSeed] = [
        FloatingHeartSeed(horizontal: 0, baseScale: 0.55, cycleDuration: 2.6, phaseOffset: 0.0, color: .pink),
        FloatingHeartSeed(horizontal: -20, baseScale: 0.45, cycleDuration: 3.0, phaseOffset: 0.8, color: .red),
        FloatingHeartSeed(horizontal: 18, baseScale: 0.5, cycleDuration: 2.8, phaseOffset: 1.3, color: .purple),
        FloatingHeartSeed(horizontal: -12, baseScale: 0.4, cycleDuration: 2.4, phaseOffset: 1.9, color: .pink),
        FloatingHeartSeed(horizontal: 15, baseScale: 0.42, cycleDuration: 3.2, phaseOffset: 2.6, color: .orange)
    ]
}
