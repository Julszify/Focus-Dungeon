import DungeonCore
import SwiftUI

/// The animated dungeon: the hero walks along a scrolling corridor and every room plays out as
/// a short scene. Everything derives from the session clock, so after returning to the app the
/// scene picks up exactly where it would be.
struct DungeonScene: View {
    let session: FocusSession
    /// Events revealed so far.
    let events: [DungeonEvent]
    let heroClass: HeroClass
    let startHP: Int
    /// `.continuing` lets the clock run past the session's end, for the final room.
    var clock: Clock = .session

    enum Clock { case session, continuing }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let walkSpeed = 34.0  // points per second

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { context in
            GeometryReader { geometry in
                SceneFrame(
                    elapsed: clock == .session
                        ? session.elapsed(at: context.date)
                        : context.date.timeIntervalSince(session.startDate),
                    rooms: events.filter { $0.kind != .descend },
                    descents: Set(events.filter { $0.kind == .descend }.map(\.minute)),
                    heroClass: heroClass,
                    startHP: startHP,
                    size: geometry.size,
                    motion: !reduceMotion
                )
            }
        }
        .clipShape(.rect(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.panelBorder))
    }

    /// How long the hero stands still for a room before walking on.
    static func pause(for kind: DungeonEventKind) -> Double {
        switch kind {
        case .fight, .bossFight: 4.2
        case .knockout: 6.8
        case .treasure, .loot, .shrine: 3.0
        case .trap: 1.2
        case .quiet, .descend: 0
        }
    }
}

// MARK: - One frame

private struct SceneFrame: View {
    let elapsed: Double
    let rooms: [DungeonEvent]
    let descents: Set<Int>
    let heroClass: HeroClass
    let startHP: Int
    let size: CGSize
    let motion: Bool

    private let pixel: CGFloat = 8
    private var floorY: CGFloat { size.height - 38 }
    private var heroX: CGFloat { size.width * 0.3 }
    private var objectX: CGFloat { size.width * 0.7 }

    /// The current room, and seconds since the hero entered it.
    private var room: DungeonEvent? { rooms.last }
    private var t: Double { room.map { elapsed - Double($0.minute * 60) } ?? .infinity }
    private var pause: Double { room.map { DungeonScene.pause(for: $0.kind) } ?? 0 }
    private var walking: Bool { t >= pause }

    /// Distance walked: total time minus every pause so far, so the corridor never jumps.
    private var walked: Double {
        guard motion else { return 0 }
        let paused = rooms.reduce(0.0) { total, event in
            let since = elapsed - Double(event.minute * 60)
            return since > 0 ? total + min(since, DungeonScene.pause(for: event.kind)) : total
        }
        return (elapsed - paused) * DungeonScene.walkSpeed
    }

    private var previousHP: Int { rooms.dropLast().last?.hpAfter ?? startHP }

    var body: some View {
        let shake = trapShake
        ZStack {
            Corridor(walked: walked, time: elapsed, heroX: heroX, floorY: floorY)
            if let room {
                roomObject(room)
            }
            hero
            if let room {
                floatingTexts(room)
            }
            flash
        }
        .offset(x: shake)
    }

    // MARK: Hero

    private var heroKnockedOut: Double {
        guard room?.kind == .knockout else { return 0 }
        // Falls at the end of the fight, gets back up by the campfire.
        return smooth(ramp(t, 2.6, 3.0)) * (1 - smooth(ramp(t, 6.0, 6.6)))
    }

    private var hero: some View {
        let step = walking && motion ? Int(walked / 10) % 2 : 0
        let bob: CGFloat = walking && motion && step == 1 ? -2 : 0
        let height = 14 * pixel
        return PixelHero(heroClass: heroClass, pixelSize: pixel, step: step)
            .rotationEffect(.degrees(-90 * heroKnockedOut), anchor: .bottom)
            .opacity(1 - 0.4 * heroKnockedOut)
            .brightness(heroHitFlash ? 0.6 : 0)
            .position(x: heroX + heroLunge, y: floorY - height / 2 + bob)
    }

