import SwiftUI
import PencilKit
import Vision
struct ImageEditorView: View {
    let originalImage: UIImage
    let onEditComplete: ((UIImage) -> Void)?
    
    @State private var canvasView = PKCanvasView()
    @State private var editPrompt: String = ""
    @State private var isProcessing = false
    @State private var editedImage: UIImage?
    @State private var showingPromptSheet = false
    @State private var selectedMode: EditMode = .replace
    @State private var maskImage: UIImage?
    @State private var hasDrawing = false
    @State private var showComparison = false
    @Environment(\.dismiss) private var dismiss
    
    init(originalImage: UIImage, onEditComplete: ((UIImage) -> Void)? = nil) {
        self.originalImage = originalImage
        self.onEditComplete = onEditComplete
    }
    
    var body: some View {
        VStack {
            modeSelectionView
            imageDisplayView
            instructionsView
            Spacer()
            actionButtonsView
        }
        .navigationTitle("\(selectedMode.displayName) Editor")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupDrawingForMode(selectedMode)
        }
        .sheet(isPresented: $showingPromptSheet) {
            promptSheetView
        }
    }
    
    private var modeSelectionView: some View {
        VStack(spacing: 12) {
            Text("Choose Editing Mode")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack(spacing: 15) {
                ForEach([EditMode.remove, EditMode.add, EditMode.replace], id: \.self) { mode in
                    modeButton(for: mode)
                }
            }
            
            HStack {
                Spacer()
                Button("Clear Drawing") {
                    canvasView.drawing = PKDrawing()
                    hasDrawing = false
                }
                .font(.caption)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
        .padding(.horizontal)
    }
    
    private func modeButton(for mode: EditMode) -> some View {
        Button {
            selectedMode = mode
            setupDrawingForMode(mode)
        } label: {
            VStack(spacing: 6) {
                Image(systemName: mode.icon)
                    .font(.title2)
                    .foregroundColor(selectedMode == mode ? .white : .blue)
                Text(mode.displayName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(selectedMode == mode ? .white : .blue)
            }
            .frame(width: 80, height: 60)
            .background(selectedMode == mode ? Color.blue : Color.blue.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedMode == mode ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var imageDisplayView: some View {
        Group {
            if let editedImage = editedImage, showComparison {
                comparisonView(editedImage: editedImage)
            } else {
                singleImageView
            }
        }
        .padding()
    }
    
    private func comparisonView(editedImage: UIImage) -> some View {
        VStack(spacing: 12) {
            HStack {
                Button("Hide Comparison") {
                    showComparison = false
                }
                .font(.caption)
                .foregroundColor(.blue)
                Spacer()
            }
            
            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    Text("Original")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(uiImage: originalImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .background(Color.white)
                        .cornerRadius(8)
                }
                
                VStack(spacing: 4) {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Image(uiImage: editedImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .background(Color.white)
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    private var singleImageView: some View {
        VStack(spacing: 12) {
            HStack {
                Text(editedImage != nil ? "Edited Image:" : "Original Image:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if editedImage != nil {
                    Button("Compare") {
                        showComparison = true
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                Text("Size: \(Int(originalImage.size.width))×\(Int(originalImage.size.height))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            ZStack {
                Image(uiImage: editedImage ?? originalImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .background(Color.white)
                
                if editedImage == nil {
                    DrawingCanvasView(canvasView: $canvasView, hasDrawing: $hasDrawing)
                        .frame(maxHeight: 300)
                        .allowsHitTesting(true)
                }
            }
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
    }
    
    private var instructionsView: some View {
        VStack {
            Text("Circle or draw around the area you want to \(selectedMode.displayName.lowercased())")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Text("Tap for circles, draw for custom shapes - the area will be filled automatically")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if hasDrawing {
                Text("Area selected - ready to \(selectedMode.displayName.lowercased())")
                    .font(.caption2)
                    .foregroundColor(.green)
            } else {
                Text("Tap or draw on the image to select areas")
                    .font(.caption2)
                    .foregroundColor(.orange)
            }
        }
        .padding(.horizontal)
    }
    
    private var actionButtonsView: some View {
        HStack {
            if let editedImage = editedImage {
                Button("Edit Again") {
                    self.editedImage = nil
                    showComparison = false
                    canvasView.drawing = PKDrawing()
                    hasDrawing = false
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("Use This Image") {
                    onEditComplete?(editedImage)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Spacer()
                
                Button("Apply \(selectedMode.displayName)") {
                    showingPromptSheet = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasDrawing)
                .opacity(hasDrawing ? 1.0 : 0.6)
                
                Spacer()
            }
        }
        .padding()
    }
    
    private var promptSheetView: some View {
        NavigationView {
            EditPromptView(
                originalImage: originalImage,
                canvasView: canvasView,
                selectedMode: selectedMode,
                onEditComplete: { editedImg in
                    editedImage = editedImg
                    showingPromptSheet = false
                    showComparison = true
                    canvasView.drawing = PKDrawing()
                    hasDrawing = false
                }
            )
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        showingPromptSheet = false
                    }
                }
            }
        }
    }
    
    private func setupDrawingForMode(_ mode: EditMode) {
        let color: UIColor
        
        switch mode {
        case .remove:
            color = .systemRed.withAlphaComponent(0.6)
        case .add:
            color = .systemGreen.withAlphaComponent(0.6)
        case .replace:
            color = .systemBlue.withAlphaComponent(0.6)
        }
        
        let ink = PKInk(.marker, color: color)
        canvasView.tool = PKInkingTool(ink: ink, width: 30)
    }
}


struct DrawingCanvasView: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    @Binding var hasDrawing: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.drawingPolicy = .anyInput
        
        let ink = PKInk(.marker, color: .systemBlue.withAlphaComponent(0.6))
        canvasView.tool = PKInkingTool(ink: ink, width: 30)
        canvasView.isUserInteractionEnabled = true
        canvasView.delegate = context.coordinator
        
        return canvasView
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = true
        hasDrawing = !uiView.drawing.strokes.isEmpty
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        let parent: DrawingCanvasView
        
        init(_ parent: DrawingCanvasView) {
            self.parent = parent
        }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            parent.hasDrawing = !canvasView.drawing.strokes.isEmpty
        }
    }
}

struct EditPromptView: View {
    let originalImage: UIImage
    let canvasView: PKCanvasView
    let selectedMode: EditMode
    let onEditComplete: (UIImage) -> Void
    
    @State private var editPrompt: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    var quickPrompts: [String] {
        switch selectedMode {
        case .remove:
            return [
                "Remove background",
                "Remove this object",
                "Remove person",
                "Remove text",
                "Remove watermark",
                "Remove shadows"
            ]
        case .add:
            return [
                "Add flowers",
                "Add sparkles",
                "Add fire effect",
                "Add rainbow",
                "Add snow",
                "Add sunlight"
            ]
        case .replace:
            return [
                "Make it cartoon style",
                "Change to winter scene",
                "Turn into painting",
                "Make it vintage",
                "Change color to blue",
                "Make it futuristic"
            ]
        }
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: selectedMode.icon)
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("\(selectedMode.displayName) Mode")
                        .font(.headline)
                        .fontWeight(.medium)
                }
                
                Text(selectedMode.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.top)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 10) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) {
                        editPrompt = prompt
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(editPrompt == prompt ? Color.blue.opacity(0.3) : Color.blue.opacity(0.1))
                    .cornerRadius(8)
                    .font(.caption)
                    .foregroundColor(editPrompt == prompt ? .blue : .primary)
                }
            }
            .padding(.horizontal)
                

            VStack(alignment: .leading) {
                Text("Or describe what you want:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                TextField(placeholderText, text: $editPrompt)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
            }
            .padding(.horizontal)
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Action Buttons
                HStack {
                    Spacer()
                    
                    Button {
                        processAIEdit()
                    } label: {
                        if isProcessing {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Processing...")
                            }
                        } else {
                            Text("Apply \(selectedMode.displayName)")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(editPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    
                    Spacer()
                }
                .padding()
        }
        .navigationTitle("\(selectedMode.displayName) Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    var placeholderText: String {
        switch selectedMode {
        case .remove:
            return "e.g., 'background', 'person', 'text'"
        case .add:
            return "e.g., 'flowers', 'sparkles', 'rainbow'"
        case .replace:
            return "e.g., 'cartoon style', 'winter scene', 'painting'"
        }
    }
    
    private func processAIEdit() {
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                let maskImage = try await createMaskFromDrawing()
                let editedImage = try await performEdit(
                    originalImage: originalImage,
                    maskImage: maskImage,
                    prompt: editPrompt,
                    mode: selectedMode
                )
                
                await MainActor.run {
                    canvasView.drawing = PKDrawing()
                    onEditComplete(editedImage)
                    isProcessing = false
                }
                
            } catch {
                await MainActor.run {
                    errorMessage = "Processing failed: \(error.localizedDescription)"
                    isProcessing = false
                }
            }
        }
    }
    
    private func createMaskFromDrawing() async throws -> UIImage {
        return await withCheckedContinuation { continuation in
            let drawing = canvasView.drawing
            let bounds = originalImage.size
            
            let renderer = UIGraphicsImageRenderer(size: bounds)
            let maskImage = renderer.image { context in
                let cgContext = context.cgContext
                
                cgContext.setFillColor(UIColor.black.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: bounds))
                let canvasSize = canvasView.bounds.size
                guard canvasSize.width > 0 && canvasSize.height > 0 else {
                    continuation.resume(returning: UIImage())
                    return
                }
                
                let scaleX = bounds.width / canvasSize.width
                let scaleY = bounds.height / canvasSize.height
                
                cgContext.saveGState()
                cgContext.scaleBy(x: scaleX, y: scaleY)
                cgContext.setFillColor(UIColor.white.cgColor)
                for stroke in drawing.strokes {
                    let strokePath = stroke.path
                    let interpolatedPoints = strokePath.interpolatedPoints(by: .parametricStep(0.5))
                    let pointsArray = Array(interpolatedPoints)
                    
                    if pointsArray.count == 1 {
                        let point = pointsArray[0].location
                        let radius: CGFloat = 25
                        let circleRect = CGRect(
                            x: point.x - radius,
                            y: point.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )
                        cgContext.fillEllipse(in: circleRect)
                    } else if pointsArray.count > 1 {
                        let bezierPath = UIBezierPath()
                        for (index, point) in pointsArray.enumerated() {
                            let location = point.location
                            if index == 0 {
                                bezierPath.move(to: location)
                            } else {
                                bezierPath.addLine(to: location)
                            }
                            let radius: CGFloat = 20
                            let circleRect = CGRect(
                                x: location.x - radius,
                                y: location.y - radius,
                                width: radius * 2,
                                height: radius * 2
                            )
                            cgContext.fillEllipse(in: circleRect)
                        }
                        bezierPath.close()
                        cgContext.addPath(bezierPath.cgPath)
                        cgContext.fillPath()
                    }
                }
                
                cgContext.restoreGState()
            }
            
            continuation.resume(returning: maskImage)
        }
    }
    
    private func performEdit(originalImage: UIImage, maskImage: UIImage, prompt: String, mode: EditMode) async throws -> UIImage {
        return try await ImageProcessor.editImage(
            originalImage: originalImage,
            maskImage: maskImage,
            prompt: prompt,
            mode: mode
        )
    }
}


