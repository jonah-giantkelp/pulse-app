import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var settings: SettingsStore

    @State private var recipientInput = ""
    @State private var editingRecipient: String?
    @State private var showDeleteConfirm = false
    @State private var isDeletingAccount = false
    @State private var showCityPicker = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("SETTINGS")
                    .font(.mono(16, .bold))
                    .kerning(3)
                    .foregroundStyle(Color.pulseAccent)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    accountCard
                    alertsSection
                    locationsSection

                    if let error = settings.errorMessage {
                        Text(error.uppercased())
                            .font(.mono(10))
                            .foregroundStyle(Color.pulseDanger)
                            .frame(maxWidth: .infinity)
                    }

                    dangerSection
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .task { await settings.load() }
        .alert("Delete account?", isPresented: $showDeleteConfirm) {
            Button("Delete", role: .destructive) {
                Task {
                    isDeletingAccount = true
                    if await settings.deleteAccount() {
                        auth.signOut()
                    }
                    isDeletingAccount = false
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account, tracked artists and favourites. It cannot be undone.")
        }
    }

    // MARK: - Account

    private var accountCard: some View {
        PulseCard {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("LOGGED IN AS")
                        .font(.mono(9))
                        .kerning(1)
                        .foregroundStyle(Color.pulseTextFaint)
                    Text(auth.email ?? "—")
                        .font(.mono(13))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    auth.signOut()
                } label: {
                    Text("SIGN OUT")
                }
                .buttonStyle(OutlineButtonStyle(color: .pulseTextMuted))
            }
        }
    }

    // MARK: - Event alerts (email + push)

    private var alertsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(text: "Event alerts")
            PulseCard {
                VStack(alignment: .leading, spacing: 14) {
                    alertRow(
                        title: "PUSH NOTIFICATIONS",
                        subtitle: "INSTANT ALERTS ON THIS DEVICE",
                        isOn: Binding(
                            get: { settings.pushEnabled },
                            set: { settings.setPush($0) }
                        )
                    )

                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.pulseBorder)

                    alertRow(
                        title: "DAILY EMAIL",
                        subtitle: "RECEIVE NEW EVENTS TO YOUR INBOX",
                        isOn: Binding(
                            get: { settings.newsletterEnabled },
                            set: { settings.setNewsletter($0) }
                        )
                    )

                    if settings.newsletterEnabled {
                        // Indented under EMAIL with a rail so it reads as its sub-block
                        recipientsEditor
                            .padding(.leading, 14)
                            .overlay(
                                Rectangle()
                                    .frame(width: 2)
                                    .foregroundStyle(Color.pulseBorderLight),
                                alignment: .leading
                            )
                    }
                }
            }
        }
    }

    private func alertRow(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.mono(12, .bold))
                    .kerning(1)
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.mono(9))
                    .foregroundStyle(Color.pulseTextFaint)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.pulseAccent)
                .scaleEffect(0.75, anchor: .trailing)
        }
    }

    private var recipientsEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECIPIENTS")
                .font(.mono(10, .bold))
                .kerning(1)
                .foregroundStyle(Color.pulseTextMuted)

            ForEach(settings.recipients, id: \.self) { email in
                HStack(spacing: 14) {
                    Text(email)
                        .font(.mono(13))
                        .foregroundStyle(editingRecipient == email ? Color.pulseAmber : .white)
                        .lineLimit(1)
                    Spacer()
                    Button {
                        editingRecipient = email
                        recipientInput = email
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.pulseTextMuted)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    Button {
                        if editingRecipient == email {
                            editingRecipient = nil
                            recipientInput = ""
                        }
                        settings.removeRecipient(email)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.pulseTextFaint)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(Color.pulseBorder),
                    alignment: .bottom
                )
            }

            if editingRecipient != nil || settings.recipients.count < SettingsStore.maxRecipients {
                HStack(spacing: 8) {
                    PulseTextField(
                        placeholder: editingRecipient == nil ? "ADD RECIPIENT" : "EDIT RECIPIENT",
                        text: $recipientInput,
                        keyboard: .emailAddress,
                        compact: true
                    )
                    Button {
                        commitRecipient()
                    } label: {
                        Text(editingRecipient == nil ? "ADD" : "SAVE")
                    }
                    .buttonStyle(OutlineButtonStyle())
                }
            } else {
                Text("MAX \(SettingsStore.maxRecipients) RECIPIENTS")
                    .font(.mono(9))
                    .kerning(1)
                    .foregroundStyle(Color.pulseTextFaint)
            }
        }
    }

    private func commitRecipient() {
        let value = recipientInput.trimmingCharacters(in: .whitespaces)
        guard !value.isEmpty else { return }
        if let original = editingRecipient {
            settings.updateRecipient(original, to: value)
            editingRecipient = nil
        } else {
            settings.addRecipient(value)
        }
        recipientInput = ""
    }

    // MARK: - Locations

    private var locationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            PulseSectionHeader(text: "Locations")
            PulseCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("TRACKED CITIES")
                        .font(.mono(10, .bold))
                        .kerning(1)
                        .foregroundStyle(Color.pulseTextMuted)

                    FlowLayout(spacing: 6) {
                        ForEach(settings.cities.isEmpty ? ["London"] : settings.cities, id: \.self) { city in
                            trackedCityPill(city)
                        }
                    }

                    if !settings.availableCities.isEmpty {
                        Button {
                            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                                showCityPicker.toggle()
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                Text("ADD CITY")
                                    .font(.mono(10, .bold))
                                    .kerning(1)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                                    .rotationEffect(.degrees(showCityPicker ? 180 : 0))
                            }
                            .foregroundStyle(Color.pulseAccent)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 2)

                        // Picker unfolds from under the toggle, no overflow flash
                        VStack(alignment: .leading, spacing: 10) {
                            if showCityPicker {
                                Rectangle()
                                    .frame(height: 1)
                                    .foregroundStyle(Color.pulseBorder)
                                FlowLayout(spacing: 6) {
                                    ForEach(settings.availableCities) { city in
                                        availableCityPill(city)
                                    }
                                }
                                .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        .clipped()
                    }
                }
            }
        }
    }

    private func trackedCityPill(_ city: String) -> some View {
        HStack(spacing: 6) {
            Text(city.capitalized)
                .font(.mono(11))
                .foregroundStyle(.white)
            if settings.cities.count > 1 {
                Button {
                    withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                        settings.removeCity(city)
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.pulseTextFaint)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .overlay(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.pulseBorderLight, lineWidth: 1)
        )
    }

    private func availableCityPill(_ city: City) -> some View {
        Button {
            withAnimation(.spring(duration: 0.35, bounce: 0.15)) {
                settings.addCity(city.name)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 9, weight: .bold))
                Text(city.name.capitalized)
                    .font(.mono(11))
            }
            .foregroundStyle(Color.pulseTextSecondary)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color.pulseBorder, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Danger zone

    private var dangerSection: some View {
        VStack(spacing: 16) {
            Button {
                showDeleteConfirm = true
            } label: {
                if isDeletingAccount {
                    ProgressView()
                        .tint(Color.pulseDanger)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("DELETE ACCOUNT")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(OutlineButtonStyle(color: .pulseDanger))
            .disabled(isDeletingAccount)
        }
        .padding(.top, 8)
    }

}
