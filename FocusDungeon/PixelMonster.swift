import DungeonCore
import SwiftUI

/// A dungeon monster as pixel art, picked by its name. Bosses are drawn bigger and wear a crown.
struct PixelMonster: View {
    let name: String
    var pixelSize: CGFloat = 8

    var body: some View {
        let look = MonsterLook(name: name)
        let size = look.isBoss ? pixelSize * 1.25 : pixelSize
        VStack(spacing: 0) {
            if look.isBoss {
                PixelSprite(grid: MonsterShape.crown, palette: MonsterShape.crownPalette, pixelSize: size)
            }
            PixelSprite(grid: look.shape.grid, palette: look.palette, pixelSize: size)
        }
        .accessibilityLabel(name)
    }
}

/// Body shape plus colors. Letters: A body · B dark parts · C accent · E eyes · W teeth, bones, highlights.
private struct MonsterLook {
    let shape: MonsterShape
    let palette: [Character: Color]
    let isBoss: Bool

    init(name: String) {
        isBoss = DungeonSimulator.isBoss(named: name)
        let (shape, a, b, c, e) = Self.appearance(of: name)
        self.shape = shape
        palette = ["A": a, "B": b, "C": c, "E": e, "W": Color(red: 0.95, green: 0.93, blue: 0.88)]
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    private static func appearance(of name: String) -> (MonsterShape, Color, Color, Color, Color) {
        let red = rgb(0.9, 0.2, 0.2), yellow = rgb(1, 0.85, 0.2), dark = rgb(0.1, 0.08, 0.12)
        switch name {
        case "Ratte": return (.rat, rgb(0.55, 0.5, 0.45), rgb(0.4, 0.35, 0.32), rgb(0.95, 0.6, 0.65), red)
        case "Schleim": return (.slime, rgb(0.35, 0.8, 0.4), rgb(0.2, 0.55, 0.25), rgb(0.8, 1, 0.8), dark)
        case "Goblin", "Goblinkönig": return (.humanoid, rgb(0.45, 0.7, 0.3), rgb(0.45, 0.3, 0.2), rgb(0.35, 0.55, 0.22), yellow)
        case "Fledermaus": return (.bat, rgb(0.35, 0.25, 0.4), rgb(0.2, 0.15, 0.25), rgb(0.35, 0.25, 0.4), red)
        case "Skelett": return (.skeleton, rgb(0.9, 0.88, 0.8), rgb(0.4, 0.4, 0.42), rgb(0.9, 0.88, 0.8), dark)
        case "Ork": return (.humanoid, rgb(0.3, 0.5, 0.25), rgb(0.35, 0.35, 0.38), rgb(0.25, 0.42, 0.2), red)
        case "Riesenspinne": return (.spider, rgb(0.2, 0.18, 0.22), rgb(0.3, 0.28, 0.32), rgb(0.2, 0.18, 0.22), red)
        case "Spinnenkönigin": return (.spider, rgb(0.4, 0.2, 0.5), rgb(0.55, 0.3, 0.65), rgb(0.4, 0.2, 0.5), yellow)
        case "Zombie-Ritter": return (.humanoid, rgb(0.55, 0.65, 0.5), rgb(0.55, 0.58, 0.62), rgb(0.5, 0.6, 0.45), rgb(0.9, 0.9, 0.3))
        case "Kobold-Schamane": return (.humanoid, rgb(0.75, 0.4, 0.25), rgb(0.45, 0.25, 0.55), yellow, yellow)
        case "Troll": return (.humanoid, rgb(0.45, 0.55, 0.5), rgb(0.4, 0.3, 0.25), rgb(0.38, 0.48, 0.42), rgb(1, 0.6, 0.1))
        case "Steingolem": return (.golem, rgb(0.55, 0.55, 0.58), rgb(0.3, 0.3, 0.33), rgb(0.55, 0.55, 0.58), rgb(0.4, 0.9, 1))
        case "Vampir": return (.humanoid, rgb(0.9, 0.88, 0.9), rgb(0.15, 0.1, 0.15), rgb(0.6, 0.1, 0.15), red)
        case "Basilisk": return (.serpent, rgb(0.35, 0.6, 0.35), rgb(0.25, 0.45, 0.25), rgb(0.85, 0.8, 0.4), yellow)
        case "Schattenwandler": return (.ghost, rgb(0.3, 0.25, 0.4), rgb(0.15, 0.1, 0.2), rgb(0.3, 0.25, 0.4), rgb(0.7, 0.5, 1))
        case "Knochendrache": return (.serpent, rgb(0.88, 0.86, 0.78), rgb(0.55, 0.52, 0.48), rgb(0.4, 0.4, 0.42), rgb(0.4, 0.9, 1))
        case "Dämonenfürst": return (.humanoid, rgb(0.8, 0.2, 0.2), rgb(0.2, 0.1, 0.1), rgb(0.95, 0.9, 0.8), yellow)
        case "Lich der Prokrastination": return (.skeleton, rgb(0.85, 0.85, 0.78), rgb(0.45, 0.25, 0.6), rgb(0.85, 0.85, 0.78), rgb(0.6, 1, 0.6))
        case "Drache der Ablenkung": return (.serpent, rgb(0.8, 0.25, 0.2), rgb(0.6, 0.15, 0.15), rgb(1, 0.75, 0.3), yellow)
        default:
            // "Uralter Schatten Nr. …" and anything new.
            return (.ghost, rgb(0.12, 0.1, 0.15), rgb(0.3, 0, 0.05), rgb(0.12, 0.1, 0.15), red)
        }
    }
}

private enum MonsterShape {
    case slime, rat, bat, humanoid, skeleton, spider, golem, serpent, ghost

