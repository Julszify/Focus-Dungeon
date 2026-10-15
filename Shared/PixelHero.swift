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

    private func color(for pixel: Character) -> Color? {
        switch pixel {
        case "H": heroClass.color
        case "S", "A": Color(red: 0.96, green: 0.78, blue: 0.62)
        case "E": Color(red: 0.12, green: 0.1, blue: 0.15)
        case "B": heroClass.color.mix(with: .white, by: 0.15)
        case "b": heroClass.color.mix(with: .black, by: 0.35)
        case "L": Color(red: 0.35, green: 0.25, blue: 0.2)
        case "F": Color(red: 0.2, green: 0.14, blue: 0.12)
        case "W": weaponColor
        default: nil
        }
    }

    // One shape per palette color: plain shapes render in widgets and Live Activities, Canvas does not.
    var body: some View {
        ZStack {
            ForEach(Array("HSAEBbLFW"), id: \.self) { pixel in
                if let color = color(for: pixel) {
                    PixelLayer(grid: Self.grid, pixel: pixel).fill(color)
                }
            }
        }
        .frame(width: CGFloat(Self.grid[0].count) * pixelSize, height: CGFloat(Self.grid.count) * pixelSize)
        .accessibilityLabel("Pixel-Held")
    }
}

/// All cells of one palette character, scaled to whatever frame the shape gets.
private nonisolated struct PixelLayer: Shape {
    let grid: [String]
    let pixel: Character

    func path(in rect: CGRect) -> Path {
        let rows = grid.map(Array.init)
        let size = CGSize(width: rect.width / CGFloat(rows[0].count), height: rect.height / CGFloat(rows.count))
        var path = Path()
        for (y, row) in rows.enumerated() {
            for (x, cell) in row.enumerated() where cell == pixel {
                path.addRect(CGRect(x: rect.minX + CGFloat(x) * size.width, y: rect.minY + CGFloat(y) * size.height,
                                    width: size.width, height: size.height))
            }
        }
        return path
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
