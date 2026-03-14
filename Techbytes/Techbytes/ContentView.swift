import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showOnboarding = !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            if showOnboarding {
                TopicPickerView {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                        showOnboarding = false
                    }
                }
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
                        removal: .opacity.combined(with: .scale(scale: 0.92))
                    )
                )
            } else {
                mainTabView
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: showOnboarding)
        .preferredColorScheme(.dark)
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab(value: 0) {
                WikipediaFeedView()
            } label: {
                Label("Wikipedia", systemImage: "globe.americas.fill")
            }

            Tab(value: 1) {
                HackerNewsFeedView()
            } label: {
                Label("Hacker News", systemImage: "y.square.fill")
            }

            Tab(value: 2) {
                LobstersFeedView()
            } label: {
                Label("Lobsters", systemImage: "chevron.left.forwardslash.chevron.right")
            }

            Tab(value: 3) {
                TechmemeFeedView()
            } label: {
                Label("Techmeme", systemImage: "newspaper.fill")
            }

            Tab(value: 4) {
                SettingsView()
            } label: {
                Label("Settings", systemImage: "gearshape.fill")
            }
        }
        .tint(.liquidLava)
        .toolbarBackground(Color.gluonGrey, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Article.self, UserTopic.self, ArticleInteraction.self])
}
