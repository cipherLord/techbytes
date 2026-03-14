import Foundation

struct TechmemeItem: Sendable {
    var title: String = ""
    var link: String = ""
    var description: String = ""
    var pubDate: String = ""

    /// The first `<A HREF="...">` in the description points to the original source article.
    /// Falls back to the Techmeme permalink in `link`.
    var sourceURL: String {
        if let regex = try? NSRegularExpression(pattern: #"<A\s+HREF="(https?://(?!www\.techmeme\.com)[^"]+)"#, options: .caseInsensitive),
           let match = regex.firstMatch(in: description, range: NSRange(description.startIndex..., in: description)),
           let urlRange = Range(match.range(at: 1), in: description) {
            return String(description[urlRange])
        }
        return link
    }
}

final class TechmemeService {
    static let shared = TechmemeService()
    private let network = NetworkManager.shared
    private let baseURL = "https://www.techmeme.com"

    private init() {}

    func fetchStories(ignoreCache: Bool = false) async throws -> [Article] {
        guard let url = URL(string: "\(baseURL)/feed.xml") else {
            throw NetworkError.invalidURL
        }
        
        let data = try await network.fetchTechmemeRaw(url, ignoreCache: ignoreCache)
        
        let parser = TechmemeRSSParser()
        let items = try await parser.parse(data: data)
        
        return items.compactMap { toArticle(from: $0) }
    }

    private func toArticle(from item: TechmemeItem) -> Article? {
        guard !item.title.isEmpty, !item.link.isEmpty else { return nil }

        let summary = item.description.strippingHTML.trimmingCharacters(in: .whitespacesAndNewlines)
        let articleURL = item.sourceURL
        let imageURL = Self.extractImageURL(from: item.description)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let publishDate = formatter.date(from: item.pubDate)

        let idString = item.link.components(separatedBy: CharacterSet(charactersIn: "?&")).first ?? item.link
        let hash = String(abs(idString.hashValue))

        return Article(
            id: "techmeme-\(hash)",
            title: item.title.trimmingCharacters(in: .whitespacesAndNewlines),
            summary: summary.isEmpty ? (articleURL.domainFromURL ?? "") : summary,
            articleURL: articleURL.trimmingCharacters(in: .whitespacesAndNewlines),
            imageURL: imageURL,
            source: .techmeme,
            section: TechmemeSection.topNews.rawValue,
            author: articleURL.domainFromURL,
            publishDate: publishDate
        )
    }

    private static func extractImageURL(from html: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"<IMG[^>]+SRC="(https?://[^"]+)"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let urlRange = Range(match.range(at: 1), in: html) else {
            return nil
        }
        return String(html[urlRange])
    }
}

final class TechmemeRSSParser: NSObject, XMLParserDelegate, Sendable {
    private final class ParserState {
        var items: [TechmemeItem] = []
        var currentItem: TechmemeItem?
        var currentElement: String = ""
        var currentString: String = ""
    }
    
    private let state = ParserState()
    private var completion: (([TechmemeItem]) -> Void)?
    private var error: Error?
    
    func parse(data: Data) async throws -> [TechmemeItem] {
        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            
            self.completion = { items in
                guard !resumed else { return }
                resumed = true
                continuation.resume(returning: items)
            }
            
            let parser = XMLParser(data: data)
            parser.delegate = self
            
            if !parser.parse(), !resumed {
                resumed = true
                if let error = parser.parserError {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(throwing: NetworkError.decodingError(NSError(domain: "XMLParser", code: 0)))
                }
            }
        }
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        state.currentElement = elementName
        if elementName == "item" {
            state.currentItem = TechmemeItem()
        }
        state.currentString = ""
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        state.currentString += string
    }
    
    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        if let string = String(data: CDATABlock, encoding: .utf8) {
            state.currentString += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "item" {
            if let item = state.currentItem {
                state.items.append(item)
            }
            state.currentItem = nil
        } else if state.currentItem != nil {
            let value = state.currentString.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName {
            case "title": state.currentItem?.title = value
            case "link": state.currentItem?.link = value
            case "description": state.currentItem?.description = value
            case "pubDate": state.currentItem?.pubDate = value
            default: break
            }
        }
        state.currentElement = ""
        state.currentString = ""
    }
    
    func parserDidEndDocument(_ parser: XMLParser) {
        completion?(state.items)
    }
    
    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        error = parseError
    }
}
