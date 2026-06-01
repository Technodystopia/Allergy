import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models.dart';

/// Base WMS URL for the SILAM pollen dataset (ncWMS / EDAL server).
const _silamWmsBase =
    'https://thredds.silam.fmi.fi/thredds/wms/silam_europe_pollen_v6_1/silam_europe_pollen_v6_1_best.ncd?';

/// A live SILAM pollen map: an OSM base layer with the SILAM concentration
/// cloud for the chosen allergen overlaid as a WMS tile layer.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _controller = MapController();
  String? _allergenId;

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

  String _legendUrl(Allergen a) =>
      '${_silamWmsBase}request=GetLegendGraphic&layer=${a.silamVar}'
      '&colorscalerange=${_scaleRange(a)}&logscale=true&palette=default'
      '&numcolorbands=100&width=30&height=180&vertical=true';

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
                    label: Text('${a.emoji} ${s.allergenName(a).split(' · ').first}'),
                    selected: a.id == active.id,
                    onSelected: (_) => setState(() => _allergenId = a.id),
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
                  // SILAM pollen overlay — keyed by layer so it reloads on switch.
                  Opacity(
                    opacity: 0.7,
                    child: TileLayer(
                      key: ValueKey('silam-${active.silamVar}'),
                      wmsOptions: WMSTileLayerOptions(
                        baseUrl: _silamWmsBase,
                        layers: [active.silamVar!],
                        styles: const ['default-scalar/default'],
                        format: 'image/png',
                        transparent: true,
                        version: '1.3.0',
                        otherParameters: {
                          'COLORSCALERANGE': _scaleRange(active),
                          'LOGSCALE': 'true',
                          'NUMCOLORBANDS': '100',
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
              // Legend.
              Positioned(
                left: 12,
                top: 12,
                child: _Legend(
                  url: _legendUrl(active),
                  lowLabel: active.thresholds.low.toStringAsFixed(0),
                  highLabel: active.thresholds.veryHigh.toStringAsFixed(0),
                  unit: s.mapLegend,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final String url, lowLabel, highLabel, unit;
  const _Legend({
    required this.url,
    required this.lowLabel,
    required this.highLabel,
    required this.unit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(unit, style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 2),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.network(
                  url,
                  width: 30,
                  height: 120,
                  fit: BoxFit.fill,
                  errorBuilder: (_, e, st) =>
                      const SizedBox(width: 30, height: 120),
                ),
                const SizedBox(width: 4),
                SizedBox(
                  height: 120,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(highLabel,
                          style: Theme.of(context).textTheme.labelSmall),
                      Text(lowLabel,
                          style: Theme.of(context).textTheme.labelSmall),
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
