import XCTest
@testable import ActtraderCharts

final class BridgeCommandTests: XCTestCase {

    // ── BridgeCommand JSON encoding ───────────────────────────────────────────

    func testInitCommandJSON() throws {
        let cmd = BridgeCommand.initialize(
            theme: "dark",
            symbol: "EURUSD",
            series: "candlestick",
            enableTrading: false,
            showCandleCountdown: nil,
            disableCountdownOnMobile: nil
        )
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "init")
        let payload = try XCTUnwrap(obj["payload"] as? [String: Any])
        XCTAssertEqual(payload["theme"] as? String, "dark")
        XCTAssertEqual(payload["symbol"] as? String, "EURUSD")
        XCTAssertEqual(payload["series"] as? String, "candlestick")
    }

    func testLoadDataCommandJSON() throws {
        let bars = [
            OHLCVBar(time: 1_700_000_000_000, open: 1.1, high: 1.2, low: 1.0, close: 1.15, volume: 1000),
            OHLCVBar(time: 1_700_000_060_000, open: 1.15, high: 1.25, low: 1.1, close: 1.2, volume: 2000),
        ]
        let cmd = BridgeCommand.loadData(bars: bars, fitAll: true)
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "loadData")
        let payload = try XCTUnwrap(obj["payload"] as? [String: Any])
        XCTAssertEqual(payload["fitAll"] as? Bool, true)
        let barsArr = try XCTUnwrap(payload["bars"] as? [[String: Any]])
        XCTAssertEqual(barsArr.count, 2)
        XCTAssertEqual(barsArr[0]["open"] as? Double, 1.1)
        XCTAssertEqual(barsArr[0]["close"] as? Double, 1.15)
    }

    func testPushTickCommandJSON() throws {
        let cmd = BridgeCommand.pushTick(bid: 1.0500, ask: 1.0502, timestamp: 1_700_000_000_000)
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "pushTick")
        let payload = try XCTUnwrap(obj["payload"] as? [String: Any])
        XCTAssertEqual(payload["B"] as? Double, 1.0500)
        XCTAssertEqual(payload["A"] as? Double, 1.0502)
        XCTAssertEqual(payload["T"] as? Int64, 1_700_000_000_000)
    }

    func testSetThemeCommandJSON() throws {
        let cmd = BridgeCommand.setTheme("light")
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "setTheme")
        let payload = try XCTUnwrap(obj["payload"] as? [String: Any])
        XCTAssertEqual(payload["theme"] as? String, "light")
    }

    func testAddIndicatorWithParamsJSON() throws {
        let cmd = BridgeCommand.addIndicator(name: "SMA", params: ["period": 20])
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "addIndicator")
        let payload = try XCTUnwrap(obj["payload"] as? [String: Any])
        XCTAssertEqual(payload["shortName"] as? String, "SMA")
        let params = try XCTUnwrap(payload["params"] as? [String: Any])
        XCTAssertEqual(params["period"] as? Int, 20)
    }

    func testSetDrawingToolNilJSON() throws {
        let cmd = BridgeCommand.setDrawingTool(nil)
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "setDrawingTool")
        let payload = try XCTUnwrap(obj["payload"] as? [String: Any])
        XCTAssertTrue(payload["tool"] is NSNull)
    }

    func testClearAllDrawingsJSON() throws {
        let cmd = BridgeCommand.clearAllDrawings
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "clearAllDrawings")
    }

    func testDestroyCommandJSON() throws {
        let cmd = BridgeCommand.destroy
        let obj = try parseJSON(cmd.jsonString)
        XCTAssertEqual(obj["type"] as? String, "destroy")
    }

    // ── BridgeEvent parsing ───────────────────────────────────────────────────

    func testParseReadyEvent() {
        let event = BridgeEvent.parse(#"{"type":"ready"}"#)
        guard case .ready = event else {
            XCTFail("Expected .ready, got \(String(describing: event))")
            return
        }
    }

    func testParseCrosshairEvent() {
        let json = """
        {
          "type": "crosshair",
          "bar": {"time": 1700000000000, "open": 1.1, "high": 1.2, "low": 1.0, "close": 1.15, "volume": 1000},
          "position": {"x": 100.5, "y": 200.0}
        }
        """
        let event = BridgeEvent.parse(json)
        guard case let .crosshair(time, open, high, low, close, volume, x, y) = event else {
            XCTFail("Expected .crosshair, got \(String(describing: event))")
            return
        }
        XCTAssertEqual(time, 1_700_000_000_000)
        XCTAssertEqual(open, 1.1)
        XCTAssertEqual(high, 1.2)
        XCTAssertEqual(low, 1.0)
        XCTAssertEqual(close, 1.15)
        XCTAssertEqual(volume, 1000)
        XCTAssertEqual(x, 100.5)
        XCTAssertEqual(y, 200.0)
    }

    func testParseViewportChangeEvent() {
        let json = """
        {"type":"viewportChange","viewport":{"startIndex":0,"endIndex":99,"barWidth":8.5}}
        """
        let event = BridgeEvent.parse(json)
        guard case let .viewportChange(start, end, barWidth) = event else {
            XCTFail("Expected .viewportChange, got \(String(describing: event))")
            return
        }
        XCTAssertEqual(start, 0)
        XCTAssertEqual(end, 99)
        XCTAssertEqual(barWidth, 8.5)
    }

    func testParseDataLoadedEvent() {
        let json = #"{"type":"dataLoaded","barCount":250}"#
        let event = BridgeEvent.parse(json)
        guard case let .dataLoaded(count) = event else {
            XCTFail("Expected .dataLoaded, got \(String(describing: event))")
            return
        }
        XCTAssertEqual(count, 250)
    }

    func testParseErrorEvent() {
        let json = #"{"type":"error","message":"Engine crash","code":"E001"}"#
        let event = BridgeEvent.parse(json)
        guard case let .error(message, code) = event else {
            XCTFail("Expected .error, got \(String(describing: event))")
            return
        }
        XCTAssertEqual(message, "Engine crash")
        XCTAssertEqual(code, "E001")
    }

    func testParseInvalidJSONReturnsNil() {
        XCTAssertNil(BridgeEvent.parse("not json at all"))
    }

    func testParseUnknownTypeReturnsNil() {
        XCTAssertNil(BridgeEvent.parse(#"{"type":"unknownFutureEvent","payload":{}}"#))
    }

    func testParseMissingTypeReturnsNil() {
        XCTAssertNil(BridgeEvent.parse(#"{"foo":"bar"}"#))
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private func parseJSON(_ jsonString: String) throws -> [String: Any] {
        let data = try XCTUnwrap(jsonString.data(using: .utf8))
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
