import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

IconData _categoryIcon(String c) => switch (c) {
      'food' => Icons.restaurant,
      'medication' => Icons.medication_outlined,
      'animal' => Icons.pets,
      'environment' => Icons.eco_outlined,
      _ => Icons.help_outline,
    };

/// A free-form list of the user's non-pollen allergies (food, medicine,
/// animals, etc.) — kept in the diary, separate from tracked pollen.
class MyAllergiesScreen extends StatelessWidget {
  const MyAllergiesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final list = state.otherAllergies;

    return Scaffold(
      appBar: AppBar(title: Text(s.otherAllergiesTitle)),
      body: list.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child:
                    Text(s.otherAllergiesEmpty, textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (var i = 0; i < list.length; i++)
                  Card(
                    child: ListTile(
                      leading: Icon(_categoryIcon(list[i].category)),
                      title: Text(list[i].name),
                      subtitle: Text(list[i].note.isNotEmpty
                          ? '${s.allergyCategory(list[i].category)} · ${list[i].note}'
                          : s.allergyCategory(list[i].category)),
                      isThreeLine: list[i].note.length > 40,
                      onTap: () =>
                          _showSheet(context, state, index: i, existing: list[i]),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: s.delete,
                        onPressed: () => state.removeAllergy(i),
                      ),
                    ),
                  ),
                const SizedBox(height: 80),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showSheet(context, state),
        icon: const Icon(Icons.add),
        label: Text(s.addAllergyTitle),
      ),
    );
  }
}

void _showSheet(BuildContext context, AppState state,
    {int? index, OtherAllergy? existing}) {
  final s = state.s;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String category = existing?.category ?? 'food';

  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
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
              Text(s.addAllergyTitle,
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextField(
                controller: nameCtrl,
                autofocus: existing == null,
                decoration: InputDecoration(
                  labelText: s.allergyNameHint,
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in kAllergyCategories)
                    ChoiceChip(
                      avatar: Icon(_categoryIcon(c), size: 18),
                      label: Text(s.allergyCategory(c)),
                      selected: category == c,
                      onSelected: (_) => setSheet(() => category = c),
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
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final a = OtherAllergy(
                        name: name,
                        category: category,
                        note: noteCtrl.text.trim());
                    if (index != null) {
                      state.updateAllergy(index, a);
                    } else {
                      state.addAllergy(a);
                    }
                    Navigator.of(ctx).pop();
                  },
                  child: Text(s.save),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
