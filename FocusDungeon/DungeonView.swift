import DungeonCore
import SwiftUI

/// Shows the running dungeon, then the report once the session ends.
struct AdventureFlowView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if let finale = store.finale {
            FinaleView(finale: finale)
        } else if let report = store.report {
            ReportView(report: report)
        } else {
            DungeonView()
        }
    }
}

/// The final room after time is up; it hands over to the report by itself.
private struct FinaleView: View {
    @Environment(GameStore.self) private var store
    let finale: GameStore.Finale

    var body: some View {
        VStack(spacing: 20) {
            Text("🏁 Ein letzter Raum …")
                .font(Theme.title(18))
                .padding(.top, 40)
            DungeonScene(session: finale.session, events: finale.events, heroClass: finale.heroClass,
                         startHP: finale.startHP, clock: .continuing)
                .frame(height: 250)
            if let last = finale.events.last {
                HStack(alignment: .top, spacing: 10) {
                    Text(last.kind.icon)
                    Text(last.text)
                }
                .font(.callout.weight(.semibold))
            }
            Spacer()
            Button("Zum Abenteuerbericht") { store.endFinale() }
                .buttonStyle(.bordered)
                .tint(.secondary)
        }
        .padding()
        .background(Theme.background)
        .task {
            try? await Task.sleep(for: .seconds(max(0, finale.until.timeIntervalSinceNow)))
            store.endFinale()
        }
    }
}

struct DungeonView: View {
    @Environment(GameStore.self) private var store
    @State private var confirmFlee = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            if let session = store.session, let run = store.run {
                content(session: session, run: run, now: context.date)
            }
        }
        .background(Theme.background)
        .task {
            while !Task.isCancelled {
                store.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        .confirmationDialog("Wirklich fliehen?", isPresented: $confirmFlee, titleVisibility: .visible) {
            Button("Fliehen", role: .destructive) { store.flee() }
            Button("Weiterkämpfen", role: .cancel) {}
        } message: {
            Text("Dein Held behält die Erfahrung, aber nur die Hälfte des Goldes und keine Fundstücke.")
        }
    }

    @ViewBuilder
    private func content(session: FocusSession, run: DungeonRun, now: Date) -> some View {
        let hero = store.hero
        let minute = session.focusedMinutes(at: now)
        let events = run.events(upToMinute: minute)
        let latest = events.last
        let floor = latest?.floor ?? hero.checkpointFloor
        let elapsed = Int(session.elapsed(at: now))
        let secondsToNextRoom = 60 - elapsed % 60

        VStack(spacing: 20) {
            header(session: session, floor: floor, now: now)

            DungeonScene(session: session, events: events, heroClass: hero.heroClass, startHP: hero.maxHP)
                .frame(height: 250)

            VStack(spacing: 6) {
                HStack {
                    Text("❤️ \(latest?.hpAfter ?? hero.maxHP) / \(latest?.maxHP ?? hero.maxHP)")
                    Spacer()
                    Text("Nächster Raum in \(secondsToNextRoom) s")
                        .foregroundStyle(.secondary)
                }
                .font(.caption.monospacedDigit())
                StatBar(value: latest?.hpAfter ?? hero.maxHP, max: latest?.maxHP ?? hero.maxHP, color: Theme.hp)
            }

            eventLog(events)

            Button {
                confirmFlee = true
            } label: {
                Text("Fliehen 🏃")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.secondary)
        }
        .padding()
    }

    private func header(session: FocusSession, floor: Int, now: Date) -> some View {
        let remaining = Int(session.remaining(at: now).rounded(.up))
        return VStack(spacing: 8) {
            Text("\(session.category.emoji) \(session.category.displayName) · Ebene \(floor)\(DungeonSimulator.isBossFloor(floor) ? " 👑" : "")")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(String(format: "%02d:%02d", remaining / 60, remaining % 60))
                .font(.system(size: 64, weight: .heavy, design: .monospaced))
                .contentTransition(.numericText(countsDown: true))
            StatBar(value: Int(session.progress(at: now) * 1000), max: 1000, color: Theme.torch, height: 6)
        }
    }

    private func eventLog(_ events: [DungeonEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if events.isEmpty {
                Text("🕯️ Dein Held entzündet eine Fackel und betritt den Dungeon …")
                    .foregroundStyle(.secondary)
            }
            ForEach(Array(events.suffix(5).reversed().enumerated()), id: \.element.id) { index, event in
                HStack(alignment: .top, spacing: 10) {
                    Text(event.kind.icon)
                    Text(event.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(index == 0 ? .callout.weight(.semibold) : .footnote)
                .opacity(index == 0 ? 1 : 0.75 - Double(index) * 0.12)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .animation(.spring(duration: 0.4), value: events.count)
    }
}
