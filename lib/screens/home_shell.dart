import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import 'bloom_screen.dart';
import 'diary_screen.dart';
import 'locations_screen.dart';
import 'map_screen.dart';
import 'reference_screen.dart';
import 'settings_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // Load the forecast once the first frame is up.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppState>().refresh();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final titles = [s.today, s.bloom, s.map, s.diary, s.reference];
    final pages = const [
      TodayScreen(),
      BloomScreen(),
      MapScreen(),
      DiaryScreen(),
      ReferenceScreen()
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('${titles[_tab]} · ${state.currentLocation.nameFi}'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.satellite_alt_outlined),
            tooltip: s.tooltipSource,
            onSelected: state.setSource,
            itemBuilder: (_) => state.sources
                .map((s) => PopupMenuItem(
                      value: s.id,
                      child: Row(
                        children: [
                          Icon(
                            s.id == state.sourceId
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(s.label),
                        ],
                      ),
                    ))
                .toList(),
          ),
          if (state.favoriteIds.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.swap_horiz),
              tooltip: s.tooltipFavourite,
              onSelected: state.setCurrent,
              itemBuilder: (_) => state.favoriteIds
                  .map((id) => PopupMenuItem(
                        value: id,
                        child: Text(state.catalog.locationById(id).nameFi),
                      ))
                  .toList(),
            ),
          IconButton(
            icon: const Icon(Icons.place_outlined),
            tooltip: s.tooltipLocations,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationsScreen()),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: s.tooltipSettings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.today_outlined),
              selectedIcon: const Icon(Icons.today),
              label: s.today),
          NavigationDestination(
              icon: const Icon(Icons.timeline_outlined),
              selectedIcon: const Icon(Icons.timeline),
              label: s.bloom),
          NavigationDestination(
              icon: const Icon(Icons.map_outlined),
              selectedIcon: const Icon(Icons.map),
              label: s.map),
          NavigationDestination(
              icon: const Icon(Icons.event_note_outlined),
              selectedIcon: const Icon(Icons.event_note),
              label: s.diary),
          NavigationDestination(
              icon: const Icon(Icons.menu_book_outlined),
              selectedIcon: const Icon(Icons.menu_book),
              label: s.reference),
        ],
      ),
    );
  }
}
