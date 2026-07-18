import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var settings: SettingsStore

    @State private var cityInput = ""
    @State private var countryInput = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("SETTINGS")
                    .font(.mono(16, .bold))
                    .kerning(3)
                    .foregroundStyle(Color.pulseAccent)

                accountSection
                digestSection
                locationSection

                Button {
                    Task { await settings.save() }
                } label: {
                    if settings.isSaving {
                        ProgressView()
                            .tint(Color.pulseBg)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("SAVE PREFERENCES")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(settings.isSaving)

                if let status = settings.statusMessage {
                    Text(status)
                        .font(.mono(11, .bold))
                        .kerning(2)
                        .foregroundStyle(Color.pulseAccent)
                        .frame(maxWidth: .infinity)
                }
                if let error = settings.errorMessage {
                    Text(error.uppercased())
                        .font(.mono(11))
                        .foregroundStyle(Color.pulseDanger)
                        .frame(maxWidth: .infinity)
                }

                aboutSection
            }
            .padding(16)
        }
        .task { await settings.load() }
    }

    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(text: "Account")
            PulseCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("SIGNED IN AS")
                            .font(.mono(9))
                            .kerning(1)
                            .foregroundStyle(Color.pulseTextFaint)
                        Text(auth.email ?? "—")
                            .font(.mono(13))
                            .foregroundStyle(.white)
                    }
                    Spacer()
                    Button {
                        auth.signOut()
                    } label: {
                        Text("SIGN OUT")
                    }
                    .buttonStyle(OutlineButtonStyle(color: .pulseDanger))
                }
            }
        }
    }

    private var digestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(text: "Email digest")
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    PulseTextField(placeholder: "DIGEST EMAIL", text: $settings.email, keyboard: .emailAddress)
                    Toggle(isOn: $settings.digestEnabled) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("DAILY DIGEST")
                                .font(.mono(12, .bold))
                                .kerning(1)
                                .foregroundStyle(.white)
                            Text("NEW EVENTS FOR YOUR ARTISTS, EVERY MORNING")
                                .font(.mono(9))
                                .foregroundStyle(Color.pulseTextFaint)
                        }
                    }
                    .tint(Color.pulseAccent)
                }
            }
        }
    }

    private var locationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(text: "Locations")
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("FILTER THE DIGEST TO THESE PLACES — EMPTY MEANS EVERYWHERE")
                        .font(.mono(9))
                        .foregroundStyle(Color.pulseTextFaint)

                    chipEditor(
                        title: "CITIES",
                        placeholder: "ADD CITY",
                        items: $settings.cities,
                        input: $cityInput
                    ) { $0 }

                    chipEditor(
                        title: "COUNTRIES (ISO CODES)",
                        placeholder: "ADD COUNTRY E.G. GB",
                        items: $settings.countries,
                        input: $countryInput
                    ) { $0.uppercased() }
                }
            }
        }
    }

    private func chipEditor(
        title: String, placeholder: String,
        items: Binding<[String]>, input: Binding<String>,
        normalise: @escaping (String) -> String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.mono(10, .bold))
                .kerning(1)
                .foregroundStyle(Color.pulseTextMuted)

            if !items.wrappedValue.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(items.wrappedValue, id: \.self) { item in
                            HStack(spacing: 5) {
                                Text(item)
                                    .font(.mono(11))
                                    .foregroundStyle(.white)
                                Image(systemName: "xmark")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(Color.pulseTextMuted)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 5)
                                    .stroke(Color.pulseBorderLight, lineWidth: 1)
                            )
                            .onTapGesture {
                                items.wrappedValue.removeAll { $0 == item }
                            }
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                PulseTextField(placeholder: placeholder, text: input)
                Button {
                    let value = normalise(input.wrappedValue.trimmingCharacters(in: .whitespaces))
                    guard !value.isEmpty, !items.wrappedValue.contains(value) else { return }
                    items.wrappedValue.append(value)
                    input.wrappedValue = ""
                } label: {
                    Text("ADD")
                }
                .buttonStyle(OutlineButtonStyle())
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(text: "About")
            PulseCard {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow("VERSION", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                    infoRow("API", Config.apiBaseURL.absoluteString)
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.mono(10))
                .kerning(1)
                .foregroundStyle(Color.pulseTextFaint)
            Spacer()
            Text(value)
                .font(.mono(10))
                .foregroundStyle(Color.pulseTextMuted)
                .lineLimit(1)
        }
    }
}