    // MARK: Fights

    private var isFight: Bool { [.fight, .bossFight, .knockout].contains(room?.kind) }

    /// The exchange of blows: four rounds of half a second, hero strikes first.
    private var round: (index: Int, phase: Double)? {
        guard isFight, t >= 0.6, t < 2.6 else { return nil }
        let r = (t - 0.6) / 0.5
        return (Int(r), r - r.rounded(.down))
    }

    private var heroLunge: CGFloat {
        guard motion, let round, round.phase < 0.3 else { return 0 }
        return 16 * sin(round.phase / 0.3 * .pi)
    }

    private var monsterLunge: CGFloat {
        guard motion, let round, round.phase >= 0.5, round.phase < 0.8 else { return 0 }
        return -16 * sin((round.phase - 0.5) / 0.3 * .pi)
    }

    private var monsterHitFlash: Bool {
        guard let round else { return false }
        return round.phase >= 0.15 && round.phase < 0.3
    }

    private var heroHitFlash: Bool {
        guard let round else { return false }
        return round.phase >= 0.65 && round.phase < 0.8
    }

    // MARK: Room objects

    /// Slides in from the right on entering, then drifts out left once the hero walks on.
    private var objectOffset: CGFloat {
        let enter = smooth(ramp(t, 0, 0.6))
        let incoming = (1 - enter) * size.width * 0.45
        let passed = walking ? CGFloat(t - pause) * DungeonScene.walkSpeed : 0
        return incoming - (motion ? passed : 0)
    }

    @ViewBuilder
    private func roomObject(_ room: DungeonEvent) -> some View {
        let x = objectX + objectOffset
        if x > -80 {
            if let monster = room.monster {
                let defeated = room.kind == .knockout ? 0 : smooth(ramp(t, 2.6, 3.0))
                PixelMonster(name: monster, pixelSize: pixel)
                    .rotationEffect(.degrees(90 * defeated), anchor: .bottom)
                    .opacity(1 - 0.6 * defeated)
                    .brightness(monsterHitFlash ? 0.7 : 0)
                    // Sprites differ in height; standing them in a bottom-aligned box puts all feet on the floor.
                    .frame(width: 200, height: 200, alignment: .bottom)
                    .position(x: x + monsterLunge, y: floorY - 100)
                if room.kind == .knockout, t > 3.0, t < 6.8 {
                    Text("🔥").font(.system(size: 34))
                        .scaleEffect(motion ? 1 + 0.08 * sin(elapsed * 9) : 1)
                        .position(x: heroX + 62, y: floorY - 18)
                }
            } else {
                switch room.kind {
                case .treasure, .loot:
                    let bounce = t > 0.6 && t < 1.3 ? -abs(sin((t - 0.6) / 0.7 * .pi * 2)) * 14 : 0
                    Text(room.kind == .treasure ? "💰" : "🎁").font(.system(size: 52))
                        .position(x: x, y: floorY - 30 + (motion ? bounce : 0))
                case .shrine:
                    Text("⛲️").font(.system(size: 56))
                        .position(x: x, y: floorY - 32)
                case .trap:
                    Text("🪤").font(.system(size: 36))
                        .position(x: heroX + 26, y: floorY - 14)
                        .opacity(1 - ramp(t, 1.0, 1.4))
                default:
                    EmptyView()
                }
            }
        }
    }

    // MARK: Floating numbers and particles

