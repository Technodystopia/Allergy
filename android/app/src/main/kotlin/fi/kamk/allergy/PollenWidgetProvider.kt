package fi.kamk.allergy

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Build
import android.widget.RemoteViews

/// Home-screen widget showing today's worst pollen level for the user's
/// current location. Data is pushed from Dart via the home_widget plugin,
/// which stores it in the "HomeWidgetPreferences" SharedPreferences file —
/// we read it directly here to avoid coupling to the plugin's Kotlin API.
class PollenWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray
    ) {
        val data = context.getSharedPreferences(
            "HomeWidgetPreferences", Context.MODE_PRIVATE
        )

        appWidgetIds.forEach { widgetId ->
            val views = RemoteViews(context.packageName, R.layout.pollen_widget)

            val location = data.getString("widget_location", "Pollen FI")
            val level = data.getString("widget_level", "—")
            val allergen = data.getString("widget_allergen", "")
            val updated = data.getString("widget_updated", "")
            // Level accent colour (defaults to a calm grey-green).
            val color = data.getInt("widget_color", 0xFFB0BEC5.toInt())

            views.setTextViewText(R.id.widget_location, location)
            views.setTextViewText(R.id.widget_level, level)
            views.setTextViewText(R.id.widget_allergen, allergen)
            views.setTextViewText(R.id.widget_updated, updated)
            views.setTextColor(R.id.widget_level, color)

            // Tap the widget to open the app.
            val intent = Intent(context, MainActivity::class.java)
            var flags = PendingIntent.FLAG_UPDATE_CURRENT
            if (Build.VERSION.SDK_INT >= 23) {
                flags = flags or PendingIntent.FLAG_IMMUTABLE
            }
            val pending = PendingIntent.getActivity(context, 0, intent, flags)
            views.setOnClickPendingIntent(R.id.widget_root, pending)

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
