# charts-ios

iOS Swift framework that embeds the ActTrader financial charting library inside a `WKWebView`.

## Requirements

- iOS 14.0+
- Swift 5.7+
- Xcode 15+

## Installation

### Swift Package Manager

Add to your `Package.swift`:

```swift
.package(url: "https://github.com/acttrader/charts-ios.git", from: "0.1.0")
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
.package(url: "https://github.com/acttrader/charts-ios.git", exact: "1.1.0-beta.1")
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

### SL/TP amounts instead of prices

By default the SL/TP pills read `SL 4159.00`. Pass `bracketLabelMode: "amount"`
and they read `SL -$290.80` — what the position gains or loses if that bracket
is hit, with the currency symbol in front.

The chart has no access to contract specs, so each level supplies what the maths
needs. These go in the level dictionaries you already pass to `setLevels`:

| key | meaning |
|---|---|
| `contractSize` | Units per lot — `100` for XAUUSD, `100000` for most FX pairs |
| `valuePerPoint` | Account-currency value of one price unit, folding in any quote → account conversion. Default `1` |
| `currencySymbol` | Per-level override of the chart-wide `currencySymbol` |

```swift
let chart = ActtraderChartsView(theme: "dark", bracketLabelMode: "amount", currencySymbol: "$")

chart.setLevels([[
    "label": "POS-1", "price": 4173.54, "side": "buy", "lots": 0.20,
    "stopLossPrice": 4159.00, "takeProfitPrice": 4183.00,
    "contractSize": 100, "valuePerPoint": 1,
]], labelKey: "label", priceKey: "price", type: "position")
// pills render: SL -$290.80   TP +$189.20
```

`amount = (bracket − entry) × direction × lots × contractSize × valuePerPoint`

A level missing `lots` or `contractSize` keeps showing its price, so a partial
rollout degrades level by level rather than rendering `NaN`. Switch at runtime
with `setBracketLabelMode("amount")`.

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
| `instrument` | `InstrumentSpec?` | `nil` | Contract specs for `symbol` — see [Instrument specs](#instrument-specs) |
| `account` | `AccountSpec?` | `nil` | Account equity and per-trade risk — see [Position tools](#position-tools) |
| `enableForecasting` | `Bool?` | `nil` (`false`) | The reworked drawing tools, as one switch — see [Feature flags](#feature-flags) |
| `series` | `String?` | `nil` | Initial chart type (e.g. `"candlestick"`, `"line"`, `"area"`, `"ohlc"`, `"hollow_candle"`) |
| `timeframe` | `String?` | `nil` | Initial timeframe (e.g. `"1m"`, `"5m"`, `"1h"`, `"1D"`) |
| `duration` | `String?` | `nil` | Initial duration button (e.g. `"1D"`, `"1M"`, `"1Y"`, `"All"`) |
| `showVolume` | `Bool?` | `nil` | Show volume bars |
| `showUI` | `Bool?` | `nil` | Show top / bottom bars. When `false`, the loading overlay is also suppressed |
| `showDrawingTools` | `Bool?` | `nil` | Show drawing toolbar and pencil button |
| `showBidAskLines` | `Bool?` | `nil` | **Deprecated** — show bid and ask as dashed lines during a live stream. Prefer `showAskLine` / `showBidLine` |
| `showAskLine` | `Bool?` | `nil` | Show the Ask price line independently. `nil`: legacy `showBidAskLines` behavior |
| `showBidLine` | `Bool?` | `nil` | Show the Bid price line independently. `nil`: legacy `showBidAskLines` behavior |
| `showActLogo` | `Bool?` | `nil` | Show ACT watermark logo |
| `showCandleCountdown` | `Bool?` | `nil` | Show countdown timer on the live candle (time axis) |
| `candleCountdownTimeframes` | `[String]?` / `"all"` | `nil` | Timeframes where the countdown appears |
| `showPriceAxisCountdown` | `Bool?` | `nil` (`false`) | Show candle countdown on the right price axis just below the live price tag. Honours `candleCountdownTimeframes`. Toggleable from the in-chart Settings dialog. |
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
| `tickClosePriceSource` | `String?` | `nil` | `"bid"` (default), `"ask"`, or `"ltp"` for live tick close/high/low. `"ltp"` builds candles from the last traded price (exchange/dealing feeds); ticks without a valid LTP fall back to the bid |
| `showLtpPrice` | `Bool?` | `nil` | Show the LTP marker (dashed price line + axis tag). `nil`: shown only in `"ltp"` mode. `true`: always shown when the feed supplies an LTP. `false`: hidden even in `"ltp"` mode |
| `priceSourceSelector` | `[String]?` | `nil` | Show a price-source dropdown in the chart header listing these sources, e.g. `["ltp", "bid"]` (dealing feeds). A user pick switches the live candle source and fires `onPriceSourceChange`. Hidden when `nil`/empty |
| `tradesThresholdForHorizontalLine` | `Int?` | `nil` | Level count above which render auto-switches to dot mode |
| `tradeDisplayFilter` | `String?` | `nil` | Which TFC levels are visible: `"all"` · `"positions"` · `"orders"` · `"none"` |
| `positionRenderStyle` | `String?` | `nil` | Force position render style: `"line"` or `"dot"` |
| `hideLevelConfirmCancel` | `Bool?` | `nil` | Hide on-canvas ✓/✗ confirm/cancel buttons for TFC level edits |
| `deselectActiveOnOutsideClick` | `Bool?` | `nil` (`false`) | When `true`, clicking/tapping outside a selected trade level dismisses it (reverts pending edits). Default `false` preserves the active level across outside clicks so incidental taps (price-axis resize, taps outside the QTY input) don't drop an in-progress edit. Set `true` to restore the legacy outside-click-to-cancel behavior |
| `showTradeLevelsAlways` | `Bool?` | `true` | Always render SL/TP bracket lines + price pills, even when the parent level isn't hovered or selected. Close (×) buttons stay hover-only. Pass `false` to hide them until hover/selection. Toggleable from the in-chart Settings dialog (Trading tab). |
| `showTradeLevelsAlways` | `Bool?` | `true` | Always render SL/TP bracket lines + price pills, even when the parent level isn't hovered or selected. Close (×) buttons stay hover-only. Pass `false` to show them only on hover/selection. Toggleable from the in-chart Settings dialog (Trading tab). |
| `tradeLevelButtonScale` | `Double?` | `nil` (`1.0`) | Multiplier for trade-level Confirm/Cancel/Edit/Close button radii and gaps. Scales visuals **and** hit/drag areas together — raise it on touch devices for easier tapping. Clamped to `[1.0, 3.0]` |
| `bracketLabelMode` | `String?` | `nil` (`"price"`) | `"amount"` makes SL/TP pills show the money at the bracket instead of its price — see below |
| `currencySymbol` | `String?` | `nil` (`"$"`) | Symbol for SL/TP amounts when `bracketLabelMode` is `"amount"` |
| `levelClusteringEnabled` | `Bool?` | `true` | Enable trade-level fan-out clustering; overlapping levels group into expandable badges |
| `clusterThresholdDistance` | `Int?` | `20` | Pixel proximity threshold for clustering (only when `levelClusteringEnabled` is `true`) |
| `hideQtyButton` | `Bool?` | `nil` | Hide the floating Qty input overlay on draft orders |
| `showQuantityField` | `Bool?` | `nil` (`false`) | Render an editable QTY pill at the left of the draft order info box. Tapping opens a flyout input to edit the quantity before submitting |
| `quantityFieldMinLots` | `Double?` | `nil` (`1.0`) | Minimum lot size, step size, and initial quantity for the QTY flyout (only used when `showQuantityField = true`) |
| `quantityFieldMaxLots` | `Double?` | `nil` (`100.0`) | Maximum lot size for the QTY flyout (only used when `showQuantityField = true`) |
| `tfcEnabled` | `Bool?` | `nil` (`true`) | Enable the TFC toggle button in the top bar. When `false`, TFC is completely disabled — the toggle button is hidden and all trade levels, draft orders, and the floating trade button are suppressed |
| `showSettings` | `Bool?` | `nil` | Show the settings gear button in the top bar; set to `false` to hide it entirely |
| `showFullscreenButton` | `Bool` | `false` | Show the fullscreen toggle button in the top bar. Hidden by default on mobile; set to `true` to surface it |
| `hideSymbolAndTick` | `Bool?` | `nil` | Hide the symbol name and tick-activity (streaming) dot in the top-left overlay. Does **not** affect the OHLC(V) strip — use `hideOHLCV` for that |
| `hideOHLCV` | `Bool?` | `nil` | Hide the OHLC(V) data strip (`O: H: L: C: V:`) in the top-left overlay. Independent of `hideSymbolAndTick` — set both to `true` to hide the entire overlay |
| `showBottomBar` | `Bool?` | `nil` | Show the bottom duration-selector bar (hidden by default) |
| `hideHeader` | `Bool?` | `nil` (`false`) | Hide the chart header entirely (whichever `headerLayout` variant would have rendered). Bottom bar, drawing tools, and on-canvas overlays remain on their own flags. Drive the chart from native UI via `setTimeframe(...)`, `setSeries(...)`, `addIndicatorByName(...)`, `removeIndicator(...)` |
| `timezone` | `String?` | `nil` (`"UTC"`) | IANA timezone string for time-axis and crosshair labels. `"UTC"` (default), `"local"` (device timezone), or any IANA string (`"America/New_York"`, `"Europe/London"`, etc.) |
| `uiConfigJson` | `String?` | `nil` | Per-component UI configuration overrides (font sizes, icon sizes, spacing) as a raw JSON string. See *Mobile icon sizing* below. |
| `themeOverrides` | `ThemeOverrides?` | `nil` | Typed per-theme color overrides. See *Theme overrides* below. |
| `initialCompares` | `[String]?` | `nil` | Compare symbols to add automatically on init. Each one fires `onCompareDataRequest` against the initial primary range — respond via `resolveCompareDataRequest` |
| `maxCompares` | `Int?` | `nil` (`8`) | Maximum concurrent compare symbols. Adding beyond fires `onCompareError` |
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

> **Canvas vs. chrome.** `themeOverrides` styles the whole chart — canvas *and* chrome
> (top/bottom/left bars, dialogs, popovers). The colours a user picks in the in-chart
> **Chart Settings** dialog are scoped to the canvas: `background`, `grid`, `axisText`,
> `axisBorder` and `crosshair` repaint the canvas only, so a custom chart background no
> longer repaints the toolbars and a custom axis-border colour no longer lands on the
> settings dialog's own frame. Candle and volume picks still apply everywhere so legends
> and indicator pills track them. Where a user picks a custom background but no explicit
> axis-text colour, the symbol name and OHLC strip switch to pure white or pure black —
> whichever contrasts with that background.


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

### Fonts

The chart renders inside a `WKWebView`. The symbol name, O/H/L/C strip, and toolbar text
inherit the WebView document's `body` font. The bundled `chart.html` sets a system-font
stack (`'Inter', system-ui, -apple-system, …`), so these render in **San Francisco** — no
setup required.

> Fixed in `v1.1.0` (chart bundle from ActCharts): earlier beta bundles set no `body`
> font, so the symbol name and OHLC strip fell back to the WebView's default **serif**
> (Times). Updating to a build with the current `chart.html` resolves it — there are no
> Swift API changes.

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
| `pushTick(bid:ask:timestamp:ltp:ltpv:)` | Streams a live tick. `ltp`/`ltpv` (last traded price/volume) are optional — sent by exchange/dealing feeds and used when `tickClosePriceSource == "ltp"`, e.g. `chart.pushTick(bid: 1.2055, ask: 1.2057, timestamp: ts, ltp: 1.2056, ltpv: 120)` |
| `setShowLtpPrice(_:)` | Show/hide the LTP price marker at runtime; pass `nil` to restore the default (marker follows `tickClosePriceSource == "ltp"`) |
| `setTickClosePriceSource(_:)` | Switch which price drives live candle close/high/low at runtime (`"bid"`, `"ask"` or `"ltp"`); also syncs the header price-source dropdown when `priceSourceSelector` is enabled |
| `setTheme(_:)` | `"dark"` or `"light"` |
| `setSeries(_:)` | `"candlestick"`, `"line"`, `"area"`, `"ohlc"`, `"hollow_candle"` |
| `setTimeframe(_:)` | `"1m"` `"5m"` `"15m"` `"30m"` `"1h"` `"4h"` `"1D"` `"1W"` `"1M"` `"1Y"` |
| `setDuration(_:timeframe:)` | Select a duration (`"1D"` `"5D"` `"1M"` `"3M"` `"6M"` `"1Y"` `"5Y"` `"All"`) and refetch. The timeframe is paired from `durationTimeframeMap` unless given. The x-axis rescales from the new bars — no reinitialisation needed |
| `setBracketLabelMode(_:currencySymbol:)` | `"price"` (default), `"amount"`, or `"priceAndAmount"` — whether SL/TP pills show the bracket price, the money it is worth, or the price with the currency symbol plus the P/L while dragging |
| `setSymbol(_:)` | Updates the symbol name in the top bar |
| `setInstrument(_:)` | Contract specs used by the measurement tools — see [Instrument specs](#instrument-specs). Pair it with `setSymbol(_:)`; `nil` clears them |
| `setAccount(_:)` | Account equity and per-trade risk used to size the position tools — see [Position tools](#position-tools). Push it whenever equity moves |
| `addIndicator(_:params:)` | `"SMA"`, `"EMA"`, `"RSI"`, `"BB"`, etc. Parameterized studies add a **new instance** per call; observe `onIndicatorAdded` for its `instanceId` |
| `removeIndicator(_:)` | Remove a study — pass an `instanceId` (e.g. `"EMA#3"`) for one instance, or a short name (e.g. `"EMA"`) for all instances of that study |
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
| `updateLevelQty(_:qty:)` | Update the quantity on an existing level's pill when your modify panel changes the size — stops the chart showing the broker's old lots while the modify is in flight. Staged like a chart-side qty edit: survives `setLevels` refreshes and is reverted by `cancelCurrentEdit()` |
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
| `setLayoutSync(_:)` | Update the layout popover's cross-pane sync toggles (`LayoutSync`, partial). Only with `enableMultipleLayouts: true`. See [Multi-pane layouts](#multi-pane-layouts--snapshot) |
| `setThemeOverrides(_:)` | Update per-theme color overrides at runtime — accepts typed `ThemeOverrides` or raw JSON string |
| `correctBar(barTime:bar:)` | Replace a specific bar with authoritative OHLCV data (e.g. server correction) |
| **Compare** | |
| `addCompare(_:)` | Add a compare symbol overlay. Fires `onCompareDataRequest` — reply via `resolveCompareDataRequest` |
| `removeCompare(_:)` | Remove a compare symbol. No-op if not active |
| `clearCompares()` | Remove every active compare symbol |
| `resolveCompareDataRequest(requestId:bars:)` | Resolve a pending `onCompareDataRequest` with fetched bars |

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
| `onPriceSourceChange` | User picked a price source (BID / ASK / LTP) from the header dropdown (`priceSourceSelector`) |
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
| `onCompareDataRequest` | Chart needs bars for a compare symbol — payload includes `requestId`, `symbol`, `timeframe`, `interval`, `start`, `end`; reply via `resolveCompareDataRequest` |
| `onCompareAdded` | Compare symbol added — payload includes `symbol`, `color` |
| `onCompareRemoved` | Compare symbol removed — payload includes `symbol` |
| `onCompareError` | Compare fetch / add failed — payload includes `symbol`, `message` |
| `onIndicatorAdded` | Study instance added — payload includes `instanceId`, `shortName`, `params`; keep `instanceId` to remove that instance later |
| `onIndicatorRemoved` | Study instance removed — payload includes `instanceId`, `shortName` |
| `onError` | Engine error |
| `onBridgeEvent` | Generic fallback — every event including those with typed callbacks |

> **`isFullscreen`** is `true` when the chart is in fullscreen mode at the time of the TFC action. Use it to gate toast notifications so they only appear while the chart is covering the full screen.

## Multi-pane layouts & snapshot

The WebView bundle includes the chart-owned multi-layout popover (26 grid
presets + 5 cross-pane sync toggles) and a snapshot popover (Download / Copy
PNG). Both are opt-in and dispatch bridge events back to the host.

### Enabling the layout & snapshot UI

```swift
let chart = ActtraderChartsView(
    theme:                 "dark",
    symbol:                "EURUSD",
    timeframe:             "1h",
    headerLayout:          "advanced",   // "simple" (default) | "advanced" | "compact"
    enableMultipleLayouts: true,         // Layout button + preset picker
    enableSnapshot:        true,         // Snapshot button + Download/Copy
    layoutSync:            LayoutSync(symbol: false, interval: true) // optional — seed the sync toggles
)

