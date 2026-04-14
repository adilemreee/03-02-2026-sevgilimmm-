//
//  FirestoreDocumentDecoder.swift
//  sevgilim
//

import Foundation
import FirebaseFirestore

enum FirestoreDocumentDecoder {
    static func decode<T: Decodable>(_ type: T.Type, from document: QueryDocumentSnapshot) throws -> T {
        let decoder = Firestore.Decoder()
        var data = document.data()
        data["id"] = document.documentID
        return try decoder.decode(T.self, from: data)
    }
    
    static func decode<T: Decodable>(_ type: T.Type, from document: DocumentSnapshot) throws -> T {
        guard var data = document.data() else {
            throw NSError(
                domain: "FirestoreDocumentDecoder",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Document data is missing"]
            )
        }
        
        let decoder = Firestore.Decoder()
        data["id"] = document.documentID
        return try decoder.decode(T.self, from: data)
    }
}
