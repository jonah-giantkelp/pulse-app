import Foundation

@MainActor
final class SettingsStore: ObservableObject {
    @Published var email = ""
    @Published var digestEnabled = false
    @Published var cities: [String] = []
    @Published var countries: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var statusMessage: String?
    @Published var errorMessage: String?

    private let api: APIClient

    init(api: APIClient) {
        self.api = api
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            apply(try await api.emailPreferences())
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save() async {
        isSaving = true
        statusMessage = nil
        errorMessage = nil
        defer { isSaving = false }
        do {
            let saved = try await api.updateEmailPreferences(
                email: email.trimmingCharacters(in: .whitespaces),
                digestEnabled: digestEnabled,
                cities: cities,
                countries: countries.map { $0.uppercased() }
            )
            apply(saved)
            statusMessage = "SAVED"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ prefs: EmailPreferences) {
        email = prefs.email ?? ""
        digestEnabled = prefs.digestEnabled
        cities = prefs.defaultCities
        countries = prefs.defaultCountries
    }
}