chart.onLayoutChange = { event in
    guard case let .layoutChange(presetId, syncJson) = event else { return }
    // presetId is one of "1", "2-h", "2-v", "4-2x2", "6-2x3", "8-4x2", … —
    // see the JS library's LAYOUT_PRESETS for the full catalogue.
    // syncJson is the raw LayoutSyncState JSON: {symbol, interval, crosshair, time, dateRange}.
    print("preset=\(presetId) sync=\(syncJson)")
    // The host owns the actual N-pane grid — mount/teardown sibling
    // ActtraderChartsViews to match preset.count and apply the sync flags.
}

chart.onSnapshot = { event in
    guard case let .snapshot(dataUrl, action) = event else { return }
    // action is "download" or "copy"; dataUrl is a base64 PNG.
    // Intercept here to save to Photos / UIPasteboard via platform APIs.
}
```

### `headerLayout`

| Value         | Use case
|---------------|----------------------------------------------------------------
| `"simple"`    | Classic TopBar (default) — symbol, type, timeframe, studies, drawings
| `"advanced"`  | Compact pill-style toolbar — recommended above multi-pane grids
| `"compact"`   | Slim per-pane toolbar — recommended for individual cells of a grid

> **Sync flags are intent, not action.** The native host is responsible for
> mirroring symbol/timeframe/viewport across sibling chart views — the
> JS-side `ChartGroup` only operates inside one WebView. On iOS each pane is
> its own `ActtraderChartsView`, so coordinate from Swift (e.g. call
> `setTimeframe(_:)` on every pane when the sync JSON's `interval` is `true`).

### Seeding & restoring the sync toggles

The layout popover's five sync toggles default to the library's `DEFAULT_LAYOUT_SYNC`.
Pass a partial `LayoutSync` to the initializer to open the popover in a saved state,
and call `setLayoutSync(_:)` to update an already-mounted chart (e.g. mirroring a
native settings screen). Omitted (`nil`) fields keep their current value.

```swift
// Seed at init — restore the user's persisted preference
let chart = ActtraderChartsView(
    enableMultipleLayouts: true,
    layoutSync: LayoutSync(symbol: false, interval: false, crosshair: false, time: false, dateRange: false)
)

