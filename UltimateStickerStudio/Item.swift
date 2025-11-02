//
//  Item.swift
//  UltimateStickerStudio
//
//  Created by Anas Almasri on 2025-11-01.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
