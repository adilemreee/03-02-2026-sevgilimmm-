//
//  ProfileView.swift
//  sevgilim
//

import SwiftUI
import UserNotifications

struct ProfileView: View {
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var relationshipService: RelationshipService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingEditProfile = false
    @State private var showingEditRelationship = false
    @State private var showingThemeSelector = false
    @State private var showingSettings = false
    @State private var showingSignOutAlert = false
    
    var body: some View {
        ZStack {
            // Animated gradient background
            AnimatedGradientBackground(theme: themeManager.currentTheme)
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 25) {
                    // Profile Header Card
                    ProfileHeaderCard(
                        profileImageURL: authService.currentUser?.profileImageURL,
                        name: authService.currentUser?.name ?? "",
                        email: authService.currentUser?.email ?? "",
                        onEditProfile: { showingEditProfile = true }
                    )
                    
                    // Relationship Info Card
                    if let relationship = relationshipService.currentRelationship {
                        RelationshipInfoCard(
                            relationship: relationship,
                            currentUserId: authService.currentUser?.id ?? "",
                            onEdit: { showingEditRelationship = true }
                        )
                    }
                    
                    // Theme Selector Card
                    ThemeCard(
                        currentTheme: themeManager.currentTheme,
                        onTap: { showingThemeSelector = true }
                    )
                    
                    // Settings Card - Tıklanabilir
                    SettingsButtonCard(
                        onTap: { showingSettings = true }
                    )
                    
                    // Sign Out Card
                    SignOutCard(
                        onSignOut: { showingSignOutAlert = true }
                    )
                    
                    // Made with Love Footer
                    VStack(spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.pink.opacity(0.6))
                            
                            Text("Bu uygulama aşkımmm içinnn özenle yapıldı")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .italic()
                            
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.pink.opacity(0.6))
                        }
                        
                        Text("🧡")
                            .font(.caption2)
                    }
                    .padding(.top, 10)
                    .padding(.bottom, 10)
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationTitle("Profil")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showingEditRelationship) {
            EditRelationshipView()
        }
        .sheet(isPresented: $showingThemeSelector) {
            ThemeSelectorView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .alert("Çıkış Yap", isPresented: $showingSignOutAlert) {
            Button("İptal", role: .cancel) {}
            Button("Çıkış Yap", role: .destructive) {
                authService.signOut()
            }
        } message: {
            Text("Çıkış yapmak istediğinizden emin misiniz?")
        }
    }
}

// MARK: - Profile Header Card
struct ProfileHeaderCard: View {
    let profileImageURL: String?
    let name: String
    let email: String
    let onEditProfile: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Image with Caching
            if let urlString = profileImageURL {
                CachedAsyncImage(url: urlString, thumbnail: true) { image, _ in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white, lineWidth: 4))
                        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                } placeholder: {
                    ProfilePlaceholderModern()
                }
            } else {
                ProfilePlaceholderModern()
            }
            
            // Name and Email
            VStack(spacing: 8) {
                Text(name)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                
                Text(email)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            // Edit Button
            Button(action: onEditProfile) {
                HStack {
                    Image(systemName: "pencil")
                    Text("Profili Düzenle")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 30)
                .padding(.vertical, 12)
                .background(
                    LinearGradient(
                        colors: [Color.white.opacity(0.3), Color.white.opacity(0.2)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(25)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 25))
        .shadow(color: .black.opacity(0.1), radius: 15, x: 0, y: 5)
    }
}

struct ProfilePlaceholderModern: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(
                    colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 120, height: 120)
                .overlay(Circle().stroke(Color.white, lineWidth: 4))
                .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
            
            Image(systemName: "person.fill")
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.8))
        }
    }
}

// MARK: - Relationship Info Card
struct RelationshipInfoCard: View {
    let relationship: Relationship
    let currentUserId: String
    let onEdit: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "heart.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                Text("İlişki Bilgileri")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            VStack(spacing: 15) {
                InfoRow(
                    icon: "person.2.fill",
                    title: "Sevgilimm",
                    value: relationship.partnerName(for: currentUserId)
                )
                
