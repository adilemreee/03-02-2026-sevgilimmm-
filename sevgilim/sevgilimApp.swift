//
//  sevgilimApp.swift
//  sevgilim
//

import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseMessaging
import UserNotifications

@main
struct sevgilimApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    @StateObject private var authService = AuthenticationService()
    @StateObject private var relationshipService = RelationshipService()
    @StateObject private var memoryService = MemoryService()
    @StateObject private var photoService = PhotoService()
    @StateObject private var noteService = NoteService()
    @StateObject private var movieService = MovieService()
    @StateObject private var planService = PlanService()
    @StateObject private var placeService = PlaceService()
    @StateObject private var songService = SongService()
    @StateObject private var spotifyService = SpotifyService()
    @StateObject private var surpriseService = SurpriseService()
    @StateObject private var specialDayService = SpecialDayService()
    @StateObject private var storyService = StoryService()
    @StateObject private var messageService = MessageService()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var greetingService = GreetingService()
    @StateObject private var secretVaultService = SecretVaultService()
    @StateObject private var moodService = MoodService()
    
 
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(relationshipService)
                .environmentObject(memoryService)
                .environmentObject(photoService)
                .environmentObject(noteService)
                .environmentObject(movieService)
                .environmentObject(planService)
                .environmentObject(placeService)
                .environmentObject(songService)
                .environmentObject(spotifyService)
                .environmentObject(surpriseService)
                .environmentObject(specialDayService)
                .environmentObject(storyService)
                .environmentObject(messageService)
                .environmentObject(moodService)
                .environmentObject(themeManager)
                .environmentObject(greetingService)
                .environmentObject(secretVaultService)
                
                
        }
    }
}

// MARK: - App Delegate
class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    /// Rozet sayısını saklamak için kullanılacak UserDefaults anahtarı
    private let badgeKey = "badgeCount"
    
    /// Saklanan rozet değerini get/set eden özellik
    private var badgeCount: Int {
        get { UserDefaults.standard.integer(forKey: badgeKey) }
        set { UserDefaults.standard.set(newValue, forKey: badgeKey) }
    }
    
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        // Firebase'i yapılandır
        FirebaseApp.configure()
        
        // Bildirim delegelerini ayarla
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self
        
        // Kullanıcıdan bildirim izni iste
        requestNotificationPermissions()
        
        // Uygulamanın önceden kalan rozeti varsa sıfırla
        resetBadge()
        
        // Firebase’e ait token senkronizasyonu yapılacaksa
        PushNotificationManager.shared.refreshIfNeeded()
        
        return true
    }
    
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        print("❌ APNs kayıt hatası: \(error.localizedDescription)")
    }
    
    /// Uygulama aktif olduğunda rozet sıfırlanır ve token senkronizasyonu yapılır.
    func applicationDidBecomeActive(_ application: UIApplication) {
        resetBadge()
        PushNotificationManager.shared.syncTokenWithCurrentUser()
    }
    
    /// Arka plandan dönüldüğünde rozetler ve bildirimler temizlenir.
    func applicationWillEnterForeground(_ application: UIApplication) {
        resetBadge()
    }
    
    /// FCM token güncellendiğinde sunucuya iletilir.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        PushNotificationManager.shared.updateFCMToken(token)
    }
    
    /// Uygulama ön plandayken gelen bildirim için çağrılır.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Bildirimin userInfo’sundan rozet güncellenir
        updateBadge(using: notification.request.content.userInfo)
        
        // Banner, liste ve ses gösterilir. Badge güncellenmesi manuel yapıldığı için .badge eklenmez
        completionHandler([.banner, .list, .sound])
    }
    
    /// Kullanıcı bildirim etkileşimine yanıt verdiğinde çağrılır.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Bildirim açıldığında rozet güncellenir
        updateBadge(using: response.notification.request.content.userInfo)
        
        // Bildirimin içeriğini uygulamanın diğer bölümlerine aktar
        NotificationCenter.default.post(
            name: .didReceiveRemoteNotification,
            object: nil,
            userInfo: response.notification.request.content.userInfo
        )
        
        completionHandler()
    }
    
    /// Bildirim izinlerini ister.
    private func requestNotificationPermissions() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error = error {
                print("❌ Bildirim izni hatası: \(error.localizedDescription)")
                return
            }
            
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                print("ℹ️ Kullanıcı bildirim izni vermedi.")
            }
        }
    }
    
    /// Rozet değerini güncelleyen metod. userInfo içinde aps.badge varsa onu kullanır; yoksa +1 artırır.
    private func updateBadge(using userInfo: [AnyHashable: Any]) {
        let updateBlock = {
            // Eğer bildirim payload’ı içinde “aps.badge” varsa onu kullan
            if let aps = userInfo["aps"] as? [String: Any],
               let badgeValue = aps["badge"] as? Int {
                self.badgeCount = badgeValue
            } else {
                // Değer gönderilmediyse +1 artır
                self.badgeCount = max(self.badgeCount + 1, 1)
            }
            
            // iOS 17 ve üzeri için setBadgeCount kullanılır; alt sürümlerde eski API
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(self.badgeCount) { error in
                    if let error = error {
                        print("Rozet güncelleme hatası: \(error.localizedDescription)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = self.badgeCount
            }
        }
        
        // Ana thread’de çalıştır; arka plandaysa ana thread’e gönder
        if Thread.isMainThread {
            updateBlock()
        } else {
            DispatchQueue.main.async {
                updateBlock()
            }
        }
    }
    
    /// Rozet ve bildirimleri sıfırlar.
    private func resetBadge() {
        let clearBlock = {
            // Yerel saklanan badge sayısını sıfırla
            self.badgeCount = 0
            
            // iOS 17 ve üzeri için setBadgeCount ile sıfırla
            if #available(iOS 17.0, *) {
                UNUserNotificationCenter.current().setBadgeCount(0) { error in
                    if let error = error {
                        print("Rozet sıfırlama hatası: \(error.localizedDescription)")
                    }
                }
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
            
            // Bildirim Merkezi’ndeki bildirimleri temizle
            UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        }
        
        if Thread.isMainThread {
            clearBlock()
        } else {
            DispatchQueue.main.async {
                clearBlock()
            }
        }
    }
}

// Bildirim geldiğinde kullanılacak notification name
extension Notification.Name {
    static let didReceiveRemoteNotification = Notification.Name("didReceiveRemoteNotification")
}
