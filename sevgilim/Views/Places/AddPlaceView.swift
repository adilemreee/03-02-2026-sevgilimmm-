//
//  AddPlaceView.swift
//  sevgilim
//

import SwiftUI
import MapKit
import CoreLocation

struct AddPlaceView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var placeService: PlaceService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @StateObject private var locationService = LocationService()
    
    @State private var searchText = ""
    @State private var searchResults: [MKMapItem] = []
    @State private var isSearching = false
    @State private var selectedResult: MKMapItem?
    @State private var placeName = ""
    @State private var placeAddress = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var note = ""
    @State private var date = Date()
    @State private var isAdding = false
    @State private var searchTask: Task<Void, Never>?
    @State private var isGettingCurrentLocation = false
    @State private var showLocationAlert = false
    @State private var locationAlertMessage = ""
    @State private var showMapPicker = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient Background
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
                        // Header
                        headerSection
                        
                        // Search Section
                        searchSection
                        
                        // Location Buttons Section
                        locationButtonsSection
                        
                        // Place Info Section
                        placeInfoSection
                        
                        // Note Section
                        noteSection
                        
                        // Location Status
                        locationStatusSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("İptal")
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        addPlace()
                    }
                    .disabled(placeName.isEmpty || latitude == 0 || isAdding)
                    .foregroundColor(placeName.isEmpty || latitude == 0 ? .secondary : themeManager.currentTheme.primaryColor)
                }
            }
            .overlay {
                if isAdding {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Ekleniyor...")
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
            .alert("Konum İzni", isPresented: $showLocationAlert) {
                Button("Ayarlar") {
                    if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(settingsUrl)
                    }
                }
                Button("Tamam", role: .cancel) { }
            } message: {
                Text(locationAlertMessage)
            }
            .sheet(isPresented: $showMapPicker) {
                MapPickerView(
                    showMapPicker: $showMapPicker,
                    placeName: $placeName,
                    placeAddress: $placeAddress,
                    latitude: $latitude,
                    longitude: $longitude,
                    locationService: locationService,
                    themeManager: themeManager
                )
            }
            .onAppear {
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestLocationPermission()
                } else if locationService.authorizationStatus == .authorizedWhenInUse ||
                          locationService.authorizationStatus == .authorizedAlways {
                    if locationService.currentLocation == nil {
                        locationService.getCurrentLocation()
                    }
                }
            }
        }
    }
    
    // MARK: - Header Section
    @ViewBuilder
    private var headerSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin.circle.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Yeni Mekan")
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text("Özel mekanlarınızı kaydedin")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Search Section
    @ViewBuilder
    private var searchSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.blue)
                Text("Yer Ara")
                    .font(.headline)
            }
            
            // Search Field
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("", text: $searchText, prompt: Text("Yer adı yazın..."))
                    .textFieldStyle(.plain)
                    .onChange(of: searchText) { _, newValue in
                        searchTask?.cancel()
                        
                        if !newValue.isEmpty {
                            searchTask = Task {
                                try? await Task.sleep(nanoseconds: 300_000_000)
                                
                                if !Task.isCancelled {
                                    await MainActor.run {
                                        searchPlaces(query: newValue)
                                    }
                                }
                            }
                        } else {
                            searchResults = []
                            isSearching = false
                        }
                    }
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        searchResults = []
                        isSearching = false
                        searchTask?.cancel()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
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
            
            // Search Status
            if isSearching {
                HStack(spacing: 8) {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Aranıyor...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Search Results
            if !searchResults.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Öneriler (\(searchResults.count))")
                        .font(.caption.weight(.medium))
                        .foregroundColor(.secondary)
                    
                    ForEach(Array(searchResults.enumerated()), id: \.offset) { index, result in
                        Button {
                            selectSearchResult(result)
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                        .frame(width: 28, height: 28)
                                    
                                    Text("\(index + 1)")
                                        .font(.caption.weight(.semibold))
                                        .foregroundColor(themeManager.currentTheme.primaryColor)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name ?? "Bilinmeyen Yer")
                                        .font(.subheadline.weight(.medium))
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    if let address = result.placemark.title, !address.isEmpty {
                                        Text(address)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(selectedResult?.name == result.name ?
                                          themeManager.currentTheme.primaryColor.opacity(0.1) :
                                          Color(.systemBackground).opacity(0.7))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Location Buttons Section
    @ViewBuilder
    private var locationButtonsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Konum Seçimi")
                .font(.headline)
            
            VStack(spacing: 12) {
                // Current Location Button
                Button {
                    useCurrentLocation()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "location.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(
                                    colors: [.blue, .cyan],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            if isGettingCurrentLocation {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Konum alınıyor...")
                                        .font(.subheadline.weight(.medium))
                                }
                            } else {
                                Text("Mevcut Konumu Kullan")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundColor(.primary)
                                Text("GPS ile konumunuzu tespit edin")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.7))
                    )
                }
                .disabled(isGettingCurrentLocation)
                .buttonStyle(.plain)
                
                // Map Picker Button
                Button {
                    showMapPicker = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "map.fill")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 40, height: 40)
                            .background(
                                LinearGradient(
                                    colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Haritadan Seç")
                                .font(.subheadline.weight(.medium))
                                .foregroundColor(.primary)
                            Text("Harita üzerinde konum seçin")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(.systemBackground).opacity(0.7))
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Place Info Section
    @ViewBuilder
    private var placeInfoSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Mekan Bilgileri")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                fieldLabel("Yer Adı")
                TextField("", text: $placeName, prompt: Text("Mekan adını girin"))
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
                fieldLabel("Adres (isteğe bağlı)")
                TextField("", text: $placeAddress, prompt: Text("Adres bilgisi"))
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
                fieldLabel("Ziyaret Tarihi")
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
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Note Section
    @ViewBuilder
    private var noteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Not")
                .font(.headline)
            
            ZStack(alignment: .topLeading) {
                if note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Bu yer hakkında notlarınız...")
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                }
                
                TextEditor(text: $note)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.systemBackground).opacity(0.94))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
    }
    
    // MARK: - Location Status Section
    @ViewBuilder
    private var locationStatusSection: some View {
        if latitude != 0 && longitude != 0 {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Konum Seçildi")
                        .font(.subheadline.weight(.medium))
                    Text(String(format: "%.4f, %.4f", latitude, longitude))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.green.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.green.opacity(0.3), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Helper Views
    private func fieldLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption.weight(.semibold))
            .foregroundColor(.secondary)
            .kerning(0.5)
    }
    
    // MARK: - Functions
    private func searchPlaces(query: String) {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        
        if let userLocation = locationService.currentLocation {
            searchRequest.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 30000,
                longitudinalMeters: 30000
            )
        } else {
            searchRequest.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597),
                span: MKCoordinateSpan(latitudeDelta: 5.0, longitudeDelta: 5.0)
            )
        }
        
        let search = MKLocalSearch(request: searchRequest)
        search.start { response, error in
            DispatchQueue.main.async {
                self.isSearching = false
                
                if let error = error {
                    print("❌ Search error: \(error.localizedDescription)")
                    return
                }
                
                guard let response = response else {
                    print("❌ No response from search")
                    return
                }
                
                var filteredResults = response.mapItems.filter { mapItem in
                    guard let name = mapItem.name, !name.isEmpty else { return false }
                    return true
                }
                
                if let userLocation = self.locationService.currentLocation {
                    filteredResults.sort { item1, item2 in
                        guard let loc1 = item1.placemark.location,
                              let loc2 = item2.placemark.location else {
                            return false
                        }
                        
                        let distance1 = userLocation.distance(from: loc1)
                        let distance2 = userLocation.distance(from: loc2)
                        
                        return distance1 < distance2
                    }
                }
                
                let limitedResults = Array(filteredResults.prefix(10))
                print("✅ Found \(limitedResults.count) places for query: '\(query)'")
                self.searchResults = limitedResults
            }
        }
    }
    
    private func selectSearchResult(_ result: MKMapItem) {
        selectedResult = result
        placeName = result.name ?? ""
        placeAddress = result.placemark.title ?? ""
        latitude = result.placemark.location?.coordinate.latitude ?? 0
        longitude = result.placemark.location?.coordinate.longitude ?? 0
        
        searchText = ""
        searchResults = []
        isSearching = false
        searchTask?.cancel()
        searchTask = nil
        
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func useCurrentLocation() {
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
            return
        }
        
        guard locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways else {
            locationAlertMessage = "Konum izni verilmedi. Lütfen ayarlardan konum iznini açın."
            showLocationAlert = true
            return
        }
        
        guard CLLocationManager.locationServicesEnabled() else {
            locationAlertMessage = "Konum servisleri kapalı. Lütfen ayarlardan konum servislerini açın."
            showLocationAlert = true
            return
        }
        
        isGettingCurrentLocation = true
        locationService.getCurrentLocation()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let location = self.locationService.currentLocation {
                self.latitude = location.coordinate.latitude
                self.longitude = location.coordinate.longitude
                
                self.locationService.getPlaceName(for: location) { placeName, address in
                    DispatchQueue.main.async {
                        if let placeName = placeName {
                            self.placeName = placeName
                        }
                        if let address = address {
                            self.placeAddress = address
                        }
                        self.isGettingCurrentLocation = false
                    }
                }
            } else {
                self.isGettingCurrentLocation = false
                if let error = self.locationService.locationError {
                    self.locationAlertMessage = "Konum alınamadı: \(error)"
                    self.showLocationAlert = true
                }
            }
        }
    }
    
    private func addPlace() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else { return }
        
        isAdding = true
        Task {
            do {
                try await placeService.addPlace(
                    relationshipId: relationshipId,
                    name: placeName,
                    address: placeAddress.isEmpty ? nil : placeAddress,
                    latitude: latitude,
                    longitude: longitude,
                    note: note.isEmpty ? nil : note,
                    photoURLs: nil,
                    date: date,
                    userId: userId
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error adding place: \(error)")
                await MainActor.run {
                    isAdding = false
                }
            }
        }
    }
}

