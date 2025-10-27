//
//  SecretVaultView.swift
//  sevgilim
//

import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct SecretVaultContentView: View {
    @EnvironmentObject private var secretVaultService: SecretVaultService
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var filter: Filter = .all
    @State private var gridSize: SecretVaultGridSize = .medium
    @State private var showingAddSheet = false
    @State private var viewerIndex: Int = 0
    @State private var isShowingViewer = false
    @State private var viewerItems: [SecretVaultItem] = []
    @State private var itemPendingDeletion: SecretVaultItem?
    @State private var deletionError: String?
    
    private enum Filter: String, CaseIterable {
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
    
    private var filteredItems: [SecretVaultItem] {
        let items = secretVaultService.items
        switch filter {
        case .all:
            return items
        case .photos:
            return items.filter { !$0.isVideo }
        case .videos:
            return items.filter { $0.isVideo }
        }
    }
    
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: gridSize.minWidth), spacing: gridSize.columnSpacing, alignment: .top)]
    }
    
    private var displayedItems: [IndexedVaultItem] {
        filteredItems.enumerated().map { IndexedVaultItem(item: $0.element, displayIndex: $0.offset) }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.25),
                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                header
                
                Picker("Filtre", selection: $filter) {
                    ForEach(Filter.allCases, id: \.self) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                Picker("Yerleşim", selection: $gridSize) {
                    ForEach(SecretVaultGridSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
                
                content
                    .overlay {
                        if secretVaultService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
            }
            
            addButton
        }
        .navigationTitle("Gizli Kasamız")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddSheet) {
            AddSecretMediaView()
                .environmentObject(secretVaultService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .fullScreenCover(isPresented: $isShowingViewer) {
            SecretVaultMediaViewer(items: $viewerItems, currentIndex: $viewerIndex) {
                isShowingViewer = false
            }
        }
        .confirmationDialog(
            "Bu medyayı silmek istediğinizden emin misiniz?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { if !$0 { itemPendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Sil", role: .destructive) {
                if let item = itemPendingDeletion {
                    delete(item)
                }
                itemPendingDeletion = nil
            }
            Button("Vazgeç", role: .cancel) {
                itemPendingDeletion = nil
            }
        }
        .alert(
            "Hata",
            isPresented: Binding(
                get: { deletionError != nil },
                set: { if !$0 { deletionError = nil } }
            )
        ) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(deletionError ?? "")
        }
        .onAppear {
            guard let relationshipId = authService.currentUser?.relationshipId else { return }
            secretVaultService.listenToVault(relationshipId: relationshipId)
            viewerItems = filteredItems
        }
        .onChange(of: filter) { _, _ in
            guard isShowingViewer else { return }
            viewerItems = filteredItems
            adjustViewerIndex()
        }
        .onChange(of: secretVaultService.items.count) { _, _ in
            guard isShowingViewer else { return }
            viewerItems = filteredItems
            adjustViewerIndex()
        }
    }
    
    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 26))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.accentColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Gizli Kasamız")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Sadece ikimizin bildiği fotoğraf ve videolar")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 12)
    }
    
    @ViewBuilder
    private var content: some View {
        if filteredItems.isEmpty {
            VStack(spacing: 18) {
                Image(systemName: "lock")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.7))
                
                Text("Henüz gizli bir medya eklemediniz.")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Sadece ikimize özel fotoğraf ve videoları buraya yükleyebiliriz.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                
                Button {
                    showingAddSheet = true
                } label: {
                    Label("İlk Medyayı Ekle", systemImage: "plus.circle.fill")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(themeManager.currentTheme.primaryColor)
                        .cornerRadius(14)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: gridSize.columnSpacing) {
                    ForEach(displayedItems) { indexed in
                        SecretVaultMediaCard(item: indexed.item, style: gridSize, theme: themeManager.currentTheme)
                            .onTapGesture {
                                viewerItems = filteredItems
                                viewerIndex = indexed.displayIndex
                                isShowingViewer = true
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    itemPendingDeletion = indexed.item
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.bottom, 24)
            }
        }
    }
    
    private var addButton: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    showingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 60, height: 60)
                        .background(
                            LinearGradient(
                                colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.28), radius: 12, x: 0, y: 6)
                }
                .padding(.trailing, 22)
                .padding(.bottom, 24)
            }
        }
    }
    
    private func delete(_ item: SecretVaultItem) {
        Task {
            do {
                try await secretVaultService.delete(item)
            } catch {
                await MainActor.run {
                    deletionError = error.localizedDescription
                }
            }
        }
    }
    
    private func adjustViewerIndex() {
        if viewerItems.isEmpty {
            viewerIndex = 0
            isShowingViewer = false
        } else {
            viewerIndex = min(max(viewerIndex, 0), viewerItems.count - 1)
        }
    }
}

