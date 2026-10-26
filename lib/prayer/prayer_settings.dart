// prayer_settings.dart — Salah Fit's prayer-alarm preferences.
//
// Stored in SharedPreferences so BOTH the foreground app and the headless
// background sync (which has no AppState) read the same values when they
// arm the band. The band holds a single alarm, so the arming code in
// state/alarm_schedule.dart asks [nextPrayerAfter] for the next enabled
// prayer and arms whichever comes first: that or the wake alarm. When the
// band fires, the normal re-arm path picks the following prayer.

import 'package:shared_preferences/shared_preferences.dart';

import 'prayer_times.dart';

class PrayerCity {
  final String name;
  final double lat, lng;
  const PrayerCity(this.name, this.lat, this.lng);
}

const kPrayerCities = <PrayerCity>[
  PrayerCity('Erode', 11.3410, 77.7172),
  PrayerCity('Coimbatore', 11.0168, 76.9558),
];

class PrayerSettings {
  final bool enabled;
  final Set<Prayer> prayers;
  final String cityName;
  final double lat, lng;

  /// 2 = Hanafi (default), 1 = Shafi'i.
  final int asrFactor;

  const PrayerSettings({
    required this.enabled,
    required this.prayers,
    required this.cityName,
    required this.lat,
    required this.lng,
    required this.asrFactor,
  });

  static const _kEnabled = 'salahfit_prayer_enabled';
  static const _kPrayers = 'salahfit_prayer_list';
  static const _kCity = 'salahfit_prayer_city';
  static const _kLat = 'salahfit_prayer_lat';
  static const _kLng = 'salahfit_prayer_lng';
  static const _kAsr = 'salahfit_prayer_asr';

  static Future<PrayerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Re-read from disk: the background isolate and the UI isolate each hold
    // their own cached copy, and a change made in one must reach the other.
    await prefs.reload();
    final names = prefs.getStringList(_kPrayers);
    final def = kPrayerCities.first;
    return PrayerSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      prayers: names == null
          ? Prayer.values.toSet()
          : {
              for (final p in Prayer.values)
                if (names.contains(p.name)) p
            },
      cityName: prefs.getString(_kCity) ?? def.name,
      lat: prefs.getDouble(_kLat) ?? def.lat,
      lng: prefs.getDouble(_kLng) ?? def.lng,
      asrFactor: prefs.getInt(_kAsr) ?? 2,
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
    await prefs.setStringList(_kPrayers, [for (final p in prayers) p.name]);
    await prefs.setString(_kCity, cityName);
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
    await prefs.setInt(_kAsr, asrFactor);
  }

  PrayerSettings copyWith({
    bool? enabled,
    Set<Prayer>? prayers,
    String? cityName,
    double? lat,
    double? lng,
    int? asrFactor,
  }) =>
      PrayerSettings(
        enabled: enabled ?? this.enabled,
        prayers: prayers ?? this.prayers,
        cityName: cityName ?? this.cityName,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
        asrFactor: asrFactor ?? this.asrFactor,
      );

  PrayerCalculator get calculator =>
      PrayerCalculator(lat: lat, lng: lng, asrFactor: asrFactor);

  PrayerDay today([DateTime? now]) => calculator.forDate(now ?? DateTime.now());

  /// The next enabled prayer strictly after [now], or null when prayer
  /// alarms are off. Looks at today and tomorrow, which always finds one.
  ({Prayer prayer, DateTime at})? nextPrayerAfter(DateTime now) {
    if (!enabled || prayers.isEmpty) return null;
    for (var dayOffset = 0; dayOffset < 2; dayOffset++) {
      final day = calculator
          .forDate(DateTime(now.year, now.month, now.day + dayOffset));
      for (final p in Prayer.values) {
        if (!prayers.contains(p)) continue;
        final at = day.of(p);
        if (at.isAfter(now)) return (prayer: p, at: at);
      }
    }
    return null;
  }

  /// Which prayer, if any, an armed band alarm at [at] belongs to.
  Prayer? prayerAt(DateTime at) {
    if (!enabled) return null;
    final day = calculator.forDate(at);
    for (final p in prayers) {
      if (day.of(p).difference(at).inSeconds.abs() < 60) return p;
    }
    return null;
  }
}
