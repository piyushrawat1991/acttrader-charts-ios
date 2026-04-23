# ActtraderCharts — iOS

iOS Swift framework that embeds the ActTrader financial charting library inside a `WKWebView`.

## Requirements

- iOS 14.0+
- Swift 5.7+
- Xcode 15+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/piyushrawat1991/acttrader-charts-ios.git", from: "0.1.0")
```

Or in Xcode: **File → Add Package Dependencies…** and enter the repo URL.

### CocoaPods

```ruby
pod 'ActtraderCharts', '~> 0.1'
```

### Beta releases

Pre-release builds are tagged as `vX.Y.Z-beta.N`. Both CocoaPods (`~>`) and SPM (`from:`) **exclude prereleases by default** — you must pin exactly to opt in.

**SPM:**

```swift
.package(url: "https://github.com/piyushrawat1991/acttrader-charts-ios.git", exact: "1.1.0-beta.1")
```

**CocoaPods:**

```ruby
pod 'ActtraderCharts', '1.1.0-beta.1'
```

Existing dependency declarations using `from:` or `~>` continue to resolve only to stable releases.

## Usage

```swift
import ActtraderCharts

let chart = ActtraderChartsView(theme: "dark", symbol: "EURUSD")

chart.onReady = { [weak chart] in
    chart?.loadData(bars, fitAll: true)
}

chart.onCrosshair = { event in
    if case let .crosshair(time, open, high, low, close, volume, _, _) = event {
        print("Hovered bar — O:\(open) H:\(high) L:\(low) C:\(close)")
    }
}

chart.onError = { event in
    if case let .error(message, _) = event {
        print("Chart error:", message)
    }
}

