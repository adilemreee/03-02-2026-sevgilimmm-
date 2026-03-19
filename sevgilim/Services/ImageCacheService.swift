//
//  ImageCacheService.swift
//  sevgilim
//
//  High-performance image caching service with memory and disk cache
//  Optimized for offline-first experience with aggressive caching

import UIKit
import Foundation
import CryptoKit

private enum SharedImageCacheStorage {
    static let fileManager = FileManager.default
    
    static let memoryCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 1024 * 1024 * 80 // 80 MB max memory usage
        return cache
    }()
    
    static let cacheDirectory: URL = {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = cachesDirectory.appendingPathComponent("ImageCache")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    
    static let thumbnailCacheDirectory: URL = {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = cachesDirectory.appendingPathComponent("ThumbnailCache")
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }()
    
    static func cacheKey(for urlString: String, thumbnail: Bool) -> String {
        thumbnail ? "\(urlString)_thumb" : urlString
    }
    
    static func imageFromMemory(forKey key: String) -> UIImage? {
        memoryCache.object(forKey: key as NSString)
    }
    
    static func storeInMemory(_ image: UIImage, forKey key: String) {
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: key as NSString, cost: cost)
    }
    
    static func loadFromDisk(key: String, thumbnail: Bool = false) -> UIImage? {
        let directory = thumbnail ? thumbnailCacheDirectory : cacheDirectory
        let fileURL = directory.appendingPathComponent(key.md5)
        
        let fallbackDirectory = thumbnail ? cacheDirectory : thumbnailCacheDirectory
        let fallbackURL = fallbackDirectory.appendingPathComponent(key.md5)
        
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }
        
        if let data = try? Data(contentsOf: fallbackURL),
           let image = UIImage(data: data) {
            return image
        }
        
        return nil
    }
    
    static func cachedImageIfAvailable(forKey key: String, thumbnail: Bool = false) -> UIImage? {
        if let image = imageFromMemory(forKey: key) {
            return image
        }
        
        if let image = loadFromDisk(key: key, thumbnail: thumbnail) {
            storeInMemory(image, forKey: key)
            return image
        }
        
        return nil
    }
    
    static func saveToDisk(image: UIImage, key: String, thumbnail: Bool = false) {
        let quality: CGFloat = thumbnail ? 0.7 : 0.85
        guard let data = image.jpegData(compressionQuality: quality) else { return }
        let directory = thumbnail ? thumbnailCacheDirectory : cacheDirectory
        let fileURL = directory.appendingPathComponent(key.md5)
        try? data.write(to: fileURL, options: .atomic)
    }
    
    static func clearMemory() {
        memoryCache.removeAllObjects()
    }
    
    static func clearAll() {
        clearMemory()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.removeItem(at: thumbnailCacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailCacheDirectory, withIntermediateDirectories: true)
    }
    
    static func clearOldCache() {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        for directory in [cacheDirectory, thumbnailCacheDirectory] {
            guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey]) else {
                continue
            }
            
            for file in files {
                if let attributes = try? fileManager.attributesOfItem(atPath: file.path),
                   let modificationDate = attributes[.modificationDate] as? Date,
                   modificationDate < thirtyDaysAgo {
                    _ = try? fileManager.removeItem(at: file)
                }
            }
        }
    }
    
    static func diskCacheSize() -> Int64 {
        var totalSize: Int64 = 0
        
        for directory in [cacheDirectory, thumbnailCacheDirectory] {
            guard let files = try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.fileSizeKey]) else {
                continue
            }
            
            for file in files {
                let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                totalSize += Int64(size)
            }
        }
        
        return totalSize
    }
}

