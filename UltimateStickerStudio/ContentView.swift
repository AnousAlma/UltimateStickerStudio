import SwiftUI
import PhotosUI
import Foundation

let kAppGroupID = "group.com.AnasAlmasri.UltimateStickerStudio"
let kStickerDirectoryName = "GeneratedStickers"

struct ContentView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var originalImage: Image?
    @State private var uploadedUIImage: UIImage?
    @State private var editedUIImage: UIImage?
    @State private var showingStickerAlert: Bool = false
    @State private var stickerAlertMessage: String = ""
    
    @State private var showingAIEditor = false
    var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroupID)
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Create Sticker from Image") {
                    photoPickerView
                    imageDisplayView
                    actionButtonsView
                }
                
                navigationSection
            }
            .navigationTitle("Sticker Studio")
            .onChange(of: pickedItem) {
                handleImageSelection()
            }
            .alert("Sticker Studio", isPresented: $showingStickerAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(stickerAlertMessage)
            }
            .sheet(isPresented: $showingAIEditor) {
                aiEditorSheet
            }
        }
    }
    
    private var photoPickerView: some View {
        PhotosPicker(selection: $pickedItem, matching: .images) {
            Label("Select Photo", systemImage: "photo.on.rectangle.angled")
        }
    }
    
    private var imageDisplayView: some View {
        Group {
            if let originalImage = originalImage {
                VStack(spacing: 12) {
                    Text("Selected Image:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if let editedUIImage = editedUIImage {
                        comparisonView(originalImage: originalImage, editedImage: editedUIImage)
                    } else {
                        singleImageView(originalImage)
                    }
                }
            }
        }
    }
    
    private func comparisonView(originalImage: Image, editedImage: UIImage) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text("Original")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                originalImage
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(8)
            }
            
            VStack(spacing: 4) {
                Text("Edited")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Image(uiImage: editedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 120)
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.05))
        .cornerRadius(12)
    }
    
    private func singleImageView(_ image: Image) -> some View {
        image
            .resizable()
            .scaledToFit()
            .frame(height: 200)
            .cornerRadius(12)
            .shadow(radius: 3)
    }
    
    private var actionButtonsView: some View {
        Group {
            if let uploadedUIImage = uploadedUIImage {
                VStack(spacing: 16) {
                    Text("Ready to create sticker!")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    if let editedUIImage = editedUIImage {
                        editedImageButtons(originalImage: uploadedUIImage, editedImage: editedUIImage)
                    } else {
                        originalImageButtons(uploadedUIImage)
                    }
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    private func editedImageButtons(originalImage: UIImage, editedImage: UIImage) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Button("Save Original") {
                    saveSticker(originalImage, prefix: "original")
                }
                .buttonStyle(.bordered)
                
                Button("Save Edited") {
                    saveSticker(editedImage, prefix: "edited")
                }
                .buttonStyle(.borderedProminent)
            }
            
            HStack(spacing: 12) {
                Button("Edit Again") {
                    showingAIEditor = true
                }
                .buttonStyle(.bordered)
                
                Button("Reset to Original") {
                    editedUIImage = nil
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
    }
    
    private func originalImageButtons(_ image: UIImage) -> some View {
        HStack(spacing: 20) {
            Button("Save as Sticker") {
                saveSticker(image, prefix: "sticker")
            }
            .buttonStyle(.borderedProminent)
            
            Button("Edit Image") {
                showingAIEditor = true
            }
            .buttonStyle(.bordered)
        }
    }
    
    private var navigationSection: some View {
        Section {
            NavigationLink {
                StickerListView(sharedContainerURL: sharedContainerURL)
            } label: {
                Label("View Saved Stickers", systemImage: "folder.fill")
            }
        }
    }
    
    private var aiEditorSheet: some View {
        Group {
            if let currentImage = uploadedUIImage {
                NavigationView {
                    ImageEditorView(
                        originalImage: currentImage,
                        onEditComplete: { editedImage in
                            editedUIImage = editedImage
                            showingAIEditor = false
                        }
                    )
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") {
                                showingAIEditor = false
                            }
                        }
                    }
                }
            } else {
                VStack {
                    Text("No image available for editing")
                        .foregroundColor(.red)
                    Button("Close") {
                        showingAIEditor = false
                    }
                }
                .padding()
            }
        }
    }
    
    private func handleImageSelection() {
        Task {
            if let data = try? await pickedItem?.loadTransferable(type: Data.self) {
                if let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.originalImage = Image(uiImage: uiImage)
                        self.uploadedUIImage = uiImage.laundered()
                        self.editedUIImage = nil
                    }
                }
            }
        }
    }

    func saveSticker(_ uiImage: UIImage, prefix: String) {
        guard let sharedContainerURL = sharedContainerURL else {
            stickerAlertMessage = "Error: Could not access shared storage. Did you set the App Group ID?"
            showingStickerAlert = true
            
            print("[MainApp] ERROR: 'sharedContainerURL' is nil.")
            print("   This means the App Group ID ('\(kAppGroupID)') in this file")
            print("   does not match the one in 'Signing & Capabilities' for the 'UltimateStickerStudio' target.")
            return
        }
        
        let stickerFolderPath = sharedContainerURL.appendingPathComponent(kStickerDirectoryName)
        
        do {
            try FileManager.default.createDirectory(at: stickerFolderPath, withIntermediateDirectories: true, attributes: nil)
            
            let filename = "\(prefix)-\(UUID().uuidString).png"
            let fileURL = stickerFolderPath.appendingPathComponent(filename)
            

            let optimizedImage = optimizeImageForSticker(uiImage)
            
            if let data = optimizedImage.pngData() {
                try data.write(to: fileURL)
                
                let fileSizeKB = data.count / 1024
                print("[MainApp] Sticker saved to: \(fileURL.path)")
                print("   File size: \(fileSizeKB) KB")
                
                stickerAlertMessage = "Sticker saved successfully! (\(fileSizeKB) KB)\nRun the 'StickerExtension' target to see it in iMessage."
                showingStickerAlert = true
                
            } else {
                stickerAlertMessage = "Error: Could not convert image to PNG."
                showingStickerAlert = true
            }
        } catch {
            stickerAlertMessage = "Error saving sticker: \(error.localizedDescription)"
            showingStickerAlert = true
            print("[MainApp] Error saving sticker: \(error)")
        }
    }
    

    func optimizeImageForSticker(_ image: UIImage) -> UIImage {
        let maxDimension: CGFloat = 618
        let maxFileSize = 500_000
        let originalSize = image.size
        print("[MainApp] Original image size: \(originalSize.width)x\(originalSize.height)")
        

        var newSize = originalSize
        if originalSize.width > maxDimension || originalSize.height > maxDimension {
            let aspectRatio = originalSize.width / originalSize.height
            if originalSize.width > originalSize.height {
                newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
            } else {
                newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
            }
            print("[MainApp] Resizing to: \(newSize.width)x\(newSize.height)")
        }
        

        let renderer = UIGraphicsImageRenderer(size: newSize)
        let resizedImage = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
        

        if let pngData = resizedImage.pngData() {
            let fileSize = pngData.count
            print("[MainApp] Optimized file size: \(fileSize / 1024) KB")
            
            if fileSize > maxFileSize {
                print("[MainApp] File still large, consider further compression")
            }
        }
        
        return resizedImage
    }
}



#Preview {
    ContentView()
}

