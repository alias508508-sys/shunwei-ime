import AppKit
import InputMethodKit

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
if CommandLine.arguments.contains("--smoke-test") {
    let engine = Engine.shared
    guard let url = Bundle.main.url(forResource: "fixtures", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let fixtures = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { exit(1) }
    for fixture in fixtures {
        let raw = fixture["raw"] as! String
        let expected = fixture["candidates"] as! [String]
        guard let result = engine.decode(raw, cursor: (raw as NSString).length, mode: "auto", sessionId: "fixture", revision: 1), result.candidates.map({ $0.text }) == expected else {
            fputs("Native decoder failed: \(engine.error ?? raw)\n", stderr); exit(1)
        }
    }
    print("JavaScriptCore parity OK: \(fixtures.count) fixtures match web core")
    exit(0)
}
_ = Engine.shared
if CommandLine.arguments.contains("--controller-test") { nativeChecks(); exit(0) }
guard let server = IMKServer(name: "ShunwriteConnection", bundleIdentifier: "org.shunwrite.inputmethod.Shunwrite") else { fputs("IMKServer initialization failed\n", stderr); exit(1) }
if CommandLine.arguments.contains("--startup-check") {
    DispatchQueue.main.asyncAfter(deadline: .now() + 1) { print("InputMethodKit server event loop OK; host clients not tested"); application.terminate(nil) }
}
withExtendedLifetime(server) { application.run() }
