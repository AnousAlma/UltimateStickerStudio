import SwiftUI
import PhotosUI
import Foundation

let kAppGroupID = "group.com.AnasAlmasri.UltimateStickerStudio"
let kStickerDirectoryName = "GeneratedStickers"

struct ContentView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var originalImage: Image?
    @State private var uploadedUIImage: UIImage?
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
                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("Select Photo", systemImage: "photo.on.rectangle.angled")
                    }
                    
                    if let originalImage {
                        VStack(spacing: 12) {
                            Text("Selected Image:")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            originalImage
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(12)
                                .shadow(radius: 3)
                        }
                    }
                    
                    if let uploadedUIImage {
                        VStack(spacing: 16) {
                            Text("Ready to create sticker!")
                                .font(.headline)
                                .foregroundColor(.green)
                            
                            HStack(spacing: 20) {
                                Button("Save as Sticker") {
                                    saveSticker(uploadedUIImage, prefix: "sticker")
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button("Edit Image") {
                                    showingAIEditor = true
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                

                Section {
                    NavigationLink {
                        StickerListView(sharedContainerURL: sharedContainerURL)
                    } label: {
                        Label("View Saved Stickers", systemImage: "folder.fill")
                    }
                }
            }
            .navigationTitle("Sticker Studio")

            .onChange(of: pickedItem) {
                Task {
                    if let data = try? await pickedItem?.loadTransferable(type: Data.self) {
                        if let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                self.originalImage = Image(uiImage: uiImage)
                                self.uploadedUIImage = uiImage.laundered()
                            }
                        }
                    }
                }
            }
            .alert("Sticker Studio", isPresented: $showingStickerAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(stickerAlertMessage)
            }
            .sheet(isPresented: $showingAIEditor) {
                if let currentImage = uploadedUIImage {
                    NavigationView {
                        ImageEditorView(
                            originalImage: currentImage,
                            onEditComplete: { editedImage in
                                uploadedUIImage = editedImage
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

