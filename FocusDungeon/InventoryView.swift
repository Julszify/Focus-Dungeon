import DungeonCore
import SwiftUI

struct InventoryView: View {
    @Environment(GameStore.self) private var store

    private var backpack: [Item] {
        store.hero.inventory.sorted { ($0.rarity, $0.power) > ($1.rarity, $1.power) }
    }

    var body: some View {
        List {
            Section("Angelegt") {
                ForEach(ItemSlot.allCases, id: \.self) { slot in
                    if let item = store.hero.equipped(in: slot) {
                        ItemRow(item: item, equipped: true)
                    } else {
                        Label("\(slot == .trinket ? "Kein" : "Keine") \(slot.displayName)", systemImage: "circle.dashed")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                if backpack.isEmpty {
                    Text("Noch leer. Im Dungeon wartet Beute!")
                        .foregroundStyle(.secondary)
                }
                ForEach(backpack) { item in
                    Button {
                        store.equip(item)
                    } label: {
                        ItemRow(item: item)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Rucksack (\(backpack.count))")
            } footer: {
                Text("Tippe auf einen Gegenstand, um ihn anzulegen. Waffen erhöhen den Angriff, Rüstungen die Verteidigung und Leben, Talismane dein Glück bei Gold und Beute.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Inventar")
    }
}
