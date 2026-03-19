//
//  PhotosView.swift
//  sevgilim
//

import SwiftUI
import PhotosUI
import AVFoundation


struct PhotosView: View {
    @EnvironmentObject var photoService: PhotoService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddPhoto = false
    @State private var selectedPhotoIndex: Int = 0
    @State private var isShowingViewer = false
    @State private var sortOption: PhotoSortOption = .newest
    @State private var gridSize: PhotoGridSize = .medium
    @State private var searchText = ""
    @State private var mediaFilter: PhotoMediaFilter = .all
    @State private var showingFilterSheet = false
    
    enum PhotoSortOption: String, CaseIterable {
        case newest = "En Yeni"
        case oldest = "En Eski"
        case alphabetical = "A-Z"
    }
    
    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: gridSize.minWidth), spacing: gridSize.columnSpacing, alignment: .top)]
    }
    
    enum PhotoMediaFilter: String, CaseIterable {
        case all = "Tümü"
        case photos = "Fotoğraf"
        case videos = "Video"
        case tagged = "Etiketli"
        case located = "Konumlu"
        
        var systemImage: String {
            switch self {
            case .all: return "square.stack.3d.down.right.fill"
            case .photos: return "photo.fill"
            case .videos: return "video.fill"
            case .tagged: return "number"
            case .located: return "mappin.and.ellipse"
            }
        }
    }
    
    enum PhotoGridSize: String, CaseIterable {
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
            case .compact: return 100
            case .medium: return 170
            case .spacious: return 220
            }
        }
        
        var detailsHeight: CGFloat {
            switch self {
            case .compact: return 0
            case .medium: return 56
            case .spacious: return 74
            }
        }
        
        var titleHeight: CGFloat {
            switch self {
            case .compact: return 0
            case .medium: return 24
            case .spacious: return 42
            }
        }
        
        var titleLineLimit: Int {
            switch self {
            case .compact: return 1
            case .medium: return 1
            case .spacious: return 2
            }
        }
        
        var cardHeight: CGFloat {
            switch self {
            case .compact: return tileHeight
            case .medium: return tileHeight + detailsHeight + 36
            case .spacious: return tileHeight + detailsHeight + 36
            }
        }
        
        var columnSpacing: CGFloat {
            switch self {
            case .compact: return 10
            case .medium: return 16
            case .spacious: return 18
            }
        }
        
        var showsDetails: Bool {
            self != .compact
        }
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.3),
                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            Group {
                if photoService.photos.isEmpty {
                    VStack(spacing: 0) {
                        headerSection
                        controlsSection
                        emptyLibraryState
                    }
                } else if visiblePhotoItems.isEmpty {
                    VStack(spacing: 0) {
                        headerSection
                        controlsSection
                        filteredEmptyState
                    }
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            headerSection
                            controlsSection
                            
                            VStack(spacing: 18) {
                                HStack {
                                    Text(resultsSummaryText)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                
                                LazyVGrid(columns: gridColumns, spacing: gridSize.columnSpacing) {
                                    ForEach(Array(visiblePhotoItems.enumerated()), id: \.element.id) { index, item in
                                        PhotoCardModern(photo: item.photo, style: gridSize)
                                            .onTapGesture {
                                                guard !visiblePhotos.isEmpty else { return }
                                                selectedPhotoIndex = index
                                                isShowingViewer = true
                                            }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                            }
                        }
                    }
                    .overlay(alignment: .top) {
                        if photoService.isLoading {
                            ProgressView()
                                .padding()
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddPhoto = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(themeManager.currentTheme.primaryColor)
                            .clipShape(Circle())
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingAddPhoto) {
            AddPhotoView()
                .environmentObject(photoService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingFilterSheet) {
            PhotoFiltersSheet(
                mediaFilter: $mediaFilter,
                sortOption: $sortOption,
                gridSize: $gridSize,
                tint: themeManager.currentTheme.primaryColor,
                showsResetAction: hasCustomControlSelections,
                onReset: resetControlSelections
            )
        }
        .fullScreenCover(isPresented: $isShowingViewer) {
            FullScreenPhotoViewer(currentIndex: $selectedPhotoIndex, photos: visiblePhotos) {
                isShowingViewer = false
            }
            .environmentObject(photoService)
        }
        .onChange(of: visiblePhotos.count) { _, newCount in
            if newCount == 0 {
                isShowingViewer = false
                selectedPhotoIndex = 0
            } else if selectedPhotoIndex >= newCount {
                selectedPhotoIndex = max(0, newCount - 1)
            }
        }
        .onAppear {
            // Listener is handled by MainTabView
        }
    }
}

extension PhotosView {
    private struct IndexedPhoto: Identifiable {
        let photo: Photo
        let originalIndex: Int
        
        var id: String {
            photo.id ?? "photo-\(originalIndex)"
        }
    }
    
    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    private var hasActiveFilters: Bool {
        mediaFilter != .all || !normalizedSearchText.isEmpty
    }
    
    private var hasCustomControlSelections: Bool {
        mediaFilter != .all || sortOption != .newest || gridSize != .medium
    }
    
    private var allPhotoItems: [IndexedPhoto] {
        photoService.photos.enumerated().map { IndexedPhoto(photo: $0.element, originalIndex: $0.offset) }
    }
    
    private var filteredPhotoItems: [IndexedPhoto] {
        allPhotoItems.filter { item in
            matchesMediaFilter(item.photo) && matchesSearch(item.photo)
        }
    }
    
    private var visiblePhotoItems: [IndexedPhoto] {
        sort(items: filteredPhotoItems)
    }
    
    private var visiblePhotos: [Photo] {
        visiblePhotoItems.map(\.photo)
    }
    
    private var resultsSummaryText: String {
        if hasActiveFilters {
            return "\(visiblePhotos.count) sonuç gösteriliyor"
        }
        return "\(visiblePhotos.count) içerik albümde kayıtlı"
    }
    
    private var headerSection: some View {
        SectionHeroHeader(
            systemImage: "photo.stack.fill",
            iconColors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
            title: "Fotoğraflarımız",
            subtitle: hasActiveFilters ? "Aradığın anı daha hızlı bul" : "Birlikte çektiğiniz anılar burada",
            countValue: "\(photoService.photos.count)",
            countTint: themeManager.currentTheme.primaryColor,
            trailingContent: AnyView(filterMenuButton)
        )
    }
    
    private var controlsSection: some View {
        searchField
            .padding(.bottom, 8)
    }
    
    private var filterMenuButton: some View {
        Button {
            showingFilterSheet = true
        } label: {
            SectionRoundIconButton(
                systemImage: "slider.horizontal.3",
                tint: themeManager.currentTheme.primaryColor,
                emphasized: hasCustomControlSelections
            )
        }
        .buttonStyle(.plain)
    }
    
    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
                .font(.system(size: 18, weight: .medium))
            
            TextField("Başlık, konum veya etiket ara", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }
    
    private var emptyLibraryState: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo")
                .font(.system(size: 60))
                .foregroundColor(.secondary.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Henüz fotoğraf yok")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("Güzel anlarınızı fotoğraf olarak ekleyin")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button(action: { showingAddPhoto = true }) {
                Label("İlk Fotoğrafı Ekle", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
            }
        }
        .frame(maxHeight: .infinity)
    }
    
    private var filteredEmptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "sparkle.magnifyingglass")
                .font(.system(size: 56))
                .foregroundColor(themeManager.currentTheme.primaryColor.opacity(0.8))
            
            VStack(spacing: 8) {
                Text("Eşleşen fotoğraf bulunamadı")
                    .font(.headline)
                
                Text("Aramayı değiştir veya filtreleri temizleyip tüm albümü tekrar göster.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button {
                clearFilters()
            } label: {
                Label("Filtreleri Temizle", systemImage: "line.3.horizontal.decrease.circle.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 12)
                    .background(themeManager.currentTheme.primaryColor)
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 28)
        .frame(maxHeight: .infinity)
    }
    
    private func clearFilters() {
        searchText = ""
        mediaFilter = .all
    }
    
    private func resetControlSelections() {
        mediaFilter = .all
        sortOption = .newest
        gridSize = .medium
    }
    
    private func sort(items: [IndexedPhoto]) -> [IndexedPhoto] {
        switch sortOption {
        case .newest:
            return items.sorted { $0.photo.date > $1.photo.date }
        case .oldest:
            return items.sorted { $0.photo.date < $1.photo.date }
        case .alphabetical:
            return items.sorted {
                ($0.photo.title ?? "").localizedCaseInsensitiveCompare($1.photo.title ?? "") == .orderedAscending
            }
        }
    }
    
    private func matchesMediaFilter(_ photo: Photo) -> Bool {
        switch mediaFilter {
        case .all:
            return true
        case .photos:
            return !photo.isVideo
        case .videos:
            return photo.isVideo
        case .tagged:
            return !(tags(for: photo).isEmpty)
        case .located:
            guard let location = photo.location else { return false }
            return !location.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private func matchesSearch(_ photo: Photo) -> Bool {
        guard !normalizedSearchText.isEmpty else { return true }
        
        let query = normalizedSearchText.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
        let searchableTokens = [
            photo.title,
            photo.location,
            DateFormatter.displayFormat.string(from: photo.date)
        ].compactMap { $0 } + tags(for: photo)
        
        return searchableTokens.contains { token in
            token.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
                .contains(query)
        }
    }
    
    private func tags(for photo: Photo) -> [String] {
        photo.tags?.flatMap { [$0, "#\($0)"] } ?? []
    }
}

private struct PhotoFiltersSheet: View {
    @Binding var mediaFilter: PhotosView.PhotoMediaFilter
    @Binding var sortOption: PhotosView.PhotoSortOption
    @Binding var gridSize: PhotosView.PhotoGridSize
    
    let tint: Color
    let showsResetAction: Bool
    let onReset: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filterSection(title: "Göster") {
                        ForEach(PhotosView.PhotoMediaFilter.allCases, id: \.self) { filter in
                            FilterOptionRow(
                                title: filter.rawValue,
                                systemImage: filter.systemImage,
                                isSelected: mediaFilter == filter,
                                tint: tint
                            ) {
                                mediaFilter = filter
                            }
                        }
                    }
                    
                    filterSection(title: "Sırala") {
                        ForEach(PhotosView.PhotoSortOption.allCases, id: \.self) { option in
                            FilterOptionRow(
                                title: option.rawValue,
                                systemImage: sortIcon(for: option),
                                isSelected: sortOption == option,
                                tint: tint
                            ) {
                                sortOption = option
                            }
                        }
                    }
                    
                    filterSection(title: "Görünüm") {
                        ForEach(PhotosView.PhotoGridSize.allCases, id: \.self) { size in
                            FilterOptionRow(
                                title: size.rawValue,
                                systemImage: gridIcon(for: size),
                                isSelected: gridSize == size,
                                tint: tint
                            ) {
                                gridSize = size
                            }
                        }
                    }
                    
                    if showsResetAction {
                        Button {
                            onReset()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Varsayılana Dön")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                            }
                            .foregroundColor(tint)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(tint.opacity(0.10))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Filtreler")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Bitti") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    
    private func filterSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
            
            VStack(spacing: 10) {
                content()
            }
        }
    }
    
    private func sortIcon(for option: PhotosView.PhotoSortOption) -> String {
        switch option {
        case .newest:
            return "arrow.down.circle.fill"
        case .oldest:
            return "arrow.up.circle.fill"
        case .alphabetical:
            return "textformat.abc"
        }
    }
    
    private func gridIcon(for size: PhotosView.PhotoGridSize) -> String {
        switch size {
        case .compact:
            return "square.grid.3x3.fill"
        case .medium:
            return "square.grid.2x2.fill"
        case .spacious:
            return "rectangle.grid.1x2.fill"
        }
    }
}

private struct FilterOptionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let tint: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : tint)
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(isSelected ? tint : tint.opacity(0.12))
                    )
                
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(isSelected ? tint : .secondary.opacity(0.45))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(isSelected ? tint.opacity(0.10) : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? tint.opacity(0.28) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// Modern Photo Card with Caching
struct PhotoCardModern: View {
    let photo: Photo
    let style: PhotosView.PhotoGridSize
    @EnvironmentObject var themeManager: ThemeManager
    
    private var trimmedTitle: String? {
        let trimmed = photo.title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private var trimmedLocation: String? {
        let trimmed = photo.location?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private var cleanedTags: [String] {
        (photo.tags ?? []).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    private var primaryTag: String? {
        cleanedTags.first
    }
    
    private var remainingTagCount: Int {
        max(0, cleanedTags.count - 1)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: style.showsDetails ? 12 : 0) {
            ZStack {
                CachedAsyncImage(url: photo.displayThumbnailURL, thumbnail: true) { image, size in
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
                                themeManager.currentTheme.primaryColor.opacity(0.25),
                                themeManager.currentTheme.secondaryColor.opacity(0.2)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
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
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.35)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                )
                .overlay(alignment: .center) {
                    if photo.isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                }
                .overlay(alignment: .topLeading) {
                    if !style.showsDetails, let location = trimmedLocation {
                        overlayChip(systemImage: "mappin.and.ellipse", text: location)
                            .padding(12)
                    }
                }
                .overlay(alignment: .bottomLeading) {
                    if style.showsDetails {
                        if let primaryTag {
                            HStack(spacing: 6) {
                                Text("#\(primaryTag)")
                                    .lineLimit(1)
                                if remainingTagCount > 0 {
                                    Text("+\(remainingTagCount)")
                                }
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(themeManager.currentTheme.primaryColor.opacity(0.88), in: Capsule())
                            .padding(12)
                        }
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                            Text(photo.date, formatter: DateFormatter.displayFormat)
                        }
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.45), in: Capsule())
                        .padding([.leading, .bottom], 12)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                    }
                }
            }
            
            if style.showsDetails {
                VStack(alignment: .leading, spacing: 10) {
                    Group {
                        if let trimmedTitle {
                            Text(trimmedTitle)
                                .font(.headline)
                                .foregroundColor(.primary)
                                .lineLimit(style.titleLineLimit)
                                .frame(maxWidth: .infinity, minHeight: style.titleHeight, maxHeight: style.titleHeight, alignment: .topLeading)
                        } else {
                            Color.clear
                                .frame(maxWidth: .infinity, minHeight: style.titleHeight, maxHeight: style.titleHeight)
                        }
                    }
                    
                    HStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "calendar")
                                .font(.caption)
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            Text(photo.date, formatter: DateFormatter.displayFormat)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .layoutPriority(1)
                        
                        Spacer(minLength: 6)
                        
                        if let location = trimmedLocation {
                            HStack(spacing: 5) {
                                Image(systemName: "mappin.and.ellipse")
                                    .font(.caption2)
                                Text(location)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.85)
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundColor(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: style.detailsHeight, alignment: .top)
            }
        }
        .padding(style.showsDetails ? 12 : 0)
        .background(
            Group {
                if style.showsDetails {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                }
            }
        )
        .overlay(
            Group {
                if style.showsDetails {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.1), lineWidth: 1)
                }
            }
        )
        .shadow(color: .black.opacity(style.showsDetails ? 0.1 : 0.0), radius: style.showsDetails ? 12 : 0, x: 0, y: style.showsDetails ? 6 : 0)
        .frame(height: style.cardHeight, alignment: .top)
    }
    
    private func overlayChip(systemImage: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
            Text(text)
                .lineLimit(1)
        }
        .font(.caption2)
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.45), in: Capsule())
    }
}

