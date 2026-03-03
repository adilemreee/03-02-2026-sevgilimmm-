//
//  VideoCacheService.swift
//  sevgilim
//

import Foundation
import CryptoKit

final class VideoCacheService {
    static let shared = VideoCacheService()
    
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let queue = DispatchQueue(label: "VideoCacheService.queue", qos: .utility)
    
    /// Maximum total cache size: 200 MB
    private let maxCacheSize: Int = 200 * 1024 * 1024
    
    /// In-flight downloads keyed by remote URL — prevents duplicate concurrent downloads
    private var inFlightDownloads: [String: Task<URL, Error>] = [:]
    private let lock = NSLock()
    
    private init() {
        let baseDirectory = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let directory = baseDirectory.appendingPathComponent("StoryVideoCache", isDirectory: true)
        cacheDirectory = directory
        
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    func cachedURL(for remoteURLString: String) async throws -> URL {
        guard let remoteURL = URL(string: remoteURLString) else {
            throw NSError(domain: "VideoCacheService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Geçersiz video URL'si"])
        }
        
        let destinationURL = cacheFileURL(for: remoteURL)
        if fileManager.fileExists(atPath: destinationURL.path) {
            // Touch the file to update access date (LRU)
            try? fileManager.setAttributes([.modificationDate: Date()], ofItemAtPath: destinationURL.path)
            return destinationURL
        }
        
        // Dedup: check if we're already downloading this URL
        lock.lock()
        if let existing = inFlightDownloads[remoteURLString] {
            lock.unlock()
            return try await existing.value
        }
        
        let task = Task<URL, Error> {
            defer {
                lock.lock()
                inFlightDownloads.removeValue(forKey: remoteURLString)
                lock.unlock()
            }
            
            let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
            
            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                throw NSError(domain: "VideoCacheService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Video indirilemedi (kod: \(httpResponse.statusCode))"])
            }
            
            do {
                try fileManager.moveItem(at: temporaryURL, to: destinationURL)
            } catch {
                if !fileManager.fileExists(atPath: destinationURL.path) {
                    throw error
                }
            }
            
            // Evict old files if cache exceeds 200 MB
            evictIfNeeded()
            
            return destinationURL
        }
        
        inFlightDownloads[remoteURLString] = task
        lock.unlock()
        
        return try await task.value
    }
    
    func clearCache() {
        queue.async { [cacheDirectory, fileManager] in
            guard let files = try? fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil) else {
                return
            }
            for file in files {
                try? fileManager.removeItem(at: file)
            }
        }
    }
    
    /// LRU eviction: remove oldest-accessed files until total size is under maxCacheSize
    private func evictIfNeeded() {
        queue.async { [weak self] in
            guard let self = self else { return }
            let resourceKeys: Set<URLResourceKey> = [.fileSizeKey, .contentModificationDateKey]
            guard let files = try? self.fileManager.contentsOfDirectory(
                at: self.cacheDirectory,
                includingPropertiesForKeys: Array(resourceKeys)
            ) else { return }
            
            var totalSize = 0
            var fileInfos: [(url: URL, size: Int, date: Date)] = []
            
            for file in files {
                guard let values = try? file.resourceValues(forKeys: resourceKeys),
                      let size = values.fileSize,
                      let date = values.contentModificationDate else { continue }
                totalSize += size
                fileInfos.append((url: file, size: size, date: date))
            }
            
            guard totalSize > self.maxCacheSize else { return }
            
            // Sort oldest first
            fileInfos.sort { $0.date < $1.date }
            
            for info in fileInfos {
                guard totalSize > self.maxCacheSize else { break }
                try? self.fileManager.removeItem(at: info.url)
                totalSize -= info.size
            }
        }
    }
    
    private func cacheFileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        return cacheDirectory.appendingPathComponent("\(hash).\(ext)")
    }
}