    @ViewBuilder
    private func floatingTexts(_ room: DungeonEvent) -> some View {
        let lost = previousHP - room.hpAfter
        switch room.kind {
        case .fight, .bossFight:
            if lost > 0 {
                FloatingText(text: "-\(lost)", color: Theme.hp, progress: ramp(t, 1.4, 2.6))
                    .position(x: heroX, y: floorY - 130)
            }
            if room.gold > 0 {
                FloatingText(text: "+\(room.gold) 🪙", color: Theme.gold, progress: ramp(t, 3.0, 4.2))
                    .position(x: objectX, y: floorY - 120)
            }
            if room.item != nil {
                FloatingText(text: "🎁 Beute!", color: .white, progress: ramp(t, 3.3, 4.5))
                    .position(x: objectX, y: floorY - 150)
            }
        case .knockout:
            FloatingText(text: "💫", color: .white, progress: ramp(t, 2.8, 4.2))
                .position(x: heroX, y: floorY - 80)
        case .treasure, .loot:
            Coins(progress: ramp(t, 0.9, 2.4), symbol: room.kind == .treasure ? "🪙" : (room.item?.slot.symbol ?? "✨"))
                .position(x: objectX, y: floorY - 60)
            if room.gold > 0 {
                FloatingText(text: "+\(room.gold) 🪙", color: Theme.gold, progress: ramp(t, 1.2, 2.6))
                    .position(x: objectX, y: floorY - 110)
            }
        case .shrine:
            Coins(progress: ramp(t, 0.5, 2.5), symbol: "✨")
                .position(x: heroX, y: floorY - 50)
            if room.hpAfter > previousHP {
                FloatingText(text: "+\(room.hpAfter - previousHP) ❤️", color: Color(red: 0.4, green: 0.9, blue: 0.5),
                             progress: ramp(t, 0.8, 2.4))
                    .position(x: heroX, y: floorY - 130)
            }
        case .trap:
            FloatingText(text: lost > 0 ? "-\(lost)" : "Ausgewichen!", color: lost > 0 ? Theme.hp : .white,
                         progress: ramp(t, 0.1, 1.2))
                .position(x: heroX, y: floorY - 130)
        default:
            EmptyView()
        }
    }

    // MARK: Screen effects

    private var trapShake: CGFloat {
        guard motion, room?.kind == .trap, t < 0.6 else { return 0 }
        return 6 * (1 - t / 0.6) * sin(t * 60)
    }

    @ViewBuilder
    private var flash: some View {
        if let room {
            if descents.contains(room.minute), t < 1.0 {
                // Going down the stairs: fade through black and name the new floor.
                let darkness = sin(min(t / 1.0, 1) * .pi)
                Color.black.opacity(darkness)
                Text("Ebene \(room.floor)")
                    .font(Theme.title(28))
                    .foregroundStyle(.white)
                    .opacity(darkness)
            } else if room.kind == .trap, t < 0.4, previousHP > room.hpAfter {
                Theme.hp.opacity(0.3 * (1 - t / 0.4))
            }
        }
    }
}

// MARK: - Pieces

/// Text that rises and fades out as `progress` goes from 0 to 1.
private struct FloatingText: View {
    let text: String
    let color: Color
    let progress: Double

    var body: some View {
        if progress > 0, progress < 1 {
            Text(text)
                .font(.system(.headline, design: .rounded).weight(.heavy))
                .foregroundStyle(color)
                .shadow(color: .black, radius: 2)
                .offset(y: -36 * progress)
                .opacity(progress < 0.7 ? 1 : (1 - progress) / 0.3)
        }
    }
}

/// A small fountain of symbols, e.g. coins out of a chest.
private struct Coins: View {
    let progress: Double
    let symbol: String

    var body: some View {
        if progress > 0, progress < 1 {
            ZStack {
                ForEach(0..<6, id: \.self) { i in
                    let angle = Double(i) / 6 * .pi - .pi
                    let spread = 34 * progress
                    let rise = 70 * sin(progress * .pi * 0.9)
                    Text(symbol)
                        .font(.system(size: 18))
                        .offset(x: cos(angle) * spread * 1.4, y: -rise + sin(angle) * spread * 0.4)
                        .opacity(1 - progress)
                }
            }
        }
    }
}

/// Brick walls with torches and a tiled floor, scrolling with the hero's steps.
/// The wall moves a bit slower than the floor, which gives a touch of depth.
private struct Corridor: View {
    let walked: Double
    let time: Double
    let heroX: CGFloat
    let floorY: CGFloat

    private static let wall = Color(red: 0.1, green: 0.09, blue: 0.12)
    private static let floor = Color(red: 0.12, green: 0.1, blue: 0.13)

