// Basic smoke test for the pollen reference/seasonal logic.
import 'package:flutter_test/flutter_test.dart';
import 'package:allergy/models.dart';
import 'package:allergy/services.dart';

void main() {
  final birch = Allergen(
    id: 'birch',
    openMeteoVar: 'birch_pollen',
    nameEn: 'Birch',
    nameFi: 'Koivu',
    scientificName: 'Betula',
    family: 'Betulaceae',
    emoji: '🌲',
    relevanceFi: 'very_high',
    description: '',
    season: const Season(
        startMonth: 4, endMonth: 5, peakStartMonth: 5, peakEndMonth: 5, note: ''),
    thresholds: const Thresholds(low: 1, moderate: 10, high: 100, veryHigh: 1500),
    crossReactions: const CrossReactions(pollen: [], foods: []),
  );

  test('thresholds map grains to levels', () {
    expect(birch.thresholds.levelFor(0), PollenLevel.none);
    expect(birch.thresholds.levelFor(5), PollenLevel.low);
    expect(birch.thresholds.levelFor(50), PollenLevel.moderate);
    expect(birch.thresholds.levelFor(500), PollenLevel.high);
    expect(birch.thresholds.levelFor(2000), PollenLevel.veryHigh);
  });

  test('bloom stage tracks the season', () {
    expect(Seasonal.stageFor(birch, DateTime(2026, 2, 1)), BloomStage.dormant);
    expect(Seasonal.stageFor(birch, DateTime(2026, 4, 15)), BloomStage.onset);
    expect(Seasonal.stageFor(birch, DateTime(2026, 5, 10)), BloomStage.peak);
    expect(Seasonal.stageFor(birch, DateTime(2026, 7, 1)), BloomStage.ended);
  });

  test('seven day series fills estimated days', () {
    final series = Seasonal.sevenDaySeries(
      allergen: birch,
      live: [
        DailyPollen(date: DateTime(2026, 5, 1), peak: 200, estimated: false),
      ],
      today: DateTime(2026, 5, 1),
    );
    expect(series.length, 7);
    expect(series.first.estimated, false);
    expect(series.last.estimated, true);
  });
}