// Update later — partial; other toggles unchanged. No layoutChange echo.
chart.setLayoutSync(LayoutSync(crosshair: true))
```

## Compare symbols

Overlay one or more comparison instruments on the main chart, normalized to
percent change from the leftmost visible bar. Historical-only — no live
streaming. The chart owns the picker UI (filtered by the symbols supplied via
the JS bundle's `isins`) and refetches every active compare automatically
when the primary timeframe / symbol changes or the user pans back into
history.

```swift
let chart = ActtraderChartsView(
    theme:           "dark",
    symbol:          "AAPL",
    headerLayout:    "advanced",     // Compare button lives in this toolbar
    initialCompares: ["SPY"],
    maxCompares:     8,
)

// Serve the chart's compare data requests.
chart.onCompareDataRequest = { [weak self] event in
    guard case let .compareDataRequest(requestId, symbol, _, interval, start, end) = event,
          let self else { return }
    Task {
        let bars = try await self.api.fetchBars(symbol: symbol,
                                                interval: interval,
                                                start: start,
                                                end: end)
        self.chart.resolveCompareDataRequest(requestId: requestId, bars: bars)
    }
}

chart.onCompareAdded   = { event in
    if case let .compareAdded(symbol, color) = event { print("+ \(symbol) \(color)") }
}
chart.onCompareRemoved = { event in
    if case let .compareRemoved(symbol) = event { print("- \(symbol)") }
}
chart.onCompareError   = { event in
    if case let .compareError(symbol, message) = event { print("⚠️ \(symbol): \(message)") }
}

