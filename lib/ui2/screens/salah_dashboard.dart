// Salah Fit — the Dashboard tab: a short glimpse of sleep, health and
// activity. Each card opens its own tab. Nothing is computed here but
// formatting; a missing input shows "—".

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../state/app_state.dart';
import '../app_shell.dart' show ShellDomain, shellJump;
import '../profile/profile.dart' show ProfileAvatar;
import '../revision.dart';
import '../ui2.dart';
import 'home_screen.dart' show HomeData, envValue, repoOf;
import 'salah_dashboards.dart' show DataRefresher, SyncStatusBar;
import 'salah_sleep_home.dart' show kHijriMonths, salahHijri;
import 'sleep_detail.dart' show SleepData;

class SalahDashboard extends StatefulWidget {
  const SalahDashboard({super.key});

  @override
  State<SalahDashboard> createState() => _DashState();
}

class _DashState extends State<SalahDashboard> with RevisionReload {
  SleepData? _sleep;
  HomeData? _home;
  num? _hrv, _perf;
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
    final t = beginRead(#dashHome);
    if (repo == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      final sl = await SleepData.load(repo);
      final home = await HomeData.load(repo);
      num? hrv;
      if (sl.day != null) {
        final heart = await repo.getDayHeart(sl.day!);
        hrv = (heart['hrv'] as Map?)?['rmssd'] as num?;
      }
      final ins = await repo.getInsights();
      final coach = ins['sleep_coach'];
      final perf =
          envValue(coach is Map ? coach['performance'] : null)?['pct'] as num?;
      if (!mounted || !stillNewest(#dashHome, t)) return;
      setState(() {
        _sleep = sl;
        _home = home;
        _hrv = hrv;
        _perf = perf;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _go(ShellDomain d) => shellJump.value = d;

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final name = c
        .select<AppState, String?>((a) => a.user?['name'] as String?)
        ?.trim();
    final now = DateTime.now();
    final h = salahHijri(now);
    final date =
        '${_wd[now.weekday - 1]}, ${now.day} ${_mo[now.month - 1]} · ${h.day} ${kHijriMonths[h.month - 1]}';
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x5, S.x4, S.x5, S.x10),
        children: [
          DataRefresher(onChange: _load),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
          ]),
          const SizedBox(height: S.x5),
          if (_loading && _sleep == null)
            const SizedBox(height: 240)
          else ...[
            _sleepCard(c, p),
            const SizedBox(height: S.x4),
            _healthCard(c, p),
            const SizedBox(height: S.x4),
            _activityCard(c, p),
          ],
        ],
      ),
    );
  }

  // ── cards ─────────────────────────────────────────────────────────────────

