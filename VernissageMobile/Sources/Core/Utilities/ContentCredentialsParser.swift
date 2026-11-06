//
//  https://mczachurski.dev
//  Copyright © 2026 Marcin Czachurski and the repository contributors.
//  Licensed under the Apache License 2.0.
//

import Foundation

/// Normalizes the SDK's manifest store using the same rules as VernissageWeb's C2paService.
struct ContentCredentialsParser {
    func parse(_ data: Data, imageURL: URL) throws -> ContentCredentials? {
        let store = try JSONDecoder().decode(ContentCredentialsJSON.self, from: data)

        guard let label = store["active_manifest"]?.string,
              let manifest = store["manifests"]?[label],
              case .object = manifest,
              let verifyURL = verificationURL(for: imageURL) else {
            return nil
        }

        let manifests = store["manifests"]?.object ?? [:]
        let errors = validationErrors(store: store, manifest: manifest)
        let state = store["validation_state"]?.string
        let allActions = actions(manifest)

        return ContentCredentials(
            imageURL: imageURL,
            author: author(manifest),
            appOrDeviceUsed: appOrDeviceUsed(manifest, manifests: manifests),
            aiGenerated: isAIGenerated(manifest, manifests: manifests),
            identity: identity(manifest),
            actions: actionsLabel(allActions),
            title: manifest["title"]?.string,
            format: manifest["format"]?.string,
            claimGenerator: claimGenerator(manifest),
            softwareAgent: softwareAgent(manifest),
            signatureIssuer: manifest["signature_info"]?["issuer"]?.string,
            signatureTime: manifest["signature_info"]?["time"]?.string,
            ingredientsCount: manifest["ingredients"]?.array.count ?? 0,
            actionsCount: allActions.count,
            validationStatuses: validationStatuses(store["validation_status"])
                + validationStatuses(manifest["validation_status"]),
            verificationStatus: verificationStatus(state: state, errors: errors),
            validationErrors: errors,
            validationState: state,
            verifyURL: verifyURL,
            manifest: manifest
        )
    }

    private func verificationURL(for imageURL: URL) -> URL? {
        var components = URLComponents(string: AppConstants.ContentCredentials.verifySiteURL)
        components?.queryItems = [URLQueryItem(name: "url", value: imageURL.absoluteString)]
        return components?.url
    }

    private func assertions(_ manifest: ContentCredentialsJSON) -> [ContentCredentialsJSON] {
        manifest["assertions"]?.array ?? []
    }

    private func actions(_ manifest: ContentCredentialsJSON) -> [ContentCredentialsJSON] {
        assertions(manifest).flatMap { assertion in
            assertion["data"]?["actions"]?.array ?? []
        }
    }

    private func actionsLabel(_ actions: [ContentCredentialsJSON]) -> String? {
        var seenActions = Set<String>()
        let names = actions
            .compactMap { $0["action"]?.displayString }
            .map { String($0.trimmingPrefix("c2pa.")).replacing("_", with: " ") }
            .filter { seenActions.insert($0).inserted }

        return names.isEmpty ? nil : names.joined(separator: ", ")
    }

    private func author(_ manifest: ContentCredentialsJSON) -> String? {
        let assertion = assertions(manifest).first { assertion in
            assertion["label"]?.string?.contains("schema-org.CreativeWork") == true
        }
        let data = assertion?["data"]
        return data?["author"]?.displayString ?? data?["creator"]?.displayString
    }

    private func identity(_ manifest: ContentCredentialsJSON) -> String? {
        let assertion = assertions(manifest).first { assertion in
            assertion["label"]?.string == "cawg.identity"
        }
        return assertion?["data"]?["signature_info"]?["issuer"]?.displayString ?? author(manifest)
    }

    private func appOrDeviceUsed(
        _ manifest: ContentCredentialsJSON,
        manifests: [String: ContentCredentialsJSON]
    ) -> String? {
        // An edited photo can retain the camera's claim generator in its parent ingredient.
        let parentLabel = manifest["ingredients"]?.array
            .compactMap { $0["active_manifest"]?.string }
            .first
        let parent = parentLabel.flatMap { manifests[$0] }
        return parent.flatMap(claimGenerator) ?? claimGenerator(manifest)
    }

    private func claimGenerator(_ manifest: ContentCredentialsJSON) -> String? {
        let info = manifest["claim_generator_info"]?.array.first { info in
            info["name"]?.string != nil
        }
        return normalizedName(info) ?? normalize(manifest["claim_generator"]?.string)
    }

    private func softwareAgent(_ manifest: ContentCredentialsJSON) -> String? {
        let action = actions(manifest).first { action in
            action["softwareAgent"] != nil
        }
        return normalizedName(action?["softwareAgent"])
    }

