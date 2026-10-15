public enum StatKind: String, CaseIterable, Codable, Sendable {
    case intelligence, dexterity, strength, charisma

    public var displayName: String {
        switch self {
        case .intelligence: "Intelligenz"
        case .dexterity: "Geschick"
        case .strength: "Stärke"
        case .charisma: "Charisma"
        }
    }
}

/// What the user focuses on. Each category trains one hero stat.
public enum FocusCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case learning, work, sport, creative

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .learning: "Lernen"
        case .work: "Arbeit"
        case .sport: "Sport"
        case .creative: "Kreatives"
        }
    }

    public var emoji: String {
        switch self {
        case .learning: "📚"
        case .work: "💻"
        case .sport: "🏋️"
        case .creative: "🎨"
        }
    }

    public var stat: StatKind {
        switch self {
        case .learning: .intelligence
        case .work: .dexterity
        case .sport: .strength
        case .creative: .charisma
        }
    }
}

public enum HeroClass: String, Codable, Sendable {
    case adventurer, mage, rogue, warrior, bard

    public var displayName: String {
        switch self {
        case .adventurer: "Abenteurer"
        case .mage: "Magier"
        case .rogue: "Schurke"
        case .warrior: "Krieger"
        case .bard: "Barde"
        }
    }
}

public struct Stats: Codable, Hashable, Sendable {
    public var intelligence: Int
    public var dexterity: Int
    public var strength: Int
    public var charisma: Int

    public init(intelligence: Int = 1, dexterity: Int = 1, strength: Int = 1, charisma: Int = 1) {
        self.intelligence = intelligence
        self.dexterity = dexterity
        self.strength = strength
        self.charisma = charisma
    }

    public subscript(kind: StatKind) -> Int {
        get {
            switch kind {
            case .intelligence: intelligence
            case .dexterity: dexterity
            case .strength: strength
            case .charisma: charisma
            }
        }
        set {
            switch kind {
            case .intelligence: intelligence = newValue
            case .dexterity: dexterity = newValue
            case .strength: strength = newValue
            case .charisma: charisma = newValue
            }
        }
    }

    /// The single highest stat, or nil if the top is tied.
    public var dominant: StatKind? {
        let sorted = StatKind.allCases.sorted { self[$0] > self[$1] }
        return self[sorted[0]] > self[sorted[1]] ? sorted[0] : nil
    }
}