    var grid: [String] {
        switch self {
        case .slime: [
            "............",
            "....AAAA....",
            "..AAAAAAAA..",
            ".AWWAAAAAAA.",
            ".AWAEAAAEAA.",
            "AAAAEAAAEAAA",
            "AAAAAAAAAAAA",
            "AAAABBBBAAAA",
            "BAAAAAAAAAAB",
            ".BBBBBBBBBB.",
        ]
        case .rat: [
            "............",
            ".BB......BB.",
            ".BAB....BAB.",
            "..AAAAAAAA..",
            ".AAEAAAAEAA.",
            ".AAAAAAAAAA.",
            "..AAACCAAA..",
            "...AWAAWA...",
            "..AAAAAAAA.C",
            ".AAAAAAAAACC",
            "..BB....BB..",
        ]
        case .bat: [
            "B..........B",
            "BB........BB",
            "BBB..AA..BBB",
            "BBBBAAAABBBB",
            "BBBAEAAEABBB",
            ".BBAAAAAABB.",
            "..B.AWWA.B..",
            "....A..A....",
        ]
        case .humanoid: [
            "....AAAA....",
            "..C.AAAA.C..",
            "..CAEAAEAC..",
            "....AAAA....",
            "....AWWA....",
            "...BBBBBB...",
            "..ABBBBBBA..",
            "..ABBBBBBA..",
            "..A.BBBB.A..",
            "....B..B....",
            "....B..B....",
            "...BB..BB...",
        ]
        case .skeleton: [
            "....WWWW....",
            "...WWWWWW...",
            "...WEWWEW...",
            "...WWWWWW...",
            "....WEEW....",
            ".....WW.....",
            "...BBBBBB...",
            "..WBWBBWBW..",
            "..W.BWWB.W..",
            "....BBBB....",
            "....W..W....",
            "...WW..WW...",
        ]
        case .spider: [
            "B..B....B..B",
            ".B..B..B..B.",
            "..B.AAAA.B..",
            "BBBAAAAAABBB",
            "...AEAAEA...",
            "BBBAAAAAABBB",
            "..B.AAAA.B..",
            ".B..BWWB..B.",
            "B..B....B..B",
        ]
        case .golem: [
            "...AAAAAA...",
            "...AEAAEA...",
            "...AAAAAA...",
            "....ABBA....",
            ".AAAAAAAAAA.",
            "AAAAAAAAAAAA",
            "AA.AABBAA.AA",
            "AA.AAAAAA.AA",
            "...AAAAAA...",
            "...AA..AA...",
            "..AAA..AAA..",
        ]
        case .serpent: [
            ".......AAA..",
            "......AAAAA.",
            "......AEAAAW",
            "..B...AAAAA.",
            ".BBB...AAA..",
            "BBBBB.AAA...",
            ".BBBAAAAA...",
            "..AAAAAACC..",
            ".AAAA.AAACC.",
            "AAA....AAA..",
            "AA......AA..",
        ]
        case .ghost: [
            "....AAAA....",
            "..AAAAAAAA..",
            ".AAAAAAAAAA.",
            ".AAEEAAEEAA.",
            ".AAEEAAEEAA.",
            ".AAAAAAAAAA.",
            ".AAAABBAAAA.",
            ".AAAAAAAAAA.",
            ".AAAAAAAAAA.",
            ".AA.AAA.AAA.",
            ".A...A...A..",
        ]
        }
    }

    static let crown = [
        "..G..GG..G..",
        "..GG.GG.GG..",
        "..GGGGGGGG..",
        "..GRGGGGRG..",
    ]

    static let crownPalette: [Character: Color] = [
        "G": Color(red: 1, green: 0.8, blue: 0.2),
        "R": Color(red: 0.85, green: 0.15, blue: 0.25),
    ]
}

#Preview {
    let names = ["Ratte", "Schleim", "Goblin", "Fledermaus", "Skelett", "Ork", "Riesenspinne", "Zombie-Ritter",
                 "Kobold-Schamane", "Troll", "Steingolem", "Vampir", "Basilisk", "Schattenwandler", "Knochendrache",
                 "Dämonenfürst", "Goblinkönig", "Spinnenkönigin", "Lich der Prokrastination", "Drache der Ablenkung",
                 "Uralter Schatten Nr. 1"]
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 16) {
            ForEach(names, id: \.self) { name in
                VStack {
                    PixelMonster(name: name, pixelSize: 5)
                    Text(name).font(.caption2)
                }
            }
        }
        .padding()
    }
    .background(Theme.background)
}
