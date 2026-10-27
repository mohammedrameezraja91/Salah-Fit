// Salah Fit — the sleep-first home screen.
//
// One clear dashboard for last night: score, hours, bed and wake time,
// stages, overnight heart and breathing, the last nights, and the next
// prayer. Every number comes from the same repository reads the detailed
// Sleep screen uses (SleepData.load, getDayHeart, getInsights); nothing is
// computed here except formatting. A missing input shows "—", never a guess.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../prayer/prayer_settings.dart';
import '../../prayer/prayer_times.dart';
import '../../state/app_state.dart';
import '../profile/profile.dart' show ProfileAvatar;
import '../revision.dart';
import '../ui2.dart';
import 'salah_dashboards.dart' show SyncStatusBar, DataRefresher;
import 'home_screen.dart' show HomeScreen, envValue, repoOf;
import 'sleep_detail.dart' show SleepData;
import 'sleep_tab.dart';

class SalahSleepHome extends StatefulWidget {
  const SalahSleepHome({super.key});

  @override
  State<SalahSleepHome> createState() => _SalahSleepHomeState();
}

class _Night {
  final SleepData sleep;
  final num? hrv;
  final num? performancePct;
  final PrayerSettings? prayer;
  const _Night(this.sleep, this.hrv, this.performancePct, this.prayer);
}

class _SalahSleepHomeState extends State<SalahSleepHome> with RevisionReload {
  _Night? _n;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void reload() => _load();

