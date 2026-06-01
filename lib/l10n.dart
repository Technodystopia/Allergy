import 'models.dart';

enum AppLang { en, fi }

/// Lightweight in-app localisation. Each getter/method returns the string for
/// the active language — `_('english', 'suomi')`.
class L10n {
  final AppLang lang;
  const L10n(this.lang);

  String _(String en, String fi) => lang == AppLang.fi ? fi : en;

  bool get isFi => lang == AppLang.fi;

  // --- navigation / shell ---
  String get today => _('Today', 'Tänään');
  String get bloom => _('Bloom', 'Kukinta');
  String get reference => _('Reference', 'Tietopankki');
  String get tooltipSource => _('Data source', 'Tietolähde');
  String get tooltipFavourite => _('Switch to favourite', 'Vaihda suosikkiin');
  String get tooltipLocations => _('Locations', 'Sijainnit');
  String get tooltipSettings => _('Settings', 'Asetukset');

  // --- onboarding ---
  String get onboardTitle =>
      _('Which allergens affect you?', 'Mitkä allergeenit vaivaavat sinua?');
  String get onboardBody => _(
      'Pick the pollen types you react to. You can change this any time. Your forecast and bloom timeline will only show these.',
      'Valitse siitepölyt, joille olet herkkä. Voit muuttaa valintaa milloin vain. Ennuste ja kukinta-aikajana näyttävät vain nämä.');
  String get continueLabel => _('Continue', 'Jatka');

  // --- today ---
  String get noAllergens => _('No allergens selected.\nAdd some from the Reference tab.',
      'Ei valittuja allergeeneja.\nLisää niitä Tietopankki-välilehdeltä.');
  String get errorTitle =>
      _('Could not load live forecast', 'Ennusteen lataus epäonnistui');
  String get errorEstimates =>
      _('Showing seasonal estimates.', 'Näytetään kausiarviot.');
  String get offlineTitle => _(
      'Offline — showing last saved forecast', 'Offline — näytetään viimeisin ennuste');
  String offlineUpdated(String ago) =>
      _('Last updated $ago.', 'Päivitetty $ago.');
  String get retry => _('Retry', 'Yritä uudelleen');
  String get todayLabel => _('Today', 'Tänään');
  String get tomorrow => _('Tomorrow', 'Huomenna');
  String grains(int n) => _('$n grains/m³', '$n kpl/m³');
  String get estSuffix => _(' (est.)', ' (arvio)');
  String get show7 => _('Show 7 days', 'Näytä 7 päivää');
  String get showLess => _('Show less', 'Näytä vähemmän');
  String get estimateNote => _(
      'Faded points (days 5–7) are seasonal estimates — the live model only forecasts ~4 days ahead.',
      'Haaleat pisteet (päivät 5–7) ovat kausiarvioita — malli ennustaa vain ~4 päivää eteenpäin.');
  String source(String attr) => _('Source: $attr', 'Lähde: $attr');
  String get updated => _('updated', 'päivitetty');
  String get noNotable =>
      _('No notable pollen today', 'Ei merkittävää siitepölyä tänään');
  String summaryHeadline(String level, String? allergen) {
    final a = allergen != null ? ' · $allergen' : '';
    return _('$level pollen today$a', '$level siitepölymäärä tänään$a');
  }

  // --- bloom ---
  String get bloomHeader => _(
      'Flowering seasons for your allergens (southern Finland). The bar is the typical season; "right now" uses the live forecast.',
      'Allergeeniesi kukinta-ajat (Etelä-Suomi). Palkki on tyypillinen kausi; "juuri nyt" perustuu ennusteeseen.');
  String get bloomNow => _('Right now', 'Juuri nyt');
  String get bloomLive => _('live', 'live');
  String get bloomModelEst => _('seasonal estimate', 'kausiarvio');

