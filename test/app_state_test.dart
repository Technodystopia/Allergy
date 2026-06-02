import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:allergy/app_state.dart';
import 'package:allergy/l10n.dart';
import 'package:allergy/location_service.dart';
import 'package:allergy/models.dart';
import 'package:allergy/notification_service.dart';
import 'package:allergy/services.dart';

class FakeSource implements PollenSource {
  @override
  final String id;
  final Map<String, List<DailyPollen>> data;
  final bool fail;
  FakeSource(this.id, {this.data = const {}, this.fail = false});

  @override
  String get label => id;
  @override
  String get attribution => id;

  @override
  Future<Map<String, List<DailyPollen>>> fetch({
    required double lat,
    required double lon,
    required List<Allergen> allergens,
  }) async {
    if (fail) throw Exception('network down');
    return data;
  }
}

Allergen _birch() => Allergen(
      id: 'birch',
      openMeteoVar: 'birch_pollen',
      silamVar: 'cnc_POLLEN_BIRCH_m22',
      nameEn: 'Birch',
      nameFi: 'Koivu',
      scientificName: 'Betula',
      family: 'Betulaceae',
      emoji: '*',
      relevanceFi: 'very_high',
      description: '',
      season: const Season(
          startMonth: 4, endMonth: 5, peakStartMonth: 5, peakEndMonth: 5, note: ''),
      thresholds: const Thresholds(low: 1, moderate: 10, high: 100, veryHigh: 1500),
      crossReactions: const CrossReactions(pollen: [], foods: []),
    );

Catalog _catalog() => Catalog(allergens: [
      _birch()
    ], locations: const [
      AppLocation(
          id: 'helsinki',
          nameFi: 'Helsinki',
          region: 'Uusimaa',
          lat: 60.17,
          lon: 24.94,
          capitalRegion: true),
    ]);

AppState _state(List<PollenSource> sources, SharedPreferences prefs) => AppState(
      catalog: _catalog(),
      sources: sources,
      prefs: prefs,
      locationService: LocationService(),
      notifications: _NoopNotifications(),
      weatherService: _NoopWeather(),
    );

// Weather service that never touches the network in tests.
class _NoopWeather extends WeatherService {
  @override
  Future<Weather> fetch({required double lat, required double lon}) async =>
      throw Exception('no network in tests');
}

// NotificationService with no-op overrides so tests never touch the plugin.
class _NoopNotifications extends NotificationService {
  @override
  Future<void> init() async {}
  @override
  Future<bool> requestPermission() async => true;
  @override
  Future<void> showHeadsUp(String title, String body) async {}
  @override
  Future<void> scheduleDaily(int hour, int minute) async {}
  @override
  Future<void> cancelDaily() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final sample = {
    'birch': [DailyPollen(date: DateTime(2026, 5, 10), peak: 200, estimated: false)]
  };

  test('successful refresh stores forecast + cache and stamps lastUpdated',
      () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo', data: sample)], prefs);
    await state.toggleAllergen('birch');

    await state.refresh();

    expect(state.forecastFor('birch').first.peak, 200);
    expect(state.lastUpdated, isNotNull);
    expect(state.usingCache, false);
    expect(state.error, isNull);
    // a cache entry was written
    expect(prefs.getKeys().any((k) => k.startsWith('cache_')), true);
  });

  test('failed refresh falls back to cached forecast (offline)', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    // First, a good run to populate the cache.
    final good = _state([FakeSource('openmeteo', data: sample)], prefs);
    await good.toggleAllergen('birch');
    await good.refresh();

    // Then a fresh state with a failing source but the same prefs/cache.
    final offline = _state([FakeSource('openmeteo', fail: true)], prefs);
    await offline.refresh();

    expect(offline.error, isNotNull);
    expect(offline.usingCache, true);
    expect(offline.forecastFor('birch').first.peak, 200); // from cache
  });

  test('switching source persists and is reloaded', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state(
        [FakeSource('openmeteo'), FakeSource('silam')], prefs);

    expect(state.currentSource.id, 'openmeteo');
    await state.setSource('silam');
    expect(state.currentSource.id, 'silam');

    final reloaded = _state(
        [FakeSource('openmeteo'), FakeSource('silam')], prefs);
    expect(reloaded.sourceId, 'silam');
  });

  test('language preference persists across instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo')], prefs);
    expect(state.lang, AppLang.en);
    await state.setLang(AppLang.fi);

    final reloaded = _state([FakeSource('openmeteo')], prefs);
    expect(reloaded.lang, AppLang.fi);
  });

  test('diary entry logs, persists, and deletes', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo')], prefs);

    await state.logToday(2, 'sneezy');
    expect(state.todayEntry, isNotNull);
    expect(state.todayEntry!.severity, 2);
    expect(state.diary.length, 1);

    // persists across instances
    final reloaded = _state([FakeSource('openmeteo')], prefs);
    expect(reloaded.diary.length, 1);
    expect(reloaded.todayEntry!.note, 'sneezy');

    // re-logging the same day replaces, not duplicates
    await reloaded.logToday(0, '');
    expect(reloaded.diary.length, 1);
    expect(reloaded.todayEntry!.severity, 0);

    await reloaded.deleteDiaryEntry(reloaded.todayEntry!.dayKey);
    expect(reloaded.diary, isEmpty);
  });

  test('food intolerance flag + note persist across instances', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo')], prefs);

    await state.toggleFood('apple');
    await state.setFoodNote('apple', 'winter apples fine');
    expect(state.isFoodFlagged('apple'), true);
    expect(state.foodNote('apple'), 'winter apples fine');

    final reloaded = _state([FakeSource('openmeteo')], prefs);
    expect(reloaded.isFoodFlagged('apple'), true);
    expect(reloaded.foodNote('apple'), 'winter apples fine');

    await reloaded.toggleFood('apple'); // unflag removes it
    expect(reloaded.isFoodFlagged('apple'), false);
    expect(reloaded.flaggedFoods, isEmpty);
  });

  test('food tri-state cycles and persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo')], prefs);

    expect(state.foodStatus('kiwi'), FoodStatus.none);
    await state.cycleFood('kiwi');
    expect(state.foodStatus('kiwi'), FoodStatus.caution);
    await state.cycleFood('kiwi');
    expect(state.foodStatus('kiwi'), FoodStatus.avoid);

    final reloaded = _state([FakeSource('openmeteo')], prefs);
    expect(reloaded.foodStatus('kiwi'), FoodStatus.avoid);
    await reloaded.cycleFood('kiwi'); // back to none → removed
    expect(reloaded.isFoodFlagged('kiwi'), false);
  });

  test('legacy food notes migrate to avoid', () async {
    // Old format: a bare note string per food meant "avoid".
    SharedPreferences.setMockInitialValues(
        {'flutter.food_intolerances': '{"apple":"winter ok"}'});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo')], prefs);
    expect(state.foodStatus('apple'), FoodStatus.avoid);
    expect(state.foodNote('apple'), 'winter ok');
  });

  test('allergen selection persists', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final state = _state([FakeSource('openmeteo')], prefs);
    await state.toggleAllergen('birch');
    expect(state.selectedIds.contains('birch'), true);

    final reloaded = _state([FakeSource('openmeteo')], prefs);
    expect(reloaded.selectedIds.contains('birch'), true);
  });
}
