import XCTest
@testable import HermesiOS

final class HermesPhotonGatewayTests: XCTestCase {
    func testHostPhotonCatalogDecodesWithoutClientPlatformAllowlist() throws {
        let data = Data(#"""
        {
          "workspacePath":"/fixture", "resolvedWorkspacePath":"/fixture",
          "profileName":"selected", "profilePath":"/fixture/profiles/selected",
          "envFilePath":"/fixture/profiles/selected/.env",
          "configPath":"/fixture/profiles/selected/config.yaml", "gatewayRunning":false,
          "env":{"PHOTON_PROJECT_SECRET":"[configured]"}, "platformEnabled":{"photon":true},
          "fields":[
            {"key":"PHOTON_PROJECT_ID","label":"Spectrum project ID","type":"text","hint":"Fixture"},
            {"key":"PHOTON_PROJECT_SECRET","label":"Project secret","type":"password","hint":"Write-only"}
          ],
          "platforms":[{"key":"photon","label":"Photon iMessage","description":"Fixture",
                        "fields":["PHOTON_PROJECT_ID","PHOTON_PROJECT_SECRET"]}]
        }
        """#.utf8)
        let result = try JSONDecoder().decode(HermesCompanionGatewayConfigResult.self, from: data)
        let photon = try XCTUnwrap(result.platforms.first)
        XCTAssertEqual(photon.id, "photon")
        let fields = photon.fields.compactMap { key in result.fields.first { $0.key == key } }
        XCTAssertEqual(fields.map(\.key), photon.fields)
        XCTAssertEqual(fields.map(\.isSecret), [false, true])
        XCTAssertEqual(result.env["PHOTON_PROJECT_SECRET"], "[configured]")
        XCTAssertEqual(result.platformEnabled[photon.key], true)
        XCTAssertEqual(result.profileName, "selected")
    }

    func testPhotonMutationPayloadsRetainSelectedProfile() throws {
        let env = HermesCompanionSetGatewayEnvPayload(workspacePath: "/fixture", profileName: "selected", key: "PHOTON_PROJECT_SECRET", value: "fixture-replacement")
        let encoded = try JSONEncoder().encode(env)
        let decoded = try JSONDecoder().decode(HermesCompanionSetGatewayEnvPayload.self, from: encoded)
        XCTAssertEqual(decoded.profileName, "selected")
        XCTAssertEqual(decoded.key, "PHOTON_PROJECT_SECRET")
        for enabled in [false, true] {
            let payload = HermesCompanionSetGatewayPlatformPayload(workspacePath: "/fixture", profileName: "selected", platform: "photon", enabled: enabled)
            let roundTrip = try JSONDecoder().decode(HermesCompanionSetGatewayPlatformPayload.self, from: JSONEncoder().encode(payload))
            XCTAssertEqual(roundTrip.profileName, "selected")
            XCTAssertEqual(roundTrip.platform, "photon")
            XCTAssertEqual(roundTrip.enabled, enabled)
        }
    }
}
