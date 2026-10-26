// prayer_settings.dart — Salah Fit's prayer-alarm preferences.
//
// Stored in SharedPreferences so BOTH the foreground app and the headless
// background sync (which has no AppState) read the same values when they
// arm the band. The band holds a single alarm, so the arming code in
// state/alarm_schedule.dart asks [nextPrayerAfter] for the next enabled
// prayer and arms whichever comes first: that or the wake alarm. When the
// band fires, the normal re-arm path picks the following prayer.

import 'dart:math' as math;

import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../gps/gps_source.dart';

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

  /// Follow the phone's location (default) instead of a fixed city.
  final bool auto;
  final Set<Prayer> prayers;
  final String cityName;
  final double lat, lng;

  /// 2 = Hanafi (default), 1 = Shafi'i.
  final int asrFactor;

  const PrayerSettings({
    required this.enabled,
    required this.auto,
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
  static const _kAuto = 'salahfit_prayer_auto';
  static const _kChecked = 'salahfit_prayer_loc_checked_ms';

  static Future<PrayerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    // Re-read from disk: the background isolate and the UI isolate each hold
    // their own cached copy, and a change made in one must reach the other.
    await prefs.reload();
    final names = prefs.getStringList(_kPrayers);
    final def = kPrayerCities.first;
    return PrayerSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      auto: prefs.getBool(_kAuto) ?? true,
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
    await prefs.setBool(_kAuto, auto);
    await prefs.setStringList(_kPrayers, [for (final p in prayers) p.name]);
    await prefs.setString(_kCity, cityName);
    await prefs.setDouble(_kLat, lat);
    await prefs.setDouble(_kLng, lng);
    await prefs.setInt(_kAsr, asrFactor);
  }

  PrayerSettings copyWith({
    bool? enabled,
    bool? auto,
    Set<Prayer>? prayers,
    String? cityName,
    double? lat,
    double? lng,
    int? asrFactor,
  }) =>
      PrayerSettings(
        enabled: enabled ?? this.enabled,
        auto: auto ?? this.auto,
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

  /// Automatic location: when [auto] is on, read where the phone is and, if
  /// it moved more than a few km since the last fix, save the new place and
  /// return the updated settings (null = nothing changed, or auto is off).
  ///
  /// [ask] may show the location permission prompt (only from the prayer
  /// screen); without it this only uses a permission already granted, and
  /// checks at most every 3 hours so the Today screen stays cheap.
  static Future<PrayerSettings?> refreshAuto({bool ask = false}) async {
    final s = await load();
    if (!s.auto) return null;
    final prefs = await SharedPreferences.getInstance();
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (!ask && nowMs - (prefs.getInt(_kChecked) ?? 0) < 3 * 3600 * 1000) {
      return null;
    }
    try {
      if (ask) {
        if (await GpsSource.ensurePermission() != GpsPermissionStatus.granted) {
          return null;
        }
      } else {
        final perm = await Geolocator.checkPermission();
        if (perm != LocationPermission.always &&
            perm != LocationPermission.whileInUse) {
          return null;
        }
      }
      Position? pos;
      try {
        pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
              timeLimit: Duration(seconds: 20)),
        );
      } catch (_) {
        pos = await Geolocator.getLastKnownPosition();
      }
      if (pos == null) return null;
      // Never located before: always take the first real fix.
      final first = (prefs.getInt(_kChecked) ?? 0) == 0;
      await prefs.setInt(_kChecked, nowMs);
      if (!first && _km(s.lat, s.lng, pos.latitude, pos.longitude) < 5) {
        return null;
      }
      final next = s.copyWith(
          cityName: _placeName(pos.latitude, pos.longitude),
          lat: pos.latitude,
          lng: pos.longitude);
      await next.save();
      return next;
    } catch (_) {
      return null;
    }
  }

  /// A known city's name when within 30 km of it, else a generic label.
  static String _placeName(double lat, double lng) {
    for (final c in kPrayerCities) {
      if (_km(lat, lng, c.lat, c.lng) < 30) return c.name;
    }
    return 'Current location';
  }

  static double _km(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0;
    double rad(double d) => d * math.pi / 180;
    final dLat = rad(lat2 - lat1), dLng = rad(lng2 - lng1);
    final a = math.pow(math.sin(dLat / 2), 2) +
        math.cos(rad(lat1)) * math.cos(rad(lat2)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.sqrt(a));
  }
}
