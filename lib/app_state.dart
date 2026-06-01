import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n.dart';
import 'location_service.dart';
import 'background.dart';
import 'models.dart';
import 'notification_service.dart';
import 'services.dart';
import 'widget_service.dart';

/// Central app state: user's selected allergens, home base + favourite
/// locations, and the currently loaded forecast. Persisted via prefs.
class AppState extends ChangeNotifier {
  final Catalog catalog;
  final List<PollenSource> sources;
  final SharedPreferences prefs;
  final LocationService locationService;
  final NotificationService notifications;
  final WidgetService widgetService;
  final BackgroundService background;

  AppState({
    required this.catalog,
    required this.sources,
    required this.prefs,
    required this.locationService,
    required this.notifications,
    WidgetService? widgetService,
    BackgroundService? background,
  })  : widgetService = widgetService ?? WidgetService(),
        background = background ?? BackgroundService() {
    _load();
  }

  // --- persisted keys ---
  static const _kSelected = 'selected_allergens';
  static const _kHome = 'home_location';
  static const _kFavorites = 'favorite_locations';
  static const _kOnboarded = 'onboarded';
  static const _kGpsLat = 'gps_lat';
  static const _kGpsLon = 'gps_lon';
  static const _kGpsName = 'gps_name';
  static const _kSource = 'pollen_source';
  static const _kDailyAlert = 'daily_alert';
  static const _kAlertHour = 'alert_hour';
  static const _kAlertMinute = 'alert_minute';
  static const _kLang = 'language';
  static const _kDiary = 'symptom_diary';

  Set<String> _selected = {};
  String _homeId = 'helsinki';
  List<String> _favoriteIds = [];
  String _currentId = 'helsinki';
  bool onboarded = false;
  String _sourceId = 'openmeteo';
  bool dailyAlert = false;
  int alertHour = 7;
  int alertMinute = 0;
  AppLang _lang = AppLang.en;
  List<SymptomEntry> _diary = [];
  AppLocation? _gpsLocation;

  /// True while a GPS fix is being acquired.
  bool locating = false;

  // forecast state for the current location
  Map<String, List<DailyPollen>> _forecast = {};
  bool loading = false;
  Object? error;
  DateTime? lastUpdated;
  bool usingCache = false;

  Set<String> get selectedIds => _selected;
  String get homeId => _homeId;
  List<String> get favoriteIds => _favoriteIds;
  String get currentId => _currentId;

  AppLocation? get gpsLocation => _gpsLocation;

  AppLang get lang => _lang;
  L10n get s => L10n(_lang);

  Future<void> setLang(AppLang lang) async {
    if (_lang == lang) return;
    _lang = lang;
    await prefs.setString(_kLang, lang == AppLang.fi ? 'fi' : 'en');
    notifyListeners();
  }

  /// Diary entries, most recent first.
  List<SymptomEntry> get diary =>
      [..._diary]..sort((a, b) => b.dayKey.compareTo(a.dayKey));

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  SymptomEntry? get todayEntry {
    final key = _dayKey(DateTime.now());
    for (final e in _diary) {
      if (e.dayKey == key) return e;
    }
    return null;
  }

  /// Logs (or replaces) today's symptom entry, snapshotting today's worst level.
  Future<void> logToday(int severity, String note) async {
    final key = _dayKey(DateTime.now());
    final rank = worstToday()?.level.rank ?? -1;
    _diary.removeWhere((e) => e.dayKey == key);
    _diary.add(SymptomEntry(
        dayKey: key, severity: severity, pollenRank: rank, note: note));
    await _saveDiary();
    notifyListeners();
  }

  Future<void> deleteDiaryEntry(String dayKey) async {
    _diary.removeWhere((e) => e.dayKey == dayKey);
    await _saveDiary();
    notifyListeners();
  }

  Future<void> _saveDiary() async {
    await prefs.setString(
        _kDiary, json.encode(_diary.map((e) => e.toJson()).toList()));
  }

