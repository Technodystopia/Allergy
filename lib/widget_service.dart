import 'package:flutter/services.dart';

import 'l10n.dart';
import 'models.dart';

/// Pushes the current "worst pollen today" snapshot to the Android home-screen
/// widget via a platform channel. The native side stores the values and asks
/// the AppWidgetManager to redraw. Failures (e.g. iOS, or no channel) are
/// swallowed — the widget is a nice-to-have, never load-bearing.
class WidgetService {
  static const _channel = MethodChannel('fi.kamk.allergy/widget');

  Future<void> update({
    required String location,
    required ({Allergen allergen, PollenLevel level})? worst,
    required L10n s,
  }) async {
    try {
      final level = worst?.level ?? PollenLevel.none;
      final levelText = worst == null ? s.noNotable : s.level(level);
      final allergenText =
          worst == null ? '' : s.allergenName(worst.allergen).split(' · ').first;

      await _channel.invokeMethod<void>('update', {
        'location': location,
        'level': levelText,
        'allergen': allergenText,
        'updated': '${s.updated} ${_hhmm(DateTime.now())}',
        'color': level.color.toARGB32(),
        'rank': level.rank,
      });
    } catch (_) {
      // No widget / unsupported platform — ignore.
    }
  }

  /// Asks the launcher to pin our widget to the home screen (Android 8+).
  /// Returns true if the request was issued.
  Future<bool> pinWidget() async {
    try {
      final ok = await _channel.invokeMethod<bool>('pin');
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
