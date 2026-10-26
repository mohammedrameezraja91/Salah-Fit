// Salah Fit — the Activity, Salah and Health dashboards.
//
// Same grammar as the sleep home: a few clean cards, every number read from
// the repository the detailed screens already use, nothing computed here but
// formatting. A missing input shows "—", never a guess. Each dashboard ends
// with a link to the full screen it sits on top of.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../prayer/prayer_settings.dart';
import '../../prayer/prayer_times.dart';
import '../profile/prayer.dart' show PrayerScreen;
import '../revision.dart';
import '../ui2.dart';
import 'health_screen.dart' show HealthScreen;
import 'home_screen.dart' show HomeData, repoOf;
import 'sleep_detail.dart' show SleepData;
import 'workout_screen.dart' show WorkoutScreen;

// ── shared bits ───────────────────────────────────────────────────────────────

class _Ring extends CustomPainter {
  final double? value; // 0..1, null = empty track only
  final Color track, color;
  const _Ring({required this.value, required this.track, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 10.0;
    final arc = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
        arc,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    final v = value;
    if (v == null || v <= 0) return;
    canvas.drawArc(
        arc,
        -math.pi / 2,
        2 * math.pi * v.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = stroke);
  }

  @override
  bool shouldRepaint(_Ring old) =>
      old.value != value || old.color != color || old.track != track;
}

Widget _ringCard(P p,
        {required double? fraction,
        required String center,
        required String sub,
        required String label,
        required String big,
        String? note}) =>
    Surface(
      child: Row(children: [
        SizedBox(
          width: 104,
          height: 104,
          child: CustomPaint(
            painter: _Ring(
                value: fraction, track: p.track, color: p.on(C.green)),
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(center, style: F.n24.copyWith(color: p.ink)),
                Text(sub, style: F.cap.copyWith(color: p.ink3)),
              ]),
            ),
          ),
        ),
        const SizedBox(width: S.x4),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: F.cap.copyWith(color: p.ink3)),
            Text(big, style: F.n34.copyWith(color: p.ink)),
            if (note != null)
              Text(note, style: F.cap.copyWith(color: p.on(C.green))),
          ]),
        ),
      ]),
    );

Widget _stat(P p, String k, String v, String unit) => Surface(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(k, style: F.cap.copyWith(color: p.ink3)),
        const SizedBox(height: S.x1),
        Text(v, style: F.n24.copyWith(color: p.ink)),
        Text(unit, style: F.cap.copyWith(color: p.ink3)),
      ]),
    );

Widget _twoUp(Widget a, Widget b) => Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: a),
        const SizedBox(width: S.x3),
        Expanded(child: b),
      ],
    );

Widget _title(P p, String t, String sub) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(t, style: F.t1.copyWith(color: p.ink)),
      const SizedBox(height: S.x1),
      Text(sub, style: F.cap.copyWith(color: p.ink2)),
    ]);

Widget _link(P p, IconData icon, String title, String sub, VoidCallback onTap) =>
    Surface(
      onTap: onTap,
      child: Row(children: [
        Icon(icon, color: p.on(C.green), size: 20),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: F.body.copyWith(color: p.ink)),
            Text(sub, style: F.cap.copyWith(color: p.ink3)),
          ]),
        ),
        Icon(LucideIcons.chevronRight, color: p.ink3, size: 18),
      ]),
    );

void _open(BuildContext c, Widget screen) {
  Navigator.of(c).push(MaterialPageRoute<void>(
      builder: (ctx) => Scaffold(
          backgroundColor: P.of(ctx).bg, body: SafeArea(child: screen))));
}

String _num(num? v) => v == null ? '—' : v.round().toString();

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

// ── Activity ──────────────────────────────────────────────────────────────────

class SalahActivityHome extends StatefulWidget {
  const SalahActivityHome({super.key});

  @override
  State<SalahActivityHome> createState() => _ActivityState();
}

