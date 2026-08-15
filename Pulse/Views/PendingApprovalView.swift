import SwiftUI

/// Shown after sign-in while the account is still awaiting approval.
struct PendingApprovalView: View {
    @EnvironmentObject private var auth: AuthManager
    @EnvironmentObject private var access: AccessStore

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            PulseMark()
                .stroke(
                    Color.pulseAmber,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                )
                .frame(width: 96, height: 96)
                .padding(.bottom, 32)

            Text("AWAITING APPROVAL")
                .font(.mono(18, .bold))
                .kerning(3)
                .foregroundStyle(Color.pulseAmber)

            Text("YOUR ACCOUNT IS PENDING REVIEW.\nYOU'LL GET ACCESS ONCE IT'S\nBEEN APPROVED.")
                .font(.mono(11))
                .kerning(1)
                .lineSpacing(6)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.pulseTextMuted)
                .padding(.top, 16)

            VStack(spacing: 12) {
                Button {
                    Task { await access.check() }
                } label: {
                    if access.isChecking {
                        ProgressView()
                            .tint(Color.pulseBg)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("CHECK AGAIN")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(AccentButtonStyle())
                .disabled(access.isChecking)

                Button {
                    auth.signOut()
                } label: {
                    Text("SIGN OUT")
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
}
