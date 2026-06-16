import Foundation

/// The quality of a diatonic triad.
public enum ChordQuality: String, Sendable {
    case major
    case minor
    case diminished
    case augmented

    /// Suffix appended to the root symbol: `""`, `"m"`, `"°"`, `"+"`.
    public var symbolSuffix: String {
        switch self {
        case .major:      return ""
        case .minor:      return "m"
        case .diminished: return "°"
        case .augmented:  return "+"
        }
    }
}

/// A spelled triad with its Roman-numeral function within a key.
public struct Chord: Sendable, Equatable, Identifiable {
    public var id: String { roman + "-" + symbol }
    public let root: NoteSpelling
    public let quality: ChordQuality
    /// Roman-numeral function, e.g. `"i"`, `"ii°"`, `"III"`, `"V"`.
    public let roman: String

    public init(root: NoteSpelling, quality: ChordQuality, roman: String) {
        self.root = root
        self.quality = quality
        self.roman = roman
    }

    /// Chord symbol, e.g. `"Am"`, `"B°"`, `"C"`.
    public var symbol: String { root.symbol + quality.symbolSuffix }
}

/// A named chord progression, both as Roman numerals and concrete chords.
public struct Progression: Sendable, Equatable, Identifiable {
    public var id: String { label }
    /// Display label, e.g. `"Pop  I–V–vi–IV"`.
    public let label: String
    public let romanNumerals: [String]
    public let chords: [Chord]

    public init(label: String, romanNumerals: [String], chords: [Chord]) {
        self.label = label
        self.romanNumerals = romanNumerals
        self.chords = chords
    }
}

/// A full producer-mode theory breakdown of a key.
public struct DiatonicAnalysis: Sendable, Equatable {
    public let key: MusicalKey
    /// The seven scale degrees, correctly spelled.
    public let scale: [NoteSpelling]
    /// The seven diatonic triads, with Roman numerals.
    public let chords: [Chord]
    /// Borrowed/harmonic-minor chords: for minor keys the major V and the vii°;
    /// for major keys this is empty.
    public let secondaryChords: [Chord]
    /// A handful of idiomatic progressions for the key's mode.
    public let progressions: [Progression]
    /// The relative key (shares the same notes, opposite mode).
    public let relativeKey: MusicalKey
    /// The parallel key (same tonic, opposite mode).
    public let parallelKey: MusicalKey

    public init(
        key: MusicalKey,
        scale: [NoteSpelling],
        chords: [Chord],
        secondaryChords: [Chord],
        progressions: [Progression],
        relativeKey: MusicalKey,
        parallelKey: MusicalKey
    ) {
        self.key = key
        self.scale = scale
        self.chords = chords
        self.secondaryChords = secondaryChords
        self.progressions = progressions
        self.relativeKey = relativeKey
        self.parallelKey = parallelKey
    }
}

/// Producer-mode music theory: scale spelling, diatonic harmony, and progressions.
public enum Diatonic {

    /// The seven letters in order, used to walk a scale.
    private static let letters: [Character] = ["C", "D", "E", "F", "G", "A", "B"]

    /// Natural pitch class of each letter.
    private static let naturalPitchClass: [Character: Int] =
        ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    /// Semitone intervals from the tonic for each mode.
    private static func intervals(for mode: Mode) -> [Int] {
        switch mode {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        }
    }

    /// Triad qualities for each scale degree.
    private static func qualities(for mode: Mode) -> [ChordQuality] {
        switch mode {
        case .major: return [.major, .minor, .minor, .major, .major, .minor, .diminished]
        case .minor: return [.minor, .diminished, .major, .minor, .minor, .major, .major]
        }
    }

    /// Roman numerals for each scale degree.
    private static func romanNumerals(for mode: Mode) -> [String] {
        switch mode {
        case .major: return ["I", "ii", "iii", "IV", "V", "vi", "vii°"]
        case .minor: return ["i", "ii°", "III", "iv", "v", "VI", "VII"]
        }
    }

    /// Spell the diatonic scale of `key`, choosing the right accidental for each
    /// consecutive letter so that e.g. A-minor is `A B C D E F G`.
    private static func spellScale(_ key: MusicalKey) -> [NoteSpelling] {
        let startLetter = key.tonicSpelling.letter
        let startIndex = letters.firstIndex(of: startLetter) ?? 0
        let stepIntervals = intervals(for: key.mode)

        return (0..<7).map { degree in
            let letter = letters[(startIndex + degree) % 7]
            let targetPC = (key.tonic + stepIntervals[degree]) % 12
            let naturalPC = naturalPitchClass[letter] ?? 0
            // Nearest signed difference, wrapped into -6…+6.
            var diff = targetPC - naturalPC
            if diff > 6 { diff -= 12 }
            if diff < -6 { diff += 12 }
            return NoteSpelling(letter: letter, accidental: diff)
        }
    }