view.addSubview(chart)
chart.translatesAutoresizingMaskIntoConstraints = false
NSLayoutConstraint.activate([
    chart.topAnchor.constraint(equalTo: view.topAnchor),
    chart.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    chart.leadingAnchor.constraint(equalTo: view.leadingAnchor),
    chart.trailingAnchor.constraint(equalTo: view.trailingAnchor),
])
```

### Pre-warming (optional, recommended)

Call `prewarm()` before the chart screen appears to absorb the WKWebView process startup cost (200–400 ms):

```swift
// AppDelegate or SceneDelegate
ActtraderChartsView.prewarm()
```

## API

### Constructor parameters

| Parameter | Type | Default | Description |
|---|---|---|---|
| `theme` | `String` | `"dark"` | `"dark"` or `"light"` |
| `symbol` | `String?` | `nil` | Symbol name shown in the top bar (e.g. `"EURUSD"`) |
| `series` | `String?` | `nil` | Initial chart type (e.g. `"candlestick"`, `"line"`, `"area"`, `"ohlc"`, `"hollow_candle"`) |
| `timeframe` | `String?` | `nil` | Initial timeframe (e.g. `"1m"`, `"5m"`, `"1h"`, `"1D"`) |
| `duration` | `String?` | `nil` | Initial duration button (e.g. `"1D"`, `"1M"`, `"1Y"`, `"All"`) |
| `showVolume` | `Bool?` | `nil` | Show volume bars |
| `showUI` | `Bool?` | `nil` | Show top / bottom bars. When `false`, the loading overlay is also suppressed |
| `showDrawingTools` | `Bool?` | `nil` | Show drawing toolbar and pencil button |
| `showBidAskLines` | `Bool?` | `nil` | Show bid and ask as dashed lines during a live stream |
| `showActLogo` | `Bool?` | `nil` | Show ACT watermark logo |
| `showCandleCountdown` | `Bool?` | `nil` | Show countdown timer on the live candle |
| `candleCountdownTimeframes` | `[String]?` / `"all"` | `nil` | Timeframes where the countdown appears |
| `disableCountdownOnMobile` | `Bool?` | `nil` | Hide the countdown on small screens |
| `enableTrading` | `Bool` | `false` | Show the floating buy/sell order button |
| `minLots` | `Int?` | `nil` | Minimum lot size for order entry (requires `enableTrading`) |
| `maxSubPanes` | `Int?` | `nil` | Max simultaneous oscillator sub-panes |
| `prefetchThreshold` | `Int?` | `nil` | Bars from start of data at which historical fetch triggers (min 20, default 80) |
| `mobileBarDivisor` | `Int?` | `nil` | Divide desktop bar count on touch (`2`, `3`, or `4`) |
| `minInitialBars` | `Int?` | `nil` | If `onDataRequest` returns fewer bars, the fetch window auto-widens and retries. Default: `10` |
| `maxLookbackMs` | `Int64?` | `nil` | Hard ceiling (ms) for auto-widening retries. Default: 365 days |
| `momentumScrollEnabled` | `Bool?` | `nil` | Enable momentum (kinetic) scrolling — chart coasts after a fast flick. Default: `true`. Note: momentum runs in the JS layer, not `UIScrollView` |
| `momentumDecay` | `Double?` | `nil` | Per-frame velocity decay, normalised to 60 fps. Clamped `[0.80, 0.99]`. Default: `0.95` |
| `momentumThreshold` | `Double?` | `nil` | Min release velocity (px/ms) to launch momentum. Default: `0.3` |
| `momentumMaxVelocity` | `Double?` | `nil` | Max launch velocity (px/ms). Default: `6.0` |
| `targetCandleWidth` | `Double?` | `nil` | Target px width per candle for auto-calculating initial bar count |
| `tickClosePriceSource` | `String?` | `nil` | `"bid"` or `"ask"` for live tick close/high/low |
| `tradesThresholdForHorizontalLine` | `Int?` | `nil` | Level count above which render auto-switches to dot mode |
| `tradeDisplayFilter` | `String?` | `nil` | Which TFC levels are visible: `"all"` · `"positions"` · `"orders"` · `"none"` |
| `positionRenderStyle` | `String?` | `nil` | Force position render style: `"line"` or `"dot"` |
| `hideLevelConfirmCancel` | `Bool?` | `nil` | Hide on-canvas ✓/✗ confirm/cancel buttons for TFC level edits |
| `tradeLevelButtonScale` | `Double?` | `nil` (`1.0`) | Multiplier for trade-level Confirm/Cancel/Edit/Close button radii and gaps. Scales visuals **and** hit/drag areas together — raise it on touch devices for easier tapping. Clamped to `[1.0, 3.0]` |
| `levelClusteringEnabled` | `Bool?` | `true` | Enable trade-level fan-out clustering; overlapping levels group into expandable badges |
| `clusterThresholdDistance` | `Int?` | `20` | Pixel proximity threshold for clustering (only when `levelClusteringEnabled` is `true`) |
| `hideQtyButton` | `Bool?` | `nil` | Hide the floating Qty input overlay on draft orders |
| `showQuantityField` | `Bool?` | `nil` (`false`) | Render an editable QTY pill at the left of the draft order info box. Tapping opens a flyout input to edit the quantity before submitting |
| `quantityFieldMinLots` | `Double?` | `nil` (`1.0`) | Minimum lot size, step size, and initial quantity for the QTY flyout (only used when `showQuantityField = true`) |
| `quantityFieldMaxLots` | `Double?` | `nil` (`100.0`) | Maximum lot size for the QTY flyout (only used when `showQuantityField = true`) |
| `tfcEnabled` | `Bool?` | `nil` (`true`) | Enable the TFC toggle button in the top bar. When `false`, TFC is completely disabled — the toggle button is hidden and all trade levels, draft orders, and the floating trade button are suppressed |
| `showSettings` | `Bool?` | `nil` | Show the settings gear button in the top bar; set to `false` to hide it entirely |
| `showFullscreenButton` | `Bool` | `false` | Show the fullscreen toggle button in the top bar. Hidden by default on mobile; set to `true` to surface it |
| `hideSymbolAndTick` | `Bool?` | `nil` | Hide the symbol name, OHLC strip, and tick-activity dot overlay |
| `showBottomBar` | `Bool?` | `nil` | Show the bottom duration-selector bar (hidden by default) |
| `timezone` | `String?` | `nil` (`"UTC"`) | IANA timezone string for time-axis and crosshair labels. `"UTC"` (default), `"local"` (device timezone), or any IANA string (`"America/New_York"`, `"Europe/London"`, etc.) |
| `uiConfigJson` | `String?` | `nil` | Per-component UI configuration overrides (font sizes, icon sizes, spacing) as a raw JSON string. See *Mobile icon sizing* below. |
| `themeOverrides` | `ThemeOverrides?` | `nil` | Typed per-theme color overrides. See *Theme overrides* below. |
| `initialState` | `String?` | `nil` | Raw JSON from a prior `onStateSnapshot` to restore atomically at init (timeframe, series, indicators, drawings). See *Restoring state without a flash* below. |

### Restoring state without a flash

When you need to restore a previously saved chart state (e.g. user re-opens the chart screen), pass the snapshot JSON as `initialState` instead of calling `setState()` inside `onReady`:

```swift
// ✅ Correct — init + setState are queued together and flushed atomically;
//    the engine never renders a frame with the default "1D" timeframe.
let chart = ActtraderChartsView(
    theme: "dark",
    symbol: "EURUSD",
    initialState: savedStateJson
)

