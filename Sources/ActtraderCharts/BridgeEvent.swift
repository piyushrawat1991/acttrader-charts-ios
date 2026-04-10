import Foundation

/// Events emitted from the chart WebView back to native iOS code.
public enum BridgeEvent {

    /// Chart engine is initialised and ready to receive commands.
    case ready

    /// Crosshair moved; contains the bar data at the cursor position.
    case crosshair(time: Int64, open: Double, high: Double, low: Double, close: Double, volume: Double, x: Double, y: Double)

    /// User tapped/clicked a bar.
    case barClick(time: Int64, open: Double, high: Double, low: Double, close: Double, volume: Double)

    /// Viewport scroll or zoom changed.
    case viewportChange(startIndex: Int, endIndex: Int, barWidth: Double)

    /// Active chart series type changed.
    case seriesChange(String)

    /// Active timeframe changed.
    case timeframeChange(String)

    /// Active duration changed.
    case durationChange(String)

    /// Any aspect of chart state changed (generic).
    case stateChange(String)

    /// Response to a `getState` command; contains the full serialised state JSON.
    case stateSnapshot(String)

    /// `loadData` command completed successfully.
    case dataLoaded(barCount: Int)

    /// A new bar was appended at the live edge.
    case newBar(time: Int64, open: Double, high: Double, low: Double, close: Double, volume: Double)

    /// Stream connection status changed.
    case streamStatus(String)

    /// User submitted an order via the floating trade button.
    case placeOrder(price: Double, side: String, orderType: String)

    /// An error occurred inside the chart engine.
    case error(message: String, code: String?)

    // ── Parser ────────────────────────────────────────────────────────────────

    /// Parses a raw JSON string received from the WebView into a `BridgeEvent`.
    /// Returns `nil` for malformed or unrecognised messages.
    public static func parse(_ json: String) -> BridgeEvent? {
        guard
            let data = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = obj["type"] as? String
        else { return nil }

        switch type {

        case "ready":
            return .ready

        case "crosshair":
            guard let bar = obj["bar"] as? [String: Any] else { return nil }
            let pos = obj["position"] as? [String: Any]
            let chTime: Int64 = (bar["time"] as? Int64) ?? Int64(bar["time"] as? Double ?? 0)
            let chOpen:   Double = bar["open"]   as? Double ?? 0
            let chHigh:   Double = bar["high"]   as? Double ?? 0
            let chLow:    Double = bar["low"]    as? Double ?? 0
            let chClose:  Double = bar["close"]  as? Double ?? 0
            let chVol:    Double = bar["volume"] as? Double ?? 0
            let chX:      Double = pos?["x"]     as? Double ?? 0
            let chY:      Double = pos?["y"]     as? Double ?? 0
            return .crosshair(time: chTime, open: chOpen, high: chHigh, low: chLow,
                              close: chClose, volume: chVol, x: chX, y: chY)

        case "barClick":
            guard let bar = obj["bar"] as? [String: Any] else { return nil }
            let bcTime:  Int64  = (bar["time"] as? Int64) ?? Int64(bar["time"] as? Double ?? 0)
            let bcOpen:  Double = bar["open"]   as? Double ?? 0
            let bcHigh:  Double = bar["high"]   as? Double ?? 0
            let bcLow:   Double = bar["low"]    as? Double ?? 0
            let bcClose: Double = bar["close"]  as? Double ?? 0
            let bcVol:   Double = bar["volume"] as? Double ?? 0
            return .barClick(time: bcTime, open: bcOpen, high: bcHigh, low: bcLow,
                             close: bcClose, volume: bcVol)

        case "viewportChange":
            guard let vp = obj["viewport"] as? [String: Any] else { return nil }
            return .viewportChange(
                startIndex: vp["startIndex"] as? Int ?? 0,
                endIndex:   vp["endIndex"]   as? Int ?? 0,
                barWidth:   vp["barWidth"]   as? Double ?? 0
            )

        case "seriesChange":
            guard let series = obj["series"] as? String else { return nil }
            return .seriesChange(series)

        case "timeframeChange":
            guard let tf = obj["timeframe"] as? String else { return nil }
            return .timeframeChange(tf)

        case "durationChange":
            guard let dur = obj["duration"] as? String else { return nil }
            return .durationChange(dur)

        case "stateChange":
            guard
                let state = obj["state"],
                let stateData = try? JSONSerialization.data(withJSONObject: state),
                let stateJson = String(data: stateData, encoding: .utf8)
            else { return nil }
            return .stateChange(stateJson)

        case "stateSnapshot":
            guard
                let state = obj["state"],
                let stateData = try? JSONSerialization.data(withJSONObject: state),
                let stateJson = String(data: stateData, encoding: .utf8)
            else { return nil }
            return .stateSnapshot(stateJson)

        case "dataLoaded":
            return .dataLoaded(barCount: obj["barCount"] as? Int ?? 0)

        case "newBar":
            guard let bar = obj["bar"] as? [String: Any] else { return nil }
            let nbTime:  Int64  = (bar["time"] as? Int64) ?? Int64(bar["time"] as? Double ?? 0)
            let nbOpen:  Double = bar["open"]   as? Double ?? 0
            let nbHigh:  Double = bar["high"]   as? Double ?? 0
            let nbLow:   Double = bar["low"]    as? Double ?? 0
            let nbClose: Double = bar["close"]  as? Double ?? 0
            let nbVol:   Double = bar["volume"] as? Double ?? 0
            return .newBar(time: nbTime, open: nbOpen, high: nbHigh, low: nbLow,
                           close: nbClose, volume: nbVol)

        case "streamStatus":
            guard let status = obj["status"] as? String else { return nil }
            return .streamStatus(status)

        case "placeOrder":
            guard let payload = obj["payload"] as? [String: Any] else { return nil }
            return .placeOrder(
                price:     payload["price"]     as? Double ?? 0,
                side:      payload["side"]      as? String ?? "",
                orderType: payload["orderType"] as? String ?? "limit"
            )

        case "error":
            let message = obj["message"] as? String ?? "Unknown error"
            let code    = obj["code"]    as? String
            return .error(message: message, code: code?.isEmpty == false ? code : nil)

        default:
            return nil
        }
    }
}
