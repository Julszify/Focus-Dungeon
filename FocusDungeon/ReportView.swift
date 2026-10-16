import DungeonCore
import SwiftUI

struct ReportView: View {
    @Environment(GameStore.self) private var store
    let report: AdventureReport

    private var completed: Bool { report.outcome == .completed }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headline
                    rewards
                    if !report.items.isEmpty {
                        loot
                    }
                    if !report.events.isEmpty {
                        log
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Abenteuerbericht")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                Button {
                    store.dismissReport()
                } label: {
                    Text("Zurück in die Taverne 🍺")
                        .font(Theme.title(17))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.torch)
                .foregroundStyle(.black)
                .padding()
            }
        }
    }

    private var headline: some View {
        VStack(spacing: 8) {
            Text(completed ? "🏆" : "🏃").font(.system(size: 64))
            Text(completed ? "Erfolgreich zurückgekehrt!" : "Geflohen!")
                .font(Theme.title(24))
                .multilineTextAlignment(.center)
            Text("\(report.focusedMinutes) von \(report.plannedMinutes) Minuten · \(report.category.emoji) \(report.category.displayName)")
                .foregroundStyle(.secondary)
            if !completed {
                Text("Die Hälfte des Goldes und alle Fundstücke sind verloren.")
                    .font(.footnote)
                    .foregroundStyle(Theme.hp)
            }
        }
        .padding(.vertical, 8)
    }

    private var rewards: some View {
        Panel {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                row("🪜", "Tiefste Ebene", "\(report.floorReached)")
                row("⚔️", "Besiegte Gegner", "\(report.monstersDefeated)")
                if report.bossesDefeated > 0 {
                    row("👑", "Bosse", "\(report.bossesDefeated)")
                }
                row("🪙", "Gold", "+\(report.gold)")
                row("✨", "Erfahrung", "+\(report.xp) XP")
                if report.statGain > 0 {
                    row(report.category.emoji, report.stat.displayName, "+\(report.statGain)")
                }
                if report.levelsGained > 0 {
                    row("⬆️", "Stufenaufstieg", "Stufe \(store.hero.level)!")
                }
                if report.potionsUsed > 0 {
                    row("🧪", "Heiltränke getrunken", "\(report.potionsUsed)")
                }
            }
        }
    }

    private func row(_ icon: String, _ label: String, _ value: String) -> some View {
        GridRow {
            Text(icon)
            Text(label).foregroundStyle(.secondary)
            Text(value)
                .font(.body.monospacedDigit().weight(.bold))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var loot: some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Beute").font(Theme.title(16))
                ForEach(report.items) { item in
                    ItemRow(item: item, equipped: store.hero.equipped(in: item.slot)?.id == item.id)
                }
            }
        }
    }

    private var log: some View {
        Panel {
            DisclosureGroup("Das ganze Abenteuer (\(report.events.count) \(report.events.count == 1 ? "Eintrag" : "Einträge"))") {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(report.events) { event in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(event.minute)'")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 28, alignment: .trailing)
                            Text(event.kind.icon)
                            Text(event.text).font(.footnote)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .tint(.primary)
        }
    }
}

struct ItemRow: View {
    let item: Item
    var equipped = false

    var body: some View {
        HStack(spacing: 12) {
            Text(item.slot.symbol)
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(item.rarity.color.opacity(0.15), in: .rect(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(item.rarity.color.opacity(0.6)))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName).font(.headline).foregroundStyle(item.rarity.color)
                Text("\(item.rarity.displayName) · \(item.slot.displayName)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("+\(item.power)").font(.headline.monospacedDigit())
                if equipped {
                    Text("angelegt").font(.caption2).foregroundStyle(Theme.torch)
                }
            }
        }
    }
}
