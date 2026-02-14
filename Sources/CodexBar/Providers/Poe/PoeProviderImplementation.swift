import AppKit
import CodexBarCore
import CodexBarMacroSupport
import Foundation
import SwiftUI

@ProviderImplementationRegistration
struct PoeProviderImplementation: ProviderImplementation {
    let id: UsageProvider = .poe

    @MainActor
    func presentation(context _: ProviderPresentationContext) -> ProviderPresentation {
        ProviderPresentation { _ in "api" }
    }

    @MainActor
    func observeSettings(_ settings: SettingsStore) {
        _ = settings.poeAPIToken
    }

    @MainActor
    func settingsSnapshot(context: ProviderSettingsSnapshotContext) -> ProviderSettingsSnapshotContribution? {
        _ = context
        return .poe(context.settings.poeSettingsSnapshot())
    }

    @MainActor
    func isAvailable(context: ProviderAvailabilityContext) -> Bool {
        if PoeSettingsReader.apiKey(environment: context.environment) != nil {
            return true
        }
        context.settings.ensurePoeAPITokenLoaded()
        return !context.settings.poeAPIToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @MainActor
    func settingsPickers(context: ProviderSettingsContext) -> [ProviderSettingsPickerDescriptor] {
        _ = context
        return []
    }

    @MainActor
    func settingsFields(context: ProviderSettingsContext) -> [ProviderSettingsFieldDescriptor] {
        let quotaBinding = Binding(
            get: {
                let quota = context.settings.poeMonthlyQuota
                return quota > 0 ? String(quota) : ""
            },
            set: { newValue in
                if let intValue = Int(newValue) {
                    context.settings.poeMonthlyQuota = intValue
                } else if newValue.isEmpty {
                    context.settings.poeMonthlyQuota = 0
                }
            })

        return [
            ProviderSettingsFieldDescriptor(
                id: "poe-api-key",
                title: "API Key",
                subtitle: "Stored in ~/.codexbar/config.json. Get your key from poe.com/settings",
                kind: .secure,
                placeholder: "Paste key…",
                binding: context.stringBinding(\.poeAPIToken),
                actions: [],
                isVisible: nil,
                onActivate: { context.settings.ensurePoeAPITokenLoaded() }),
            ProviderSettingsFieldDescriptor(
                id: "poe-monthly-quota",
                title: "Monthly Quota",
                subtitle: "Your Poe monthly point quota (leave empty for default 1,000,000)",
                kind: .plain,
                placeholder: "1000000",
                binding: quotaBinding,
                actions: [],
                isVisible: nil,
                onActivate: nil)
        ]
    }
}