actor ImageCacheService {
    static let shared = ImageCacheService()
    
    // In-flight requests to prevent duplicate downloads
    private var inFlightRequests: [String: Task<UIImage?, Error>] = [:]
    
    // Cache statistics
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    private(set) var diskHits: Int = 0
    
    private init() {
        // Setup memory warning observer
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { await self?.handleMemoryWarning() }
        }
    }
    
    // MARK: - Public API
    
    nonisolated static func cacheKey(for urlString: String, thumbnail: Bool = false) -> String {
        SharedImageCacheStorage.cacheKey(for: urlString, thumbnail: thumbnail)
    }
    
    nonisolated static func warmImageIfAvailable(from urlString: String, thumbnail: Bool = false) -> UIImage? {
        let cacheKey = cacheKey(for: urlString, thumbnail: thumbnail)
        return SharedImageCacheStorage.imageFromMemory(forKey: cacheKey)
    }
    
    /// Load image with automatic caching (offline-first)
    func loadImage(from urlString: String, thumbnail: Bool = false) async throws -> UIImage? {
        let cacheKey = Self.cacheKey(for: urlString, thumbnail: thumbnail)
        
        // 1. Check memory cache first (fastest)
        if let cachedImage = SharedImageCacheStorage.imageFromMemory(forKey: cacheKey) {
            cacheHits += 1
            return cachedImage
        }
        
        // 2. Check disk cache (fast, works offline)
        if let diskImage = SharedImageCacheStorage.loadFromDisk(key: cacheKey, thumbnail: thumbnail) {
            // Save to memory cache for next access
            SharedImageCacheStorage.storeInMemory(diskImage, forKey: cacheKey)
            diskHits += 1
            return diskImage
        }
        
        // 3. Check if already downloading (dedup)
        if let existingTask = inFlightRequests[cacheKey] {
            return try await existingTask.value
        }
        
        cacheMisses += 1
        
        // 4. Download image from network
        let task = Task<UIImage?, Error> {
            try await downloadAndCache(urlString: urlString, cacheKey: cacheKey, thumbnail: thumbnail)
        }
        
        inFlightRequests[cacheKey] = task
        
        defer {
            inFlightRequests.removeValue(forKey: cacheKey)
        }
        
        return try await task.value
    }
    
    /// Preload images in background with concurrent downloading
    func preloadImages(_ urlStrings: [String], thumbnail: Bool = false) {
        Task {
            // Download in batches of 5 for better performance
            let batchSize = 5
            for batchStart in stride(from: 0, to: urlStrings.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, urlStrings.count)
                let batch = Array(urlStrings[batchStart..<batchEnd])
                
                await withTaskGroup(of: Void.self) { group in
                    for urlString in batch {
                        group.addTask {
                            _ = try? await self.loadImage(from: urlString, thumbnail: thumbnail)
                        }
                    }
                }
            }
        }
    }
    
    /// Aggressively preload ALL images for a list of URLs (for offline use)
    func preloadAllForOffline(_ urlStrings: [String]) {
        Task {
            let batchSize = 3
            for batchStart in stride(from: 0, to: urlStrings.count, by: batchSize) {
                let batchEnd = min(batchStart + batchSize, urlStrings.count)
                let batch = Array(urlStrings[batchStart..<batchEnd])
                
                await withTaskGroup(of: Void.self) { group in
                    for urlString in batch {
                        // Download both full and thumbnail versions
                        group.addTask {
                            _ = try? await self.loadImage(from: urlString, thumbnail: false)
                        }
                        group.addTask {
                            _ = try? await self.loadImage(from: urlString, thumbnail: true)
                        }
                    }
                }
            }
            print("📦 ImageCache: \(urlStrings.count) görsel offline için önbelleğe alındı")
        }
    }
    
    /// Check if an image exists in cache (memory or disk)
    func isImageCached(urlString: String, thumbnail: Bool = false) -> Bool {
        let cacheKey = Self.cacheKey(for: urlString, thumbnail: thumbnail)
        return SharedImageCacheStorage.cachedImageIfAvailable(forKey: cacheKey, thumbnail: thumbnail) != nil
    }
    
    /// Clear all caches
    func clearCache() async {
        SharedImageCacheStorage.clearAll()
        cacheHits = 0
        cacheMisses = 0
        diskHits = 0
    }
    
    /// Clear old cached items (older than 30 days for offline support)
    func clearOldCache() async {
        SharedImageCacheStorage.clearOldCache()
    }
    
    /// Get total disk cache size
    func diskCacheSize() -> Int64 {
        SharedImageCacheStorage.diskCacheSize()
    }
    
    /// Human-readable cache size
    var formattedDiskCacheSize: String {
        let bytes = diskCacheSize()
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Private Methods
    
    private func downloadAndCache(urlString: String, cacheKey: String, thumbnail: Bool) async throws -> UIImage? {
        guard let url = URL(string: urlString) else {
            throw CacheError.invalidURL
        }
        
        // Use URLSession with caching policy
        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        
        let (data, _) = try await URLSession.shared.data(for: request)
        
        guard var image = UIImage(data: data) else {
            throw CacheError.invalidImageData
        }
        
        // Create thumbnail if requested
        if thumbnail {
            image = image.preparingThumbnail(of: CGSize(width: 400, height: 400)) ?? image
        }
        
        // Save to memory cache with cost tracking
        SharedImageCacheStorage.storeInMemory(image, forKey: cacheKey)
        
        // Save to disk cache (in background) - use higher quality for offline
        let isThumbnail = thumbnail
        Task.detached(priority: .background) {
            SharedImageCacheStorage.saveToDisk(image: image, key: cacheKey, thumbnail: isThumbnail)
        }
        
        return image
    }
    
    private func handleMemoryWarning() {
        SharedImageCacheStorage.clearMemory()
    }
    
    enum CacheError: Error {
        case invalidURL
        case invalidImageData
    }
}

