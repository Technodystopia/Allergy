import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import 'models.dart';

/// Loads the bundled reference data (allergens + locations) from assets.
class Catalog {
  final List<Allergen> allergens;
  final List<AppLocation> locations;
  const Catalog({required this.allergens, required this.locations});

  static Future<Catalog> load() async {
    final aJson = json.decode(
        await rootBundle.loadString('assets/data/allergens.json')) as Map<String, dynamic>;
    final lJson = json.decode(
        await rootBundle.loadString('assets/data/locations.json')) as Map<String, dynamic>;

    final allergens = (aJson['allergens'] as List)
        .map((e) => Allergen.fromJson(e as Map<String, dynamic>))
        .toList();
    final locations = (lJson['locations'] as List)
        .map((e) => AppLocation.fromJson(e as Map<String, dynamic>))
        .toList();
    return Catalog(allergens: allergens, locations: locations);
  }

  Allergen byId(String id) => allergens.firstWhere((a) => a.id == id);
  AppLocation locationById(String id) =>
      locations.firstWhere((l) => l.id == id, orElse: () => locations.first);
}

/// A source of live pollen forecasts. Returns allergenId → daily peaks.
abstract class PollenSource {
  String get id;
  String get label;
  String get attribution;
  Future<Map<String, List<DailyPollen>>> fetch({
    required double lat,
    required double lon,
    required List<Allergen> allergens,
  });
}

/// Builds allergenId → sorted daily forecasts from per-day hourly samples.
/// Each day's peak is the max hourly value; the hourly samples are retained.
Map<String, List<DailyPollen>> _buildDays(
    Map<String, Map<String, List<HourSample>>> byAllergenDay) {
  final result = <String, List<DailyPollen>>{};
  byAllergenDay.forEach((allergenId, byDay) {
    final days = byDay.entries.map((e) {
      final hours = [...e.value]..sort((a, b) => a.hour.compareTo(b.hour));
      final peak = hours.fold<double>(0, (m, h) => h.value > m ? h.value : m);
      return DailyPollen(
        date: DateTime.parse(e.key),
        peak: peak,
        estimated: false,
        hours: hours,
      );
    }).toList()
      ..sort((x, y) => x.date.compareTo(y.date));
    result[allergenId] = days;
  });
  return result;
}

/// Free Open-Meteo Air-Quality API (CAMS European model). No API key.
class OpenMeteoSource implements PollenSource {
  @override
  String get id => 'openmeteo';
  @override
  String get label => 'Open-Meteo (CAMS)';
  @override
  String get attribution => 'Open-Meteo · CAMS European model';

  static const _base = 'https://air-quality-api.open-meteo.com/v1/air-quality';

  @override
  Future<Map<String, List<DailyPollen>>> fetch({
    required double lat,
    required double lon,
    required List<Allergen> allergens,
  }) async {
    final live = allergens.where((a) => a.openMeteoVar != null).toList();
    if (live.isEmpty) return {};

    final vars = live.map((a) => a.openMeteoVar!).toSet().toList();
    final url = Uri.parse(_base).replace(queryParameters: {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'hourly': vars.join(','),
      'timezone': 'Europe/Helsinki',
      'forecast_days': '4', // model cap for pollen in Europe
    });

    final resp = await http.get(url).timeout(const Duration(seconds: 15));
    if (resp.statusCode != 200) {
      throw Exception('Open-Meteo error ${resp.statusCode}');
    }
    final body = json.decode(resp.body) as Map<String, dynamic>;
    return parseBody(body, live);
  }

  /// Pure parsing of an Open-Meteo air-quality response body. Exposed for tests.
  static Map<String, List<DailyPollen>> parseBody(
      Map<String, dynamic> body, List<Allergen> live) {
    final hourly = body['hourly'] as Map<String, dynamic>?;
    if (hourly == null) return {};
    final times = (hourly['time'] as List).cast<String>();

    final byAllergenDay = <String, Map<String, List<HourSample>>>{};
    for (final a in live) {
      final series = hourly[a.openMeteoVar] as List?;
      if (series == null) continue;
      final byDay = <String, List<HourSample>>{};
      for (var i = 0; i < times.length && i < series.length; i++) {
        final v = series[i];
        if (v == null) continue;
        final t = times[i];
        final day = t.substring(0, 10);
        final hour = int.tryParse(t.substring(11, 13)) ?? 0;
        byDay
            .putIfAbsent(day, () => [])
            .add(HourSample(hour, (v as num).toDouble()));
      }
      byAllergenDay[a.id] = byDay;
    }
    return _buildDays(byAllergenDay);
  }
}

/// FMI's official SILAM model via the THREDDS NetCDF Subset Service.
/// Returns surface-level (lowest altitude) hourly concentrations as CSV,
/// which we reduce to a daily peak per allergen.
class SilamSource implements PollenSource {
  @override
  String get id => 'silam';
  @override
  String get label => 'SILAM (FMI, official)';
  @override
  String get attribution => 'SILAM v6.1 · Finnish Meteorological Institute';

  static const _base =
      'https://thredds.silam.fmi.fi/thredds/ncss/grid/silam_europe_pollen_v6_1/silam_europe_pollen_v6_1_best.ncd';

