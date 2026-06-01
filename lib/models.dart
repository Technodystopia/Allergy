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
    required this.season,
    required this.thresholds,
    required this.crossReactions,
  });

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

/// A single day's peak pollen for one allergen.
class DailyPollen {
  final DateTime date;
  final double peak; // max hourly grains/m³ that day
  final bool estimated; // true → derived from the seasonal calendar, not the live model
  const DailyPollen({
    required this.date,
    required this.peak,
    required this.estimated,
  });

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'peak': peak,
        'estimated': estimated,
      };

  factory DailyPollen.fromJson(Map<String, dynamic> j) => DailyPollen(
        date: DateTime.parse(j['date'] as String),
        peak: (j['peak'] as num).toDouble(),
        estimated: j['estimated'] as bool,
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