  PollenSource get currentSource =>
      sources.firstWhere((s) => s.id == _sourceId, orElse: () => sources.first);
  String get sourceId => _sourceId;

  Future<void> setSource(String id) async {
    if (_sourceId == id) return;
    _sourceId = id;
    await prefs.setString(_kSource, id);
    notifyListeners();
    await refresh();
  }

  AppLocation get currentLocation {
    if (_currentId == 'gps' && _gpsLocation != null) return _gpsLocation!;
    return catalog.locationById(_currentId);
  }

  /// Resolves any location id (including the GPS pseudo-location) to a name.
  String nameForId(String id) {
    if (id == 'gps') return _gpsLocation?.nameFi ?? 'My location';
    return catalog.locationById(id).nameFi;
  }

  List<Allergen> get selectedAllergens =>
      catalog.allergens.where((a) => _selected.contains(a.id)).toList();

  List<DailyPollen> forecastFor(String allergenId) =>
      _forecast[allergenId] ?? const [];

  void _load() {
    _selected = (prefs.getStringList(_kSelected) ?? const []).toSet();
    _homeId = prefs.getString(_kHome) ?? 'helsinki';
    _favoriteIds = prefs.getStringList(_kFavorites) ?? <String>[];
    onboarded = prefs.getBool(_kOnboarded) ?? false;
    _sourceId = prefs.getString(_kSource) ?? 'openmeteo';
    dailyAlert = prefs.getBool(_kDailyAlert) ?? false;
    alertHour = prefs.getInt(_kAlertHour) ?? 7;
    alertMinute = prefs.getInt(_kAlertMinute) ?? 0;
    _lang = (prefs.getString(_kLang) == 'fi') ? AppLang.fi : AppLang.en;

    final diaryStr = prefs.getString(_kDiary);
    if (diaryStr != null) {
      try {
        _diary = (json.decode(diaryStr) as List)
            .map((e) => SymptomEntry.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _diary = [];
      }
    }

    final lat = prefs.getDouble(_kGpsLat);
    final lon = prefs.getDouble(_kGpsLon);
    if (lat != null && lon != null) {
      _gpsLocation = AppLocation(
        id: 'gps',
        nameFi: prefs.getString(_kGpsName) ?? 'My location',
        region: 'Current location',
        lat: lat,
        lon: lon,
        capitalRegion: false,
      );
    }
    _currentId = _homeId;
  }

  /// Acquires a GPS fix, stores it, switches to it, and refreshes the forecast.
  /// Returns an error message on failure, or null on success.
  Future<String?> useMyLocation() async {
    locating = true;
    notifyListeners();
    try {
      final loc = await locationService.currentLocation();
      _gpsLocation = loc;
      await prefs.setDouble(_kGpsLat, loc.lat);
      await prefs.setDouble(_kGpsLon, loc.lon);
      await prefs.setString(_kGpsName, loc.nameFi);
      _currentId = 'gps';
      locating = false;
      notifyListeners();
      await refresh();
      return null;
    } catch (e) {
      locating = false;
      notifyListeners();
      return e.toString();
    }
  }

  Future<void> toggleAllergen(String id) async {
    if (_selected.contains(id)) {
      _selected.remove(id);
    } else {
      _selected.add(id);
    }
    await prefs.setStringList(_kSelected, _selected.toList());
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    onboarded = true;
    await prefs.setBool(_kOnboarded, true);
    notifyListeners();
    await refresh();
  }

  Future<void> setHome(String id) async {
    _homeId = id;
    await prefs.setString(_kHome, id);
    notifyListeners();
  }

  Future<void> toggleFavorite(String id) async {
    if (_favoriteIds.contains(id)) {
      _favoriteIds.remove(id);
    } else {
      _favoriteIds.add(id);
    }
    await prefs.setStringList(_kFavorites, _favoriteIds);
    notifyListeners();
  }

  Future<void> setCurrent(String id) async {
    if (_currentId == id) return;
    _currentId = id;
    notifyListeners();
    await refresh();
  }

  Future<void> setDailyAlert(bool on) async {
    dailyAlert = on;
    await prefs.setBool(_kDailyAlert, on);
    if (on) {
      await notifications.requestPermission();
      await notifications.scheduleDaily(alertHour, alertMinute);
      await background.enable(); // also check "high tomorrow" in the background
    } else {
      await notifications.cancelDaily();
      await background.disable();
    }
    notifyListeners();
  }

  Future<void> setAlertTime(int hour, int minute) async {
    alertHour = hour;
    alertMinute = minute;
    await prefs.setInt(_kAlertHour, hour);
    await prefs.setInt(_kAlertMinute, minute);
    if (dailyAlert) await notifications.scheduleDaily(hour, minute);
    notifyListeners();
  }

  /// The worst (allergen, level) across selected allergens for today.
  ({Allergen allergen, PollenLevel level})? worstToday() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    Allergen? worstA;
    PollenLevel worst = PollenLevel.none;
    for (final a in selectedAllergens) {
      final series = Seasonal.sevenDaySeries(
          allergen: a, live: forecastFor(a.id), today: today);
      final lvl = a.thresholds.levelFor(series.first.peak);
      if (lvl.rank >= worst.rank) {
        worst = lvl;
        worstA = a;
      }
    }
    if (worstA == null) return null;
    return (allergen: worstA, level: worst);
  }

