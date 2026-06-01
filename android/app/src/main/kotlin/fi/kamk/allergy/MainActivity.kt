package fi.kamk.allergy

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channel = "fi.kamk.allergy/widget"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        saveWidgetData(call)
                        refreshWidgets()
                        result.success(null)
                    }
                    "pin" -> result.success(requestPin())
                    else -> result.notImplemented()
                }
            }
    }

    /// Persist the snapshot where PollenWidgetProvider reads it.
    private fun saveWidgetData(call: MethodCall) {
        val prefs = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
            .edit()
        prefs.putString("widget_location", call.argument("location"))
        prefs.putString("widget_level", call.argument("level"))
        prefs.putString("widget_allergen", call.argument("allergen"))
        prefs.putString("widget_updated", call.argument("updated"))
        // Dart sends the ARGB int as a Long (it exceeds 32-bit signed range),
        // so read it as a Number and narrow to Int (wraps to signed ARGB).
        val color: Number? = call.argument("color")
        if (color != null) prefs.putInt("widget_color", color.toInt())
        prefs.apply()
    }

    /// Ask the launcher to pin our widget (Android 8+). Returns false if the
    /// launcher doesn't support pinning.
    private fun requestPin(): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        val manager = AppWidgetManager.getInstance(this)
        val provider = ComponentName(this, PollenWidgetProvider::class.java)
        if (!manager.isRequestPinAppWidgetSupported) return false
        return manager.requestPinAppWidget(provider, null, null)
    }

    /// Ask every placed instance of our widget to redraw.
    private fun refreshWidgets() {
        val manager = AppWidgetManager.getInstance(this)
        val ids = manager.getAppWidgetIds(
            ComponentName(this, PollenWidgetProvider::class.java)
        )
        if (ids.isEmpty()) return
        val intent = Intent(this, PollenWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        sendBroadcast(intent)
    }
}
