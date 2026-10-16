import Charts
import DungeonCore
import SwiftUI

/// The hero's chronicle: focus statistics, streak, records and recent adventures.
struct ChronicleView: View {
    @Environment(GameStore.self) private var store
    @State private var selectedDay: Date?

    private var chronicle: Chronicle { Chronicle(records: store.history) }

    var body: some View {
        let chronicle = chronicle
        ScrollView {
            VStack(spacing: 16) {
                tiles(chronicle)
                if chronicle.records.isEmpty {
                    Panel {
                        Text("📜 Die Chronik beginnt mit deinem nächsten Abenteuer. Jede Session wird hier festgehalten.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    week(chronicle)
                    categories(chronicle)
                    records(chronicle)
                    recent(chronicle)
                }
            }
            .padding()
        }
        .background(Theme.background)
        .navigationTitle("Heldenchronik")
    }

    // MARK: Tiles

    private func tiles(_ chronicle: Chronicle) -> some View {
        let streak = chronicle.currentStreak()
        return Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                tile(formatMinutes(store.hero.totalFocusMinutes), "Fokuszeit gesamt")
                tile(streak == 1 ? "🔥 1 Tag" : "🔥 \(streak) Tage", "Serie")
            }
            GridRow {
                tile("\(chronicle.records.count)", chronicle.fledCount > 0 ? "Abenteuer · \(chronicle.fledCount) geflohen" : "Abenteuer")
                tile("👑 \(chronicle.bossesDefeated)", "Bosse besiegt")
            }
        }
    }

    private func tile(_ value: String, _ label: String) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(Theme.title(20))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Week chart

    private func week(_ chronicle: Chronicle) -> some View {
        let daily = chronicle.daily(days: 7)
        let selection = selectedDay.map { day in daily.filter { Calendar.current.isDate($0.day, inSameDayAs: day) } }
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Letzte 7 Tage").font(Theme.title(16))
                Chart(daily) { entry in
                    BarMark(
                        x: .value("Tag", entry.day, unit: .day),
                        y: .value("Minuten", entry.minutes),
                        width: .ratio(0.55)
                    )
                    .foregroundStyle(by: .value("Kategorie", entry.category.displayName))
                    .cornerRadius(3)
                    .opacity(selectedDay == nil || Calendar.current.isDate(entry.day, inSameDayAs: selectedDay!) ? 1 : 0.35)
                }
                .chartForegroundStyleScale(
                    domain: FocusCategory.chartOrder.map(\.displayName),
                    range: FocusCategory.chartOrder.map(\.color)
                )
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { _ in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated), centered: true)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.08))
                        AxisValueLabel()
                    }
                }
                .chartLegend(position: .bottom, spacing: 12)
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .onTapGesture { location in
                                guard let plot = proxy.plotFrame else { return }
                                let x = location.x - geometry[plot].origin.x
                                guard let tapped: Date = proxy.value(atX: x) else { return }
                                let day = Calendar.current.startOfDay(for: tapped)
                                // A second tap on the same day clears the selection.
                                selectedDay = selectedDay == day ? nil : day
                            }
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: selectedDay)
                .frame(height: 200)

                // Tap or drag over a day for its breakdown.
                if let selection, let day = selection.first?.day {
                    let total = selection.reduce(0) { $0 + $1.minutes }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(day.formatted(.dateTime.weekday(.wide).day().month())): \(formatMinutes(total))")
                            .font(.subheadline.weight(.semibold))
                        ForEach(selection.filter { $0.minutes > 0 }) { entry in
                            Text("\(entry.category.emoji) \(entry.category.displayName): \(entry.minutes) Min.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    Text("Tippe auf einen Tag für Details.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Categories

    private func categories(_ chronicle: Chronicle) -> some View {
        let total = max(chronicle.totalMinutes, 1)
        return Panel {
            VStack(alignment: .leading, spacing: 12) {
                Text("Nach Kategorie").font(Theme.title(16))
                ForEach(FocusCategory.chartOrder) { category in
                    let minutes = chronicle.minutes(in: category)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("\(category.emoji) \(category.displayName)")
                            Spacer()
                            Text(formatMinutes(minutes)).monospacedDigit()
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        StatBar(value: minutes, max: total, color: category.color, height: 6)
                    }
                }
            }
        }
    }

    // MARK: Records

    private func records(_ chronicle: Chronicle) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Rekorde").font(Theme.title(16))
                if let longest = chronicle.longestSession {
                    recordRow("⏱️", "Längste Session", "\(longest.focusedMinutes) Min. · \(longest.category.emoji)")
                }
                recordRow("🪜", "Tiefste Ebene", "\(chronicle.deepestFloor)")
                recordRow("🔥", "Längste Serie", chronicle.longestStreak == 1 ? "1 Tag" : "\(chronicle.longestStreak) Tage")
                recordRow("🏆", "Erfolgreich zurückgekehrt", "\(chronicle.completedCount) von \(chronicle.records.count)")
            }
        }
    }

    private func recordRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack {
            Text(icon)
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).font(.body.monospacedDigit().weight(.semibold))
        }
    }

    // MARK: Recent

    private func recent(_ chronicle: Chronicle) -> some View {
        Panel {
            VStack(alignment: .leading, spacing: 10) {
                Text("Letzte Abenteuer").font(Theme.title(16))
                ForEach(chronicle.records.prefix(10)) { record in
                    HStack(spacing: 10) {
                        Text(record.completed ? "🏆" : "🏃")
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.category.emoji) \(record.category.displayName) · \(record.focusedMinutes) Min.")
                                .font(.subheadline)
                            Text(record.date.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.floorReached > 0 ? "Ebene \(record.floorReached)" : "–")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
