// Multi-day trend card: the last 14 days as bars, this week against last
// week, and a plain verdict — improving, declining or steady.
import 'package:flutter/material.dart';

import '../revision.dart';
import '../ui2.dart';
import 'home_screen.dart' show repoOf;
import 'salah_dashboards.dart' show recoveryColor, kSleepColor, kStrainColor;

enum TrendKind { sleep, recovery, strain }

class DaysTrendCard extends StatefulWidget {
  final TrendKind kind;
  const DaysTrendCard(this.kind, {super.key});
  @override
  State<DaysTrendCard> createState() => _DaysTrendCardState();
}

class _DaysTrendCardState extends State<DaysTrendCard> with RevisionReload {
  static const _days = 14;
  List<double?> _v = const []; // oldest → newest, one slot per calendar day
  bool _loaded = false;

  Color get _accent => widget.kind == TrendKind.sleep
      ? kSleepColor
      : widget.kind == TrendKind.strain
          ? kStrainColor
          : const Color(0xFF16A34A);

  String get _key => switch (widget.kind) {
        TrendKind.sleep => 'sleep',
        TrendKind.recovery => 'recovery',
        TrendKind.strain => 'strain',
      };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => reload());
  }

  @override
  void reload() async {
    final repo = repoOf(context);
    final t = beginRead("trend${widget.kind.name}");
    if (repo == null) return;
    try {
      final chart = await repo.getChart(_key);
      final byDay = <String, double>{};
      for (final e in (chart['points'] as List? ?? const [])) {
        if (e is Map && e['t'] is num && e['v'] is num) {
          final d = DateTime.fromMillisecondsSinceEpoch(
              (e['t'] as num).toInt() * 1000);
          byDay['${d.year}-${d.month}-${d.day}'] = (e['v'] as num).toDouble();
        }
      }
      final now = DateTime.now();
      final out = <double?>[];
      for (var i = _days - 1; i >= 0; i--) {
        final d = DateTime(now.year, now.month, now.day - i);
        out.add(byDay['${d.year}-${d.month}-${d.day}']);
      }
      if (!stillNewest("trend${widget.kind.name}", t)) return;
      setState(() {
        _v = out;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  static double? _avg(Iterable<double?> xs) {
    final l = [for (final x in xs) if (x != null) x];
    return l.length < 3 ? null : l.reduce((a, b) => a + b) / l.length;
  }

  String _fmt(double v) => switch (widget.kind) {
        TrendKind.sleep => '${v ~/ 60}h ${(v % 60).round()}m',
        TrendKind.recovery => '${v.round()}%',
        TrendKind.strain => v.toStringAsFixed(1),
      };

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final title = switch (widget.kind) {
      TrendKind.sleep => 'Sleep over 14 days',
      TrendKind.recovery => 'Recovery over 14 days',
      TrendKind.strain => 'Strain over 14 days',
    };
    final have = _v.whereType<double>().length;
    final top = switch (widget.kind) {
      TrendKind.sleep => 600.0,
      TrendKind.recovery => 100.0,
      TrendKind.strain => 21.0,
    };
    final thisWk = _avg(_v.skip(_days - 7));
    final lastWk = _avg(_v.take(_days - 7));
    String verdict;
    Color vc = p.ink3;
    if (!_loaded) {
      verdict = '';
    } else if (thisWk == null || lastWk == null) {
      verdict = have == 0
          ? 'No days scored yet'
          : 'Need 3 scored days in each week to compare ($have so far)';
    } else {
      final ch = (thisWk - lastWk) / (lastWk == 0 ? 1 : lastWk);
      final up = widget.kind != TrendKind.strain; // for strain, just direction
      if (ch.abs() < 0.05) {
        verdict = 'Steady — ${_fmt(thisWk)} avg this week, ${_fmt(lastWk)} last week';
      } else if (ch > 0) {
        verdict =
            '${up ? 'Improving' : 'Higher'} — ${_fmt(thisWk)} avg this week vs ${_fmt(lastWk)} last week';
        vc = up ? C.green : p.ink2;
      } else {
        verdict =
            '${up ? 'Declining' : 'Lower'} — ${_fmt(thisWk)} avg this week vs ${_fmt(lastWk)} last week';
        vc = up ? const Color(0xFFB45309) : p.ink2;
      }
      if (widget.kind == TrendKind.sleep && thisWk < 7 * 60) {
        verdict += ' · below 7h, you are running short';
      }
    }
    return Surface(
      pad: const EdgeInsets.all(S.x5),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: F.head.copyWith(color: p.ink)),
        const SizedBox(height: S.x1),
        Text(verdict, style: F.cap.copyWith(color: vc)),
        const SizedBox(height: S.x3),
        SizedBox(
          height: 90,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < _v.length; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: _v[i] == null
                      ? 3
                      : (90 * (_v[i]! / top)).clamp(4.0, 90.0),
                  decoration: BoxDecoration(
                    color: _v[i] == null
                        ? p.track
                        : widget.kind == TrendKind.recovery
                            ? recoveryColor(_v[i]!)
                            : (i == _v.length - 1
                                ? _accent
                                : _accent.withValues(alpha: .45)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ],
          ]),
        ),
        const SizedBox(height: S.x1),
        Row(children: [
          Text('14 days ago', style: F.cap.copyWith(color: p.ink3)),
          const Spacer(),
          Text('Today', style: F.cap.copyWith(color: p.ink3)),
        ]),
      ]),
    );
  }
}
