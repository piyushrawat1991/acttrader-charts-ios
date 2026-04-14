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
        timeframe: String?,
        duration: String?,
        enableTrading: Bool,
        minLots: Int,
        showVolume: Bool?,
        showUI: Bool?,
        showDrawingTools: Bool?,
        showBidAskLines: Bool?,
        showActLogo: Bool?,
        showCandleCountdown: Bool?,
        candleCountdownTimeframes: [String]?,
        disableCountdownOnMobile: Bool?,
        maxSubPanes: Int?,
        mobileBarDivisor: Int?,
        targetCandleWidth: Double?,
        tickClosePriceSource: String?,
        tradesThresholdForHorizontalLine: Int?,
        tradeDisplayFilter: String?,
        positionRenderStyle: String?,
        hideLevelConfirmCancel: Bool?,
        hideQtyButton: Bool?,
        aggregateFrom: [String: String]?,
        canvasColorsJson: String?,
        themeOverridesJson: String?,
        labelsJson: String?,
        uiConfigJson: String?,
        durationTimeframeMap: [String: String]?,
        onSymbolClick: Bool?
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

    /// Resolves a pending dataLoader request with fetched bars.
    /// - Parameters:
    ///   - requestId: The ID received in the `dataRequest` bridge event.
    ///   - bars: The fetched OHLCV bars to return to the chart engine.
    case resolveDataRequest(requestId: String, bars: [OHLCVBar])

    /// Enables or disables verbose tick/render logging in the chart engine.
    case setDebug(Bool)

    /// Destroys the chart engine and releases resources.
    case destroy

    // ── Trade levels ──────────────────────────────────────────────────────────

    /// Replaces all levels of the given type with the provided data array.
    /// - Parameters:
    ///   - levels: Array of level objects. Each must contain at least `labelKey` and `priceKey` fields.
    ///             Optional per-entry fields: `side`, `stopLossPrice`, `takeProfitPrice`,
    ///             `pnl`, `pnlText`, `text`, `lots`, `orderType`, `entryPriceEditable`.
    ///   - labelKey: Key in each object that holds the level's label string.
    ///   - priceKey: Key in each object that holds the level's price (Double).
    ///   - type: `"position"`, `"pending"`, or `"trade"`.
    ///   - pnlKey: Optional key for a numeric P&L value.
    ///   - pnlTextKey: Optional key for a formatted P&L string.
    case setLevels(
        levels: [[String: Any]],
        labelKey: String,
        priceKey: String,
        type: String,
        pnlKey: String?,
        pnlTextKey: String?
    )

    /// Removes a single level by its label. No-op if not found.
    case removeLevelByLabel(String)

    /// Updates the entry price of an existing level.
    case updateLevelMainPrice(label: String, price: Double)

    /// Updates or removes a SL/TP bracket on an existing level.
    /// Pass `nil` for `price` to remove the bracket.
    /// - Parameter bracketType: `"sl"` or `"tp"`.
    case updateLevelBracket(label: String, bracketType: String, price: Double?)

    /// Cancels an in-progress level edit, reverting to the last confirmed price.
    case cancelLevelEdit(String)

    /// Programmatically selects (highlights) a level, or deselects all when `nil`.
    case selectLevel(String?)

    // ── Draft orders ──────────────────────────────────────────────────────────

    /// Shows a draggable limit or stop draft order line on the chart.
    /// While the user drags it, `tradeLevelDrag` events fire; confirming emits `tradeLevelConfirmed`.
    /// - Parameter orderType: `"limit"` or `"stop"`.
    case showDraftOrder(price: Double, side: String, orderType: String)

    /// Shows a non-draggable market-order preview line.
    /// SL/TP brackets can still be attached via `updateDraftOrderBracket`.
    case showMarketDraft(price: Double, side: String)

    /// Removes any active draft order from the chart.
    case clearDraftOrder

    /// Cancels whatever is currently being edited or drafted on the chart (draft order or level edit). No-op when nothing is active.
    case cancelCurrentEdit

    /// Updates the lot quantity shown on the active draft order chip.
    case setDraftOrderLots(Double)

    /// Moves the draft order price line to a new price.
    case updateDraftOrderPrice(Double)

    /// Updates or removes a SL/TP bracket on the active draft order.
    /// Pass `nil` for `price` to remove the bracket.
    /// - Parameter bracketType: `"sl"` or `"tp"`.
    case updateDraftOrderBracket(bracketType: String, price: Double?)

    // ── UI controls ───────────────────────────────────────────────────────────

    /// Shows or hides the volume sub-pane.
    case setVolume(Bool)

    /// Updates the symbol list used by the ISIN picker modal after initial setup.
    case setIsins([String])

    /// Updates the minimum lot size shown in the trade popover.
    case setMinLots(Double)

    /// Resets both price and time axes to their default auto-fit state.
    case resetView

    /// Shows or hides the loading overlay.
    case setLoading(Bool)

    /// Replaces a specific bar with authoritative OHLCV data (e.g. a correction from the server).
    /// - Parameter barTime: Unix millisecond timestamp of the bar to replace.
    case correctBar(barTime: Int64, bar: OHLCVBar)

    // ── Serialisation ─────────────────────────────────────────────────────────

    /// The JSON string to pass to `window.ChartBridge.send(...)`.
    public var jsonString: String {
        let envelope: [String: Any]
        switch self {

        case let .initialize(theme, symbol, series, timeframe, duration, enableTrading, minLots,
                             showVolume, showUI, showDrawingTools, showBidAskLines, showActLogo,
                             showCandleCountdown, candleCountdownTimeframes, disableCountdownOnMobile,
                             maxSubPanes, mobileBarDivisor, targetCandleWidth, tickClosePriceSource,
                             tradesThresholdForHorizontalLine, tradeDisplayFilter, positionRenderStyle,
                             hideLevelConfirmCancel, hideQtyButton,
                             aggregateFrom, canvasColorsJson, themeOverridesJson, labelsJson,
                             uiConfigJson, durationTimeframeMap, onSymbolClick):
            var payload: [String: Any] = ["theme": theme]
            if let symbol { payload["symbol"] = symbol }
            if let series { payload["series"] = series }
            if let timeframe { payload["timeframe"] = timeframe }
            if let duration { payload["duration"] = duration }
            if enableTrading {
                payload["enableTrading"] = true
                payload["minLots"] = minLots
            }
            if let showVolume { payload["showVolume"] = showVolume }
            if let showUI { payload["showUI"] = showUI }
            if let showDrawingTools { payload["showDrawingTools"] = showDrawingTools }
            if let showBidAskLines { payload["showBidAskLines"] = showBidAskLines }
            if let showActLogo { payload["showActLogo"] = showActLogo }
            if let showCandleCountdown { payload["showCandleCountdown"] = showCandleCountdown }
            if let candleCountdownTimeframes { payload["candleCountdownTimeframes"] = candleCountdownTimeframes }
            if let disableCountdownOnMobile { payload["disableCountdownOnMobile"] = disableCountdownOnMobile }
            if let maxSubPanes { payload["maxSubPanes"] = maxSubPanes }
            if let mobileBarDivisor { payload["mobileBarDivisor"] = mobileBarDivisor }
            if let targetCandleWidth { payload["targetCandleWidth"] = targetCandleWidth }
            if let tickClosePriceSource { payload["tickClosePriceSource"] = tickClosePriceSource }
            if let tradesThresholdForHorizontalLine { payload["tradesThresholdForHorizontalLine"] = tradesThresholdForHorizontalLine }
            if let tradeDisplayFilter { payload["tradeDisplayFilter"] = tradeDisplayFilter }
            if let positionRenderStyle { payload["positionRenderStyle"] = positionRenderStyle }
            if let hideLevelConfirmCancel { payload["hideLevelConfirmCancel"] = hideLevelConfirmCancel }
            if let hideQtyButton { payload["hideQtyButton"] = hideQtyButton }
            if let aggregateFrom { payload["aggregateFrom"] = aggregateFrom }
            if let durationTimeframeMap { payload["durationTimeframeMap"] = durationTimeframeMap }
            if let onSymbolClick, onSymbolClick { payload["onSymbolClick"] = true }
            func embedJson(_ key: String, _ json: String?) {
                guard let json,
                      let data = json.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data)
                else { return }
                payload[key] = obj
            }
            embedJson("canvasColors", canvasColorsJson)
            embedJson("themeOverrides", themeOverridesJson)
            embedJson("labels", labelsJson)
            embedJson("uiConfig", uiConfigJson)
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

        case let .resolveDataRequest(requestId, bars):
            let barsArray: [[String: Any]] = bars.map { bar in
                ["open": bar.open, "high": bar.high, "low": bar.low,
                 "close": bar.close, "volume": bar.volume, "time": bar.time]
            }
            envelope = ["type": "resolveDataRequest", "payload": ["requestId": requestId, "bars": barsArray]]

        case let .setDebug(enabled):
            envelope = ["type": "setDebug", "payload": ["enabled": enabled]]

        case .destroy:
            envelope = ["type": "destroy", "payload": [:]]

        // ── Trade levels ──────────────────────────────────────────────────────
        case let .setLevels(levels, labelKey, priceKey, type, pnlKey, pnlTextKey):
            var payload: [String: Any] = [
                "levels": levels, "labelKey": labelKey, "priceKey": priceKey, "type": type,
            ]
            if let pnlKey { payload["pnlKey"] = pnlKey }
            if let pnlTextKey { payload["pnlTextKey"] = pnlTextKey }
            envelope = ["type": "setLevels", "payload": payload]

        case let .removeLevelByLabel(label):
            envelope = ["type": "removeLevelByLabel", "payload": ["label": label]]

        case let .updateLevelMainPrice(label, price):
            envelope = ["type": "updateLevelMainPrice", "payload": ["label": label, "price": price]]

        case let .updateLevelBracket(label, bracketType, price):
            let priceValue: Any = price ?? NSNull()
            envelope = ["type": "updateLevelBracket",
                        "payload": ["label": label, "bracketType": bracketType, "price": priceValue]]

        case let .cancelLevelEdit(label):
            envelope = ["type": "cancelLevelEdit", "payload": ["label": label]]

        case let .selectLevel(label):
            let labelValue: Any = label ?? NSNull()
            envelope = ["type": "selectLevel", "payload": ["label": labelValue]]

        // ── Draft orders ──────────────────────────────────────────────────────
        case let .showDraftOrder(price, side, orderType):
            envelope = ["type": "showDraftOrder",
                        "payload": ["price": price, "side": side, "orderType": orderType]]

        case let .showMarketDraft(price, side):
            envelope = ["type": "showMarketDraft", "payload": ["price": price, "side": side]]

        case .clearDraftOrder:
            envelope = ["type": "clearDraftOrder", "payload": [:]]

        case .cancelCurrentEdit:
            envelope = ["type": "cancelCurrentEdit", "payload": [:]]

        case let .setDraftOrderLots(lots):
            envelope = ["type": "setDraftOrderLots", "payload": ["lots": lots]]

        case let .updateDraftOrderPrice(price):
            envelope = ["type": "updateDraftOrderPrice", "payload": ["price": price]]

        case let .updateDraftOrderBracket(bracketType, price):
            let priceValue: Any = price ?? NSNull()
            envelope = ["type": "updateDraftOrderBracket",
                        "payload": ["bracketType": bracketType, "price": priceValue]]

        // ── UI controls ───────────────────────────────────────────────────────
        case let .setVolume(show):
            envelope = ["type": "setVolume", "payload": ["show": show]]

        case let .setIsins(isins):
            envelope = ["type": "setIsins", "payload": ["isins": isins]]

        case let .setMinLots(lots):
            envelope = ["type": "setMinLots", "payload": ["lots": lots]]

        case .resetView:
            envelope = ["type": "resetView", "payload": [:]]

        case let .setLoading(loading):
            envelope = ["type": "setLoading", "payload": ["loading": loading]]

        case let .correctBar(barTime, bar):
            let barObj: [String: Any] = [
                "open": bar.open, "high": bar.high, "low": bar.low,
                "close": bar.close, "volume": bar.volume, "time": bar.time,
            ]
            envelope = ["type": "correctBar", "payload": ["barTime": barTime, "bar": barObj]]
        }

        guard
            let data = try? JSONSerialization.data(withJSONObject: envelope),
            let json = String(data: data, encoding: .utf8)
        else { return "{}" }
        return json
    }
}
