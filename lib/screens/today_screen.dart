import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../models.dart';
import '../services.dart';
import '../widgets.dart';

/// Human-friendly "x ago" for a timestamp.
String _ago(DateTime? t, L10n s) {
  if (t == null) return s.justNow;
  final d = DateTime.now().difference(t);
  if (d.inMinutes < 1) return s.justNow;
  if (d.inMinutes < 60) return s.minAgo(d.inMinutes);
  if (d.inHours < 24) return s.hAgo(d.inHours);
  return s.dAgo(d.inDays);
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final allergens = state.selectedAllergens;

    if (allergens.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.noAllergens, textAlign: TextAlign.center),
        ),
      );
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Worst level across all selected allergens for today.
    PollenLevel worst = PollenLevel.none;
    Allergen? worstAllergen;
    for (final a in allergens) {
      final series = Seasonal.sevenDaySeries(
          allergen: a, live: state.forecastFor(a.id), today: today);
      final lvl = a.thresholds.levelFor(series[0].peak);
      if (lvl.rank >= worst.rank) {
        worst = lvl;
        worstAllergen = a;
      }
    }

    return RefreshIndicator(
      onRefresh: state.refresh,
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          if (state.loading)
            const LinearProgressIndicator(),
          _SummaryBanner(
              level: worst,
              location: state.currentLocation.nameFi,
              driver: worstAllergen),
          if (state.error != null)
            Card(
              color: state.usingCache
                  ? Theme.of(context).colorScheme.secondaryContainer
                  : Theme.of(context).colorScheme.errorContainer,
              child: ListTile(
                leading:
                    Icon(state.usingCache ? Icons.history : Icons.cloud_off),
                title: Text(state.usingCache ? s.offlineTitle : s.errorTitle),
                subtitle: Text(state.usingCache
                    ? s.offlineUpdated(_ago(state.lastUpdated, s))
                    : s.errorEstimates),
                trailing: TextButton(
                  onPressed: state.refresh,
                  child: Text(s.retry),
                ),
              ),
            ),
          ...allergens.map((a) => _AllergenCard(allergen: a)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              '${s.source(state.currentSource.attribution)}'
              '${state.lastUpdated != null ? '  ·  ${s.updated} ${_ago(state.lastUpdated, s)}' : ''}',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final PollenLevel level;
  final String location;
  final Allergen? driver;
  const _SummaryBanner(
      {required this.level, required this.location, this.driver});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final headline = level == PollenLevel.none
        ? s.noNotable
        : s.summaryHeadline(
            s.level(level), driver != null ? s.allergenName(driver!) : null);
    return Card(
      color: level.color.withValues(alpha: 0.18),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 44,
              decoration: BoxDecoration(
                color: level.color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(location,
                      style: Theme.of(context).textTheme.labelMedium),
                  Text(headline,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(s.levelAdvice(level),
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllergenCard extends StatefulWidget {
  final Allergen allergen;
  const _AllergenCard({required this.allergen});

  @override
  State<_AllergenCard> createState() => _AllergenCardState();
}

class _AllergenCardState extends State<_AllergenCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.allergen;
    final state = context.watch<AppState>();
    final s = state.s;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final series = Seasonal.sevenDaySeries(
      allergen: a,
      live: state.forecastFor(a.id),
      today: today,
    );
    final todayD = series[0];
    final tomorrowD = series[1];
    final stage = Seasonal.stageFor(a, today);
    final todayLevel = a.thresholds.levelFor(todayD.peak);

    return Card(
      color: todayLevel == PollenLevel.none
          ? null
          : todayLevel.color.withValues(alpha: 0.10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: Text(a.emoji, style: const TextStyle(fontSize: 28)),
            title: Text(s.allergenName(a)),
            subtitle: Text('${s.stageLabel(stage)} — ${s.stageDesc(stage)}'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _DayCell(label: s.todayLabel, day: todayD, allergen: a)),
                Expanded(child: _DayCell(label: s.tomorrow, day: tomorrowD, allergen: a)),
              ],
            ),
          ),
          if (todayD.hours.isNotEmpty && todayD.lowestDaytimeHour != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${s.lowestAround(todayD.lowestDaytimeHour!)}'
                      '${todayD.peakHour != null ? ' · ${s.peaksAround(todayD.peakHour!)}' : ''}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          TextButton.icon(
            onPressed: () => setState(() => _expanded = !_expanded),
            icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more),
            label: Text(_expanded ? s.showLess : s.show7),
          ),
          if (_expanded) ...[
            if (todayD.hours.length >= 4) _HourlyBars(day: todayD, allergen: a),
            _SevenDay(series: series, allergen: a),
          ],
        ],
      ),
    );
  }
}

