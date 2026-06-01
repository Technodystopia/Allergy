import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_state.dart';
import 'background.dart';
import 'location_service.dart';
import 'notification_service.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  final catalog = await Catalog.load();
  final prefs = await SharedPreferences.getInstance();
  final background = BackgroundService();
  await background.init();
  final state = AppState(
    catalog: catalog,
    sources: [OpenMeteoSource(), SilamSource()],
    prefs: prefs,
    locationService: LocationService(),
    notifications: NotificationService(),
    background: background,
  );
  runApp(AllergyApp(state: state));
}

class AllergyApp extends StatelessWidget {
  final AppState state;
  const AllergyApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: state,
      child: MaterialApp(
        title: 'Siitepöly · Pollen FI',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF2E7D32),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF2E7D32),
          brightness: Brightness.dark,
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    final onboarded = context.select<AppState, bool>((s) => s.onboarded);
    return onboarded ? const HomeShell() : const OnboardingScreen();
  }
}