                InfoRow(
                    icon: "calendar",
                    title: "Başlangıç",
                    value: relationship.startDate.formatted(date: .long, time: .omitted)
                )
                
                InfoRow(
                    icon: "clock.fill",
                    title: "Birlikte",
                    value: "\(relationship.startDate.daysBetween(Date())) gün"
                )
            }
            
            Button(action: onEdit) {
                HStack {
                    Image(systemName: "pencil.circle.fill")
                    Text("Düzenle")
                }
                .font(.subheadline.bold())
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.2))
                .cornerRadius(15)
            }
        }
        .padding(25)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white.opacity(0.9))
                .frame(width: 25)
            
            Text(title)
                .foregroundColor(.white.opacity(0.9))
            
            Spacer()
            
            Text(value)
                .foregroundColor(.white)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let currentTheme: AppTheme
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "paintpalette.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("Tema")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 15) {
                    Circle()
                        .fill(currentTheme.primaryColor)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    
                    Circle()
                        .fill(currentTheme.secondaryColor)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    
                    Circle()
                        .fill(currentTheme.accentColor)
                        .frame(width: 40, height: 40)
                        .overlay(Circle().stroke(Color.white, lineWidth: 2))
                    
                    Spacer()
                    
                    Text(currentTheme.displayName)
                        .font(.headline)
                        .foregroundColor(.white)
                }
            }
            .padding(25)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Settings Button Card
