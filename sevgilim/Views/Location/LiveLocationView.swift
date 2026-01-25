//
//  LiveLocationView.swift
//  sevgilim
//
//  Canlı konum görünümü - Partner konumu, harita, mesafe göstergesi
//

import SwiftUI
import MapKit
import CoreLocation

struct LiveLocationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var relationshipService: RelationshipService
    @EnvironmentObject var themeManager: ThemeManager
    
    @StateObject private var viewModel = LocationViewModel()
    
    @State private var showSettings = false
    @State private var showHistory = false
    @State private var showPermissionAlert = false
    
    var body: some View {
        ZStack {
            // Arka plan
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
                // Header
                headerView
                
                if viewModel.hasLocationPermission {
                    // Ana içerik
                    mainContent
                } else {
                    // İzin isteme görünümü
                    permissionRequestView
                }
            }
            
            // Buluşma Banner'ı
            if viewModel.showMeetingBanner {
                VStack {
                    MeetingBannerView(
                        meeting: viewModel.currentMeeting,
                        duration: viewModel.meetingDuration,
                        distance: viewModel.distanceToPartner,
                        onDismiss: { viewModel.dismissMeetingBanner() },
                        onEndMeeting: {
                            Task {
                                await viewModel.endMeetingManually()
                            }
                        }
                    )
                    .padding(.horizontal)
                    .padding(.top, 60)
                    
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(), value: viewModel.showMeetingBanner)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            configureViewModel()
            // Kullanıcı konumuna odaklan
            viewModel.centerOnUser()
        }
        .sheet(isPresented: $showSettings) {
            LocationSettingsView(settings: $viewModel.settings) { newSettings in
                viewModel.updateSettings(newSettings)
            }
        }
        .sheet(isPresented: $showHistory) {
            MeetingHistoryView(
                meetings: viewModel.meetingHistory,
                onDelete: { meeting in
                    Task {
                        await viewModel.deleteMeeting(meeting)
                    }
                }
            )
        }
        .alert("Konum İzni Gerekli", isPresented: $showPermissionAlert) {
            Button("Ayarlar") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("İptal", role: .cancel) {}
        } message: {
            Text("Konum özelliğini kullanabilmek için lütfen uygulama ayarlarından konum iznini etkinleştirin.")
        }
    }
    
    // MARK: - Header
    @Environment(\.dismiss) private var dismiss
    
    private var headerView: some View {
        HStack(spacing: 12) {
            // Geri butonu
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)
                    .padding(10)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            Image(systemName: "location.fill")
                .font(.system(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Canlı Konum")
                    .font(.title3)
                    .fontWeight(.bold)
                
                if let partnerName = relationshipService.currentRelationship?.partnerName(for: authService.currentUser?.id ?? "") {
                    Text("\(partnerName) ile paylaş")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Geçmiş butonu
            Button {
                showHistory = true
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
            
            // Ayarlar butonu
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .padding(8)
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 15)
    }
    
    // MARK: - Main Content
    
    private var mainContent: some View {
        VStack(spacing: 0) {
            // Paylaşım durumu toggle
            sharingToggleView
            
            // Harita
            mapView
            
            // Partner bilgi kartı
            if viewModel.isSharingLocation {
                partnerInfoCard
            }
            
            // Kontrol butonları
            if viewModel.isSharingLocation && (viewModel.userLocation != nil || viewModel.partnerLocation != nil) {
                mapControlButtons
            }
        }
    }
    
    // MARK: - Sharing Toggle
    
    private var sharingToggleView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.isSharingLocation ? "Konum Paylaşılıyor" : "Konum Paylaşımı Kapalı")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                if viewModel.isSharingLocation {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text("Aktif")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            Toggle("", isOn: Binding(
                get: { viewModel.isSharingLocation },
                set: { _ in viewModel.toggleLocationSharing() }
            ))
            .toggleStyle(SwitchToggleStyle(tint: themeManager.currentTheme.primaryColor))
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.bottom, 10)
    }
    
    // MARK: - Map View
    
    private var mapView: some View {
        ZStack {
            PartnerLocationMapView(
                userLocation: viewModel.userLocation,
                partnerLocation: viewModel.partnerLocation,
                region: $viewModel.mapRegion,
                isNearPartner: viewModel.isNearPartner
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)
            
            // Konum yenileme butonu
            VStack {
                HStack {
                    Spacer()
                    
                    Button {
                        viewModel.refreshLocation()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .padding(.trailing, 28)
                    .padding(.top, 8)
                }
                Spacer()
            }
            
            // Konum yok mesajı
            if !viewModel.isSharingLocation {
                VStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    
                    Text("Konum paylaşımını başlatın")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            }
        }
        .frame(height: 300)
    }
    
    // MARK: - Partner Info Card
    
    private var partnerInfoCard: some View {
        VStack(spacing: 12) {
            if let partnerLocation = viewModel.partnerLocation {
                HStack(spacing: 16) {
                    // Partner ikonu
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                        
                        Image(systemName: "heart.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        // Partner adı
                        if let partnerName = relationshipService.currentRelationship?.partnerName(for: authService.currentUser?.id ?? "") {
                            Text(partnerName)
                                .font(.headline)
                        }
                        
                        // Konum adı
                        Text(viewModel.partnerPlaceName)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        
                        // Son görülme
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption)
                            Text(viewModel.partnerLastSeen)
                                .font(.caption)
                        }
                        .foregroundColor(viewModel.isPartnerLocationRecent ? .green : .orange)
                    }
                    
                    Spacer()
                    
                    // Mesafe ve yön
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(viewModel.formattedDistance)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(viewModel.isNearPartner ? .green : .primary)
                        
                        if !viewModel.directionToPartner.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "location.north.fill")
                                    .font(.caption)
                                    .rotationEffect(.degrees(viewModel.bearingToPartner ?? 0))
                                Text(viewModel.directionToPartner)
                                    .font(.caption)
                            }
                            .foregroundColor(.secondary)
                        }
                        
                        // Batarya seviyesi
                        if let battery = viewModel.partnerBatteryLevel {
                            HStack(spacing: 4) {
                                Image(systemName: batteryIcon(for: battery))
                                    .font(.caption)
                                Text("\(battery)%")
                                    .font(.caption)
                            }
                            .foregroundColor(batteryColor(for: battery))
                        }
                    }
                }
            } else {
                // Partner konumu yok
                HStack(spacing: 12) {
                    Image(systemName: "location.slash")
                        .font(.system(size: 30))
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Partner konumu bulunamadı")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("Sevgilinizin de konum paylaşımını açması gerekiyor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    // MARK: - Map Control Buttons
    
    private var mapControlButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.centerOnUser()
            } label: {
                Label("Beni Göster", systemImage: "person.fill")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            
            Button {
                viewModel.centerOnPartner()
            } label: {
                Label("Onu Göster", systemImage: "heart.fill")
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
            }
            
            Button {
                viewModel.showBothLocations()
            } label: {
                Label("İkimiz", systemImage: "person.2.fill")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
            }
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .padding(.bottom, 20)
    }
    
    // MARK: - Permission Request View
    
    private var permissionRequestView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "location.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("Konum İzni Gerekli")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("Sevgilinizin konumunu görebilmek ve buluştuğunuzda bildirim alabilmek için konum izni vermeniz gerekiyor.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 12) {
                Button {
                    viewModel.requestLocationPermission()
                } label: {
                    Text("Konum İznini Ver")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [themeManager.currentTheme.primaryColor, themeManager.currentTheme.secondaryColor],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
                .padding(.horizontal, 40)
                
                Button {
                    showPermissionAlert = true
                } label: {
                    Text("Ayarlara Git")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Helpers
    
    private func configureViewModel() {
        guard let userId = authService.currentUser?.id,
              let relationship = relationshipService.currentRelationship,
              let relationshipId = relationship.id else { return }
        
        let partnerId = relationship.partnerId(for: userId)
        let partnerName = relationship.partnerName(for: userId)
        
        viewModel.configure(
            userId: userId,
            relationshipId: relationshipId,
            partnerId: partnerId,
            partnerName: partnerName
        )
    }
    
    private func batteryIcon(for level: Int) -> String {
        switch level {
        case 0...20: return "battery.0"
        case 21...40: return "battery.25"
        case 41...60: return "battery.50"
        case 61...80: return "battery.75"
        default: return "battery.100"
        }
    }
    
    private func batteryColor(for level: Int) -> Color {
        switch level {
        case 0...20: return .red
        case 21...40: return .orange
        default: return .green
        }
    }
}

#Preview {
    NavigationView {
        LiveLocationView()
            .environmentObject(AuthenticationService())
            .environmentObject(RelationshipService())
            .environmentObject(ThemeManager())
    }
}
