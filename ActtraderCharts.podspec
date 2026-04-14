Pod::Spec.new do |s|
  s.name             = 'ActtraderCharts'
  s.version          = '1.0.9'
  s.summary          = 'ActTrader financial charting library for iOS — WKWebView wrapper.'
  s.description      = <<-DESC
    ActtraderCharts embeds the ActTrader stock chart (canvas-based, zero native deps)
    inside a WKWebView and exposes a Swift API for loading data, streaming ticks,
    switching themes/series/timeframes, managing indicators and drawings, and receiving
    typed events back from the chart engine.
  DESC

  s.homepage         = 'https://github.com/piyushrawat1991/acttrader-charts-ios'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'ActTrader' => 'dev@acttrader.com' }
  s.source           = { :git => 'https://github.com/piyushrawat1991/acttrader-charts-ios.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.swift_versions        = ['5.7']

  s.source_files     = 'Sources/ActtraderCharts/**/*.swift'
  s.resource_bundles = {
    'ActtraderCharts' => ['Sources/ActtraderCharts/Resources/chart.html']
  }

  s.frameworks       = 'UIKit', 'WebKit'
end
