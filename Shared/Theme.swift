import DungeonCore
import SwiftUI

enum Theme {
    static let background = Color(red: 0.07, green: 0.06, blue: 0.09)
    static let panel = Color(red: 0.13, green: 0.11, blue: 0.15)
    static let panelBorder = Color.white.opacity(0.08)
    static let torch = Color(red: 1.0, green: 0.69, blue: 0.25)
    static let hp = Color(red: 0.86, green: 0.25, blue: 0.27)
    static let xp = Color(red: 0.36, green: 0.62, blue: 1.0)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.3)

    static func title(_ size: CGFloat = 22) -> Font {
        .system(size: size, weight: .heavy, design: .monospaced)
    }
}

extension Rarity {
    var color: Color {
        switch self {
        case .common: Color(white: 0.7)
        case .uncommon: Color(red: 0.4, green: 0.85, blue: 0.45)
        case .rare: Color(red: 0.35, green: 0.6, blue: 1.0)
        case .epic: Color(red: 0.72, green: 0.45, blue: 1.0)
        case .legendary: Color(red: 1.0, green: 0.6, blue: 0.15)
        }
    }
}

extension HeroClass {
    var color: Color {
        switch self {
        case .adventurer: Color(red: 0.6, green: 0.42, blue: 0.27)
        case .mage: Color(red: 0.5, green: 0.32, blue: 0.85)
        case .rogue: Color(red: 0.2, green: 0.55, blue: 0.4)
        case .warrior: Color(red: 0.75, green: 0.22, blue: 0.22)
        case .bard: Color(red: 0.9, green: 0.7, blue: 0.2)
        }
    }
}

extension ItemSlot {
    var symbol: String {
        switch self {
        case .weapon: "🗡️"
        case .armor: "🛡️"
        case .trinket: "💍"
        }
    }
}

extension DungeonEventKind {
    var icon: String {
        switch self {
        case .fight: "⚔️"
        case .bossFight: "👑"
        case .treasure: "💰"
        case .loot: "🎁"
        case .trap: "🪤"
        case .shrine: "✨"
        case .quiet: "🕯️"
        case .knockout: "💫"
        case .descend: "🪜"
        }
    }
}

/// Dark rounded card used throughout the app.
struct Panel<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.panel, in: .rect(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.panelBorder))
    }
}

struct StatBar: View {
    let value: Int
    let max: Int
    let color: Color
    var height: CGFloat = 10

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(color)
                    .frame(width: geo.size.width * CGFloat(Swift.max(0, Swift.min(value, max))) / CGFloat(Swift.max(max, 1)))
            }
        }
        .frame(height: height)
    }
}
