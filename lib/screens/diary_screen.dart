import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets.dart';
import 'food_screen.dart';

/// Colours for the 4 severity levels (green → red).
const _sevColors = [
  Color(0xFF43A047),
  Color(0xFFFBC02D),
  Color(0xFFFB8C00),
  Color(0xFFE53935),
];

/// The Diary tab is a personal hub: everything "about me", click-to-open.
class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;

    Widget tile(IconData icon, String title, String sub, Widget screen,
            {String? trailing}) =>
        Card(
          child: ListTile(
            leading: Icon(icon),
            title: Text(title),
            subtitle: Text(sub),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (trailing != null)
                  Text(trailing,
                      style: Theme.of(context).textTheme.labelLarge),
                const Icon(Icons.chevron_right),
              ],
            ),
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => screen)),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        tile(Icons.spa_outlined, s.myAllergens, s.myAllergensSub,
            const MyAllergensScreen(),
            trailing: '${state.selectedIds.length}'),
        tile(Icons.restaurant_menu, s.foodCatalogTitle, s.crossReactionsSub,
            const FoodCatalogScreen(),
            trailing: '${state.flaggedFoods.length}'),
        tile(Icons.event_note, s.symptomDiary, s.symptomDiarySub,
            const DailyTrackerScreen(),
            trailing: '${state.diary.length}'),
      ],
    );
  }
}

/// Day-by-day symptom log (the original diary), now reached from the hub.
class DailyTrackerScreen extends StatelessWidget {
  const DailyTrackerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final entries = state.diary;

    return Scaffold(
      appBar: AppBar(title: Text(s.symptomDiary)),
      body: Column(
        children: [
          const _DiaryGlance(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.diaryHeader),
          ),
          if (entries.isEmpty)
            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(s.diaryEmpty, textAlign: TextAlign.center),
                ),
              ),
            )
          else
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                children: entries.map((e) => _EntryCard(entry: e)).toList(),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showLogSheet(context, state),
        icon: const Icon(Icons.add),
        label: Text(s.logToday),
      ),
    );
  }
}

/// Today's pollen and weather, side by side — the quick "what does today look
/// like" glance at the top of the diary.
class _DiaryGlance extends StatelessWidget {
  const _DiaryGlance();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final worst = state.worstToday();
    final level = worst?.level ?? PollenLevel.none;
    final weather = state.weather;

    return Card(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Pollen side.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(s.pollenWord,
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  LevelDot(level, size: 40),
                  const SizedBox(height: 4),
                  Text(
                    worst == null
                        ? s.level(PollenLevel.none)
                        : '${s.level(level)} · ${s.allergenName(worst.allergen).split(' · ').first}',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(
                height: 70, child: VerticalDivider(width: 24)),
            // Weather side.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(s.weatherWord,
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  if (weather != null)
                    WeatherGlance(weather)
                  else
                    const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.cloud_off, size: 24),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showLogSheet(BuildContext context, AppState state) {
  final s = state.s;
  final existing = state.todayEntry;
  int severity = existing?.severity ?? 1;
  final areas = {...?existing?.areas};
  final noteCtrl = TextEditingController(text: existing?.note ?? '');

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
        ),
        child: StatefulBuilder(
          builder: (ctx, setSheet) => SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(s.logTitle,
                          style: Theme.of(ctx).textTheme.titleLarge),
                    ),
                    if (state.lastLoggedEntry != null)
                      TextButton.icon(
                        icon: const Icon(Icons.history, size: 18),
                        label: Text(s.copyYesterday),
                        onPressed: () => setSheet(() {
                          final last = state.lastLoggedEntry!;
                          severity = last.severity;
                          areas
                            ..clear()
                            ..addAll(last.areas);
                          noteCtrl.text = last.note;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: List.generate(4, (i) {
                    final selected = severity == i;
                    return ChoiceChip(
                      label: Text(s.severity(i)),
                      selected: selected,
                      onSelected: (_) => setSheet(() => severity = i),
                      selectedColor: _sevColors[i].withValues(alpha: 0.35),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                Text(s.diaryAreasTitle,
                    style: Theme.of(ctx).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final id in state.enabledAreas)
                      FilterChip(
                        label: Text(s.area(id)),
                        selected: areas.contains(id),
                        onSelected: (on) => setSheet(() {
                          if (on) {
                            areas.add(id);
                          } else {
                            areas.remove(id);
                          }
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteCtrl,
                  decoration: InputDecoration(
                    labelText: s.noteHint,
                    border: const OutlineInputBorder(),
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () async {
                      await state.logToday(severity, noteCtrl.text.trim(),
                          areas: areas);
                      if (ctx.mounted) Navigator.of(ctx).pop();
                    },
                    child: Text(s.save),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _EntryCard extends StatelessWidget {
  final SymptomEntry entry;
  const _EntryCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final color = _sevColors[entry.severity.clamp(0, 3)];
    final pollen = (entry.pollenRank >= 0 &&
            entry.pollenRank < PollenLevel.values.length)
        ? s.pollenThatDay(s.level(PollenLevel.values[entry.pollenRank]))
        : s.pollenUnknown;
    final areaText = entry.areas.isEmpty
        ? null
        : kBodyAreas
            .where(entry.areas.contains)
            .map((a) => s.area(a))
            .join(' · ');
    final subtitle = [
      pollen,
      ?areaText,
      if (entry.note.isNotEmpty) entry.note,
    ].join('\n');

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 8,
        ),
        title: Text('${entry.dayKey} · ${s.severity(entry.severity)}'),
        subtitle: Text(subtitle),
        isThreeLine: areaText != null || entry.note.isNotEmpty,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: s.delete,
          onPressed: () => state.deleteDiaryEntry(entry.dayKey),
        ),
      ),
    );
  }
}

/// The allergens you track — toggle which pollens are "yours".
class MyAllergensScreen extends StatelessWidget {
  const MyAllergensScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    return Scaffold(
      appBar: AppBar(title: Text(s.myAllergens)),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: state.catalog.allergens.map((a) {
          final selected = state.selectedIds.contains(a.id);
          return Card(
            child: ListTile(
              leading: Text(a.emoji, style: const TextStyle(fontSize: 26)),
              title: Text(s.allergenName(a)),
              subtitle: RelevanceChip(a.relevanceFi),
              trailing: IconButton(
                icon: Icon(selected ? Icons.star : Icons.star_border,
                    color: selected ? Colors.amber : null),
                tooltip: selected ? s.removeAllergen : s.addAllergen,
                onPressed: () => state.toggleAllergen(a.id),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
