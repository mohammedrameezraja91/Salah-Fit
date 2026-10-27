// Salah Fit — the Sleep tab: the whole night on one page.
//
// Score, bed and wake, the stage timeline, stages, night quality, overnight
// body, tonight's plan, naps and the last nights. Every card has a link to
// that section's own page with the full analysis. Every number comes from the
// same repository reads the detailed screens use; nothing is computed here but
// formatting. A missing input shows "—", never a guess.

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../prayer/prayer_settings.dart';
import '../../prayer/prayer_times.dart';
import '../app_shell.dart' show ShellDomain, shellJump;
import '../charts.dart' show Hypnogram, SleepStage;
import '../profile/profile.dart' show ProfileAvatar;
import '../revision.dart';
import '../ui2.dart';
import 'home_screen.dart' show envValue, repoOf;
import 'naps.dart' show NapsData, NapsScreen;
import 'salah_dashboards.dart' show DataRefresher, SyncStatusBar;
import 'sleep_detail.dart' show SleepData, SleepDetail;
import 'wellness_screen.dart' show WellnessScreen;
import '../../state/app_state.dart';
import 'package:provider/provider.dart';

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
  final NapsData? naps;
  const _Night(this.sleep, this.hrv, this.performancePct, this.prayer, this.naps);
}

