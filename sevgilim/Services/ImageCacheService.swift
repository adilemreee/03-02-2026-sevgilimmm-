//
//  ImageCacheService.swift
//  sevgilim
//
//  High-performance image caching service with memory and disk cache
//  Optimized for offline-first experience with aggressive caching

import UIKit
import Foundation

actor ImageCacheService {
    static let shared = ImageCacheService()
    
    private let memoryCache = NSCache<NSString, UIImage>()
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let thumbnailCacheDirectory: URL
    
    // In-flight requests to prevent duplicate downloads
    private var inFlightRequests: [String: Task<UIImage?, Error>] = [:]
    
    // Cache statistics
    private(set) var cacheHits: Int = 0
    private(set) var cacheMisses: Int = 0
    private(set) var diskHits: Int = 0
    
    private init() {
        // Configure memory cache — balanced for offline-first without OOM risk
        memoryCache.countLimit = 100 // Max 100 images in memory
        memoryCache.totalCostLimit = 1024 * 1024 * 80 // 80 MB max memory usage
        
        // Setup disk cache directory
        let cachesDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        cacheDirectory = cachesDirectory.appendingPathComponent("ImageCache")
        thumbnailCacheDirectory = cachesDirectory.appendingPathComponent("ThumbnailCache")
        
        // Create cache directories if needed
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailCacheDirectory, withIntermediateDirectories: true)
        
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
    
    /// Load image with automatic caching (offline-first)
    func loadImage(from urlString: String, thumbnail: Bool = false) async throws -> UIImage? {
        let cacheKey = thumbnail ? "\(urlString)_thumb" : urlString
        
        // 1. Check memory cache first (fastest)
        if let cachedImage = memoryCache.object(forKey: cacheKey as NSString) {
            cacheHits += 1
            return cachedImage
        }
        
        // 2. Check disk cache (fast, works offline)
        if let diskImage = loadFromDisk(key: cacheKey, thumbnail: thumbnail) {
            // Save to memory cache for next access
            let cost = Int(diskImage.size.width * diskImage.size.height * 4)
            memoryCache.setObject(diskImage, forKey: cacheKey as NSString, cost: cost)
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
        let cacheKey = thumbnail ? "\(urlString)_thumb" : urlString
        
        // Check memory
        if memoryCache.object(forKey: cacheKey as NSString) != nil {
            return true
        }
        
        // Check disk
        let fileURL = thumbnail 
            ? thumbnailCacheDirectory.appendingPathComponent(cacheKey.md5)
            : cacheDirectory.appendingPathComponent(cacheKey.md5)
        return fileManager.fileExists(atPath: fileURL.path)
    }
    
    /// Clear all caches
    func clearCache() async {
        memoryCache.removeAllObjects()
        try? fileManager.removeItem(at: cacheDirectory)
        try? fileManager.removeItem(at: thumbnailCacheDirectory)
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: thumbnailCacheDirectory, withIntermediateDirectories: true)
        cacheHits = 0
        cacheMisses = 0
        diskHits = 0
    }
    
    /// Clear old cached items (older than 30 days for offline support)
    func clearOldCache() async {
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
    
    /// Get total disk cache size
    func diskCacheSize() -> Int64 {
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
        let cost = Int(image.size.width * image.size.height * 4)
        memoryCache.setObject(image, forKey: cacheKey as NSString, cost: cost)
        
        // Save to disk cache (in background) - use higher quality for offline
        let isThumbnail = thumbnail
        Task.detached(priority: .background) {
            await self.saveToDisk(image: image, key: cacheKey, thumbnail: isThumbnail)
        }
        
        return image
    }
    
    private func loadFromDisk(key: String, thumbnail: Bool = false) -> UIImage? {
        let directory = thumbnail ? thumbnailCacheDirectory : cacheDirectory
        let fileURL = directory.appendingPathComponent(key.md5)
        
        // Also check the other directory as fallback
        let fallbackDirectory = thumbnail ? cacheDirectory : thumbnailCacheDirectory
        let fallbackURL = fallbackDirectory.appendingPathComponent(key.md5)
        
        if let data = try? Data(contentsOf: fileURL),
           let image = UIImage(data: data) {
            return image
        }
        
        // Fallback check
        if let data = try? Data(contentsOf: fallbackURL),
           let image = UIImage(data: data) {
            return image
        }
        
        return nil
    }
    
    private func saveToDisk(image: UIImage, key: String, thumbnail: Bool = false) {
        let quality: CGFloat = thumbnail ? 0.7 : 0.85
        guard let data = image.jpegData(compressionQuality: quality) else { return }
        let directory = thumbnail ? thumbnailCacheDirectory : cacheDirectory
        let fileURL = directory.appendingPathComponent(key.md5)
        try? data.write(to: fileURL, options: .atomic)
    }
    
    private func handleMemoryWarning() {
        memoryCache.removeAllObjects()
    }
    
    enum CacheError: Error {
        case invalidURL
        case invalidImageData
    }
}

// MARK: - String Extension for MD5 (cache key)
extension String {
    nonisolated var md5: String {
        // Simple hash for file name
        return String(self.hash)
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
    @State private var isLoading = true
    @State private var loadError: Error?
    
    init(
        url: String,
        thumbnail: Bool = false,
        @ViewBuilder content: @escaping (Image, CGSize) -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.url = url
        self.thumbnail = thumbnail
        self.content = content
        self.placeholder = placeholder
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
        .task(id: url) {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        isLoading = true
        loadError = nil
        
        do {
            if let image = try await ImageCacheService.shared.loadImage(from: url, thumbnail: thumbnail) {
                await MainActor.run {
                    loadedImage = image
                    isLoading = false
                }
            } else {
                await MainActor.run {
                    isLoading = false
                }
            }
        } catch {
            await MainActor.run {
                loadError = error
                isLoading = false
            }
        }
    }
}