  Future<void> _load() async {
    final repo = repoOf(context);
    final t = beginRead(#sleepHome);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final d = await SleepData.load(repo);
      num? hrv;
      if (d.day != null) {
        final heart = await repo.getDayHeart(d.day!);
        hrv = (heart['hrv'] as Map?)?['rmssd'] as num?;
      }
      final ins = await repo.getInsights();
      final coach = ins['sleep_coach'];
      final perf = envValue(coach is Map ? coach['performance'] : null)?['pct']
          as num?;
      PrayerSettings? prayer;
      try {
        prayer = await PrayerSettings.load();
      } catch (_) {}
      if (!mounted || !stillNewest(#sleepHome, t)) return;
      setState(() {
        _n = _Night(d, hrv, perf, prayer);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final n = _n;
    final night = n?.sleep.night ?? const <String, dynamic>{};
    final hasNight = n?.sleep.hasNight ?? false;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x10),
        children: [
          DataRefresher(onChange: _load),
          _header(c, p),
          const SizedBox(height: S.x4),
          if (_loading && n == null)
            const SizedBox(height: 200)
          else if (!hasNight)
            _emptyCard(c, p)
          else ...[
            _heroCard(c, p, n!, night),
            const SizedBox(height: S.x3),
            _bedWakeCard(c, p, n, night),
            const SizedBox(height: S.x3),
            _stagesCard(c, p, night),
            const SizedBox(height: S.x3),
            _vitalsCard(c, p, n, night),
            const SizedBox(height: S.x3),
            _weekCard(c, p, n, night),
          ],
          const SizedBox(height: S.x4),
          _link(c, p, LucideIcons.moon, 'Sleep details',
              'Hypnogram, sleep plan, alarm and body clock', () {
            Navigator.of(c).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                    backgroundColor: P.of(c).bg,
                    body: const SafeArea(child: SleepTab()))));
          }),
          const SizedBox(height: S.x2),
          _link(c, p, LucideIcons.house, 'Full day overview',
              'Strain, recovery, steps and everything else', () {
            Navigator.of(c).push(MaterialPageRoute<void>(
                builder: (_) => Scaffold(
                    backgroundColor: P.of(c).bg,
                    body: const SafeArea(child: HomeScreen()))));
          }),
        ],
      ),
    );
  }

  // ── pieces ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext c, P p) {
    // The name typed on the About you screen (or edited in Profile).
    final name = c
        .select<AppState, String?>((a) => a.user?['name'] as String?)
        ?.trim();
    final now = DateTime.now();
    final h = _hijri(now);
    final date =
        '${_weekday(now)}, ${now.day} ${_month(now.month)} · ${h.day} ${_hijriMonths[h.month - 1]}';
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              (name == null || name.isEmpty)
                  ? 'Asalamualaikum'
                  : 'Asalamualaikum $name',
              style: F.t1.copyWith(color: p.ink)),
          const SizedBox(height: S.x1),
          Text(date, style: F.cap.copyWith(color: p.ink2)),
          const SyncStatusBar(),
        ]),
      ),
      const ProfileAvatar(accent: C.domHome),
    ]);
  }

  Widget _emptyCard(BuildContext c, P p) {
    final working = c.select<AppState, bool>((a) => a.deriving || a.syncingNow);
    return Surface(
        child: Row(children: [
          Icon(LucideIcons.bedDouble, color: p.on(C.green), size: 28),
          const SizedBox(width: S.x3),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(working ? 'Working out last night' : 'No night yet',
                  style: F.head.copyWith(color: p.ink)),
              const SizedBox(height: S.x1),
              Text(
                  working
                      ? 'Your band data is being analysed. This fills in on its own.'
                      : 'Wear the band tonight and sync in the morning. If you slept with it on, tap sync above.',
                  style: F.cap.copyWith(color: p.ink2)),
            ]),
          ),
        ]),
      );
  }

  Widget _heroCard(
      BuildContext c, P p, _Night n, Map<String, dynamic> night) {
    final dur = night['duration_min'] as num?;
    final perf = n.performancePct;
    final eff = night['efficiency'] as num?; // 0..1
    final (ringValue, ringLabel) = perf != null
        ? (perf.toDouble(), 'of your need')
        : eff != null
            ? (eff * 100.0, 'efficiency')
            : (null, 'sleep');
    final hist = n.sleep.tstHistory;
    String? vsUsual;
    if (dur != null && hist.length >= 3) {
      final avg = hist.reduce((a, b) => a + b) / hist.length;
      final diff = (dur - avg).round();
      vsUsual = diff.abs() < 10
          ? 'About your usual'
          : diff > 0
              ? '${_hm(diff)} more than usual'
              : '${_hm(-diff)} less than usual';
    }
    return Surface(
      child: Row(children: [
        SizedBox(
          width: 104,
          height: 104,
          child: CustomPaint(
            painter: _Ring(
                value: ringValue == null ? null : ringValue / 100,
                track: p.track,
                color: p.on(C.green)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(ringValue == null ? '—' : '${ringValue.round()}%',
                    style: F.n24.copyWith(color: p.ink)),
                Text(ringLabel, style: F.cap.copyWith(color: p.ink3)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: S.x4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Last night', style: F.cap.copyWith(color: p.ink3)),
            Text(dur == null ? '—' : _hm(dur.round()),
                style: F.n34.copyWith(color: p.ink)),
            if (vsUsual != null)
              Text(vsUsual, style: F.cap.copyWith(color: p.on(C.green))),
          ]),
        ),
      ]),
    );
  }

  Widget _bedWakeCard(
      BuildContext c, P p, _Night n, Map<String, dynamic> night) {
    final on = _ts(night['onset_ts']);
    final off = _ts(night['wake_ts']);
    String? fajrNote;
    final prayer = n.prayer;
    if (off != null && prayer != null) {
      final fajr = prayer.calculator.forDate(off).of(Prayer.fajr);
      final mins = off.difference(fajr).inMinutes;
      if (mins.abs() <= 180) {
        fajrNote = mins == 0
            ? 'Woke at Fajr time'
            : mins < 0
                ? 'Woke ${_hm(-mins)} before Fajr'
                : 'Woke ${_hm(mins)} after Fajr';
      }
    }
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: _kv(p, LucideIcons.moon, 'Bedtime', _clock(on))),
          Expanded(child: _kv(p, LucideIcons.sunrise, 'Woke up', _clock(off))),
        ]),
        if (fajrNote != null) ...[
          const SizedBox(height: S.x2),
          Text(fajrNote, style: F.cap.copyWith(color: p.ink2)),
        ],
      ]),
    );
  }

  Widget _stagesCard(BuildContext c, P p, Map<String, dynamic> night) {
    final stages = <(String, num?, Color)>[
      ('Deep', night['deep_min'] as num?, C.green),
      ('REM', night['rem_min'] as num?, C.indigo),
      ('Light', night['light_min'] as num?, C.sky),
      ('Awake', night['awake_min'] as num?, C.orange),
    ];
    final total = stages.fold<double>(
        0, (s, e) => s + (e.$2 == null ? 0 : e.$2!.toDouble()));
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Sleep stages', style: F.head.copyWith(color: p.ink)),
        const SizedBox(height: S.x3),
        if (total > 0)
          ClipRRect(
            borderRadius: BorderRadius.circular(7),
            child: SizedBox(
              height: 14,
              child: Row(children: [
                for (final s in stages)
                  if ((s.$2 ?? 0) > 0)
                    Expanded(
                        flex: (s.$2!.toDouble() * 10).round(),
                        child: ColoredBox(color: s.$3)),
              ]),
            ),
          )
        else
          Text('Stages not available for this night',
              style: F.cap.copyWith(color: p.ink3)),
        const SizedBox(height: S.x3),
        Wrap(runSpacing: S.x2, children: [
          for (final s in stages)
            SizedBox(
              width: 140,
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: s.$3, shape: BoxShape.circle)),
                const SizedBox(width: S.x2),
                Text('${s.$1} ', style: F.body.copyWith(color: p.ink2)),
                Text(s.$2 == null ? '—' : _hm(s.$2!.round()),
                    style: F.body.copyWith(color: p.ink)),
              ]),
            ),
        ]),
        const SizedBox(height: S.x2),
        Text('Stages are an estimate from the wrist',
            style: F.cap.copyWith(color: p.ink3)),
      ]),
    );
  }

  Widget _vitalsCard(
      BuildContext c, P p, _Night n, Map<String, dynamic> night) {
    final rhr = (night['nocturnal'] as Map?)?['sleeping_hr_avg'] as num?;
    final resp = (night['resp'] as Map?)?['value'] as num?;
    Widget cell(String k, String v, String unit) => Expanded(
          child: Column(children: [
            Text(k, style: F.cap.copyWith(color: p.ink3)),
            const SizedBox(height: S.x1),
            Text(v, style: F.n24.copyWith(color: p.ink)),
            Text(unit, style: F.cap.copyWith(color: p.ink3)),
          ]),
        );
    return Surface(
      child: Row(children: [
        cell('Sleeping HR', rhr == null ? '—' : '${rhr.round()}', 'bpm'),
        cell('HRV', n.hrv == null ? '—' : '${n.hrv!.round()}', 'ms'),
        cell('Breathing', resp == null ? '—' : resp.toStringAsFixed(1), '/min'),
      ]),
    );
  }

  Widget _weekCard(
      BuildContext c, P p, _Night n, Map<String, dynamic> night) {
    final dur = (night['duration_min'] as num?)?.toDouble();
    final past = n.sleep.tstHistory;
    final shown = [
      ...past.length > 6 ? past.sublist(past.length - 6) : past,
      if (dur != null) dur,
    ];
    if (shown.length < 2) return const SizedBox.shrink();
    const goal = 7 * 60.0;
    final top = math.max(goal * 1.2, shown.reduce(math.max) * 1.05);
    final avg = shown.reduce((a, b) => a + b) / shown.length;
    return Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text('Last ${shown.length} nights',
                  style: F.head.copyWith(color: p.ink))),
          Text('avg ${_hm(avg.round())}', style: F.cap.copyWith(color: p.ink3)),
        ]),
        const SizedBox(height: S.x3),
        SizedBox(
          height: 96,
          child: Stack(children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: 96 * goal / top,
              child: Container(height: 1, color: p.ink3),
            ),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var i = 0; i < shown.length; i++) ...[
                if (i > 0) const SizedBox(width: S.x2),
                Expanded(
                  child: Container(
                    height: math.max(4, 96 * shown[i] / top),
                    decoration: BoxDecoration(
                      color: i == shown.length - 1
                          ? p.on(C.green)
                          : p.wash(C.green, strength: 1).withValues(alpha: .35),
                      borderRadius:
                          const BorderRadius.vertical(top: Radius.circular(4)),
                    ),
                  ),
                ),
              ],
            ]),
          ]),
        ),
        const SizedBox(height: S.x2),
        Text('Line = 7 h goal · darkest bar = last night',
            style: F.cap.copyWith(color: p.ink3)),
      ]),
    );
  }

  Widget _kv(P p, IconData icon, String k, String v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: p.ink3),
          const SizedBox(width: S.x1),
          Text(k, style: F.cap.copyWith(color: p.ink3)),
        ]),
        const SizedBox(height: S.x1),
        Text(v, style: F.n24.copyWith(color: p.ink)),
      ]);

  Widget _link(BuildContext c, P p, IconData icon, String title, String sub,
          VoidCallback onTap) =>
      Surface(
        onTap: onTap,
        child: Row(children: [
          Icon(icon, color: p.on(C.green), size: 20),
          const SizedBox(width: S.x3),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: F.body.copyWith(color: p.ink)),
              Text(sub, style: F.cap.copyWith(color: p.ink3)),
            ]),
          ),
          Icon(LucideIcons.chevronRight, color: p.ink3, size: 18),
        ]),
      );
}

