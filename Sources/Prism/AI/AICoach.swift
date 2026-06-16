import Foundation
import PrismCore

/// One creative direction returned by the optional AI layer.
struct AISuggestion: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let detail: String
}

/// Optional Anthropic-backed "creative directions" for Producer mode.
///
/// Never required: the live readout and deterministic suggestions work fully
/// with AI switched off. The key is read from `ANTHROPIC_API_KEY` (or
/// `~/.prism/anthropic_key`) — never hardcoded. Uses a fast model by default.
final class AICoach {
    enum CoachError: Error, LocalizedError {
        case notConfigured
        case http(Int, String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "Set ANTHROPIC_API_KEY to enable AI suggestions."
            case .http(let code, _): return "Anthropic API error (HTTP \(code))."
            case .emptyResponse: return "The model returned no usable suggestions."
            }
        }
    }

    private let model = "claude-haiku-4-5-20251001"
    private let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!

    var apiKey: String? {
        if let env = ProcessInfo.processInfo.environment["ANTHROPIC_API_KEY"],
           !env.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return env.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".prism/anthropic_key")
        if let s = try? String(contentsOf: url, encoding: .utf8) {
            let t = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return t.isEmpty ? nil : t
        }
        return nil
    }

    var isConfigured: Bool { apiKey != nil }

    func suggestions(for key: MusicalKey) async throws -> [AISuggestion] {
        guard let apiKey else { throw CoachError.notConfigured }

        let dia = Diatonic.analyze(key)
        let chords = dia.chords.map { $0.symbol }.joined(separator: " ")
        let prompt = """
        You are a concise music-production assistant. The track's detected key is \
        \(key.displayName) (Camelot \(Camelot.code(for: key).code)). Diatonic chords: \(chords).
        Give exactly 3 concrete creative directions for writing in this key — borrowed chords, \
        modal interchange, chord moves, or arrangement ideas. Each needs a 2–4 word title and a \
        single-sentence rationale. Respond with ONLY JSON, no prose, in this exact shape:
        {"ideas":[{"title":"...","detail":"..."},{"title":"...","detail":"..."},{"title":"...","detail":"..."}]}
        """

        var req = URLRequest(url: endpoint)
        req.httpMethod = "POST"
        req.timeoutInterval = 30
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 512,
            "messages": [["role": "user", "content": prompt]],
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw CoachError.emptyResponse }
        guard http.statusCode == 200 else {
            throw CoachError.http(http.statusCode, String(data: data, encoding: .utf8) ?? "")
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        let text = decoded.content.first(where: { $0.type == "text" })?.text ?? ""
        guard let ideas = Self.parseIdeas(from: text), !ideas.isEmpty else {
            throw CoachError.emptyResponse
        }
        return ideas.map { AISuggestion(title: $0.title, detail: $0.detail) }
    }

    // Extract the JSON object from the model text (tolerant of stray prose / fences).
    private static func parseIdeas(from text: String) -> [Idea]? {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}") else { return nil }
        let json = String(text[start...end])
        guard let data = json.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(IdeaWrapper.self, from: data) else { return nil }
        return wrapper.ideas
    }

    private struct AnthropicResponse: Decodable {
        struct Block: Decodable { let type: String; let text: String? }
        let content: [Block]
    }
    private struct IdeaWrapper: Decodable { let ideas: [Idea] }
    private struct Idea: Decodable { let title: String; let detail: String }
}
