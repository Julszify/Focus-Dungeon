/// Deterministic RNG (SplitMix64). The same seed always produces the same dungeon,
/// so a run can be precomputed at session start and revealed minute by minute.
public struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Returns true with the given probability (0...1).
    public mutating func chance(_ probability: Double) -> Bool {
        Double.random(in: 0..<1, using: &self) < probability
    }

    public mutating func pick<T>(_ options: [T]) -> T {
        options.randomElement(using: &self)!
    }
}
