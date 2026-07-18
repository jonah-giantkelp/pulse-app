import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isSigningUp = false
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var infoMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            PulseWordmark(size: 32)
            Text("GIG TRACKER")
                .font(.mono(11))
                .kerning(4)
                .foregroundStyle(Color.pulseTextMuted)
                .padding(.top, 12)

            VStack(spacing: 12) {
                PulseTextField(placeholder: "EMAIL", text: $email, keyboard: .emailAddress)
                PulseTextField(placeholder: "PASSWORD", text: $password, secure: true)

                if let errorMessage {
                    Text(errorMessage.uppercased())
                        .font(.mono(11))
                        .foregroundStyle(Color.pulseDanger)
                        .multilineTextAlignment(.center)
                }
                if let infoMessage {
                    Text(infoMessage.uppercased())
                        .font(.mono(11))
                        .foregroundStyle(Color.pulseAccent)
                        .multilineTextAlignment(.center)
                }

                Button {
                    submit()
                } label: {
                    if isWorking {
                        ProgressView()
                            .tint(Color.pulseBg)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(isSigningUp ? "CREATE ACCOUNT" : "SIGN IN")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(isWorking || email.isEmpty || password.isEmpty)

                Button {
                    isSigningUp.toggle()
                    errorMessage = nil
                    infoMessage = nil
                } label: {
                    Text(isSigningUp ? "HAVE AN ACCOUNT? SIGN IN" : "NEW HERE? CREATE ACCOUNT")
                        .font(.mono(11))
                        .kerning(1)
                        .foregroundStyle(Color.pulseTextMuted)
                }
                .padding(.top, 8)
            }
            .padding(.horizontal, 32)
            .padding(.top, 48)

            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.pulseBg.ignoresSafeArea())
    }

    private func submit() {
        errorMessage = nil
        infoMessage = nil
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                if isSigningUp {
                    try await auth.signUp(email: email, password: password)
                } else {
                    try await auth.signIn(email: email, password: password)
                }
            } catch let error as AuthError where error.message.hasPrefix("Account created") {
                infoMessage = error.message
                isSigningUp = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
