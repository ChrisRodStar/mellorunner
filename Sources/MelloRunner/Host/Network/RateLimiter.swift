import Foundation

/// Actor managing client-side request pacing based on a token-bucket sliding interval.
public actor RateLimiter {
    public private(set) var requestsPerPeriod: Int
    public private(set) var periodSeconds: Double

    private var requestTimestamps: [ContinuousClock.Instant] = []
    private let clock = ContinuousClock()

    public init(requestsPerPeriod: Int = 0, periodSeconds: Double = 0) {
        self.requestsPerPeriod = max(0, requestsPerPeriod)
        self.periodSeconds = max(0, periodSeconds)
    }

    /// Updates the configured rate limit parameters.
    public func setRateLimit(requests: Int, period: Double) {
        self.requestsPerPeriod = max(0, requests)
        self.periodSeconds = max(0, period)
        self.requestTimestamps.removeAll(keepingCapacity: true)
    }

    /// Acquires permission to send a request, suspending the caller if rate limits are currently exceeded.
    public func acquire() async {
        guard requestsPerPeriod > 0, periodSeconds > 0 else { return }

        let window = Duration.seconds(periodSeconds)

        while true {
            let now = clock.now
            // Prune timestamps older than the sliding window
            requestTimestamps.removeAll { now - $0 >= window }

            if requestTimestamps.count < requestsPerPeriod {
                requestTimestamps.append(now)
                return
            }

            // Must wait until oldest timestamp exits the window
            if let oldest = requestTimestamps.first {
                let waitDuration = window - (now - oldest)
                if waitDuration > .zero {
                    try? await Task.sleep(for: waitDuration)
                }
            }
        }
    }
}
