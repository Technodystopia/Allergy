import 'package:flutter/material.dart';

/// Severity level for a pollen reading. Ranks are used for sorting/colouring.
enum PollenLevel {
  none(0, 'None', Color(0xFF9E9E9E),
      'No pollen of this type expected.'),
  low(1, 'Low', Color(0xFF43A047),
      'Low — most people won’t notice symptoms.'),
  moderate(2, 'Moderate', Color(0xFFFBC02D),
      'Sensitive people may react — keep medication handy.'),
  high(3, 'High', Color(0xFFFB8C00),
      'Symptoms likely. Limit time outdoors, keep windows shut, take antihistamines.'),
  veryHigh(4, 'Very high', Color(0xFFE53935),
      'Strong reactions likely. Stay in midday, windows closed, consider a mask outdoors.');

  final int rank;
  final String label;
  final Color color;
  final String advice;
  const PollenLevel(this.rank, this.label, this.color, this.advice);
}

/// Per-taxon grains/m³ thresholds (Finnish aerobiology scale).
/// Trees, grass and weeds use very different cut-offs, so each allergen
/// carries its own thresholds.
class Thresholds {
  final double low, moderate, high, veryHigh;
  const Thresholds({
    required this.low,
    required this.moderate,
    required this.high,
    required this.veryHigh,
  });

  factory Thresholds.fromJson(Map<String, dynamic> j) => Thresholds(
        low: (j['low'] as num).toDouble(),
        moderate: (j['moderate'] as num).toDouble(),
        high: (j['high'] as num).toDouble(),
        veryHigh: (j['veryHigh'] as num).toDouble(),
      );

  PollenLevel levelFor(double v) {
    if (v < low) return PollenLevel.none;
    if (v < moderate) return PollenLevel.low;
    if (v < high) return PollenLevel.moderate;
    if (v < veryHigh) return PollenLevel.high;
    return PollenLevel.veryHigh;
  }

  /// A representative grains value for a level — used to plot estimated days.
  double valueFor(PollenLevel level) {
    switch (level) {
      case PollenLevel.none:
        return 0;
      case PollenLevel.low:
        return low;
      case PollenLevel.moderate:
        return moderate;
      case PollenLevel.high:
        return high;
      case PollenLevel.veryHigh:
        return veryHigh;
    }
  }
}

class Season {
  final int startMonth, endMonth, peakStartMonth, peakEndMonth;
  final String note;
  final String? noteFi;
  const Season({
    required this.startMonth,
    required this.endMonth,
    required this.peakStartMonth,
    required this.peakEndMonth,
    required this.note,
    this.noteFi,
  });

  factory Season.fromJson(Map<String, dynamic> j) => Season(
        startMonth: j['startMonth'] as int,
        endMonth: j['endMonth'] as int,
        peakStartMonth: j['peakStartMonth'] as int,
        peakEndMonth: j['peakEndMonth'] as int,
        note: (j['note'] ?? '') as String,
        noteFi: j['noteFi'] as String?,
      );

  String localizedNote(bool fi) => (fi ? noteFi : null) ?? note;

  /// Calendar intensity tier for a given month (1–12), for the compact grid:
  /// 3 = main flowering (peak), 2 = early/late flowering (in season, off peak),
  /// 1 = possible occurrence (one month either side of the core season),
  /// 0 = none. The "possible" fringe is a convention, not extra data.
  int tierForMonth(int month) {
    if (month >= peakStartMonth && month <= peakEndMonth) return 3;
    if (month >= startMonth && month <= endMonth) return 2;
    final pStart = startMonth > 1 ? startMonth - 1 : 1;
    final pEnd = endMonth < 12 ? endMonth + 1 : 12;
    if (month >= pStart && month <= pEnd) return 1;
    return 0;
  }
}

/// Current + daily weather (Open-Meteo forecast), shown beside pollen.
class DailyWeather {
  final DateTime date;
  final double max, min;
  final int code; // WMO weather code
  const DailyWeather(
      {required this.date,
      required this.max,
      required this.min,
      required this.code});

  Map<String, dynamic> toJson() => {
        'd': date.toIso8601String(),
        'max': max,
        'min': min,
        'c': code,
      };

  factory DailyWeather.fromJson(Map<String, dynamic> j) => DailyWeather(
        date: DateTime.parse(j['d'] as String),
        max: (j['max'] as num).toDouble(),
        min: (j['min'] as num).toDouble(),
        code: j['c'] as int,
      );
}

