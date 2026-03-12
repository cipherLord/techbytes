import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.liquidLava)
                .scaleEffect(1.2)

            Text(message)
                .font(.label)
                .foregroundStyle(.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.appBackground)
    }
}
