//
//  PlacesView.swift
//  sevgilim
//

import SwiftUI
import MapKit

struct PlacesView: View {
    @EnvironmentObject var placeService: PlaceService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddPlace = false
    @State private var viewMode: ViewMode = .list
    @State private var searchText = ""
    @State private var selectedPlace: Place?
    
    enum ViewMode {
        case list, map
    }
    
    private var headerSubtitle: String {
        switch viewMode {
        case .list:
            return searchText.isEmpty ?
                "Birlikte keşfettiğiniz yerler" :
                "Aradığın yeri daha hızlı bul"
        case .map:
            return "Birlikte keşfettiğiniz noktalar"
        }
    }
    
    var filteredPlaces: [Place] {
        if searchText.isEmpty {
            return placeService.places
        } else {
            return placeService.places.filter { place in
                place.name.localizedCaseInsensitiveContains(searchText) ||
                (place.address?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (place.note?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.3),
                        themeManager.currentTheme.secondaryColor.opacity(0.2)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    SectionHeroHeader(
                        systemImage: "map.fill",
                        iconColors: [.green, .blue],
                        title: "Gittiğimiz Yerler",
                        subtitle: headerSubtitle,
                        countValue: "\(filteredPlaces.count)",
                        countTint: .green,
                        countLabel: searchText.isEmpty ? "Yer" : "Sonuç"
                    )
                    
                    Picker("Görünüm", selection: $viewMode) {
                        Image(systemName: "list.bullet").tag(ViewMode.list)
                        Image(systemName: "map").tag(ViewMode.map)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    
                    // Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Yer ara...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 15)
                    
                    // Content
                    if placeService.places.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "map")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary.opacity(0.6))
                            
                            VStack(spacing: 8) {
                                Text("Henüz yer eklenmemiş")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text("Birlikte gittiğiniz yerleri ekleyin")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                            
                            Button(action: { showingAddPlace = true }) {
                                Label("İlk Yeri Ekle", systemImage: "plus.circle.fill")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(themeManager.currentTheme.primaryColor)
                                    .cornerRadius(12)
                            }
                        }
                        .frame(maxHeight: .infinity)
                    } else {
                        if viewMode == .list {
                            // List View
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(filteredPlaces) { place in
                                        PlaceCard(place: place) {
                                            selectedPlace = place
                                        }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        } else {
                            // Map View
                            PlacesMapView(places: filteredPlaces, selectedPlace: $selectedPlace)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                }
                
                // Loading Overlay
                if placeService.isLoading {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Yükleniyor...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
                }
                
                // Floating Add Button
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: { showingAddPlace = true }) {
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
                        .padding(.bottom, 80)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .sheet(isPresented: $showingAddPlace) {
            AddPlaceView()
                .environmentObject(placeService)
                .environmentObject(authService)
                .environmentObject(themeManager)
        }
        .sheet(item: $selectedPlace) { place in
            PlaceDetailView(place: place)
                .environmentObject(placeService)
                .environmentObject(themeManager)
        }
    }
}

// MARK: - Place Card
struct PlaceCard: View {
    let place: Place
    let onTap: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 15) {
                // Map Icon
                ZStack {
                    Circle()
                        .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "map.fill")
                        .font(.title2)
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                }
                
                // Content
                VStack(alignment: .leading, spacing: 4) {
                    Text(place.name)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    if let address = place.address {
                        Text(address)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                    
                    Text(place.date, formatter: DateFormatter.displayFormat)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Places Map View
struct PlacesMapView: View {
    let places: [Place]
    @Binding var selectedPlace: Place?
    @State private var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597), // Ankara
        span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
    )
    
    var body: some View {
        ZStack {
            Map(coordinateRegion: $region, annotationItems: places) { place in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)) {
                    Button(action: { selectedPlace = place }) {
                        Image(systemName: "mappin.circle.fill")
                            .font(.title)
                            .foregroundColor(.red)
                            .background(
                                Circle()
                                    .fill(.white)
                                    .frame(width: 20, height: 20)
                            )
                    }
                }
            }
            .ignoresSafeArea()
            
            if places.isEmpty {
                VStack(spacing: 20) {
                    Image(systemName: "map")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary.opacity(0.6))
                    
                    Text("Henüz yer eklenmemiş")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Harita görünümü için yer ekleyin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
        }
        .onAppear {
            if let firstPlace = places.first {
                region = MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: firstPlace.latitude, longitude: firstPlace.longitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                )
            }
        }
    }
}

// MARK: - Place Detail View
struct PlaceDetailView: View {
    let place: Place
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var placeService: PlaceService
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Map Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Konum")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Map(coordinateRegion: .constant(MKCoordinateRegion(
                            center: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude),
                            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                        )), annotationItems: [place]) { place in
                            MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)) {
                                Image(systemName: "mappin.circle.fill")
                                    .font(.title)
                                    .foregroundColor(.red)
                            }
                        }
                        .frame(height: 200)
                        .cornerRadius(12)
                    }
                    
                    // Details Section
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Detaylar")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                Text(place.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            if let address = place.address {
                                HStack {
                                    Image(systemName: "building.2.fill")
                                        .foregroundColor(.secondary)
                                    Text(address)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundColor(.secondary)
                                Text(place.date, formatter: DateFormatter.displayFormat)
                                    .foregroundColor(.secondary)
                            }
                            
                            if let note = place.note, !note.isEmpty {
                                VStack(alignment: .leading, spacing: 5) {
                                    HStack {
                                        Image(systemName: "note.text")
                                            .foregroundColor(.secondary)
                                        Text("Not")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                    }
                                    Text(note)
                                        .foregroundColor(.primary)
                                        .padding(.leading, 20)
                                }
                            }
                        }
                        .padding()
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Yer Detayı")
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
            .alert("Yeri Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        try? await placeService.deletePlace(place)
                        dismiss()
                    }
                }
            } message: {
                Text("Bu yeri silmek istediğinizden emin misiniz?")
            }
        }
    }
}