struct SecretVaultView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var stage: AccessStage = .loading
    @State private var errorMessage: String?
    
    private let pinManager = SecretVaultPINManager.shared
    
    var body: some View {
        Group {
            switch stage {
            case .unlocked:
                SecretVaultContentView()
            case .loading:
                lockedBackground {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.1)
                }
            case .setup:
                lockedBackground {
                    PINEntryView(
                        title: "Gizli Kasayı Kur",
                        subtitle: "Kasayı açmak için 4 haneli bir PIN belirleyelim.",
                        errorMessage: errorMessage,
                        primaryColor: themeManager.currentTheme.primaryColor,
                        showBackButton: false,
                        onBack: nil,
                        onEditingChanged: { errorMessage = nil },
                        onSubmit: { pin in
                            errorMessage = nil
                            stage = .confirm(pin)
                            return true
                        }
                    )
                }
            case .confirm(let original):
                lockedBackground {
                    PINEntryView(
                        title: "PIN'i Onayla",
                        subtitle: "Aynı PIN'i tekrar girerek doğrulayalım.",
                        errorMessage: errorMessage,
                        primaryColor: themeManager.currentTheme.primaryColor,
                        showBackButton: true,
                        onBack: {
                            errorMessage = nil
                            stage = .setup
                        },
                        onEditingChanged: { errorMessage = nil },
                        onSubmit: { pin in
                            if pin == original {
                                pinManager.setPIN(pin)
                                errorMessage = nil
                                stage = .unlocked
                                return true
                            } else {
                                errorMessage = "PIN'ler eşleşmedi. Tekrar deneyelim."
                                return false
                            }
                        }
                    )
                }
            case .enter:
                lockedBackground {
                    PINEntryView(
                        title: "Gizli Kasayı Aç",
                        subtitle: "Belirlediğin 4 haneli PIN'i gir.",
                        errorMessage: errorMessage,
                        primaryColor: themeManager.currentTheme.primaryColor,
                        showBackButton: false,
                        onBack: nil,
                        onEditingChanged: {
                            if errorMessage != nil {
                                errorMessage = nil
                            }
                        },
                        onSubmit: { pin in
                            if pinManager.validate(pin: pin) {
                                errorMessage = nil
                                stage = .unlocked
                                return true
                            } else {
                                errorMessage = "PIN yanlış. Tekrar dene."
                                return false
                            }
                        }
                    )
                }
            }
        }
        .onAppear {
            if stage == .loading {
                stage = pinManager.hasPIN() ? .enter : .setup
                errorMessage = nil
            }
        }
    }
    
    @ViewBuilder
    private func lockedBackground<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.25),
                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
        }
    }
    
    private enum AccessStage: Equatable {
        case loading
        case setup
        case confirm(String)
        case enter
        case unlocked
    }
}

private struct PINEntryView: View {
    let title: String
    let subtitle: String
    let errorMessage: String?
    let primaryColor: Color
    let showBackButton: Bool
    let onBack: (() -> Void)?
    let onEditingChanged: (() -> Void)?
    let onSubmit: (String) -> Bool
    