  // --- reference ---
  String get refHeader => _(
      'Tap a plant for details and cross-reactions. Use the star to add it to your allergens.',
      'Napauta kasvia nähdäksesi tiedot ja ristireaktiot. Tähdellä lisäät sen allergeeneihisi.');
  String get crossPollen => _('Cross-reacting pollen', 'Ristireagoiva siitepöly');
  String get noneNoted => _('None noted.', 'Ei tunnettuja.');
  String get crossFoods => _('Foods that may cross-react (oral allergy syndrome)',
      'Ruoat, jotka voivat ristireagoida (suun allergiaoireyhtymä)');
  String get severityScale => _('Severity scale (grains/m³)', 'Voimakkuusasteikko (kpl/m³)');
  String get addAllergen => _('Add to my allergens', 'Lisää allergeeneihini');
  String get removeAllergen =>
      _('Remove from my allergens', 'Poista allergeeneista');

  // --- locations ---
  String get locations => _('Locations', 'Sijainnit');
  String get locHeader => _(
      'Tap to view its forecast. Set a home base (🏠) and star your favourites for quick switching.',
      'Napauta nähdäksesi ennusteen. Aseta kotipaikka (🏠) ja merkitse suosikit tähdellä.');
  String get useMyLocation => _('Use my location', 'Käytä sijaintiani');
  String get useMyLocationSub =>
      _('Forecast for where you are now', 'Ennuste nykyiselle sijainnillesi');
  String current(String name) => _('Current: $name', 'Nykyinen: $name');
  String get capitalRegion => _('Capital region', 'Pääkaupunkiseutu');
  String get setHome => _('Set as home', 'Aseta kotipaikaksi');
  String get favourite => _('Favourite', 'Suosikki');

  // --- settings ---
  String get settings => _('Settings', 'Asetukset');
  String get dataSource => _('Data source', 'Tietolähde');
  String get notifications => _('Notifications', 'Ilmoitukset');
  String get dailyAlert => _('Daily pollen alert', 'Päivittäinen siitepölyilmoitus');
  String get dailyAlertSub => _(
      'A daily reminder, plus a heads-up when any of your allergens hits High or above.',
      'Päivittäinen muistutus sekä hälytys, kun jokin allergeeneistasi nousee korkealle.');
  String get reminderTime => _('Reminder time', 'Muistutusaika');
  String get sendTest => _('Send a test notification', 'Lähetä testi-ilmoitus');
  String get about => _('About', 'Tietoja');
  String get aboutBody => _(
      'Educational reference, not medical advice. Pollen seasons vary year to year.',
      'Opastava tietolähde, ei lääketieteellinen neuvo. Siitepölykaudet vaihtelevat vuosittain.');
  String get language => _('Language', 'Kieli');
  String get english => _('English', 'Englanti');
  String get finnish => _('Finnish', 'Suomi');

  // --- relative time ---
  String get justNow => _('just now', 'juuri nyt');
  String minAgo(int n) => _('$n min ago', '$n min sitten');
  String hAgo(int n) => _('$n h ago', '$n t sitten');
  String dAgo(int n) => _('$n d ago', '$n pv sitten');

  // --- enums ---
  String level(PollenLevel l) {
    switch (l) {
      case PollenLevel.none:
        return _('None', 'Ei');
      case PollenLevel.low:
        return _('Low', 'Matala');
      case PollenLevel.moderate:
        return _('Moderate', 'Kohtalainen');
      case PollenLevel.high:
        return _('High', 'Korkea');
      case PollenLevel.veryHigh:
        return _('Very high', 'Erittäin korkea');
    }
  }

