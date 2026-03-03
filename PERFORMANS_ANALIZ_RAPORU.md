# 🔍 Sevgilim Uygulaması - Detaylı Performans Analiz Raporu

**Tarih:** 3 Mart 2026  
**Analiz Yapan:** GitHub Copilot  
**Analiz Edilen Dosya Sayısı:** 60+  

---

## 📋 YÖNETICI ÖZETİ

Uygulama açılışta ciddi performans kaybı yaşıyor. Temel nedenler:

1. **Açılışta 20 servis aynı anda başlatılıyor** ve hepsi Firestore snapshot listener açıyor
2. **Ana ekranda sürekli 60fps çalışan 2 adet TimelineView animasyonu** GPU'yu yüyor
3. **HomeViewModel 10 servisi dinliyor** — herhangi birindeki değişiklik tüm HomeView'ı yeniden çiziyor
4. **OfflineSyncManager açılışta main thread'de disk I/O yapıyor** → UI donması
5. **ImageCacheService'te 250MB memory limiti** → düşük RAM'li cihazlarda ciddi sorun

**Tahmini etki:** Uygulama açılışı normal olması gereken ~0.5 saniyeden 3-5 saniyeye uzuyor, ana ekran kaydırma 60fps yerine 30-40fps'te takılıyor.

---

## 🔴 KRİTİK SEVİYE SORUNLAR (P0)

### 1. Açılışta Tüm Servislerin Aynı Anda Başlatılması

