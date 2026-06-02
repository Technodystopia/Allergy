import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

const _cautionColor = Color(0xFFFB8C00); // orange — test with caution
const _avoidColor = Color(0xFFE53935); // red — avoid

/// Personal cross-reaction catalogue, built from the OAS cross-reaction foods
/// in the bundled data. Each food cycles none → test-with-caution → avoid,
/// with a note for the exceptions that are still fine.
class FoodCatalogScreen extends StatelessWidget {
  const FoodCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;

    final foods = <String, List<Allergen>>{};
    for (final a in state.catalog.allergens) {
      for (final f in a.crossReactions.foods) {
        foods.putIfAbsent(f, () => []).add(a);
      }
    }

    // Avoid first, then caution, then untracked; alphabetical within each.
    int rank(String f) => switch (state.foodStatus(f)) {
          FoodStatus.avoid => 0,
          FoodStatus.caution => 1,
          FoodStatus.none => 2,
        };
    final keys = foods.keys.toList()
      ..sort((a, b) {
        final r = rank(a).compareTo(rank(b));
        return r != 0
            ? r
            : s.food(a).toLowerCase().compareTo(s.food(b).toLowerCase());
      });

    return Scaffold(
      appBar: AppBar(title: Text(s.foodCatalogTitle)),
      body: keys.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(s.foodEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(s.foodCatalogHeader,
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                ...keys
                    .map((f) => _FoodTile(food: f, pollens: foods[f]!)),
                const SizedBox(height: 24),
              ],
            ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  final String food;
  final List<Allergen> pollens;
  const _FoodTile({required this.food, required this.pollens});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final status = state.foodStatus(food);
    final note = state.foodNote(food);
    final pollenNames =
        pollens.map((a) => s.allergenName(a).split(' · ').first).join(', ');

    final (IconData icon, Color? color) = switch (status) {
      FoodStatus.avoid => (Icons.do_not_disturb_on, _avoidColor),
      FoodStatus.caution => (Icons.warning_amber_rounded, _cautionColor),
      FoodStatus.none => (Icons.radio_button_unchecked, null),
    };

    return Card(
      color: color?.withValues(alpha: 0.14),
      child: ListTile(
        leading: IconButton(
          icon: Icon(icon, color: color ?? Colors.grey),
          tooltip: s.foodStatusLabel(status),
          onPressed: () => state.cycleFood(food),
        ),
        title: Text(s.food(food)),
        // Line 1 always says what it cross-reacts with (+ your tag); line 2 is
        // your note, so you remember why you tagged it.
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(TextSpan(children: [
              TextSpan(text: s.foodCrossWith(pollenNames)),
              if (status != FoodStatus.none)
                TextSpan(
                  text: '  ·  ${s.foodStatusLabel(status)}',
                  style: TextStyle(
                      color: color, fontWeight: FontWeight.w600),
                ),
            ])),
            if (note.isNotEmpty)
              Text(note,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
          ],
        ),
        isThreeLine: status != FoodStatus.none && note.isNotEmpty,
        trailing: status == FoodStatus.none
            ? null
            : IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: s.foodNoteHint,
                onPressed: () => _editNote(context, state, food),
              ),
        onTap: () => state.cycleFood(food),
      ),
    );
  }
}

void _editNote(BuildContext context, AppState state, String food) {
  final s = state.s;
  final ctrl = TextEditingController(text: state.foodNote(food));
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.food(food)),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        decoration: InputDecoration(
          labelText: s.foodNoteHint,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () {
            state.setFoodNote(food, ctrl.text.trim());
            Navigator.of(ctx).pop();
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}
