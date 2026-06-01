# Siitepöly · Pollen FI

A Flutter pollen-allergy app for Finland (Helsinki capital region focus).

## Features
- **Pick your allergens** — onboarding selection, persisted; everything else filters to these.
- **Today / Tomorrow forecast** per allergen, with a per-taxon Finnish severity scale.
- **7-day view** ("Show 7 days") — live model for ~4 days + seasonal estimate for days 5–7 (clearly labelled).
- **Bloom timeline** — flowering season bar per allergen with a "where we are now" marker.
- **Reference** — plant specs, cross-reacting pollens, and oral-allergy-syndrome foods.
- **Locations** — home base 🏠 + starred favourites, quick switching.

## Data sources
- **Live forecast:** [Open-Meteo Air-Quality API](https://open-meteo.com/en/docs/air-quality-api)
  (CAMS European model) — free, no API key, hourly per-allergen grains/m³, ~4-day pollen forecast.
- **Thresholds / seasons / cross-reactions:** bundled in `assets/data/allergens.json`
  (Finnish aerobiology scale, Univ. of Turku / Norkko). No medical advice.
- Possible upgrade: official **SILAM** model (FMI, `silam.fmi.fi`, NetCDF/THREDDS) for an
  "authoritative Finnish source" toggle.

## Project layout
```
assets/data/        allergens.json, locations.json   (bundled reference data)
lib/
  models.dart       Allergen, Thresholds, Season, PollenLevel, DailyPollen, BloomStage
  services.dart     Catalog (asset loader) · PollenApi (Open-Meteo) · Seasonal (bloom + estimates)
  app_state.dart    ChangeNotifier: selection, locations, forecast (persisted via prefs)
  screens/          onboarding · home_shell · today · bloom · reference · locations
  widgets.dart      LevelBadge, RelevanceChip
```

## Running it
Flutter SDK lives at `~/development/flutter` (on PATH via `~/.bashrc`).

```bash
flutter analyze     # static check (clean)
flutter test        # unit tests for thresholds + seasonal logic
flutter run         # pick a device
```

### Toolchain still needed to *run* (see `flutter doctor`)
- **Quickest (Linux desktop):** `sudo apt install clang cmake ninja-build libgtk-3-dev pkg-config` → `flutter run -d linux`
- **Android emulator:** Android Studio → SDK Manager → SDK Tools → install *Android SDK Command-line Tools (latest)*, then `flutter doctor --android-licenses` (accept all), create an AVD, `flutter run`.
- **Web:** install Google Chrome → `flutter run -d chrome`
