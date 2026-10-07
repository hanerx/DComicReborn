import Cocoa
import FlutterMacOS
import SystemConfiguration

class MainFlutterWindow: NSWindow {
  private var networkDiagnosticsChannel: FlutterMethodChannel?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    registerNetworkDiagnosticsChannel(with: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  private func registerNetworkDiagnosticsChannel(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "dcomic/network_diagnostics",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "getDnsConfiguration" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let store = SCDynamicStoreCreate(
          nil,
          "top.hanerx.dcomic.network-diagnostics" as CFString,
          nil,
          nil
        ),
        let dns = SCDynamicStoreCopyValue(
          store,
          "State:/Network/Global/DNS" as CFString
        ) as? [String: Any],
        let servers = dns["ServerAddresses"] as? [String]
      else {
        result(
          FlutterError(
            code: "DNS_UNAVAILABLE",
            message: "Could not read DNS configuration",
            details: nil
          )
        )
        return
      }

      result(["servers": servers])
    }
    networkDiagnosticsChannel = channel
  }
}
