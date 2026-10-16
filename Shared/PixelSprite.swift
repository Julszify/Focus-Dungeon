import SwiftUI

/// Draws a pixel grid: each character is one pixel, colored by the palette; unknown characters are transparent.
/// One shape per palette color, since plain shapes render in widgets and Live Activities and Canvas does not.
struct PixelSprite: View {
    let grid: [String]
    let palette: [Character: Color]
    var pixelSize: CGFloat = 8

    var body: some View {
        ZStack {
            ForEach(palette.keys.sorted(), id: \.self) { pixel in
                PixelLayer(grid: grid, pixel: pixel).fill(palette[pixel] ?? .clear)
            }
        }
        .frame(width: CGFloat(grid.first?.count ?? 0) * pixelSize, height: CGFloat(grid.count) * pixelSize)
    }
}

/// All cells of one palette character, scaled to whatever frame the shape gets.
private nonisolated struct PixelLayer: Shape {
    let grid: [String]
    let pixel: Character

    func path(in rect: CGRect) -> Path {
        let rows = grid.map(Array.init)
        guard let width = rows.first?.count, width > 0 else { return Path() }
        let size = CGSize(width: rect.width / CGFloat(width), height: rect.height / CGFloat(rows.count))
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
