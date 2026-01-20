//
//  ContentView.swift
//  Tribuneros
//
//  Created by albert vila on 18/2/25.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        TribuneruText(
                            content: "Item at \(item.timestamp.formatted(Date.FormatStyle(date: .numeric, time: .standard)))",
                            style: .size14WeightRegular
                        )
                        .font(.body)
                    } label: {
                        TribuneruText(
                            content: item.timestamp.formatted(Date.FormatStyle(date: .numeric, time: .standard)),
                            style: .size14WeightRegular
                        )
                        .font(.body)
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            TribuneruText(content: "Select an item", style: .size14WeightRegular)
                .font(.body)
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}