struct SettingsButtonCard: View {
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text("Ayarlar")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            .padding(25)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        }
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingDeleteAccountAlert = false
    @State private var showingClearCacheAlert = false
    @State private var showingNotificationSettings = false
    @State private var cacheCleared = false
    
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
                
                ScrollView {
                    VStack(spacing: 20) {
                        // Header
                        HStack(spacing: 12) {
                            Image(systemName: "gearshape.2.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.blue, .cyan],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Ayarlar")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text("Uygulama ayarları")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // Settings Items
                        VStack(spacing: 16) {
                            // Notification Settings
                            Button(action: { showingNotificationSettings = true }) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.purple.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "bell.fill")
                                            .font(.title3)
                                            .foregroundColor(.purple)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Bildirim Ayarları")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text("Push bildirimleri ve izinler")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(16)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // Clear Cache
                            Button(action: { showingClearCacheAlert = true }) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "arrow.clockwise.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.blue)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Önbelleği Temizle")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.primary)
                                        
                                        Text(cacheCleared ? "Önbellek temizlendi ✓" : "Önbelleğe alınmış resimleri sil")
                                            .font(.caption)
                                            .foregroundColor(cacheCleared ? .green : .secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(16)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            }
                            
                            // App Version
                            HStack(spacing: 15) {
                                ZStack {
                                    Circle()
                                        .fill(Color.green.opacity(0.2))
                                        .frame(width: 50, height: 50)
                                    
                                    Image(systemName: "info.circle.fill")
                                        .font(.title3)
                                        .foregroundColor(.green)
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Uygulama Sürümü")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    Text("v1.0.0")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(16)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                            
                            // Divider
                            Rectangle()
                                .fill(Color.secondary.opacity(0.3))
                                .frame(height: 1)
                                .padding(.vertical, 8)
                            
                            // Delete Account
                            Button(action: { showingDeleteAccountAlert = true }) {
                                HStack(spacing: 15) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.red.opacity(0.2))
                                            .frame(width: 50, height: 50)
                                        
                                        Image(systemName: "trash.circle.fill")
                                            .font(.title3)
                                            .foregroundColor(.red)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Hesabı Sil")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundColor(.red)
                                        
                                        Text("Tüm verileriniz kalıcı olarak silinir")
                                            .font(.caption)
                                            .foregroundColor(.red.opacity(0.7))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.5))
                                }
                                .padding(16)
                                .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Geri")
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
            .alert("Önbelleği Temizle", isPresented: $showingClearCacheAlert) {
                Button("İptal", role: .cancel) {}
                Button("Temizle") {
                    Task {
                        await ImageCacheService.shared.clearCache()
                        await MainActor.run {
                            cacheCleared = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                                cacheCleared = false
                            }
                        }
                    }
                }
            } message: {
                Text("Önbelleğe alınmış tüm resimler silinecek. Verileriniz korunacak.")
            }
            .alert("Hesabı Sil", isPresented: $showingDeleteAccountAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        do {
                            try await authService.deleteAccount()
                            dismiss()
                        } catch {
                            print("Error deleting account: \(error.localizedDescription)")
                            // In a real app, we should show an error alert here
                            // For now, we'll just sign out if deletion fails to ensure safety
                            authService.signOut()
                            dismiss()
                        }
                    }
                }
            } message: {
                Text("⚠️ Hesabınız ve tüm verileriniz kalıcı olarak silinecek. Bu işlem geri alınamaz!")
            }
            .sheet(isPresented: $showingNotificationSettings) {
                NotificationSettingsView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - Notification Settings View
struct NotificationSettingsView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var pushEnabled = PushNotificationManager.shared.notificationsEnabled
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var permissionMessage: String?
    
    @AppStorage("notifyChatAlerts") private var chatAlertsEnabled = true
    @AppStorage("notifyMemoryAlerts") private var memoryAlertsEnabled = true
    @AppStorage("notifyPlanAlerts") private var planAlertsEnabled = true
    @AppStorage("notifySpecialDayAlerts") private var specialDayAlertsEnabled = true
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Push Bildirimleri")) {
                    Toggle(isOn: $pushEnabled) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Push bildirimlerini aç")
                            Text(statusText(for: permissionStatus))
                                .font(.caption)
                                .foregroundColor(statusColor(for: permissionStatus))
                        }
                    }
                    .onChange(of: pushEnabled, perform: handlePushToggle)
                    
                    if let permissionMessage {
                        Text(permissionMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    
                    Button {
                        openSystemSettings()
                    } label: {
                        Label("Bildirim izinlerini iOS Ayarlarında yönet", systemImage: "gearshape.arrow.triangle.2.circlepath")
                    }
                }
                
                Section(header: Text("Bildirim Kategorileri")) {
                    Toggle("Sohbet bildirimleri", isOn: $chatAlertsEnabled)
                    Toggle("Anı güncellemeleri", isOn: $memoryAlertsEnabled)
                    Toggle("Plan hatırlatmaları", isOn: $planAlertsEnabled)
                    Toggle("Özel gün hatırlatmaları", isOn: $specialDayAlertsEnabled)
                }
                .tint(themeManager.currentTheme.primaryColor)
                
                Section(footer: Text("Bu tercihler sadece uygulama içi davranış için saklanır. Push bildirim türlerine göre filtrelemek için arka uçla entegre etmeniz gerekir.")) {
                    EmptyView()
                }
            }
            .navigationTitle("Bildirim Ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .tint(themeManager.currentTheme.primaryColor)
            .task {
                await refreshAuthorizationStatus()
            }
            .onReceive(
                NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification),
                perform: { _ in
                    Task {
                        await refreshAuthorizationStatus()
                    }
                }
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
    
    private func handlePushToggle(_ isEnabled: Bool) {
        if isEnabled {
            switch permissionStatus {
            case .denied:
                permissionMessage = "Bildirim izni kapalı. Ayarlar > Bildirimler bölümünden açabilirsiniz."
                pushEnabled = false
                PushNotificationManager.shared.setNotificationsEnabled(false)
                openSystemSettings()
            case .notDetermined:
                requestAuthorization { granted in
                    DispatchQueue.main.async {
                        if granted {
                            permissionMessage = nil
                            PushNotificationManager.shared.setNotificationsEnabled(true)
                            Task { await refreshAuthorizationStatus() }
                        } else {
                            pushEnabled = false
                            permissionMessage = "Bildirim izni verilmedi."
                            PushNotificationManager.shared.setNotificationsEnabled(false)
                        }
                    }
                }
            default:
                permissionMessage = nil
                PushNotificationManager.shared.setNotificationsEnabled(true)
            }
        } else {
            permissionMessage = nil
            PushNotificationManager.shared.setNotificationsEnabled(false)
        }
    }
    
    private func requestAuthorization(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            completion(granted)
        }
    }
    
    @MainActor
    private func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        permissionStatus = settings.authorizationStatus
    }
    
    private func openSystemSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    private func statusText(for status: UNAuthorizationStatus) -> String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return "Bildirim izni açık"
        case .denied:
            return "Bildirim izni kapalı"
        case .notDetermined:
            return "İzin henüz sorulmadı"
        @unknown default:
            return "Bilinmeyen durum"
        }
    }
    
    private func statusColor(for status: UNAuthorizationStatus) -> Color {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .secondary
        }
    }
}

