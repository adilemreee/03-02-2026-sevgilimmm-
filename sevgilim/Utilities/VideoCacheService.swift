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
            return destinationURL
        }
        
        let (temporaryURL, response) = try await URLSession.shared.download(from: remoteURL)
        
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw NSError(domain: "VideoCacheService", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Video indirilemedi (kod: \(httpResponse.statusCode))"])
        }
        
        do {
            try fileManager.moveItem(at: temporaryURL, to: destinationURL)
        } catch {
            // Eğer dosya zaten varsa veya taşınamıyorsa, var olanı döndür
            if !fileManager.fileExists(atPath: destinationURL.path) {
                throw error
            }
        }
        
        return destinationURL
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
    
    private func cacheFileURL(for url: URL) -> URL {
        let hash = SHA256.hash(data: Data(url.absoluteString.utf8)).map { String(format: "%02x", $0) }.joined()
        let ext = url.pathExtension.isEmpty ? "mp4" : url.pathExtension
        return cacheDirectory.appendingPathComponent("\(hash).\(ext)")
    }
}
