import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../l10n.dart';
import '../models.dart';

/// Base WMS URL for the SILAM pollen dataset (ncWMS / EDAL server).
const _silamWmsBase =
    'https://thredds.silam.fmi.fi/thredds/wms/silam_europe_pollen_v6_1/silam_europe_pollen_v6_1_best.ncd?';

/// Sequential yellow→orange→red palette — reads intuitively as low→high.
const _palette = 'seq-YlOrRd';

/// How many forecast days the day-slider offers (SILAM forecasts ~5 days).
const _maxDayOffset = 4;

/// A live SILAM pollen map: an OSM base layer with the SILAM concentration
/// cloud for the chosen allergen overlaid as a WMS tile layer, scrubable by day.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();
  String? _allergenId;
  int _dayOffset = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Allergens the user selected that SILAM can actually map.
  List<Allergen> _mappable(AppState state) =>
      state.selectedAllergens.where((a) => a.silamVar != null).toList();

  /// Colour scale for the overlay: a log range from the allergen's "low"
  /// threshold up to its "very high" cut-off, so each taxon is scaled sensibly.
  String _scaleRange(Allergen a) {
    final low = a.thresholds.low.clamp(1, double.infinity);
    return '${low.toStringAsFixed(0)},${a.thresholds.veryHigh.toStringAsFixed(0)}';
  }

  /// WMS TIME value (UTC noon) for the chosen day offset.
  String _timeIso(int offset) {
    final n = DateTime.now();
    final d = DateTime(n.year, n.month, n.day + offset);
    String two(int x) => x.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}T12:00:00Z';
  }

  String _dayLabel(int offset, L10n s) {
    if (offset == 0) return s.todayLabel;
    if (offset == 1) return s.tomorrow;
    final d = DateTime.now().add(Duration(days: offset));
    return DateFormat.E(s.isFi ? 'fi' : 'en').format(d);
  }

  String _legendUrl(Allergen a) =>
      '${_silamWmsBase}request=GetLegendGraphic&layer=${a.silamVar}'
      '&colorscalerange=${_scaleRange(a)}&logscale=true&palette=$_palette'
      '&numcolorbands=100&width=24&height=130&vertical=true&colorbaronly=true';

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final s = state.s;
    final mappable = _mappable(state);

    if (mappable.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(s.mapNoSilam, textAlign: TextAlign.center),
        ),
      );
    }

    // Resolve the active allergen (default to the first mappable one).
    final active = mappable.firstWhere(
      (a) => a.id == _allergenId,
      orElse: () => mappable.first,
    );

    final loc = state.currentLocation;
    final here = LatLng(loc.lat, loc.lon);
    final timeIso = _timeIso(_dayOffset);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Text(s.mapHeader, style: Theme.of(context).textTheme.bodySmall),
        ),
        // Allergen chips.
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (final a in mappable)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label:
                        Text('${a.emoji} ${s.allergenName(a).split(' · ').first}'),
                    selected: a.id == active.id,
                    onSelected: (_) => setState(() => _allergenId = a.id),
                  ),
                ),
            ],
          ),
        ),
        // Day selector (time scrub).
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              for (var d = 0; d <= _maxDayOffset; d++)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(_dayLabel(d, s)),
                    selected: d == _dayOffset,
                    visualDensity: VisualDensity.compact,
                    onSelected: (_) => setState(() => _dayOffset = d),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              FlutterMap(
                mapController: _controller,
                options: MapOptions(
                  initialCenter: here,
                  initialZoom: 6,
                  minZoom: 3,
                  maxZoom: 11,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'fi.kamk.allergy',
                  ),
                  // SILAM pollen overlay — keyed by layer+time so it reloads
                  // when the allergen or the chosen day changes.
                  Opacity(
                    opacity: 0.7,
                    child: TileLayer(
                      key: ValueKey('silam-${active.silamVar}-$timeIso'),
                      wmsOptions: WMSTileLayerOptions(
                        baseUrl: _silamWmsBase,
                        layers: [active.silamVar!],
                        styles: const ['default-scalar/$_palette'],
                        format: 'image/png',
                        transparent: true,
                        version: '1.3.0',
                        otherParameters: {
                          'COLORSCALERANGE': _scaleRange(active),
                          'LOGSCALE': 'true',
                          'NUMCOLORBANDS': '100',
                          'TIME': timeIso,
                        },
                      ),
                      userAgentPackageName: 'fi.kamk.allergy',
                    ),
                  ),
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: here,
                        width: 40,
                        height: 40,
                        child: Tooltip(
                          message: loc.nameFi,
                          child: const Icon(Icons.location_on,
                              color: Colors.black, size: 36),
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap'),
                      TextSourceAttribution('SILAM · FMI'),
                    ],
                  ),
                ],
              ),
              // Recenter button.
              Positioned(
                right: 12,
                bottom: 12,
                child: FloatingActionButton.small(
                  heroTag: 'mapRecenter',
                  onPressed: () => _controller.move(here, 6),
                  child: const Icon(Icons.my_location),
                ),
              ),
              // Legend with severity thresholds.
              Positioned(
                left: 12,
                top: 12,
                child: _Legend(
                  url: _legendUrl(active),
                  thresholds: active.thresholds,
                  unit: s.mapLegend,
                  s: s,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Floating legend: the WMS colour bar annotated with our severity-class
/// thresholds (Low / Moderate / High / Very high) so "is *my* pollen high
/// here" reads at a glance.
class _Legend extends StatelessWidget {
  final String url, unit;
  final Thresholds thresholds;
  final L10n s;
  const _Legend({
    required this.url,
    required this.thresholds,
    required this.unit,
    required this.s,
  });

  static const _h = 130.0;

  /// Distance from the top of the bar for a grains value (log scale).
  double _top(double v) {
    final lo = thresholds.low <= 0 ? 1.0 : thresholds.low;
    final hi = thresholds.veryHigh;
    if (hi <= lo) return 0;
    final f = (math.log(v / lo) / math.log(hi / lo)).clamp(0.0, 1.0);
    return (1 - f) * _h;
  }

  @override
  Widget build(BuildContext context) {
    final ticks = <(double, PollenLevel)>[
      (thresholds.veryHigh, PollenLevel.veryHigh),
      (thresholds.high, PollenLevel.high),
      (thresholds.moderate, PollenLevel.moderate),
      (thresholds.low, PollenLevel.low),
    ];

    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(unit, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Image.network(
                  url,
                  width: 22,
                  height: _h,
                  fit: BoxFit.fill,
                  errorBuilder: (_, e, st) =>
                      const SizedBox(width: 22, height: _h),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  width: 64,
                  height: _h,
                  child: Stack(
                    children: [
                      for (final (value, level) in ticks)
                        Positioned(
                          top: (_top(value) - 7).clamp(0.0, _h - 12),
                          left: 0,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                    color: level.color,
                                    shape: BoxShape.circle),
                              ),
                              const SizedBox(width: 3),
                              Text(value.toStringAsFixed(0),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