    var body: some View {
        Canvas { context, size in
            let wallTop = 0.0
            let wallBottom = floorY

            // Bricks, two rows offset by half a brick.
            context.fill(Path(CGRect(x: 0, y: wallTop, width: size.width, height: wallBottom)), with: .color(Self.wall))
            let brickWidth = 44.0, brickHeight = 22.0
            let wallScroll = walked * 0.6
            for row in 0..<Int(wallBottom / brickHeight) + 1 {
                let y = Double(row) * brickHeight
                let shift = row.isMultiple(of: 2) ? 0 : brickWidth / 2
                let first = Int(((wallScroll + shift) / brickWidth).rounded(.down)) - 1
                var column = first
                while true {
                    let x = Double(column) * brickWidth - wallScroll - shift
                    if x > size.width { break }
                    // Stable per-brick shade from its absolute position.
                    let shade = Double((column &* 7 &+ row &* 13) & 7) / 7 * 0.035
                    let brick = Color(red: 0.17 + shade, green: 0.15 + shade, blue: 0.19 + shade)
                    context.fill(Path(roundedRect: CGRect(x: x + 1, y: y + 1, width: brickWidth - 2, height: brickHeight - 2),
                                      cornerRadius: 2), with: .color(brick))
                    column += 1
                }
            }

            // Wall torches every 210 points, flickering.
            let spacing = 210.0
            let firstTorch = Int((wallScroll / spacing).rounded(.down)) - 1
            for index in firstTorch...(firstTorch + Int(size.width / spacing) + 2) {
                let x = Double(index) * spacing - wallScroll + 105
                let y = wallBottom * 0.38
                let flicker = 0.85 + 0.15 * sin(time * 11 + Double(index) * 1.7)
                context.fill(Path(ellipseIn: CGRect(x: x - 80, y: y - 80, width: 160, height: 160)),
                             with: .radialGradient(Gradient(colors: [Theme.torch.opacity(0.28 * flicker), .clear]),
                                                   center: CGPoint(x: x, y: y), startRadius: 4, endRadius: 80))
                context.fill(Path(CGRect(x: x - 3, y: y, width: 6, height: 16)), with: .color(Color(red: 0.35, green: 0.25, blue: 0.18)))
                let flame = CGRect(x: x - 5, y: y - 14 * flicker, width: 10, height: 14 * flicker)
                context.fill(Path(ellipseIn: flame), with: .color(Theme.torch))
                context.fill(Path(ellipseIn: flame.insetBy(dx: 2.5, dy: 4)), with: .color(Color(red: 1, green: 0.92, blue: 0.6)))
            }

            // Floor with scrolling tile seams.
            context.fill(Path(CGRect(x: 0, y: wallBottom, width: size.width, height: size.height - wallBottom)), with: .color(Self.floor))
            context.fill(Path(CGRect(x: 0, y: wallBottom, width: size.width, height: 3)), with: .color(Color.black.opacity(0.5)))
            let tile = 48.0
            var seam = -(walked.truncatingRemainder(dividingBy: tile))
            while seam < size.width {
                context.fill(Path(CGRect(x: seam, y: wallBottom + 3, width: 2, height: size.height - wallBottom)),
                             with: .color(Color.white.opacity(0.04)))
                seam += tile
            }

            // The torch the hero carries.
            context.fill(Path(CGRect(origin: .zero, size: size)),
                         with: .radialGradient(Gradient(colors: [Theme.torch.opacity(0.22), .clear]),
                                               center: CGPoint(x: heroX + 30, y: floorY - 70), startRadius: 10, endRadius: 170))
        }
        // Darken the edges so the corridor fades into the dark.
        .overlay(
            LinearGradient(stops: [.init(color: Theme.background, location: 0), .init(color: .clear, location: 0.15),
                                   .init(color: .clear, location: 0.85), .init(color: Theme.background, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
        )
    }
}

// MARK: - Easing

private func ramp(_ t: Double, _ start: Double, _ end: Double) -> Double {
    min(max((t - start) / (end - start), 0), 1)
}

private func smooth(_ x: Double) -> Double {
    x * x * (3 - 2 * x)
}
