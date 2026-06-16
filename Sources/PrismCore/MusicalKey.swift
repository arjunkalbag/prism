import Foundation

/// Major or minor — the two modes Prism detects.
public enum Mode: String, Codable, Sendable, CaseIterable {
    case major
    case minor

    public var longName: String { self == .major ? "major" : "minor" }

    /// Camelot letter convention: A = minor, B = major.
    public var camelotLetter: String { self == .major ? "B" : "A" }
}

/// A note spelled with a letter (C…B) and an accidental in semitones
/// (-1 = flat, 0 = natural, +1 = sharp, +2 = double sharp, etc.).
///
/// Spelling matters in Producer mode: the A-minor scale is `A B C D E F G`,
/// not `A B C D E E# G`. Storing a letter + accidental (rather than a raw
/// pitch class) lets the theory layer spell scales and chords correctly.
public struct NoteSpelling: Hashable, Codable, Sendable {
    /// One of C D E F G A B.
    public let letter: Character
    /// Semitone offset from the natural letter.
    public let accidental: Int

    public init(letter: Character, accidental: Int) {
        self.letter = letter
        self.accidental = accidental
    }

    // `Character` is not `Codable`, so encode `letter` as a single-character
    // `String` and validate on decode. Keeps the public API unchanged.
    private enum CodingKeys: String, CodingKey { case letter, accidental }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let s = try c.decode(String.self, forKey: .letter)
        guard let ch = s.first, s.count == 1 else {
            throw DecodingError.dataCorruptedError(
                forKey: .letter, in: c,
                debugDescription: "letter must be a single character")
        }
        self.letter = ch
        self.accidental = try c.decode(Int.self, forKey: .accidental)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(String(letter), forKey: .letter)
        try c.encode(accidental, forKey: .accidental)
    }

    private static let naturalPitchClass: [Character: Int] =
        ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    /// Pitch class 0…11 (C = 0).
    public var pitchClass: Int {
        let base = NoteSpelling.naturalPitchClass[letter] ?? 0
        return (((base + accidental) % 12) + 12) % 12
    }

    /// Rendered symbol, e.g. "C", "F#", "Bb", "F##".
    public var symbol: String {
        let acc: String
        if accidental > 0 {
            acc = String(repeating: "#", count: accidental)
        } else if accidental < 0 {
            acc = String(repeating: "b", count: -accidental)
        } else {
            acc = ""
        }
        return "\(letter)\(acc)"
    }
}

/// A musical key: a tonic pitch class plus a mode.
///
/// `tonic` is a pitch class 0…11 where C = 0, C# = 1, … B = 11.
public struct MusicalKey: Hashable, Codable, Sendable {
    public let tonic: Int
    public let mode: Mode

    public init(tonic: Int, mode: Mode) {
        self.tonic = ((tonic % 12) + 12) % 12
        self.mode = mode
    }

    /// All 24 keys, ordered C major, C minor, C# major, C# minor, …
    public static var all: [MusicalKey] {
        (0..<12).flatMap { pc in
            [MusicalKey(tonic: pc, mode: .major), MusicalKey(tonic: pc, mode: .minor)]
        }
    }

    /// Canonical tonic spelling, matching standard notation and the Camelot chart
    /// (e.g. major index 6 → Gb, minor index 3 → Eb, minor index 8 → G#).
    public var tonicSpelling: NoteSpelling {
        MusicalKey.canonicalSpelling(tonic: tonic, mode: mode)
    }

    /// Compact name, e.g. "C", "Am", "F#m", "Bb".
    public var shortName: String {
        mode == .major ? tonicSpelling.symbol : "\(tonicSpelling.symbol)m"
    }

    /// Full name, e.g. "C major", "A minor".
    public var displayName: String {
        "\(tonicSpelling.symbol) \(mode.longName)"
    }

    static func canonicalSpelling(tonic: Int, mode: Mode) -> NoteSpelling {
        let pc = ((tonic % 12) + 12) % 12
        switch mode {
        case .major:
            // C, Db, D, Eb, E, F, Gb, G, Ab, A, Bb, B
            let table: [NoteSpelling] = [
                .init(letter: "C", accidental: 0),  .init(letter: "D", accidental: -1),
                .init(letter: "D", accidental: 0),  .init(letter: "E", accidental: -1),
                .init(letter: "E", accidental: 0),  .init(letter: "F", accidental: 0),
                .init(letter: "G", accidental: -1), .init(letter: "G", accidental: 0),
                .init(letter: "A", accidental: -1), .init(letter: "A", accidental: 0),
                .init(letter: "B", accidental: -1), .init(letter: "B", accidental: 0),
            ]
            return table[pc]
        case .minor:
            // Cm, C#m, Dm, Ebm, Em, Fm, F#m, Gm, G#m, Am, Bbm, Bm
            let table: [NoteSpelling] = [
                .init(letter: "C", accidental: 0), .init(letter: "C", accidental: 1),
                .init(letter: "D", accidental: 0), .init(letter: "E", accidental: -1),
                .init(letter: "E", accidental: 0), .init(letter: "F", accidental: 0),
                .init(letter: "F", accidental: 1), .init(letter: "G", accidental: 0),
                .init(letter: "G", accidental: 1), .init(letter: "A", accidental: 0),
                .init(letter: "B", accidental: -1), .init(letter: "B", accidental: 0),
            ]
            return table[pc]
        }
    }
}
