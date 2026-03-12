import SwiftUI

struct ErrorView: View {
    let message: String
    var retryAction: (() async -> Void)?
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(.liquidLava)
                .cascadeIn(delay: 0.0, appeared: appeared)

            Text("Something went wrong")
                .font(.headline3)
                .foregroundStyle(.primaryText)
                .cascadeIn(delay: 0.08, appeared: appeared)

            Text(message)
                .font(.bodyMedium)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .cascadeIn(delay: 0.14, appeared: appeared)

            if let retryAction {
                Button {
                    Task { await retryAction() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Retry")
                    }
                    .font(.label)
                    .foregroundStyle(.snow)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(.liquidLava)
                    .clipShape(Capsule())
                }
                .cascadeIn(delay: 0.2, appeared: appeared)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.appBackground)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5)) {
                appeared = true
            }
        }
    }
}