  @override
  Future<Map<String, List<DailyPollen>>> fetch({
    required double lat,
    required double lon,
    required List<Allergen> allergens,
  }) async {
    final live = allergens.where((a) => a.silamVar != null).toList();
    if (live.isEmpty) return {};

    // var → allergenId (CSV column header carries the var name + unit).
    final varToId = {for (final a in live) a.silamVar!: a.id};

    // Limit the payload hard: a single (surface) vertical level and just the
    // forecast window. Without this the response is ~190 KB of every altitude
    // level across the whole archive and times out on slower connections.
    final now = DateTime.now().toUtc();
    final start = DateTime.utc(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 6));
    final params = <String, dynamic>{
      'latitude': lat.toStringAsFixed(4),
      'longitude': lon.toStringAsFixed(4),
      'accept': 'csv',
      'vertCoord': '12.5', // lowest model level ≈ surface
      'time_start': _iso(start),
      'time_end': _iso(end),
    };
    // Uri supports repeated query keys via an iterable value.
    final url = Uri.parse(_base).replace(queryParameters: {
      ...params,
      'var': varToId.keys.toList(),
    });

    final resp = await http.get(url).timeout(const Duration(seconds: 25));
    if (resp.statusCode != 200) {
      throw Exception('SILAM error ${resp.statusCode}');
    }
    return parseCsv(resp.body, varToId);
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _iso(DateTime d) =>
      '${d.year}-${_two(d.month)}-${_two(d.day)}T00:00:00Z';

  /// Parses a SILAM NCSS CSV response. [nowUtc] sets the "today onward" cutoff
  /// (defaults to the real clock); exposed so tests can pin it.
  static Map<String, List<DailyPollen>> parseCsv(
      String body, Map<String, String> varToId,
      {DateTime? nowUtc}) {
    final lines = body.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return {};

    final header = lines.first.split(',');
    final timeIdx = header.indexWhere((h) => h.startsWith('time'));
    final altIdx = header.indexWhere((h) => h.startsWith('alt'));

    // Map each requested var to its column index (header is e.g.
    // `cnc_POLLEN_BIRCH_m22[unit="number/m3"]`).
    final colForId = <int, String>{};
    for (var c = 0; c < header.length; c++) {
      for (final v in varToId.keys) {
        if (header[c].startsWith(v)) colForId[c] = varToId[v]!;
      }
    }
    if (colForId.isEmpty || timeIdx < 0) return {};

    // The grid-as-point response includes every vertical level; keep only the
    // lowest altitude (surface) by first finding the minimum alt.
    double minAlt = double.infinity;
    if (altIdx >= 0) {
      for (var i = 1; i < lines.length; i++) {
        final cells = lines[i].split(',');
        if (cells.length <= altIdx) continue;
        final a = double.tryParse(cells[altIdx]);
        if (a != null && a < minAlt) minAlt = a;
      }
    }

    final byAllergenDay = <String, Map<String, List<HourSample>>>{};
    final today = (nowUtc ?? DateTime.now()).toUtc();
    final cutoff = DateTime.utc(today.year, today.month, today.day);

    for (var i = 1; i < lines.length; i++) {
      final cells = lines[i].split(',');
      if (cells.length <= timeIdx) continue;
      if (altIdx >= 0) {
        final a = double.tryParse(cells[altIdx]);
        if (a == null || a != minAlt) continue; // surface only
      }
      final ts = DateTime.tryParse(cells[timeIdx]);
      if (ts == null || ts.isBefore(cutoff)) continue; // today onward
      final day = cells[timeIdx].substring(0, 10);
      final hour = ts.toLocal().hour;
      colForId.forEach((col, allergenId) {
        if (cells.length <= col) return;
        final val = double.tryParse(cells[col]);
        if (val == null) return;
        byAllergenDay
            .putIfAbsent(allergenId, () => {})
            .putIfAbsent(day, () => [])
            .add(HourSample(hour, val));
      });
    }
    return _buildDays(byAllergenDay);
  }
}

/// Pure-logic seasonal model: bloom stage + climatological estimates used to
/// extend the live forecast out to 7 days (and to power the bloom timeline).
class Seasonal {
  static bool _inSeason(Season s, int month) =>
      month >= s.startMonth && month <= s.endMonth;

  static BloomStage stageFor(Allergen a, DateTime date) {
    final s = a.season;
    final m = date.month;
    if (m < s.startMonth) return BloomStage.dormant;
    if (m > s.endMonth) return BloomStage.ended;
    if (m >= s.peakStartMonth && m <= s.peakEndMonth) return BloomStage.peak;
    if (m < s.peakStartMonth) return BloomStage.onset;
    return BloomStage.declining;
  }

  static PollenLevel estimateLevel(Allergen a, DateTime date) {
    if (!_inSeason(a.season, date.month)) return PollenLevel.none;
    switch (stageFor(a, date)) {
      case BloomStage.peak:
        return PollenLevel.high;
      case BloomStage.onset:
      case BloomStage.declining:
        return PollenLevel.moderate;
      default:
        return PollenLevel.none;
    }
  }

  /// A representative daily peak (grains/m³) for an estimated day.
  static double estimatePeak(Allergen a, DateTime date) =>
      a.thresholds.valueFor(estimateLevel(a, date));

  /// Builds a full 7-day series: live model days first, then seasonal
  /// estimates for the remaining days, starting from [today] (date-only).
  static List<DailyPollen> sevenDaySeries({
    required Allergen allergen,
    required List<DailyPollen> live,
    required DateTime today,
  }) {
    final byDate = {for (final d in live) _key(d.date): d};
    final out = <DailyPollen>[];
    for (var i = 0; i < 7; i++) {
      final date = DateTime(today.year, today.month, today.day + i);
      final existing = byDate[_key(date)];
      out.add(existing ??
          DailyPollen(
            date: date,
            peak: estimatePeak(allergen, date),
            estimated: true,
          ));
    }
    return out;
  }

  static String _key(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
