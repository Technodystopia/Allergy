import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import 'l10n.dart';
import 'models.dart';
import 'notification_service.dart';
import 'services.dart';

/// Unique names for the background work.
const _taskName = 'pollenDailyCheck';
const _taskUnique = 'pollen-daily-check';

/// Schedules / cancels the periodic "high pollen tomorrow" background check.
/// Failures (e.g. plugin missing in a test) are swallowed.
class BackgroundService {
  Future<void> init() async {
    try {
      await Workmanager().initialize(callbackDispatcher);
    } catch (_) {}
  }

  Future<void> enable() async {
    try {
      // Recurring twice-daily check.
      await Workmanager().registerPeriodicTask(
        _taskUnique,
        _taskName,
        frequency: const Duration(hours: 12),
        initialDelay: const Duration(minutes: 30),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
      );
      // And one immediate run so the user gets a first check right away.
      await Workmanager().registerOneOffTask(
        '$_taskUnique-now',
        _taskName,
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingWorkPolicy.replace,
      );
    } catch (_) {}
  }

  Future<void> disable() async {
    try {
      await Workmanager().cancelByUniqueName(_taskUnique);
      await Workmanager().cancelByUniqueName('$_taskUnique-now');
    } catch (_) {}
  }
}

/// Entry point for the background isolate. Runs detached from the UI, so it
/// rebuilds the minimal state it needs (catalog + prefs) from scratch.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await checkTomorrow();
      return true;
    } catch (_) {
      // Let WorkManager retry later rather than crash-looping.
      return true;
    }
  });
}

/// The actual check: fetch the home location's forecast and, if any selected
/// allergen is High+ tomorrow, post a heads-up notification. Pure-ish: pulls
/// everything from prefs + bundled assets so it works without the UI.
Future<void> checkTomorrow() async {
  final prefs = await SharedPreferences.getInstance();

  // Respect the user's notification opt-in.
  if (!(prefs.getBool('daily_alert') ?? false)) return;

  final selected = (prefs.getStringList('selected_allergens') ?? const [])
      .toSet();
  if (selected.isEmpty) return;

  final catalog = await Catalog.load();
  final allergens =
      catalog.allergens.where((a) => selected.contains(a.id)).toList();
  if (allergens.isEmpty) return;

  // Resolve the home location (which may be the GPS pseudo-location).
  final homeId = prefs.getString('home_location') ?? 'helsinki';
  final double lat, lon;
  final String placeName;
  if (homeId == 'gps' && prefs.getDouble('gps_lat') != null) {
    lat = prefs.getDouble('gps_lat')!;
    lon = prefs.getDouble('gps_lon')!;
    placeName = prefs.getString('gps_name') ?? 'My location';
  } else {
    final loc = catalog.locationById(homeId);
    lat = loc.lat;
    lon = loc.lon;
    placeName = loc.nameFi;
  }

  // Use the same source the user picked.
  final sourceId = prefs.getString('pollen_source') ?? 'openmeteo';
  final PollenSource source =
      sourceId == 'silam' ? SilamSource() : OpenMeteoSource();

  Map<String, List<DailyPollen>> forecast;
  try {
    forecast =
        await source.fetch(lat: lat, lon: lon, allergens: allergens);
  } catch (_) {
    return; // offline — skip this run quietly
  }

  // Worst (allergen, level) for tomorrow across selected allergens.
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final worst = Seasonal.worstForDay(
    allergens: allergens,
    forecast: forecast,
    today: today,
    dayOffset: 1, // tomorrow
  );

  debugPrint('[pollen-bg] tomorrow worst = '
      '${worst?.allergen.id} ${worst?.level.name} @ $placeName');
  if (worst == null || worst.level.rank < PollenLevel.high.rank) return;

  final lang = prefs.getString('language') == 'fi' ? AppLang.fi : AppLang.en;
  final s = L10n(lang);
  final notifications = NotificationService();
  await notifications.showHeadsUp(
    s.tomorrowHeadline(s.level(worst.level), s.allergenName(worst.allergen)),
    '$placeName: ${s.levelAdvice(worst.level)}',
  );
}
