//
//  NotesView.swift
//  sevgilim
//

import SwiftUI

struct NotesView: View {
    @EnvironmentObject var noteService: NoteService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddNote = false
    @State private var selectedNote: Note?
    
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
                // Compact Header
                HStack(spacing: 12) {
                    Image(systemName: "note.text")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notlarımız")
                            .font(.title3)
                            .fontWeight(.bold)
                        
                        Text("Paylaşımlı not defterimiz")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(.top, 10)
                .padding(.horizontal, 20)
                .padding(.bottom, 15)
                
                // Content
                if noteService.notes.isEmpty {
                    let _ = print("📝 Notes list is empty")
                    VStack(spacing: 20) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary.opacity(0.6))
                        
                        VStack(spacing: 8) {
                            Text("Henüz not yok")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            Text("Birlikte not tutmaya başlayın")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        
                        Button(action: { showingAddNote = true }) {
                            Label("İlk Notu Ekle", systemImage: "plus.circle.fill")
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
                    let _ = print("📝 Displaying \(noteService.notes.count) notes")
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(noteService.notes) { note in
                                NoteCardModern(note: note)
                                    .onTapGesture {
                                        print("📝 Note tapped: \(note.title)")
                                        selectedNote = note
                                    }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                    .id(noteService.notes.count) // Force refresh when count changes
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddNote = true }) {
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
                    .padding(.bottom, 20)
                }
            }
        }
        .sheet(isPresented: $showingAddNote) {
            AddNoteView()
        }
        .sheet(item: $selectedNote) { note in
            NoteDetailView(note: note)
        }
        .onAppear {
            print("📝 NotesView appeared")
            // Listener is handled by MainTabView
        }
        .onDisappear {
            print("📝 NotesView disappeared - keeping listener active")
        }
    }
}

// Modern Note Card
struct NoteCardModern: View {
    let note: Note
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: "doc.text.fill")
                .font(.title2)
                .foregroundColor(.orange)
                .frame(width: 44, height: 44)
                .background(.orange.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text(note.content)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                
                Text(note.updatedAt.timeAgo())
                    .font(.caption)
                    .foregroundColor(.secondary)
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

struct NoteRowView: View {
    let note: Note
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        NoteCardModern(note: note)
    }
}

struct NoteDetailView: View {
    let note: Note
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var noteService: NoteService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedContent: String
    @State private var showingDeleteAlert = false
    
    init(note: Note) {
        self.note = note
        _editedTitle = State(initialValue: note.title)
        _editedContent = State(initialValue: note.content)
    }
    
    var body: some View {
        NavigationView {
            VStack {
                if isEditing {
                    Form {
                        Section("Başlık") {
                            TextField("Başlık", text: $editedTitle)
                        }
                        
                        Section("İçerik") {
                            TextEditor(text: $editedContent)
                                .frame(minHeight: 300)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            Text(note.title)
                                .font(.title.bold())
                            
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Oluşturulma: \(note.createdAt, formatter: DateFormatter.fullFormat)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Text("Güncellenme: \(note.updatedAt, formatter: DateFormatter.fullFormat)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Divider()
                            
                            Text(note.content)
                                .font(.body)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                    }
                }
            }
            .navigationTitle("Not Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "İptal" : "Kapat") {
                        if isEditing {
                            editedTitle = note.title
                            editedContent = note.content
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        if isEditing {
                            Button("Kaydet") {
                                saveChanges()
                            }
                            .disabled(editedTitle.isEmpty || editedContent.isEmpty)
                        } else {
                            Button(action: { isEditing = true }) {
                                Image(systemName: "pencil")
                            }
                            
                            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .alert("Notu Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        do {
                            print("🗑️ Starting delete operation for note: \(note.title)")
                            try await noteService.deleteNote(note)
                            print("✅ Delete completed, waiting before dismiss...")
                            
                            // Kısa bir gecikme ekle - Firebase'in listener'ı tetiklemesi için zaman tanı
                            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 saniye
                            
                            await MainActor.run {
                                print("✅ Dismissing detail view")
                                dismiss()
                            }
                        } catch {
                            print("❌ Error in delete operation: \(error.localizedDescription)")
                            await MainActor.run {
                                dismiss()
                            }
                        }
                    }
                }
            } message: {
                Text("Bu notu silmek istediğinizden emin misiniz?")
            }
        }
    }
    
    private func saveChanges() {
        Task {
            try? await noteService.updateNote(note, title: editedTitle, content: editedContent)
            await MainActor.run {
                isEditing = false
            }
        }
    }
}

struct AddNoteView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var noteService: NoteService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var title = ""
    @State private var content = ""
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Gradient Background
                LinearGradient(
                    colors: [
                        themeManager.currentTheme.primaryColor.opacity(0.25),
                        themeManager.currentTheme.secondaryColor.opacity(0.18)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        HStack(spacing: 12) {
                            Image(systemName: "note.text.badge.plus")
                                .font(.system(size: 24))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [.orange, .yellow],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Yeni Not")
                                    .font(.title3)
                                    .fontWeight(.bold)
                                
                                Text("Birlikte not tutun")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        // Title Section
                        VStack(alignment: .leading, spacing: 18) {
                            Text("BAŞLIK")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .kerning(0.5)
                            
                            TextField("", text: $title, prompt: Text("Not başlığı..."))
                                .textFieldStyle(.plain)
                                .font(.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(.systemBackground).opacity(0.94))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                                )
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
                        
                        // Content Section
                        VStack(alignment: .leading, spacing: 18) {
                            Text("İÇERİK")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(.secondary)
                                .kerning(0.5)
                            
                            ZStack(alignment: .topLeading) {
                                if content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text("Notunuzu buraya yazın...")
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 16)
                                }
                                
                                TextEditor(text: $content)
                                    .scrollContentBackground(.hidden)
                                    .frame(minHeight: 250)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(.systemBackground).opacity(0.94))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(themeManager.currentTheme.primaryColor.opacity(0.08), lineWidth: 1)
                            )
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 10)
                        
                        // Save Button
                        Button(action: saveNote) {
                            HStack {
                                if isSaving {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Kaydet")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [
                                        themeManager.currentTheme.primaryColor,
                                        themeManager.currentTheme.secondaryColor
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(color: themeManager.currentTheme.primaryColor.opacity(0.3), radius: 10, x: 0, y: 5)
                        }
                        .disabled(title.isEmpty || content.isEmpty || isSaving)
                        .opacity((title.isEmpty || content.isEmpty) ? 0.5 : 1.0)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("İptal")
                        }
                        .foregroundColor(themeManager.currentTheme.primaryColor)
                    }
                }
            }
            .overlay {
                if isSaving {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 15) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Kaydediliyor...")
                                .foregroundColor(.white)
                        }
                        .padding(30)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    }
                }
            }
        }
    }
    
    private func saveNote() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else { return }
        
        isSaving = true
        Task {
            do {
                try await noteService.addNote(
                    relationshipId: relationshipId,
                    title: title,
                    content: content,
                    userId: userId
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving note: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

