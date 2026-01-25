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
            Form {
                Section("Yer Bilgileri") {
                    // Search Field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Yer Ara")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundColor(.secondary)
                            
                            TextField("Yer adı yazın...", text: $searchText)
                                .textFieldStyle(PlainTextFieldStyle())
                                .onChange(of: searchText) { _, newValue in
                                    // Önceki arama task'ını iptal et
                                    searchTask?.cancel()
                                    
                                    if !newValue.isEmpty {
                                        // 0.3 saniye bekle, sonra ara (daha hızlı)
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
                            
                            // Clear button
                            if !searchText.isEmpty {
                                Button(action: {
                                    searchText = ""
                                    searchResults = []
                                    isSearching = false
                                    searchTask?.cancel()
                                }) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        
                        // Search Results
                        if !searchResults.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Öneriler (\(searchResults.count))")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 4)
                                
                                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, result in
                                    Button(action: {
                                        selectSearchResult(result)
                                    }) {
                                        HStack(spacing: 12) {
                                            // Numara ikonu
                                            ZStack {
                                                Circle()
                                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.15))
                                                    .frame(width: 24, height: 24)
                                                
                                                Text("\(index + 1)")
                                                    .font(.caption)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                            }
                                            
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(result.name ?? "Bilinmeyen Yer")
                                                    .font(.subheadline)
                                                    .fontWeight(.medium)
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
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            selectedResult?.name == result.name ?
                                            themeManager.currentTheme.primaryColor.opacity(0.1) :
                                            Color(.systemGray6)
                                        )
                                        .cornerRadius(8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.top, 4)
                        }
                        
                        if isSearching {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Aranıyor...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.top, 4)
                        }
                    }
                    
                    // Konum Seçme Butonları
                    VStack(spacing: 12) {
                        // Mevcut Konumu Kullan Butonu
                        Button(action: {
                            useCurrentLocation()
                        }) {
                            HStack {
                                Image(systemName: "location.fill")
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                
                                if isGettingCurrentLocation {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Konum alınıyor...")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                } else {
                                    Text("Mevcut Konumu Kullan")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .disabled(isGettingCurrentLocation)
                        .buttonStyle(PlainButtonStyle())
                        
                        // Haritadan Seç Butonu
                        Button(action: {
                            showMapPicker = true
                        }) {
                            HStack {
                                Image(systemName: "map.fill")
                                    .foregroundColor(themeManager.currentTheme.primaryColor)
                                
                                Text("Haritadan Seç")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                Spacer()
                            }
                            .padding(.vertical, 12)
                            .padding(.horizontal, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(themeManager.currentTheme.primaryColor.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(themeManager.currentTheme.primaryColor.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Manual Entry Fields
                    TextField("Yer Adı", text: $placeName)
                    TextField("Adres (isteğe bağlı)", text: $placeAddress)
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                
                Section("Not") {
                    TextField("Bu yer hakkında not ekleyin...", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Konum") {
                    if latitude != 0 && longitude != 0 {
                        HStack {
                            Image(systemName: "location.fill")
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                            Text("Konum seçildi")
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Yer arama sonucu seçin")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Yer Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        addPlace()
                    }
                    .disabled(placeName.isEmpty || latitude == 0 || isAdding)
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
                        .background(Color(.systemBackground))
                        .cornerRadius(15)
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
                // View açıldığında konum iznini kontrol et ve konumu al
                if locationService.authorizationStatus == .notDetermined {
                    locationService.requestLocationPermission()
                } else if locationService.authorizationStatus == .authorizedWhenInUse ||
                          locationService.authorizationStatus == .authorizedAlways {
                    // Konum izni varsa konumu al
                    if locationService.currentLocation == nil {
                        locationService.getCurrentLocation()
                    }
                }
            }
        }
    }
    
    private func searchPlaces(query: String) {
        // Minimum 2 karakter kontrolü
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        let searchRequest = MKLocalSearch.Request()
        searchRequest.naturalLanguageQuery = query
        
        // Kullanıcının konumuna göre ara
        if let userLocation = locationService.currentLocation {
            // Kullanıcının konumunu merkez al (30km yarıçap)
            searchRequest.region = MKCoordinateRegion(
                center: userLocation.coordinate,
                latitudinalMeters: 30000,
                longitudinalMeters: 30000
            )
        } else {
            // Konum yoksa Türkiye genelinde ara
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
                
                // Sonuçları filtrele
                var filteredResults = response.mapItems.filter { mapItem in
                    guard let name = mapItem.name, !name.isEmpty else { return false }
                    return true
                }
                
                // Kullanıcının konumuna göre sırala (en yakından en uzağa)
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
                
                // En fazla 10 sonuç göster
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
        
        // Arama state'ini tamamen temizle
        searchText = ""
        searchResults = []
        isSearching = false
        searchTask?.cancel()
        searchTask = nil
        
        // Keyboard'u kapat
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
    
    private func useCurrentLocation() {
        // Önce konum izni kontrol et
        if locationService.authorizationStatus == .notDetermined {
            locationService.requestLocationPermission()
            return
        }
        
        guard locationService.authorizationStatus == .authorizedWhenInUse || locationService.authorizationStatus == .authorizedAlways else {
            // İzin verilmemiş, kullanıcıyı uyar
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
        
        // Mevcut konumu al
        locationService.getCurrentLocation()
        
        // Konum alındığında işle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if let location = self.locationService.currentLocation {
                self.latitude = location.coordinate.latitude
                self.longitude = location.coordinate.longitude
                
                // Yer adını ve adresini al
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
                // Apple Maps benzeri interaktif harita
                InteractiveMapView(
                    selectedCoordinate: $selectedCoordinate,
                    centerOnCoordinate: $centerOnCoordinate,
                    initialCoordinate: locationService.currentLocation?.coordinate ?? CLLocationCoordinate2D(latitude: 39.9334, longitude: 32.8597)
                )
                .ignoresSafeArea()
                
                // Üst bilgi ve kontroller
                VStack {
                    // Üst bar
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
                        
                        // Mevcut konuma git butonu
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
                    
                    // Alt bilgi ve seçim kartı
                    VStack(spacing: 0) {
                        // İpucu
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
                        
                        // Seçim kartı
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
                                
                                // Seç butonu
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
        
        // Seçilen konumun adresini al
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        locationService.getPlaceName(for: location) { name, address in
            if let name = name {
                placeName = name
            }
            if let address = address {
                placeAddress = address
            }
        }
        
        // Modal'ı kapat
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
        
        // Harita tipini standard yap (Apple Maps benzeri)
        mapView.showsCompass = true
        mapView.showsScale = true
        
        // Başlangıç konumunu ayarla
        let region = MKCoordinateRegion(
            center: initialCoordinate,
            latitudinalMeters: 5000,
            longitudinalMeters: 5000
        )
        mapView.setRegion(region, animated: false)
        
        // Long press gesture ekle (Apple Maps gibi)
        let longPress = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleLongPress(_:))
        )
        longPress.minimumPressDuration = 0.5
        mapView.addGestureRecognizer(longPress)
        
        return mapView
    }
    
    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Pin'i güncelle
        mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
        
        if let coordinate = selectedCoordinate {
            let annotation = MKPointAnnotation()
            annotation.coordinate = coordinate
            annotation.title = "Seçilen Konum"
            mapView.addAnnotation(annotation)
        }
        
        // Merkez koordinat değiştiyse haritayı kaydır
        if let centerCoordinate = centerOnCoordinate {
            let region = MKCoordinateRegion(
                center: centerCoordinate,
                latitudinalMeters: 1000,
                longitudinalMeters: 1000
            )
            mapView.setRegion(region, animated: true)
            
            // Koordinatı sıfırla (tekrar tetiklenmesin)
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
            
            // Hafif titreşim (haptic feedback)
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
            
            // Koordinatı güncelle
            DispatchQueue.main.async {
                self.parent.selectedCoordinate = coordinate
            }
        }
        
        // Pin görünümünü özelleştir (Apple Maps benzeri)
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
            
            // Kırmızı pin (Apple Maps benzeri)
            annotationView?.markerTintColor = .systemRed
            annotationView?.glyphImage = UIImage(systemName: "mappin")
            annotationView?.animatesWhenAdded = true
            
            return annotationView
        }
    }
}
