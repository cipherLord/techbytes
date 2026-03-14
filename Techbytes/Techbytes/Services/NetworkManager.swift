import Foundation

enum NetworkError: LocalizedError {
    case invalidURL
    case httpError(statusCode: Int)
    case decodingError(Error)
    case rateLimited
    case noData
    case unknown(Error)

    var userMessage: String {
        switch self {
        case .invalidURL: return "Something went wrong. Please try again."
        case .httpError: return "The server is having trouble. Please try again later."
        case .decodingError: return "We received unexpected data. Please try again."
        case .rateLimited: return "Too many requests. Please wait a moment."
        case .noData: return "No data received. Check your connection."
        case .unknown: return "Something went wrong. Please try again."
        }
    }

    var errorDescription: String? { userMessage }
}

final class NetworkManager: Sendable {
    static let shared = NetworkManager()

    private let session: URLSession
    private let wikipediaRateLimiter = RateLimiter(maxRequestsPerHour: 400)
    private let hackerNewsRateLimiter = RateLimiter(maxRequestsPerHour: 1800)
    private let lobstersRateLimiter = RateLimiter(maxRequestsPerHour: 1000)
    private let techmemeRateLimiter = RateLimiter(maxRequestsPerHour: 1000)

    private init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(
            memoryCapacity: 4 * 1024 * 1024,
            diskCapacity: 50 * 1024 * 1024
        )
        config.requestCachePolicy = .useProtocolCachePolicy
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = [
            "User-Agent": "Techbytes/1.0 (iOS; contact@techbytes.app)"
        ]
        self.session = URLSession(configuration: config)
    }

    func fetchWikipedia<T: Decodable>(_ url: URL, as type: T.Type, ignoreCache: Bool = false) async throws -> T {
        try await wikipediaRateLimiter.acquire()
        return try await fetchWithRetry(url, as: type, ignoreCache: ignoreCache)
    }

    func fetchHackerNews<T: Decodable>(_ url: URL, as type: T.Type, ignoreCache: Bool = false) async throws -> T {
        try await hackerNewsRateLimiter.acquire()
        return try await fetchWithRetry(url, as: type, ignoreCache: ignoreCache)
    }

    func fetchLobsters<T: Decodable>(_ url: URL, as type: T.Type, ignoreCache: Bool = false) async throws -> T {
        try await lobstersRateLimiter.acquire()
        return try await fetchWithRetry(url, as: type, ignoreCache: ignoreCache)
    }

    func fetchTechmemeRaw(_ url: URL, ignoreCache: Bool = false) async throws -> Data {
        try await techmemeRateLimiter.acquire()
        return try await fetchRawData(from: url, ignoreCache: ignoreCache)
    }

    private func fetchWithRetry<T: Decodable>(_ url: URL, as type: T.Type, maxRetries: Int = 2, ignoreCache: Bool = false) async throws -> T {
        var lastError: Error = NetworkError.unknown(NSError(domain: "", code: 0))
        for attempt in 0...maxRetries {
            if attempt > 0 {
                let delay = Double(1 << attempt)
                try await Task.sleep(for: .seconds(delay))
            }
            do {
                return try await fetch(url, as: type, ignoreCache: ignoreCache)
            } catch NetworkError.rateLimited {
                lastError = NetworkError.rateLimited
                continue
            } catch let error as NetworkError {
                if case .httpError(let code) = error, (500...599).contains(code) {
                    lastError = error
                    continue
                }
                throw error
            } catch {
                throw NetworkError.unknown(error)
            }
        }
        throw lastError
    }

    private func fetch<T: Decodable>(_ url: URL, as type: T.Type, ignoreCache: Bool = false) async throws -> T {
        let request: URLRequest
        if ignoreCache {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            request = req
        } else {
            request = URLRequest(url: url)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.noData
        }
        switch http.statusCode {
        case 200..<300:
            break
        case 429:
            throw NetworkError.rateLimited
        default:
            throw NetworkError.httpError(statusCode: http.statusCode)
        }
        do {
            let decoder = JSONDecoder()
            return try decoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingError(error)
        }
    }

    func fetchWikipediaRaw(_ url: URL, ignoreCache: Bool = false) async throws -> Data {
        try await wikipediaRateLimiter.acquire()
        return try await fetchRawData(from: url, ignoreCache: ignoreCache)
    }

    private func fetchRawData(from url: URL, ignoreCache: Bool = false) async throws -> Data {
        let request: URLRequest
        if ignoreCache {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            request = req
        } else {
            request = URLRequest(url: url)
        }
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw NetworkError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        return data
    }
}
