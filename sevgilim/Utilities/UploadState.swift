//
//  UploadState.swift
//  sevgilim
//

import SwiftUI
import Combine

@MainActor
final class UploadState: ObservableObject {
    @Published var isUploading: Bool = false
    @Published var message: String
    @Published var errorMessage: String?
    
    init(message: String = "Yükleniyor...") {
        self.message = message
    }
    
    func start(message: String? = nil) {
        if let message = message {
            self.message = message
        }
        errorMessage = nil
        isUploading = true
    }
    
    func update(message: String) {
        self.message = message
    }
    
    func finish() {
        isUploading = false
    }
    
    func fail(with message: String) {
        errorMessage = message
        isUploading = false
    }
}

struct UploadStatusOverlay: View {
    @ObservedObject var state: UploadState
    
    var body: some View {
        Group {
            if state.isUploading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.4)
                        Text(state.message)
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 32)
                    .padding(.vertical, 24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(radius: 12)
                }
            }
        }
    }
}
