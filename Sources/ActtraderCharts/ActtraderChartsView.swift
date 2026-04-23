#if canImport(UIKit)
import UIKit
import WebKit

/// A self-contained chart view that renders the ActTrader chart bundle inside a `WKWebView`.
///
/// ## Basic usage
/// ```swift
/// let chart = ActtraderChartsView(theme: "dark", symbol: "EURUSD")
/// chart.onReady = { [weak chart] in
///     chart?.loadData(bars, fitAll: true)
/// }
/// chart.onError = { err in print("Chart error:", err) }
/// view.addSubview(chart)
/// // pin chart to edges with Auto Layout
/// ```
///
/// All public command methods are safe to call from any thread.
///
/// ## Performance notes (all applied at init time)
/// - `isOpaque = true` + matching `backgroundColor` — eliminates per-frame GPU compositing overhead
/// - `contentInsetAdjustmentBehavior = .never` — prevents safe-area insets from shifting chart layout
/// - `overrideUserInterfaceStyle` — blocks iOS dark-mode interference with chart colours
/// - Skeleton overlay — hides the blank WKWebView flash during cold-start
/// - Command batching — queues pre-ready commands and flushes in a single `evaluateJavaScript`
///   call (each call is an IPC round-trip to the out-of-process WebContent renderer)
public class ActtraderChartsView: UIView {

    // ── WKWebView ─────────────────────────────────────────────────────────────

    private let webView: WKWebView

    // ── Skeleton overlay ──────────────────────────────────────────────────────

