import SwiftUI


struct StickerListView: View {
    let sharedContainerURL: URL?
    @State private var stickers: [URL] = []
    @State private var showingAIEditor = false
    @State private var selectedStickerForEditing: UIImage?
    @State private var selectedStickerURL: URL?
    @State private var showingEditOptions = false
    @State private var editedStickerImage: UIImage?
    @State private var debugMessage = ""
    
    var stickerDirectoryURL: URL? {
        sharedContainerURL?.appendingPathComponent(kStickerDirectoryName)
    }
    
    var body: some View {
        Group {
            if stickers.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                    
                    Text("No stickers yet")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Create your first sticker using the main app, then come back here to edit them!")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Tap the wand icon to edit any sticker")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(stickers.count) stickers")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120))], spacing: 15) {
                            ForEach(stickers, id: \.self) { stickerURL in
                                if let uiImage = UIImage(contentsOfFile: stickerURL.path) {
                                    VStack(spacing: 8) {
                                        ZStack(alignment: .topLeading) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFit()
                                                .frame(width: 100, height: 100)
                                                .cornerRadius(8)
                                                .shadow(radius: 2)
                                            
                                            if stickerURL.lastPathComponent.contains("edited") {
                                                Image(systemName: "wand.and.stars.inverse")
                                                    .font(.caption2)
                                                    .foregroundColor(.white)
                                                    .background(Circle().fill(Color.purple))
                                                    .offset(x: -5, y: -5)
                                            }
                                        }
                                        
                                        HStack(spacing: 8) {
                                            Button {
                                                debugMessage = "Edit button tapped"
                                                selectedStickerForEditing = uiImage
                                                selectedStickerURL = stickerURL
                                                showingAIEditor = true
                                            } label: {
                                                Image(systemName: "wand.and.stars")
                                                    .font(.caption)
                                                    .foregroundColor(.blue)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                            
                                            Button {
                                                deleteSticker(at: stickerURL)
                                            } label: {
                                                Image(systemName: "trash")
                                                    .font(.caption)
                                                    .foregroundColor(.red)
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.mini)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle("Your Stickers")
        .onAppear(perform: loadStickers)
        .overlay(alignment: .bottom) {
            if !debugMessage.isEmpty {
                Text(debugMessage)
                    .font(.caption)
                    .padding(8)
                    .background(Color.green.opacity(0.8))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .padding()
            }
        }
        .sheet(isPresented: $showingAIEditor) {
            if let selectedStickerForEditing = selectedStickerForEditing {
                NavigationView {
                    ImageEditorView(
                        originalImage: selectedStickerForEditing,
                        onEditComplete: { editedImage in
                            editedStickerImage = editedImage
                            showingAIEditor = false
                            showingEditOptions = true
                        }
                    )
                    .onAppear {
                        debugMessage = "Editor opened successfully"
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAIEditor = false
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog("Save Edited Sticker", isPresented: $showingEditOptions) {
            Button("Save as New Sticker") {
                if let editedImage = editedStickerImage {
                    saveEditedSticker(editedImage)
                }
            }
            
            Button("Replace Original") {
                if let editedImage = editedStickerImage,
                   let originalURL = selectedStickerURL {
                    replaceOriginalSticker(with: editedImage, at: originalURL)
                }
            }
            
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How would you like to save your edited sticker?")
        }
    }
    
    func loadStickers() {
        guard let stickerDirectoryURL = stickerDirectoryURL else { return }
        do {
            let files = try FileManager.default.contentsOfDirectory(at: stickerDirectoryURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            stickers = files.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Error loading stickers: \(error)")
            stickers = []
        }
    }
    
    func deleteSticker(at url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            loadStickers()
        } catch {
            print("Error deleting sticker: \(error)")
        }
    }
    
    func saveEditedSticker(_ editedImage: UIImage) {
        guard let stickerDirectoryURL = stickerDirectoryURL else { return }
        
        do {
            let timestamp = DateFormatter().string(from: Date()).replacingOccurrences(of: " ", with: "-")
            let filename = "edited-\(timestamp)-\(UUID().uuidString).png"
            let fileURL = stickerDirectoryURL.appendingPathComponent(filename)
            
            let optimizedImage = optimizeImageForSticker(editedImage)
            
            if let data = optimizedImage.pngData() {
                try data.write(to: fileURL)
                print("Edited sticker saved: \(filename)")
                loadStickers()
            }
        } catch {
            print("Error saving edited sticker: \(error)")
        }
    }
    
    func optimizeImageForSticker(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 618
        let originalSize = image.size
        var newSize = originalSize
        
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let aspectRatio = originalSize.width / originalSize.height
            if originalSize.width > originalSize.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
        }
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        
        return resizedImage
    }
    
    func replaceOriginalSticker(with editedImage: UIImage, at originalURL: URL) {
        do {
            let optimizedImage = optimizeImageForSticker(editedImage)
            
            if let data = optimizedImage.pngData() {
                try data.write(to: originalURL)
                print("Original sticker replaced: \(originalURL.lastPathComponent)")
                loadStickers()
            }
        } catch {
            print("Error replacing original sticker: \(error)")
        }
    }
}