// ❌ Avoid — setState fires after the chart has already rendered once with "1D".
let chart = ActtraderChartsView(theme: "dark", symbol: "EURUSD")
chart.onReady = { chart.setState(savedStateJson) }
```

For simple cases where you only need to set a specific timeframe (without full state restore), use the `timeframe` constructor parameter directly — no `initialState` required.

### Theme overrides

Use `themeOverrides` (in the constructor) or `setThemeOverrides(_:)` to selectively override colors for each theme mode. Only the keys you supply are merged on top of the built-in dark/light themes.

```swift
// At init time
let chart = ActtraderChartsView(
    theme: "dark",
    symbol: "EURUSD",
    themeOverrides: ThemeOverrides(
        dark: ChartThemeOverride(
            background: "#0a0a0a",
            candle: CandleColors(up: "#00e676", down: "#ff1744"),
            topBar: TopBarColors(btnColor: "#cccccc")
        )
    )
)

// Or update at runtime
chart.setThemeOverrides(ThemeOverrides(
    dark: ChartThemeOverride(background: "#111111"),
    light: ChartThemeOverride(background: "#fafafa")
))
```

All properties at every level are optional — only supply the ones you want to change. Available nested types: `TooltipColors`, `CandleColors`, `VolumeColors`, `UiColors`, `StreamColors`, `DrawingToolbarColors`, `TopBarColors`, `BottomBarColors`, `IndicatorOverlayColors`, `TradeLevelColors`, `TradePanelColors`.

> Raw JSON strings are still supported via `themeOverridesJson` / `setThemeOverrides(jsonString)` for backward compatibility.

### Mobile icon sizing

The chart automatically bumps top-bar icon buttons (settings, fullscreen, drawing toggle) and the floating trade ⊕ button to larger sizes when the container width drops below `uiConfig.drawingToolbar.mobileBreakpoint` (default `480px`). Defaults:

| Element | Desktop | Mobile |
|---------|---------|--------|
| Top-bar icon button container | 26px | 28px |
| Top-bar icon SVG | 14–15px | 16–17px |
| Trade ⊕ button container | 22px | 24px |
| Trade ⊕ icon SVG | 14px | 16px |

Override via `uiConfigJson`:

```swift
chart.initialize(
    theme: "dark",
    symbol: "AAPL",
    enableTrading: true,
    uiConfigJson: """
    {
      "topBar": {
        "mobileIconBtnSize": "30px",
        "mobileDrawBtnIconSize": "18px"
      },
      "tradeButton": {
        "mobileSize": 26,
        "mobileIconSize": 18
      }
    }
    """
)
```

### Commands

| Method | Description |
|---|---|
| `loadData(_ bars:, fitAll:)` | Replaces the full dataset |
| `pushTick(bid:ask:timestamp:)` | Streams a live tick |
| `setTheme(_:)` | `"dark"` or `"light"` |
| `setSeries(_:)` | `"candlestick"`, `"line"`, `"area"`, `"ohlc"`, `"hollow_candle"` |
| `setTimeframe(_:)` | `"1m"` `"5m"` `"15m"` `"30m"` `"1h"` `"4h"` `"1D"` `"1W"` `"1M"` `"1Y"` |
| `setSymbol(_:)` | Updates the symbol name in the top bar |
| `addIndicator(_:params:)` | `"SMA"`, `"EMA"`, `"RSI"`, `"BB"`, etc. |
| `removeIndicator(_:)` | Removes a study by name |
| `setDrawingTool(_:)` | `"trend_line"`, `"horizontal_line"`, etc. — `nil` to deactivate |
| `clearAllDrawings()` | Removes all drawings |
| `getState()` | Fires `onStateSnapshot` asynchronously |
| `setState(_:)` | Restores from a prior `onStateSnapshot` JSON string |
| `resolveDataRequest(requestId:bars:)` | Resolves a pending `onDataRequest` with fetched bars |
| `setDebug(_:)` | Enable or disable verbose logging in the browser console |
| `destroy()` | Tears down the engine |
| **TFC — Trade Levels** | |
| `setLevels(_:labelKey:priceKey:type:pnlKey:pnlTextKey:)` | Replace all levels of a given type; pass `[]` to clear |
| `removeLevelByLabel(_:)` | Remove a single level by label |
| `updateLevelMainPrice(label:price:)` | Update the entry price of an existing level. Stages the edit in the chart's pending-edit buffer so it survives subsequent `setLevels` refreshes (e.g. per-tick PnL updates) until the server echoes the new price or `cancelLevelEdit` / `cancelCurrentEdit` is called. Call `cancelLevelEdit(label)` when your modify panel closes without submitting, otherwise the staged edit keeps overriding server state on the chart |
| `updateLevelBracket(label:bracketType:price:)` | Update or remove a SL/TP bracket on an existing level; pass `nil` price to remove. Same staging semantics as `updateLevelMainPrice` |
| `addLevelBracket(label:bracketType:)` | Auto-place a SL or TP bracket at a default price offset; fires `onTradeLevelBracketActivated` with the computed price |
| `addBracket(bracketType:label:)` | Unified auto-price bracket placement — pass `label` for an existing order/position, omit it for the active draft order; fires `onTradeLevelBracketActivated` (`label` is `""` for drafts — check `label.isEmpty`) |
| `removeBracket(bracketType:label:)` | Unified bracket removal — pass `label` for an existing order/position, omit it for the active draft order |
| `cancelLevelEdit(_:)` | Cancel an in-progress level edit, reverting to last confirmed price |
| `selectLevel(_:)` | Programmatically highlight a level; pass `nil` to deselect all |
| | **Off-viewport indicators:** When a level's entry/SL/TP is outside the visible price range, a `▲ N` / `▼ N` pill appears near the chart's right edge. Tapping the pill smooth-scrolls the nearest off-screen marker to center. This is automatic — no configuration needed. |
| | **Trade level visuals:** Pending orders and ES/EL entry working orders render as **dashed** lines tinted by side (`pendingBuyLine` green / `pendingSellLine` red). True open positions render as **solid** lines — green/red when `pnl` is set, otherwise `positionLine` (purple/indigo). Each true open position shows a colored entry-price tag on the right-side price axis (same style as the Bid/Ask tag). |
| | **Brackets follow entry on drag:** dragging the entry line of a pending order, draft order, or an entry-editable open position translates any existing SL/TP brackets by the same price delta. The distance is whatever the user currently sees; if they manually adjust SL or TP, the new distance anchors subsequent entry drags. Missing brackets are not auto-created. On confirm, `onTradeLevelEdit` carries all translated fields together in one `changes` array; with `hideLevelConfirmCancel = true` the three changes arrive as a single atomic event. |
| | **Bracket pill auto-offset:** when an SL/TP price sits within about one pill-height of the entry price, the bracket's label pill is pushed vertically away from the entry pill and connected back to its real price line by a dashed leader. The horizontal bracket line stays at the true price; only the pill and its `×` button move, and drag/tap targets follow the displaced pill — so the bracket pill and entry pill never share a touch area. Works for both buy and sell orders, automatic (no configuration). |
| **TFC — Draft Orders** | |
| `showDraftOrder(price:side:orderType:)` | Show a draggable limit or stop draft order line |
| `showMarketDraft(price:side:)` | Show a non-draggable market-order preview line |
| `clearDraftOrder()` | Remove the active draft order |
| `cancelCurrentEdit()` | Cancel whatever is currently being edited or drafted (draft order or level edit); no-op when nothing is active |
| `setDraftOrderLots(_:)` | Update the lot quantity on the active draft order chip |
| `updateDraftOrderPrice(_:)` | Move the draft order price line to a new price |
| `updateDraftOrderBracket(bracketType:price:)` | Update or remove a SL/TP bracket on the draft order; pass `nil` to remove |
| `setDraftBracketPnl(bracketType:pnlText:)` | Display estimated P&L text next to the active bracket host's SL or TP line — a draft order while drafting, or the currently selected existing pending order / position while modifying; pass `nil` to clear |
| **UI / Utility** | |
| `setTfcActive(_:)` | Toggle TFC (Trade from Charts) on or off at runtime. Hides/shows all trade levels, draft orders, and the floating trade button. Fires `onTfcToggle` |
| `setVolume(_:)` | Show or hide the volume sub-pane |
| `setIsins(_:)` | Update the symbol list used by the ISIN picker |
| `setMinLots(_:)` | Update the minimum lot size in the trade popover |
| `resetView()` | Reset price and time axes to auto-fit. The built-in bottom-center reset button invokes this — it is hidden while the chart is at its default view and fades in only after the user pans, zooms, or price-scales |
| `resetData()` | Clear all bars, the live price line, any in-flight fetch, **all user drawings, and all trade/position levels** (including pending draft orders). Call before switching to a new symbol to prevent previous symbol state from bleeding in (see example below). For a same-symbol data refresh that should preserve drawings, call `loadData([])` directly instead |
| `setLoading(_:)` | Show or hide the loading overlay |
| `setTimezone(_:)` | Change display timezone at runtime — IANA string (`"America/New_York"`) or `"local"` |
| `setThemeOverrides(_:)` | Update per-theme color overrides at runtime — accepts typed `ThemeOverrides` or raw JSON string |
| `correctBar(barTime:bar:)` | Replace a specific bar with authoritative OHLCV data (e.g. server correction) |

#### Symbol switch pattern

Always call `resetData()` before loading bars for a new symbol. This prevents
the previous symbol's candles, live price line, drawings, and trade levels
from bleeding into the new chart during the data-fetch window.

```swift
chart.setSymbol("GBPUSD")
chart.resetData()
// … fetch new bars for GBPUSD …
chart.loadData(bars)
```

### Events (callbacks)

| Callback | Fires when |
|---|---|
| `onReady` | Engine initialised |
| `onCrosshair` | Crosshair moved over a bar |
| `onBarClick` | User tapped a bar |
| `onViewportChange` | Pan or zoom changed |
| `onSeriesChange` | Series type changed |
| `onTimeframeChange` | Timeframe changed |
| `onDurationChange` | Duration changed |
| `onStateChange` | Any state mutation |
| `onStateSnapshot` | Response to `getState()` |
| `onDataLoaded` | `loadData` completed |
| `onNewBar` | New bar appended at live edge |
| `onStreamStatus` | Stream connection status changed |
| `onPlaceOrder` | User submitted an order (requires `enableTrading`) |
| `onTradeLevelEdit` | User confirmed a TFC level drag or bracket edit — payload includes `label`, `type`, `data`, `newLots?`, `changes[]` (each with `newLots?` on the `MAIN` change), `isFullscreen`. When qty was edited this session, the `lots` field embedded in `data` (and in the `MAIN` change's `data`) is overridden with the new value for convenience. |
| `onTradeLevelQtyChange` | Live qty edit via the QTY pill flyout — fires before the edit is confirmed, so hosts can refresh Estimated PNL on SL/TP brackets in real time — payload includes `label`, `type` (`"draft"` for draft orders, otherwise parent level's type), `newLots`, `previousLots`, `isFullscreen` |
| `onTradeLevelClose` | User tapped × on a level — payload includes `label`, `type`, `action`, `data`, `isFullscreen` |
| `onTradeLevelDrag` | Live price during drag, fires on every move — payload includes `label`, `newPrice`, `bracketType?`, `data`, `isFullscreen` |
| `onTradeLevelEditOpen` | User tapped the pencil button **or** (when `hideLevelConfirmCancel: true`) tapped a trade level line — payload includes `label`, `type`, `price`, `side?`, `stopLossPrice?`, `takeProfitPrice?`, `data`, `isFullscreen` |
| `onTradeLevelBracketActivated` | SL/TP bracket auto-placed via `addLevelBracket` or `addBracket` — use the `price` to pre-populate your bracket price input — payload includes `label` (`""` for draft orders, OrderID string for existing levels), `bracketType`, `price`, `isFullscreen` |
| `onTradeLevelConfirmed` | Chart ✓ button confirmed an edit — payload includes `label`, `type`, `isFullscreen` |
| `onTradeLevelEditCancelled` | In-progress level edit aborted from the chart (ESC key or inline ✕ cancel button). Not fired for draft orders (see `onDraftCancelled`). Hosts listen to reset an external modify-order panel — payload includes `label`, `type`, `isFullscreen` |
| `onDraftInitiated` | New draft order shown — payload includes `side`, `price`, `orderType`, `isFullscreen` |
| `onDraftCancelled` | Draft order cancelled — payload includes `label`, `isFullscreen` |
| `onTfcToggle` | TFC toggled on or off — payload includes `enabled: Bool` |
| `onUiStateChange` | Any chart flyout/modal/dropdown opened or closed — payload includes `hasOpenUI: Bool`. Most hosts don't need this directly; `ActtraderChartsView.hasOpenUI` mirrors the state automatically and `dismissAllUI()` is the usual integration point. |
| `onDataRequest` | Chart requests data for a time range — payload includes `requestId`, `from`, `to`, `timeframe`; call `resolveDataRequest` to respond |
| `onSymbolClick` | User tapped the symbol name (requires `onSymbolClick: true` in `init`) |
| `onError` | Engine error |
| `onBridgeEvent` | Generic fallback — every event including those with typed callbacks |

> **`isFullscreen`** is `true` when the chart is in fullscreen mode at the time of the TFC action. Use it to gate toast notifications so they only appear while the chart is covering the full screen.

## Handling back / dismiss actions

When a flyout, modal, or dropdown is open inside the chart and the user performs a back action (swipe-back gesture, custom back button, or dismiss button in your UI), call `dismissAllUI()` first. It returns `true` if something was dismissed — consume the event in that case and skip your normal back navigation.

```swift
// Custom back button wired to a UIBarButtonItem or UIButton
@objc func backTapped() {
    if !chart.dismissAllUI() {
        navigationController?.popViewController(animated: true)
    }
}
```

For swipe-back gesture interception, implement `UIGestureRecognizerDelegate` and intercept the interactive pop:

```swift
// In viewDidLoad — replace the interactive pop target with your own handler
override func viewDidLoad() {
    super.viewDidLoad()
    navigationController?.interactivePopGestureRecognizer?.addTarget(
        self, action: #selector(handleSwipeBack(_:))
    )
    navigationController?.interactivePopGestureRecognizer?.delegate = self
}

