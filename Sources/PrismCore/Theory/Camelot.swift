import Foundation

/// A position on the Camelot wheel — the DJ-friendly relabelling of the circle
/// of fifths used for harmonic mixing.
///
/// Each of the 24 keys maps to a number `1…12` and a letter: `A` for minor,
/// `B` for major (matching ``Mode/camelotLetter``). For example C major is
/// `8B`, A minor is `8A`, and E minor is `9A`.
public struct Camelot: Hashable, Sendable {
    /// Wheel number, `1…12`.
    public let number: Int
    /// Mode (which also fixes the letter: `A` minor, `B` major).
    public let mode: Mode

    public init(number: Int, mode: Mode) {
        self.number = number
        self.mode = mode
    }

    /// Camelot code, e.g. `"8A"` (minor) or `"8B"` (major).
    public var code: String {
        "\(number)\(mode.camelotLetter)"
    }

    /// Parse a Camelot code such as `"8A"`, `"12b"`, `"3B"` (case-insensitive).
    ///
    /// Returns `nil` if the string is malformed or the number is outside `1…12`.
    public init?(code: String) {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last else { return nil }

        let mode: Mode
        switch last {
        case "A", "a": mode = .minor
        case "B", "b": mode = .major
        default: return nil
        }

        let digits = trimmed.dropLast()
        guard !digits.isEmpty, let number = Int(digits), (1...12).contains(number) else {
            return nil
        }

        self.number = number
        self.mode = mode
    }

    // MARK: - Lookup tables (index = pitch class 0…11)

    /// Camelot number for a major key, indexed by tonic pitch class.
    static let majorNumbers: [Int] = [8, 3, 10, 5, 12, 7, 2, 9, 4, 11, 6, 1]
    /// Camelot number for a minor key, indexed by tonic pitch class.
    static let minorNumbers: [Int] = [5, 12, 7, 2, 9, 4, 11, 6, 1, 8, 3, 10]

    /// The Camelot position for a given musical key.
    public static func code(for key: MusicalKey) -> Camelot {
        let number: Int
        switch key.mode {
        case .major: number = majorNumbers[key.tonic]
        case .minor: number = minorNumbers[key.tonic]
        }
        return Camelot(number: number, mode: key.mode)
    }

    /// The musical key occupying this Camelot position (inverse of the lookup tables).
    public func key() -> MusicalKey {
        let table = mode == .major ? Camelot.majorNumbers : Camelot.minorNumbers
        // The tables are permutations of 1…12, so a matching index always exists.
        let tonic = table.firstIndex(of: number) ?? 0
        return MusicalKey(tonic: tonic, mode: mode)
    }
}
