//
//  VideoPicker.swift
//  sevgilim
//

import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct VideoPicker: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.filter = .videos
        configuration.selectionLimit = 1
        configuration.preferredAssetRepresentationMode = .automatic
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: VideoPicker
        private let fileManager = FileManager.default
        
        init(parent: VideoPicker) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            parent.dismiss()
            
            guard let provider = results.first?.itemProvider else { return }
            
            let supportedTypes: [UTType] = [.movie, .video, .mpeg4Movie]
            guard let matchedType = supportedTypes.first(where: { provider.hasItemConformingToTypeIdentifier($0.identifier) }) else {
                return
            }
            
            provider.loadFileRepresentation(forTypeIdentifier: matchedType.identifier) { [weak self] url, error in
                guard let self, let sourceURL = url, error == nil else {
                    if let error {
                        print("❌ Video picker load error: \(error.localizedDescription)")
                    }
                    return
                }
                
                let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension.lowercased()
                let tempURL = self.fileManager.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
                
                do {
                    if self.fileManager.fileExists(atPath: tempURL.path) {
                        try self.fileManager.removeItem(at: tempURL)
                    }
                    try self.fileManager.copyItem(at: sourceURL, to: tempURL)
                    
                    DispatchQueue.main.async {
                        self.parent.videoURL = tempURL
                    }
                } catch {
                    print("❌ Video picker copy error: \(error.localizedDescription)")
                }
            }
        }
    }
}
