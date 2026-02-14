import CodexBarCore
import Foundation

extension SettingsStore {
    var poeAPIToken: String {
        get { self.configSnapshot.providerConfig(for: .poe)?.sanitizedAPIKey ?? "" }
        set {
            self.updateProviderConfig(provider: .poe) { entry in
                entry.apiKey = self.normalizedConfigValue(newValue)
            }
            self.logSecretUpdate(provider: .poe, field: "apiKey", value: newValue)
        }
    }

    var poeMonthlyQuota: Int {
        get { self.configSnapshot.providerConfig(for: .poe)?.monthlyQuota ?? 0 }
        set {
            self.updateProviderConfig(provider: .poe) { entry in
                entry.monthlyQuota = newValue
            }
        }
    }

    func ensurePoeAPITokenLoaded() {}
}

extension SettingsStore {
    func poeSettingsSnapshot() -> ProviderSettingsSnapshot.PoeProviderSettings {
        let quota = self.poeMonthlyQuota
        return ProviderSettingsSnapshot.PoeProviderSettings(
            monthlyQuota: quota > 0 ? quota : nil)
    }
}
