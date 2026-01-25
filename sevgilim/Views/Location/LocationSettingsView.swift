//
//  LocationSettingsView.swift
//  sevgilim
//
//  Konum paylaşım ayarları görünümü
//

import SwiftUI

struct LocationSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var settings: LocationSharingSettings
    let onSave: (LocationSharingSettings) -> Void
    
    @State private var localSettings: LocationSharingSettings
    @State private var showProximityPicker = false
    
    init(settings: Binding<LocationSharingSettings>, onSave: @escaping (LocationSharingSettings) -> Void) {
        self._settings = settings
        self.onSave = onSave
        self._localSettings = State(initialValue: settings.wrappedValue)
    }
    
    var body: some View {
        NavigationView {
            Form {
                // Ana paylaşım ayarı
                Section {
                    Toggle("Konum Paylaşımı", isOn: $localSettings.isEnabled)
                        .tint(.pink)
                } header: {
                    Text("Genel")
                } footer: {
                    Text("Konum paylaşımını açtığınızda sevgiliniz konumunuzu görebilir.")
                }
                
                // Paylaşım modu
                Section {
                    Picker("Paylaşım Modu", selection: $localSettings.sharingMode) {
                        ForEach(LocationSharingSettings.SharingMode.allCases, id: \.self) { mode in
                            VStack(alignment: .leading) {
                                Label(mode.displayName, systemImage: mode.icon)
                            }
                            .tag(mode)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Paylaşım Modu")
                } footer: {
                    Text(localSettings.sharingMode.description)
                }
                
                // Güncelleme sıklığı
                Section {
                    Picker("Güncelleme Sıklığı", selection: $localSettings.updateFrequency) {
                        ForEach(LocationSharingSettings.UpdateFrequency.allCases, id: \.self) { freq in
                            HStack {
                                Image(systemName: freq.icon)
                                Text(freq.displayName)
                            }
                            .tag(freq)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("Güncelleme Sıklığı")
                } footer: {
                    Text(localSettings.updateFrequency.description)
                }
                
                // Yakınlık algılama
                Section {
                    Toggle("Buluşma Algılama", isOn: $localSettings.meetingDetectionEnabled)
                        .tint(.pink)
                    
                    if localSettings.meetingDetectionEnabled {
                        // Yakınlık eşiği
                        Button {
                            showProximityPicker = true
                        } label: {
                            HStack {
                                Text("Yakınlık Eşiği")
                                    .foregroundColor(.primary)
                                Spacer()
                                Text(localSettings.formattedProximityThreshold)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Minimum buluşma süresi
                        Picker("Min. Buluşma Süresi", selection: $localSettings.minimumMeetingDuration) {
                            Text("30 saniye").tag(TimeInterval(30))
                            Text("1 dakika").tag(TimeInterval(60))
                            Text("2 dakika").tag(TimeInterval(120))
                            Text("5 dakika").tag(TimeInterval(300))
                        }
                    }
                } header: {
                    Text("Buluşma Algılama")
                } footer: {
                    if localSettings.meetingDetectionEnabled {
                        Text("Yakınlık eşiği içinde \(localSettings.formattedMinimumMeetingDuration) kaldığınızda buluşma olarak algılanır.")
                    } else {
                        Text("Buluşma algılama kapalı. Sevgilinizle buluştuğunuzda bildirim almayacaksınız.")
                    }
                }
                
                // Bildirimler
                Section {
                    Toggle("Buluşma Bildirimleri", isOn: $localSettings.notificationsEnabled)
                        .tint(.pink)
                } header: {
                    Text("Bildirimler")
                } footer: {
                    Text("Sevgilinizle buluştuğunuzda bildirim alın.")
                }
                
                // Görünürlük ayarları
                Section {
                    Toggle("Batarya Seviyesini Göster", isOn: $localSettings.showBatteryLevel)
                    Toggle("Hız Bilgisini Göster", isOn: $localSettings.showSpeed)
                    Toggle("Son Görülme Zamanı", isOn: $localSettings.showLastSeen)
                } header: {
                    Text("Görünürlük")
                } footer: {
                    Text("Bu bilgiler sevgiliniz tarafından görülebilir.")
                }
                
                // Hakkında
                Section {
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                        Text("Pil Kullanımı Hakkında")
                    }
                } header: {
                    Text("Bilgi")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("• Gerçek Zamanlı: Yüksek pil tüketimi")
                        Text("• Normal: Dengeli pil tüketimi")
                        Text("• Pil Tasarrufu: Düşük pil tüketimi")
                        Text("")
                        Text("Arka planda konum paylaşımı (Her Zaman modu) daha fazla pil tüketir.")
                    }
                }
            }
            .navigationTitle("Konum Ayarları")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("İptal") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Kaydet") {
                        settings = localSettings
                        onSave(localSettings)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showProximityPicker) {
                ProximityPickerView(threshold: $localSettings.proximityThreshold)
            }
        }
    }
}

// MARK: - Proximity Picker View
struct ProximityPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var threshold: Double
    
    let presets: [LocationSharingSettings.ProximityPreset] = LocationSharingSettings.ProximityPreset.allCases
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(presets, id: \.self) { preset in
                        Button {
                            threshold = preset.distance
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(preset.displayName)
                                        .foregroundColor(.primary)
                                    Text(preset.description)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if threshold == preset.distance {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.pink)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                    }
                } header: {
                    Text("Yakınlık Eşiği Seçin")
                } footer: {
                    Text("Bu mesafe içinde olduğunuzda buluşma algılanır.")
                }
                
                // Özel değer
                Section {
                    HStack {
                        Text("Özel Değer")
                        Spacer()
                        TextField("Metre", value: $threshold, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("m")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Özel")
                }
            }
            .navigationTitle("Yakınlık Eşiği")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Tamam") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Preview
#Preview {
    LocationSettingsView(
        settings: .constant(.default),
        onSave: { _ in }
    )
}
