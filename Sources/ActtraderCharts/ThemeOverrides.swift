import Foundation

// MARK: - ThemeOverrides

/// Per-theme deep-partial color overrides applied on top of the built-in
/// dark / light themes. Only the keys you supply are replaced; everything
/// else falls back to `DARK_THEME` / `LIGHT_THEME`.
///
/// ```swift
/// let overrides = ThemeOverrides(
///     dark: ChartThemeOverride(
///         background: "#0a0a0a",
///         candle: CandleColors(up: "#00e676", down: "#ff1744")
///     )
/// )
/// chart.setThemeOverrides(overrides)
/// ```
public struct ThemeOverrides {
    public var dark: ChartThemeOverride?
    public var light: ChartThemeOverride?

    public init(
        dark: ChartThemeOverride? = nil,
        light: ChartThemeOverride? = nil
    ) {
        self.dark = dark
        self.light = light
    }

    /// Serialises to the JSON string expected by the bridge.
    func toJsonString() -> String {
        var root: [String: Any] = [:]
        if let dark { root["dark"] = dark.toDictionary() }
        if let light { root["light"] = light.toDictionary() }
        guard let data = try? JSONSerialization.data(withJSONObject: root),
              let str = String(data: data, encoding: .utf8)
        else { return "{}" }
        return str
    }
}

// MARK: - ChartThemeOverride

/// Deep-partial mirror of the JS `ChartTheme` interface.
/// Every property is optional — supply only the colors you want to override.
public struct ChartThemeOverride {
    public var background: String?
    public var grid: String?
    public var axisText: String?
    public var axisBorder: String?
    public var crosshair: String?
    public var tooltip: TooltipColors?
    public var candle: CandleColors?
    public var volume: VolumeColors?
    public var ui: UiColors?
    public var drawingToolbar: DrawingToolbarColors?
    public var topBar: TopBarColors?
    public var bottomBar: BottomBarColors?
    public var indicatorOverlay: IndicatorOverlayColors?
    public var tradeLevels: TradeLevelColors?
    public var tradePanel: TradePanelColors?

    public init(
        background: String? = nil,
        grid: String? = nil,
        axisText: String? = nil,
        axisBorder: String? = nil,
        crosshair: String? = nil,
        tooltip: TooltipColors? = nil,
        candle: CandleColors? = nil,
        volume: VolumeColors? = nil,
        ui: UiColors? = nil,
        drawingToolbar: DrawingToolbarColors? = nil,
        topBar: TopBarColors? = nil,
        bottomBar: BottomBarColors? = nil,
        indicatorOverlay: IndicatorOverlayColors? = nil,
        tradeLevels: TradeLevelColors? = nil,
        tradePanel: TradePanelColors? = nil
    ) {
        self.background = background
        self.grid = grid
        self.axisText = axisText
        self.axisBorder = axisBorder
        self.crosshair = crosshair
        self.tooltip = tooltip
        self.candle = candle
        self.volume = volume
        self.ui = ui
        self.drawingToolbar = drawingToolbar
        self.topBar = topBar
        self.bottomBar = bottomBar
        self.indicatorOverlay = indicatorOverlay
        self.tradeLevels = tradeLevels
        self.tradePanel = tradePanel
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let background { d["background"] = background }
        if let grid { d["grid"] = grid }
        if let axisText { d["axisText"] = axisText }
        if let axisBorder { d["axisBorder"] = axisBorder }
        if let crosshair { d["crosshair"] = crosshair }
        if let tooltip { d["tooltip"] = tooltip.toDictionary() }
        if let candle { d["candle"] = candle.toDictionary() }
        if let volume { d["volume"] = volume.toDictionary() }
        if let ui { d["ui"] = ui.toDictionary() }
        if let drawingToolbar { d["drawingToolbar"] = drawingToolbar.toDictionary() }
        if let topBar { d["topBar"] = topBar.toDictionary() }
        if let bottomBar { d["bottomBar"] = bottomBar.toDictionary() }
        if let indicatorOverlay { d["indicatorOverlay"] = indicatorOverlay.toDictionary() }
        if let tradeLevels { d["tradeLevels"] = tradeLevels.toDictionary() }
        if let tradePanel { d["tradePanel"] = tradePanel.toDictionary() }
        return d
    }
}

// MARK: - Nested color structs

public struct TooltipColors {
    public var background: String?
    public var text: String?
    public var border: String?

    public init(background: String? = nil, text: String? = nil, border: String? = nil) {
        self.background = background
        self.text = text
        self.border = border
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let background { d["background"] = background }
        if let text { d["text"] = text }
        if let border { d["border"] = border }
        return d
    }
}

