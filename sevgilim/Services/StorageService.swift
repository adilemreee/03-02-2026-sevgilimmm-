//
//  StorageService.swift
//  sevgilim
//

import Foundation
import FirebaseStorage
import UIKit
import AVFoundation

class StorageService {
    static let shared = StorageService()
    private let storage = Storage.storage()
    
    private init() {}
    
    struct MediaUploadResult {
        let downloadURL: String
        let thumbnailURL: String?
        let storagePath: String
        let thumbnailPath: String?
        let sizeInBytes: Int64?
        let duration: Double?
        let contentType: String
    }
    
    // MARK: - Optimized Image Upload with Compression
    
    /// Upload image with automatic optimization
    func uploadImage(_ image: UIImage, path: String, quality: CGFloat = 0.75) async throws -> String {
        // Optimize image before upload
        let optimizedImage = optimizeImage(image, maxDimension: 2048)
        
        guard let imageData = optimizedImage.jpegData(compressionQuality: quality) else {
            throw StorageError.invalidImage
        }
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000" // 1 year cache
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    /// Upload image with thumbnail for faster grid loading
    func uploadImageWithThumbnail(_ image: UIImage, path: String) async throws -> (fullURL: String, thumbURL: String) {
        // Generate thumbnail
        let thumbnail = generateThumbnail(from: image, maxSize: 400)
        
        // Upload both in parallel
        async let fullUpload = uploadImage(image, path: path, quality: 0.75)
        async let thumbUpload = uploadImage(thumbnail, path: path.replacingOccurrences(of: ".jpg", with: "_thumb.jpg"), quality: 0.6)
        
        let (fullURL, thumbURL) = try await (fullUpload, thumbUpload)
        return (fullURL, thumbURL)
    }
    
    func uploadProfileImage(_ image: UIImage, userId: String) async throws -> String {
        let path = "profiles/\(userId)/profile.jpg"
        return try await uploadImage(image, path: path, quality: 0.7)
    }
    
    func uploadPhoto(_ image: UIImage, relationshipId: String) async throws -> String {
        let photoId = UUID().uuidString
        let path = "relationships/\(relationshipId)/photos/\(photoId).jpg"
        return try await uploadImage(image, path: path)
    }
    
    func uploadMemoryPhoto(_ image: UIImage, relationshipId: String) async throws -> String {
        let photoId = UUID().uuidString
        let path = "relationships/\(relationshipId)/memories/\(photoId).jpg"
        return try await uploadImage(image, path: path)
    }
    
    func uploadSecretPhoto(_ image: UIImage, relationshipId: String) async throws -> MediaUploadResult {
        let sizeLimit = 50 * 1024 * 1024
        let optimizedImage = optimizeImage(image, maxDimension: 2048)
        
        guard let imageData = optimizedImage.jpegData(compressionQuality: 0.78) else {
            throw StorageError.invalidImage
        }
        
        guard imageData.count <= sizeLimit else {
            throw StorageError.fileTooLarge(maxMB: 50)
        }
        
        let mediaId = UUID().uuidString
        let storagePath = "relationships/\(relationshipId)/secretVault/\(mediaId).jpg"
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        metadata.cacheControl = "public, max-age=31536000"
        
        let storageRef = storage.reference().child(storagePath)
        let uploadMetadata = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        let generatedThumbnail = generateThumbnail(from: optimizedImage, maxSize: 500)
        guard let thumbData = generatedThumbnail.jpegData(compressionQuality: 0.65) else {
            throw StorageError.invalidImage
        }
        
        let thumbnailPath = "relationships/\(relationshipId)/secretVault/\(mediaId)_thumb.jpg"
        let thumbnailRef = storage.reference().child(thumbnailPath)
        let thumbnailMetadata = StorageMetadata()
        thumbnailMetadata.contentType = "image/jpeg"
        thumbnailMetadata.cacheControl = "public, max-age=31536000"
        _ = try await thumbnailRef.putDataAsync(thumbData, metadata: thumbnailMetadata)
        let thumbnailURL = try await thumbnailRef.downloadURL()
        
        return MediaUploadResult(
            downloadURL: downloadURL.absoluteString,
            thumbnailURL: thumbnailURL.absoluteString,
            storagePath: storagePath,
            thumbnailPath: thumbnailPath,
            sizeInBytes: uploadMetadata.size,
            duration: nil,
            contentType: "image/jpeg"
        )
    }
    
    func uploadSecretVideo(from videoURL: URL, relationshipId: String) async throws -> MediaUploadResult {
        let sizeLimit = 50 * 1024 * 1024
        let resourceValues = try videoURL.resourceValues(forKeys: [.fileSizeKey])
        
        if let fileSize = resourceValues.fileSize, fileSize > sizeLimit {
            throw StorageError.fileTooLarge(maxMB: 50)
        }
        
        let mediaId = UUID().uuidString
        let ext = videoURL.pathExtension.lowercased()
        let resolvedExtension = ext.isEmpty ? "mov" : ext
        let storagePath = "relationships/\(relationshipId)/secretVault/\(mediaId).\(resolvedExtension)"
        let storageRef = storage.reference().child(storagePath)
        
        let metadata = StorageMetadata()
        metadata.contentType = contentType(forVideoExtension: resolvedExtension)
        metadata.cacheControl = "public, max-age=31536000"
        
        let uploadMetadata = try await storageRef.putFileAsync(from: videoURL, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        let thumbnailImage = try await generateVideoThumbnail(url: videoURL)
        let processedThumbnail = generateThumbnail(from: thumbnailImage, maxSize: 500)
        
        guard let thumbData = processedThumbnail.jpegData(compressionQuality: 0.65) else {
            throw StorageError.invalidImage
        }
        
        let thumbnailPath = "relationships/\(relationshipId)/secretVault/\(mediaId)_thumb.jpg"
        let thumbnailRef = storage.reference().child(thumbnailPath)
        let thumbnailMetadata = StorageMetadata()
        thumbnailMetadata.contentType = "image/jpeg"
        thumbnailMetadata.cacheControl = "public, max-age=31536000"
        _ = try await thumbnailRef.putDataAsync(thumbData, metadata: thumbnailMetadata)
        let thumbnailURL = try await thumbnailRef.downloadURL()
        
        let asset = AVURLAsset(url: videoURL)
        let duration = CMTimeGetSeconds(asset.duration)
        let durationValue = duration.isFinite ? duration : nil
        
        return MediaUploadResult(
            downloadURL: downloadURL.absoluteString,
            thumbnailURL: thumbnailURL.absoluteString,
            storagePath: storagePath,
            thumbnailPath: thumbnailPath,
            sizeInBytes: uploadMetadata.size,
            duration: durationValue,
            contentType: metadata.contentType ?? "video/mp4"
        )
    }
    
    func deleteImage(url: String) async throws {
        let storageRef = storage.reference(forURL: url)
        try await storageRef.delete()
    }
    
    // MARK: - Image Optimization Helpers
    
    private func optimizeImage(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let size = image.size
        
        // If image is already smaller, return as is
        if size.width <= maxDimension && size.height <= maxDimension {
            return image
        }
        
        // Calculate new size maintaining aspect ratio
        let ratio = size.width / size.height
        let newSize: CGSize
        
        if size.width > size.height {
            newSize = CGSize(width: maxDimension, height: maxDimension / ratio)
        } else {
            newSize = CGSize(width: maxDimension * ratio, height: maxDimension)
        }
        
        // Resize image
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    private func generateThumbnail(from image: UIImage, maxSize: CGFloat) -> UIImage {
        let size = image.size
        let ratio = size.width / size.height
        
        let thumbnailSize: CGSize
        if size.width > size.height {
            thumbnailSize = CGSize(width: maxSize, height: maxSize / ratio)
        } else {
            thumbnailSize = CGSize(width: maxSize * ratio, height: maxSize)
        }
        
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
    }
    
    enum StorageError: Error {
        case invalidImage
        case uploadFailed
        case fileTooLarge(maxMB: Int)
    }
    
    private func contentType(forVideoExtension ext: String) -> String {
        switch ext {
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        default:
            return "video/mp4"
        }
    }
    
    private func generateVideoThumbnail(url: URL) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            let asset = AVAsset(url: url)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            let time = CMTime(seconds: 0.1, preferredTimescale: 600)
            
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                    let image = UIImage(cgImage: cgImage)
                    continuation.resume(returning: image)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
