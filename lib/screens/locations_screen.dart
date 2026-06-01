import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';

class LocationsScreen extends StatelessWidget {
  const LocationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final locations = state.catalog.locations;

    return Scaffold(
      appBar: AppBar(title: Text(s.locations)),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(s.locHeader),
          ),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              selected: state.currentId == 'gps',
              leading: state.locating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.my_location),
              title: Text(s.useMyLocation),
              subtitle: Text(state.gpsLocation != null
                  ? s.current(state.gpsLocation!.nameFi)
                  : s.useMyLocationSub),
              onTap: state.locating
                  ? null
                  : () async {
                      final err = await state.useMyLocation();
                      if (!context.mounted) return;
                      if (err != null) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(err)));
                      } else {
                        Navigator.of(context).maybePop();
                      }
                    },
            ),
          ),
          const Divider(),
          ...locations.map((l) {
            final isHome = state.homeId == l.id;
            final isFav = state.favoriteIds.contains(l.id);
            final isCurrent = state.currentId == l.id;
            return ListTile(
              selected: isCurrent,
              leading: Icon(isHome ? Icons.home : Icons.location_on_outlined),
              title: Text(l.nameFi),
              subtitle: Text(l.region + (l.capitalRegion ? ' · ${s.capitalRegion}' : '')),
              onTap: () {
                state.setCurrent(l.id);
                Navigator.of(context).maybePop();
              },
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: s.setHome,
                    icon: Icon(isHome ? Icons.home : Icons.home_outlined,
                        color: isHome ? Theme.of(context).colorScheme.primary : null),
                    onPressed: () => state.setHome(l.id),
                  ),
                  IconButton(
                    tooltip: s.favourite,
                    icon: Icon(isFav ? Icons.star : Icons.star_border,
                        color: isFav ? Colors.amber : null),
                    onPressed: () => state.toggleFavorite(l.id),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
