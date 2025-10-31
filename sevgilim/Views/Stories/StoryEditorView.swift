import SwiftUI
import PencilKit

struct StoryEditorView: View {
    @Binding var image: UIImage?

    @Environment(\.dismiss) private var dismiss

    @State private var drawing = PKDrawing()
    @State private var imageFrame: CGRect = .zero
    @State private var canvasView: PKCanvasView?
    @State private var canUndo = false
    @State private var canRedo = false
    @State private var selectedInkType: PKInkingTool.InkType = .pen
    @State private var selectedColorId: String = PaletteEntry.presets.first?.id ?? "white"
    @State private var strokeWidth: Double = 6
    @State private var isEraserActive = false

    private let palette = PaletteEntry.presets
    private let minStrokeWidth: Double = 2
    private let maxStrokeWidth: Double = 26

    private var selectedColor: UIColor {
        palette.first { $0.id == selectedColorId }?.color ?? palette[0].color
    }

    private var hasDrawing: Bool {
        !drawing.strokes.isEmpty
    }

    var body: some View {
        GeometryReader { geo in
            let bottomInset = geo.safeAreaInsets.bottom

            ZStack(alignment: .top) {
                Color.black.ignoresSafeArea()

                editingSurface(size: geo.size)

                topBar
                    .padding(.top, geo.safeAreaInsets.top + 12)
                    .padding(.horizontal, 20)

                VStack {
                    Spacer()
                    bottomControls(bottomInset: bottomInset)
                        .padding(.horizontal, 12)
                        .padding(.bottom, max(bottomInset, 10))
                }
            }
            .coordinateSpace(name: "canvas")
            .onChange(of: image) { _, newValue in
                if newValue == nil {
                    drawing = PKDrawing()
                    imageFrame = .zero
                }
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            Button(action: { dismiss() }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.92))
                    .frame(width: 42, height: 42)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Text("Story Çizimi")
                .font(.headline)
                .foregroundStyle(Color.white.opacity(0.9))

            Spacer()

            Button(action: saveAndDismiss) {
                Text("Kaydet")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private func editingSurface(size: CGSize) -> some View {
        ZStack {
            if let uiImage = image {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .modifier(CanvasFrameReader(frame: $imageFrame))
                    .frame(maxWidth: size.width * 0.98, maxHeight: size.height * 0.9)
                    .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 12)
                    .transition(.opacity.combined(with: .scale))
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.6))
                    Text("Bir fotoğraf seç ve çizimine başla.")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.65))
                }
            }

            if image != nil, imageFrame.width > 0, imageFrame.height > 0 {
                PencilCanvasView(
                    drawing: $drawing,
                    canvasView: $canvasView,
                    inkType: selectedInkType,
                    selectedColor: selectedColor,
                    lineWidth: CGFloat(strokeWidth),
                    isEraserActive: isEraserActive
                ) { canUndo, canRedo in
                    self.canUndo = canUndo
                    self.canRedo = canRedo
                }
                .frame(width: imageFrame.width, height: imageFrame.height)
                .position(x: imageFrame.midX, y: imageFrame.midY)
                .clipped()
                .animation(.easeInOut(duration: 0.12), value: selectedInkType)
                .animation(.easeInOut(duration: 0.12), value: selectedColorId)
                .animation(.easeInOut(duration: 0.12), value: strokeWidth)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
    }

    private func bottomControls(bottomInset: CGFloat) -> some View {
        VStack(spacing: 16) {
            brushSelectionRow
            strokeSliderRow
            colorPaletteRow
            actionRow
        }
        .padding(.horizontal, 18)
        .padding(.top, 18)
        .padding(.bottom, max(bottomInset + 6, 22))
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 22, x: 0, y: 14)
    }

    private var brushSelectionRow: some View {
        HStack(spacing: 12) {
            BrushModeButton(
                icon: "scribble",
                title: "Kalem",
                isActive: !isEraserActive && selectedInkType == .pen
            ) {
                isEraserActive = false
                selectedInkType = .pen
            }

            BrushModeButton(
                icon: "highlighter",
                title: "Marker",
                isActive: !isEraserActive && selectedInkType == .marker
            ) {
                isEraserActive = false
                selectedInkType = .marker
            }

            BrushModeButton(
                icon: "pencil.tip",
                title: "İnce",
                isActive: !isEraserActive && selectedInkType == .monoline
            ) {
                isEraserActive = false
                selectedInkType = .monoline
            }

            BrushModeButton(
                icon: "eraser.fill",
                title: "Silgi",
                isActive: isEraserActive
            ) {
                isEraserActive.toggle()
            }
        }
    }

    private var strokeSliderRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "line.3.horizontal.decrease")
                .foregroundStyle(Color.white.opacity(0.7))

            Slider(value: $strokeWidth, in: minStrokeWidth...maxStrokeWidth)
                .tint(Color(uiColor: selectedColor))
                .onChange(of: strokeWidth) { _, _ in
                    isEraserActive = false
                }

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 38, height: 38)
                Circle()
                    .fill(Color(uiColor: selectedColor))
                    .frame(
                        width: CGFloat(max(min(strokeWidth + 6, 34), 10)),
                        height: CGFloat(max(min(strokeWidth + 6, 34), 10))
                    )
                    .shadow(color: Color(uiColor: selectedColor).opacity(0.5), radius: 6)
            }
        }
    }

    private var colorPaletteRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(palette) { entry in
                    ColorSwatch(
                        color: entry.color,
                        isSelected: entry.id == selectedColorId
                    ) {
                        selectedColorId = entry.id
                        isEraserActive = false
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 64)
    }

    private var actionRow: some View {
        HStack(spacing: 18) {
            ActionButton(
                icon: "arrow.uturn.backward",
                title: "Geri",
                isEnabled: canUndo
            ) {
                canvasView?.undoManager?.undo()
                refreshUndoRedoState()
            }

            ActionButton(
                icon: "arrow.uturn.forward",
                title: "İleri",
                isEnabled: canRedo
            ) {
                canvasView?.undoManager?.redo()
                refreshUndoRedoState()
            }

            ActionButton(
                icon: "trash",
                title: "Temizle",
                isEnabled: hasDrawing
            ) {
                drawing = PKDrawing()
                canvasView?.drawing = PKDrawing()
                refreshUndoRedoState()
            }
        }
    }

    private func refreshUndoRedoState() {
        guard let undoManager = canvasView?.undoManager else {
            canUndo = false
            canRedo = false
            return
        }

        canUndo = undoManager.canUndo
        canRedo = undoManager.canRedo
    }

    private func saveAndDismiss() {
        guard let baseImage = image else {
            dismiss()
            return
        }

        guard imageFrame.width > 0, imageFrame.height > 0 else {
            dismiss()
            return
        }

        let pixelWidth = baseImage.size.width * baseImage.scale
        let scaleFactor = pixelWidth > 0 ? pixelWidth / imageFrame.width : 1

        let inkImage = drawing.image(
            from: CGRect(origin: .zero, size: imageFrame.size),
            scale: scaleFactor
        )

        let format = UIGraphicsImageRendererFormat()
        format.scale = baseImage.scale
        format.opaque = false

        let renderer = UIGraphicsImageRenderer(size: baseImage.size, format: format)
        let composed = renderer.image { _ in
            baseImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
            inkImage.draw(in: CGRect(origin: .zero, size: baseImage.size))
        }

        image = composed
        dismiss()
    }
}