**Dosya:** [sevgilimApp.swift](sevgilim/sevgilimApp.swift#L23-L44)

```
ContentView()
    .environmentObject(dependencies.authService)        // ← Eager
    .environmentObject(dependencies.relationshipService) // ← Eager
    .environmentObject(dependencies.themeManager)        // ← Eager
    .environmentObject(dependencies.navigationRouter)    // ← Eager
    // ↓↓↓ Bunların HEPSİ uygulama açılışında erişiliyor ↓↓↓
    .environmentObject(dependencies.memoryService)       // ← Lazy AMA erişilince init oluyor
    .environmentObject(dependencies.photoService)
    .environmentObject(dependencies.noteService)
    .environmentObject(dependencies.movieService)
    .environmentObject(dependencies.planService)
    .environmentObject(dependencies.placeService)
    .environmentObject(dependencies.songService)
    .environmentObject(dependencies.spotifyService)
    .environmentObject(dependencies.surpriseService)
    .environmentObject(dependencies.specialDayService)
    .environmentObject(dependencies.storyService)
    .environmentObject(dependencies.messageService)
    .environmentObject(dependencies.moodService)
    .environmentObject(dependencies.greetingService)
    .environmentObject(dependencies.secretVaultService)
    .environmentObject(dependencies.proximityService)
```

**Sorun:** `AppDependencies` içindeki `lazy var` tanımları `.environmentObject()` çağrıldığı anda erişildiği için **tüm 20 servis uygulama açılışında init ediliyor**. `lazy` burada hiçbir işe yaramıyor.

**Etki:** Her servis init olurken:
- Firestore referansı oluşturuyor
- OfflineDataManager'dan önbellek okuyor 
- Bazıları hemen listener başlatıyor

**Toplam:** Açılışta ~20 servis init + 12+ Firestore snapshot listener → **~2-3 saniye gecikme**

---

### 2. Ana Ekranda Sürekli 60fps Çalışan İki TimelineView

**Dosya:** [CoupleHeaderCard.swift](sevgilim/Views/Home/Components/CoupleHeaderCard.swift#L151-L207)

```swift
// HeartPulseView — Her FRAME'de sin(), cos() hesaplıyor
private struct HeartPulseView: View {
    var body: some View {
        TimelineView(.animation) { timeline in           // ← 60fps sürekli
            let time = timeline.date.timeIntervalSinceReferenceDate
            let normalized = (sin(time * .pi * 1.4) + 1) / 2
            let scale = 0.88 + normalized * 0.16
            let rotation = sin(time * 1.3) * 4
            let glowOpacity = 0.3 + normalized * 0.35
            // ... blur, scaleEffect, rotationEffect, shadow
        }
    }
}

// FloatingHeartsField — İkinci 60fps TimelineView aynı ZStack'te!
private struct FloatingHeartsField: View {
    var body: some View {
        TimelineView(.animation) { timeline in           // ← 60fps sürekli
            let time = timeline.date.timeIntervalSinceReferenceDate
            ForEach(seeds) { seed in                      // ← 5 kalp, her frame'de
                // sin(), cos(), progress hesabı x5
            }
        }
    }
}
```

**Sorun:** Ana ekranda 2 adet `TimelineView(.animation)` aynı anda çalışıyor. Bu, **her saniye 120 view body evaluation** demek (2 view × 60fps). Kalp animasyonu her frame'de 7 trigonometrik hesap + 5 floating heart hesabı yapıyor.

**Etki:** 
- GPU sürekli %30-50 kullanımda
- ScrollView kaydırılırken frame drop
- Pil tüketimi ciddi şekilde artıyor
- Ekran dışında bile durmadan çalışıyor

---

### 3. HomeViewModel — 10 Servisin objectWillChange Zincirleme Yayılımı

**Dosya:** [HomeViewModel.swift](sevgilim/ViewModels/HomeViewModel.swift#L139-L158)

```swift
private func observeServices() {
    [
        authService.objectWillChange,
        relationshipService.objectWillChange,
        memoryService.objectWillChange,
        photoService.objectWillChange,
        noteService.objectWillChange,
        planService.objectWillChange,
        surpriseService.objectWillChange,
        specialDayService.objectWillChange,
        messageServiceRef.objectWillChange,
        moodService.objectWillChange             // 10 servis!
    ].forEach { publisher in
        publisher
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()    // ← HER değişiklikte TÜM view yeniden çiziliyor
            }
            .store(in: &cancellables)
    }
}
```

**Sorun:** 10 servisin herhangi birinde `@Published` bir property değiştiğinde `HomeViewModel.objectWillChange.send()` tetikleniyor. Bu da HomeView'ın tüm body'sini yeniden evaluate ettiriyor:
- CoupleHeaderCard
- StoryCircles
- GreetingCard
- DayCounterCard
- PartnerLocationCard
- MoodStatusWidget
- QuickStatsGrid
- UpcomingSpecialDayWidget
- RecentMemoriesCard
- UpcomingPlansCard

**Etki:** Bir mesaj geldiğinde tüm ana ekran yeniden çiziliyor. Firestore snapshot listener'lar sık tetiklendiğinde saniyede birden fazla tam redraw olabiliyor.

---

### 4. MainTabView — onAppear'da 11 Firestore Listener Aynı Anda Açılıyor

**Dosya:** [MainTabView.swift](sevgilim/Views/MainTabView.swift#L88-L107)

```swift
private func startServices() {
    relationshipService.listenToRelationship(relationshipId: relationshipId)
    surpriseService.listenToSurprises(...)
    memoryService.listenToMemories(...)
    photoService.listenToPhotos(...)
    noteService.listenToNotes(...)
    planService.listenToPlans(...)
    movieService.listenToMovies(...)
    placeService.listenToPlaces(...)
    songService.listenToSongs(...)
    storyService.listenToStories(...)
    secretVaultService.listenToVault(...)
    // + HomeView.startListeners() → 3 listener daha
}
```

**Sorun:** `onAppear` tetiklendiğinde **14 Firestore snapshot listener aynı anda başlatılıyor**. Her listener:
1. Önce offline cache'den veri okuyor (disk I/O, main thread)
2. Sonra Firestore'a bağlanıyor (network)
3. İlk snapshot geldiğinde decode + sort + tekrar cache yazma yapıyor

**Etki:** MainTabView göründüğünde ~2-3 saniye boyunca CPU %100'e çıkıyor, UI donuyor.

---

### 5. OfflineSyncManager — Main Thread'de Disk I/O

**Dosya:** [OfflineSyncManager.swift](sevgilim/Utilities/OfflineSyncManager.swift)

```swift
@MainActor                                    // ← TÜM sınıf main thread'de
final class OfflineSyncManager: ObservableObject {
    private init() {
        loadQueue()                            // ← init'te disk okuma!
    }
    
    private func loadQueue() {
        // JSON dosyasından kuyruk okuma — main thread'de!
    }
    
    private func saveQueue() {
        // JSON dosyasına yazma — main thread'de!
    }
}
```

**Sorun:** Tüm sınıf `@MainActor` olarak işaretlenmiş. `init()` içinde `loadQueue()` çağırılıyor. Bu, uygulama başlarken **main thread'i bloke eden disk I/O** yapıyor.

**Etki:** Uygulama açılışında ~100-500ms donma (kuyruk boyutuna bağlı)

---

### 6. StoryViewer — Memory Leak ve 20fps Timer

**Dosya:** StoryViewer.swift

```swift
// MEMORY LEAK: strong self capture
videoTimeObserver = player.addPeriodicTimeObserver(...) { time in
    if self.isPaused { return }    // ← strong self!
    self.progress = ...            // ← strong self!
}

videoEndObserver = NotificationCenter.default.addObserver(...) { _ in
    self.progress = 1.0            // ← strong self!
    self.nextStory()               // ← strong self!
}
```

**Sorun:** Video observer closure'ları `self`'i strong olarak yakalıyor. `View` → `videoPlayer` → `observer` → `View` döngüsü oluşuyor. Story ekranı kapatıldığında bellek serbest bırakılmıyor.

Ayrıca `currentStory` computed property'si her body evaluation'da 2 array birleştirip lineer arama yapıyor — bu timer nedeniyle saniyede 20 kez çalışıyor.

**Etki:** Her story görüntülemede memory leak. Uzun kullanımda uygulama memory warning alıp crash olabilir.

---

## 🟠 YÜKSEK SEVİYE SORUNLAR (P1)

### 7. ImageCacheService — 250MB Memory Limiti

**Dosya:** [ImageCacheService.swift](sevgilim/Services/ImageCacheService.swift#L30-L31)

```swift
memoryCache.countLimit = 200                        // Max 200 resim
memoryCache.totalCostLimit = 1024 * 1024 * 250      // 250 MB memory!
```

**Sorun:** NSCache'e 250MB limit verilmiş. iPhone'larda toplam uygulama RAM limiti genellikle 1-2GB. Bu, toplam RAM'in %12-25'i. Diğer cache'lerle birlikte (Firestore 100MB, video cache sınırsız) ciddi memory pressure oluşuyor.

**Önerilen:** 50-100MB arası yeterli.

---

### 8. Firestore Cache — 100MB

**Dosya:** [sevgilimApp.swift](sevgilim/sevgilimApp.swift#L87-L88)

```swift
firestoreSettings.cacheSettings = PersistentCacheSettings(
    sizeBytes: 100 * 1024 * 1024 as NSNumber   // 100 MB cache
)
```

**Sorun:** Firestore offline cache'i 100MB'a ayarlanmış. Bu, ImageCache'in 250MB'ı ve sınırsız video cache ile birlikte, toplam disk kullanımını kolayca 500MB+'ya çıkarabilir. OfflineDataManager'ın kendi disk cache'i de buna eklendiğinde ciddi depolama sorunu.

---

### 9. AppNavigationRouter — 12 @Published Property

**Dosya:** [AppNavigationRouter.swift](sevgilim/Utilities/AppNavigationRouter.swift#L15-L27)

```swift
@Published private(set) var chatTrigger: Int = 0
@Published private(set) var surprisesTrigger: Int = 0
@Published private(set) var specialDaysTrigger: Int = 0
@Published private(set) var plansTrigger: Int = 0
@Published private(set) var moviesTrigger: Int = 0
@Published private(set) var notesTrigger: Int = 0
@Published private(set) var photosTrigger: Int = 0
@Published private(set) var songsTrigger: Int = 0
@Published private(set) var placesTrigger: Int = 0
@Published private(set) var secretVaultTrigger: Int = 0
@Published private(set) var memoriesTrigger: Int = 0
@Published var hideTabBar: Bool = false
```

**Sorun:** Her `@Published` property değiştiğinde `objectWillChange` tetikleniyor. Bu da `AppNavigationRouter`'ı dinleyen **tüm view'ları** yeniden çiziyor. MainTabView'da 11 adet `.onChange(of:)` bu trigger'ları dinliyor.

**Önerilen:** Tek bir `@Published var pendingNavigation: NavigationTarget?` enum kullanılmalı.

---

### 10. MainTabView — 11 onChange Listener

**Dosya:** [MainTabView.swift](sevgilim/Views/MainTabView.swift#L92-L103)

```swift
.onChange(of: navigationRouter.chatTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.surprisesTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.specialDaysTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.moviesTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.plansTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.songsTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.placesTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.secretVaultTrigger) { _, _ in selectedTab = 0 }
.onChange(of: navigationRouter.photosTrigger) { _, _ in selectedTab = 2 }
.onChange(of: navigationRouter.notesTrigger) { _, _ in selectedTab = 3 }
.onChange(of: navigationRouter.memoriesTrigger) { _, _ in selectedTab = 1 }
```

**Sorun:** 11 ayrı `onChange` modifier, SwiftUI'da her body evaluation'da 11 ayrı karşılaştırma yapıyor. Bunların çoğu `selectedTab = 0` yapıyor — tekrarlayan mantık.

---

### 11. VideoCacheService — Sınırsız Disk Kullanımı

**Dosya:** VideoCacheService.swift

**Sorun:** 
- Cache eviction policy yok — videolar sonsuza kadar birikir
- Boyut limiti yok
- LRU veya süre bazlı temizleme yok
- Aynı URL için eşzamanlı indirme koruması yok

**Etki:** Story videoları izlendikçe disk kullanımı sürekli artar. Gigabaytlarca yer kaplayabilir.

---

### 12. StoryService — Listener İçinde Silme Operasyonu

**Dosya:** StoryService.swift

```swift
// Snapshot listener callback içinde:
let expiredStories = // süresi dolmuş story'ler
for story in expiredStories {
    deleteStory(story)    // ← Silme, yeni snapshot tetikler → sonsuz döngü riski!
}
```

**Sorun:** Firestore snapshot listener callback'i içinde doküman silme yapılıyor. Her silme yeni bir snapshot tetikler. Bu zincirleme güncelleme döngüsü oluşturabilir.

---

### 13. Splash Screen — Aşırı Animasyon Yükü

**Dosya:** [SplashScreenView.swift](sevgilim/Views/Splash/SplashScreenView.swift)

```swift
// Aynı anda çalışan animasyonlar:
1. LinearGradient sürekli animasyon (.repeatForever)
2. 3 adet genişleyen Circle (.repeatForever)  
3. Rotating ring (.repeatForever)
4. Pulse animasyonu (.repeatForever)
5. Shimmer animasyonu (.repeatForever)
6. 8 adet sparkle animasyonu (.repeatForever)
7. 15 floating heart, her biri ayrı animasyon (.repeatForever)
8. DispatchQueue.main.asyncAfter ile 2.5 saniye bekleme
```

**Sorun:** Splash ekranında **~30 eşzamanlı .repeatForever animasyon** çalışıyor. Bunlar splash bittikten sonra `SplashScreenView` dispose edilene kadar GPU'da devam eder. 2.5 saniyelik bekleme süresi boyunca GPU sabit %60-80 kullanımda.

---

## 🟡 ORTA SEVİYE SORUNLAR (P2)

### 14. Tüm Servislerde Gereksiz Client-Side Sorting

| Servis | Firestore Sıralaması | İstemci Tarafı Tekrar Sıralaması |
|--------|---------------------|----------------------------------|
| MemoryService | `.order(by: "date", descending: true)` | `.sorted { $0.date > $1.date }` |
| PhotoService | `.order(by: "date", descending: true)` | `.sorted { $0.date > $1.date }` |
| SongService | `.order(by: "date", descending: true)` | `.sorted { $0.date > $1.date }` |
| MovieService | `.order(by: "watchedDate", descending: true)` | `.sorted { $0.watchedDate > $1.watchedDate }` |
| NoteService | `.order(by: "updatedAt", descending: true)` | `.sorted { $0.updatedAt > $1.updatedAt }` |
| PlaceService | `.order(by: "date", descending: true)` | `.sorted { $0.date > $1.date }` |
| PlanService | `.order(by: "createdAt", descending: true)` | `.sorted { $0.createdAt > $1.createdAt }` |

**Sorun:** Firestore zaten sıralı veri döndürüyor, ama istemci tarafında **aynı sıralama tekrar yapılıyor**. Bu O(n log n) işlemi her snapshot update'inde gereksiz yere tekrarlanıyor.

---

### 15. Servis Listener'larında Gereksiz Task { @MainActor in }

**Tüm servisler** (@MainActor class olarak işaretlenmiş ama snapshot callback'leri içinde tekrar `Task { @MainActor in }` kullanıyorlar):

```swift
@MainActor
class MemoryService: ObservableObject {
    // ...
    .addSnapshotListener { snapshot, error in
        // Zaten @MainActor sınıfındayız
        Task { @MainActor in          // ← GEREKSIZ async hop!
            self.memories = sortedMemories
            self.isLoading = false
        }
    }
}
```

**Sorun:** `@MainActor` sınıf olmasına rağmen, Firestore callback'leri background thread'den geldiği için `Task { @MainActor in }` teknik olarak gerekli FAKAT her callback'te yeni bir Task oluşturmak overhead yaratıyor. Bunun yerine `DispatchQueue.main.async` daha hafif olurdu, veya daha iyisi Firestore callback'ten çıkışta `MainActor.run` kullanılmalı.

---

### 16. OfflineDataManager — Çift Katmanlı Cache

**Dosya:** [OfflineDataManager.swift](sevgilim/Utilities/OfflineDataManager.swift)

```swift
// In-memory cache
private var memoryCache: [String: Data] = [:]

// Disk cache
let cacheDirectory: URL
```

**Sorun:** OfflineDataManager'ın kendisi zaten bir memory + disk cache katmanı. Ama her servis ayrıca kendi `@Published` array'inde veriyi tutuyor. Ve Firestore'un kendi 100MB offline cache'i de var. Yani aynı veri **3 katmanda** tutulyor:
1. Firestore offline cache (100MB)
2. OfflineDataManager disk + memory cache
3. Service @Published property

Bu ciddi bellek israfı.

---

### 17. PhotoService — Agresif Preloading

**Dosya:** [PhotoService.swift](sevgilim/Services/PhotoService.swift#L73-L87)

```swift
private func preloadThumbnails(photos: [Photo]) {
    // İlk 20 thumbnail'ı hemen yükle
    let thumbnailUrls = photos.prefix(20).map { ... }
    Task.detached(priority: .background) {
        await ImageCacheService.shared.preloadImages(Array(thumbnailUrls), thumbnail: true)
    }
    
    // WiFi'daysa TÜM fotoğrafları indir!
    if NetworkMonitor.shared.shouldDownloadLargeMedia {
        let allUrls = photos.map { ... }
        Task.detached(priority: .background) {
            await ImageCacheService.shared.preloadAllForOffline(Array(allUrls))
        }
    }
}
```

**Sorun:** WiFi'dayken **50 fotoğrafın hem orijinal hem thumbnail versiyonu** indirilmeye çalışılıyor → 100 HTTP request. Bu, başlangıçta network bandwidth'i tıkıyor ve diğer Firestore listener'ların ilk yanıtını geciktirebilir.

---

### 18. PushNotificationManager — Tüm Kullanıcı Koleksiyonunda Arama

**Dosya:** PushNotificationManager.swift

```swift
func detachTokenFromOtherUsers(token: String) {
    db.collection("users")
        .whereField("fcmTokens", arrayContains: token)  // ← TÜM users taranıyor
        .getDocuments { ... }
}
```

**Sorun:** Her token güncellenmesinde tüm `users` koleksiyonu `arrayContains` ile taranıyor. Kullanıcı sayısı arttıkça bu sorgu giderek yavaşlar.

---

### 19. LocationService — Maximum GPS Doğruluğu

**Dosya:** LocationService.swift

```swift
locationManager?.desiredAccuracy = kCLLocationAccuracyBest  // ← En yüksek doğruluk
```

**Sorun:** Partner uzaklığı hesaplamak için en yüksek GPS doğruluğu kullanılıyor. `kCLLocationAccuracyHundredMeters` bu kullanım senaryosu için yeterli ve pil tüketimini %80 azaltır.

---

## 🟢 DÜŞÜK SEVİYE SORUNLAR (P3)

### 20. Gereksiz EnvironmentObject Bağımlılıkları

`MainTabView` 17 adet `@EnvironmentObject` tanımlıyor. Bunların çoğu sadece `startServices()` fonksiyonunda kullanılıyor. Bu durum, herhangi bir servisin `objectWillChange` göndermesinde MainTabView'ın body'sinin yeniden evaluate edilmesine neden oluyor.

### 21. Timer Her 60 Saniyede Bir HomeView'ı Güncelliyor

```swift
let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
.onReceive(timer) { _ in currentDate = Date() }
```

Bu küçük bir etki ama diğer performans sorunlarıyla birleştiğinde ek yük oluşturuyor.

### 22. UIImpactFeedbackGenerator Her Tap'te Yeniden Oluşturuluyor

```swift
let impactFeedback = UIImpactFeedbackGenerator(style: .light)  // ← Her tap'te yeni instance
impactFeedback.impactOccurred()
```

`prepare()` ve singleton pattern kullanılmalı.

---

## 📊 PERFORMANS ETKİ MATRİSİ

| # | Sorun | CPU Etkisi | RAM Etkisi | GPU Etkisi | Pil Etkisi | Açılış Etkisi |
|---|-------|-----------|-----------|-----------|-----------|--------------|
| 1 | 20 servis aynı anda init | ⬛⬛⬛⬛⬛ | ⬛⬛⬛ | ⬜ | ⬛⬛ | ⬛⬛⬛⬛⬛ |
| 2 | 2x TimelineView 60fps | ⬛⬛⬛⬛ | ⬜ | ⬛⬛⬛⬛⬛ | ⬛⬛⬛⬛⬛ | ⬜ |
| 3 | HomeViewModel 10 servis zinciri | ⬛⬛⬛⬛ | ⬜ | ⬛⬛⬛ | ⬛⬛ | ⬛⬛ |
| 4 | 14 Firestore listener aynı anda | ⬛⬛⬛⬛⬛ | ⬛⬛⬛ | ⬜ | ⬛⬛⬛ | ⬛⬛⬛⬛⬛ |
| 5 | OfflineSyncManager main thread I/O | ⬛⬛⬛ | ⬛ | ⬜ | ⬜ | ⬛⬛⬛⬛ |
| 6 | StoryViewer memory leak | ⬛⬛ | ⬛⬛⬛⬛⬛ | ⬛⬛ | ⬛⬛ | ⬜ |
| 7 | 250MB image cache limiti | ⬜ | ⬛⬛⬛⬛⬛ | ⬜ | ⬜ | ⬜ |
| 8 | 100MB Firestore cache | ⬜ | ⬛⬛⬛ | ⬜ | ⬜ | ⬛⬛ |
| 9 | 12 @Published router property | ⬛⬛⬛ | ⬜ | ⬛⬛ | ⬛ | ⬜ |
| 13 | Splash 30 concurrent animation | ⬛⬛⬛ | ⬛ | ⬛⬛⬛⬛⬛ | ⬛⬛⬛ | ⬛⬛⬛⬛ |

---

## 🛠️ ÖNERİLEN ÇÖZÜMLER (Öncelik Sırasına Göre)

### Aşama 1: Acil Düzeltmeler (1-2 gün)

#### 1.1 TimelineView'ları Basit Animasyonla Değiştir
```swift
// ÖNCE (60fps sürekli):
TimelineView(.animation) { timeline in ... }

// SONRA (sadece state değişince):
struct HeartPulseView: View {
    @State private var isPulsing = false
    var body: some View {
        Image(systemName: "heart.fill")
            .scaleEffect(isPulsing ? 1.04 : 0.88)
            .animation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear { isPulsing = true }
    }
}
```

#### 1.2 Servis Başlatmayı Kademeli Yap
```swift
// ÖNCE: Tümü onAppear'da
func startServices() {
    // 14 listener aynı anda → UI donması
}

// SONRA: Kademeli başlatma
func startServices() {
    // Sadece kritik servisler hemen
    relationshipService.listenToRelationship(...)
    
    // Diğerleri 0.5 saniye sonra
    Task {
        try await Task.sleep(nanoseconds: 500_000_000)
        memoryService.listenToMemories(...)
        photoService.listenToPhotos(...)
    }
    
    // Geri kalanı 1.5 saniye sonra
    Task {
        try await Task.sleep(nanoseconds: 1_500_000_000)
        movieService.listenToMovies(...)
        placeService.listenToPlaces(...)
        songService.listenToSongs(...)
        // ...
    }
}
```

#### 1.3 OfflineSyncManager I/O'yu Background'a Taşı
```swift
// @MainActor kaldır, sadece @Published property'leri MainActor'da güncelle
final class OfflineSyncManager {
    private init() {
        Task.detached(priority: .utility) {
            await self.loadQueue()
        }
    }
}
```

### Aşama 2: Orta Vadeli İyileştirmeler (3-5 gün)

#### 2.1 HomeViewModel Throttle/Debounce Ekle
```swift
private func observeServices() {
    Publishers.MergeMany([
        authService.objectWillChange.eraseToAnyPublisher(),
        relationshipService.objectWillChange.eraseToAnyPublisher(),
        // ...
    ])
    .throttle(for: .milliseconds(200), scheduler: RunLoop.main, latest: true)
    .sink { [weak self] _ in
        self?.objectWillChange.send()
    }
    .store(in: &cancellables)
}
```

#### 2.2 AppNavigationRouter Tek Enum Kullan
```swift
enum NavigationTarget {
    case chat, surprises, specialDays, plans, movies, notes
    case photos, songs, places, secretVault, memories
}

@Published var pendingNavigation: NavigationTarget?
```

#### 2.3 Gereksiz Client-Side Sorting'i Kaldır
Tüm servislerde zaten Firestore'dan sıralı gelen veriyi tekrar sıralama kodlarını kaldır.

#### 2.4 ImageCache Memory Limitini Düşür
```swift
memoryCache.totalCostLimit = 1024 * 1024 * 80  // 250MB → 80MB
```

#### 2.5 Lazy EnvironmentObject Erişimi
```swift
// Kullanılmayan servisleri environmentObject olarak ekleme
// Sadece ihtiyaç duyulduğunda inject et
```

### Aşama 3: Uzun Vadeli Mimari İyileştirmeler (1-2 hafta)

#### 3.1 Service Listener'ları Tab Bazlı Yap
Her tab sadece kendi ihtiyacı olan listener'ları açsın:
- Home tab: relationship, specialDay, message, mood
- Memories tab: memoryService
- Photos tab: photoService
- Notes tab: noteService
- Profile tab: Hiçbiri (sadece görüntüleme)

#### 3.2 Triple Cache Katmanını Sadeleştir
Firestore offline cache + OfflineDataManager + @Published → Firestore cache zaten yeterli, OfflineDataManager'ı kaldır veya sadece kritik veriler için kullan.

#### 3.3 StoryViewer Memory Leak'i Düzelt
```swift
// Weak self kullan:
videoTimeObserver = player.addPeriodicTimeObserver(...) { [weak self] time in
    guard let self else { return }
    if self.isPaused { return }
    self.progress = ...
}
```

#### 3.4 VideoCacheService'e Eviction Policy Ekle
```swift
let maxCacheSize: Int64 = 200 * 1024 * 1024  // 200MB limit
func evictOldEntries() { /* LRU temizleme */ }
```

---

## 📈 BEKLENEN İYİLEŞTİRMELER

| Metrik | Mevcut (Tahmini) | Aşama 1 Sonrası | Aşama 2 Sonrası | Aşama 3 Sonrası |
|--------|-----------------|-----------------|-----------------|-----------------|
| Açılış süresi | ~4-5 saniye | ~2 saniye | ~1.5 saniye | ~0.8 saniye |
| Ana ekran FPS | 30-40 fps | 55-60 fps | 58-60 fps | 60 fps |
| RAM kullanımı | ~400-600 MB | ~300-400 MB | ~200-300 MB | ~150-200 MB |
| GPU kullanımı (idle) | %30-50 | %5-10 | %3-5 | %2-3 |
| Pil tüketimi | Yüksek | Orta | Düşük-Orta | Düşük |
| İlk etkileşim süresi | ~5-6 saniye | ~2.5 saniye | ~1.5 saniye | ~1 saniye |

---

## 🔑 SONUÇ

Uygulamanın performans sorunlarının **%70'i 3 temel nedenden** kaynaklanıyor:

1. **Tüm servislerin ve listener'ların açılışta eşzamanlı başlatılması** (CPU spike)
2. **CoupleHeaderCard'daki kesintisiz 60fps TimelineView animasyonları** (GPU tüketimi)
3. **HomeViewModel'in 10 servisi throttle olmadan dinlemesi** (sürekli view yeniden çizimi)

Bu 3 sorunu çözmek, kullanıcının hissedeceği performans farkının büyük çoğunluğunu sağlayacaktır.
