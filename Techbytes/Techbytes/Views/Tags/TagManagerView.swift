import SwiftUI
import SwiftData

struct TagManagerView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = TagManagerViewModel()
    @FocusState private var isAddFieldFocused: Bool
    @State private var topicToDelete: UserTopic?

    var body: some View {
        ZStack {
            Color.appBackground.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    addCustomTagSection
                    selectedSection
                    availableSection
                }
                .padding(20)
            }
        }
        .navigationTitle("Manage Topics")
        .toolbarTitleDisplayMode(.large)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onAppear {
            viewModel.configure(modelContext: modelContext)
        }
        .confirmationDialog(
            "Delete Topic",
            isPresented: Binding(
                get: { topicToDelete != nil },
                set: { if !$0 { topicToDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let topic = topicToDelete {
                    withAnimation { viewModel.deleteTopic(topic) }
                    topicToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) {
                topicToDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete \"\(topicToDelete?.name ?? "")\"?")
        }
    }

    private var addCustomTagSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("ADD CUSTOM TOPIC")
                .font(.caption)
                .foregroundStyle(.dustyGrey)
                .tracking(1.2)

            HStack(spacing: 12) {
                TextField("Enter topic name", text: $viewModel.newTagName)
                    .font(.bodyMedium)
                    .foregroundStyle(.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.slateGrey)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .focused($isAddFieldFocused)
                    .onChange(of: viewModel.newTagName) { _, newValue in
                        if newValue.count > TagManagerViewModel.maxTagLength {
                            viewModel.newTagName = String(newValue.prefix(TagManagerViewModel.maxTagLength))
                        }
                    }

                Button {
                    viewModel.addCustomTag()
                    isAddFieldFocused = false
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.liquidLava)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.newTagName.trimmingCharacters(in: .whitespaces).isEmpty)
                .opacity(viewModel.newTagName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.4 : 1)
                .accessibilityLabel("Add custom topic")
            }
        }
    }

    @ViewBuilder
    private var selectedSection: some View {
        if !viewModel.selectedTopics.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("ACTIVE TOPICS (\(viewModel.selectedTopics.count))")
                    .font(.caption)
                    .foregroundStyle(.dustyGrey)
                    .tracking(1.2)

                FlowLayout(spacing: 8) {
                    ForEach(viewModel.selectedTopics, id: \.id) { topic in
                        HStack(spacing: 6) {
                            Text(topic.name)
                                .font(.label)
                                .foregroundStyle(.snow)

                            if topic.isCustom {
                                Button {
                                    topicToDelete = topic
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.snow.opacity(0.7))
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Delete \(topic.name)")
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.liquidLava)
                        .clipShape(Capsule())
                        .onTapGesture {
                            withAnimation { viewModel.toggleTopic(topic) }
                        }
                        .accessibilityLabel("\(topic.name), active")
                        .accessibilityHint("Tap to deactivate")
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var availableSection: some View {
        let unselected = viewModel.topics.filter { !$0.isSelected }
        if !unselected.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("AVAILABLE TOPICS")
                    .font(.caption)
                    .foregroundStyle(.dustyGrey)
                    .tracking(1.2)

                FlowLayout(spacing: 8) {
                    ForEach(unselected, id: \.id) { topic in
                        TagChipView(
                            topic: topic,
                            isSelected: false,
                            onTap: {
                                withAnimation { viewModel.toggleTopic(topic) }
                            }
                        )
                    }
                }
            }
        }
    }
}