public struct CandleColors {
    public var up: String?
    public var down: String?
    public var wickUp: String?
    public var wickDown: String?
    public var borderUp: String?
    public var borderDown: String?

    public init(
        up: String? = nil, down: String? = nil,
        wickUp: String? = nil, wickDown: String? = nil,
        borderUp: String? = nil, borderDown: String? = nil
    ) {
        self.up = up
        self.down = down
        self.wickUp = wickUp
        self.wickDown = wickDown
        self.borderUp = borderUp
        self.borderDown = borderDown
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let up { d["up"] = up }
        if let down { d["down"] = down }
        if let wickUp { d["wickUp"] = wickUp }
        if let wickDown { d["wickDown"] = wickDown }
        if let borderUp { d["borderUp"] = borderUp }
        if let borderDown { d["borderDown"] = borderDown }
        return d
    }
}

public struct VolumeColors {
    public var up: String?
    public var down: String?

    public init(up: String? = nil, down: String? = nil) {
        self.up = up
        self.down = down
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let up { d["up"] = up }
        if let down { d["down"] = down }
        return d
    }
}

public struct StreamColors {
    public var connected: String?
    public var reconnecting: String?
    public var disconnected: String?

    public init(connected: String? = nil, reconnecting: String? = nil, disconnected: String? = nil) {
        self.connected = connected
        self.reconnecting = reconnecting
        self.disconnected = disconnected
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let connected { d["connected"] = connected }
        if let reconnecting { d["reconnecting"] = reconnecting }
        if let disconnected { d["disconnected"] = disconnected }
        return d
    }
}

public struct UiColors {
    public var accent: String?
    public var accentText: String?
    public var accentBg: String?
    public var accentBgStrong: String?
    public var disabledText: String?
    public var soonBadgeText: String?
    public var stream: StreamColors?

    public init(
        accent: String? = nil, accentText: String? = nil,
        accentBg: String? = nil, accentBgStrong: String? = nil,
        disabledText: String? = nil, soonBadgeText: String? = nil,
        stream: StreamColors? = nil
    ) {
        self.accent = accent
        self.accentText = accentText
        self.accentBg = accentBg
        self.accentBgStrong = accentBgStrong
        self.disabledText = disabledText
        self.soonBadgeText = soonBadgeText
        self.stream = stream
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let accent { d["accent"] = accent }
        if let accentText { d["accentText"] = accentText }
        if let accentBg { d["accentBg"] = accentBg }
        if let accentBgStrong { d["accentBgStrong"] = accentBgStrong }
        if let disabledText { d["disabledText"] = disabledText }
        if let soonBadgeText { d["soonBadgeText"] = soonBadgeText }
        if let stream { d["stream"] = stream.toDictionary() }
        return d
    }
}

public struct DrawingToolbarColors {
    public var iconColor: String?
    public var activeIconColor: String?
    public var flyoutLabelColor: String?
    public var flyoutHeadingColor: String?

    public init(
        iconColor: String? = nil, activeIconColor: String? = nil,
        flyoutLabelColor: String? = nil, flyoutHeadingColor: String? = nil
    ) {
        self.iconColor = iconColor
        self.activeIconColor = activeIconColor
        self.flyoutLabelColor = flyoutLabelColor
        self.flyoutHeadingColor = flyoutHeadingColor
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let iconColor { d["iconColor"] = iconColor }
        if let activeIconColor { d["activeIconColor"] = activeIconColor }
        if let flyoutLabelColor { d["flyoutLabelColor"] = flyoutLabelColor }
        if let flyoutHeadingColor { d["flyoutHeadingColor"] = flyoutHeadingColor }
        return d
    }
}

public struct TopBarColors {
    public var btnColor: String?
    public var activeBtnColor: String?
    public var flyoutRowColor: String?
    public var flyoutCategoryColor: String?

    public init(
        btnColor: String? = nil, activeBtnColor: String? = nil,
        flyoutRowColor: String? = nil, flyoutCategoryColor: String? = nil
    ) {
        self.btnColor = btnColor
        self.activeBtnColor = activeBtnColor
        self.flyoutRowColor = flyoutRowColor
        self.flyoutCategoryColor = flyoutCategoryColor
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let btnColor { d["btnColor"] = btnColor }
        if let activeBtnColor { d["activeBtnColor"] = activeBtnColor }
        if let flyoutRowColor { d["flyoutRowColor"] = flyoutRowColor }
        if let flyoutCategoryColor { d["flyoutCategoryColor"] = flyoutCategoryColor }
        return d
    }
}

public struct BottomBarColors {
    public var btnColor: String?
    public var activeBtnBg: String?
    public var activeBtnText: String?
    public var activeBtnBorder: String?

