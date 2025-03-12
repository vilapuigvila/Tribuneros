//
//  EmptyResultsCardView.swift
//  Tribuneros
//
//  Created by albert vila on 12/3/25.
//

import SwiftUI

struct EmptyResultsCardView: View {
    let title: String
    let info: String
    
    var body: some View {
        VStack {
            HStack {
                Text(title)
                    .font(.system(size: 16, weight: .bold, design: .default))
                    .padding(.top, 12)
                    .padding(.horizontal, 8)
                Spacer()
            }
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.top, 12)
            
            Spacer()
            
            Text(info)
                .font(.system(size: 14, weight: .light, design: .monospaced))
                .padding(.top, 12)
                .padding(.horizontal, 8)
            
            Spacer()
        }
    }
}

#Preview {
    VStack {
        EmptyResultsCardView(
            title: "Results today",
            info: "No results found for your search"
        )
        .background(.blue.opacity(0.5))
        .cornerRadius(8)
    }
    .frame(height: 140)
}