struct PhotoDetailView: View {
    let photo: Photo
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var photoService: PhotoService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    AsyncImage(url: URL(string: photo.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        case .failure:
                            Image(systemName: "photo.fill")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        if let title = photo.title {
                            Text(title)
                                .font(.title2.bold())
                        }
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text(photo.date, formatter: DateFormatter.displayFormat)
                                .foregroundColor(.secondary)
                        }
                        
                        if let location = photo.location {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(.secondary)
                                Text(location)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        if let tags = photo.tags, !tags.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack {
                                    ForEach(tags, id: \.self) { tag in
                                        Text("#\(tag)")
                                            .font(.caption)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(themeManager.currentTheme.primaryColor.opacity(0.2))
                                            .foregroundColor(themeManager.currentTheme.primaryColor)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            .navigationTitle("Fotoğraf Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Fotoğrafı Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        try? await photoService.deletePhoto(photo)
                        dismiss()
                    }
                }
            } message: {
                Text("Bu fotoğrafı silmek istediğinizden emin misiniz?")
            }
        }
    }
}

struct AddPhotoView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var photoService: PhotoService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var selectedVideoDuration: Double?
    @State private var selectedVideoThumbnail: UIImage?
    @State private var isGeneratingVideoThumbnail = false
    @State private var showingImagePicker = false
    @State private var showingVideoPicker = false
    @State private var title = ""
    @State private var location = ""
    @State private var date = Date()
    @State private var tagInput = ""
    @State private var tags: [String] = []
    @StateObject private var uploadState = UploadState(message: "Fotoğraf yükleniyor...")
    
    var body: some View {
        NavigationView {
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
                        imagePickerSection
                        detailsSection
                        tagsSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationTitle("Fotoğraf Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        uploadMedia()
                    }
                    .disabled((selectedImage == nil && selectedVideoURL == nil) || uploadState.isUploading)
                }
            }
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .sheet(isPresented: $showingVideoPicker) {
            VideoPicker(videoURL: $selectedVideoURL)
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
        .onChange(of: selectedImage) { _, newImage in
            if newImage != nil {
                selectedVideoURL = nil
                clearVideoSelection()
            }
        }
        .onChange(of: selectedVideoURL) { _, newURL in
            if let url = newURL {
                selectedImage = nil
                setupVideoSelection(with: url)
            } else {
                clearVideoSelection()
            }
        }
        .onDisappear {
            clearVideoSelection()
        }
    }
    
    private func uploadMedia() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else {
            uploadState.fail(with: "Kullanıcı bilgileri alınamadı")
            return
        }
        
        let hasImage = selectedImage != nil
        let hasVideo = selectedVideoURL != nil
        
        if hasImage == hasVideo {
            uploadState.fail(with: "Lütfen bir fotoğraf veya video seçin.")
            return
        }
        
        uploadState.start(message: hasVideo ? "Video yükleniyor..." : "Fotoğraf yükleniyor...")
        Task {
            do {
                if let image = selectedImage {
                    let imageURL = try await StorageService.shared.uploadPhoto(image, relationshipId: relationshipId)
                    try await photoService.addPhoto(
                        relationshipId: relationshipId,
                        imageURL: imageURL,
                        thumbnailURL: nil,
                        videoURL: nil,
                        mediaType: .photo,
                        duration: nil,
                        title: normalizedTitle,
                        date: date,
                        location: normalizedLocation,
                        tags: normalizedTags,
                        userId: userId
                    )
                } else if let videoURL = selectedVideoURL {
                    let uploadResult = try await StorageService.shared.uploadPhotoVideo(from: videoURL, relationshipId: relationshipId)
                    try await photoService.addPhoto(
                        relationshipId: relationshipId,
                        imageURL: uploadResult.thumbnailURL ?? uploadResult.downloadURL,
                        thumbnailURL: uploadResult.thumbnailURL ?? uploadResult.downloadURL,
                        videoURL: uploadResult.downloadURL,
                        mediaType: .video,
                        duration: uploadResult.duration,
                        title: normalizedTitle,
                        date: date,
                        location: normalizedLocation,
                        tags: normalizedTags,
                        userId: userId
                    )
                }
                
                await MainActor.run {
                    uploadState.finish()
                    selectedImage = nil
                    selectedVideoURL = nil
                    clearVideoSelection()
                    dismiss()
                }
            } catch {
                print("Error uploading photo: \(error)")
                await MainActor.run {
                    uploadState.fail(with: "Fotoğraf yüklenirken hata oluştu: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func addTag() {
        let trimmed = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if !tags.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            tags.append(trimmed)
        }
        tagInput = ""
    }
    
    private var normalizedTitle: String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private var normalizedLocation: String? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    
    private var normalizedTags: [String]? {
        tags.isEmpty ? nil : tags
    }
    
    @ViewBuilder
    private var imagePickerSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Medya")
                .font(.headline)
            Text("Birlikte çektiğiniz fotoğraf veya videoyu albümünüze ekleyin.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxHeight: 260)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    )
                
                HStack(spacing: 12) {
                    Button {
                        showingImagePicker = true
                    } label: {
                        Label("Fotoğrafı Değiştir", systemImage: "arrow.triangle.2.circlepath")
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.16))
                            )
                    }
                    
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedImage = nil
                        }
                    } label: {
                        Label("Kaldır", systemImage: "trash")
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.12))
                            )
                    }
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
            } else if selectedVideoURL != nil {
                ZStack(alignment: .bottomLeading) {
                    if let thumbnail = selectedVideoThumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 260)
                            .frame(maxWidth: .infinity)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                            )
                    } else {
                        RoundedRectangle(cornerRadius: 18)
                            .fill(Color(.systemBackground).opacity(0.65))
                            .frame(height: 260)
                            .frame(maxWidth: .infinity)
                            .overlay {
                                if isGeneratingVideoThumbnail {
                                    ProgressView()
                                } else {
                                    Image(systemName: "video")
                                        .font(.system(size: 32, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                            }
                    }
                    
                    HStack(spacing: 10) {
                        Image(systemName: "video.fill")
                            .font(.caption.bold())
                        Text(formattedVideoDuration ?? "Video")
                            .font(.caption.bold())
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.55), in: Capsule())
                    .padding(14)
                }
                
                HStack(spacing: 12) {
                    Button {
                        showingVideoPicker = true
                    } label: {
                        Label("Videoyu Değiştir", systemImage: "arrow.triangle.2.circlepath.video")
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.16))
                            )
                    }
                    
                    Button(role: .destructive) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedVideoURL = nil
                            clearVideoSelection()
                        }
                    } label: {
                        Label("Kaldır", systemImage: "trash")
                            .font(.subheadline.bold())
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(Color.red.opacity(0.12))
                            )
                    }
                }
                .foregroundColor(themeManager.currentTheme.primaryColor)
            } else {
                VStack(spacing: 20) {
                    Text("Ne eklemek istersin?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 14) {
                        Button {
                            showingImagePicker = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle")
                                    .font(.system(size: 36, weight: .medium))
                                Text("Fotoğraf Seç")
                                    .font(.subheadline)
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        themeManager.currentTheme.primaryColor.opacity(0.35),
                                        style: StrokeStyle(lineWidth: 1.4, dash: [8, 6])
                                    )
                            )
                        }
                        
                        Button {
                            showingVideoPicker = true
                        } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "video.badge.plus")
                                    .font(.system(size: 36, weight: .medium))
                                Text("Video Seç")
                                    .font(.subheadline)
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .background(
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(.ultraThinMaterial)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(
                                        themeManager.currentTheme.primaryColor.opacity(0.35),
                                        style: StrokeStyle(lineWidth: 1.4, dash: [8, 6])
                                    )
                            )
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Detaylar")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Başlık (isteğe bağlı)")
                TextField("", text: $title, prompt: Text("Örneğin: Yaz tatili"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Tarih")
                HStack(spacing: 12) {
                    Image(systemName: "calendar")
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    DatePicker("", selection: $date, displayedComponents: .date)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.systemBackground).opacity(0.94))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                )
            }
            
            VStack(alignment: .leading, spacing: 12) {
                detailFieldLabel("Konum (isteğe bağlı)")
                TextField("", text: $location, prompt: Text("Örneğin: Kapadokya"))
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.94))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    @ViewBuilder
    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Etiketler")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    TextField("", text: $tagInput, prompt: Text("Etiket ekle"))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(.systemBackground).opacity(0.94))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                        )
                        .onSubmit(addTag)
                    
                    Button(action: addTag) {
                        Image(systemName: "plus")
                            .font(.headline)
                            .frame(width: 46, height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(themeManager.currentTheme.primaryColor)
                            )
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                }
                
                if !tags.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
                        ForEach(tags, id: \.self) { tag in
                            HStack(spacing: 6) {
                                Text("#\(tag)")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                Button {
                                    tags.removeAll { $0 == tag }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.caption2)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                            )
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                } else {
                    Text("Fotoğrafı daha sonra kolayca bulabilmek için etiket ekleyin. Örn: sahil, tatil, aile.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private func detailFieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }
    
    private func setupVideoSelection(with url: URL) {
        selectedVideoDuration = videoDuration(for: url)
        selectedVideoThumbnail = nil
        isGeneratingVideoThumbnail = true
        generateVideoThumbnail(from: url)
    }
    
    private func clearVideoSelection() {
        selectedVideoURL = nil
        selectedVideoDuration = nil
        selectedVideoThumbnail = nil
        isGeneratingVideoThumbnail = false
    }
    
    private func videoDuration(for url: URL) -> Double? {
        let asset = AVURLAsset(url: url)
        let duration = CMTimeGetSeconds(asset.duration)
        return duration.isFinite ? duration : nil
    }
    
    private var formattedVideoDuration: String? {
        guard let duration = selectedVideoDuration else { return nil }
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func generateVideoThumbnail(from url: URL) {
        isGeneratingVideoThumbnail = true
        Task.detached(priority: .utility) {
            let asset = AVURLAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            let thumbnailImage: UIImage?
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                thumbnailImage = UIImage(cgImage: cgImage)
            } catch {
                thumbnailImage = nil
            }
            await MainActor.run {
                guard self.selectedVideoURL == url else { return }
                self.selectedVideoThumbnail = thumbnailImage
                self.isGeneratingVideoThumbnail = false
            }
        }
    }
}
