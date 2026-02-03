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