    /// Spell a single note for a given letter so that it lands on `targetPC`.
    private static func spell(letter: Character, targetPC: Int) -> NoteSpelling {
        let naturalPC = naturalPitchClass[letter] ?? 0
        var diff = (targetPC % 12) - naturalPC
        if diff > 6 { diff -= 12 }
        if diff < -6 { diff += 12 }
        return NoteSpelling(letter: letter, accidental: diff)
    }

    /// Build the seven diatonic triads from a spelled scale.
    private static func diatonicChords(scale: [NoteSpelling], mode: Mode) -> [Chord] {
        let q = qualities(for: mode)
        let r = romanNumerals(for: mode)
        return (0..<7).map { i in
            Chord(root: scale[i], quality: q[i], roman: r[i])
        }
    }

    /// Compute the full diatonic analysis for a key.
    public static func analyze(_ key: MusicalKey) -> DiatonicAnalysis {
        let scale = spellScale(key)
        let chords = diatonicChords(scale: scale, mode: key.mode)

        // Relative & parallel keys.
        let relativeKey: MusicalKey
        switch key.mode {
        case .major: relativeKey = MusicalKey(tonic: key.tonic - 3, mode: .minor)
        case .minor: relativeKey = MusicalKey(tonic: key.tonic + 3, mode: .major)
        }
        let parallelKey = MusicalKey(tonic: key.tonic, mode: key.mode == .major ? .minor : .major)

        // Secondary (harmonic-minor) chords.
        let secondaryChords: [Chord]
        switch key.mode {
        case .major:
            secondaryChords = []
        case .minor:
            // Harmonic-minor V: a MAJOR triad built on the 5th scale degree.
            let vRoot = scale[4]
            let v = Chord(root: vRoot, quality: .major, roman: "V")

            // vii°: DIMINISHED on the raised 7th (leading tone, tonic + 11).
            let leadingPC = (key.tonic + 11) % 12
            // Spell the leading tone from the letter a step below the tonic letter,
            // i.e. the natural 7th letter of the scale (degree 6).
            let leadingLetter = scale[6].letter
            let viiRoot = spell(letter: leadingLetter, targetPC: leadingPC)
            let viiDim = Chord(root: viiRoot, quality: .diminished, roman: "vii°")

            secondaryChords = [v, viiDim]
        }

        // Quick lookups for progression building.
        // Diatonic chords by Roman numeral.
        var byRoman: [String: Chord] = [:]
        for chord in chords { byRoman[chord.roman] = chord }
        // Harmonic-minor V (major) for minor-key progressions that need it.
        let harmonicV = secondaryChords.first { $0.roman == "V" }

        func chord(forRoman roman: String) -> Chord {
            byRoman[roman] ?? chords[0]
        }

        let progressions: [Progression]
        switch key.mode {
        case .major:
            progressions = [
                progression("Pop  I–V–vi–IV",   ["I", "V", "vi", "IV"], chord),
                progression("Classic  I–IV–V",  ["I", "IV", "V"],       chord),
                progression("50s  I–vi–IV–V",   ["I", "vi", "IV", "V"], chord),
                progression("Jazz  ii–V–I",     ["ii", "V", "I"],       chord),
            ]
        case .minor:
            // For the "Tension" progression, use the harmonic-minor major V.
            let vChord = harmonicV ?? chord(forRoman: "v")
            progressions = [
                progression("Anthem  i–VI–III–VII", ["i", "VI", "III", "VII"], chord),
                progression("Drive  i–VII–VI–VII",  ["i", "VII", "VI", "VII"], chord),
                progression("Lament  i–iv–v",       ["i", "iv", "v"],          chord),
                Progression(
                    label: "Tension  i–iv–V",
                    romanNumerals: ["i", "iv", "V"],
                    chords: [chord(forRoman: "i"), chord(forRoman: "iv"), vChord]
                ),
            ]
        }

        return DiatonicAnalysis(
            key: key,
            scale: scale,
            chords: chords,
            secondaryChords: secondaryChords,
            progressions: progressions,
            relativeKey: relativeKey,
            parallelKey: parallelKey
        )
    }

    /// Helper that maps a list of Roman numerals to diatonic chords.
    private static func progression(
        _ label: String,
        _ romanNumerals: [String],
        _ resolve: (String) -> Chord
    ) -> Progression {
        Progression(
            label: label,
            romanNumerals: romanNumerals,
            chords: romanNumerals.map(resolve)
        )
    }
}