    @State private var pin: String = ""
    @State private var animateError: Bool = false
    @State private var previousLength: Int = 0
    @State private var isResetting: Bool = false
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            VStack(spacing: 12) {
                Text(title)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            PINDotsRow(
                filledCount: pin.count,
                primaryColor: primaryColor,
                animateError: animateError
            )
            .onTapGesture {
                isTextFieldFocused = true
            }
            
            hiddenTextField
            
            if let errorMessage, !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if showBackButton {
                Button {
                    provideSelectionFeedback()
                    isResetting = true
                    pin = ""
                    onBack?()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isTextFieldFocused = true
                    }
                } label: {
                    Label("Geri", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.bold())
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(primaryColor.opacity(0.16))
                        .foregroundColor(primaryColor)
                        .clipShape(Capsule())
                }
            }
            
            Spacer()
            
            Text("Gizliliğimiz için PIN'i sadece ikimiz bilelim.")
                .font(.footnote)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                isTextFieldFocused = true
            }
        }
    }
    
    private var hiddenTextField: some View {
        TextField("", text: $pin)
            .keyboardType(.numberPad)
            .textContentType(.oneTimeCode)
            .focused($isTextFieldFocused)
            .onChange(of: pin) { newValue in
                var sanitized = newValue.filter { $0.isNumber }
                if sanitized.count > 4 {
                    sanitized = String(sanitized.prefix(4))
                }
                
                if sanitized != newValue {
                    pin = sanitized
                    previousLength = sanitized.count
                    return
                }
                
                if isResetting {
                    previousLength = sanitized.count
                    if sanitized.isEmpty {
                        isResetting = false
                    }
                    return
                }
                
                let newLength = sanitized.count
                
                if newLength != previousLength {
                    onEditingChanged?()
                }
                
                previousLength = newLength
                
                if sanitized.count == 4 {
                    let success = onSubmit(sanitized)
                    if success {
                        provideSelectionFeedback()
                    } else {
                        triggerErrorFeedback()
                        isResetting = true
                        pin = ""
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            isTextFieldFocused = true
                        }
                    }
                }
            }
            .frame(width: 0, height: 0)
            .opacity(0.01)
    }
    
    private func triggerErrorFeedback() {
        provideErrorFeedback()
        withAnimation(.spring(response: 0.22, dampingFraction: 0.32, blendDuration: 0.2)) {
            animateError = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
            animateError = false
        }
    }
    
    private func provideErrorFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)
    }
    
    private func provideSelectionFeedback() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
    }
}

private struct PINDotsRow: View {
    let filledCount: Int
    let primaryColor: Color
    let animateError: Bool
    
    var body: some View {
        HStack(spacing: 18) {
            ForEach(0..<4, id: \.self) { index in
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.12))
                    Circle()
                        .strokeBorder(primaryColor.opacity(0.4), lineWidth: 1.4)
                    if index < filledCount {
                        Circle()
                            .fill(primaryColor)
                            .frame(width: 18, height: 18)
                    }
                }
                .frame(width: 56, height: 56)
            }
        }
        .modifier(ShakeEffect(animatableData: animateError ? 1 : 0))
    }
}

private struct ShakeEffect: GeometryEffect {
    var amplitude: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: amplitude * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}

private struct IndexedVaultItem: Identifiable {
    let item: SecretVaultItem
    let displayIndex: Int
    
    var id: String {
        item.id ?? "vault-\(displayIndex)"
    }
}

private struct SecretVaultMediaCard: View {
    let item: SecretVaultItem
    let style: SecretVaultContentView.SecretVaultGridSize
    let theme: AppTheme
    
