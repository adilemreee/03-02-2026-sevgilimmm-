//
//  SecretVaultViewModel.swift
//  sevgilim
//
//  ViewModel for SecretVaultView - extracts business logic from view
//

import Foundation
import Combine
import UIKit

@MainActor
final class SecretVaultViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var filter: SecretVaultFilter = .all
    @Published var gridSize: SecretVaultGridSize = .medium
    @Published var showingAddSheet: Bool = false
    @Published var viewerIndex: Int = 0
    @Published var isShowingViewer: Bool = false
    @Published var viewerItems: [SecretVaultItem] = []
    @Published var itemPendingDeletion: SecretVaultItem?
    @Published var deletionError: String?
    
    // MARK: - Dependencies
    private let secretVaultService: SecretVaultService
    private let authService: AuthenticationService
    
    // MARK: - Types
    enum SecretVaultFilter: String, CaseIterable {
        case all = "Tümü"
        case photos = "Fotoğraflar"
        case videos = "Videolar"
    }
    
    enum SecretVaultGridSize: String, CaseIterable {
        case compact = "Yoğun"
        case medium = "Orta"
        case spacious = "Geniş"
        
        var minWidth: CGFloat {
            switch self {
            case .compact: return 90
            case .medium: return 140
            case .spacious: return 200
            }
        }
        
        var tileHeight: CGFloat {
            switch self {
            case .compact: return 110
            case .medium: return 180
            case .spacious: return 240
            }
        }
        
        var cardHeight: CGFloat {
            switch self {
            case .compact: return tileHeight + 0
            case .medium: return tileHeight + 80
            case .spacious: return tileHeight + 110
            }
        }
        
        var columnSpacing: CGFloat {
            switch self {
            case .compact: return 10
            case .medium: return 16
            case .spacious: return 20
            }
        }
        
        var showsDetails: Bool {
            self != .compact
        }
    }
    
    // MARK: - Computed Properties
    var items: [SecretVaultItem] {
        secretVaultService.items
    }
    
    var isLoading: Bool {
        secretVaultService.isLoading
    }
    
    var relationshipId: String? {
        authService.currentUser?.relationshipId
    }
    
    var filteredItems: [SecretVaultItem] {
        let items = self.items
        switch filter {
        case .all:
            return items
        case .photos:
            return items.filter { !$0.isVideo }
        case .videos:
            return items.filter { $0.isVideo }
        }
    }
    
    // MARK: - Initialization
    init(secretVaultService: SecretVaultService, authService: AuthenticationService) {
        self.secretVaultService = secretVaultService
        self.authService = authService
    }
    
    // MARK: - Lifecycle
    func setupListener() {
        guard let relationshipId = relationshipId else { return }
        secretVaultService.listenToVault(relationshipId: relationshipId)
        viewerItems = filteredItems
    }
    
    // MARK: - Actions
    func openViewer(at index: Int) {
        viewerItems = filteredItems
        viewerIndex = index
        isShowingViewer = true
    }
    
    func requestDeletion(for item: SecretVaultItem) {
        itemPendingDeletion = item
    }
    
    func confirmDeletion() {
        guard let item = itemPendingDeletion else { return }
        
        Task {
            do {
                try await secretVaultService.delete(item)
            } catch {
                deletionError = error.localizedDescription
            }
        }
        
        itemPendingDeletion = nil
    }
    
    func cancelDeletion() {
        itemPendingDeletion = nil
    }
    
    func adjustViewerIndex() {
        if viewerItems.isEmpty {
            viewerIndex = 0
            isShowingViewer = false
        } else {
            viewerIndex = min(max(viewerIndex, 0), viewerItems.count - 1)
        }
    }
    
    func updateViewerItems() {
        guard isShowingViewer else { return }
        viewerItems = filteredItems
        adjustViewerIndex()
    }
    
    func dismissError() {
        deletionError = nil
    }
}
