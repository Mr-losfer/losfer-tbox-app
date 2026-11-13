package pro.noqi.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private var security: SecurityBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val bridge = SecurityBridge(this)
        security = bridge
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SecurityBridge.CHANNEL)
            .setMethodCallHandler(bridge)

        // 播放器手势调亮度：只改当前窗口，不动系统设置
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getBrightness" -> {
                        val current = window.attributes.screenBrightness
                        result.success(if (current < 0f) 0.5 else current.toDouble())
                    }
                    "setBrightness" -> {
                        val value = (call.argument<Double>("value") ?: 0.5).toFloat().coerceIn(0.02f, 1f)
                        val lp = window.attributes
                        lp.screenBrightness = value
                        window.attributes = lp
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    companion object {
        private const val DISPLAY_CHANNEL = "pro.noqi/display"
    }

    override fun onDestroy() {
        security = null
        super.onDestroy()
    }
}
