import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

/// Colours for the 4 severity levels (green → red).
const _sevColors = [
  Color(0xFF43A047),
  Color(0xFFFBC02D),
  Color(0xFFFB8C00),
  Color(0xFFE53935),
];

class DiaryScreen extends StatelessWidget {
  const DiaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final entries = state.diary;

    return Scaffold(
      body: Column(
        children: [
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

void _showLogSheet(BuildContext context, AppState state) {
  final s = state.s;
  final existing = state.todayEntry;
  int severity = existing?.severity ?? 1;
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
          builder: (ctx, setSheet) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.logTitle, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
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
                    await state.logToday(severity, noteCtrl.text.trim());
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                  child: Text(s.save),
                ),
              ),
            ],
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

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color,
          radius: 8,
        ),
        title: Text('${entry.dayKey} · ${s.severity(entry.severity)}'),
        subtitle: Text(
            '$pollen${entry.note.isNotEmpty ? '\n${entry.note}' : ''}'),
        isThreeLine: entry.note.isNotEmpty,
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: s.delete,
          onPressed: () => state.deleteDiaryEntry(entry.dayKey),
        ),
      ),
    );
  }
}
