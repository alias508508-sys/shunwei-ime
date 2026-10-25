import Foundation
import JavaScriptCore

struct Candidate: Codable {
    let id: String
    let text: String
    let score: Double
    let reason: [String]
}
struct EngineResult: Codable {
    let sessionId: String
    let revision: Int
    let candidates: [Candidate]
    let rawFallback: String
}
final class Engine {
    static let shared = Engine()
    private let context: JSContext?
    private(set) var error: String?
    init() {
        context = JSContext()
        context?.exceptionHandler = { [weak self] _, exception in self?.error = exception?.toString() }
        guard let url = Bundle.main.url(forResource: "engine", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8) else {
            error = "缺少 engine.js"; return
        }
        context?.evaluateScript(script)
    }
    func decode(_ raw: String, cursor: Int, mode: String, sessionId: String, revision: Int, entries: [[String: String]] = []) -> EngineResult? {
        let request: [String: Any] = ["raw": raw, "cursor": cursor, "mode": mode, "sessionId": sessionId, "revision": revision]
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let json = String(data: data, encoding: .utf8),
              let entryData = try? JSONSerialization.data(withJSONObject: entries),
              let entryJSON = String(data: entryData, encoding: .utf8),
              let function = context?.objectForKeyedSubscript("SmartEngine")?.objectForKeyedSubscript("decodeJSON"),
              let output = function.call(withArguments: [json, entryJSON])?.toString(),
              let resultData = output.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(EngineResult.self, from: resultData)
    }
}
