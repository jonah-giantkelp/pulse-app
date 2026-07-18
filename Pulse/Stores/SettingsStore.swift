import Foundation
import UIKit
import UserNotifications

extension Notification.Name {
    static let pulsePushToken = Notification.Name("pulsePushToken")
}

/// Preferences auto-save on every change — no save button.
@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var newsletterEnabled = false
    @Published private(set) var recipients: [String] = []
    @Published private(set) var pushEnabled = false
    @Published private(set) var cities: [String] = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private let api: APIClient
    private var deviceToken: String?
    private static let tokenKey = "pushDeviceToken"

    init(api: APIClient) {
        self.api = api
        deviceToken = UserDefaults.standard.string(forKey: Self.tokenKey)
        NotificationCenter.default.addObserver(
            forName: .pulsePushToken, object: nil, queue: .main
        ) { [weak self] note in
            guard let token = note.object as? String else { return }
            Task { @MainActor in self?.receivedDeviceToken(token) }
        }
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let prefs = try await api.emailPreferences()
            newsletterEnabled = prefs.digestEnabled
            recipients = prefs.recipients ?? (prefs.email.map { [$0] } ?? [])
            pushEnabled = prefs.pushEnabled ?? false
            cities = prefs.defaultCities
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Newsletter

    func setNewsletter(_ on: Bool) {
        newsletterEnabled = on
        persist()
    }

    static let maxRecipients = 5

    func addRecipient(_ raw: String) {
        let email = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard recipients.count < Self.maxRecipients,
              email.contains("@"), email.contains("."), !recipients.contains(email) else { return }
        recipients.append(email)
        persist()
    }

    func updateRecipient(_ original: String, to raw: String) {
        let email = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard email.contains("@"), email.contains("."),
              let index = recipients.firstIndex(of: original) else { return }
        recipients[index] = email
        persist()
    }

    func removeRecipient(_ email: String) {
        recipients.removeAll { $0 == email }
        persist()
    }

    // MARK: - Push notifications

    func setPush(_ on: Bool) {
        pushEnabled = on
        persist()
        if on {
            Task { await enablePush() }
        } else if let token = deviceToken {
            Task { try? await api.deletePushToken(token) }
        }
    }

    private func enablePush() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            guard granted else {
                errorMessage = "Notifications are off for Pulse in iOS Settings"
                pushEnabled = false
                persist()
                return
            }
            UIApplication.shared.registerForRemoteNotifications()
            if let token = deviceToken {
                try await api.registerPushToken(token)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func receivedDeviceToken(_ token: String) {
        deviceToken = token
        UserDefaults.standard.set(token, forKey: Self.tokenKey)
        if pushEnabled {
            Task { try? await api.registerPushToken(token) }
        }
    }

    // MARK: - Account

    func deleteAccount() async -> Bool {
        do {
            try await api.deleteAccount()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    private func persist() {
        Task {
            do {
                _ = try await api.updateEmailPreferences(
                    digestEnabled: newsletterEnabled,
                    recipients: recipients,
                    pushEnabled: pushEnabled
                )
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
