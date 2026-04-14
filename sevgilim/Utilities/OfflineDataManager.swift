//
//  OfflineDataManager.swift
//  sevgilim
//
//  Local data cache for instant app loading
//  Stores Firestore data as JSON on disk for offline access
//  Data loads from cache first, then syncs from Firestore
//
//  Uses Firestore.Encoder/Decoder to handle @DocumentID properly
//

import Foundation
import FirebaseFirestore

final class OfflineDataManager {
    
    static let shared = OfflineDataManager()
    
    // MARK: - Cache Keys
    enum CacheKey: String, CaseIterable {
        case photos = "cached_photos"
        case memories = "cached_memories"
        case messages = "cached_messages"
        case notes = "cached_notes"
        case movies = "cached_movies"
        case plans = "cached_plans"
        case places = "cached_places"
        case songs = "cached_songs"
        case specialDays = "cached_special_days"
        case surprises = "cached_surprises"
        case stories = "cached_stories"
        case secretVault = "cached_secret_vault"
        case moodStatuses = "cached_mood_statuses"
        case relationship = "cached_relationship"
        case currentUser = "cached_current_user"
    }
    
    // MARK: - Properties
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // Firestore encoder/decoder handles @DocumentID, Timestamp, etc.
    private let firestoreEncoder = Firestore.Encoder()
    private let firestoreDecoder = Firestore.Decoder()
    
    // In-memory cache for frequently accessed data
    private var memoryCache: [String: Data] = [:]
    private let memoryCacheLock = NSLock()
    