// MARK: - Sign Out Card
struct SignOutCard: View {
    let onSignOut: () -> Void
    
    var body: some View {
        Button(action: onSignOut) {
            HStack {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.title3)
                Text("Çıkış Yap")
                    .font(.headline)
                Spacer()
            }
            .foregroundColor(.white)
            .padding(25)
            .background(
                LinearGradient(
                    colors: [Color.red.opacity(0.7), Color.red.opacity(0.5)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 20)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: .red.opacity(0.3), radius: 10, x: 0, y: 5)
        }
    }
}

struct ProfilePlaceholder: View {
    var body: some View {
        Image(systemName: "person.circle.fill")
            .font(.system(size: 80))
            .foregroundStyle(.secondary)
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var name: String
    @State private var selectedImage: UIImage?
    @State private var showingImagePicker = false
    @State private var isSaving = false
    
    init() {
        _name = State(initialValue: "")
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack {
                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                            } else if let profileURL = authService.currentUser?.profileImageURL {
                                CachedAsyncImage(url: profileURL, thumbnail: true) { image, _ in
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                } placeholder: {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.2))
                                            .frame(width: 120, height: 120)
                                        ProgressView()
                                    }
                                }
                            } else {
                                Image(systemName: "person.circle.fill")
                                    .font(.system(size: 120))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Button("Fotoğraf Değiştir") {
                                showingImagePicker = true
                            }
                            .padding(.top, 10)
                        }
                        Spacer()
                    }
                }
                
                Section("İsim") {
                    TextField("İsim", text: $name)
                }
            }
            .navigationTitle("Profili Düzenle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveProfile()
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage)
            }
            .onAppear {
                name = authService.currentUser?.name ?? ""
            }
        }
    }
    
    private func saveProfile() {
        guard let userId = authService.currentUser?.id else { return }
        
        isSaving = true
        Task {
            do {
                var profileImageURL: String? = nil
                if let image = selectedImage {
                    profileImageURL = try await StorageService.shared.uploadProfileImage(image, userId: userId)
                }
                
                try await authService.updateUserProfile(
                    name: name != authService.currentUser?.name ? name : nil,
                    profileImageURL: profileImageURL
                )
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving profile: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

struct EditRelationshipView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var relationshipService: RelationshipService
    
    @State private var startDate: Date
    @State private var isSaving = false
    
    init() {
        _startDate = State(initialValue: Date())
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section("İlişki Başlangıç Tarihi") {
                    DatePicker("Tarih", selection: $startDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                }
            }
            .navigationTitle("İlişki Bilgileri")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveRelationship()
                    }
                    .disabled(isSaving)
                }
            }
            .onAppear {
                startDate = relationshipService.currentRelationship?.startDate ?? Date()
            }
        }
    }
    
    private func saveRelationship() {
        isSaving = true
        Task {
            do {
                try await relationshipService.updateRelationship(startDate: startDate, themeColor: nil)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving relationship: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

struct ThemeSelectorView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            List {
                ForEach(AppTheme.allThemes, id: \.name) { theme in
                    Button(action: {
                        themeManager.setTheme(theme)
                        dismiss()
                    }) {
                        HStack {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(theme.primaryColor)
                                    .frame(width: 30, height: 30)
                                Circle()
                                    .fill(theme.secondaryColor)
                                    .frame(width: 30, height: 30)
                                Circle()
                                    .fill(theme.accentColor)
                                    .frame(width: 30, height: 30)
                            }
                            
                            Text(theme.displayName)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if themeManager.currentTheme.name == theme.name {
                                Image(systemName: "checkmark")
                                    .foregroundColor(theme.primaryColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Tema Seç")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Statistics Card
struct StatisticsCard: View {
    let notesCount: Int
    let photosCount: Int
    let plansCount: Int
    let memoriesCount: Int
    let moviesCount: Int
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                Text("İstatistikler")
                    .font(.title3.bold())
                    .foregroundColor(.white)
                Spacer()
            }
            
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                StatItem(icon: "note.text", title: "Notlar", count: notesCount, color: .orange)
                StatItem(icon: "photo.fill", title: "Fotoğraflar", count: photosCount, color: .blue)
                StatItem(icon: "list.star", title: "Planlar", count: plansCount, color: .indigo)
                StatItem(icon: "heart.text.square.fill", title: "Anılar", count: memoriesCount, color: .pink)
                StatItem(icon: "film.fill", title: "Filmler", count: moviesCount, color: .red)
                StatItem(icon: "heart.fill", title: "Birlikte", count: Int(Date().timeIntervalSince1970 / 86400), color: .green)
            }
        }
        .padding(25)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
    }
}

struct StatItem: View {
    let icon: String
    let title: String
    let count: Int
    let color: Color
    
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.title2.bold())
                .foregroundColor(.white)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 15)
        .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 15))
    }
}

