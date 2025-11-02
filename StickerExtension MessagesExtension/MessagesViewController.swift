import UIKit
import Messages

class MessagesViewController: MSMessagesAppViewController, MSStickerBrowserViewDataSource {
    
    // Global App Group ID - must match the main app configuration
    let kAppGroupID = "group.com.AnasAlmasri.UltimateStickerStudio"
    let kStickerDirectoryName = "GeneratedStickers"
    
    var stickers: [MSSticker] = []
    var stickerBrowserViewController: MSStickerBrowserViewController?
    var lastLoadTime: Date?
    var cacheExpirationInterval: TimeInterval = 60 // Cache for 60 seconds
    
    // Path to the shared container directory
    var sharedContainerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: kAppGroupID)
    }
    
    var stickerDirectoryURL: URL? {
        sharedContainerURL?.appendingPathComponent(kStickerDirectoryName)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        print("[StickerExtension] viewDidLoad called")
        print("   View frame: \(view.frame)")
        print("   View bounds: \(view.bounds)")
        
        // Set a background color to verify the view is actually rendering
        view.backgroundColor = .systemBackground
        
        // Load stickers only once on initial load
        loadStickersIfNeeded()
        presentStickerBrowser()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("[StickerExtension] viewDidAppear called")
        print("   View frame: \(view.frame)")
        print("   View is in window: \(view.window != nil)")
        print("   Number of subviews: \(view.subviews.count)")
        print("   Presentation style: \(self.presentationStyle.rawValue)")
        
        if let browser = stickerBrowserViewController {
            print("   Browser view frame: \(browser.view.frame)")
            print("   Browser view superview: \(browser.view.superview != nil)")
            print("   Browser user interaction enabled: \(browser.view.isUserInteractionEnabled)")
            print("   Browser sticker view interaction enabled: \(browser.stickerBrowserView.isUserInteractionEnabled)")
            print("   Stickers count in array: \(stickers.count)")
            
            // Force reload the browser to display stickers
            print("[StickerExtension] Forcing browser reload in viewDidAppear")
            browser.stickerBrowserView.reloadData()
        }
    }
    
    // MARK: - Conversation Handling
    
    override func willBecomeActive(with conversation: MSConversation) {
        print("[StickerExtension] willBecomeActive called")
        
        // Only reload stickers if cache has expired
        loadStickersIfNeeded()
        
        // Force reload the sticker browser
        if let browser = stickerBrowserViewController {
            print("[StickerExtension] Reloading sticker browser data")
            browser.stickerBrowserView.reloadData()
        } else {
            print("[StickerExtension] WARNING: stickerBrowserViewController is nil!")
        }
    }
    
    // Load stickers only if cache has expired or no stickers loaded
    func loadStickersIfNeeded() {
        let now = Date()
        
        // Check if we need to reload
        if let lastLoad = lastLoadTime,
           now.timeIntervalSince(lastLoad) < cacheExpirationInterval,
           !stickers.isEmpty {
            print("[StickerExtension] Using cached stickers (\(stickers.count) stickers)")
            return
        }
        
        print("[StickerExtension] Cache expired or empty, loading stickers...")
        loadStickers()
        lastLoadTime = now
    }
    
    func loadStickers() {
        print("[StickerExtension] loadStickers() started")
        stickers.removeAll()
        
        // Check shared container URL
        if let sharedURL = sharedContainerURL {
            print("[StickerExtension] Shared container URL: \(sharedURL.path)")
        } else {
            print("[StickerExtension] ERROR: sharedContainerURL is nil!")
            print("   App Group ID: '\(kAppGroupID)'")
            return
        }
        
        // Check sticker directory URL
        guard let stickerDirectoryURL = stickerDirectoryURL else {
            print("[StickerExtension] ERROR: stickerDirectoryURL is nil.")
            print("   App Group ID: '\(kAppGroupID)'")
            print("   Directory name: '\(kStickerDirectoryName)'")
            return
        }
        
        print("[StickerExtension] Looking for stickers in: \(stickerDirectoryURL.path)")
        
        // Check if directory exists
        var isDirectory: ObjCBool = false
        let directoryExists = FileManager.default.fileExists(atPath: stickerDirectoryURL.path, isDirectory: &isDirectory)
        
        if !directoryExists {
            print("[StickerExtension] Directory does NOT exist yet: \(stickerDirectoryURL.path)")
            print("   The main app needs to create stickers first!")
            return
        }
        
        if !isDirectory.boolValue {
            print("[StickerExtension] Path exists but is NOT a directory!")
            return
        }
        
        print("[StickerExtension] Directory exists!")
        
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(at: stickerDirectoryURL, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: .skipsHiddenFiles)
            
            print("[StickerExtension] Total files in directory: \(fileURLs.count)")
            
            // List all files for debugging
            for (index, fileURL) in fileURLs.enumerated() {
                let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                print("   [\(index + 1)] \(fileURL.lastPathComponent) - \(fileSize ?? 0) bytes")
            }
            
            let stickerFiles = fileURLs.filter { $0.pathExtension.lowercased() == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
            
            print("[StickerExtension] Found \(stickerFiles.count) PNG sticker files")
            
            for (index, fileURL) in stickerFiles.enumerated() {
                do {
                    // Check if file is readable
                    guard FileManager.default.isReadableFile(atPath: fileURL.path) else {
                        print("[StickerExtension] File is not readable: \(fileURL.lastPathComponent)")
                        continue
                    }
                    
                    // Get file size to warn about large stickers
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        if fileSize > 500000 { // 500KB
                            print("[StickerExtension] Large sticker detected (\(fileSize) bytes): \(fileURL.lastPathComponent)")
                        }
                    }
                    
                    // Create sticker with proper description
                    let description = fileURL.deletingPathExtension().lastPathComponent
                    let sticker = try MSSticker(contentsOfFileURL: fileURL, localizedDescription: description)
                    stickers.append(sticker)
                    print("[StickerExtension] [\(index + 1)/\(stickerFiles.count)] Loaded: \(fileURL.lastPathComponent)")
                } catch {
                    print("[StickerExtension] Error creating MSSticker from \(fileURL.lastPathComponent): \(error)")
                }
            }
            print("[StickerExtension] Successfully loaded \(stickers.count) stickers into array")
        } catch {
            print("[StickerExtension] Error reading directory contents: \(error)")
        }
    }
    
    // Presents the sticker browser view controller
    func presentStickerBrowser() {
        print("[StickerExtension] presentStickerBrowser() called")
        
        // Only create the browser once
        guard stickerBrowserViewController == nil else {
            print("[StickerExtension] Browser already exists, skipping creation")
            return
        }
        
        print("[StickerExtension] Creating new MSStickerBrowserViewController")
        let browser = MSStickerBrowserViewController(stickerSize: .regular) // Use .regular, .small, or .large
        
        // Store the browser FIRST before setting data source
        stickerBrowserViewController = browser
        
        print("[StickerExtension] Adding browser as child view controller")
        addChild(browser)
        
        // Ensure the browser view is interactive
        browser.view.isUserInteractionEnabled = true
        browser.stickerBrowserView.isUserInteractionEnabled = true
        
        browser.view.frame = view.bounds // Make it fill the entire iMessage app view
        browser.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        browser.stickerBrowserView.backgroundColor = .systemBackground
        browser.view.backgroundColor = .systemBackground
        
        view.addSubview(browser.view)
        browser.didMove(toParent: self)
        
        print("[StickerExtension] Setting data source to self")
        browser.stickerBrowserView.dataSource = self // This class will provide the stickers
        
        // Try setting it again after a slight delay to ensure it sticks
        DispatchQueue.main.async {
            print("[StickerExtension] Re-setting data source (async)")
            browser.stickerBrowserView.dataSource = self
            
            // Verify the data source was set
            if browser.stickerBrowserView.dataSource != nil {
                print("[StickerExtension] Data source successfully set (async)")
            } else {
                print("[StickerExtension] WARNING: Data source is STILL nil (async)!")
            }
            
            // Reload data after ensuring data source is set
            print("[StickerExtension] Reloading data (async)")
            browser.stickerBrowserView.reloadData()
        }
        
        // Verify the data source was set
        if browser.stickerBrowserView.dataSource != nil {
            print("[StickerExtension] Data source successfully set")
        } else {
            print("[StickerExtension] WARNING: Data source is STILL nil!")
        }
        
        print("[StickerExtension] Browser setup complete. View frame: \(browser.view.frame)")
        
        // Force layout to ensure the browser is properly displayed
        browser.view.setNeedsLayout()
        browser.view.layoutIfNeeded()
        
        // Reload data to trigger the data source methods
        print("[StickerExtension] Initial browser.reloadData() call")
        browser.stickerBrowserView.reloadData()
        
        print("[StickerExtension] Current stickers count: \(stickers.count)")
    }
    
    // MARK: - MSStickerBrowserViewDataSource
    
    func numberOfStickers(in stickerBrowserView: MSStickerBrowserView) -> Int {
        print("[StickerExtension] numberOfStickers called, returning: \(stickers.count)")
        return stickers.count
    }
    
    func stickerBrowserView(_ stickerBrowserView: MSStickerBrowserView, stickerAt index: Int) -> MSSticker {
        print("[StickerExtension] Returning sticker at index: \(index)")
        return stickers[index]
    }
}
