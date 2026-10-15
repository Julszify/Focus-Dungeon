import DungeonCore
import SwiftUI

struct SessionSetupView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    /// Called with the choice; the caller starts the session once this sheet is gone.
    let onStart: (FocusCategory, Int) -> Void
    @AppStorage("lastCategory") private var category: FocusCategory = .work
    @AppStorage("lastMinutes") private var minutes = 25

    #if DEBUG
    // Short sessions to try the full loop without waiting.
    private static let durations = [1, 2, 15, 25, 45, 60, 90]
    #else
    private static let durations = [15, 25, 45, 60, 90]
    #endif

    var body: some View {
        let checkpoint = store.hero.checkpointFloor
        let boss = DungeonSimulator.nextBoss(from: checkpoint)

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Woran arbeitest du?").font(Theme.title(16))
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(FocusCategory.allCases) { option in
                            categoryButton(option)
                        }
                    }

                    Text("Wie lange?").font(Theme.title(16))
                    HStack(spacing: 8) {
                        ForEach(Self.durations, id: \.self) { option in
                            Button {
                                minutes = option
                            } label: {
                                Text("\(option)")
                                    .font(.headline.monospacedDigit())
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .background(option == minutes ? Theme.torch : Theme.panel, in: .rect(cornerRadius: 10))
                                    .foregroundStyle(option == minutes ? .black : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    Text("Minuten").font(.caption).foregroundStyle(.secondary)

                    Panel {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Dein Held erreicht Ebene \(DungeonSimulator.floorReached(from: checkpoint, minutes: minutes)).")
                                .font(.headline)
                            if minutes >= boss.minutes {
                                Text("👑 Bosskampf gegen \(boss.name)!")
                                    .foregroundStyle(Theme.torch)
                            } else {
                                Text("Für den Boss (\(boss.name)) brauchst du \(boss.minutes) Minuten.")
                                    .foregroundStyle(.secondary)
                            }
                            Text("Verlässt du die App länger als \(Int(FocusSession.gracePeriod)) Sekunden, flieht dein Held. Das Display sperren ist erlaubt.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Abenteuer planen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    onStart(category, minutes)
                    dismiss()
                } label: {
                    Text("Abstieg beginnen")
                        .font(Theme.title(18))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.torch)
                .foregroundStyle(.black)
                .padding()
            }
        }
        .presentationDetents([.large])
    }

    private func categoryButton(_ option: FocusCategory) -> some View {
        let selected = option == category
        return Button {
            category = option
        } label: {
            VStack(spacing: 6) {
                Text(option.emoji).font(.largeTitle)
                Text(option.displayName).font(.headline)
                Text("+ \(option.stat.displayName)").font(.caption).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 110)
            .background(Theme.panel, in: .rect(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(selected ? Theme.torch : Theme.panelBorder, lineWidth: selected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}
