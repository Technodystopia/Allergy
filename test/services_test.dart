import 'package:flutter_test/flutter_test.dart';
import 'package:allergy/models.dart';
import 'package:allergy/services.dart';

Allergen _a(String id, {String? om, String? silam}) => Allergen(
      id: id,
      openMeteoVar: om,
      silamVar: silam,
      nameEn: id,
      nameFi: id,
      scientificName: id,
      family: id,
      emoji: '*',
      relevanceFi: 'high',
      description: '',
      season: const Season(
          startMonth: 1, endMonth: 12, peakStartMonth: 6, peakEndMonth: 7, note: ''),
      thresholds: const Thresholds(low: 1, moderate: 10, high: 100, veryHigh: 1500),
      crossReactions: const CrossReactions(pollen: [], foods: []),
    );

void main() {
  group('Open-Meteo parseBody', () {
    test('groups hourly values into daily maxima', () {
      final body = {
        'hourly': {
          'time': ['2026-06-01T00:00', '2026-06-01T06:00', '2026-06-02T00:00'],
          'birch_pollen': [1.0, 5.0, 2.0],
          'grass_pollen': [0.0, 3.0, 1.0],
        }
      };
      final out = OpenMeteoSource.parseBody(
          body, [_a('birch', om: 'birch_pollen'), _a('grass', om: 'grass_pollen')]);
      expect(out['birch']!.length, 2);
      expect(out['birch']![0].peak, 5.0); // max of day 1
      expect(out['birch']![1].peak, 2.0);
      expect(out['grass']![0].peak, 3.0);
      expect(out['birch']!.every((d) => d.estimated == false), true);
    });

    test('skips nulls and missing variables', () {
      final body = {
        'hourly': {
          'time': ['2026-06-01T00:00', '2026-06-01T06:00'],
          'birch_pollen': [null, 4.0],
        }
      };
      final out = OpenMeteoSource.parseBody(
          body, [_a('birch', om: 'birch_pollen'), _a('grass', om: 'grass_pollen')]);
      expect(out['birch']![0].peak, 4.0);
      expect(out.containsKey('grass'), false); // no series → omitted
    });
  });

  group('SILAM parseCsv', () {
    final now = DateTime.utc(2026, 6, 1);
    final varToId = {
      'cnc_POLLEN_BIRCH_m22': 'birch',
      'cnc_POLLEN_GRASS_m32': 'grass',
    };

    test('parses single-level CSV into daily maxima', () {
      const csv = '''
time,station,latitude[unit="degrees_north"],longitude[unit="degrees_east"],cnc_POLLEN_BIRCH_m22[unit="number/m3"],cnc_POLLEN_GRASS_m32[unit="number/m3"]
2026-06-01T00:00:00Z,GP,60.2,24.9,3.0,1.0
2026-06-01T12:00:00Z,GP,60.2,24.9,9.0,4.0
2026-06-02T00:00:00Z,GP,60.2,24.9,2.0,2.0''';
      final out = SilamSource.parseCsv(csv, varToId, nowUtc: now);
      expect(out['birch']!.length, 2);
      expect(out['birch']![0].peak, 9.0);
      expect(out['grass']![0].peak, 4.0);
    });

    test('keeps only the lowest altitude when multiple levels present', () {
      const csv = '''
time,alt[unit="m"],station,lat,lon,cnc_POLLEN_BIRCH_m22[unit="number/m3"]
2026-06-01T00:00:00Z,12.5,GP,60,24,5.0
2026-06-01T00:00:00Z,50.0,GP,60,24,20.0
2026-06-01T01:00:00Z,12.5,GP,60,24,7.0''';
      final out = SilamSource.parseCsv(csv, {'cnc_POLLEN_BIRCH_m22': 'birch'},
          nowUtc: now);
      expect(out['birch']![0].peak, 7.0); // ignores the 20.0 at 50 m
    });

    test('drops rows before the cutoff day', () {
      const csv = '''
time,station,lat,lon,cnc_POLLEN_BIRCH_m22[unit="number/m3"]
2026-05-30T00:00:00Z,GP,60,24,99.0
2026-06-01T00:00:00Z,GP,60,24,3.0''';
      final out = SilamSource.parseCsv(csv, {'cnc_POLLEN_BIRCH_m22': 'birch'},
          nowUtc: now);
      expect(out['birch']!.length, 1);
      expect(out['birch']![0].peak, 3.0);
    });

    test('handles empty/garbage body gracefully', () {
      expect(SilamSource.parseCsv('', varToId, nowUtc: now), isEmpty);
      expect(SilamSource.parseCsv('only,a,header\n', varToId, nowUtc: now), isEmpty);
    });
  });
}
