import WebKit

/// Weak-reference proxy for `WKScriptMessageHandler`.
///
/// `WKUserContentController` holds a **strong** reference to any handler added via
/// `add(_:name:)`. Because `WKWebView` owns its configuration (and therefore the
/// `userContentController`), and `ActtraderChartsView` owns the `WKWebView`, the
/// chain `ActtraderChartsView → WKWebView → WKUserContentController → handler`
/// forms a retain cycle when `self` is passed directly — `deinit` would never fire.
///
/// Fix: pass `WeakScriptMessageHandler(self)` instead of `self`. The proxy holds
/// a `weak` reference, breaking the cycle. `deinit` on `ActtraderChartsView` is
/// also used as a safety net to call `removeScriptMessageHandler(forName:)`.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {

    weak var delegate: WKScriptMessageHandler?

    init(_ delegate: WKScriptMessageHandler) {
        self.delegate = delegate
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        delegate?.userContentController(userContentController, didReceive: message)
    }
}
