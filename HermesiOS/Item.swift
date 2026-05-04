//
//  Item.swift
//  HermesiOS
//
//  Created by Laurent Dubertrand on 04/05/2026.
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