class _SalahSleepHomeState extends State<SalahSleepHome> with RevisionReload {
  _Night? _n;
  bool _loading = true;
  String? _day; // null = the latest night

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
      final d = await SleepData.load(repo, want: _day);
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
      NapsData? naps;
      try {
        if (d.day != null) naps = await NapsData.load(repo, want: d.day);
      } catch (_) {}
      if (!mounted || !stillNewest(#sleepHome, t)) return;
      setState(() {
        _n = _Night(d, hrv, perf, prayer, naps);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _step(int dir) {
    final days = _n?.sleep.days ?? const <String>[];
    final cur = _n?.sleep.day;
    if (cur == null) return;
    final i = days.indexOf(cur); // newest first
    final j = i - dir; // dir +1 = newer
    if (i < 0 || j < 0 || j >= days.length) return;
    _day = days[j];
    _load();
  }

  void _push(BuildContext c, Widget screen) => Navigator.of(c)
      .push(MaterialPageRoute<void>(builder: (_) => screen));

  void _pushScaffold(BuildContext c, Widget screen) =>
      _push(c, Builder(builder: (ctx) => Scaffold(
          backgroundColor: P.of(ctx).bg, body: SafeArea(child: screen))));

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final n = _n;
    final night = n?.sleep.night ?? const <String, dynamic>{};
    final hasNight = n?.sleep.hasNight ?? false;
    final day = n?.sleep.day;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(S.x5, S.x4, S.x5, S.x10),
        children: [
          DataRefresher(onChange: _load),
          _header(c, p),
          const SizedBox(height: S.x4),
          if (_loading && n == null)
            const SizedBox(height: 240)
          else if (!hasNight)
            _emptyCard(c, p)
          else ...[
            _heroCard(c, p, n!, night),
            const SizedBox(height: S.x3),
            _timelineCard(c, p, n, night, day),
            const SizedBox(height: S.x3),
            _stagesCard(c, p, night),
            const SizedBox(height: S.x3),
            _qualityRow(c, p, n, night),
            const SizedBox(height: S.x3),
            _vitalsCard(c, p, n, night),
          ],
          if (n != null) ...[
            const SizedBox(height: S.x3),
            _planCard(c, p, n, day),
            const SizedBox(height: S.x3),
            _napsCard(c, p, n, day),
            const SizedBox(height: S.x3),
            _weekCard(c, p, n, night, day),
          ],
        ],
      ),
    );
  }

  // ── pieces ────────────────────────────────────────────────────────────────

  Widget _header(BuildContext c, P p) {
    final days = _n?.sleep.days ?? const <String>[];
    final cur = _n?.sleep.day;
    final i = cur == null ? -1 : days.indexOf(cur);
    final canOlder = i >= 0 && i + 1 < days.length;
    final canNewer = i > 0;
    final label = cur == null
        ? 'Last night'
        : i == 0
            ? 'Last night'
            : _dayLabel(cur);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Sleep', style: F.t1.copyWith(color: p.ink)),
            const SyncStatusBar(),
          ]),
        ),
        const ProfileAvatar(accent: C.domHome),
      ]),
      const SizedBox(height: S.x3),
      Row(children: [
        _arrow(p, LucideIcons.chevronLeft, canOlder ? () => _step(-1) : null),
        Expanded(
            child: Text(label,
                textAlign: TextAlign.center,
                style: F.body.copyWith(color: p.ink))),
        _arrow(p, LucideIcons.chevronRight, canNewer ? () => _step(1) : null),
      ]),
    ]);
  }

  Widget _arrow(P p, IconData i, VoidCallback? onTap) => Pressable(
        onTap: onTap,
        semanticLabel: 'Change night',
        child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(i, size: 20, color: onTap == null ? p.line : p.ink2)),
      );

  Widget _emptyCard(BuildContext c, P p) {
    final working = c.select<AppState, bool>((a) => a.deriving || a.syncingNow);
    return Surface(
      child: Row(children: [
        Icon(LucideIcons.bedDouble, color: p.on(C.green), size: 28),
        const SizedBox(width: S.x3),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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

  Widget _section(BuildContext c, P p, String title, {required Widget child, VoidCallback? onMore, String more = 'Details'}) =>
      Surface(
        pad: const EdgeInsets.all(S.x5),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(title, style: F.head.copyWith(color: p.ink))),
            if (onMore != null)
              Pressable(
                onTap: onMore,
                semanticLabel: '$title $more',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: S.x2),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(more, style: F.cap.copyWith(color: p.on(C.green))),
                    Icon(LucideIcons.chevronRight, size: 16, color: p.on(C.green)),
                  ]),
                ),
              ),
          ]),
          const SizedBox(height: S.x3),
          child,
        ]),
      );

  Widget _heroCard(BuildContext c, P p, _Night n, Map<String, dynamic> night) {
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
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
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
              Text('Total sleep', style: F.cap.copyWith(color: p.ink3)),
              Text(dur == null ? '—' : _hm(dur.round()),
                  style: F.n34.copyWith(color: p.ink)),
              if (vsUsual != null)
                Text(vsUsual, style: F.cap.copyWith(color: p.on(C.green))),
            ]),
          ),
        ]),
        const SizedBox(height: S.x4),
        Container(height: 1, color: p.line),
        const SizedBox(height: S.x3),
        Row(children: [
          Expanded(child: _kv(p, LucideIcons.moon, 'Bedtime', _clock(on))),
          Expanded(child: _kv(p, LucideIcons.sunrise, 'Woke up', _clock(off))),
          Expanded(
              child: _kv(p, LucideIcons.bed, 'In bed',
                  night['in_bed_min'] is num
                      ? _hm((night['in_bed_min'] as num).round())
                      : '—')),
        ]),
        if (fajrNote != null) ...[
          const SizedBox(height: S.x3),
          Text(fajrNote, style: F.cap.copyWith(color: p.ink2)),
        ],
      ]),
    );
  }

  Widget _timelineCard(BuildContext c, P p, _Night n,
      Map<String, dynamic> night, String? day) {
    final stages = n.sleep.stages;
    final on = _ts(night['onset_ts']);
    final off = _ts(night['wake_ts']);
    final mid = (on != null && off != null)
        ? on.add(Duration(seconds: off.difference(on).inSeconds ~/ 2))
        : null;
    return _section(c, p, 'Through the night',
        more: 'Timeline',
        onMore: day == null ? null : () => _push(c, SleepDetail(day: day)),
        child: stages.length < 2
            ? Text('The timeline is not available for this night',
                style: F.cap.copyWith(color: p.ink3))
            : Column(children: [
                SizedBox(
                  height: 112,
                  width: double.infinity,
                  child: CustomPaint(
                      painter: _Lanes(stages, Hypnogram.cols(p), p.line)),
                ),
                const SizedBox(height: S.x2),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(_clock(on), style: F.cap.copyWith(color: p.ink3)),
                  Text(_clock(mid), style: F.cap.copyWith(color: p.ink3)),
                  Text(_clock(off), style: F.cap.copyWith(color: p.ink3)),
                ]),
                const SizedBox(height: S.x2),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  for (final s in SleepStage.values)
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: Hypnogram.cols(p)[s], shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(_stageName(s), style: F.cap.copyWith(color: p.ink3)),
                    ]),
                ]),
              ]));
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
    return _section(c, p, 'Sleep stages',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
        ]));
  }

  Widget _qualityRow(BuildContext c, P p, _Night n, Map<String, dynamic> night) {
    final eff = night['efficiency'] as num?;
    final wake = n.sleep.awakenings;
    final longest = n.sleep.longestSleepMin;
    Widget tile(String k, String v, String sub) => Expanded(
          child: Surface(
            pad: const EdgeInsets.all(S.x4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(k, style: F.cap.copyWith(color: p.ink3)),
              const SizedBox(height: S.x1),
              Text(v, style: F.n24.copyWith(color: p.ink)),
              Text(sub, style: F.cap.copyWith(color: p.ink3)),
            ]),
          ),
        );
    return Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      tile('Asleep', eff == null ? '—' : '${(eff * 100).round()}%', 'of time in bed'),
      const SizedBox(width: S.x3),
      tile('Wake-ups', wake == null ? '—' : '${wake.round()}', '5 min or more'),
      const SizedBox(width: S.x3),
      tile('Longest', longest == null ? '—' : _hm(longest.round()), 'unbroken'),
    ]);
  }

  Widget _vitalsCard(BuildContext c, P p, _Night n, Map<String, dynamic> night) {
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
    return _section(c, p, 'Overnight body',
        more: 'Health',
        onMore: () => shellJump.value = ShellDomain.health,
        child: Row(children: [
          cell('Sleeping HR', rhr == null ? '—' : '${rhr.round()}', 'bpm'),
          cell('HRV', n.hrv == null ? '—' : '${n.hrv!.round()}', 'ms'),
          cell('Breathing', resp == null ? '—' : resp.toStringAsFixed(1), '/min'),
        ]));
  }

  Widget _planCard(BuildContext c, P p, _Night n, String? day) {
    final need = n.sleep.need.value;
    final debt = n.sleep.debt.value;
    final bed = n.sleep.bedtime.value;
    Widget row(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: S.x2),
          child: Row(children: [
            Expanded(child: Text(k, style: F.body.copyWith(color: p.ink2))),
            Text(v, style: F.body.copyWith(color: p.ink)),
          ]),
        );
    return _section(c, p, 'Tonight\'s plan',
        more: 'Sleep plan',
        onMore: () => _pushScaffold(c, const WellnessScreen(sleepPlanOnly: true)),
        child: Column(children: [
          row('Sleep you need', need == null ? '—' : _hm(need.round())),
          Container(height: 1, color: p.line),
          row('Sleep debt', debt == null ? '—' : _hm(debt.round())),
          Container(height: 1, color: p.line),
          row('Bedtime tonight', bed == null ? '—' : _clockMin(bed.round())),
        ]));
  }

  Widget _napsCard(BuildContext c, P p, _Night n, String? day) {
    final naps = n.naps?.naps ?? const <Map<String, dynamic>>[];
    return _section(c, p, 'Naps',
        more: 'Naps',
        onMore: day == null ? null : () => _push(c, NapsScreen(day: day)),
        child: naps.isEmpty
            ? Text(
                (n.naps?.judged ?? false)
                    ? 'No naps today. Tap Naps to add one.'
                    : 'Naps appear here. Tap Naps to add one.',
                style: F.cap.copyWith(color: p.ink3))
            : Column(children: [
                for (final nap in naps)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: S.x1),
                    child: Row(children: [
                      Expanded(
                          child: Text(
                              '${_clock(_ts(nap['start']))} – ${_clock(_ts(nap['end']))}',
                              style: F.body.copyWith(color: p.ink))),
                      Text(
                          nap['duration_min'] is num
                              ? _hm((nap['duration_min'] as num).round())
                              : '',
                          style: F.cap.copyWith(color: p.ink3)),
                    ]),
                  ),
              ]));
  }

  Widget _weekCard(BuildContext c, P p, _Night n, Map<String, dynamic> night, String? day) {
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
    return _section(c, p, 'Last ${shown.length} nights',
        more: 'Trends',
        onMore: day == null ? null : () => _push(c, SleepDetail(day: day)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
          Text('Average ${_hm(avg.round())} · line = 7 h goal',
              style: F.cap.copyWith(color: p.ink3)),
        ]));
  }

  Widget _kv(P p, IconData icon, String k, String v) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: p.ink3),
          const SizedBox(width: S.x1),
          Text(k, style: F.cap.copyWith(color: p.ink3)),
        ]),
        const SizedBox(height: S.x1),
        Text(v, style: F.head.copyWith(color: p.ink)),
      ]);
}

