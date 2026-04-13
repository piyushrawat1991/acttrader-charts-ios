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
| `showUI` | `Bool?` | `nil` | Show top / bottom bars |
| `showDrawingTools` | `Bool?` | `nil` | Show drawing toolbar and pencil button |
| `showBidAskLines` | `Bool?` | `nil` | Show bid and ask as dashed lines during a live stream |
| `showActLogo` | `Bool?` | `nil` | Show ACT watermark logo |
| `showCandleCountdown` | `Bool?` | `nil` | Show countdown timer on the live candle |
| `candleCountdownTimeframes` | `[String]?` / `"all"` | `nil` | Timeframes where the countdown appears |
| `disableCountdownOnMobile` | `Bool?` | `nil` | Hide the countdown on small screens |
| `enableTrading` | `Bool` | `false` | Show the floating buy/sell order button |
| `minLots` | `Int?` | `nil` | Minimum lot size for order entry (requires `enableTrading`) |
| `maxSubPanes` | `Int?` | `nil` | Max simultaneous oscillator sub-panes |
| `mobileBarDivisor` | `Int?` | `nil` | Divide desktop bar count on touch (`2`, `3`, or `4`) |
| `targetCandleWidth` | `Double?` | `nil` | Target px width per candle for auto-calculating initial bar count |
| `tickClosePriceSource` | `String?` | `nil` | `"bid"` or `"ask"` for live tick close/high/low |
| `tradesThresholdForHorizontalLine` | `Int?` | `nil` | Level count above which render auto-switches to dot mode |
| `tradeDisplayFilter` | `String?` | `nil` | Which TFC levels are visible: `"all"` · `"positions"` · `"orders"` · `"none"` |
| `positionRenderStyle` | `String?` | `nil` | Force position render style: `"line"` or `"dot"` |
| `hideLevelConfirmCancel` | `Bool?` | `nil` | Hide on-canvas ✓/✗ confirm/cancel buttons for TFC level edits |
| `hideQtyButton` | `Bool?` | `nil` | Hide the floating Qty input overlay on draft orders |

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
| `updateLevelMainPrice(label:price:)` | Update the entry price of an existing level |
| `updateLevelBracket(label:bracketType:price:)` | Update or remove a SL/TP bracket; pass `nil` price to remove |
| `cancelLevelEdit(_:)` | Cancel an in-progress level edit, reverting to last confirmed price |
| `selectLevel(_:)` | Programmatically highlight a level; pass `nil` to deselect all |
| **TFC — Draft Orders** | |
| `showDraftOrder(price:side:orderType:)` | Show a draggable limit or stop draft order line |
| `showMarketDraft(price:side:)` | Show a non-draggable market-order preview line |
| `clearDraftOrder()` | Remove the active draft order |
| `setDraftOrderLots(_:)` | Update the lot quantity on the active draft order chip |
| `updateDraftOrderPrice(_:)` | Move the draft order price line to a new price |
| `updateDraftOrderBracket(bracketType:price:)` | Update or remove a SL/TP bracket on the draft order; pass `nil` to remove |
| **UI / Utility** | |
| `setVolume(_:)` | Show or hide the volume sub-pane |
| `setIsins(_:)` | Update the symbol list used by the ISIN picker |
| `setMinLots(_:)` | Update the minimum lot size in the trade popover |
| `resetView()` | Reset price and time axes to auto-fit |
| `setLoading(_:)` | Show or hide the loading overlay |
| `correctBar(barTime:bar:)` | Replace a specific bar with authoritative OHLCV data (e.g. server correction) |

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
| `onTradeLevelEdit` | User confirmed a TFC level drag or bracket edit — payload includes `label`, `type`, `data`, `changes[]`, `isFullscreen` |
| `onTradeLevelClose` | User tapped × on a level — payload includes `label`, `type`, `action`, `data`, `isFullscreen` |
| `onTradeLevelDrag` | Live price during drag, fires on every move — payload includes `label`, `newPrice`, `bracketType?`, `data`, `isFullscreen` |
| `onTradeLevelEditOpen` | User tapped the pencil edit button — payload includes `label`, `type`, `price`, `side?`, `stopLossPrice?`, `takeProfitPrice?`, `data`, `isFullscreen` |
| `onTradeLevelConfirmed` | Chart ✓ button confirmed an edit — payload includes `label`, `type`, `isFullscreen` |
| `onDraftInitiated` | New draft order shown — payload includes `side`, `price`, `orderType`, `isFullscreen` |
| `onDraftCancelled` | Draft order cancelled — payload includes `label`, `isFullscreen` |
| `onDataRequest` | Chart requests data for a time range — payload includes `requestId`, `from`, `to`, `timeframe`; call `resolveDataRequest` to respond |
| `onSymbolClick` | User tapped the symbol name (requires `onSymbolClick: true` in `init`) |
| `onError` | Engine error |
| `onBridgeEvent` | Generic fallback — every event including those with typed callbacks |

> **`isFullscreen`** is `true` when the chart is in fullscreen mode at the time of the TFC action. Use it to gate toast notifications so they only appear while the chart is covering the full screen.

## CI / CD

- **`sync-chart.yml`**: Triggered by `repository_dispatch` from `acttrader/stockchart` on release. Opens a PR that updates `Sources/ActtraderCharts/Resources/chart.html`.
- **`publish.yml`**: Triggered on `v*` tag push. Runs `swift test` on macOS and creates a GitHub Release (consumed by SPM consumers via git tag).