class _ActivityState extends State<SalahActivityHome> with RevisionReload {
  HomeData? _d;
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
    final t = beginRead(#activityHome);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final d = await HomeData.load(repo);
      if (!mounted || !stillNewest(#activityHome, t)) return;
      setState(() {
        _d = d;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final d = _d;
    final strain = d?.strain.value;
    final steps = d?.steps.value;
    final goal = d?.stepGoal ?? 10000;
    final kcal = d?.calories.value;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x10),
        children: [
          _title(p, 'Activity', 'How hard your body worked today'),
          const SizedBox(height: S.x4),
          if (_loading && d == null)
            const SizedBox(height: 200)
          else ...[
            _ringCard(p,
                fraction: strain == null ? null : strain.toDouble() / 21,
                center: strain == null ? '—' : strain.toStringAsFixed(1),
                sub: 'of 21',
                label: 'Day strain',
                big: strain == null ? '—' : strain.toStringAsFixed(1),
                note: strain == null
                    ? 'Builds as the day goes on'
                    : null),
            const SizedBox(height: S.x3),
            Surface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                          child: Text('Steps',
                              style: F.cap.copyWith(color: p.ink3))),
                      Text('Goal $goal',
                          style: F.cap.copyWith(color: p.ink3)),
                    ]),
                    const SizedBox(height: S.x1),
                    Text(steps == null ? '—' : _grouped(steps.round()),
                        style: F.n34.copyWith(color: p.ink)),
                    const SizedBox(height: S.x2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: steps == null
                            ? 0
                            : (steps / goal).clamp(0.0, 1.0).toDouble(),
                        minHeight: 8,
                        backgroundColor: p.track,
                        color: p.on(C.green),
                      ),
                    ),
                    const SizedBox(height: S.x2),
                    Text('Steps are estimated from the wrist',
                        style: F.cap.copyWith(color: p.ink3)),
                  ]),
            ),
            const SizedBox(height: S.x3),
            _twoUp(
              _stat(p, 'Active calories', _num(kcal), 'kcal'),
              _stat(p, 'Resting HR', _num(d?.rhr.value), 'bpm'),
            ),
          ],
          const SizedBox(height: S.x4),
          _link(p, LucideIcons.activity, 'Workouts and heart rate zones',
              'Start a workout, see past ones', () => _open(c, const WorkoutScreen())),
        ],
      ),
    );
  }
}

String _grouped(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// ── Salah ─────────────────────────────────────────────────────────────────────

class SalahPrayerHome extends StatefulWidget {
  const SalahPrayerHome({super.key});

  @override
  State<SalahPrayerHome> createState() => _PrayerHomeState();
}

class _PrayerHomeState extends State<SalahPrayerHome> {
  PrayerSettings? _s;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _load();
    _tick = Timer.periodic(
        const Duration(seconds: 30), (_) => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await PrayerSettings.load();
      if (mounted) setState(() => _s = s);
    } catch (_) {}
  }

  static String _in(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return 'less than a minute';
    final h = m ~/ 60, r = m % 60;
    return h == 0 ? '$m min' : '$h h ${r.toString().padLeft(2, '0')} min';
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final s = _s;
    final now = DateTime.now();
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x10),
        children: [
          _title(p, 'Salah',
              s == null ? ' ' : '${s.cityName} · ${s.asrFactor == 2 ? 'Hanafi' : 'Shafi\'i'} Asr'),
          const SizedBox(height: S.x4),
          if (s != null) ...[
            _nextCard(p, s, now),
            const SizedBox(height: S.x3),
            _listCard(p, s, now),
            const SizedBox(height: S.x3),
            _twoUp(
              _stat(p, 'Sunrise', _clock(s.today(now).sunrise), 'no alarm'),
              _stat(p, 'Band alarm', s.enabled ? 'On' : 'Off',
                  s.enabled ? 'buzzes at prayer' : 'turn on in settings'),
            ),
          ],
          const SizedBox(height: S.x4),
          _link(p, LucideIcons.settings, 'Prayer settings',
              'Alarms per prayer, location, Asr method', () async {
            await Navigator.of(c).push(MaterialPageRoute<void>(
                builder: (_) => const PrayerScreen()));
            _load();
          }),
        ],
      ),
    );
  }

  Widget _nextCard(P p, PrayerSettings s, DateTime now) {
    final next = s.copyWith(enabled: true, prayers: Prayer.values.toSet())
        .nextPrayerAfter(now);
    if (next == null) {
      return Surface(child: Text('—', style: F.n34.copyWith(color: p.ink)));
    }
    // Previous prayer time: the latest of today's/yesterday's that has passed.
    final yesterday = s.calculator
        .forDate(DateTime(now.year, now.month, now.day - 1));
    final today = s.today(now);
    final times = [
      for (final pr in Prayer.values) yesterday.of(pr),
      for (final pr in Prayer.values) today.of(pr),
    ].where((t) => !t.isAfter(now)).toList();
    double? progress;
    if (times.isNotEmpty) {
      final prev = times.last;
      final span = next.at.difference(prev).inSeconds;
      if (span > 0) progress = now.difference(prev).inSeconds / span;
    }
    return Container(
      padding: const EdgeInsets.all(S.x4),
      decoration: BoxDecoration(
          color: C.green, borderRadius: BorderRadius.circular(20)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Next prayer',
            style: F.cap.copyWith(color: Colors.white.withValues(alpha: .8))),
        const SizedBox(height: S.x1),
        Text('${next.prayer.label} · ${_clock(next.at)}',
            style: F.n34.copyWith(color: Colors.white)),
        Text('in ${_in(next.at.difference(now))}',
            style: F.cap.copyWith(color: Colors.white.withValues(alpha: .85))),
        if (progress != null) ...[
          const SizedBox(height: S.x3),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: .25),
              color: Colors.white,
            ),
          ),
        ],
      ]),
    );
  }

  Widget _listCard(P p, PrayerSettings s, DateTime now) {
    final day = s.today(now);
    final next = s.copyWith(enabled: true, prayers: Prayer.values.toSet())
        .nextPrayerAfter(now);
    return Surface(
      child: Column(children: [
        for (var i = 0; i < Prayer.values.length; i++) ...[
          if (i > 0) Container(height: 0.5, color: p.line),
          Builder(builder: (_) {
            final pr = Prayer.values[i];
            final at = day.of(pr);
            final isNext = next != null && next.prayer == pr &&
                next.at.day == at.day;
            final passed = !at.isAfter(now);
            final col = passed ? p.ink3 : p.ink;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: S.x3),
              child: Row(children: [
                Expanded(
                  child: Text(pr.label,
                      style: F.body.copyWith(
                          color: col,
                          fontWeight:
                              isNext ? FontWeight.w600 : FontWeight.w400)),
                ),
                Text(_clock(at), style: F.body.copyWith(color: col)),
                const SizedBox(width: S.x3),
                Icon(
                    s.enabled && s.prayers.contains(pr)
                        ? LucideIcons.bellRing
                        : LucideIcons.bellOff,
                    size: 16,
                    color: isNext ? p.on(C.green) : p.ink3),
              ]),
            );
          }),
        ],
      ]),
    );
  }
}

