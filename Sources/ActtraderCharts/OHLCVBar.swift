import Foundation

/// A single OHLCV candlestick bar.
///
/// `time` is a Unix timestamp in **milliseconds** (UTC), matching the format
/// expected by the chart bridge protocol.
public struct OHLCVBar {
    public let time: Int64
    public let open: Double
    public let high: Double
    public let low: Double
    public let close: Double
    public let volume: Double

    public init(
        time: Int64,
        open: Double,
        high: Double,
        low: Double,
        close: Double,
        volume: Double
    ) {
        self.time = time
        self.open = open
        self.high = high
        self.low = low
        self.close = close
        self.volume = volume
    }
}
