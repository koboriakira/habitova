//
//  Item.swift
//  Habitova
//
//  Created by Akira Kobori on 2025/12/21.
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
