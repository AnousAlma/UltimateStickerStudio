import SwiftUI

struct SimpleAIEditor: View {
    let originalImage: UIImage
    let onEditComplete: ((UIImage) -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Simple AI Editor Test")
                .font(.title2)
            
            Text("Image Size: \(Int(originalImage.size.width)) × \(Int(originalImage.size.height))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Image(uiImage: originalImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .border(Color.red, width: 2)
                .background(Color.yellow.opacity(0.2))
            
            Button("Test Complete") {
                onEditComplete?(originalImage)
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .navigationTitle("Test Editor")
    }
}