    private var previewURL: String {
        item.thumbnailURL ?? item.downloadURL
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: style.showsDetails ? 12 : 0) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: previewURL, thumbnail: true) { image, size in
                    let isLandscape = size.width > size.height && size.width > 0 && size.height > 0
                    image
                        .resizable()
                        .aspectRatio(contentMode: isLandscape ? .fit : .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(isLandscape ? 0.18 : 0))
                } placeholder: {
                    ZStack {
                        LinearGradient(
                            colors: [
                                theme.primaryColor.opacity(0.25),
                                theme.secondaryColor.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(height: style.tileHeight)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .overlay(alignment: .topTrailing) {
                    if item.isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.white)
                            .padding(12)
                    }
                }
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.45)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
                .overlay(
                    overlayContent
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12),
                    alignment: .bottomLeading
                )
            }
            
            if style.showsDetails {
                detailsContent
            }
        }
        .padding(style.showsDetails ? 12 : 0)
        .background(
            Group {
                if style.showsDetails {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                }
            }
        )
        .overlay(
            Group {
                if style.showsDetails {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.primaryColor.opacity(0.08), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(style.showsDetails ? 0.12 : 0), radius: style.showsDetails ? 12 : 0, x: 0, y: style.showsDetails ? 6 : 0)
        .frame(minHeight: style.cardHeight, alignment: .top)
    }
    
    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !style.showsDetails {
                Text(item.displayTitle)
                    .font(.headline)
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
            
            if !overlayMetadata.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: item.isVideo ? "video.fill" : "photo.fill")
                    Text(overlayMetadata.joined(separator: " • "))
                }
                .font(.caption2)
                .foregroundColor(Color.white.opacity(0.9))
            }
        }
    }
    
    private var overlayMetadata: [String] {
        var parts: [String] = []
        if !style.showsDetails {
            parts.append(DateFormatter.displayFormat.string(from: item.createdAt))
            if item.isVideo, let duration = item.duration {
                parts.append(duration.formattedDuration)
            }
            if let size = item.formattedSize {
                parts.append(size)
            }
        } else if item.isVideo, let duration = item.duration {
            parts.append(duration.formattedDuration)
        }
        return parts
    }
    
    private var detailsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(item.displayTitle)
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(2)
            
            VStack(alignment: .leading, spacing: 6) {
                infoRow(icon: "calendar", text: DateFormatter.displayFormat.string(from: item.createdAt))
                
                if item.isVideo, let duration = item.duration {
                    infoRow(icon: "clock", text: duration.formattedDuration)
                }
                
                if let size = item.formattedSize {
                    infoRow(icon: "internaldrive.fill", text: size)
                }
            }
            
            if let note = item.note, !note.isEmpty {
                Text(note)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func infoRow(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(theme.primaryColor)
            Text(text)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private extension SecretVaultItem {
    var displayTitle: String {
        if let title = title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty {
            return title
        }
        return isVideo ? "Gizli Video" : "Gizli Fotoğraf"
    }
}

private struct SecretVaultLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 8) {
            configuration.icon
                .foregroundColor(.secondary)
            configuration.title
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }
}