// Programmatic control.
chart.addCompare("MSFT")
chart.removeCompare("MSFT")
chart.clearCompares()
```

When at least one compare is active the Y-axis switches to percent
(`+12.34%` / `-5.67%`); removing every compare returns it to absolute prices.

## Multiple instances of the same study

Parameterized studies (EMA, SMA, RSI, BB, …) support multiple simultaneous
instances, each with an auto-cycled color:

```swift
chart.addIndicator("EMA", params: ["period": 20])
chart.addIndicator("EMA", params: ["period": 50])   // a 2nd EMA, distinct color
chart.addIndicator("EMA", params: ["period": 200])  // a 3rd

// Track instance ids so you can remove a specific one.
var emaIds: [String] = []
chart.onIndicatorAdded = { event in
    if case let .indicatorAdded(instanceId, shortName, _) = event, shortName == "EMA" {
        emaIds.append(instanceId)
    }
}
chart.onIndicatorRemoved = { event in
    if case let .indicatorRemoved(instanceId, _) = event {
        emaIds.removeAll { $0 == instanceId }
    }
}

chart.removeIndicator(emaIds.first!)  // remove just that instance ("EMA#1")
chart.removeIndicator("EMA")          // or remove ALL EMA instances
```

A few studies stay single-instance and toggle off when re-added: `VOL`, `OBV`,
`A/D`, `AO`, `VWAP`, `Ichimoku`, `PSAR`, `Pivot`, and Heikin-Ashi.

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

---

## Instrument specs

The chart reads prices, never contract specs — so a tool that reports a distance
in **pips**, or converts one to money, has to be told how.

The **ruler** uses this. With specs it reads:

```
0.00455 (0.80%) 45.5
43 bars, 9d 4h
Vol 102.27K
```

Without them a pip figure is still shown, but inferred from how many decimals
the feed quotes — the usual FX convention, which is wrong for metals, indices
and crypto.

```swift
let chart = ActtraderChartsView(
    theme: "dark",
    symbol: "EURUSD",
    instrument: InstrumentSpec(
        pipSize: 0.0001,       // 0.01 for JPY crosses
        contractSize: 100_000  // units per lot
    )
)

