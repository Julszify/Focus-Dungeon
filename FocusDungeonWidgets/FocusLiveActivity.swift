import ActivityKit
import DungeonCore
import SwiftUI
import WidgetKit

@main
struct FocusDungeonWidgets: WidgetBundle {
    var body: some Widget {
        FocusLiveActivity()
    }
}

struct FocusLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            LockScreenView(context: context)
                .activityBackgroundTint(Theme.background)
                .activitySystemActionForegroundColor(Theme.torch)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    PixelHero(heroClass: context.attributes.heroClass, pixelSize: 3.5)
                        .padding(.leading, 6)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(context: context)
                        .font(.system(.title2, design: .monospaced).weight(.heavy))
                        .foregroundStyle(Theme.torch)
                        .padding(.trailing, 6)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("\(context.attributes.category.emoji) Ebene \(context.state.floor)")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        EventLine(state: context.state, isStale: context.isStale)
                        ProgressBar(context: context)
                    }
                    .padding(.horizontal, 6)
                }
            } compactLeading: {
                PixelHero(heroClass: context.attributes.heroClass, pixelSize: 1.5)
            } compactTrailing: {
                CountdownText(context: context)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.torch)
                    .frame(maxWidth: 44)
            } minimal: {
                PixelHero(heroClass: context.attributes.heroClass, pixelSize: 1.5)
            }
            .keylineTint(Theme.torch)
        }
    }
}

private struct LockScreenView: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        let attributes = context.attributes
        HStack(alignment: .center, spacing: 14) {
            PixelHero(heroClass: attributes.heroClass, pixelSize: 5)
                .padding(8)
                .background(
                    RadialGradient(colors: [Theme.torch.opacity(0.35), .clear], center: .center, startRadius: 2, endRadius: 50)
                )

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(attributes.heroName) · Ebene \(context.state.floor)")
                        .font(.headline)
                    Spacer()
                    CountdownText(context: context)
                        .font(.system(.title3, design: .monospaced).weight(.heavy))
                        .foregroundStyle(Theme.torch)
                }
                EventLine(state: context.state, isStale: context.isStale)
                ProgressBar(context: context)
                if let boss = attributes.bossName, let floor = attributes.bossFloor, context.state.outcome == nil {
                    Text("👑 \(boss) wartet auf Ebene \(floor)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .foregroundStyle(.white)
    }
}

/// Counts down by itself, even while the app is suspended.
private struct CountdownText: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        if context.state.outcome != nil || context.isStale {
            Text("✓")
        } else {
            Text(timerInterval: context.attributes.timerRange, countsDown: true)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct ProgressBar: View {
    let context: ActivityViewContext<FocusActivityAttributes>

    var body: some View {
        // The timer-driven bar keeps moving on its own, so hide it once the adventure is over.
        if context.state.outcome == nil {
            ProgressView(timerInterval: context.attributes.timerRange, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(Theme.torch)
        }
    }
}

private struct EventLine: View {
    let state: FocusActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        if let outcome = state.outcome {
            Text(outcome).font(.subheadline.weight(.semibold))
        } else if isStale {
            Text("🏁 Zeit ist um! Öffne die App für deinen Abenteuerbericht.")
                .font(.subheadline)
        } else {
            HStack(alignment: .top, spacing: 6) {
                Text(state.lastEventIcon)
                Text(state.lastEvent).lineLimit(2)
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.85))
        }
    }
}
