import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'models.dart';

/// "View local growth atlas" link → kasviatlas.fi distribution maps for the
/// taxon. Renders nothing if the allergen has no atlas key.
class AtlasLinkButton extends StatelessWidget {
  final Allergen allergen;
  const AtlasLinkButton(this.allergen, {super.key});

  @override
  Widget build(BuildContext context) {
    final url = allergen.kasviatlasUrl;
    if (url == null) return const SizedBox.shrink();
    final s = context.watch<AppState>().s;
    return TextButton.icon(
      icon: const Icon(Icons.public, size: 18),
      label: Text(s.viewAtlas),
      onPressed: () => launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication),
    );
  }
}

/// Small coloured pill showing a pollen level (localised).
class LevelBadge extends StatelessWidget {
  final PollenLevel level;
  final bool estimated;
  const LevelBadge(this.level, {super.key, this.estimated = false});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: estimated ? 0.45 : 1.0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estimated ? '${s.level(level)}${s.estSuffix}' : s.level(level),
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}

/// A colour-coded dot with the level's rank number inside (0–4) — the
/// at-a-glance "green = fine, red = stay in" indicator. Reused on the Today
/// summary, the day-grid and the widget.
class LevelDot extends StatelessWidget {
  final PollenLevel level;
  final double size;
  final bool estimated;
  const LevelDot(this.level, {super.key, this.size = 28, this.estimated = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: level.color.withValues(alpha: estimated ? 0.45 : 1.0),
        shape: BoxShape.circle,
      ),
      child: Text(
        '${level.rank}',
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: size * 0.5,
        ),
      ),
    );
  }
}

/// Maps a WMO weather code to a Material icon.
IconData weatherIcon(int code) {
  if (code == 0) return Icons.wb_sunny;
  if (code <= 2) return Icons.wb_cloudy;
  if (code == 3) return Icons.cloud;
  if (code <= 48) return Icons.foggy;
  if (code <= 67) return Icons.water_drop;
  if (code <= 77) return Icons.ac_unit;
  if (code <= 82) return Icons.grain;
  if (code <= 86) return Icons.ac_unit;
  return Icons.thunderstorm;
}

/// Compact weather readout: icon, current temp, and today's hi/lo.
class WeatherGlance extends StatelessWidget {
  final Weather weather;
  const WeatherGlance(this.weather, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    final today = weather.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(weatherIcon(weather.code), size: 28),
        const SizedBox(height: 2),
        Text('${weather.tempC.round()}°',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        if (today != null)
          Text('${today.max.round()}° / ${today.min.round()}°',
              style: Theme.of(context).textTheme.bodySmall),
        Text(s.weatherLabel(weather.code),
            style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

/// Relevance chip for the Finnish context (very_high … none).
class RelevanceChip extends StatelessWidget {
  final String relevance;
  const RelevanceChip(this.relevance, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppState>().s;
    return Chip(
      label: Text(s.relevance(relevance), style: const TextStyle(fontSize: 11)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
