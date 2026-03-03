//
//  OfflineSyncManager.swift
//  sevgilim
//
//  Manages offline operations queue and syncs when back online
//  Queues write operations (add/update/delete) when offline
//  Automatically retries when connection is restored
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
final class OfflineSyncManager: ObservableObject {
    
    static let shared = OfflineSyncManager()
    
    // MARK: - Published State
    @Published private(set) var pendingOperations: Int = 0
    @Published private(set) var isSyncing: Bool = false
    @Published private(set) var lastSyncDate: Date?
    @Published var syncError: String?
    
    // MARK: - Private
    private var operationQueue: [PendingOperation] = []
    private let queueFileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Models
    struct PendingOperation: Codable, Identifiable {
        let id: String
        let type: OperationType
        let collection: String
        let documentId: String?
        let data: [String: CodableValue]?
        let timestamp: Date
        var retryCount: Int
        
        enum OperationType: String, Codable {
            case add
            case update
            case delete
        }
    }
    
    // Generic codable value wrapper for Firestore data
    enum CodableValue: Codable {
        case string(String)
        case int(Int)
        case double(Double)
        case bool(Bool)
        case date(Date)
        case array([CodableValue])
        case null
        
        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let value = try? container.decode(String.self) {
                self = .string(value)
            } else if let value = try? container.decode(Int.self) {
                self = .int(value)
            } else if let value = try? container.decode(Double.self) {
                self = .double(value)
            } else if let value = try? container.decode(Bool.self) {
                self = .bool(value)
            } else if let value = try? container.decode(Date.self) {
                self = .date(value)
            } else if let value = try? container.decode([CodableValue].self) {
                self = .array(value)
            } else {
                self = .null
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let value): try container.encode(value)
            case .int(let value): try container.encode(value)
            case .double(let value): try container.encode(value)
            case .bool(let value): try container.encode(value)
            case .date(let value): try container.encode(value)
            case .array(let value): try container.encode(value)
            case .null: try container.encodeNil()
            }
        }
        
        var toAny: Any {
            switch self {
            case .string(let v): return v
            case .int(let v): return v
            case .double(let v): return v
            case .bool(let v): return v
            case .date(let v): return v
            case .array(let v): return v.map { $0.toAny }
            case .null: return NSNull()
            }
        }
    }
    
    // MARK: - Init
    private init() {
        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        queueFileURL = documentsDir.appendingPathComponent("pending_sync_queue.json")
        
        encoder.dateEncodingStrategy = .secondsSince1970
        decoder.dateDecodingStrategy = .secondsSince1970
        
        // Load persisted queue OFF main thread to avoid blocking UI at launch
        let url = queueFileURL
        let dec = decoder
        Task.detached { [weak self] in
            guard let data = try? Data(contentsOf: url),
                  let queue = try? dec.decode([PendingOperation].self, from: data) else { return }
            await self?.applyLoadedQueue(queue)
        }
        
        // Listen for connectivity changes
        setupNetworkListener()
    }
    
    /// Apply loaded queue on main actor after background disk read
    private func applyLoadedQueue(_ queue: [PendingOperation]) {
        operationQueue = queue
        pendingOperations = queue.count
        if !queue.isEmpty {
            print("📋 OfflineSync: \(queue.count) bekleyen işlem yüklendi")
        }
    }
    
    // MARK: - Public API
    
    /// Queue an operation for later sync
    func queueOperation(
        type: PendingOperation.OperationType,
        collection: String,
        documentId: String? = nil,
        data: [String: Any]? = nil
    ) {
        let codableData = data?.compactMapValues { value -> CodableValue? in
            if let s = value as? String { return .string(s) }
            if let i = value as? Int { return .int(i) }
            if let d = value as? Double { return .double(d) }
            if let b = value as? Bool { return .bool(b) }
            if let date = value as? Date { return .date(date) }
            return nil
        }
        
        let operation = PendingOperation(
            id: UUID().uuidString,
            type: type,
            collection: collection,
            documentId: documentId,
            data: codableData,
            timestamp: Date(),
            retryCount: 0
        )
        
        operationQueue.append(operation)
        pendingOperations = operationQueue.count
        saveQueue()
        
        print("📝 OfflineSync: İşlem kuyruğa eklendi (\(type.rawValue) → \(collection))")
    }
    
    /// Manually trigger sync
    func syncNow() async {
        guard NetworkMonitor.shared.isConnected else {
            syncError = "İnternet bağlantısı yok"
            return
        }
        
        guard !isSyncing else { return }
        guard !operationQueue.isEmpty else { return }
        
        isSyncing = true
        syncError = nil
        
        var failedOperations: [PendingOperation] = []
        
        for operation in operationQueue {
            do {
                try await executeOperation(operation)
                print("✅ OfflineSync: İşlem başarılı (\(operation.type.rawValue) → \(operation.collection))")
            } catch {
                var failedOp = operation
                failedOp.retryCount += 1
                
                // Max 5 retry
                if failedOp.retryCount < 5 {
                    failedOperations.append(failedOp)
                } else {
                    print("❌ OfflineSync: İşlem kalıcı olarak başarısız (\(operation.id))")
                }
            }
        }
        
        operationQueue = failedOperations
        pendingOperations = operationQueue.count
        lastSyncDate = Date()
        isSyncing = false
        saveQueue()
        
        if failedOperations.isEmpty {
            print("🎉 OfflineSync: Tüm işlemler senkronize edildi")
        } else {
            syncError = "\(failedOperations.count) işlem senkronize edilemedi"
        }
    }
    
    /// Clear the operation queue
    func clearQueue() {
        operationQueue.removeAll()
        pendingOperations = 0
        saveQueue()
    }
    
    // MARK: - Private Methods
    
    private func executeOperation(_ operation: PendingOperation) async throws {
        let db = Firestore.firestore()
        
        switch operation.type {
        case .add:
            let data = operation.data?.mapValues { $0.toAny } ?? [:]
            if let docId = operation.documentId {
                try await db.collection(operation.collection).document(docId).setData(data)
            } else {
                _ = try await db.collection(operation.collection).addDocument(data: data)
            }
            
        case .update:
            guard let docId = operation.documentId else { return }
            let data = operation.data?.mapValues { $0.toAny } ?? [:]
            try await db.collection(operation.collection).document(docId).updateData(data)
            
        case .delete:
            guard let docId = operation.documentId else { return }
            try await db.collection(operation.collection).document(docId).delete()
        }
    }
    
    private func setupNetworkListener() {
        // When connection comes back, try to sync
        NetworkMonitor.shared.onConnected { [weak self] in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                if !self.operationQueue.isEmpty {
                    print("🔄 OfflineSync: Bağlantı geri geldi, senkronizasyon başlıyor...")
                    await self.syncNow()
                }
            }
        }
    }
    
    private func saveQueue() {
        let data: Data
        do {
            data = try encoder.encode(operationQueue)
        } catch { return }
        let url = queueFileURL
        // Write to disk off main thread
        Task.detached {
            try? data.write(to: url, options: .atomic)
        }
    }
    
    // loadQueue is now handled inline in init via Task.detached
}