  String levelAdvice(PollenLevel l) {
    switch (l) {
      case PollenLevel.none:
        return _('No pollen of this type expected.',
            'Tätä siitepölyä ei ole odotettavissa.');
      case PollenLevel.low:
        return _('Low — most people won’t notice symptoms.',
            'Matala — useimmat eivät huomaa oireita.');
      case PollenLevel.moderate:
        return _('Sensitive people may react — keep medication handy.',
            'Herkät voivat saada oireita — pidä lääkkeet lähellä.');
      case PollenLevel.high:
        return _(
            'Symptoms likely. Limit time outdoors, keep windows shut, take antihistamines.',
            'Oireita todennäköisesti. Vältä ulkoilua, pidä ikkunat kiinni, ota antihistamiini.');
      case PollenLevel.veryHigh:
        return _(
            'Strong reactions likely. Stay in midday, windows closed, consider a mask outdoors.',
            'Voimakkaita oireita todennäköisesti. Pysy sisällä keskipäivällä, ikkunat kiinni, harkitse maskia ulkona.');
    }
  }

  String stageLabel(BloomStage s) {
    switch (s) {
      case BloomStage.dormant:
        return _('Pre-season', 'Ennen kautta');
      case BloomStage.onset:
        return _('Onset', 'Alkaa');
      case BloomStage.peak:
        return _('Peak', 'Huippu');
      case BloomStage.declining:
        return _('Declining', 'Laskussa');
      case BloomStage.ended:
        return _('Over', 'Ohi');
    }
  }

  String stageDesc(BloomStage s) {
    switch (s) {
      case BloomStage.dormant:
        return _('Not flowering yet', 'Ei vielä kuki');
      case BloomStage.onset:
        return _('Season starting, counts rising', 'Kausi alkaa, määrät nousevat');
      case BloomStage.peak:
        return _('Peak flowering — highest counts', 'Kukinnan huippu — suurimmat määrät');
      case BloomStage.declining:
        return _('Season winding down', 'Kausi hiipuu');
      case BloomStage.ended:
        return _('Season finished for this year', 'Kausi päättynyt tältä vuodelta');
    }
  }

  String relevance(String r) {
    switch (r) {
      case 'very_high':
        return _('Major FI allergen', 'Merkittävä Suomessa');
      case 'high':
        return _('Common in FI', 'Yleinen Suomessa');
      case 'moderate':
        return _('Present in FI', 'Esiintyy Suomessa');
      case 'low':
        return _('Minor / transported', 'Vähäinen / kaukokulkeuma');
      case 'none':
        return _('Not a FI allergen', 'Ei allergeeni Suomessa');
      default:
        return r;
    }
  }

  /// Display name: primary in the active language, secondary after a dot.
  String allergenName(Allergen a) =>
      isFi ? '${a.nameFi} · ${a.nameEn}' : '${a.nameEn} · ${a.nameFi}';

  /// A food chip label. Falls back to the prettified English key.
  String food(String key) {
    final fi = _foodsFi[key];
    if (isFi && fi != null) return fi;
    return key
        .replaceAll('_', ' ')
        .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
  }

  static const _foodsFi = {
    'apple': 'Omena',
    'pear': 'Päärynä',
    'peach': 'Persikka',
    'cherry': 'Kirsikka',
    'plum': 'Luumu',
    'hazelnut': 'Hasselpähkinä',
    'almond': 'Manteli',
    'carrot': 'Porkkana',
    'celery': 'Selleri',
    'kiwi': 'Kiivi',
    'soy': 'Soija',
    'tomato': 'Tomaatti',
    'melon': 'Meloni',
    'watermelon': 'Vesimeloni',
    'honeydew': 'Hunajameloni',
    'orange': 'Appelsiini',
    'peanut': 'Maapähkinä',
    'swiss_chard': 'Lehtimangoldi',
    'parsley': 'Persilja',
    'coriander': 'Korianteri',
    'cumin': 'Kumina',
    'fennel': 'Fenkoli',
    'sunflower_seed': 'Auringonkukansiemen',
    'mango': 'Mango',
    'chamomile': 'Kamomilla',
    'banana': 'Banaani',
    'cucumber': 'Kurkku',
    'zucchini': 'Kesäkurpitsa',
  };
}