    public init(
        btnColor: String? = nil, activeBtnBg: String? = nil,
        activeBtnText: String? = nil, activeBtnBorder: String? = nil
    ) {
        self.btnColor = btnColor
        self.activeBtnBg = activeBtnBg
        self.activeBtnText = activeBtnText
        self.activeBtnBorder = activeBtnBorder
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let btnColor { d["btnColor"] = btnColor }
        if let activeBtnBg { d["activeBtnBg"] = activeBtnBg }
        if let activeBtnText { d["activeBtnText"] = activeBtnText }
        if let activeBtnBorder { d["activeBtnBorder"] = activeBtnBorder }
        return d
    }
}

public struct IndicatorOverlayColors {
    public var pillBg: String?
    public var iconColor: String?
    public var dropdownHoverBg: String?

    public init(pillBg: String? = nil, iconColor: String? = nil, dropdownHoverBg: String? = nil) {
        self.pillBg = pillBg
        self.iconColor = iconColor
        self.dropdownHoverBg = dropdownHoverBg
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let pillBg { d["pillBg"] = pillBg }
        if let iconColor { d["iconColor"] = iconColor }
        if let dropdownHoverBg { d["dropdownHoverBg"] = dropdownHoverBg }
        return d
    }
}

public struct TradeLevelColors {
    public var tradeLine: String?
    public var positionLine: String?
    public var pendingBuyLine: String?
    public var pendingSellLine: String?
    public var labelText: String?
    public var closeBtn: String?
    public var closeBtnText: String?
    public var boxBg: String?
    public var boxBgHover: String?
    public var dragHandle: String?
    public var dragHandleHover: String?

    public init(
        tradeLine: String? = nil, positionLine: String? = nil,
        pendingBuyLine: String? = nil, pendingSellLine: String? = nil,
        labelText: String? = nil, closeBtn: String? = nil, closeBtnText: String? = nil,
        boxBg: String? = nil, boxBgHover: String? = nil,
        dragHandle: String? = nil, dragHandleHover: String? = nil
    ) {
        self.tradeLine = tradeLine
        self.positionLine = positionLine
        self.pendingBuyLine = pendingBuyLine
        self.pendingSellLine = pendingSellLine
        self.labelText = labelText
        self.closeBtn = closeBtn
        self.closeBtnText = closeBtnText
        self.boxBg = boxBg
        self.boxBgHover = boxBgHover
        self.dragHandle = dragHandle
        self.dragHandleHover = dragHandleHover
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let tradeLine { d["tradeLine"] = tradeLine }
        if let positionLine { d["positionLine"] = positionLine }
        if let pendingBuyLine { d["pendingBuyLine"] = pendingBuyLine }
        if let pendingSellLine { d["pendingSellLine"] = pendingSellLine }
        if let labelText { d["labelText"] = labelText }
        if let closeBtn { d["closeBtn"] = closeBtn }
        if let closeBtnText { d["closeBtnText"] = closeBtnText }
        if let boxBg { d["boxBg"] = boxBg }
        if let boxBgHover { d["boxBgHover"] = boxBgHover }
        if let dragHandle { d["dragHandle"] = dragHandle }
        if let dragHandleHover { d["dragHandleHover"] = dragHandleHover }
        return d
    }
}

public struct TradePanelColors {
    public var background: String?
    public var border: String?
    public var headerBg: String?
    public var tabActive: String?
    public var tabInactive: String?
    public var rowHoverBg: String?
    public var rowText: String?
    public var rowSubText: String?

    public init(
        background: String? = nil, border: String? = nil, headerBg: String? = nil,
        tabActive: String? = nil, tabInactive: String? = nil,
        rowHoverBg: String? = nil, rowText: String? = nil, rowSubText: String? = nil
    ) {
        self.background = background
        self.border = border
        self.headerBg = headerBg
        self.tabActive = tabActive
        self.tabInactive = tabInactive
        self.rowHoverBg = rowHoverBg
        self.rowText = rowText
        self.rowSubText = rowSubText
    }

    func toDictionary() -> [String: Any] {
        var d: [String: Any] = [:]
        if let background { d["background"] = background }
        if let border { d["border"] = border }
        if let headerBg { d["headerBg"] = headerBg }
        if let tabActive { d["tabActive"] = tabActive }
        if let tabInactive { d["tabInactive"] = tabInactive }
        if let rowHoverBg { d["rowHoverBg"] = rowHoverBg }
        if let rowText { d["rowText"] = rowText }
        if let rowSubText { d["rowSubText"] = rowSubText }
        return d
    }
}
