import DungeonCore
import SwiftUI

/// The hero drawn as pixel art. Hat, tunic and weapon change with the class.
struct PixelHero: View {
    let heroClass: HeroClass
    var pixelSize: CGFloat = 8

    // H hat/hood · S skin · E eyes · B tunic · b tunic shade · A arms · L legs · F boots · W weapon
    private static let grid = [
        "...HHHH.......",
        "..HHHHHH......",
        ".HHHHHHHH.....",
        "..SSSSSS......",
        "..SESSES....W.",
        "..SSSSSS....W.",
        "...SSSS.....W.",
        "..BBBBBB....W.",
        ".ABBbbBBA..AW.",
        ".ABBbbBBAAA...",
        "..BBBBBB......",
        "..bbbbbb......",
        "..LL..LL......",
        "..FF..FF......",
    ]

    private var weaponColor: Color {
        switch heroClass {
        case .mage: Color(red: 0.55, green: 0.38, blue: 0.2)
        case .bard: Color(red: 0.85, green: 0.6, blue: 0.3)
        default: Color(white: 0.82)
        }
    }

    private var palette: [Character: Color] {
        let skin = Color(red: 0.96, green: 0.78, blue: 0.62)
        return [
            "H": heroClass.color,
            "S": skin, "A": skin,
            "E": Color(red: 0.12, green: 0.1, blue: 0.15),
            "B": heroClass.color.mix(with: .white, by: 0.15),
            "b": heroClass.color.mix(with: .black, by: 0.35),
            "L": Color(red: 0.35, green: 0.25, blue: 0.2),
            "F": Color(red: 0.2, green: 0.14, blue: 0.12),
            "W": weaponColor,
        ]
    }

    var body: some View {
        PixelSprite(grid: Self.grid, palette: palette, pixelSize: pixelSize)
            .accessibilityLabel("Pixel-Held")
    }
}

#Preview {
    HStack {
        ForEach([HeroClass.adventurer, .mage, .rogue, .warrior, .bard], id: \.self) {
            PixelHero(heroClass: $0, pixelSize: 5)
        }
    }
    .padding()
    .background(Theme.background)
}