// Specs belong to the instrument — swap them with the symbol.
chart.setSymbol("USDJPY")
chart.setInstrument(InstrumentSpec(pipSize: 0.01, contractSize: 100_000))
```

| Field | Type | Default | Description |
|---|---|---|---|
| `pipSize` | `Double?` | inferred | Price distance counted as one pip |
| `contractSize` | `Double?` | `1` | Units per lot (`100` for XAUUSD, `100000` for most FX pairs) |
| `valuePerPoint` | `Double?` | `1` | Account-currency value of one price unit per contract unit |
| `currencySymbol` | `String?` | `"$"` | Prefixed to money figures |

Every field is optional and the whole struct can be omitted — tools fall back to
price-only readouts, so an existing integration keeps working untouched.

When `pipSize` is absent it is inferred from how many decimals the feed quotes:
five-decimal (`1.08531`) and three-decimal (`151.234`) feeds carry fractional
pips, so the pip is the second-to-last digit; two- and four-decimal feeds quote
whole pips. **That convention is wrong for metals, indices and crypto** — pass
`pipSize` explicitly if pips matter.

> A stale pip size reports a wrong number rather than failing visibly, so always
> call `setInstrument(_:)` alongside `setSymbol(_:)`.

## Freehand drawing

`brush` and `highlighter` draw freehand: press, drag, release. The pointer path
is sampled continuously and the finished stroke is thinned to the points that
carry its shape. (`polyline` and `path` remain tap-per-point.)

## Position tools

`"longPosition"` and `"shortPosition"` sketch a trade that hasn't been placed:
a green profit zone from entry to target, a red risk zone from entry to stop,
and live readouts.

```
Target: 0.00313 (0.549%) 31.3, Amount: 5622.13
Open PnL: 0.00146, Qty: 11323
Risk/reward ratio: 1.84
Stop: 0.00170 (0.298%) 17.0, Amount: 2887.5
```

Two taps place it — entry, then target — and the stop lands at a 2:1
reward:risk to be dragged. All three prices have handles.

Quantity is sized so hitting the stop costs exactly `riskPercent` of the
account:

```swift
chart.setAccount(AccountSpec(size: 10_000, riskPercent: 1))
```

| Field | Type | Default | Description |
|---|---|---|---|
| `size` | `Double?` | — | Account equity in the account currency |
| `riskPercent` | `Double?` | `1` | Percent of the account risked per trade |

Omit it and the tools still draw — price, percent, pips and risk/reward all
render; only quantity and money are left out. Money amounts and pips also need
[Instrument specs](#instrument-specs).

> **These are drawings, not orders.** Trade-From-Chart is what puts real broker
> orders on the chart. Nothing on a position tool reaches the broker.
>
> A sketch drawn against a stale balance reports the wrong quantity rather than
> failing visibly, so call `setAccount(_:)` whenever equity moves.

## Feature flags

The reworked drawing tools ship behind one init flag so each broker opts in.
**It defaults to `false`** — an app that doesn't set it keeps exactly the toolbar
it has today.

```swift
let chart = ActtraderChartsView(
    theme: "dark",
    symbol: "EURUSD",
    enableForecasting: true
)
```

`enableForecasting` turns on three things together:

| | What it changes |
|---|---|
| **Position tools** | Adds **Long Position** / **Short Position** in a **Forecasting** group. Off, the group is not rendered at all |
| **Freehand brush** | **Brush** and **Highlighter** draw freehand (press, drag, release). Off, they stay tap-per-point, ended by a double-tap |
| **Detailed ruler** | **Ruler** reports percent, pips, duration and volume. Off, it reports bar count and raw price delta |

One flag rather than three because they ship and roll back together. With it off
the Forecasting group is absent from both the drawing toolbar and the mobile
tools sheet.

> Pass these ids to `setDrawingTool` exactly as written — `"longPosition"` /
> `"shortPosition"`, camelCase. An unrecognised id silently draws a Trend Line.

The position tools show quantity and money only with `account`; pips on both the
position tools and the ruler come from `instrument`.
