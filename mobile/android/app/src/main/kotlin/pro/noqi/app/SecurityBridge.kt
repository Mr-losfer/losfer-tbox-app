package pro.noqi.app

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * 客户端安全能力：
 *  · inspect —— 系统代理 / VPN / Root / 可调试 四项探测
 *  · secure  —— FLAG_SECURE，开启后截屏与录屏均为黑屏
 *  · wipe    —— 清空剪贴板（避免播放直链被复制外流）
 */
class SecurityBridge(private val activity: MainActivity) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "pro.noqi/security"
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "inspect" -> result.success(inspect())
            "secure" -> {
                val on = call.arguments as? Boolean ?: true
                secure(on)
                result.success(null)
            }
            "wipe" -> {
                wipeClipboard()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun inspect(): Map<String, Any> {
        val cm = activity.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager

        val proxy = hasSystemProxy(cm)
        val vpn = cm?.let {
            val net = it.activeNetwork ?: return@let false
            val caps = it.getNetworkCapabilities(net) ?: return@let false
            caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
        } ?: false

        val debuggable = (activity.applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0

        return mapOf(
            "proxy" to proxy,
            "vpn" to vpn,
            "rooted" to isRooted(),
            "debuggable" to debuggable,
        )
    }

    private fun hasSystemProxy(cm: ConnectivityManager?): Boolean {
        // 1) JVM 层代理（Charles / mitmproxy 常用）
        val host = System.getProperty("http.proxyHost")
        if (!host.isNullOrBlank()) return true
        // 2) 系统全局代理（Wi-Fi 高级选项里手填的）
        val global = Settings.Global.getString(activity.contentResolver, Settings.Global.HTTP_PROXY)
        if (!global.isNullOrBlank()) return true
        // 3) 当前网络生效的代理（API 23+）
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val p = cm?.defaultProxy
                p != null && !p.host.isNullOrBlank()
            } else {
                false
            }
        } catch (_: Throwable) {
            false
        }
    }

    private fun isRooted(): Boolean {
        val paths = arrayOf(
            "/system/bin/su", "/system/xbin/su", "/sbin/su", "/su/bin/su",
            "/system/app/Superuser.apk", "/system/app/SuperSU.apk",
            "/data/local/bin/su", "/data/local/xbin/su",
        )
        if (paths.any { File(it).exists() }) return true
        return try {
            val tags = Build.TAGS ?: ""
            tags.contains("test-keys")
        } catch (_: Throwable) {
            false
        }
    }

    private fun secure(on: Boolean) {
        activity.runOnUiThread {
            val flag = WindowManager.LayoutParams.FLAG_SECURE
            if (on) {
                activity.window.addFlags(flag)
            } else {
                activity.window.clearFlags(flag)
            }
        }
    }

    private fun wipeClipboard() {
        try {
            val cm = activity.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager ?: return
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                cm.clearPrimaryClip()
            } else {
                cm.setPrimaryClip(ClipData.newPlainText("", ""))
            }
        } catch (_: Throwable) {
        }
    }
}