class _Ring extends CustomPainter {
  final double? value; // 0..1, null = no ring
  final Color track, color;
  const _Ring({required this.value, required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final rect = Offset.zero & size;
    final arc = rect.deflate(stroke / 2);
    final base = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawArc(arc, 0, 2 * math.pi, false, base);
    final v = value;
    if (v == null || v <= 0) return;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = stroke;
    canvas.drawArc(arc, -math.pi / 2, 2 * math.pi * v.clamp(0.0, 1.0), false, fg);
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.value != value || old.color != color || old.track != track;
}

// ── formatting ───────────────────────────────────────────────────────────────

DateTime? _ts(Object? v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.round() * 1000) : null;

String _hm(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  if (h == 0) return '${m}m';
  return '${h}h ${m.toString().padLeft(2, '0')}m';
}

String _clock(DateTime? t) {
  if (t == null) return '—';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

String _weekday(DateTime d) => const [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ][d.weekday - 1];

String _month(int m) => const [
      'January', 'February', 'March', 'April', 'May', 'June', 'July',
      'August', 'September', 'October', 'November', 'December'
    ][m - 1];

const _hijriMonths = [
  'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 'Jumada al-Ula',
  'Jumada al-Thani', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhul Qadah',
  'Dhul Hijjah',
];

/// Tabular (Kuwaiti) Hijri date. Can differ by a day from the local
/// moon-sighting calendar.
({int year, int month, int day}) _hijri(DateTime g) {
  final a = (14 - g.month) ~/ 12;
  final y = g.year + 4800 - a;
  final m = g.month + 12 * a - 3;
  final jd = g.day + (153 * m + 2) ~/ 5 + 365 * y + y ~/ 4 - y ~/ 100 +
      y ~/ 400 - 32045;
  var l = jd - 1948440 + 10632;
  final n = (l - 1) ~/ 10631;
  l = l - 10631 * n + 354;
  final j = ((10985 - l) ~/ 5316) * ((50 * l) ~/ 17719) +
      (l ~/ 5670) * ((43 * l) ~/ 15238);
  l = l - ((30 - j) ~/ 15) * ((17719 * j) ~/ 50) -
      (j ~/ 16) * ((15238 * j) ~/ 43) +
      29;
  final month = (24 * l) ~/ 709;
  final day = l - (709 * month) ~/ 24;
  return (year: 30 * n + j - 30, month: month, day: day);
}
