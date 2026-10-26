// prayer_times.dart — the five daily prayer times, computed on the phone.
//
// Pure Dart, no network and no packages: the standard astronomical method
// (the same one PrayTimes.org and most adhan apps use). Defaults match what
// is common in India: University of Islamic Sciences, Karachi angles
// (Fajr 18°, Isha 18°) and the Hanafi Asr (shadow = 2× object length).
//
// Every time is computed in UTC from the sun's position and returned as a
// LOCAL DateTime, so the phone's own time zone decides how it is shown.

import 'dart:math' as math;

enum Prayer { fajr, dhuhr, asr, maghrib, isha }

extension PrayerName on Prayer {
  String get label => switch (this) {
        Prayer.fajr => 'Fajr',
        Prayer.dhuhr => 'Dhuhr',
        Prayer.asr => 'Asr',
        Prayer.maghrib => 'Maghrib',
        Prayer.isha => 'Isha',
      };
}

/// One day's times, all local.
class PrayerDay {
  final DateTime fajr, sunrise, dhuhr, asr, maghrib, isha;
  const PrayerDay({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
  });

  DateTime of(Prayer p) => switch (p) {
        Prayer.fajr => fajr,
        Prayer.dhuhr => dhuhr,
        Prayer.asr => asr,
        Prayer.maghrib => maghrib,
        Prayer.isha => isha,
      };
}

class PrayerCalculator {
  final double lat, lng;
  final double fajrAngle, ishaAngle;

  /// 1 = Shafi'i / standard, 2 = Hanafi.
  final int asrFactor;

  const PrayerCalculator({
    required this.lat,
    required this.lng,
    this.fajrAngle = 18,
    this.ishaAngle = 18,
    this.asrFactor = 2,
  });

  static double _d2r(double d) => d * math.pi / 180;
  static double _r2d(double r) => r * 180 / math.pi;
  static double _fixAngle(double a) => a - 360 * (a / 360).floorToDouble();
  static double _fixHour(double h) => h - 24 * (h / 24).floorToDouble();

  static double _julian(int y, int m, int d) {
    if (m <= 2) {
      y -= 1;
      m += 12;
    }
    final a = (y / 100).floor();
    final b = 2 - a + (a / 4).floor();
    return (365.25 * (y + 4716)).floorToDouble() +
        (30.6001 * (m + 1)).floorToDouble() +
        d +
        b -
        1524.5;
  }

  /// (declination°, equation of time in hours)
  static (double, double) _sun(double jd) {
    final dd = jd - 2451545.0;
    final g = _fixAngle(357.529 + 0.98560028 * dd);
    final q = _fixAngle(280.459 + 0.98564736 * dd);
    final l = _fixAngle(
        q + 1.915 * math.sin(_d2r(g)) + 0.020 * math.sin(_d2r(2 * g)));
    final e = 23.439 - 0.00000036 * dd;
    final ra = _r2d(math.atan2(
            math.cos(_d2r(e)) * math.sin(_d2r(l)), math.cos(_d2r(l)))) /
        15;
    final eqt = q / 15 - _fixHour(ra);
    final decl = _r2d(math.asin(math.sin(_d2r(e)) * math.sin(_d2r(l))));
    return (decl, eqt);
  }

  /// Prayer times for the calendar [date] (only its y/m/d are used).
  PrayerDay forDate(DateTime date) {
    final jd = _julian(date.year, date.month, date.day) - lng / (15 * 24);

    double midDay(double t) => _fixHour(12 - _sun(jd + t).$2);

    double sunAngleTime(double angle, double t, {bool ccw = false}) {
      final decl = _sun(jd + t).$1;
      final noon = midDay(t);
      var x = (-math.sin(_d2r(angle)) -
              math.sin(_d2r(decl)) * math.sin(_d2r(lat))) /
          (math.cos(_d2r(decl)) * math.cos(_d2r(lat)));
      x = x.clamp(-1.0, 1.0); // polar edge cases; never hit in India
      final tt = _r2d(math.acos(x)) / 15;
      return ccw ? noon - tt : noon + tt;
    }

    double asrTime(double t) {
      final decl = _sun(jd + t).$1;
      final angle =
          -_r2d(math.atan(1 / (asrFactor + math.tan(_d2r((lat - decl).abs())))));
      return sunAngleTime(angle, t);
    }

    const riseSet = 0.833;
    final fajr = sunAngleTime(fajrAngle, 5 / 24, ccw: true);
    final sunrise = sunAngleTime(riseSet, 6 / 24, ccw: true);
    final dhuhr = midDay(12 / 24);
    final asr = asrTime(13 / 24);
    final maghrib = sunAngleTime(riseSet, 18 / 24);
    final isha = sunAngleTime(ishaAngle, 18 / 24);

    final base = DateTime.utc(date.year, date.month, date.day);
    DateTime at(double hours) {
      final utcHours = hours - lng / 15;
      // Round to the nearest minute, the way timetables print it.
      final minutes = (utcHours * 60).round();
      return base.add(Duration(minutes: minutes)).toLocal();
    }

    return PrayerDay(
      fajr: at(fajr),
      sunrise: at(sunrise),
      dhuhr: at(dhuhr),
      asr: at(asr),
      maghrib: at(maghrib),
      isha: at(isha),
    );
  }
}