// ── Health ────────────────────────────────────────────────────────────────────

class SalahHealthHome extends StatefulWidget {
  const SalahHealthHome({super.key});

  @override
  State<SalahHealthHome> createState() => _HealthState();
}

class _HealthState extends State<SalahHealthHome> with RevisionReload {
  HomeData? _d;
  SleepData? _sleep;
  num? _hrv;
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
    final t = beginRead(#healthHome);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final d = await HomeData.load(repo);
      final sl = await SleepData.load(repo);
      num? hrv;
      if (sl.day != null) {
        final heart = await repo.getDayHeart(sl.day!);
        hrv = (heart['hrv'] as Map?)?['rmssd'] as num?;
      }
      if (!mounted || !stillNewest(#healthHome, t)) return;
      setState(() {
        _d = d;
        _sleep = sl;
        _hrv = hrv;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final d = _d;
    final night = _sleep?.night ?? const <String, dynamic>{};
    final rec = d?.readiness.value;
    final resp = (night['resp'] as Map?)?['value'] as num?;
    final sleepHr = (night['nocturnal'] as Map?)?['sleeping_hr_avg'] as num?;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x10),
        children: [
          _title(p, 'Health', 'How recovered your body is'),
          const SizedBox(height: S.x4),
          if (_loading && d == null)
            const SizedBox(height: 200)
          else ...[
            _ringCard(p,
                fraction: rec == null ? null : rec.toDouble() / 100,
                center: rec == null ? '—' : '${rec.round()}',
                sub: 'recovery',
                label: 'Ready today',
                big: rec == null
                    ? '—'
                    : rec >= 67
                        ? 'Good'
                        : rec >= 34
                            ? 'Fair'
                            : 'Low',
                note: rec == null
                    ? 'Needs about 2 weeks of nights to learn your normal'
                    : null),
            const SizedBox(height: S.x3),
            _twoUp(
              _stat(p, 'Resting HR', _num(d?.rhr.value), 'bpm'),
              _stat(p, 'HRV', _num(_hrv), 'ms'),
            ),
            const SizedBox(height: S.x3),
            _twoUp(
              _stat(p, 'Sleeping HR', _num(sleepHr), 'bpm'),
              _stat(p, 'Breathing',
                  resp == null ? '—' : resp.toStringAsFixed(1), 'per min'),
            ),
            const SizedBox(height: S.x2),
            Text('Measured overnight. Scores are estimates, not medical advice.',
                style: F.cap.copyWith(color: p.ink3)),
          ],
          const SizedBox(height: S.x4),
          _link(p, LucideIcons.heartPulse, 'More health detail',
              'Stress, blood oxygen, temperature, journal',
              () => _open(c, const HealthScreen())),
        ],
      ),
    );
  }
}