@objc func handleSwipeBack(_ gesture: UIScreenEdgePanGestureRecognizer) {
    if gesture.state == .began, chart.dismissAllUI() {
        gesture.state = .cancelled   // absorb the gesture; flyout is now closed
    }
}
```

`ActtraderChartsView.hasOpenUI` is updated synchronously from the `uiStateChange` bridge event, so checking it before calling `dismissAllUI()` is safe inside any synchronous gesture or button handler.

## Mobile mode — `hideLevelConfirmCancel`

Pass `hideLevelConfirmCancel: true` in the constructor to hide the on-canvas ✓/✗ buttons and drive the edit flow from your native UI instead.

Behaviour changes when this flag is active:

| Action | Result |
|---|---|
| Tap a trade level line | `onTradeLevelEditOpen` fires immediately (whole line is the edit target) |
| Tap empty canvas while a level is selected | Edit dismissed; pending drag changes reverted |
| Release a SL/TP bracket drag | `onTradeLevelEdit` fires automatically (no ✓ button needed) |

**Market orders from chart crosshair:** When live BID/ASK data is streaming and the crosshair trade button is tapped at a price inside the spread, `onDraftInitiated` fires with `orderType = "market"` — use this to open your market order form.

**Adding a bracket without a price:** Use `addBracket(bracketType:label:)` from your native form to auto-place a SL or TP bracket at a sensible default price:
- **Draft order (new order, no ID yet):** `chart.addBracket(bracketType: "sl")` — omit `label`; the chart operates on the active draft.
- **Existing order/position:** `chart.addBracket(bracketType: "sl", label: orderId)` — pass the OrderID/TradeID.

In both cases the chart fires `onTradeLevelBracketActivated` with the computed price — use it to populate your SL/TP input field. The event's `label` is `""` (empty string) for draft orders — check `label.isEmpty` — and the OrderID string for existing levels.

To remove a bracket without a price: use `removeBracket(bracketType: "sl")` (draft) or `removeBracket(bracketType: "sl", label: orderId)` (existing).

**Estimated P&L on bracket lines:** Call `setDraftBracketPnl(bracketType: "sl", pnlText: "-$12.50")` to display a consumer-calculated P&L string next to the active bracket line on the chart. The text attaches to whichever level is the active bracket host — the draft order while drafting, or the currently selected existing pending order / position while modifying. Call `selectLevel(label: orderId)` (or have the user tap a level) before pushing the P&L text for an existing order. Pass `nil` as `pnlText` to clear.

## CI / CD

- **`sync-chart.yml`**: Triggered by `repository_dispatch` from `acttrader/stockchart` on release. Opens a PR that updates `Sources/ActtraderCharts/Resources/chart.html`.
- **`publish.yml`**: Triggered on `v*` tag push. Runs `swift test` on macOS and creates a GitHub Release (consumed by SPM consumers via git tag).