    private func normalizedName(_ value: ContentCredentialsJSON?) -> String? {
        if let string = value?.string {
            return normalize(string)
        }

        guard let name = value?["name"]?.displayString else {
            return nil
        }

        let version = value?["version"]?.displayString
        return normalize(version.map { "\(name) \($0)" } ?? name)
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value
            .replacing("_", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func isAIGenerated(
        _ manifest: ContentCredentialsJSON,
        manifests: [String: ContentCredentialsJSON]
    ) -> Bool {
        var pending = [manifest]
        var visited = Set<String>()

        // Follow ingredient references because an AI declaration may exist only in an earlier manifest.
        // Manifest references form a graph; tracking labels prevents cycles from repeating indefinitely.
        while let current = pending.popLast() {
            if hasAIDigitalSourceType(current) || hasAITextMarker(current) {
                return true
            }

            for ingredient in current["ingredients"]?.array ?? [] {
                guard let label = ingredient["active_manifest"]?.string,
                      visited.insert(label).inserted,
                      let related = manifests[label] else {
                    continue
                }

                pending.append(related)
            }
        }

        return false
    }

    private func hasAIDigitalSourceType(_ manifest: ContentCredentialsJSON) -> Bool {
        actions(manifest).contains { action in
            let source = action["digitalSourceType"]?.displayString?.lowercased() ?? ""
            return AppConstants.ContentCredentials.aiDigitalSourceMarkers.contains { marker in
                source.contains(marker)
            }
        }
    }

    private func hasAITextMarker(_ manifest: ContentCredentialsJSON) -> Bool {
        let metadata = [
            claimGenerator(manifest),
            softwareAgent(manifest),
            manifest["signature_info"]?["issuer"]?.string,
            manifest["signature_info"]?["common_name"]?.string
        ]
        let actionMetadata = actions(manifest).flatMap { action in
            [
                action["description"]?.displayString,
                action["action"]?.displayString,
                normalizedName(action["softwareAgent"])
            ]
        }
        let values = (metadata + actionMetadata).compactMap { $0?.lowercased() }

        return values.contains { value in
            AppConstants.ContentCredentials.aiTextMarkers.contains { marker in
                value.contains(marker)
            }
        }
    }

    private func verificationStatus(
        state: String?,
        errors: [ContentCredentialsValidationStatus]
    ) -> ContentCredentialsVerification {
        if state == "Invalid" || !errors.isEmpty {
            return .invalid
        }

        switch state {
        case "Trusted":
            return .verified
        case "Valid":
            return .untrusted
        default:
            return .unknown
        }
    }

    private func validationErrors(
        store: ContentCredentialsJSON,
        manifest: ContentCredentialsJSON
    ) -> [ContentCredentialsValidationStatus] {
        // SDK versions report failures in either legacy status arrays or structured results.
        let failures = statusesForFailures(store["validation_status"])
            + statusesForFailures(manifest["validation_status"])
            + validationFailures(store["validation_results"])
            + validationFailures(manifest["validation_results"])
        var errors: [ContentCredentialsValidationStatus] = []

        // An untrusted issuer does not invalidate integrity. Keep all other failures and
        // deduplicate by code and explanation, preserving the first occurrence as on the web.
        for failure in failures where failure.code != "signingCredential.untrusted" {
            let alreadyIncluded = errors.contains { error in
                error.code == failure.code && error.explanation == failure.explanation
            }

            if !alreadyIncluded {
                errors.append(failure)
            }
        }

        return errors
    }

    private func validationStatuses(_ value: ContentCredentialsJSON?) -> [ContentCredentialsValidationStatus] {
        (value?.array ?? []).map { status in
            ContentCredentialsValidationStatus(
                code: status["code"]?.string,
                explanation: status["explanation"]?.string,
                success: status["success"]?.bool
            )
        }
    }

    private func statusesForFailures(_ value: ContentCredentialsJSON?) -> [ContentCredentialsValidationStatus] {
        let failures = (value?.array ?? []).filter { status in
            status["success"]?.bool == false
        }
        return validationStatuses(.array(failures))
    }

    private func validationFailures(_ value: ContentCredentialsJSON?) -> [ContentCredentialsValidationStatus] {
        let activeManifestFailures = validationStatuses(value?["activeManifest"]?["failure"])
        let ingredientFailures = (value?["ingredientDeltas"]?.array ?? []).flatMap { ingredient in
            validationStatuses(ingredient["validationDeltas"]?["failure"])
        }
        return activeManifestFailures + ingredientFailures
    }
}