    // MARK: - Init
    private init() {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        cacheDirectory = documentsDirectory.appendingPathComponent("OfflineCache", isDirectory: true)
        
        // Create cache directory
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Generic Save/Load (Firestore-compatible)
    
    /// Save an array of Firestore models to disk cache
    /// Uses Firestore.Encoder to handle @DocumentID, Timestamp, etc.
    func saveArray<T: Encodable>(_ items: [T], forKey key: CacheKey) {
        do {
            // Step 1: Encode each item using Firestore.Encoder → [String: Any]
            let dicts: [[String: Any]] = try items.map { item in
                try firestoreEncoder.encode(item)
            }
            
            // Step 2: Sanitize for JSON (convert Timestamp → Double, etc.)
            let sanitized = dicts.map { sanitizeForJSON($0) }
            
            // Step 3: Serialize to JSON Data
            let jsonData = try JSONSerialization.data(withJSONObject: sanitized, options: [])
            
            // Step 4: Write to disk
            let fileURL = cacheFileURL(for: key)
            try jsonData.write(to: fileURL, options: .atomic)
            
            // Update memory cache
            memoryCacheLock.lock()
            memoryCache[key.rawValue] = jsonData
            memoryCacheLock.unlock()
            
            // Save timestamp
            saveTimestamp(for: key)
            
            #if DEBUG
            let sizeKB = Double(jsonData.count) / 1024.0
            print("💾 OfflineCache: \(key.rawValue) kaydedildi (\(String(format: "%.1f", sizeKB)) KB)")
            #endif
        } catch {
            print("❌ OfflineCache: \(key.rawValue) kaydedilemedi - \(error.localizedDescription)")
        }
    }
    
    /// Load an array of Firestore models from cache
    /// Uses Firestore.Decoder to handle @DocumentID, Timestamp, etc.
    func loadArray<T: Decodable>(_ type: T.Type, forKey key: CacheKey) -> [T]? {
        // Check memory cache first
        memoryCacheLock.lock()
        let cachedData = memoryCache[key.rawValue]
        memoryCacheLock.unlock()
        
        let jsonData: Data
        if let cached = cachedData {
            jsonData = cached
        } else {
            // Fall back to disk
            let fileURL = cacheFileURL(for: key)
            guard let diskData = try? Data(contentsOf: fileURL) else { return nil }
            jsonData = diskData
            
            // Update memory cache
            memoryCacheLock.lock()
            memoryCache[key.rawValue] = jsonData
            memoryCacheLock.unlock()
        }
        
        // Deserialize JSON → [[String: Any]]
        guard let jsonArray = try? JSONSerialization.jsonObject(with: jsonData) as? [[String: Any]] else {
            return nil
        }
        
        // Decode each dictionary using Firestore.Decoder
        let desanitized = jsonArray.map { desanitizeFromJSON($0) }
        let items = desanitized.compactMap { dict -> T? in
            try? firestoreDecoder.decode(T.self, from: dict)
        }
        
        return items.isEmpty ? nil : items
    }
    
    /// Check if cache exists for a key
    func hasCachedData(forKey key: CacheKey) -> Bool {
        let fileURL = cacheFileURL(for: key)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Get the age of cached data in seconds
    func cacheAge(forKey key: CacheKey) -> TimeInterval? {
        guard let timestamp = loadTimestamp(for: key) else { return nil }
        return Date().timeIntervalSince(timestamp)
    }
    
    /// Check if cache is stale (older than maxAge seconds)
    func isCacheStale(forKey key: CacheKey, maxAge: TimeInterval = 3600) -> Bool {
        guard let age = cacheAge(forKey: key) else { return true }
        return age > maxAge
    }
    
    // MARK: - Convenience Methods
    
    /// Save photos cache
    func savePhotos(_ photos: [Photo]) {
        saveArray(photos, forKey: .photos)
        
        // Also preload image cache for first photos
        let urls = photos.prefix(20).map { $0.thumbnailURL ?? $0.imageURL }
        Task.detached(priority: .background) {
            await ImageCacheService.shared.preloadImages(Array(urls), thumbnail: true)
        }
    }
    
    /// Load cached photos
    func loadPhotos() -> [Photo]? {
        loadArray(Photo.self, forKey: .photos)
    }
    
    /// Save memories cache
    func saveMemories(_ memories: [Memory]) {
        saveArray(memories, forKey: .memories)
    }
    
    /// Load cached memories
    func loadMemories() -> [Memory]? {
        loadArray(Memory.self, forKey: .memories)
    }
    
    /// Save messages cache
    func saveMessages(_ messages: [Message]) {
        saveArray(messages, forKey: .messages)
    }
    
    /// Load cached messages
    func loadMessages() -> [Message]? {
        loadArray(Message.self, forKey: .messages)
    }
    
    /// Save notes cache
    func saveNotes(_ notes: [Note]) {
        saveArray(notes, forKey: .notes)
    }
    
    /// Load cached notes
    func loadNotes() -> [Note]? {
        loadArray(Note.self, forKey: .notes)
    }
    
    /// Save movies cache
    func saveMovies(_ movies: [Movie]) {
        saveArray(movies, forKey: .movies)
    }
    
    /// Load cached movies
    func loadMovies() -> [Movie]? {
        loadArray(Movie.self, forKey: .movies)
    }
    
    /// Save plans cache
    func savePlans(_ plans: [Plan]) {
        saveArray(plans, forKey: .plans)
    }
    
    /// Load cached plans
    func loadPlans() -> [Plan]? {
        loadArray(Plan.self, forKey: .plans)
    }
    
    /// Save places cache
    func savePlaces(_ places: [Place]) {
        saveArray(places, forKey: .places)
    }
    
    /// Load cached places
    func loadPlaces() -> [Place]? {
        loadArray(Place.self, forKey: .places)
    }
    
    /// Save songs cache
    func saveSongs(_ songs: [Song]) {
        saveArray(songs, forKey: .songs)
    }
    
    /// Load cached songs
    func loadSongs() -> [Song]? {
        loadArray(Song.self, forKey: .songs)
    }
    
    /// Save special days cache
    func saveSpecialDays(_ days: [SpecialDay]) {
        saveArray(days, forKey: .specialDays)
    }
    
    /// Load cached special days
    func loadSpecialDays() -> [SpecialDay]? {
        loadArray(SpecialDay.self, forKey: .specialDays)
    }
    
    /// Save stories cache
    func saveStories(_ stories: [Story]) {
        saveArray(stories, forKey: .stories)
    }
    
    /// Load cached stories
    func loadStories() -> [Story]? {
        loadArray(Story.self, forKey: .stories)
    }
    
    /// Save surprises cache
    func saveSurprises(_ surprises: [Surprise]) {
        saveArray(surprises, forKey: .surprises)
    }
    
    /// Load cached surprises
    func loadSurprises() -> [Surprise]? {
        loadArray(Surprise.self, forKey: .surprises)
    }
    
    /// Save secret vault items cache
    func saveSecretVault(_ items: [SecretVaultItem]) {
        saveArray(items, forKey: .secretVault)
    }
    
    /// Load cached secret vault items
    func loadSecretVault() -> [SecretVaultItem]? {
        loadArray(SecretVaultItem.self, forKey: .secretVault)
    }
    
    /// Save mood statuses cache
    func saveMoodStatuses(_ statuses: [MoodStatus]) {
        saveArray(statuses, forKey: .moodStatuses)
    }
    
    /// Load cached mood statuses
    func loadMoodStatuses() -> [MoodStatus]? {
        loadArray(MoodStatus.self, forKey: .moodStatuses)
    }
    
    // MARK: - Cache Management
    
    /// Clear all offline caches
    func clearAll() {
        memoryCacheLock.lock()
        memoryCache.removeAll()
        memoryCacheLock.unlock()
        
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Clear timestamps
        CacheKey.allCases.forEach { key in
            UserDefaults.standard.removeObject(forKey: "cache_timestamp_\(key.rawValue)")
        }
        
        print("🗑️ OfflineCache: Tüm önbellek temizlendi")
    }
    
    /// Clear specific cache
    func clear(forKey key: CacheKey) {
        memoryCacheLock.lock()
        memoryCache.removeValue(forKey: key.rawValue)
        memoryCacheLock.unlock()
        
        let fileURL = cacheFileURL(for: key)
        try? fileManager.removeItem(at: fileURL)
        UserDefaults.standard.removeObject(forKey: "cache_timestamp_\(key.rawValue)")
    }
    
    /// Get total cache size on disk
    func totalCacheSize() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: cacheDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }
        
        return files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
            return total + Int64(size)
        }
    }
    
    /// Human-readable cache size
    var formattedCacheSize: String {
        let bytes = totalCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Private Helpers
    
    /// Convert Firestore types to JSON-safe types
    /// Timestamp → {"__fsType": "timestamp", "seconds": Double}
    private func sanitizeForJSON(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = sanitizeValue(value)
        }
        return result
    }
    
    private func sanitizeValue(_ value: Any) -> Any {
        if let timestamp = value as? Timestamp {
            return [
                "__fsType": "timestamp",
                "seconds": timestamp.dateValue().timeIntervalSince1970
            ]
        } else if let dict = value as? [String: Any] {
            return sanitizeForJSON(dict)
        } else if let array = value as? [Any] {
            return array.map { sanitizeValue($0) }
        }
        // String, Int, Double, Bool, NSNull are JSON-safe
        return value
    }
    
    /// Convert JSON-safe types back to Firestore types
    /// {"__fsType": "timestamp", "seconds": Double} → Timestamp
    private func desanitizeFromJSON(_ dict: [String: Any]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in dict {
            result[key] = desanitizeValue(value)
        }
        return result
    }
    
    private func desanitizeValue(_ value: Any) -> Any {
        if let dict = value as? [String: Any] {
            // Check if it's a serialized Timestamp
            if let fsType = dict["__fsType"] as? String,
               fsType == "timestamp",
               let seconds = dict["seconds"] as? Double {
                return Timestamp(date: Date(timeIntervalSince1970: seconds))
            }
            return desanitizeFromJSON(dict)
        } else if let array = value as? [Any] {
            return array.map { desanitizeValue($0) }
        }
        return value
    }
    
    private func cacheFileURL(for key: CacheKey) -> URL {
        cacheDirectory.appendingPathComponent("\(key.rawValue).json")
    }
    
    private func saveTimestamp(for key: CacheKey) {
        UserDefaults.standard.set(Date(), forKey: "cache_timestamp_\(key.rawValue)")
    }
    
    private func loadTimestamp(for key: CacheKey) -> Date? {
        UserDefaults.standard.object(forKey: "cache_timestamp_\(key.rawValue)") as? Date
    }
}
