import Foundation

actor RateLimiter {
    private let maxTokens: Double
    private let refillRate: Double
    private var tokens: Double
    private var lastRefill: Date

    init(maxRequestsPerHour: Int) {
        self.maxTokens = Double(maxRequestsPerHour)
        self.refillRate = Double(maxRequestsPerHour) / 3600.0
        self.tokens = Double(maxRequestsPerHour)
        self.lastRefill = Date()
    }

    func acquire() async throws {
        refillTokens()
        if tokens >= 1.0 {
            tokens -= 1.0
            return
        }
        let waitTime = (1.0 - tokens) / refillRate
        try await Task.sleep(for: .seconds(waitTime))
        refillTokens()
        tokens -= 1.0
    }

    private func refillTokens() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        tokens = min(maxTokens, tokens + elapsed * refillRate)
        lastRefill = now
    }
}