// MARK: - Settings Button
struct SettingsButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(20)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15))
            .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
        }
    }
}

// MARK: - About App View
struct AboutAppView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // App Icon
                    VStack(spacing: 15) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.pink, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                        
                        Text("Sevgilim")
                            .font(.title.bold())
                        
                        Text("Versiyon 1.0.0")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 40)
                    
                    // Description
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Hakkında")
                            .font(.title3.bold())
                        
                        Text("Sevgilim, çiftlerin özel anlarını paylaştığı, birlikte plan yaptığı ve hatıralarını bir arada tuttuğu özel bir uygulamadır.")
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // Features
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Özellikler")
                            .font(.title3.bold())
                        
                        FeatureRow(icon: "note.text", title: "Paylaşımlı Notlar", color: .orange)
                        FeatureRow(icon: "photo.fill", title: "Fotoğraf Albümü", color: .blue)
                        FeatureRow(icon: "list.star", title: "Ortak Planlar", color: .indigo)
                        FeatureRow(icon: "heart.text.square.fill", title: "Anılar", color: .pink)
                        FeatureRow(icon: "film.fill", title: "İzlenen Filmler", color: .red)
                        FeatureRow(icon: "paintpalette.fill", title: "Özelleştirilebilir Temalar", color: .purple)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // Contact
                    VStack(spacing: 10) {
                        Text("© 2024 Sevgilim")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("Tüm hakları saklıdır")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 30)
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Hakkında")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
}

