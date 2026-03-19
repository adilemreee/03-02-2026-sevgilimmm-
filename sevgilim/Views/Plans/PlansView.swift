//
//  PlansView.swift
//  sevgilim
//

import SwiftUI

struct PlansView: View {
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var showingAddPlan = false
    @State private var selectedSegment = 0
    @State private var selectedPlan: Plan?
    
    var activePlans: [Plan] {
        planService.plans.filter { !$0.isCompleted }
    }
    
    var completedPlans: [Plan] {
        planService.plans.filter { $0.isCompleted }
    }
    
    private var headerSubtitle: String {
        selectedSegment == 0 ?
        "Birlikte yapacağınız planlar" :
        "Tamamlanan güzel planlar"
    }
    
    private var headerCountValue: String {
        "\(selectedSegment == 0 ? activePlans.count : completedPlans.count)"
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
                    systemImage: "list.star",
                    iconColors: [.indigo, .blue],
                    title: "Planlarımız",
                    subtitle: headerSubtitle,
                    countValue: headerCountValue,
                    countTint: .indigo
                )
                
                // Segmented Picker
                Picker("", selection: $selectedSegment) {
                    Text("Aktif").tag(0)
                    Text("Tamamlanan").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                
                // Content
                ZStack {
                    if selectedSegment == 0 {
                        if activePlans.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                VStack(spacing: 8) {
                                    Text("Henüz plan yok")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text("Birlikte yapacağınız planları ekleyin")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                
                                Button(action: { showingAddPlan = true }) {
                                    Label("İlk Planı Ekle", systemImage: "plus.circle.fill")
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
                                    ForEach(activePlans) { plan in
                                        PlanCardModern(plan: plan)
                                            .onTapGesture {
                                                selectedPlan = plan
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    } else {
                        if completedPlans.isEmpty {
                            VStack(spacing: 20) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 60))
                                    .foregroundColor(.secondary.opacity(0.6))
                                
                                Text("Tamamlanan plan yok")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .frame(maxHeight: .infinity)
                        } else {
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(completedPlans) { plan in
                                        PlanCardModern(plan: plan)
                                            .onTapGesture {
                                                selectedPlan = plan
                                            }
                                    }
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            
            // Floating Add Button
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button(action: { showingAddPlan = true }) {
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
        .sheet(isPresented: $showingAddPlan) {
            AddPlanView()
                .environmentObject(planService)
                .environmentObject(authService)
        }
        .sheet(item: $selectedPlan) { plan in
            PlanDetailView(plan: plan)
                .environmentObject(planService)
        }
    }
}

// Modern Plan Card
struct PlanCardModern: View {
    let plan: Plan
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var authService: AuthenticationService
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        HStack(spacing: 16) {
            // Checkbox
            Button(action: toggleCompletion) {
                Image(systemName: plan.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(plan.isCompleted ? .green : themeManager.currentTheme.primaryColor)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 6) {
                Text(plan.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .strikethrough(plan.isCompleted)
                    .lineLimit(1)
                
                if let description = plan.description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
                
                HStack(spacing: 12) {
                    if let date = plan.date {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.caption2)
                            Text(date, formatter: DateFormatter.displayFormat)
                                .font(.caption2)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    if plan.reminderEnabled {
                        HStack(spacing: 4) {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                            Text("Hatırlatıcı")
                                .font(.caption2)
                        }
                        .foregroundColor(.orange)
                    }
                }
            }
            
            Spacer()
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
    
    private func toggleCompletion() {
        Task {
            try? await planService.toggleCompletion(
                plan,
                userId: authService.currentUser?.id
            )
        }
    }
}

struct PlanRowView: View {
    let plan: Plan
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var themeManager: ThemeManager
    
    var body: some View {
        PlanCardModern(plan: plan)
    }
}

struct AddPlanView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var title = ""
    @State private var description = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var reminderEnabled = false
    @State private var isSaving = false
    
    var body: some View {
        NavigationView {
            Form {
                Section("Plan Detayları") {
                    TextField("Başlık", text: $title)
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                }
                
                Section("Tarih") {
                    Toggle("Tarih ekle", isOn: $hasDate)
                    
                    if hasDate {
                        DatePicker("Tarih", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .environment(\.locale, Locale(identifier: "tr_TR"))
                        Toggle("Hatırlatıcı", isOn: $reminderEnabled)
                    }
                }
            }
            .navigationTitle("Yeni Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        savePlan()
                    }
                    .disabled(title.isEmpty || isSaving)
                }
            }
        }
    }
    
    private func savePlan() {
        guard let userId = authService.currentUser?.id,
              let relationshipId = authService.currentUser?.relationshipId else { return }
        
        isSaving = true
        Task {
            do {
                try await planService.addPlan(
                    relationshipId: relationshipId,
                    title: title,
                    description: description.isEmpty ? nil : description,
                    date: hasDate ? date : nil,
                    reminderEnabled: reminderEnabled,
                    userId: userId
                )
                await MainActor.run {
                    dismiss()
                }
            } catch {
                print("Error saving plan: \(error)")
                await MainActor.run {
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Plan Detail View
struct PlanDetailView: View {
    let plan: Plan
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var planService: PlanService
    @EnvironmentObject var authService: AuthenticationService
    
    @State private var isEditing = false
    @State private var editedTitle: String
    @State private var editedDescription: String
    @State private var editedDate: Date?
    @State private var editedReminderEnabled: Bool
    @State private var showingDeleteAlert = false
    
    init(plan: Plan) {
        self.plan = plan
        _editedTitle = State(initialValue: plan.title)
        _editedDescription = State(initialValue: plan.description ?? "")
        _editedDate = State(initialValue: plan.date)
        _editedReminderEnabled = State(initialValue: plan.reminderEnabled)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    // Status Badge
                    HStack {
                        if plan.isCompleted {
                            Label("Tamamlandı", systemImage: "checkmark.circle.fill")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.green)
                                .cornerRadius(20)
                        } else {
                            Label("Aktif", systemImage: "circle")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.blue)
                                .cornerRadius(20)
                        }
                        Spacer()
                    }
                    
                    if isEditing {
                        // Edit Mode
                        VStack(alignment: .leading, spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Başlık")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                TextField("Plan başlığı", text: $editedTitle)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Açıklama")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.secondary)
                                TextEditor(text: $editedDescription)
                                    .frame(minHeight: 100)
                                    .padding(8)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Tarih")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if editedDate != nil {
                                        Button("Kaldır") {
                                            editedDate = nil
                                        }
                                        .font(.caption)
                                        .foregroundColor(.red)
                                    }
                                }
                                
                                if editedDate == nil {
                                    Button(action: { editedDate = Date() }) {
                                        Label("Tarih Ekle", systemImage: "calendar.badge.plus")
                                            .font(.subheadline)
                                            .foregroundColor(.blue)
                                            .frame(maxWidth: .infinity)
                                            .padding()
                                            .background(Color(.systemGray6))
                                            .cornerRadius(8)
                                    }
                                } else {
                                    DatePicker("", selection: Binding(
                                        get: { editedDate ?? Date() },
                                        set: { editedDate = $0 }
                                    ), displayedComponents: [.date, .hourAndMinute])
                                    .datePickerStyle(.graphical)
                                }
                            }
                            
                            Toggle("Hatırlatıcı", isOn: $editedReminderEnabled)
                        }
                    } else {
                        // View Mode
                        VStack(alignment: .leading, spacing: 20) {
                            Text(plan.title)
                                .font(.title.bold())
                                .foregroundColor(.primary)
                            
                            if let description = plan.description, !description.isEmpty {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Açıklama")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.secondary)
                                    Text(description)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if let date = plan.date {
                                Divider()
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "calendar")
                                            .foregroundColor(.blue)
                                        Text("Tarih")
                                            .font(.subheadline.bold())
                                            .foregroundColor(.secondary)
                                    }
                                    Text(date, formatter: DateFormatter.fullFormat)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                }
                            }
                            
                            if plan.reminderEnabled {
                                Divider()
                                
                                HStack {
                                    Image(systemName: "bell.fill")
                                        .foregroundColor(.orange)
                                    Text("Hatırlatıcı aktif")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.orange)
                                }
                            }
                            
                            Divider()
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Oluşturulma")
                                    .font(.caption.bold())
                                    .foregroundColor(.secondary)
                                Text(plan.createdAt, formatter: DateFormatter.fullFormat)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(24)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Plan Detayı")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(isEditing ? "İptal" : "Kapat") {
                        if isEditing {
                            editedTitle = plan.title
                            editedDescription = plan.description ?? ""
                            editedDate = plan.date
                            editedReminderEnabled = plan.reminderEnabled
                            isEditing = false
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        if !isEditing {
                            // Toggle completion
                            Button(action: {
                                Task {
                                    try? await planService.toggleCompletion(
                                        plan,
                                        userId: authService.currentUser?.id
                                    )
                                }
                            }) {
                                Image(systemName: plan.isCompleted ? "arrow.uturn.backward.circle" : "checkmark.circle.fill")
                                    .foregroundColor(plan.isCompleted ? .blue : .green)
                            }
                            
                            // Edit button
                            Button(action: { isEditing = true }) {
                                Image(systemName: "pencil")
                            }
                            
                            // Delete button
                            Button(role: .destructive, action: { showingDeleteAlert = true }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                            }
                        } else {
                            // Save button
                            Button("Kaydet") {
                                saveChanges()
                            }
                            .disabled(editedTitle.isEmpty)
                        }
                    }
                }
            }
            .alert("Planı Sil", isPresented: $showingDeleteAlert) {
                Button("İptal", role: .cancel) {}
                Button("Sil", role: .destructive) {
                    Task {
                        do {
                            try await planService.deletePlan(plan)
                            await MainActor.run {
                                dismiss()
                            }
                        } catch {
                            print("Error deleting plan: \(error.localizedDescription)")
                        }
                    }
                }
            } message: {
                Text("Bu planı silmek istediğinizden emin misiniz?")
            }
        }
    }
    
    private func saveChanges() {
        Task {
            do {
                try await planService.updatePlan(
                    plan,
                    title: editedTitle,
                    description: editedDescription.isEmpty ? nil : editedDescription,
                    date: editedDate,
                    reminderEnabled: editedReminderEnabled,
                    userId: authService.currentUser?.id
                )
                await MainActor.run {
                    isEditing = false
                }
            } catch {
                print("Error updating plan: \(error.localizedDescription)")
            }
        }
    }
}
