//
//  MoviesView.swift
//  sevgilim
//

import SwiftUI

struct MoviesView: View {
    @EnvironmentObject var movieService: MovieService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddMovie = false
    @State private var selectedMovie: Movie?
    
    private var headerSubtitle: String {
        movieService.movies.isEmpty ?
        "Birlikte izlediğiniz filmler" :
        "Birlikte izlediğiniz film arşivi"
    }
    
    var body: some View {
        ZStack {
            // Gradient Background
            LinearGradient(
                colors: [
                    themeManager.currentTheme.primaryColor.opacity(0.3),
                    themeManager.currentTheme.secondaryColor.opacity(0.2)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                SectionHeroHeader(
                    systemImage: "tv.fill",
                    iconColors: [.purple, .pink],
                    title: "İzlenen Filmler",
                    subtitle: headerSubtitle,
                    countValue: "\(movieService.movies.count)",
                    countTint: .purple
                )
                
                // Content
                if movieService.movies.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "popcorn")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("Henüz film yok")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("İzlediğiniz filmleri kaydedin")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: { showingAddMovie = true }) {
                            Label("İlk Filmi Ekle", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(themeManager.currentTheme.primaryColor)
                                .cornerRadius(12)
                        }
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(movieService.movies) { movie in
                                MovieCardModern(movie: movie)
                                    .onTapGesture {
                                        selectedMovie = movie
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddMovie = true }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(width: 60, height: 60)
                            .background(themeManager.currentTheme.primaryColor)
                            .clipShape(Circle())
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 80)
                }
            }
        }
        .sheet(isPresented: $showingAddMovie) {
            AddMovieView()
        }
        .sheet(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie)
        }
        .onAppear {
            if let relationshipId = authService.currentUser?.relationshipId {
                movieService.listenToMovies(relationshipId: relationshipId)
            }
        }
    }
}

// Modern Movie Card
struct MovieCardModern: View {
    let movie: Movie
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "tv.fill")
                .font(.title2)
                .foregroundColor(.purple)
                .frame(width: 44, height: 44)
                .background(.purple.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(movie.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(movie.watchedDate, formatter: DateFormatter.displayFormat)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Rating
                if let rating = movie.rating {
                    HStack(spacing: 2) {
                        ForEach(1...5, id: \.self) { star in
                            Image(systemName: star <= rating ? "star.fill" : "star")
                                .font(.caption)
                                .foregroundColor(star <= rating ? .yellow : .secondary)
                        }
                    }
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}

struct MovieRowView: View {
    let movie: Movie
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        MovieCardModern(movie: movie)
    }
}

struct MovieDetailView: View {
    let movie: Movie
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var movieService: MovieService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingDeleteAlert = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let posterURL = movie.posterURL {
                        AsyncImage(url: URL(string: posterURL)) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure:
                                Image(systemName: "film.fill")
                                    .font(.largeTitle)
                            case .empty:
                                ProgressView()
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(maxHeight: 400)
                    }
                    
                    VStack(alignment: .leading, spacing: 15) {
                        Text(movie.title)
                            .font(.title.bold())
                        
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.secondary)
                            Text("İzlenme: \(movie.watchedDate, formatter: DateFormatter.displayFormat)")
                                .foregroundColor(.secondary)
                        }
                        
                        if let rating = movie.rating {
                            HStack {
                                Text("Değerlendirme:")
                                    .foregroundColor(.secondary)
                                HStack(spacing: 4) {
                                    ForEach(1...5, id: \.self) { star in
                                        Image(systemName: star <= rating ? "star.fill" : "star")
                                            .foregroundStyle(star <= rating ? themeManager.currentTheme.accentColor : .secondary)
                                    }
                                }
                            }
                        }
                        
                        if let notes = movie.notes {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Notlar:")
                                    .font(.headline)
                                Text(notes)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Film Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Kapat") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .alert("Filmi Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        try? await movieService.deleteMovie(movie)
                        dismiss()
                    }
                }
            } message: {
                Text("Bu filmi silmek istediğinizden emin misiniz?")
            }
        }
    }
}

struct AddMovieView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var movieService: MovieService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var title = ""
    @State private var watchedDate = Date()
    @State private var rating: Int?
    @State private var notes = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Film Bilgileri") {
                    TextField("Film adı", text: $title)
                    DatePicker("İzlenme tarihi", selection: $watchedDate, displayedComponents: .date)
                    .environment(\.locale, Locale(identifier: "tr_TR"))
                }
                
                Section("Değerlendirme") {
                    HStack {
                        Text("Puan:")
                        Spacer()
                        ForEach(1...5, id: \.self) { star in
                            Button(action: {
                                rating = (rating == star) ? nil : star
                            }) {
                                Image(systemName: (rating ?? 0) >= star ? "star.fill" : "star")
                                    .foregroundStyle((rating ?? 0) >= star ? themeManager.currentTheme.accentColor : .secondary)
                            }
                        }
                    }
                }
                
                Section("Notlar (İsteğe bağlı)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("Film Ekle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        saveMovie()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func saveMovie() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else { return }
        
        isSaving = true
        Task {
            do {
                try await movieService.addMovie(
                    relationshipId: relationshipId,
                    title: title,
                    watchedDate: watchedDate,
                    rating: rating,
                    notes: notes.isEmpty ? nil : notes,
                    posterURL: nil,
                    userId: userId
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving movie: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}
