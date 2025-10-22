//
//  CostBadge.swift
//  Inkwell Keeper
//
//  Created by Brevin Blalock on 9/1/25.
//

import SwiftUI

struct CostBadge: View {
    let cost: Int
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "hexagon.fill")
                .font(.caption2)
            Text("\(cost)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .foregroundColor(.lorcanaGold)
    }
}
