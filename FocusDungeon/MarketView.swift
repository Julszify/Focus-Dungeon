import DungeonCore
import SwiftUI

/// The tavern market: merchant for potions and chests, forge for upgrading gear.
struct MarketView: View {
    @Environment(GameStore.self) private var store
    @State private var openedChest: Item?
    @State private var errorMessage: String?
    @State private var trades = 0

    private var hero: Hero { store.hero }

    var body: some View {
        List {
            Section {
                HStack {
                    Text("🪙 \(hero.gold) Gold")
                        .font(Theme.title(20))
                        .foregroundStyle(Theme.gold)
                        .contentTransition(.numericText())
                    Spacer()
                    Text("🧪 \(hero.potions)/\(Market.maxPotions)")
                        .font(.headline.monospacedDigit())
                }
            }

            Section {
                offer(
                    icon: "🧪", title: "Heiltrank",
                    detail: "Rettet deinen Helden im Kampf vor dem K.o. Wird automatisch getrunken.",
                    price: Market.potionPrice(for: hero),
                    disabledReason: hero.potions >= Market.maxPotions ? "Rucksack voll" : nil
                ) {
                    trade { try $0.buyPotion() }
                }
                offer(
                    icon: "🎁", title: "Beutetruhe",
                    detail: "Ein zufälliger Gegenstand. Je tiefer dein Checkpoint, desto besser die Beute.",
                    price: Market.chestPrice(for: hero)
                ) {
                    if case .success(let item) = trade({ try $0.buyChest() }) {
                        openedChest = item
                    }
                }
            } header: {
                Text("Händler")
            }

            Section {
                let gear = ItemSlot.allCases.compactMap { hero.equipped(in: $0) }
                if gear.isEmpty {
                    Text("Leg zuerst Ausrüstung an, dann kann der Schmied sie verbessern.")
                        .foregroundStyle(.secondary)
                }
                ForEach(gear) { item in
                    forgeRow(item)
                }
            } header: {
                Text("Schmiede")
            } footer: {
                Text("Verbessert deine angelegte Ausrüstung bis +\(Market.maxUpgrades). Seltene Gegenstände gewinnen pro Stufe mehr. Alte Gegenstände verkaufst du im Inventar.")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Markt")
        .animation(.default, value: hero.gold)
        .sensoryFeedback(.success, trigger: trades)
        .alert("Die Truhe öffnet sich …", isPresented: .constant(openedChest != nil), presenting: openedChest) { _ in
            Button("Super!") { openedChest = nil }
        } message: { item in
            let equipped = hero.equipped(in: item.slot)?.id == item.id
            Text("\(item.displayName) (\(item.rarity.displayName), +\(item.power))\(equipped ? "\nDein Held hat ihn gleich angelegt." : "\nLiegt jetzt in deinem Rucksack.")")
        }
        .alert("Das klappt nicht", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func offer(icon: String, title: String, detail: String, price: Int,
                       disabledReason: String? = nil, buy: @escaping () -> Void) -> some View {
        HStack(spacing: 12) {
            Text(icon).font(.title)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            PriceButton(label: disabledReason ?? "\(price) 🪙", enabled: disabledReason == nil && hero.gold >= price, action: buy)
        }
    }

    private func forgeRow(_ item: Item) -> some View {
        VStack(alignment: .trailing, spacing: 8) {
            ItemRow(item: item, equipped: true)
            if let cost = Market.upgradeCost(for: item) {
                PriceButton(label: "Verbessern +\(Market.upgradeGain(for: item)) · \(cost) 🪙", enabled: hero.gold >= cost) {
                    trade { try $0.upgrade(itemID: item.id) }
                }
            } else {
                Text("Voll verbessert").font(.caption.weight(.bold)).foregroundStyle(Theme.torch)
            }
        }
    }

    @discardableResult
    private func trade<T>(_ action: (inout Hero) throws -> T) -> Result<T, MarketError> {
        let result = store.trade(action)
        switch result {
        case .success: trades += 1
        case .failure(let error): errorMessage = error.message
        }
        return result
    }
}

private struct PriceButton: View {
    let label: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.monospacedDigit().weight(.bold))
                .fixedSize()
        }
        .buttonStyle(.borderedProminent)
        .tint(Theme.torch)
        .foregroundStyle(.black)
        .disabled(!enabled)
    }
}

extension MarketError {
    var message: String {
        switch self {
        case .notEnoughGold: "Dafür reicht dein Gold noch nicht. Ab in den Dungeon!"
        case .potionsFull: "Mehr Heiltränke passen nicht in den Rucksack."
        case .fullyUpgraded: "Besser kann der Schmied diesen Gegenstand nicht machen."
        case .itemNotFound: "Diesen Gegenstand hat dein Held nicht mehr."
        }
    }
}
