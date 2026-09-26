package top.hanerx.dcomic

import android.content.Context
import android.net.ConnectivityManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dcomic/network_diagnostics")
            .setMethodCallHandler { call, result ->
                if (call.method != "getDnsConfiguration") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                try {
                    val manager = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                    val network = manager.activeNetwork
                    if (network == null) {
                        result.error("NO_ACTIVE_NETWORK", "No active network", null)
                        return@setMethodCallHandler
                    }
                    val properties = manager.getLinkProperties(network)
                    if (properties == null) {
                        result.error("DNS_UNAVAILABLE", "Network properties unavailable", null)
                        return@setMethodCallHandler
                    }
                    result.success(mapOf(
                        "servers" to properties.dnsServers.mapNotNull { it.hostAddress },
                        "privateDnsActive" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            properties.isPrivateDnsActive
                        } else null,
                        "privateDnsServerName" to if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                            properties.privateDnsServerName
                        } else null,
                    ))
                } catch (_: Exception) {
                    result.error("DNS_UNAVAILABLE", "Could not read DNS configuration", null)
                }
            }
    }
}
