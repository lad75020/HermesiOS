//
//  HermesOfficeView.swift
//  HermesiOS
//

import SwiftUI

struct HermesOfficeSettingsSection: View {
    @AppStorage(hermesMacHostStorageKey) private var macHost = defaultHermesMacHost
    @AppStorage(hermesOfficePortStorageKey) private var officePort = defaultHermesOfficePort
    @State private var officeReturnsHTTP200 = false

    private var officeURLString: String {
        HermesHostEndpoints.httpURLString(host: macHost, port: officePort)
    }

    var body: some View {
        Section("Office") {
            HStack(alignment: .center, spacing: 10) {
                HermesSettingsStatusLED(
                    isOn: officeReturnsHTTP200,
                    label: officeReturnsHTTP200 ? "Office URL returns HTTP 200" : "Office URL does not return HTTP 200"
                )

                TextField("TCP port, e.g. 9116", text: $officePort)
                    .keyboardType(.numberPad)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .hermesRuntimeInput()
            }

            Text("Office URL: \(officeURLString)")
                .font(.caption)
                .foregroundStyle(.hermesSecondaryText)
        }
        .task(id: officeURLString) {
            await runOfficeStatusLoop()
        }
    }

    private func runOfficeStatusLoop() async {
        while !Task.isCancelled {
            officeReturnsHTTP200 = await checkOfficeURLReturnsHTTP200()
            do {
                try await Task.sleep(for: .seconds(3))
            } catch {
                return
            }
        }
    }

    private func checkOfficeURLReturnsHTTP200() async -> Bool {
        let trimmedURL = officeURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return false
        }

        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 2)
        request.httpMethod = "GET"

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2
        configuration.timeoutIntervalForResource = 2
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        do {
            let (_, response) = try await session.data(for: request)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}