private struct PencilCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing
    @Binding var canvasView: PKCanvasView?
    let inkType: PKInkingTool.InkType
    let selectedColor: UIColor
    let lineWidth: CGFloat
    let isEraserActive: Bool
    var onUndoRedoChange: ((Bool, Bool) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> PKCanvasView {
        let view = PKCanvasView()
        view.backgroundColor = .clear
        view.isOpaque = false
        view.drawing = drawing
        view.delegate = context.coordinator
        view.allowsFingerDrawing = true
        view.isScrollEnabled = false
        view.alwaysBounceVertical = false
        view.alwaysBounceHorizontal = false
        view.tool = currentTool()

        DispatchQueue.main.async {
            canvasView = view
            reportUndoRedoState(for: view)
        }

        return view
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if uiView.drawing != drawing {
            uiView.drawing = drawing
        }

        uiView.tool = currentTool()
    }

    private func currentTool() -> PKTool {
        if isEraserActive {
            return PKEraserTool(.bitmap)
        }
        return PKInkingTool(inkType, color: selectedColor, width: lineWidth)
    }

    private func reportUndoRedoState(for canvas: PKCanvasView) {
        let undoManager = canvas.undoManager
        let canUndo = undoManager?.canUndo ?? false
        let canRedo = undoManager?.canRedo ?? false
        onUndoRedoChange?(canUndo, canRedo)
    }

    final class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilCanvasView

        init(_ parent: PencilCanvasView) {
            self.parent = parent
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.drawing = canvasView.drawing
            parent.reportUndoRedoState(for: canvasView)
        }

        func canvasViewDidEndUsingTool(_ canvasView: PKCanvasView) {
            parent.reportUndoRedoState(for: canvasView)
        }
    }
}