/// The stage lanes: awake on top, deep at the bottom, one column per sample.
class _Lanes extends CustomPainter {
  final List<SleepStage?> stages;
  final Map<SleepStage, Color> cols;
  final Color grid;
  const _Lanes(this.stages, this.cols, this.grid);

  @override
  void paint(Canvas canvas, Size size) {
    final laneH = size.height / 4;
    final line = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (var i = 1; i < 4; i++) {
      canvas.drawLine(Offset(0, laneH * i), Offset(size.width, laneH * i), line);
    }
    final w = size.width / stages.length;
    for (var i = 0; i < stages.length; i++) {
      final s = stages[i];
      if (s == null) continue;
      final r = Rect.fromLTWH(i * w, s.index * laneH + 3, math.max(w, 1), laneH - 6);
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(2)),
          Paint()..color = cols[s]!);
    }
  }

  @override
  bool shouldRepaint(_Lanes o) => o.stages != stages || o.cols != cols;
}

String _stageName(SleepStage s) => switch (s) {
      SleepStage.awake => 'Awake',
      SleepStage.rem => 'REM',
      SleepStage.light => 'Light',
      SleepStage.deep => 'Deep',
    };

String _dayLabel(String day) {
  final d = DateTime.tryParse(day);
  if (d == null) return day;
  return '${_weekday(d)}, ${d.day} ${_month(d.month)}';
}

String _clockMin(int minuteOfDay) {
  final h = (minuteOfDay ~/ 60) % 24, m = minuteOfDay % 60;
  final hh = h % 12 == 0 ? 12 : h % 12;
  return '$hh:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';
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

const kHijriMonths = [
  'Muharram', 'Safar', 'Rabi al-Awwal', 'Rabi al-Thani', 'Jumada al-Ula',
  'Jumada al-Thani', 'Rajab', 'Shaban', 'Ramadan', 'Shawwal', 'Dhul Qadah',
  'Dhul Hijjah',
];

/// Tabular (Kuwaiti) Hijri date. Can differ by a day from the local
/// moon-sighting calendar.
({int year, int month, int day}) salahHijri(DateTime g) {
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