  String _cacheKey() =>
      'cache_${_sourceId}_${currentLocation.id}_${currentLocation.lat.toStringAsFixed(2)}';

  void _saveCache() {
    final data = {
      for (final e in _forecast.entries)
        e.key: e.value.map((d) => d.toJson()).toList()
    };
    prefs.setString(
        _cacheKey(),
        json.encode({
          'savedAt': DateTime.now().toIso8601String(),
          'data': data,
        }));
  }

  bool _loadCache() {
    final s = prefs.getString(_cacheKey());
    if (s == null) return false;
    try {
      final obj = json.decode(s) as Map<String, dynamic>;
      final data = obj['data'] as Map<String, dynamic>;
      _forecast = {
        for (final e in data.entries)
          e.key: (e.value as List)
              .map((j) => DailyPollen.fromJson(j as Map<String, dynamic>))
              .toList()
      };
      lastUpdated = DateTime.tryParse(obj['savedAt'] as String? ?? '');
      return _forecast.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Loads the live forecast for the current location + selected allergens.
  Future<void> refresh() async {
    if (selectedAllergens.isEmpty) {
      _forecast = {};
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    usingCache = false;
    _loadCache(); // optimistic: show cached data instantly while fetching
    notifyListeners();
    try {
      final loc = currentLocation;
      _forecast = await currentSource.fetch(
        lat: loc.lat,
        lon: loc.lon,
        allergens: selectedAllergens,
      );
      lastUpdated = DateTime.now();
      _saveCache();
    } catch (e) {
      error = e;
      // Fall back to cached data if we have any, else seasonal estimates.
      usingCache = _loadCache();
      if (!usingCache) _forecast = {};
    } finally {
      loading = false;
      notifyListeners();
    }

    final worst = worstToday();

    // Keep the home-screen widget in sync with the latest snapshot.
    await widgetService.update(
      location: currentLocation.nameFi,
      worst: worst,
      s: s,
    );

    // Heads-up if any selected allergen is High+ today (only when alerts on).
    if (dailyAlert) {
      if (worst != null && worst.level.rank >= PollenLevel.high.rank) {
        await notifications.showHeadsUp(
          s.summaryHeadline(s.level(worst.level), s.allergenName(worst.allergen)),
          '${currentLocation.nameFi}: ${s.levelAdvice(worst.level)}',
        );
      }
    }
  }
}
