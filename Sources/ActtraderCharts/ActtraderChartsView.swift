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
    private let queueLock = NSLock()

    // ── Init ──────────────────────────────────────────────────────────────────

    /// Creates a chart view.
    ///
    /// - Parameters:
    ///   - theme: `"dark"` (default) or `"light"`.
    ///   - symbol: Symbol name displayed in the chart top bar (e.g. `"EURUSD"`).
    ///   - series: Initial chart type (e.g. `"candlestick"`, `"line"`). Defaults to `"candlestick"`.
    ///   - enableTrading: Show the floating trade button. Defaults to `false`.
    ///   - minLots: Minimum lot size shown in the order form. Relevant when `enableTrading` is `true`.
    public init(
        theme: String = "dark",
        symbol: String? = nil,
        series: String? = nil,
        enableTrading: Bool = false,
        minLots: Int = 1
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
            enableTrading: enableTrading,
            minLots: minLots,
            showCandleCountdown: nil,
            disableCountdownOnMobile: nil
        ))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Use init(theme:symbol:series:enableTrading:minLots:) instead")
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

    /// Called when the chart engine reports an error.
    public var onError: ((BridgeEvent) -> Void)?

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

        guard let url = bundle.url(forResource: "chart", withExtension: "html", subdirectory: "Resources") else {
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
            onReady?()
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
        case .placeOrder:   onPlaceOrder?(event)
        case .error:        onError?(event)
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
