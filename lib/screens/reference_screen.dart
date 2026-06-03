import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_state.dart';
import '../models.dart';
import '../widgets.dart';

class ReferenceScreen extends StatelessWidget {
  const ReferenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    return ListView(
      padding: const EdgeInsets.all(8),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(s.refHeader),
        ),
        ...state.catalog.allergens.map((a) {
          final selected = state.selectedIds.contains(a.id);
          return Card(
            child: ListTile(
              leading: Text(a.emoji, style: const TextStyle(fontSize: 26)),
              title: Text(s.allergenName(a)),
              subtitle: Text(a.scientificName,
                  style: const TextStyle(fontStyle: FontStyle.italic)),
              trailing: IconButton(
                icon: Icon(selected ? Icons.star : Icons.star_border,
                    color: selected ? Colors.amber : null),
                onPressed: () => state.toggleAllergen(a.id),
              ),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AllergenDetailScreen(allergen: a)),
              ),
            ),
          );
        }),
        if (state.catalog.references.isNotEmpty) ...[
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
            child: Text(s.sources,
                style: Theme.of(context).textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 2, 12, 8),
            child: Text(s.sourcesSub,
                style: Theme.of(context).textTheme.bodySmall),
          ),
          ...state.catalog.references.map((r) => Card(
                child: ListTile(
                  dense: true,
                  leading: const Icon(Icons.link),
                  title: Text(r.title),
                  trailing: const Icon(Icons.open_in_new, size: 18),
                  onTap: () => launchUrl(Uri.parse(r.url),
                      mode: LaunchMode.externalApplication),
                ),
              )),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class AllergenDetailScreen extends StatelessWidget {
  final Allergen allergen;
  const AllergenDetailScreen({super.key, required this.allergen});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final a = allergen;
    final selected = state.selectedIds.contains(a.id);
    final t = a.thresholds;

    return Scaffold(
      appBar: AppBar(title: Text('${a.emoji}  ${s.isFi ? a.nameFi : a.nameEn}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(s.isFi ? a.nameEn : a.nameFi,
              style: Theme.of(context).textTheme.headlineSmall),
          Text('${a.scientificName} · ${a.family}',
              style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          const SizedBox(height: 8),
          RelevanceChip(a.relevanceFi),
          const SizedBox(height: 16),
          Text(a.localizedDescription(s.isFi)),
          const SizedBox(height: 20),
          _section(context, s.crossPollen),
          if (a.crossReactions.pollen.isEmpty)
            Text(s.noneNoted)
          else
            Wrap(
              spacing: 6,
              children: a.crossReactions.pollen
                  .map((id) => Chip(label: Text(s.allergenName(state.catalog.byId(id)))))
                  .toList(),
            ),
          const SizedBox(height: 16),
          _section(context, s.crossFoods),
          if (a.crossReactions.foods.isEmpty)
            Text(s.noneNoted)
          else
            Wrap(
              spacing: 6,
              runSpacing: 2,
              children: a.crossReactions.foods
                  .map((f) => Chip(
                        label: Text(s.food(f)),
                        visualDensity: VisualDensity.compact,
                      ))
                  .toList(),
            ),
          if (a.kasviatlasUrl != null) ...[
            const SizedBox(height: 8),
            AtlasLinkButton(a),
          ],
          const SizedBox(height: 16),
          _section(context, s.severityScale),
          _thresholdRow(s.level(PollenLevel.low), '${t.low.round()}+', PollenLevel.low),
          _thresholdRow(s.level(PollenLevel.moderate), '${t.moderate.round()}+', PollenLevel.moderate),
          _thresholdRow(s.level(PollenLevel.high), '${t.high.round()}+', PollenLevel.high),
          _thresholdRow(s.level(PollenLevel.veryHigh), '${t.veryHigh.round()}+', PollenLevel.veryHigh),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => state.toggleAllergen(a.id),
            icon: Icon(selected ? Icons.remove_circle_outline : Icons.add),
            label: Text(selected ? s.removeAllergen : s.addAllergen),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _thresholdRow(String label, String value, PollenLevel level) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Container(width: 14, height: 14, color: level.color),
            const SizedBox(width: 8),
            Expanded(child: Text(label)),
            Text(value),
          ],
        ),
      );
}
