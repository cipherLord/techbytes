import SwiftUI
import SwiftData

@main
struct TechbytesApp: App {
    init() {
        AppFont.register()
        configureNavigationBarAppearance()
    }

    private func configureNavigationBarAppearance() {
        let darkBG = UIColor(red: 21/255, green: 20/255, blue: 25/255, alpha: 1)

        let standard = UINavigationBarAppearance()
        standard.configureWithOpaqueBackground()
        standard.backgroundColor = darkBG
        standard.titleTextAttributes = [.foregroundColor: UIColor.white]
        standard.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        let scrollEdge = UINavigationBarAppearance()
        scrollEdge.configureWithOpaqueBackground()
        scrollEdge.backgroundColor = darkBG
        scrollEdge.titleTextAttributes = [.foregroundColor: UIColor.white]
        scrollEdge.largeTitleTextAttributes = [.foregroundColor: UIColor.white]

        UINavigationBar.appearance().standardAppearance = standard
        UINavigationBar.appearance().scrollEdgeAppearance = scrollEdge
        UINavigationBar.appearance().compactAppearance = standard
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            Article.self,
            UserTopic.self,
            ArticleInteraction.self
        ])
    }
}
