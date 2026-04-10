import Foundation

extension Foundation.Bundle {
    static let module: Bundle = {
        let mainPath = Bundle.main.bundleURL.appendingPathComponent("ActtraderCharts_ActtraderCharts.bundle").path
        let buildPath = "/Users/piyush/Documents/Projects/ChartingLibrary/acttrader-charts-ios/.build/x86_64-apple-macosx/debug/ActtraderCharts_ActtraderCharts.bundle"

        let preferredBundle = Bundle(path: mainPath)

        guard let bundle = preferredBundle ?? Bundle(path: buildPath) else {
            // Users can write a function called fatalError themselves, we should be resilient against that.
            Swift.fatalError("could not load resource bundle: from \(mainPath) or \(buildPath)")
        }

        return bundle
    }()
}