/// A compact 24-hour bar strip for one day, coloured by level, with the
/// lowest daytime hour highlighted.
class _HourlyBars extends StatelessWidget {
  final DailyPollen day;
  final Allergen allergen;
  const _HourlyBars({required this.day, required this.allergen});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final maxV = day.hours.fold<double>(
        allergen.thresholds.low, (m, h) => h.value > m ? h.value : m);
    final lowHour = day.lowestDaytimeHour;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.todayByHour, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          SizedBox(
            height: 48,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: day.hours.map((h) {
                final lvl = allergen.thresholds.levelFor(h.value);
                final frac = maxV > 0 ? (h.value / maxV).clamp(0.06, 1.0) : 0.06;
                final isLow = h.hour == lowHour;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: 40 * frac,
                          decoration: BoxDecoration(
                            color: lvl.color,
                            borderRadius: BorderRadius.circular(2),
                            border: isLow
                                ? Border.all(color: Colors.black87, width: 1.5)
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: _HourAxis(count: day.hours.length),
          ),
        ],
      ),
    );
  }
}

class _HourAxis extends StatelessWidget {
  final int count;
  const _HourAxis({this.count = 24});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(count, (i) {
        final label = (i == 0 || i == 6 || i == 12 || i == 18) ? '$i' : '';
        return Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 9, color: Colors.grey)),
        );
      }),
    );
  }
}

class _DayCell extends StatelessWidget {
  final String label;
  final DailyPollen day;
  final Allergen allergen;
  const _DayCell({required this.label, required this.day, required this.allergen});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final level = allergen.thresholds.levelFor(day.peak);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 4),
        LevelBadge(level, estimated: day.estimated),
        const SizedBox(height: 4),
        Text(s.grains(day.peak.round()),
            style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _SevenDay extends StatelessWidget {
  final List<DailyPollen> series;
  final Allergen allergen;
  const _SevenDay({required this.series, required this.allergen});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final df = DateFormat('EEE d', s.isFi ? 'fi' : 'en');
    final maxY = series.fold<double>(allergen.thresholds.moderate,
            (m, d) => d.peak > m ? d.peak : m) *
        1.2;

    final spots = [
      for (var i = 0; i < series.length; i++)
        FlSpot(i.toDouble(), series[i].peak),
    ];
    final hasEstimate = series.any((d) => d.estimated);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY,
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: true, reservedSize: 36)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        final i = value.round();
                        if (i < 0 || i >= series.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(df.format(series[i].date),
                              style: const TextStyle(fontSize: 10)),
                        );
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    barWidth: 3,
                    color: allergen.thresholds.levelFor(series[0].peak).color,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        final d = series[spot.x.round()];
                        final lvl = allergen.thresholds.levelFor(d.peak);
                        return FlDotCirclePainter(
                          radius: 4,
                          color: d.estimated
                              ? lvl.color.withValues(alpha: 0.4)
                              : lvl.color,
                          strokeWidth: 0,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: allergen.thresholds
                          .levelFor(series[0].peak)
                          .color
                          .withValues(alpha: 0.12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (hasEstimate)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                s.estimateNote,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