    private let skeletonView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.074, green: 0.082, blue: 0.098, alpha: 1) // #13151a
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()

    // ── Command queue ─────────────────────────────────────────────────────────

    private var pendingCommands: [String] = []
    private var isReady = false
    private var hasCalledOnReady = false
    private let queueLock = NSLock()

    // ── Init ──────────────────────────────────────────────────────────────────

    /// Creates a chart view.
    ///
    /// - Parameters:
    ///   - theme: `"dark"` (default) or `"light"`.
    ///   - symbol: Symbol name displayed in the chart top bar (e.g. `"EURUSD"`).
    ///   - series: Initial chart type (e.g. `"candlestick"`, `"line"`). Defaults to `"candlestick"`.
    ///   - timeframe: Initial timeframe (e.g. `"1m"`, `"1h"`, `"1D"`).
    ///   - duration: Initial duration (e.g. `"1D"`, `"1M"`, `"1Y"`).
    ///   - enableTrading: Show the floating trade button. Defaults to `false`.
    ///   - showVolume: Show the volume panel. Defaults to `true` when `nil`.
    ///   - showUI: Show the chart toolbar UI. Defaults to `true` when `nil`.
    ///   - showDrawingTools: Show drawing tools in the toolbar. Defaults to `true` when `nil`.
    ///   - showBidAskLines: Show bid/ask price lines. Defaults to `false` when `nil`.
    ///   - showActLogo: Show the ActTrader watermark logo. Defaults to `false` when `nil`.
    ///   - showCandleCountdown: Show the candle countdown timer.
    ///   - candleCountdownTimeframes: Timeframes on which the countdown is shown. Pass `["all"]` to enable for all.
    ///   - disableCountdownOnMobile: Suppress the countdown specifically on mobile.
    ///   - maxSubPanes: Maximum number of indicator sub-panes (oscillators). Defaults to 3 when `nil`.
    ///   - mobileBarDivisor: Bar density divisor for mobile (2, 3, or 4). Defaults to 2 when `nil`.
    ///   - momentumScrollEnabled: Enable momentum (kinetic) scrolling on drag release. Defaults to `true` when `nil`.
    ///   - momentumDecay: Per-frame velocity decay factor, normalised to 60 fps. Clamped to [0.80, 0.99]. Defaults to `0.95` when `nil`.
    ///   - momentumThreshold: Minimum release velocity (px/ms) to trigger momentum. Defaults to `0.3` when `nil`.
    ///   - momentumMaxVelocity: Maximum launch velocity (px/ms) for momentum. Defaults to `6.0` when `nil`.
    ///   - targetCandleWidth: Target candle width in pixels. Defaults to 10 when `nil`.
    ///   - tickClosePriceSource: Price source for tick close (`"bid"` or `"ask"`). Defaults to `"bid"` when `nil`.
    ///   - tradesThresholdForHorizontalLine: Min trade count to render a horizontal level line.
    ///   - tradeDisplayFilter: Filter for which trade levels to display.
    ///   - positionRenderStyle: Render style for open positions.
    ///   - hideLevelConfirmCancel: Hide on-canvas confirm/cancel buttons on TFC level edits. Defaults to `false` when `nil`.
    ///   - tradeLevelButtonScale: Multiplier for trade-level Confirm/Cancel/Edit/Close button radii and gaps. Scales visuals AND hit/drag areas together — useful for larger touch targets. Clamped to `[1.0, 3.0]`. Defaults to `1.0` when `nil`.
    ///   - showSettings: Show the settings gear button in the top bar. Set to `false` to hide it entirely. Defaults to `true` when `nil`.
    ///   - hideSymbolAndTick: Hide the symbol name, OHLC strip, and tick-activity dot overlay. Defaults to `false` when `nil`.
    ///   - showBottomBar: Show the bottom duration-selector bar. Defaults to `false` when `nil`.
    ///   - aggregateFrom: Per-timeframe base interval override for client-side aggregation (e.g. `["1h": "1m"]`).
    ///   - canvasColorsJson: JSON string of per-theme canvas background color overrides.
    ///   - themeOverridesJson: JSON string of per-theme deep-partial color overrides.
    ///   - labelsJson: JSON string of user-visible string overrides for i18n/localisation.
    ///   - uiConfigJson: JSON string of per-component UI configuration overrides (font sizes, spacing).
    ///   - durationTimeframeMap: Override the default duration → timeframe pairings for the bottom bar.
    ///   - onSymbolClick: When `true`, fires a `symbolClick` event on symbol tap instead of opening the picker modal.
    ///   - initialState: Raw JSON string from a prior `onStateSnapshot` callback. When provided, the full
    ///     chart state (timeframe, series, indicators, drawings, etc.) is restored atomically alongside the
    ///     `init` command — both are queued before the WebView fires `ready` and flushed in a single
    ///     `evaluateJavaScript` call, so there is no intermediate "1D" flash.
    public init(
        theme: String = "dark",
        symbol: String? = nil,
        series: String? = nil,
        timeframe: String? = nil,
        duration: String? = nil,
        enableTrading: Bool = false,
        showVolume: Bool? = nil,
        showUI: Bool? = nil,
        showDrawingTools: Bool? = nil,
        showBidAskLines: Bool? = nil,
        showActLogo: Bool? = nil,
        showCandleCountdown: Bool? = nil,
        candleCountdownTimeframes: [String]? = nil,
        disableCountdownOnMobile: Bool? = nil,
        maxSubPanes: Int? = nil,
        mobileBarDivisor: Int? = nil,
        /// Minimum bars expected from the initial fetch before giving up. If fewer bars
        /// are returned by `onDataRequest`, the chart engine auto-widens the lookback
        /// window and retries — useful for weekends and sparse symbols. Default: `10`.
        minInitialBars: Int? = nil,
        /// Hard ceiling (in milliseconds) on fetch-window lookback for auto-widening
        /// retries. Default: 365 days.
        maxLookbackMs: Int64? = nil,
        momentumScrollEnabled: Bool? = nil,
        momentumDecay: Double? = nil,
        momentumThreshold: Double? = nil,
        momentumMaxVelocity: Double? = nil,
        targetCandleWidth: Double? = nil,
        tickClosePriceSource: String? = nil,
        tradesThresholdForHorizontalLine: Int? = nil,
        tradeDisplayFilter: String? = nil,
        positionRenderStyle: String? = nil,
        hideLevelConfirmCancel: Bool? = nil,
        tradeLevelButtonScale: Double? = nil,
        levelClusteringEnabled: Bool? = nil,
        clusterThresholdDistance: Int? = nil,
        tfcEnabled: Bool? = nil,
        showSettings: Bool? = nil,
        showFullscreenButton: Bool = false,
        /// Show the snapshot (camera) button in the top bar. Opens a flyout with
        /// Download (saves to Photos) and Copy (to UIPasteboard) actions.
        /// Defaults to `true` when `nil`.
        showSnapshotButton: Bool? = nil,
        hideSymbolAndTick: Bool? = nil,
        showBottomBar: Bool? = nil,
        aggregateFrom: [String: String]? = nil,
        canvasColorsJson: String? = nil,
        themeOverridesJson: String? = nil,
        themeOverrides: ThemeOverrides? = nil,
        labelsJson: String? = nil,
        uiConfigJson: String? = nil,
        durationTimeframeMap: [String: String]? = nil,
        onSymbolClick: Bool? = nil,
        /// IANA timezone string for time-axis and crosshair labels. Default: `"UTC"`.
        timezone: String? = nil,
        initialState: String? = nil
    ) {
        // Build WKWebView configuration
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: .zero, configuration: config)

        // Tier 1: Compositing — solid background avoids per-frame alpha-blend pass
        wv.isOpaque = true
        wv.backgroundColor = theme == "light" ? .white : UIColor(red: 0.074, green: 0.082, blue: 0.098, alpha: 1)
        wv.scrollView.backgroundColor = wv.backgroundColor

        // Tier 1: Disable scroll entirely (chart handles pan/zoom internally)
        wv.scrollView.isScrollEnabled = false
        wv.scrollView.bounces = false

        // Tier 1: Safe area — prevent notch/home-indicator insets from shifting layout
        wv.scrollView.contentInsetAdjustmentBehavior = .never

        // Tier 2: Prevent iOS dark-mode from overriding chart colours
        wv.overrideUserInterfaceStyle = theme == "light" ? .light : .dark

        wv.translatesAutoresizingMaskIntoConstraints = false
        self.webView = wv

        super.init(frame: .zero)

        // Register weak-proxy message handler (avoids retain cycle)
        config.userContentController.add(WeakScriptMessageHandler(self), name: "chartBridge")

        addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: topAnchor),
            webView.bottomAnchor.constraint(equalTo: bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        // Skeleton overlay — hides blank flash during WKWebView cold-start
        addSubview(skeletonView)
        NSLayoutConstraint.activate([
            skeletonView.topAnchor.constraint(equalTo: topAnchor),
            skeletonView.bottomAnchor.constraint(equalTo: bottomAnchor),
            skeletonView.leadingAnchor.constraint(equalTo: leadingAnchor),
            skeletonView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])

        loadHTML()

        // Queue init command — flushed when `ready` event fires
        sendCommand(.initialize(
            theme: theme,
            symbol: symbol,
            series: series,
            timeframe: timeframe,
            duration: duration,
            enableTrading: enableTrading,
            showVolume: showVolume,
            showUI: showUI,
            showDrawingTools: showDrawingTools,
            showBidAskLines: showBidAskLines,
            showActLogo: showActLogo,
            showCandleCountdown: showCandleCountdown,
            candleCountdownTimeframes: candleCountdownTimeframes,
            disableCountdownOnMobile: disableCountdownOnMobile,
            maxSubPanes: maxSubPanes,
            mobileBarDivisor: mobileBarDivisor,
            minInitialBars: minInitialBars,
            maxLookbackMs: maxLookbackMs,
            momentumScrollEnabled: momentumScrollEnabled,
            momentumDecay: momentumDecay,
            momentumThreshold: momentumThreshold,
            momentumMaxVelocity: momentumMaxVelocity,
            targetCandleWidth: targetCandleWidth,
            tickClosePriceSource: tickClosePriceSource,
            tradesThresholdForHorizontalLine: tradesThresholdForHorizontalLine,
            tradeDisplayFilter: tradeDisplayFilter,
            positionRenderStyle: positionRenderStyle,
            hideLevelConfirmCancel: hideLevelConfirmCancel,
            tradeLevelButtonScale: tradeLevelButtonScale,
            levelClusteringEnabled: levelClusteringEnabled,
            clusterThresholdDistance: clusterThresholdDistance,
            tfcEnabled: tfcEnabled,
            showSettings: showSettings,
            showFullscreenButton: showFullscreenButton,
            showSnapshotButton: showSnapshotButton,
            hideSymbolAndTick: hideSymbolAndTick,
            showBottomBar: showBottomBar,
            aggregateFrom: aggregateFrom,
            canvasColorsJson: canvasColorsJson,
            themeOverridesJson: themeOverridesJson ?? themeOverrides?.toJsonString(),
            labelsJson: labelsJson,
            uiConfigJson: uiConfigJson,
            durationTimeframeMap: durationTimeframeMap,
            onSymbolClick: onSymbolClick,
            timezone: timezone
        ))

        // Queue state restoration alongside the init command so both are evaluated
        // in a single evaluateJavaScript call when the WebView fires `ready`.
        // This prevents the engine from briefly rendering with its "1D" default
        // before the saved timeframe, series, and indicators are applied.
        if let initialState { sendCommand(.setState(initialState)) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(theme:symbol:series:enableTrading:) instead")
    }

    deinit {
        // Safety net — retain cycle is already broken by WeakScriptMessageHandler,
        // but remove explicitly in case the view is torn down while loading.
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "chartBridge")
    }

    // ── Typed event callbacks ─────────────────────────────────────────────────

    /// Called when the chart engine is ready to receive commands.
    public var onReady: (() -> Void)?

    /// Called whenever the crosshair moves over a bar.
    public var onCrosshair: ((BridgeEvent) -> Void)?

    /// Called when the user taps a bar.
    public var onBarClick: ((BridgeEvent) -> Void)?

    /// Called when the visible viewport changes (pan / zoom).
    public var onViewportChange: ((BridgeEvent) -> Void)?

    /// Called when the active series type changes.
    public var onSeriesChange: ((BridgeEvent) -> Void)?

    /// Called when the active timeframe changes.
    public var onTimeframeChange: ((BridgeEvent) -> Void)?

    /// Called when the active duration changes.
    public var onDurationChange: ((BridgeEvent) -> Void)?

    /// Called on any chart state mutation.
    public var onStateChange: ((BridgeEvent) -> Void)?

    /// Called in response to `getState()`; contains the full serialised state JSON.
    public var onStateSnapshot: ((BridgeEvent) -> Void)?

    /// Called after `loadData()` completes.
    public var onDataLoaded: ((BridgeEvent) -> Void)?

    /// Called when a new bar is appended at the live edge.
    public var onNewBar: ((BridgeEvent) -> Void)?

    /// Called when the stream connection status changes.
    public var onStreamStatus: ((BridgeEvent) -> Void)?

    /// Called when the user submits an order via the floating trade button.
    public var onPlaceOrder: ((BridgeEvent) -> Void)?

    /// Called when the user taps × to close or cancel a trade level or remove a bracket.
    public var onTradeLevelClose: ((BridgeEvent) -> Void)?

    /// Called on every pointer move while a level or bracket is being dragged.
    public var onTradeLevelDrag: ((BridgeEvent) -> Void)?

    /// Called when the user confirms edits to a trade level (main, SL, TP batched together).
    public var onTradeLevelEdit: ((BridgeEvent) -> Void)?

    /// Called on every live qty edit via the QTY pill flyout — before the level edit is confirmed.
    /// Use to refresh Estimated PNL for SL/TP brackets in real time.
    public var onTradeLevelQtyChange: ((BridgeEvent) -> Void)?

    /// Called when the chart ✓ button confirms an edit (including draft orders).
    public var onTradeLevelConfirmed: ((BridgeEvent) -> Void)?

    /// Called when an in-progress level edit is cancelled from the chart (ESC key or inline ✕ cancel button).
    public var onTradeLevelEditCancelled: ((BridgeEvent) -> Void)?

    /// Called when the user taps the pencil/edit button to open the order panel for a level.
    public var onTradeLevelEditOpen: ((BridgeEvent) -> Void)?

    /// Called after `addLevelBracket()` auto-places a SL/TP bracket.
    /// Use the `price` in the event to populate your order form's SL/TP input field.
    public var onTradeLevelBracketActivated: ((BridgeEvent) -> Void)?

    /// Called when a new draft order is shown on the chart — open the buy/sell form.
    public var onDraftInitiated: ((BridgeEvent) -> Void)?

    /// Called when a draft order is cancelled without confirming.
    public var onDraftCancelled: ((BridgeEvent) -> Void)?

    /// Called when TFC (Trade from Charts) is toggled on or off via the top bar button or API.
    public var onTfcToggle: ((BridgeEvent) -> Void)?

    /// Called whenever a chart flyout/modal/dropdown opens or closes.
    /// Most hosts won't need this — ``hasOpenUI`` is maintained automatically and
    /// ``dismissAllUI()`` is the usual integration point.
    public var onUiStateChange: ((BridgeEvent) -> Void)?

    /// Called when the chart engine requests data for a time range.
    ///
    /// Implement this to serve data requests from the chart. Fetch bars for the given
    /// `timeframe`/`interval` and `start`/`end` timestamps (milliseconds since epoch),
    /// then call `resolveDataRequest(requestId:bars:)` to deliver the data.
    public var onDataRequest: ((BridgeEvent) -> Void)?

    /// Called when the user taps the symbol name and `onSymbolClick` was enabled in the init command.
    public var onSymbolClick: ((BridgeEvent) -> Void)?

    /// Called when the chart engine reports an error.
    public var onError: ((BridgeEvent) -> Void)?

    /// Called after a chart snapshot has been handled (saved to Photos or copied
    /// to the system pasteboard). When the handler itself fails, `error` carries
    /// the failure reason; on success it is `nil`.
    ///
    /// Snapshots are triggered by the camera button in the chart's top bar and
    /// handled internally by ``ActtraderChartsView`` — this callback lets the
    /// host react (toast, haptic, etc.) if desired.
    public var onSnapshotResult: ((_ mode: String, _ filename: String, _ error: String?) -> Void)?

    /// Generic fallback — called for every event including those that have a typed callback.
    public var onBridgeEvent: ((BridgeEvent) -> Void)?

    // ── Public command API ────────────────────────────────────────────────────

    /// Loads a full dataset into the chart.
    ///
    /// Emits `onDataLoaded` on completion. Safe to call before `onReady` fires.
    public func loadData(_ bars: [OHLCVBar], fitAll: Bool = false) {
        sendCommand(.loadData(bars: bars, fitAll: fitAll))
    }

    /// Switches between `"dark"` and `"light"` themes.
    public func setTheme(_ theme: String) {
        webView.backgroundColor = theme == "light" ? .white : UIColor(red: 0.074, green: 0.082, blue: 0.098, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.overrideUserInterfaceStyle = theme == "light" ? .light : .dark
        sendCommand(.setTheme(theme))
    }

    /// Changes the display timezone for time-axis and crosshair labels.
    /// Accepts any IANA string (e.g. `"America/New_York"`), `"UTC"`, or `"local"`.
    public func setTimezone(_ timezone: String) {
        sendCommand(.setTimezone(timezone))
    }

    /// Changes the chart series type.
    ///
    /// Valid values: `"candlestick"`, `"hollow_candle"`, `"line"`, `"area"`, `"ohlc"`.
    public func setSeries(_ series: String) {
        sendCommand(.setSeries(series))
    }

    /// Pushes a live tick for streaming updates.
    ///
    /// The bridge aggregates ticks into the current candle; use `loadData(_:)` for bulk replacement.
    public func pushTick(bid: Double, ask: Double, timestamp: Int64) {
        sendCommand(.pushTick(bid: bid, ask: ask, timestamp: timestamp))
    }

    /// Changes the active timeframe (e.g. `"1m"`, `"1h"`, `"1D"`).
    public func setTimeframe(_ timeframe: String) {
        sendCommand(.setTimeframe(timeframe))
    }

    /// Updates the displayed symbol name in the chart's top bar.
    public func setSymbol(_ symbol: String) {
        sendCommand(.setSymbol(symbol))
    }

    /// Adds a study by short name (e.g. `"SMA"`, `"EMA"`, `"RSI"`, `"BB"`).
    public func addIndicator(_ name: String, params: [String: Any]? = nil) {
        sendCommand(.addIndicator(name: name, params: params))
    }

    /// Removes a study by name.
    public func removeIndicator(_ name: String) {
        sendCommand(.removeIndicator(name))
    }

    /// Activates a drawing tool by ID (e.g. `"trend_line"`, `"horizontal_line"`).
    ///
    /// Pass `nil` to deactivate the current drawing tool.
    public func setDrawingTool(_ tool: String?) {
        sendCommand(.setDrawingTool(tool))
    }

    /// Removes all drawings from the chart.
    public func clearAllDrawings() {
        sendCommand(.clearAllDrawings)
    }

    /// Requests the current chart state.
    ///
    /// The result is delivered asynchronously via `onStateSnapshot`.
    public func getState() {
        sendCommand(.getState)
    }

    /// Restores a previously captured chart state.
    ///
    /// - Parameter stateJson: Raw JSON string from a prior `onStateSnapshot` callback.
    public func setState(_ stateJson: String) {
        sendCommand(.setState(stateJson))
    }

    /// Resolves a pending data request from the chart engine with fetched bars.
    ///
    /// Call this from `onDataRequest` after fetching the required data.
    /// - Parameters:
    ///   - requestId: The `requestId` received in the `dataRequest` event.
    ///   - bars: The OHLCV bars covering the requested time range.
    public func resolveDataRequest(requestId: String, bars: [OHLCVBar]) {
        sendCommand(.resolveDataRequest(requestId: requestId, bars: bars))
    }

    /// Enables or disables verbose tick/render logging in the browser console.
    ///
    /// Useful for diagnosing live candle or streaming issues during development.
    public func setDebug(_ enabled: Bool) {
        sendCommand(.setDebug(enabled))
    }

    // ── Trade levels ──────────────────────────────────────────────────────────

    /// Replaces all levels of the given type with the provided data array.
    ///
    /// Pass `type: "position"` for open positions, `"pending"` for limit/stop orders,
    /// or `"trade"` for read-only reference lines. Each dict in `levels` must contain
    /// at least the `labelKey` and `priceKey` entries. Optional entries include
    /// `side`, `stopLossPrice`, `takeProfitPrice`, `pnl`, `pnlText`, `text`,
    /// `lots`, `orderType`, and `entryPriceEditable`.
    public func setLevels(_ levels: [[String: Any]], labelKey: String, priceKey: String,
                          type: String, pnlKey: String? = nil, pnlTextKey: String? = nil) {
        sendCommand(.setLevels(levels: levels, labelKey: labelKey, priceKey: priceKey,
                               type: type, pnlKey: pnlKey, pnlTextKey: pnlTextKey))
    }

    /// Removes a single level by its label. No-op if no level with that label exists.
    public func removeLevelByLabel(_ label: String) {
        sendCommand(.removeLevelByLabel(label))
    }

    /// Updates the entry price of an existing level.
    public func updateLevelMainPrice(label: String, price: Double) {
        sendCommand(.updateLevelMainPrice(label: label, price: price))
    }

    /// Updates or removes a SL/TP bracket on an existing level.
    /// - Parameter bracketType: `"sl"` or `"tp"`.
    /// - Parameter price: Pass `nil` to remove the bracket.
    public func updateLevelBracket(label: String, bracketType: String, price: Double?) {
        sendCommand(.updateLevelBracket(label: label, bracketType: bracketType, price: price))
    }

    /// Adds a SL or TP bracket to an existing level at an auto-computed default price.
    /// Listen for `onTradeLevelBracketActivated` to receive the chosen price so your form can populate its input.
    /// - Parameter bracketType: `"sl"` or `"tp"`.
    public func addLevelBracket(label: String, bracketType: String) {
        sendCommand(.addLevelBracket(label: label, bracketType: bracketType))
    }

    /// Unified bracket placement — works for both existing levels and the active draft order.
    /// Pass `label` (OrderID/TradeID) for an existing level; omit it for the active draft order.
    /// Fires `onTradeLevelBracketActivated` with the auto-computed price.
    /// The event's `label` is `""` (empty string) when the bracket was placed on a draft order — check `label.isEmpty` to detect the draft case.
    public func addBracket(bracketType: String, label: String? = nil) {
        sendCommand(.addBracket(bracketType: bracketType, label: label))
    }

    /// Unified bracket removal — works for both existing levels and the active draft order.
    /// Pass `label` (OrderID/TradeID) for an existing level; omit it for the active draft order.
    public func removeBracket(bracketType: String, label: String? = nil) {
        sendCommand(.removeBracket(bracketType: bracketType, label: label))
    }

    /// Cancels an in-progress level edit, reverting to the last confirmed price.
    public func cancelLevelEdit(_ label: String) {
        sendCommand(.cancelLevelEdit(label))
    }

    /// Programmatically selects (highlights) a level. Pass `nil` to deselect all.
    public func selectLevel(_ label: String?) {
        sendCommand(.selectLevel(label))
    }

    // ── Draft orders ──────────────────────────────────────────────────────────

    /// Shows a draggable limit or stop draft order line on the chart.
    ///
    /// While the user drags it the `onTradeLevelDrag` event fires on each move.
    /// Confirming via the chart button emits `onTradeLevelConfirmed`.
    /// - Parameter orderType: `"limit"` or `"stop"`.
    public func showDraftOrder(price: Double, side: String, orderType: String) {
        sendCommand(.showDraftOrder(price: price, side: side, orderType: orderType))
    }

    /// Shows a non-draggable market-order preview line.
    ///
    /// SL/TP brackets can still be attached via `updateDraftOrderBracket`.
    public func showMarketDraft(price: Double, side: String) {
        sendCommand(.showMarketDraft(price: price, side: side))
    }

    /// Removes any active draft order from the chart.
    public func clearDraftOrder() {
        sendCommand(.clearDraftOrder)
    }

    /// Cancels whatever is currently being edited or drafted on the chart (draft order or level edit). No-op when nothing is active.
    public func cancelCurrentEdit() {
        sendCommand(.cancelCurrentEdit)
    }

    /// Updates the lot quantity shown on the active draft order chip.
    public func setDraftOrderLots(_ lots: Double) {
        sendCommand(.setDraftOrderLots(lots))
    }

    /// Moves the draft order price line to a new price.
    public func updateDraftOrderPrice(_ price: Double) {
        sendCommand(.updateDraftOrderPrice(price))
    }

    /// Updates or removes a SL/TP bracket on the active draft order.
    /// - Parameter bracketType: `"sl"` or `"tp"`.
    /// - Parameter price: Pass `nil` to remove the bracket.
    public func updateDraftOrderBracket(bracketType: String, price: Double?) {
        sendCommand(.updateDraftOrderBracket(bracketType: bracketType, price: price))
    }

    /// Sets or clears the estimated PNL text shown on a draft order's SL or TP bracket line.
    /// Call this after `updateDraftOrderBracket` to display consumer-calculated P&L.
    /// - Parameter bracketType: `"sl"` or `"tp"`.
    /// - Parameter pnlText: Pre-formatted string (e.g. `"-$12.50"`). Pass `nil` to clear.
    public func setDraftBracketPnl(bracketType: String, pnlText: String?) {
        sendCommand(.setDraftBracketPnl(bracketType: bracketType, pnlText: pnlText))
    }

    // ── UI controls ───────────────────────────────────────────────────────────

    /// Shows or hides the volume sub-pane.
    public func setVolume(_ show: Bool) {
        sendCommand(.setVolume(show))
    }

    /// Toggles TFC (Trade from Charts) on or off at runtime.
    ///
    /// When disabled, all trade levels, the floating trade button, and draft orders are hidden.
    /// Re-enabling restores them. Fires `onTfcToggle` with the new state.
    public func setTfcActive(_ enabled: Bool) {
        sendCommand(.setTfcActive(enabled))
    }

    /// Updates the symbol list used by the ISIN picker modal after initial setup.
    public func setIsins(_ isins: [String]) {
        sendCommand(.setIsins(isins))
    }

    /// Resets both price and time axes to their default auto-fit state.
    public func resetView() {
        sendCommand(.resetView)
    }

    // ── UI dismissal ──────────────────────────────────────────────────────────

    /// `true` when any chart flyout/modal/dropdown/popover is currently open.
    /// Mirrored automatically from `uiStateChange` events emitted by the WebView.
    public private(set) var hasOpenUI: Bool = false

    /// Dismisses any open chart UI (flyouts, modals, dropdowns, popovers) and returns
    /// whether anything was dismissed.
    ///
    /// iOS has no hardware back button, but this is the integration point for
    /// custom nav-bar back buttons, interactive pop-gesture handlers, or any other
    /// host-level dismiss action. Consume the user's back action only when this
    /// returns `true`; otherwise let the normal navigation proceed.
    ///
    /// ```swift
    /// @objc func backTapped() {
    ///     if !chart.dismissAllUI() {
    ///         navigationController?.popViewController(animated: true)
    ///     }
    /// }
    /// ```
    ///
    /// - Returns: `true` if a flyout/modal was dismissed; `false` if nothing was open.
    @discardableResult
    public func dismissAllUI() -> Bool {
        guard hasOpenUI else { return false }
        sendCommand(.dismissAllUI)
        return true
    }

    /// Completely resets the chart to a blank state.
    ///
    /// Cancels any in-flight data fetch, clears all bars, and discards the live
    /// bid/ask price line. Call this before switching to a new symbol so that no
    /// previous symbol data bleeds into the new chart, then follow with `loadData(_:)`.
    ///
    /// ```swift
    /// chart.setSymbol("GBPUSD")
    /// chart.resetData()
    /// // … fetch new bars …
    /// chart.loadData(newBars)
    /// ```
    public func resetData() {
        sendCommand(.resetData)
    }

    /// Shows or hides the loading overlay.
    public func setLoading(_ loading: Bool) {
        sendCommand(.setLoading(loading))
    }

    /// Updates per-theme deep-partial color overrides and rebuilds the active theme.
    /// - Parameter overridesJson: Raw JSON string, e.g. `{"dark":{"background":"#111"}}`.
    public func setThemeOverrides(_ overridesJson: String) {
        sendCommand(.setThemeOverrides(overridesJson))
    }

    /// Updates per-theme deep-partial color overrides and rebuilds the active theme.
    /// - Parameter overrides: Typed theme overrides — only the keys you supply are replaced.
    public func setThemeOverrides(_ overrides: ThemeOverrides) {
        sendCommand(.setThemeOverrides(overrides.toJsonString()))
    }

    /// Replaces a specific bar with authoritative OHLCV data (e.g. a correction from the server).
    /// - Parameter barTime: Unix millisecond timestamp of the bar to replace.
    public func correctBar(barTime: Int64, bar: OHLCVBar) {
        sendCommand(.correctBar(barTime: barTime, bar: bar))
    }

    /// Destroys the chart engine and releases WebView resources.
    public func destroy() {
        sendCommand(.destroy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.webView.stopLoading()
        }
    }

    // ── Static helpers ────────────────────────────────────────────────────────

    /// Pre-warms the WKWebView OS process before the chart screen appears.
    ///
    /// WKWebView spawns a separate `com.apple.WebKit.WebContent` process on first use.
    /// Call `prewarm()` early (e.g. in `AppDelegate` or `SceneDelegate`) to absorb the
    /// 200–400 ms startup cost before the user navigates to the chart screen.
    ///
    /// ```swift
    /// // AppDelegate.application(_:didFinishLaunchingWithOptions:)
    /// ActtraderChartsView.prewarm()
    /// ```
    public static func prewarm() {
        _ = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
    }

    // ── Internal ──────────────────────────────────────────────────────────────

    private func loadHTML() {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: ActtraderChartsView.self)
        #endif

        guard let url = bundle.url(forResource: "chart", withExtension: "html") else {
            assertionFailure("chart.html not found in ActtraderCharts bundle. Run the sync workflow first.")
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    private func sendCommand(_ cmd: BridgeCommand) {
        let json = cmd.jsonString
        queueLock.lock()
        let ready = isReady
        if !ready { pendingCommands.append(json) }
        queueLock.unlock()

        guard ready else { return }
        evalJS(json)
    }

    private func evalJS(_ json: String) {
        let escaped = json
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
        let js = "window.ChartBridge.send('\(escaped)');"
        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js)
        }
    }

    private func flushPendingCommands() {
        queueLock.lock()
        let batch = pendingCommands
        pendingCommands.removeAll()
        isReady = true
        queueLock.unlock()

        guard !batch.isEmpty else { return }
        let js = batch.map { json in
            let escaped = json
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            return "window.ChartBridge.send('\(escaped)');"
        }.joined(separator: " ")

        DispatchQueue.main.async { [weak self] in
            self?.webView.evaluateJavaScript(js)
        }
    }

    private func dispatchEvent(_ event: BridgeEvent) {
        onBridgeEvent?(event)
        switch event {
        case .ready:
            flushPendingCommands()
            UIView.animate(withDuration: 0.2) { self.skeletonView.alpha = 0 } completion: { _ in
                self.skeletonView.isHidden = true
            }
            if !hasCalledOnReady {
                hasCalledOnReady = true
                onReady?()
            }
        case .crosshair:    onCrosshair?(event)
        case .barClick:     onBarClick?(event)
        case .viewportChange: onViewportChange?(event)
        case .seriesChange: onSeriesChange?(event)
        case .timeframeChange: onTimeframeChange?(event)
        case .durationChange: onDurationChange?(event)
        case .stateChange:  onStateChange?(event)
        case .stateSnapshot: onStateSnapshot?(event)
        case .dataLoaded:   onDataLoaded?(event)
        case .newBar:       onNewBar?(event)
        case .streamStatus: onStreamStatus?(event)
        case .placeOrder:          onPlaceOrder?(event)
        case .tradeLevelClose:     onTradeLevelClose?(event)
        case .tradeLevelDrag:      onTradeLevelDrag?(event)
        case .tradeLevelEdit:      onTradeLevelEdit?(event)
        case .tradeLevelQtyChange: onTradeLevelQtyChange?(event)
        case .tradeLevelConfirmed: onTradeLevelConfirmed?(event)
        case .tradeLevelEditCancelled: onTradeLevelEditCancelled?(event)
        case .tradeLevelEditOpen:          onTradeLevelEditOpen?(event)
        case .tradeLevelBracketActivated:  onTradeLevelBracketActivated?(event)
        case .draftInitiated:              onDraftInitiated?(event)
        case .draftCancelled:      onDraftCancelled?(event)
        case .tfcToggle:           onTfcToggle?(event)
        case let .uiStateChange(hasOpenUI):
            self.hasOpenUI = hasOpenUI
            onUiStateChange?(event)
        case .dataRequest:         onDataRequest?(event)
        case .symbolClick:         onSymbolClick?(event)
        case let .snapshot(mode, filename, _, base64, _, _, _):
            handleSnapshot(mode: mode, filename: filename, base64: base64)
        case .snapshotTaken:
            break // success is signalled via onSnapshotResult from handleSnapshot
        case let .snapshotError(mode, reason):
            onSnapshotResult?(mode, "", reason)
        case .error:               onError?(event)
        }
    }

    private func handleSnapshot(mode: String, filename: String, base64: String) {
        guard let data = Data(base64Encoded: base64) else {
            onSnapshotResult?(mode, filename, "base64-decode-failed")
            return
        }
        guard let image = UIImage(data: data) else {
            onSnapshotResult?(mode, filename, "image-decode-failed")
            return
        }

        switch mode {
        case "download":
            // Requires NSPhotoLibraryAddUsageDescription in the host app's Info.plist.
            UIImageWriteToSavedPhotosAlbum(image, self, #selector(photoSaveCompleted(_:didFinishSavingWithError:contextInfo:)), UnsafeMutableRawPointer(mutating: (filename as NSString).utf8String))
        case "copy":
            UIPasteboard.general.image = image
            onSnapshotResult?(mode, filename, nil)
        default:
            onSnapshotResult?(mode, filename, "unknown-mode")
        }
    }

    @objc private func photoSaveCompleted(_ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer?) {
        let filename: String = {
            guard let ptr = contextInfo else { return "" }
            return String(cString: ptr.assumingMemoryBound(to: CChar.self))
        }()
        if let error {
            onSnapshotResult?("download", filename, error.localizedDescription)
        } else {
            onSnapshotResult?("download", filename, nil)
        }
    }
}

// ── WKScriptMessageHandler ────────────────────────────────────────────────────

extension ActtraderChartsView: WKScriptMessageHandler {

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard
            let body = message.body as? String,
            let event = BridgeEvent.parse(body)
        else { return }

        DispatchQueue.main.async { [weak self] in
            self?.dispatchEvent(event)
        }
    }
}

#endif // canImport(UIKit)
