//
//  Item.swift
//  Tribuneros
//
//  Created by albert vila on 18/2/25.
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
