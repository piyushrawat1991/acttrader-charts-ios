import Foundation

/// A single change within a `tradeLevelEdit` event.
public struct TradeLevelChange {
    /// Which field changed: `"MAIN"`, `"SL"`, `"TP"`, `"ADD_SL"`, `"ADD_TP"`, `"REMOVE_SL"`, `"REMOVE_TP"`.
    public let field: String
    public let newPrice: Double
    /// Opaque level data serialised as a raw JSON string.
    public let data: String
    public let bracketOrderLabel: String?
}

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

    /// User tapped × to close or cancel a trade level or remove a bracket.
    case tradeLevelClose(label: String, type: String, action: String, data: String, bracketType: String?, isFullscreen: Bool)

    /// Live drag position — fires on every pointer move while a level or bracket is being dragged.
    case tradeLevelDrag(label: String, newPrice: Double, data: String, bracketType: String?, isFullscreen: Bool)

    /// User confirmed edits to a trade level (main price, SL, TP, or bracket changes batched together).
    case tradeLevelEdit(label: String, type: String, data: String, isFullscreen: Bool, changes: [TradeLevelChange])

    /// Chart ✓ button confirmed an edit (including draft orders).
    case tradeLevelConfirmed(label: String, type: String, isFullscreen: Bool)

    /// User tapped the pencil/edit button to open the order panel for a level.
    case tradeLevelEditOpen(label: String, type: String, data: String, price: Double, side: String?, stopLossPrice: Double?, takeProfitPrice: Double?, isFullscreen: Bool)

    /// Emitted after `addLevelBracket()` auto-places a SL/TP bracket.
    /// Use `price` to populate your order form's SL/TP input field.
    case tradeLevelBracketActivated(label: String, bracketType: String, price: Double, isFullscreen: Bool)

    /// Emitted when a new draft order is shown on the chart (market, limit, or stop).
    /// Native layer should open the buy/sell form.
    case draftInitiated(side: String, price: Double, orderType: String, isFullscreen: Bool)

    /// Emitted when a draft order is cancelled (Escape, ✕ button, or external revert).
    case draftCancelled(label: String, isFullscreen: Bool)

    /// Chart engine is requesting data for a time range; native must respond with `resolveDataRequest`.
    case dataRequest(requestId: String, timeframe: String, interval: String, start: Int64, end: Int64)

    /// TFC (Trade from Charts) was toggled on or off via the top bar button or API.
    case tfcToggle(enabled: Bool)

    /// User tapped the symbol name; fires when `onSymbolClick` is enabled in the init command.
    case symbolClick(symbol: String)

    /// An error occurred inside the chart engine.
    case error(message: String, code: String?)

    // ── Parser ────────────────────────────────────────────────────────────────

    /// Parses a raw JSON string received from the WebView into a `BridgeEvent`.
    ///
    /// The bridge sends `{ "type": "...", "payload": { ... } }`.  All fields
    /// are read from the nested `payload` object.
    ///
    /// Returns `nil` for malformed or unrecognised messages.
    public static func parse(_ json: String) -> BridgeEvent? {
        guard
            let data = json.data(using: .utf8),
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let type = obj["type"] as? String
        else { return nil }

        // Every event except "ready" carries a payload object.
        let p = obj["payload"] as? [String: Any] ?? [:]

        switch type {

        case "ready":
            return .ready

        case "crosshair":
            guard let bar = p["bar"] as? [String: Any] else { return nil }
            let pos = p["position"] as? [String: Any]
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
            guard let bar = p["bar"] as? [String: Any] else { return nil }
            let bcTime:  Int64  = (bar["time"] as? Int64) ?? Int64(bar["time"] as? Double ?? 0)
            let bcOpen:  Double = bar["open"]   as? Double ?? 0
            let bcHigh:  Double = bar["high"]   as? Double ?? 0
            let bcLow:   Double = bar["low"]    as? Double ?? 0
            let bcClose: Double = bar["close"]  as? Double ?? 0
            let bcVol:   Double = bar["volume"] as? Double ?? 0
            return .barClick(time: bcTime, open: bcOpen, high: bcHigh, low: bcLow,
                             close: bcClose, volume: bcVol)

        case "viewportChange":
            guard let vp = p["viewport"] as? [String: Any] else { return nil }
            return .viewportChange(
                startIndex: vp["startIndex"] as? Int ?? 0,
                endIndex:   vp["endIndex"]   as? Int ?? 0,
                barWidth:   vp["barWidth"]   as? Double ?? 0
            )

        case "seriesChange":
            guard let series = p["series"] as? String else { return nil }
            return .seriesChange(series)

        case "timeframeChange":
            guard let tf = p["timeframe"] as? String else { return nil }
            return .timeframeChange(tf)

        case "durationChange":
            guard let dur = p["duration"] as? String else { return nil }
            return .durationChange(dur)

        case "stateChange":
            guard
                let state = p["state"],
                let stateData = try? JSONSerialization.data(withJSONObject: state),
                let stateJson = String(data: stateData, encoding: .utf8)
            else { return nil }
            return .stateChange(stateJson)

        case "stateSnapshot":
            guard
                let stateData = try? JSONSerialization.data(withJSONObject: p),
                let stateJson = String(data: stateData, encoding: .utf8)
            else { return nil }
            return .stateSnapshot(stateJson)

        case "dataLoaded":
            return .dataLoaded(barCount: p["barCount"] as? Int ?? 0)

        case "newBar":
            guard let bar = p["completedBar"] as? [String: Any] else { return nil }
            let nbTime:  Int64  = (bar["time"] as? Int64) ?? Int64(bar["time"] as? Double ?? 0)
            let nbOpen:  Double = bar["open"]   as? Double ?? 0
            let nbHigh:  Double = bar["high"]   as? Double ?? 0
            let nbLow:   Double = bar["low"]    as? Double ?? 0
            let nbClose: Double = bar["close"]  as? Double ?? 0
            let nbVol:   Double = bar["volume"] as? Double ?? 0
            return .newBar(time: nbTime, open: nbOpen, high: nbHigh, low: nbLow,
                           close: nbClose, volume: nbVol)

        case "streamStatus":
            guard let status = p["status"] as? String else { return nil }
            return .streamStatus(status)

        case "placeOrder":
            return .placeOrder(
                price:     p["price"]     as? Double ?? 0,
                side:      p["side"]      as? String ?? "",
                orderType: p["orderType"] as? String ?? "limit"
            )

        case "tradeLevelClose":
            let tlcData = p["data"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return .tradeLevelClose(
                label:        p["label"]       as? String ?? "",
                type:         p["type"]        as? String ?? "",
                action:       p["action"]      as? String ?? "",
                data:         tlcData,
                bracketType:  p["bracketType"] as? String,
                isFullscreen: p["isFullscreen"] as? Bool ?? false
            )

        case "tradeLevelDrag":
            let tldData = p["data"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return .tradeLevelDrag(
                label:        p["label"]        as? String ?? "",
                newPrice:     p["newPrice"]     as? Double ?? 0,
                data:         tldData,
                bracketType:  p["bracketType"]  as? String,
                isFullscreen: p["isFullscreen"] as? Bool ?? false
            )

        case "tradeLevelEdit":
            let tleData = p["data"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            let rawChanges = p["changes"] as? [[String: Any]] ?? []
            let changes: [TradeLevelChange] = rawChanges.map { c in
                let cData = c["data"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                    .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
                return TradeLevelChange(
                    field:             c["field"]             as? String ?? "",
                    newPrice:          c["newPrice"]          as? Double ?? 0,
                    data:              cData,
                    bracketOrderLabel: c["bracketOrderLabel"] as? String
                )
            }
            return .tradeLevelEdit(
                label:        p["label"]        as? String ?? "",
                type:         p["type"]         as? String ?? "",
                data:         tleData,
                isFullscreen: p["isFullscreen"] as? Bool ?? false,
                changes:      changes
            )

        case "tradeLevelConfirmed":
            return .tradeLevelConfirmed(
                label:        p["label"]        as? String ?? "",
                type:         p["type"]         as? String ?? "",
                isFullscreen: p["isFullscreen"] as? Bool ?? false
            )

        case "tradeLevelEditOpen":
            let tleoData = p["data"].flatMap { try? JSONSerialization.data(withJSONObject: $0) }
                .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
            return .tradeLevelEditOpen(
                label:           p["label"]           as? String ?? "",
                type:            p["type"]            as? String ?? "",
                data:            tleoData,
                price:           p["price"]           as? Double ?? 0,
                side:            p["side"]            as? String,
                stopLossPrice:   p["stopLossPrice"]   as? Double,
                takeProfitPrice: p["takeProfitPrice"] as? Double,
                isFullscreen:    p["isFullscreen"]    as? Bool ?? false
            )

        case "tradeLevelBracketActivated":
            return .tradeLevelBracketActivated(
                label:        p["label"]        as? String ?? "",
                bracketType:  p["bracketType"]  as? String ?? "",
                price:        p["price"]        as? Double ?? 0,
                isFullscreen: p["isFullscreen"] as? Bool ?? false
            )

        case "draftInitiated":
            return .draftInitiated(
                side:         p["side"]         as? String ?? "",
                price:        p["price"]        as? Double ?? 0,
                orderType:    p["orderType"]    as? String ?? "",
                isFullscreen: p["isFullscreen"] as? Bool ?? false
            )

        case "draftCancelled":
            return .draftCancelled(
                label:        p["label"]        as? String ?? "",
                isFullscreen: p["isFullscreen"] as? Bool ?? false
            )

        case "dataRequest":
            guard
                let requestId  = p["requestId"] as? String,
                let timeframe  = p["timeframe"] as? String,
                let interval   = p["interval"]  as? String
            else { return nil }
            let drStart: Int64 = (p["start"] as? Int64) ?? Int64(p["start"] as? Double ?? 0)
            let drEnd:   Int64 = (p["end"]   as? Int64) ?? Int64(p["end"]   as? Double ?? 0)
            return .dataRequest(requestId: requestId, timeframe: timeframe, interval: interval,
                                start: drStart, end: drEnd)

        case "tfcToggle":
            return .tfcToggle(enabled: p["enabled"] as? Bool ?? false)

        case "symbolClick":
            return .symbolClick(symbol: p["symbol"] as? String ?? "")

        case "error":
            let message = p["message"] as? String ?? "Unknown error"
            let code    = p["code"]    as? String
            return .error(message: message, code: code?.isEmpty == false ? code : nil)

        default:
            return nil
        }
    }
}
