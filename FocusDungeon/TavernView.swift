import DungeonCore
import SwiftUI

/// Home screen: the hero resting in the tavern between adventures.
struct TavernView: View {
    @Environment(GameStore.self) private var store
    @State private var showSetup = false
    @State private var pendingStart: (category: FocusCategory, minutes: Int)?
    @State private var showRename = false
    @State private var newName = ""

    private var hero: Hero { store.hero }

    var body: some View {
        if store.session != nil || store.report != nil {
            AdventureFlowView()
                .transition(.opacity)
        } else {
            tavern
                .transition(.opacity)
        }
    }

    private var tavern: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    statsCard
                    descentCard
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Taverne")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        InventoryView()
                    } label: {
                        Label("Inventar", systemImage: "bag.fill")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    showSetup = true
                } label: {
                    Text("In den Dungeon ⚔️")
                        .font(Theme.title(18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.torch)
                .foregroundStyle(.black)
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        // Starting swaps this whole view for the dungeon, so wait until the sheet has fully closed;
        // swapping it out mid-dismissal leaves the sheet stuck on screen.
        .sheet(isPresented: $showSetup, onDismiss: {
            guard let start = pendingStart else { return }
            pendingStart = nil
            store.startSession(category: start.category, minutes: start.minutes)
        }) {
            SessionSetupView { category, minutes in
                pendingStart = (category, minutes)
            }
        }
        .alert("Wie heißt dein Held?", isPresented: $showRename) {
            TextField("Name", text: $newName)
            Button("Speichern") { store.rename(to: newName) }
            Button("Abbrechen", role: .cancel) {}
        }
    }

    private var heroCard: some View {
        Panel {
            HStack(spacing: 20) {
                PixelHero(heroClass: hero.heroClass, pixelSize: 7)
                    .padding(12)
                    .background(
                        RadialGradient(colors: [Theme.torch.opacity(0.35), .clear], center: .center, startRadius: 4, endRadius: 70)
                    )
                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        newName = hero.name
                        showRename = true
                    } label: {
                        HStack(spacing: 6) {
                            Text(hero.name).font(Theme.title(24))
                            Image(systemName: "pencil").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    Text("Stufe \(hero.level) · \(hero.heroClass.displayName)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(hero.heroClass.color.mix(with: .white, by: 0.3))
                    StatBar(value: hero.xp, max: Hero.xpNeeded(forLevel: hero.level), color: Theme.xp, height: 8)
                    Text("\(hero.xp) / \(Hero.xpNeeded(forLevel: hero.level)) XP")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    Text("🪙 \(hero.gold) Gold")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.gold)
                }
            }
        }
    }

    private var statsCard: some View {
        Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Werte").font(Theme.title(16))
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    ForEach(FocusCategory.allCases) { category in
                        GridRow {
                            Text(category.emoji)
                            Text(category.stat.displayName)
                            Text("\(hero.stats[category.stat])")
                                .font(.body.monospacedDigit().weight(.bold))
                                .gridColumnAlignment(.trailing)
                            Text("durch \(category.displayName)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Divider()
                HStack {
                    combatValue("❤️", "Leben", hero.maxHP)
                    combatValue("⚔️", "Angriff", hero.attack)
                    combatValue("🛡️", "Verteidigung", hero.defense)
                }
            }
        }
    }

    private func combatValue(_ icon: String, _ label: String, _ value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(icon) \(value)").font(.headline.monospacedDigit())
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var descentCard: some View {
        let boss = DungeonSimulator.nextBoss(from: hero.checkpointFloor)
        return Panel {
            VStack(alignment: .leading, spacing: 8) {
                Text("Nächster Abstieg").font(Theme.title(16))
                Label("Start auf Ebene \(hero.checkpointFloor)", systemImage: "stairs")
                Label("\(boss.name) wartet auf Ebene \(boss.floor)", systemImage: "crown")
                Text("Nach \(boss.minutes) Minuten Fokus stehst du vor dem Boss. Besiegst du ihn, startet deine nächste Session tiefer.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if hero.totalFocusMinutes > 0 {
                    Text("Gesamte Fokuszeit: \(formatMinutes(hero.totalFocusMinutes))")
                        .font(.caption.weight(.semibold))
                        .padding(.top, 4)
                }
            }
        }
    }
}

func formatMinutes(_ minutes: Int) -> String {
    minutes < 60 ? "\(minutes) Min." : "\(minutes / 60) Std. \(minutes % 60) Min."
}

#Preview {
    TavernView()
        .environment(GameStore())
        .preferredColorScheme(.dark)
}
