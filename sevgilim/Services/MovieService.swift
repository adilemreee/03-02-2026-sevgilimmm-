//
//  MovieService.swift
//  sevgilim
//

import Foundation
import Combine
import FirebaseFirestore

@MainActor
class MovieService: ObservableObject {
    @Published var movies: [Movie] = []
    @Published var isLoading = false
    
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    
    func listenToMovies(relationshipId: String) {
        listener?.remove()
        isLoading = true
        
        // Optimized query with limit
        listener = db.collection("movies")
            .whereField("relationshipId", isEqualTo: relationshipId)
            .order(by: "watchedDate", descending: true)
            .limit(to: 100) // Limit to 100 movies
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ Error listening to movies: \(error.localizedDescription)")
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    Task { @MainActor in
                        self.isLoading = false
                    }
                    return
                }
                
                let newMovies = documents.compactMap { doc -> Movie? in
                    try? doc.data(as: Movie.self)
                }
                
                Task { @MainActor in
                    self.movies = newMovies
                    self.isLoading = false
                }
            }
    }
    
    func addMovie(relationshipId: String, title: String, watchedDate: Date, 
                 rating: Int?, notes: String?, posterURL: String?, userId: String) async throws {
        let data: [String: Any] = [
            "relationshipId": relationshipId,
            "title": title,
            "watchedDate": Timestamp(date: watchedDate),
            "rating": rating as Any,
            "notes": notes as Any,
            "posterURL": posterURL as Any,
            "addedBy": userId,
            "createdAt": Timestamp(date: Date())
        ]
        
        try await db.collection("movies").addDocument(data: data)
    }
    
    func updateMovie(_ movie: Movie, title: String, watchedDate: Date, 
                    rating: Int?, notes: String?) async throws {
        guard let movieId = movie.id else { return }
        
        let updates: [String: Any] = [
            "title": title,
            "watchedDate": Timestamp(date: watchedDate),
            "rating": rating as Any,
            "notes": notes as Any
        ]
        
        try await db.collection("movies").document(movieId).updateData(updates)
    }
    
    func deleteMovie(_ movie: Movie) async throws {
        guard let movieId = movie.id else { return }
        try await db.collection("movies").document(movieId).delete()
    }
    
    func stopListening() {
        listener?.remove()
        listener = nil
    }
    
    deinit {
        listener?.remove()
    }
}
