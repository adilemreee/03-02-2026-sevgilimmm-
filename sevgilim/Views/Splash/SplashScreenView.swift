//
//  SplashScreenView.swift
//  sevgilim
//

import SwiftUI

struct SplashScreenView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isAnimating = false
    @State private var heartScale: CGFloat = 0.5
    @State private var heartRotation: Double = 0
    @State private var textOpacity: Double = 0
    @State private var backgroundOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var shimmerOffset: CGFloat = -300
    
    let onComplete: () -> Void
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor,
                    themeManager.currentTheme.secondaryColor,
                    themeManager.currentTheme.accentColor
                ],
                startPoint: isAnimating ? .topLeading : .bottomTrailing,
                endPoint: isAnimating ? .bottomTrailing : .topLeading
            )
            .ignoresSafeArea()
            .opacity(backgroundOpacity)
            
            VStack(spacing: 40) {
                // Animated heart logo
                ZStack {
                    // Single outer glow circle (reduced from 3)
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.4), .clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 150, height: 150)
                        .scaleEffect(isAnimating ? 1.3 : 0.8)
                        .opacity(isAnimating ? 0 : 0.9)
                        .animation(
                            .easeOut(duration: 2)
                            .repeatForever(autoreverses: false),
                            value: isAnimating
                        )
                    
                    // Rotating ring
                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.6), .white.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round, dash: [10, 10])
                        )
                        .frame(width: 140, height: 140)
                        .rotationEffect(.degrees(heartRotation))
                    
                    // Inner glow circle with pulse
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                        .scaleEffect(pulseScale)
                    
                    // Main heart icon with shimmer
                    ZStack {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .pink.opacity(0.8)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .shadow(color: .white.opacity(0.8), radius: 20, x: 0, y: 0)
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.5), radius: 30, x: 0, y: 0)
                        
                        // Shimmer overlay
                        Image(systemName: "heart.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        .white.opacity(0.8),
                                        .clear
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .mask(
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 80))
                            )
                            .offset(x: shimmerOffset)
                    }
                    .scaleEffect(heartScale)
                    
                    // Sparkles — reduced from 8 to 4
                    ForEach(0..<4, id: \.self) { index in
                        Image(systemName: "sparkle")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.8))
                            .offset(
                                x: cos(Double(index) * .pi / 2) * 80,
                                y: sin(Double(index) * .pi / 2) * 80
                            )
                            .scaleEffect(isAnimating ? 1.5 : 0.5)
                            .opacity(isAnimating ? 0 : 1)
                            .animation(
                                .easeInOut(duration: 1.5)
                                .delay(Double(index) * 0.2)
                                .repeatForever(autoreverses: true),
                                value: isAnimating
                            )
                    }
                }
                .frame(height: 200)
                
                // App name with enhanced effects
                VStack(spacing: 10) {
                    ZStack {
                        // Glow effect behind text
                        Text("Aşkımmmmmm")
                            .font(.system(size: 50, weight: .thin, design: .rounded))
                            .foregroundColor(.white)
                            .blur(radius: 10)
                            .opacity(textOpacity * 0.5)
                        
                        // Main text
                        Text("Aşkımmmmmm")
                            .font(.system(size: 50, weight: .thin, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.9)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .shadow(color: .white.opacity(0.5), radius: 5, x: 0, y: 2)
                            .opacity(textOpacity)
                    }
                    
                    Text("Aşkımmmlaaaa her annnnn")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.95))
                        .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                        .opacity(textOpacity)
                }
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Background fade in
        withAnimation(.easeIn(duration: 0.5)) {
            backgroundOpacity = 1
        }
        
        // Background gradient animation — single non-repeating transition
        withAnimation(.easeInOut(duration: 2.5)) {
            isAnimating = true
        }
        
        // Heart scale animation with bounce
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6).delay(0.3)) {
            heartScale = 1.0
        }
        
        // Heart rotation animation — single rotation, not forever
        withAnimation(.linear(duration: 2.5)) {
            heartRotation = 360
        }
        
        // Pulse animation — single pulse cycle
        withAnimation(.easeInOut(duration: 1.2).delay(0.5)) {
            pulseScale = 1.3
        }
        
        // Shimmer animation — single pass
        withAnimation(.linear(duration: 1.5).delay(0.8)) {
            shimmerOffset = 300
        }
        
        // Text fade in
        withAnimation(.easeIn(duration: 0.8).delay(0.8)) {
            textOpacity = 1
        }
        
        // Complete splash screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.5)) {
                onComplete()
            }
        }
    }
}

// MARK: - Splash Screen Wrapper
struct SplashScreenWrapper<Content: View>: View {
    @State private var showSplash = true
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            if !showSplash {
                content
                    .transition(.opacity)
            }
            
            if showSplash {
                SplashScreenView {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }
}

#Preview {
    SplashScreenView {
        print("Splash completed")
    }
    .environmentObject(ThemeManager())
}