// MARK: - Map Picker View
struct MapPickerView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var showMapPicker: Bool
    @Binding var placeName: String
    @Binding var placeAddress: String
    @Binding var latitude: Double
    @Binding var longitude: Double
    
    let locationService: LocationService
    let themeManager: ThemeManager
    
    @State private var selectedCoordinate: CLLocationCoordinate2D?
    @State private var centerOnCoordinate: CLLocationCoordinate2D?
    
    var body: some View {
        NavigationView {
            ZStack {
                InteractiveMapView(
                    selectedCoordinate: $selectedCoordinate,
                    centerOnCoordinate: $centerOnCoordinate,
                    initialCoordinate: locationService.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
                )
                .ignoresSafeArea()
                
                VStack {
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 16, weight: .semibold))
                                Text("Geri")
                                    .font(.system(size: 17))
                            }
                            .foregroundColor(themeManager.currentTheme.primaryColor)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            if let userLocation = locationService.currentLocation {
                                centerOnCoordinate = userLocation.coordinate
                                selectedCoordinate = userLocation.coordinate
                            }
                        }) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 18))
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    
                    Spacer()
                    
                    VStack(spacing: 0) {
                        if selectedCoordinate == nil {
                            HStack(spacing: 10) {
                                Image(systemName: "hand.tap.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                
                                Text("Haritada basılı tutarak konum seçin")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.ultraThinMaterial)
                            .cornerRadius(16)
                            .padding(.horizontal)
                            .padding(.bottom, 8)
                        }
                        
                        if let coordinate = selectedCoordinate {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "mappin.circle.fill")
                                        .font(.system(size: 28))
                                        .foregroundColor(.red)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Konum Seçildi")
                                            .font(.system(size: 18, weight: .semibold))
                                        
                                        Text(String(format: "%.6f, %.6f", coordinate.latitude, coordinate.longitude))
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Button(action: {
                                        selectedCoordinate = nil
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Button(action: {
                                    selectLocation(coordinate)
                                }) {
                                    HStack {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 20))
                                        Text("Bu Konumu Seç")
                                            .font(.system(size: 17, weight: .semibold))
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(themeManager.currentTheme.primaryColor)
                                    .cornerRadius(14)
                                }
                            }
                            .padding(20)
                            .background(.ultraThinMaterial)
                            .cornerRadius(20)
                            .padding(.horizontal)
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }
    
    private func selectLocation(_ coordinate: CLLocationCoordinate2D) {
        latitude = coordinate.latitude
        longitude = coordinate.longitude
        
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        locationService.getPlaceName(for: location) { name, address in
            if let name = name {
                placeName = name
            }
            if let address = address {
                placeAddress = address
            }
        }
        
        showMapPicker = false
    }
}

