import SwiftUI
import SwiftData

struct TopicPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TagManagerViewModel()
    @State private var appeared = false
    @State private var chipsAppeared = false
    var onComplete: () -> Void

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                headerSection
                topicGrid
                bottomBar
            }
        }
        .onAppear {
            viewModel.configure(modelContext: modelContext)
            withAnimation(.easeOut(duration: 0.6)) {
                appeared = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(300))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.5)) {
                    chipsAppeared = true
                }
            }
        }
    }

    private var headerSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.liquidLava.opacity(0.12))
                    .frame(width: 80, height: 80)

                Image(systemName: "sparkles")
                    .font(.system(size: 40))
                    .foregroundStyle(.liquidLava)
            }
            .padding(.top, 48)
            .cascadeIn(delay: 0.0, appeared: appeared)

            Text("What interests you?")
                .font(.headline1)
                .foregroundStyle(.primaryText)
                .cascadeIn(delay: 0.08, appeared: appeared)

            Text("Pick topics to personalize your Wikipedia feed.\nYou can always change these later.")
                .font(.bodyMedium)
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .cascadeIn(delay: 0.14, appeared: appeared)

            Text("\(viewModel.selectedTopics.count) selected")
                .font(.label)
                .foregroundStyle(.liquidLava)
                .padding(.top, 4)
                .cascadeIn(delay: 0.18, appeared: appeared)
        }
        .padding(.bottom, 24)
    }

    private var topicGrid: some View {
        ScrollView(.vertical, showsIndicators: false) {
            FlowLayout(spacing: 10) {
                ForEach(Array(viewModel.topics.enumerated()), id: \.element.id) { index, topic in
                    TagChipView(
                        topic: topic,
                        isSelected: topic.isSelected,
                        onTap: { viewModel.toggleTopic(topic) }
                    )
                    .opacity(chipsAppeared ? 1 : 0)
                    .scaleEffect(chipsAppeared ? 1 : 0.8)
                    .animation(
                        .spring(response: 0.4, dampingFraction: 0.7)
                            .delay(Double(min(index, 15)) * 0.03),
                        value: chipsAppeared
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 100)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [.appBackground.opacity(0), .appBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 40)

            Button {
                viewModel.completeOnboarding()
                onComplete()
            } label: {
                Text(viewModel.selectedTopics.isEmpty ? "Skip for now" : "Continue")
                    .font(AppFont.semiBold(16))
                    .foregroundStyle(.snow)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        viewModel.selectedTopics.isEmpty
                        ? Color.slateGrey
                        : Color.liquidLava
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .animation(.easeInOut(duration: 0.25), value: viewModel.selectedTopics.isEmpty)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
            .background(.appBackground)
            .cascadeIn(delay: 0.2, appeared: appeared)
        }
    }
}
