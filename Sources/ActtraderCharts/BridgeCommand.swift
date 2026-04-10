import Foundation

/// Commands sent from native iOS code to the chart WebView.
///
/// Each case serialises itself to the JSON format expected by
/// `window.ChartBridge.send()`:
/// ```json
/// { "type": "<cmd>", "payload": { ...fields } }
/// ```
///
/// Pass the result of `jsonString` to `ActtraderChartsView`'s internal
/// `sendCommand(_:)` — do **not** call `evaluateJavaScript` directly.
public enum BridgeCommand {

    // ── Core ──────────────────────────────────────────────────────────────────

    /// Re-creates the chart engine. Sent automatically on first load via
    /// `ActtraderChartsView.init(...)`.
    case initialize(
        theme: String,
        symbol: String?,
        series: String?,
        enableTrading: Bool,
        minLots: Int,
        showCandleCountdown: Bool?,
        disableCountdownOnMobile: Bool?
    )

    /// Replaces the full dataset.
    case loadData(bars: [OHLCVBar], fitAll: Bool)

    /// Pushes a live bid/ask tick for streaming updates.
    case pushTick(bid: Double, ask: Double, timestamp: Int64)

    // ── Appearance ────────────────────────────────────────────────────────────

    /// Switches between `"dark"` and `"light"` themes.
    case setTheme(String)

    /// Changes the chart series type (e.g. `"candlestick"`, `"line"`, `"area"`).
    case setSeries(String)

    /// Changes the active timeframe (e.g. `"1m"`, `"1h"`, `"1D"`).
    case setTimeframe(String)

    /// Updates the displayed symbol name.
    case setSymbol(String)

    // ── Studies / Drawings ────────────────────────────────────────────────────

    /// Adds a study overlay or oscillator by short name (e.g. `"SMA"`, `"RSI"`).
    case addIndicator(name: String, params: [String: Any]?)

    /// Removes a study by name.
    case removeIndicator(String)

    /// Activates a drawing tool by ID, or `nil` to deactivate.
    case setDrawingTool(String?)

    /// Removes all drawings from the chart.
    case clearAllDrawings

    // ── State ─────────────────────────────────────────────────────────────────

    /// Requests the current chart state; fires a `stateSnapshot` event in response.
    case getState

    /// Restores a previously captured chart state.
    /// - Parameter stateJson: Raw JSON string from a prior `stateSnapshot` event.
    case setState(String)

    /// Destroys the chart engine and releases resources.
    case destroy

    // ── Serialisation ─────────────────────────────────────────────────────────

    /// The JSON string to pass to `window.ChartBridge.send(...)`.
    public var jsonString: String {
        let envelope: [String: Any]
        switch self {

        case let .initialize(theme, symbol, series, enableTrading, minLots, showCandleCountdown, disableCountdownOnMobile):
            var payload: [String: Any] = ["theme": theme]
            if let symbol { payload["symbol"] = symbol }
            if let series { payload["series"] = series }
            if enableTrading {
                payload["enableTrading"] = true
                payload["minLots"] = minLots
            }
            if let showCandleCountdown { payload["showCandleCountdown"] = showCandleCountdown }
            if let disableCountdownOnMobile { payload["disableCountdownOnMobile"] = disableCountdownOnMobile }
            envelope = ["type": "init", "payload": payload]

        case let .loadData(bars, fitAll):
            let barsArray: [[String: Any]] = bars.map { bar in
                ["open": bar.open, "high": bar.high, "low": bar.low,
                 "close": bar.close, "volume": bar.volume, "time": bar.time]
            }
            envelope = ["type": "loadData", "payload": ["bars": barsArray, "fitAll": fitAll]]

        case let .pushTick(bid, ask, timestamp):
            envelope = ["type": "pushTick", "payload": ["B": bid, "A": ask, "T": timestamp]]

        case let .setTheme(theme):
            envelope = ["type": "setTheme", "payload": ["theme": theme]]

        case let .setSeries(series):
            envelope = ["type": "setSeries", "payload": ["series": series]]

        case let .setTimeframe(timeframe):
            envelope = ["type": "setTimeframe", "payload": ["timeframe": timeframe]]

        case let .setSymbol(symbol):
            envelope = ["type": "setSymbol", "payload": ["symbol": symbol]]

        case let .addIndicator(name, params):
            var payload: [String: Any] = ["shortName": name]
            if let params { payload["params"] = params }
            envelope = ["type": "addIndicator", "payload": payload]

        case let .removeIndicator(name):
            envelope = ["type": "removeIndicator", "payload": ["name": name]]

        case let .setDrawingTool(tool):
            let toolValue: Any = tool ?? NSNull()
            envelope = ["type": "setDrawingTool", "payload": ["tool": toolValue]]

        case .clearAllDrawings:
            envelope = ["type": "clearAllDrawings", "payload": [:]]

        case .getState:
            envelope = ["type": "getState", "payload": [:]]

        case let .setState(stateJson):
            guard
                let data = stateJson.data(using: .utf8),
                let stateObj = try? JSONSerialization.jsonObject(with: data)
            else { return "{}" }
            envelope = ["type": "setState", "payload": stateObj]

        case .destroy:
            envelope = ["type": "destroy", "payload": [:]]
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: envelope),
            let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }
}
