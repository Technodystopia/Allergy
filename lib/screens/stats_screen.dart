import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

// Time-of-day dot colours.
const _morningColor = Color(0xFFFFB300);
const _eveningColor = Color(0xFF5C6BC0);
const _dayColor = Color(0xFF90A4AE);

/// Yearly symptom-severity chart + a summary of known allergens and
/// cross-reactions — designed to show a doctor at a check-up.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  Color _partColor(String part) => switch (part) {
        'morning' => _morningColor,
        'evening' => _eveningColor,
        _ => _dayColor,
      };

  int _doy(DateTime d) => d.difference(DateTime(d.year, 1, 1)).inDays + 1;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final year = DateTime.now().year;

    final entries = state.diary.where((e) {
      final d = DateTime.tryParse(e.dayKey);
      return d != null && d.year == year;
    }).toList();

    // Month-start day-of-year → month number, for x-axis labels.
    final monthStart = <int, int>{
      for (var m = 1; m <= 12; m++) _doy(DateTime(year, m, 1)): m,
    };

    return Scaffold(
      appBar: AppBar(title: Text('${s.statsTitle} · $year')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.statsHeader, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Text(s.statsEmpty, textAlign: TextAlign.center),
            )
          else
            SizedBox(
              height: 240,
              child: ScatterChart(
                ScatterChartData(
                  minX: 1,
                  maxX: 366,
                  minY: -0.5,
                  maxY: 3.5,
                  scatterSpots: [
                    for (final e in entries)
                      ScatterSpot(
                        _doy(DateTime.parse(e.dayKey)).toDouble(),
                        e.severity.toDouble(),
                        dotPainter: FlDotCirclePainter(
                          color: _partColor(e.part),
                          radius: 5,
                        ),
                      ),
                  ],
                  gridData: const FlGridData(show: true, drawVerticalLine: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 40,
                        getTitlesWidget: (v, meta) {
                          final i = v.round();
                          if (i < 0 || i > 3 || (v - i).abs() > 0.01) {
                            return const SizedBox.shrink();
                          }
                          return Text(s.severity(i),
                              style: const TextStyle(fontSize: 9));
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: 1,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final m = monthStart[v.round()];
                          if (m == null) return const SizedBox.shrink();
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(s.monthAbbr(m),
                                style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          // Time-of-day legend.
          Wrap(spacing: 16, children: [
            _dot(context, _morningColor, s.dayPart('morning')),
            _dot(context, _eveningColor, s.dayPart('evening')),
          ]),
          const Divider(height: 32),
          Text(s.statsKnownAllergens,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 2,
            children: state.selectedAllergens.isEmpty
                ? [Text(s.statsNone)]
                : state.selectedAllergens
                    .map((a) => Chip(
                          label: Text(s.allergenName(a).split(' · ').first),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
          ),
          const SizedBox(height: 16),
          Text(s.statsKnownCross,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 6),
          if (state.flaggedFoods.isEmpty)
            Text(s.statsNone)
          else
            ...state.flaggedFoods.map((f) {
              final st = state.foodStatus(f);
              final note = state.foodNote(f);
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  st == FoodStatus.avoid
                      ? Icons.do_not_disturb_on
                      : Icons.warning_amber_rounded,
                  color: st == FoodStatus.avoid
                      ? const Color(0xFFE53935)
                      : const Color(0xFFFB8C00),
                  size: 20,
                ),
                title: Text(s.food(f)),
                subtitle: Text(
                  note.isNotEmpty
                      ? '${s.foodStatusLabel(st)} · $note'
                      : s.foodStatusLabel(st),
                ),
              );
            }),
          if (state.otherAllergies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(s.statsOtherAllergies,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 6),
            ...state.otherAllergies.map((a) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.warning_amber, size: 20),
                  title: Text(a.name),
                  subtitle: Text(a.note.isNotEmpty
                      ? '${s.allergyCategory(a.category)} · ${a.note}'
                      : s.allergyCategory(a.category)),
                )),
          ],
        ],
      ),
    );
  }

  Widget _dot(BuildContext context, Color c, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: Theme.of(context).textTheme.labelSmall),
        ],
      );
}
