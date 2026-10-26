// Salah Fit — the prayer alarm screen.
//
// Shows today's five prayer times for the chosen place and lets the user
// switch each prayer's band buzz on or off. The band has one alarm slot, so
// the arming code chains through the enabled prayers one at a time (see
// state/alarm_schedule.dart); this screen only edits the preferences and
// asks AppState to re-arm.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../prayer/prayer_settings.dart';
import '../../prayer/prayer_times.dart';
import '../../state/app_state.dart';
import '../screens/metric_detail.dart' show detailLinkRow;
import '../ui2.dart';
import 'profile.dart' show SetRow, settingsGroup;

class PrayerScreen extends StatefulWidget {
  const PrayerScreen({super.key});

  @override
  State<PrayerScreen> createState() => _PrayerScreenState();
}

class _PrayerScreenState extends State<PrayerScreen> {
  PrayerSettings? _s;
  String? _note;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final s = await PrayerSettings.load();
    if (!mounted) return;
    setState(() => _s = s);
    // Automatic location: may ask for permission the first time.
    final moved = await PrayerSettings.refreshAuto(ask: true);
    if (moved != null && mounted) await _update(moved);
  }

  Future<void> _update(PrayerSettings next) async {
    setState(() {
      _s = next;
      _note = null;
    });
    await next.save();
    if (!mounted) return;
    final armed = await context.read<AppState>().rearmPrayerAlarms();
    if (!mounted) return;
    setState(() => _note = armed
        ? null
        : 'Saved. The band will be updated the next time it connects.');
  }

  Future<void> _useAutomatic() async {
    final s = _s;
    if (s == null) return;
    await s.copyWith(auto: true).save();
    final moved = await PrayerSettings.refreshAuto(ask: true);
    if (!mounted) return;
    if (moved != null) {
      await _update(moved);
    } else {
      setState(() {
        _s = s.copyWith(auto: true);
        _note = 'Turn on location permission so prayer times follow you.';
      });
    }
  }

  String _hhmm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    return '$h:$m ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final s = _s;
    final now = DateTime.now();
    final day = s?.today(now);
    final next = s?.copyWith(enabled: true).nextPrayerAfter(now);
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: S.x4),
            child: NavBar('Prayer alarms',
                sub: 'The band vibrates at each prayer time'),
          ),
          Expanded(
            child: s == null || day == null
                ? const SizedBox.shrink()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(S.x4, 0, S.x4, S.x10),
                    children: [
                      if (next != null)
                        Surface(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('NEXT PRAYER',
                                    style: F.over.copyWith(color: p.ink3)),
                                const SizedBox(height: S.x1),
                                Text('${next.prayer.label}  ${_hhmm(next.at)}',
                                    style: F.n34.copyWith(color: p.ink)),
                                Text(s.cityName,
                                    style: F.cap.copyWith(color: p.ink2)),
                              ]),
                        ),
                      if (_note case final note?) ...[
                        const SizedBox(height: S.x3),
                        StatusCard(note, '', icon: LucideIcons.info),
                      ],
                      settingsGroup(c, 'Band alarm', [
                        SetRow(LucideIcons.bellRing, C.green,
                            'Vibrate at prayer times',
                            sub: 'Uses the band\'s alarm, so it works even '
                                'when the phone is away',
                            chevron: false,
                            trailing: Switch(
                                value: s.enabled,
                                onChanged: (v) =>
                                    _update(s.copyWith(enabled: v)))),
                      ]),
                      settingsGroup(c, 'Today', [
                        for (final pr in Prayer.values)
                          SetRow(LucideIcons.moonStar, C.indigo, pr.label,
                              chevron: false,
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_hhmm(day.of(pr)),
                                        style:
                                            F.body.copyWith(color: p.ink2)),
                                    const SizedBox(width: S.x2),
                                    Switch(
                                        value: s.prayers.contains(pr),
                                        onChanged: (v) {
                                          final set = {...s.prayers};
                                          v ? set.add(pr) : set.remove(pr);
                                          _update(s.copyWith(prayers: set));
                                        }),
                                  ])),
                        SetRow(LucideIcons.sunrise, C.orange, 'Sunrise',
                            value: _hhmm(day.sunrise),
                            sub: 'Shown for reference, no alarm',
                            chevron: false),
                      ]),
                      settingsGroup(c, 'Location', [
                        SetRow(LucideIcons.mapPin, C.blue, 'Automatic',
                            sub: s.auto
                                ? 'Follows your phone · now ${s.cityName}'
                                : 'Follow your phone\'s location',
                            value: s.auto ? 'Selected' : '',
                            chevron: false,
                            onTap: _useAutomatic),
                        for (final city in kPrayerCities)
                          SetRow(LucideIcons.mapPin, C.blue, city.name,
                              value: !s.auto && s.cityName == city.name
                                  ? 'Selected'
                                  : '',
                              chevron: false,
                              onTap: () => _update(s.copyWith(
                                  auto: false,
                                  cityName: city.name,
                                  lat: city.lat,
                                  lng: city.lng))),
                      ]),
                      settingsGroup(c, 'Calculation', [
                        SetRow(LucideIcons.sun, C.yellow, 'Asr method',
                            value: s.asrFactor == 2 ? 'Hanafi' : 'Shafi\'i',
                            sub: 'Tap to switch',
                            chevron: false,
                            onTap: () => _update(s.copyWith(
                                asrFactor: s.asrFactor == 2 ? 1 : 2))),
                        const SetRow(LucideIcons.moonStar, C.teal,
                            'Fajr and Isha angles',
                            value: '18° (Karachi)', chevron: false),
                      ]),
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}

/// Home's door onto prayer alarms: the next prayer and its time, or an
/// invitation to set them up. Also the quiet place automatic location gets
/// refreshed (no permission prompt here, at most every few hours), so prayer
/// times follow the user when they travel.
Widget prayerDoor(BuildContext c) => const _PrayerDoor();

class _PrayerDoor extends StatefulWidget {
  const _PrayerDoor();

  @override
  State<_PrayerDoor> createState() => _PrayerDoorState();
}

class _PrayerDoorState extends State<_PrayerDoor> {
  PrayerSettings? _s;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await PrayerSettings.load();
    if (!mounted) return;
    setState(() => _s = s);
    final moved = await PrayerSettings.refreshAuto();
    if (moved == null || !mounted) return;
    setState(() => _s = moved);
    await context.read<AppState>().rearmPrayerAlarms();
  }

  @override
  Widget build(BuildContext c) {
    final s = _s;
    if (s == null) return const SizedBox.shrink();
    final next = s.nextPrayerAfter(DateTime.now());
    final sub = next == null
        ? 'Set up prayer alarms on the band'
        : '${next.prayer.label} at ${_clock(next.at)} · ${s.cityName}';
    return detailLinkRow(c, LucideIcons.moonStar, 'Next prayer', sub, () async {
      await Navigator.of(c).push(MaterialPageRoute(builder: (_) => const PrayerScreen()));
      if (mounted) _load();
    });
  }
}

String _clock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}