class Weather {
  final double tempC;
  final int code;
  final List<DailyWeather> days;
  const Weather({required this.tempC, required this.code, required this.days});

  DailyWeather? get today => days.isNotEmpty ? days.first : null;

  Map<String, dynamic> toJson() => {
        't': tempC,
        'c': code,
        'days': days.map((d) => d.toJson()).toList(),
      };

  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
        tempC: (j['t'] as num).toDouble(),
        code: j['c'] as int,
        days: ((j['days'] as List?) ?? const [])
            .map((e) => DailyWeather.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Personal stance on a cross-reaction food: untracked, try with caution
/// (haven't confirmed yet), or known to avoid.
enum FoodStatus { none, caution, avoid }

/// Categories for a free-form, non-pollen allergy the user adds themselves.
const kAllergyCategories = [
  'food',
  'medication',
  'animal',
  'environment',
  'other'
];

/// A user-entered allergy that isn't a tracked pollen (e.g. penicillin, cats,
/// shellfish). Free-form list kept in the diary.
class OtherAllergy {
  final String name;
  final String category; // one of kAllergyCategories
  final String note;
  const OtherAllergy(
      {required this.name, this.category = 'other', this.note = ''});

  Map<String, dynamic> toJson() => {
        'name': name,
        'cat': category,
        if (note.isNotEmpty) 'note': note,
      };

  factory OtherAllergy.fromJson(Map<String, dynamic> j) => OtherAllergy(
        name: j['name'] as String,
        category: (j['cat'] as String?) ?? 'other',
        note: (j['note'] as String?) ?? '',
      );
}

class CrossReactions {
  final List<String> pollen;
  final List<String> foods;
  const CrossReactions({required this.pollen, required this.foods});

  factory CrossReactions.fromJson(Map<String, dynamic> j) => CrossReactions(
        pollen: (j['pollen'] as List).cast<String>(),
        foods: (j['foods'] as List).cast<String>(),
      );
}

class Allergen {
  final String id;
  final String? openMeteoVar;
  final String? silamVar;
  final String nameEn, nameFi, scientificName, family, emoji, relevanceFi, description;
  final String? descriptionFi;
  final String? kasviatlasKey; // Finnish name for the Kasviatlas distribution atlas
  final Season season;
  final Thresholds thresholds;
  final CrossReactions crossReactions;

  const Allergen({
    required this.id,
    required this.openMeteoVar,
    this.silamVar,
    required this.nameEn,
    required this.nameFi,
    required this.scientificName,
    required this.family,
    required this.emoji,
    required this.relevanceFi,
    required this.description,
    this.descriptionFi,
    this.kasviatlasKey,
    required this.season,
    required this.thresholds,
    required this.crossReactions,
  });

  /// URL to this taxon's distribution maps on kasviatlas.fi, or null if none.
  String? get kasviatlasUrl => kasviatlasKey == null
      ? null
      : 'https://kasviatlas.fi/lajit/?key=${Uri.encodeComponent(kasviatlasKey!)}&year=2023';

  bool get hasLiveForecast => openMeteoVar != null;

  String localizedDescription(bool fi) => (fi ? descriptionFi : null) ?? description;

  factory Allergen.fromJson(Map<String, dynamic> j) => Allergen(
        id: j['id'] as String,
        openMeteoVar: j['openMeteoVar'] as String?,
        silamVar: j['silamVar'] as String?,
        nameEn: j['nameEn'] as String,
        nameFi: j['nameFi'] as String,
        scientificName: j['scientificName'] as String,
        family: j['family'] as String,
        emoji: j['emoji'] as String,
        relevanceFi: j['relevanceFi'] as String,
        description: j['description'] as String,
        descriptionFi: j['descriptionFi'] as String?,
        kasviatlasKey: j['kasviatlasKey'] as String?,
        season: Season.fromJson(j['season'] as Map<String, dynamic>),
        thresholds: Thresholds.fromJson(j['thresholds'] as Map<String, dynamic>),
        crossReactions:
            CrossReactions.fromJson(j['crossReactions'] as Map<String, dynamic>),
      );
}

class AppLocation {
  final String id, nameFi, region;
  final double lat, lon;
  final bool capitalRegion;
  const AppLocation({
    required this.id,
    required this.nameFi,
    required this.region,
    required this.lat,
    required this.lon,
    required this.capitalRegion,
  });

  factory AppLocation.fromJson(Map<String, dynamic> j) => AppLocation(
        id: j['id'] as String,
        nameFi: j['nameFi'] as String,
        region: j['region'] as String,
        lat: (j['lat'] as num).toDouble(),
        lon: (j['lon'] as num).toDouble(),
        capitalRegion: (j['capitalRegion'] ?? false) as bool,
      );
}

/// One hour's pollen value (local hour 0–23).
class HourSample {
  final int hour;
  final double value;
  const HourSample(this.hour, this.value);

  Map<String, dynamic> toJson() => {'h': hour, 'v': value};
  factory HourSample.fromJson(Map<String, dynamic> j) =>
      HourSample(j['h'] as int, (j['v'] as num).toDouble());
}

/// A single day's peak pollen for one allergen, plus its hourly breakdown.
class DailyPollen {
  final DateTime date;
  final double peak; // max hourly grains/m³ that day
  final bool estimated; // true → derived from the seasonal calendar, not the live model
  final List<HourSample> hours; // hourly samples (empty for estimated days)
  const DailyPollen({
    required this.date,
    required this.peak,
    required this.estimated,
    this.hours = const [],
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'peak': peak,
        'estimated': estimated,
        if (hours.isNotEmpty) 'hours': hours.map((h) => h.toJson()).toList(),
      };

  factory DailyPollen.fromJson(Map<String, dynamic> j) => DailyPollen(
        date: DateTime.parse(j['date'] as String),
        peak: (j['peak'] as num).toDouble(),
        estimated: j['estimated'] as bool,
        hours: (j['hours'] as List?)
                ?.map((e) => HourSample.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );

  /// Hour of the lowest pollen within daytime (06–22), or null if no data.
  int? get lowestDaytimeHour {
    final day = hours.where((h) => h.hour >= 6 && h.hour <= 22).toList();
    if (day.isEmpty) return null;
    day.sort((a, b) => a.value.compareTo(b.value));
    return day.first.hour;
  }

  /// Hour of the day's peak pollen, or null if no hourly data.
  int? get peakHour {
    if (hours.isEmpty) return null;
    final sorted = [...hours]..sort((a, b) => b.value.compareTo(a.value));
    return sorted.first.hour;
  }
}

/// A user's symptom log for one day, with a snapshot of that day's worst
/// pollen level (so symptoms can be read against exposure later).
/// Body areas a user can flag as bothered, in display order. Personalisable
/// (the diary settings can hide ones you never use).
const kBodyAreas = [
  'general',
  'eyes',
  'nose',
  'ears',
  'mouth',
  'throat',
  'skin',
  'lungs',
  'bronchi',
];

/// Time-of-day slots a symptom entry can belong to. 'day' is the legacy /
/// unspecified slot; users pick morning or evening.
const kDayParts = ['morning', 'evening'];

class SymptomEntry {
  final String dayKey; // yyyy-MM-dd
  final String part; // 'morning' | 'evening' | 'day' (legacy)
  final int severity; // 0 none · 1 mild · 2 moderate · 3 severe
  final int pollenRank; // worst PollenLevel.rank that day at log time (-1 unknown)
  final String note;
  final Set<String> areas; // bothered body areas (ids from kBodyAreas)
  const SymptomEntry({
    required this.dayKey,
    this.part = 'day',
    required this.severity,
    required this.pollenRank,
    this.note = '',
    this.areas = const {},
  });

  Map<String, dynamic> toJson() => {
        'day': dayKey,
        if (part != 'day') 'part': part,
        'sev': severity,
        'rank': pollenRank,
        if (note.isNotEmpty) 'note': note,
        if (areas.isNotEmpty) 'areas': areas.toList(),
      };

  factory SymptomEntry.fromJson(Map<String, dynamic> j) => SymptomEntry(
        dayKey: j['day'] as String,
        part: (j['part'] as String?) ?? 'day',
        severity: j['sev'] as int,
        pollenRank: (j['rank'] as int?) ?? -1,
        note: (j['note'] as String?) ?? '',
        areas: ((j['areas'] as List?)?.cast<String>() ?? const []).toSet(),
      );
}

/// Where an allergen is in its flowering cycle right now.
enum BloomStage {
  dormant('Pre-season', 'Not flowering yet'),
  onset('Onset', 'Season starting, counts rising'),
  peak('Peak', 'Peak flowering — highest counts'),
  declining('Declining', 'Season winding down'),
  ended('Over', 'Season finished for this year');

  final String label;
  final String description;
  const BloomStage(this.label, this.description);
}