// MARK: - String Extension for MD5 (cache key)
extension String {
    nonisolated var md5: String {
        let digest = Insecure.MD5.hash(data: Data(utf8))
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

// MARK: - SwiftUI Helper View
import SwiftUI

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: String
    let thumbnail: Bool
    @ViewBuilder let content: (Image, CGSize) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    
    @State private var loadedImage: UIImage?
    @State private var loadedCacheKey: String?
    @State private var isLoading = true
    @State private var loadError: Error?
    
    init(
        url: String,
        thumbnail: Bool = false,
        @ViewBuilder content: @escaping (Image, CGSize) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        let cacheKey = ImageCacheService.cacheKey(for: url, thumbnail: thumbnail)
        let warmImage = ImageCacheService.warmImageIfAvailable(from: url, thumbnail: thumbnail)
        
        self.url = url
        self.thumbnail = thumbnail
        self.content = content
        self.placeholder = placeholder
        _loadedImage = State(initialValue: warmImage)
        _loadedCacheKey = State(initialValue: warmImage == nil ? nil : cacheKey)
        _isLoading = State(initialValue: warmImage == nil)
    }
    
    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image), image.size)
            } else if isLoading {
                placeholder()
            } else {
                placeholder() // Show placeholder on error too
            }
        }
        .task(id: cacheKey) {
            await loadImage()
        }
    }
    
    private var cacheKey: String {
        ImageCacheService.cacheKey(for: url, thumbnail: thumbnail)
    }
    
    private func loadImage() async {
        if loadedCacheKey == cacheKey, loadedImage != nil {
            await MainActor.run {
                isLoading = false
            }
            return
        }
        
        if let warmImage = ImageCacheService.warmImageIfAvailable(from: url, thumbnail: thumbnail) {
            await MainActor.run {
                loadedImage = warmImage
                loadedCacheKey = cacheKey
                isLoading = false
                loadError = nil
            }
            return
        }
        
        await MainActor.run {
            if loadedCacheKey != cacheKey {
                loadedImage = nil
                loadedCacheKey = nil
            }
            isLoading = true
            loadError = nil
        }
        
        do {
            if let image = try await ImageCacheService.shared.loadImage(from: url, thumbnail: thumbnail) {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    loadedImage = image
                    loadedCacheKey = cacheKey
                    isLoading = false
                }
            } else {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    if loadedCacheKey != cacheKey {
                        loadedImage = nil
                    }
                    isLoading = false
                }
            }
        } catch {
            guard !Task.isCancelled else { return }
            await MainActor.run {
                loadError = error
                if loadedCacheKey != cacheKey {
                    loadedImage = nil
                }
                isLoading = false
            }
        }
    }
}