// MARK: - Compact Profile View (for bottom sheet)
struct CompactProfileView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var relationshipService: RelationshipService
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var noteService: NoteService
    @EnvironmentObject var photoService: PhotoService
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var memoryService: MemoryService
    @EnvironmentObject var movieService: MovieService
    
    @State private var showingEditProfile = false
    @State private var showingEditRelationship = false
    @State private var showingThemeSelector = false
    @State private var showingSignOutAlert = false
    @State private var showingAboutApp = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Compact Profile Header
                    HStack(spacing: 15) {
                        // Profile Image with Caching
                        if let urlString = authService.currentUser?.profileImageURL {
                            CachedAsyncImage(url: urlString, thumbnail: true) { image, _ in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } placeholder: {
                                CompactProfilePlaceholder()
                            }
                        } else {
                            CompactProfilePlaceholder()
                        }
                        
                        // Name and Email
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentUser?.name ?? "")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text(authService.currentUser?.email ?? "")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Edit button
                        Button(action: { showingEditProfile = true }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title2)
                                .foregroundColor(themeManager.currentTheme.primaryColor)
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // Quick Stats
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        QuickStatItem(icon: "note.text", count: noteService.notes.count, color: .orange)
                        QuickStatItem(icon: "photo.fill", count: photoService.photos.count, color: .blue)
                        QuickStatItem(icon: "list.star", count: planService.plans.count, color: .indigo)
                        QuickStatItem(icon: "heart.text.square.fill", count: memoryService.memories.count, color: .pink)
                        QuickStatItem(icon: "film.fill", count: movieService.movies.count, color: .red)
                        
                        if let relationship = relationshipService.currentRelationship {
                            QuickStatItem(
                                icon: "heart.fill",
                                count: relationship.startDate.daysBetween(Date()),
                                label: "gün",
                                color: .green
                            )
                        }
                    }
                    
                    // Settings List
                    VStack(spacing: 0) {
                        CompactSettingsRow(
                            icon: "heart.circle.fill",
                            title: "İlişki Bilgileri",
                            color: .red,
                            action: { showingEditRelationship = true }
                        )
                        
                        Divider().padding(.leading, 50)
                        
                        CompactSettingsRow(
                            icon: "paintpalette.fill",
                            title: "Tema",
                            color: .purple,
                            action: { showingThemeSelector = true }
                        )
                        
                        Divider().padding(.leading, 50)
                        
                        CompactSettingsRow(
                            icon: "bell.fill",
                            title: "Bildirimler",
                            color: .orange,
                            action: { /* TODO */ }
                        )
                        
                        Divider().padding(.leading, 50)
                        
                        CompactSettingsRow(
                            icon: "lock.fill",
                            title: "Gizlilik",
                            color: .blue,
                            action: { /* TODO */ }
                        )
                        
                        Divider().padding(.leading, 50)
                        
                        CompactSettingsRow(
                            icon: "questionmark.circle.fill",
                            title: "Hakkında",
                            color: .teal,
                            action: { showingAboutApp = true }
                        )
                    }
                    .background(Color(.systemGray6))
                    .cornerRadius(15)
                    
                    // Sign Out Button
                    Button(action: { showingSignOutAlert = true }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Çıkış Yap")
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Profil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditProfile) {
            EditProfileView()
                .environmentObject(authService)
        }
        .sheet(isPresented: $showingEditRelationship) {
            EditRelationshipView()
                .environmentObject(relationshipService)
        }
        .sheet(isPresented: $showingThemeSelector) {
            ThemeSelectorView()
                .environmentObject(themeManager)
        }
        .sheet(isPresented: $showingAboutApp) {
            AboutAppView()
        }
        .alert("Çıkış Yap", isPresented: $showingSignOutAlert) {
            Button("İptal", role: .cancel) {}
            Button("Çıkış Yap", role: .destructive) {
                authService.signOut()
            }
        } message: {
            Text("Çıkış yapmak istediğinizden emin misiniz?")
        }
    }
}

struct CompactProfilePlaceholder: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 60, height: 60)
            
            Image(systemName: "person.fill")
                .font(.title2)
                .foregroundColor(.gray)
        }
    }
}

struct QuickStatItem: View {
    let icon: String
    let count: Int
    var label: String = ""
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            
            Text("\(count)")
                .font(.headline.bold())
                .foregroundColor(.primary)
            
            if !label.isEmpty {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct CompactSettingsRow: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 30)
                
                Text(title)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}
