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
| `enableTrading` | `Bool` | `false` | Show the floating buy/sell order button |
| `minLots` | `Int?` | `nil` | Minimum lot size for order entry (requires `enableTrading`) |
| `maxSubPanes` | `Int?` | `nil` | Max simultaneous oscillator sub-panes |
| `mobileBarDivisor` | `Int?` | `nil` | Divide desktop bar count on touch (`2`, `3`, or `4`) |
| `targetCandleWidth` | `Double?` | `nil` | Target px width per candle for auto-calculating initial bar count |
| `tickClosePriceSource` | `String?` | `nil` | `"bid"` or `"ask"` for live tick close/high/low |
| `tradesThresholdForHorizontalLine` | `Int?` | `nil` | Level count above which render auto-switches to dot mode |
| `tradeDisplayFilter` | `String?` | `nil` | Which TFC levels are visible: `"all"` · `"positions"` · `"orders"` · `"none"` |
| `positionRenderStyle` | `String?` | `nil` | Force position render style: `"line"` or `"dot"` |

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
| `destroy()` | Tears down the engine |

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
| `onError` | Engine error |
| `onBridgeEvent` | Generic fallback — every event including those with typed callbacks |

> **`isFullscreen`** is `true` when the chart is in fullscreen mode at the time of the TFC action. Use it to gate toast notifications so they only appear while the chart is covering the full screen.

## CI / CD

- **`sync-chart.yml`**: Triggered by `repository_dispatch` from `acttrader/stockchart` on release. Opens a PR that updates `Sources/ActtraderCharts/Resources/chart.html`.
- **`publish.yml`**: Triggered on `v*` tag push. Runs `swift test` on macOS and creates a GitHub Release (consumed by SPM consumers via git tag).
