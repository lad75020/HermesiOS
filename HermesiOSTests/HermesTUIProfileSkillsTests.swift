import XCTest
@testable import HermesiOS

@MainActor
final class HermesDashboardProfileSkillsTests: XCTestCase {
    private let settings = HermesAPISettings(baseURL: "https://100.64.0.2:8642/v1")

    private func response(_ request: URLRequest, status: Int = 200, body: String) -> (Data, URLResponse) {
        let http = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(body.utf8), http)
    }

    func testCompactDashboardSkillsDecodeWithoutDescriptions() throws {
        let skills = try JSONDecoder().decode([HermesDashboardProfileSkill].self, from: Data(#"""
        [{"name":"terminal","enabled":true,"category":""}]
        """#.utf8))
        XCTAssertEqual(skills, [HermesDashboardProfileSkill(name: "terminal", isEnabled: true)])
        XCTAssertNil(skills[0].description)
        XCTAssertFalse(skills[0].category.isEmpty)
    }

    func testLoadUsesExactSelectedProfileQueryAndSessionToken() async throws {
        let store = HermesDashboardProfileSkillsStore()
        var requests: [URLRequest] = []
        store.transportOverride = { request in
            requests.append(request)
            if request.url?.path != "/api/skills" {
                return self.response(request, body: #"window.__HERMES_SESSION_TOKEN__="token""#)
            }
            return self.response(request, body: #"[{"name":"terminal","enabled":true,"category":"system"}]"#)
        }

        let skills = try await store.load(profile: "Research", dashboardBaseURL: "https://100.64.0.2:8642", apiSettings: settings)

        XCTAssertEqual(skills.map(\.name), ["terminal"])
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(
            Set(URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []),
            Set([
                URLQueryItem(name: "profile", value: "Research"),
                URLQueryItem(name: "include_descriptions", value: "false")
            ])
        )
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "X-Hermes-Session-Token"), "token")
    }

    func testDescriptionLoadsOnlyRequestedSkillWithExactProfile() async throws {
        let store = HermesDashboardProfileSkillsStore()
        var requests: [URLRequest] = []
        store.transportOverride = { request in
            requests.append(request)
            if request.url?.path != "/api/skills/description" {
                return self.response(request, body: #"window.__HERMES_SESSION_TOKEN__="token""#)
            }
            return self.response(request, body: #"{"name":"terminal","description":"Run commands"}"#)
        }

        let description = try await store.loadDescription(
            name: "terminal",
            profile: "Research",
            dashboardBaseURL: "https://100.64.0.2:8642",
            apiSettings: settings
        )

        XCTAssertEqual(description, "Run commands")
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests[1].url?.path, "/api/skills/description")
        XCTAssertEqual(
            Set(URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []),
            Set([
                URLQueryItem(name: "name", value: "terminal"),
                URLQueryItem(name: "profile", value: "Research")
            ])
        )
        XCTAssertEqual(requests[1].value(forHTTPHeaderField: "X-Hermes-Session-Token"), "token")
    }

    func testToggleAcknowledgementThenExactProfileReadbackWithoutOptimism() async throws {
        let store = HermesDashboardProfileSkillsStore()
        var requests: [URLRequest] = []
        store.transportOverride = { request in
            requests.append(request)
            switch request.httpMethod {
            case "PUT": return self.response(request, body: #"{"ok":true,"name":"terminal","enabled":false}"#)
            case "GET" where request.url?.path == "/api/skills":
                return self.response(request, body: #"[{"name":"terminal","enabled":false,"category":"system"}]"#)
            default: return self.response(request, body: #"window.__HERMES_SESSION_TOKEN__="token""#)
            }
        }

        let readback = try await store.setEnabled(name: "terminal", enabled: false, profile: "research", dashboardBaseURL: "https://100.64.0.2:8642", apiSettings: settings)

        XCTAssertEqual(requests.map(\.httpMethod), ["GET", "PUT", "GET"])
        let body = try XCTUnwrap(requests[1].httpBody)
        let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(json?["name"] as? String, "terminal")
        XCTAssertEqual(json?["enabled"] as? Bool, false)
        XCTAssertEqual(json?["profile"] as? String, "research")
        XCTAssertEqual(
            Set(URLComponents(url: requests[2].url!, resolvingAgainstBaseURL: false)?.queryItems ?? []),
            Set([
                URLQueryItem(name: "profile", value: "research"),
                URLQueryItem(name: "include_descriptions", value: "false")
            ])
        )
        XCTAssertEqual(readback.first?.isEnabled, false)
    }

    func testToggleRetriesOnceWithFreshTokenOn401() async throws {
        let store = HermesDashboardProfileSkillsStore()
        var tokens: [String] = []
        var puts = 0
        var tokenCount = 0
        store.transportOverride = { request in
            if request.url?.path != "/api/skills" && request.httpMethod != "PUT" {
                tokenCount += 1
                return self.response(request, body: "window.__HERMES_SESSION_TOKEN__=\"token\(tokenCount)\"")
            }
            if request.httpMethod == "PUT" {
                puts += 1
                tokens.append(request.value(forHTTPHeaderField: "X-Hermes-Session-Token") ?? "")
                return puts == 1 ? self.response(request, status: 401, body: "") : self.response(request, body: #"{"ok":true,"name":"terminal","enabled":false}"#)
            }
            return self.response(request, body: #"[{"name":"terminal","enabled":false,"category":"system"}]"#)
        }

        _ = try await store.setEnabled(name: "terminal", enabled: false, profile: "research", dashboardBaseURL: "https://100.64.0.2:8642", apiSettings: settings)
        XCTAssertEqual(tokens, ["token1", "token2"])
    }
}