// MARK: - Interactive Map View (UIKit)
struct InteractiveMapView: UIViewRepresentable {
    @Binding var selectedCoordinate: CLLocationCoordinate2D?
    @Binding var centerOnCoordinate: CLLocationCoordinate2D?
    let initialCoordinate: CLLocationCoordinate2D
    
    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.mapType = .standard
        mapView.showsCompass = true
        mapView.showsScale = true
        
        let region = MKCoordinateRegion(
            center: initialCoordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        mapView.setRegion(region, animated: false)
        
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        if let coordinate = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Seçilen Konum"
            mapView.addAnnotation(annotation)
        }
        
        if let centerCoordinate = centerOnCoordinate {
            let region = MKCoordinateRegion(
                center: centerCoordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
            
            DispatchQueue.main.async {
                self.centerOnCoordinate = nil
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: InteractiveMapView
        
        init(_ parent: InteractiveMapView) {
            self.parent = parent
        }
        
        @objc func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
            guard gesture.state == .began else { return }
            
            let mapView = gesture.view as! MKMapView
            let locationInView = gesture.location(in: mapView)
            let coordinate = mapView.convert(locationInView, toCoordinateFrom: mapView)
            
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            DispatchQueue.main.async {
                self.parent.selectedCoordinate = coordinate
            }
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            
            let identifier = "SelectedLocation"
            var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
            
            if annotationView == nil {
                annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
                annotationView?.canShowCallout = false
            } else {
                annotationView?.annotation = annotation
            }
            
            annotationView?.markerTintColor = .systemRed
            annotationView?.glyphImage = UIImage(systemName: "mappin")
            annotationView?.animatesWhenAdded = true
            
            return annotationView
        }
    }
}
