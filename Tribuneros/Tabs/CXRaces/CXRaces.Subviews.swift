//
//  CXRaces.Subviews.swift
//  Tribuneros
//
//  Created by albert vila on 6/1/26.
//

import Foundation
import SwiftUI

extension CXRaces {
    
    // MARK: - CalendarView -
    
    struct CalendarView: View {
        let representable: CXRaces.Representable
        let action: () -> Void
        
        var body: some View {
            VStack(alignment: .leading) {
                TribuneruText(content: "Next races", style: .size20WeightBold)
                    .padding(.bottom, 12)
                
                if representable.nextThreeEvents().isEmpty {
                    TribuneruText(content: "Calendar is empty.", style: .size14WeightRegular, color: .gray, lineLimit: 2)
                        .padding(12)
                        .background(Color.tribuneru(.greenCardBackground))
                        .cornerRadius(8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(representable.nextThreeEvents().indices, id: \.self) { idx in
                            let event = representable.nextThreeEvents()[idx]
                            HStack(spacing: 10) {
                                TribuneruText(
                                    content: event.date,
                                    style: .size12WeightRegular,
                                    color: .gray,
                                    lineLimit: 1
                                )
                                .frame(maxWidth: 84, alignment: .leading)
                                
                                CachedImageView(
                                    imageUrl: event.flagURL,
                                    cornerRadius: 1
                                )
                                .frame(width: 16, height: 16)
                                
                                TribuneruText(
                                    content: event.race,
                                    style: .size14WeightRegular
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 12)
                            
                            if idx < representable.nextThreeEvents().count - 1 {
                                TribunerosDivider(height: 0.5, color: .gray.opacity(0.2))
                                    .padding(.leading, 12)
                            }
                        }
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            TribuneruText(content: "more info..", style: .size12WeightRegular, color: .cyan, lineLimit: 1)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.cyan)
                        }
                        .padding(.vertical, 8)
                        .padding(.trailing, 10)
                    }
                    .background(Color.tribuneru(.greenCardBackground))
                    .cornerRadius(8)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        action()
                    }
                }
            }
        }
    }
}

#if DEBUG



#endif
