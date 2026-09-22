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
            Group {
                if representable.nextThreeEvents().isEmpty {
                    TribuneruText(
                        content: "Calendar is empty.",
                        style: .vaporMeta,
                        color: .tribuneru(.vaporTextSecondary),
                        lineLimit: 2
                    )
                    .padding(12)
                    .background(Color.tribuneru(.vaporCardSurface))
                    .cornerRadius(8)
                } else {
                    VaporCard(spacing: 0) {
                        ForEach(representable.nextThreeEvents().indices, id: \.self) { idx in
                            let event = representable.nextThreeEvents()[idx]
                            HStack(spacing: 10) {
                                TribuneruText(
                                    content: event.date,
                                    style: .vaporETALine,
                                    color: .tribuneru(.vaporTextSecondary),
                                    lineLimit: 1
                                )
                                .frame(maxWidth: 84, alignment: .leading)

                                VaporFlagView(url: event.flagURL)

                                TribuneruText(
                                    content: event.race,
                                    style: .vaporRaceNameNext,
                                    color: .tribuneru(.vaporTextPrimary),
                                    lineLimit: 1
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)

                            if idx < representable.nextThreeEvents().count - 1 {
                                TribunerosDivider(height: 0.5, color: .tribuneru(.vaporTextSecondary).opacity(0.2))
                            }
                        }
                        VaporMoreInfoLink()
                            .padding(.top, 8)
                    }
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
