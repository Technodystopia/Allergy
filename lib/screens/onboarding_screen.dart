import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../widgets.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final allergens = state.catalog.allergens
        .where((a) => a.relevanceFi != 'none') // hide olive by default
        .toList();

    return Scaffold(
      appBar: AppBar(title: Text(s.onboardTitle)),
      body: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.onboardBody),
          ),
          ...allergens.map((a) {
            final selected = state.selectedIds.contains(a.id);
            return Card(
              child: CheckboxListTile(
                value: selected,
                onChanged: (_) => state.toggleAllergen(a.id),
                title: Row(
                  children: [
                    Text(a.emoji, style: const TextStyle(fontSize: 20)),
                    const SizedBox(width: 8),
                    Text(s.allergenName(a)),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: RelevanceChip(a.relevanceFi),
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: FilledButton(
              onPressed: state.selectedIds.isEmpty
                  ? null
                  : () => state.completeOnboarding(),
              child: Text(s.continueLabel),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
