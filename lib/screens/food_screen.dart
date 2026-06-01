import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

/// Personal food-intolerance catalogue, built from the OAS cross-reaction
/// foods in the bundled data. Flag a food ("I react to this") and add a note
/// for the exceptions that are still fine.
class FoodCatalogScreen extends StatelessWidget {
  const FoodCatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;

    // Unique cross-reaction foods → the allergens they cross-react with.
    final foods = <String, List<Allergen>>{};
    for (final a in state.catalog.allergens) {
      for (final f in a.crossReactions.foods) {
        foods.putIfAbsent(f, () => []).add(a);
      }
    }

    // Flagged first, then alphabetical by localised name.
    final keys = foods.keys.toList()
      ..sort((a, b) {
        final fa = state.isFoodFlagged(a), fb = state.isFoodFlagged(b);
        if (fa != fb) return fa ? -1 : 1;
        return s.food(a).toLowerCase().compareTo(s.food(b).toLowerCase());
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
                ...keys.map((f) => _FoodTile(
                      food: f,
                      pollens: foods[f]!,
                    )),
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
    final flagged = state.isFoodFlagged(food);
    final note = state.foodNote(food);
    final pollenNames =
        pollens.map((a) => s.allergenName(a).split(' · ').first).join(', ');

    final subtitle = flagged
        ? (note.isNotEmpty ? note : s.foodAvoid)
        : s.foodCrossWith(pollenNames);

    return Card(
      color: flagged
          ? Theme.of(context).colorScheme.secondaryContainer
          : null,
      child: ListTile(
        leading: Checkbox(
          value: flagged,
          onChanged: (_) => state.toggleFood(food),
        ),
        title: Text(s.food(food)),
        subtitle: Text(subtitle,
            style: TextStyle(
                fontStyle: flagged && note.isNotEmpty
                    ? FontStyle.normal
                    : FontStyle.italic)),
        isThreeLine: flagged && note.isNotEmpty,
        trailing: flagged
            ? IconButton(
                icon: const Icon(Icons.edit_note),
                tooltip: s.foodNoteHint,
                onPressed: () => _editNote(context, state, food),
              )
            : null,
        onTap: () => state.toggleFood(food),
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