private struct BrushModeButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
                Text(title)
                    .font(.caption2)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .foregroundColor(isActive ? .black : .white.opacity(0.72))
            .background(
                Group {
                    if isActive {
                        LinearGradient(
                            colors: [Color.white, Color.white.opacity(0.75)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.12)
                    }
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: isActive ? Color.white.opacity(0.35) : .clear, radius: 10, x: 0, y: 6)
        }
        .buttonStyle(.plain)
    }
}

private struct ColorSwatch: View {
    let color: UIColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(uiColor: color))
                .frame(width: 34, height: 34)
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(isSelected ? 1 : 0.4), lineWidth: isSelected ? 3 : 1)
                )
                .shadow(color: Color(uiColor: color).opacity(isSelected ? 0.55 : 0.25), radius: isSelected ? 10 : 4)
                .scaleEffect(isSelected ? 1.15 : 1)
                .animation(.spring(response: 0.25, dampingFraction: 0.7, blendDuration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

private struct ActionButton: View {
    let icon: String
    let title: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .foregroundColor(isEnabled ? .white : .white.opacity(0.35))
            .background(Color.white.opacity(isEnabled ? 0.18 : 0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct CanvasFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next.width > 0 && next.height > 0 {
            value = next
        }
    }
}

private struct CanvasFrameReader: ViewModifier {
    @Binding var frame: CGRect

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: CanvasFramePreferenceKey.self,
                            value: proxy.frame(in: .named("canvas"))
                        )
                }
            )
            .onPreferenceChange(CanvasFramePreferenceKey.self) { newValue in
                if newValue.width > 0, newValue.height > 0 {
                    frame = newValue
                }
            }
    }
}

private struct PaletteEntry: Identifiable, Equatable {
    let id: String
    let color: UIColor

    static func == (lhs: PaletteEntry, rhs: PaletteEntry) -> Bool {
        lhs.id == rhs.id
    }

    static let presets: [PaletteEntry] = [
        PaletteEntry(id: "white", color: .white),
        PaletteEntry(id: "yellow", color: UIColor(red: 1.0, green: 0.945, blue: 0.0, alpha: 1.0)),
        PaletteEntry(id: "orange", color: UIColor(red: 1.0, green: 0.623, blue: 0.0, alpha: 1.0)),
        PaletteEntry(id: "red", color: UIColor(red: 0.981, green: 0.278, blue: 0.333, alpha: 1.0)),
        PaletteEntry(id: "pink", color: UIColor(red: 1.0, green: 0.27, blue: 0.576, alpha: 1.0)),
        PaletteEntry(id: "purple", color: UIColor(red: 0.596, green: 0.313, blue: 0.934, alpha: 1.0)),
        PaletteEntry(id: "blue", color: UIColor(red: 0.266, green: 0.478, blue: 0.996, alpha: 1.0)),
        PaletteEntry(id: "cyan", color: UIColor(red: 0.0, green: 0.757, blue: 0.949, alpha: 1.0)),
        PaletteEntry(id: "green", color: UIColor(red: 0.356, green: 0.839, blue: 0.39, alpha: 1.0)),
        PaletteEntry(id: "black", color: .black)
    ]
}
