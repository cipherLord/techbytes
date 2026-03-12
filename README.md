# Techbytes

A tech news aggregator for iOS that combines content from Wikipedia and Hacker News into a single, personalized reading experience.

## Screenshots

<!-- Add screenshots here -->

## Features

- **Wikipedia Feed** -- Browse Featured articles, Most Read pages, On This Day events, and Random discoveries
- **Hacker News Feed** -- Stay current with Top, New, Best, Ask, Show, and Jobs stories
- **In-App Article Reader** -- Read full Wikipedia articles without leaving the app, with support for following internal links
- **Topic-Based Personalization** -- Select topics you care about (Science, Technology, History, and more) and get content ranked to your interests

## Project Structure

```
Techbytes/
├── TechbytesApp.swift          # App entry point
├── ContentView.swift           # Root tab navigation
├── Models/                     # Data models (Article, UserTopic, ArticleInteraction)
├── ViewModels/                 # Observable view models for feeds, reader, and tags
├── Views/
│   ├── Feed/                   # Wikipedia and Hacker News feed views
│   ├── Reader/                 # In-app article reader
│   ├── Tags/                   # Topic picker and tag management
│   ├── Settings/               # App settings
│   └── Components/             # Reusable UI components
├── Services/                   # Networking, API clients, recommendation engine
├── Theme/                      # Custom colors and typography
└── Utilities/                  # Swift extensions
```

## Requirements

- Xcode 26+
- iOS 26.2+

## Getting Started

1. Clone the repository
   ```bash
   git clone <repository-url>
   ```
2. Open `Techbytes/Techbytes.xcodeproj` in Xcode
3. Select a simulator or connected device
4. Build and run (Cmd + R)

## License

<!-- Add license here -->