  Widget _sleepCard(BuildContext c, P p) {
    final n = _sleep?.night ?? const <String, dynamic>{};
    final has = _sleep?.hasNight ?? false;
    final dur = n['duration_min'] as num?;
    final eff = n['efficiency'] as num?;
    final on = _ts(n['onset_ts']), off = _ts(n['wake_ts']);
    final ringV = _perf ?? (eff == null ? null : eff * 100);
    final stages = <(String, num?, Color)>[
      ('Deep', n['deep_min'] as num?, C.green),
      ('REM', n['rem_min'] as num?, C.indigo),
      ('Light', n['light_min'] as num?, C.sky),
      ('Awake', n['awake_min'] as num?, C.orange),
    ];
    final total = stages.fold<double>(
        0, (s, e) => s + (e.$2 == null ? 0 : e.$2!.toDouble()));
    return _card(c, p, 'Sleep', LucideIcons.moon, ShellDomain.today,
        child: !has
            ? Text('Last night is not in yet. It appears once your band has synced and the app has worked it out.',
                style: F.cap.copyWith(color: p.ink2))
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  _ring(p, ringV == null ? null : ringV / 100,
                      ringV == null ? '—' : '${ringV.round()}%'),
                  const SizedBox(width: S.x4),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dur == null ? '—' : _hm(dur.round()),
                              style: F.n34.copyWith(color: p.ink)),
                          Text('${_clock(on)} to ${_clock(off)}',
                              style: F.cap.copyWith(color: p.ink2)),
                        ]),
                  ),
                ]),
                if (total > 0) ...[
                  const SizedBox(height: S.x4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: SizedBox(
                      height: 10,
                      child: Row(children: [
                        for (final s in stages)
                          if ((s.$2 ?? 0) > 0)
                            Expanded(
                                flex: (s.$2!.toDouble() * 10).round(),
                                child: ColoredBox(color: s.$3)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: S.x2),
                  Text(
                      [
                        for (final s in stages.take(3))
                          if (s.$2 != null) '${s.$1} ${_hm(s.$2!.round())}'
                      ].join(' · '),
                      style: F.cap.copyWith(color: p.ink3)),
                ],
              ]));
  }

  Widget _healthCard(BuildContext c, P p) {
    final rec = _home?.readiness.value;
    final rhr = _home?.rhr.value;
    final resp = ((_sleep?.night ?? const {})['resp'] as Map?)?['value'] as num?;
    return _card(c, p, 'Health', LucideIcons.heartPulse, ShellDomain.health,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _ring(p, rec == null ? null : rec.toDouble() / 100,
                rec == null ? '—' : '${rec.round()}'),
            const SizedBox(width: S.x4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        rec == null
                            ? 'Recovery not scored yet'
                            : rec >= 67
                                ? 'Good recovery'
                                : rec >= 34
                                    ? 'Fair recovery'
                                    : 'Low recovery',
                        style: F.head.copyWith(color: p.ink)),
                    if (rec == null)
                      Text('Needs about 2 weeks of nights',
                          style: F.cap.copyWith(color: p.ink3)),
                  ]),
            ),
          ]),
          const SizedBox(height: S.x4),
          Row(children: [
            _mini(p, 'Resting HR', rhr == null ? '—' : '${rhr.round()}', 'bpm'),
            _mini(p, 'HRV', _hrv == null ? '—' : '${_hrv!.round()}', 'ms'),
            _mini(p, 'Breathing',
                resp == null ? '—' : resp.toStringAsFixed(1), '/min'),
          ]),
        ]));
  }

  Widget _activityCard(BuildContext c, P p) {
    final strain = _home?.strain.value;
    final steps = _home?.steps.value;
    final goal = _home?.stepGoal ?? 10000;
    final kcal = _home?.calories.value;
    return _card(c, p, 'Activity', LucideIcons.dumbbell, ShellDomain.activity,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _ring(p, strain == null ? null : strain.toDouble() / 21,
                strain == null ? '—' : strain.toStringAsFixed(1)),
            const SizedBox(width: S.x4),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Day strain', style: F.head.copyWith(color: p.ink)),
                    Text('out of 21', style: F.cap.copyWith(color: p.ink3)),
                  ]),
            ),
          ]),
          const SizedBox(height: S.x4),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(
              flex: 2,
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Steps · goal $goal',
                        style: F.cap.copyWith(color: p.ink3)),
                    const SizedBox(height: S.x1),
                    Text(steps == null ? '—' : steps.round().toString(),
                        style: F.n24.copyWith(color: p.ink)),
                    const SizedBox(height: S.x2),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: steps == null
                            ? 0
                            : (steps / goal).clamp(0.0, 1.0).toDouble(),
                        minHeight: 6,
                        backgroundColor: p.track,
                        color: p.on(C.green),
                      ),
                    ),
                  ]),
            ),
            const SizedBox(width: S.x4),
            _mini(p, 'Active', kcal == null ? '—' : '${kcal.round()}', 'kcal'),
          ]),
        ]));
  }

  // ── pieces ────────────────────────────────────────────────────────────────

  Widget _card(BuildContext c, P p, String title, IconData icon, ShellDomain to,
          {required Widget child}) =>
      Surface(
        onTap: () => _go(to),
        pad: const EdgeInsets.all(S.x5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(icon, size: 18, color: p.on(C.green)),
            const SizedBox(width: S.x2),
            Expanded(
                child: Text(title,
                    style: F.head.copyWith(color: p.ink))),
            Text('Open', style: F.cap.copyWith(color: p.on(C.green))),
            Icon(LucideIcons.chevronRight, size: 16, color: p.on(C.green)),
          ]),
          const SizedBox(height: S.x4),
          child,
        ]),
      );

  Widget _ring(P p, double? v, String label) => SizedBox(
        width: 76,
        height: 76,
        child: CustomPaint(
          painter: _MiniRing(v, p.track, p.on(C.green)),
          child: Center(
              child: Text(label, style: F.head.copyWith(color: p.ink))),
        ),
      );

  Widget _mini(P p, String k, String v, String unit) => Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k, style: F.cap.copyWith(color: p.ink3)),
          const SizedBox(height: S.x1),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(v, style: F.n24.copyWith(color: p.ink)),
            const SizedBox(width: 3),
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(unit, style: F.cap.copyWith(color: p.ink3)),
            ),
          ]),
        ]),
      );
}

class _MiniRing extends CustomPainter {
  final double? v;
  final Color track, color;
  const _MiniRing(this.v, this.track, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    const w = 8.0;
    final r = (Offset.zero & size).deflate(w / 2);
    canvas.drawArc(
        r,
        0,
        2 * math.pi,
        false,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = w);
    final x = v;
    if (x == null || x <= 0) return;
    canvas.drawArc(
        r,
        -math.pi / 2,
        2 * math.pi * x.clamp(0.0, 1.0),
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = w);
  }

  @override
  bool shouldRepaint(_MiniRing o) =>
      o.v != v || o.color != color || o.track != track;
}

DateTime? _ts(Object? v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.round() * 1000) : null;

String _hm(int m) => m < 60 ? '${m}m' : '${m ~/ 60}h ${(m % 60).toString().padLeft(2, '0')}m';

String _clock(DateTime? t) {
  if (t == null) return '—';
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

const _wd = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const _mo = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December'
];