struct AddSecretMediaView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var secretVaultService: SecretVaultService
    @EnvironmentObject private var authService: AuthenticationService
    @EnvironmentObject private var themeManager: ThemeManager
    
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var isShowingPhotoPicker = false
    @State private var isShowingVideoPicker = false
    @State private var title: String = ""
    @State private var note: String = ""
    @StateObject private var uploadState = UploadState(message: "Medya yükleniyor...")
    
    private var selectedType: SecretMediaType? {
        if selectedImage != nil {
            return .photo
        }
        if selectedVideoURL != nil {
            return .video
        }
        return nil
    }
    
    private var canSave: Bool {
        selectedType != nil && !uploadState.isUploading
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.25),
                        themeManager.currentTheme.secondaryColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        mediaSelectionSection
                        detailsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Gizli Medya Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        upload()
                    }
                    .disabled(!canSave)
                }
            }
        }
        .sheet(isPresented: $isShowingPhotoPicker) {
            ImagePicker(image: Binding(
                get: { selectedImage },
                set: { newValue in
                    selectedImage = newValue
                    if newValue != nil {
                        selectedVideoURL = nil
                    }
                }
            ))
        }
        .sheet(isPresented: $isShowingVideoPicker) {
            VideoPicker(videoURL: Binding(
                get: { selectedVideoURL },
                set: { newValue in
                    selectedVideoURL = newValue
                    if newValue != nil {
                        selectedImage = nil
                    }
                }
            ))
        }
        .overlay(UploadStatusOverlay(state: uploadState))
        .alert(
            "Hata",
            isPresented: Binding(
                get: { uploadState.errorMessage != nil },
                set: { if !$0 { uploadState.errorMessage = nil } }
            )
        ) {
            Button("Tamam", role: .cancel) { }
        } message: {
            Text(uploadState.errorMessage ?? "")
        }
    }
    
    private var mediaSelectionSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Medya")
                .font(.headline)
            
            Text("Sadece ikimize özel bir fotoğraf veya video seçelim.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let image = selectedImage {
                VStack(spacing: 16) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 240)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    
                    HStack(spacing: 12) {
                        Button {
                            isShowingPhotoPicker = true
                        } label: {
                            Label("Fotoğrafı Değiştir", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.bold())
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.18))
                                )
                        }
                        
                        Button(role: .destructive) {
                            selectedImage = nil
                        } label: {
                            Label("Kaldır", systemImage: "trash")
                                .font(.subheadline.bold())
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                )
                        }
                    }
                }
            } else if let url = selectedVideoURL {
                VStack(spacing: 16) {
                    VideoPreview(url: url)
                        .frame(height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    
                    metadataForSelectedVideo
                    
                    HStack(spacing: 12) {
                        Button {
                            isShowingVideoPicker = true
                        } label: {
                            Label("Videoyu Değiştir", systemImage: "arrow.triangle.2.circlepath")
                                .font(.subheadline.bold())
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.18))
                                )
                        }
                        
                        Button(role: .destructive) {
                            selectedVideoURL = nil
                        } label: {
                            Label("Kaldır", systemImage: "trash")
                                .font(.subheadline.bold())
                                .padding(.vertical, 12)
                                .frame(maxWidth: .infinity)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.red.opacity(0.12))
                                )
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Button {
                        isShowingPhotoPicker = true
                    } label: {
                        Label("Fotoğraf Seç", systemImage: "photo.on.rectangle")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(themeManager.currentTheme.primaryColor)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    
                    Button {
                        isShowingVideoPicker = true
                    } label: {
                        Label("Video Seç", systemImage: "video")
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                            )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Başlık (İsteğe Bağlı)")
                    .font(.headline)
                TextField("Sadece ikimizin bildiği kod ad", text: $title)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Notumuz (İsteğe Bağlı)")
                    .font(.headline)
                TextEditor(text: $note)
                    .frame(minHeight: 120)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.black.opacity(0.06), lineWidth: 1)
                    )
            }
            
            if let info = selectionInfoText {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    Text(info)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
        )
    }
    
    private var metadataForSelectedVideo: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let duration = selectedVideoDuration {
                Label(duration.formattedDuration, systemImage: "clock")
            }
            if let size = selectedVideoSize {
                Label(size, systemImage: "internaldrive.fill")
            }
        }
        .labelStyle(SecretVaultLabelStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private var selectionInfoText: String? {
        switch selectedType {
        case .photo:
            return "Fotoğraflar 50 MB'den küçük olmalı. Daha yüksek kalite için ışığı bol ortamda çekelim."
        case .video:
            return "Videolar 50 MB'den küçük olmalı. Uzun videolar için kırpma yapabilirsin."
        case .none:
            return "En fazla 50 MB boyutunda bir fotoğraf veya video yükleyebilirsin."
        }
    }
    
    private var selectedVideoDuration: Double? {
        guard let url = selectedVideoURL else { return nil }
        let asset = AVURLAsset(url: url)
        return CMTimeGetSeconds(asset.duration)
    }
    
    private var selectedVideoSize: String? {
        guard let url = selectedVideoURL else { return nil }
        do {
            let values = try url.resourceValues(forKeys: [.fileSizeKey])
            if let size = values.fileSize {
                let formatter = ByteCountFormatter()
                formatter.allowedUnits = [.useKB, .useMB]
                formatter.countStyle = .file
                return formatter.string(fromByteCount: Int64(size))
            }
        } catch {
            return nil
        }
        return nil
    }
    
    private func upload() {
        guard let relationshipId = authService.currentUser?.relationshipId,
              let userId = authService.currentUser?.id else {
            uploadState.fail(with: "Kullanıcı bilgileri alınamadı.")
            return
        }
        
        guard let type = selectedType else {
            uploadState.fail(with: "Lütfen önce bir fotoğraf veya video seç.")
            return
        }
        
        switch type {
        case .photo:
            uploadState.start(message: "Fotoğraf yükleniyor...")
        case .video:
            uploadState.start(message: "Video yükleniyor...")
        }
        
        Task {
            do {
                let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
                let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
                
                switch type {
                case .photo:
                    guard let image = selectedImage else {
                        throw StorageService.StorageError.invalidImage
                    }
                    
                    let result = try await StorageService.shared.uploadSecretPhoto(image, relationshipId: relationshipId)
                    
                    try await secretVaultService.addMedia(
                        relationshipId: relationshipId,
                        downloadURL: result.downloadURL,
                        thumbnailURL: result.thumbnailURL,
                        storagePath: result.storagePath,
                        thumbnailPath: result.thumbnailPath,
                        type: .photo,
                        title: trimmedTitle,
                        note: trimmedNote,
                        uploadedBy: userId,
                        sizeInBytes: result.sizeInBytes,
                        duration: nil,
                        contentType: result.contentType
                    )
                case .video:
                    guard let videoURL = selectedVideoURL else {
                        throw StorageService.StorageError.uploadFailed
                    }
                    
                    let result = try await StorageService.shared.uploadSecretVideo(from: videoURL, relationshipId: relationshipId)
                    
                    try await secretVaultService.addMedia(
                        relationshipId: relationshipId,
                        downloadURL: result.downloadURL,
                        thumbnailURL: result.thumbnailURL,
                        storagePath: result.storagePath,
                        thumbnailPath: result.thumbnailPath,
                        type: .video,
                        title: trimmedTitle,
                        note: trimmedNote,
                        uploadedBy: userId,
                        sizeInBytes: result.sizeInBytes,
                        duration: result.duration,
                        contentType: result.contentType
                    )
                }
                
                await MainActor.run {
                    secretVaultService.listenToVault(relationshipId: relationshipId)
                }
                
                await MainActor.run {
                    uploadState.finish()
                    dismiss()
                }
            } catch let error as StorageService.StorageError {
                await MainActor.run {
                    switch error {
                    case .invalidImage:
                        uploadState.fail(with: "Seçilen medya işlenemedi. Lütfen başka bir dosya dene.")
                    case .uploadFailed:
                        uploadState.fail(with: "Yükleme sırasında bir sorun oluştu. Lütfen tekrar dene.")
                    case .fileTooLarge(let maxMB):
                        uploadState.fail(with: "Dosya boyutu çok büyük. En fazla \(maxMB) MB yükleyebilirsin.")
                    }
                }
            } catch {
                await MainActor.run {
                    uploadState.fail(with: "Beklenmeyen bir hata oluştu: \(error.localizedDescription)")
                }
            }
        }
    }
}

private struct VideoPreview: View {
    let url: URL
    @State private var player: AVPlayer?
    
    var body: some View {
        VideoPlayer(player: player)
            .onAppear {
                player = AVPlayer(url: url)
                player?.isMuted = true
                player?.play()
            }
            .onDisappear {
                player?.pause()
                player = nil
            }
    }
}

private extension Double {
    var formattedDuration: String {
        guard self.isFinite else { return "Süre bilinmiyor" }
        let totalSeconds = Int(self.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
