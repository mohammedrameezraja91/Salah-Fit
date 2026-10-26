import '../../l10n/display_text.dart';
// Profile setup.
//
// The audit found this screen promising one thing and enforcing another: the
// copy said "leave a field blank and only that metric stays unknown — never
// guessed", and the validator then refused to continue until all four were
// filled. A promise the form contradicts is worse than no promise, because it
// teaches the user that the honesty copy elsewhere is decoration too.
//
// So: every field is optional except sex, which is the one input with no
// honest default — the analytics coefficient tables key on it and the
// midpoint of two sexes is a third person. Everything else that is blank
// simply withholds the metrics that need it.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/date_text.dart';
import '../../state/app_state.dart';
import '../../state/units_controller.dart';
import '../screens/home_screen.dart' show monthShortName, weekdayShortName;
import '../ui2.dart';

class ProfileSetupScreen extends StatefulWidget {
  /// Called after the profile has been written. The router uses it to let a
  /// deliberately-partial profile through the gate.
  final VoidCallback? onDone;

  const ProfileSetupScreen({super.key, this.onDone});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  @override
  Widget build(BuildContext c) {
    final app = context.read<AppState>();
    return ProfileSetupView(
      initial: app.user ?? const {},
      units: context.watch<UnitsController>(),
      cycleTracking: app.cycleTrackingEnabled,
      onSave: (fields) async {
        await app.updateProfile(fields);
        widget.onDone?.call();
      },
      onCycleTracking: app.setCycleTrackingEnabled,
    );
  }
}

/// The three answers the analytics coefficient tables can take.
///
/// 'other' maps to the non-binary block FOR CALORIES, which is the published
/// mean of the two sex constants. It does NOT for training load: Banister
/// publishes two constants and no third, so `nonbinary` collapses onto the
/// male pair everywhere TRIMP and the 0–21 strain score are computed
/// (`derivation_engine.dart` says so at its collapse). The screen says which,
/// because a woman who picks it is otherwise scored as a man with nothing on
/// screen admitting it.
List<(String, String)> _sexes(BuildContext c) {
  final l = AppLocalizations.of(c);
  return [
    ('m', l?.profileSetupSexMale ?? 'Male'),
    ('f', l?.profileSetupSexFemale ?? 'Female'),
    ('other', l?.profileSetupSexPreferNotToSay ?? 'Prefer not to say'),
  ];
}

class ProfileSetupView extends StatefulWidget {
  final Map<String, dynamic> initial;
  final Future<void> Function(Map<String, dynamic> fields) onSave;

  /// Display units for height and weight. Null is metric, which is also what
  /// the storage is.
  final UnitsController? units;

  /// Cycle tracking, offered here rather than left off in Settings where
  /// nobody found it. [cycleTracking] is the current setting; null leaves the
  /// switch to follow the sex picked (on for female).
  final bool? cycleTracking;
  final Future<void> Function(bool on)? onCycleTracking;

  const ProfileSetupView(
      {super.key,
      required this.onSave,
      this.initial = const {},
      this.units,
      this.cycleTracking,
      this.onCycleTracking});

  @override
  State<ProfileSetupView> createState() => _ProfileSetupViewState();
}

class _ProfileSetupViewState extends State<ProfileSetupView> {
  // Salah Fit: name, height, weight and age on rulers, plus sex. Age and sex
  // drive heart-rate zones, calories and strain; if sex is skipped those
  // metrics abstain until it is set in Profile.
  late final _name =
      TextEditingController(text: (widget.initial['name'] as String?) ?? '');
  late double _heightCm =
      ((widget.initial['height_cm'] as num?) ?? 170).toDouble().clamp(120.0, 220.0);
  late double _weightKg =
      ((widget.initial['weight_kg'] as num?) ?? 70).toDouble().clamp(30.0, 200.0);

  late double _age =
      ((widget.initial['age'] as num?) ?? 30).toDouble().clamp(10.0, 90.0);
  late String? _sex = (widget.initial['sex'] as String?)?.toLowerCase();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _continue() async {
    final name = _name.text.trim();
    await widget.onSave({
      if (name.isNotEmpty) 'name': name,
      'height_cm': _heightCm.round(),
      'weight_kg': _weightKg.round(),
      'age': _age.round(),
      if (_sex != null) 'sex': _sex,
    });
  }

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    final l = AppLocalizations.of(c);
    final initial = _name.text.trim().isEmpty
        ? '?'
        : _name.text.trim().substring(0, 1).toUpperCase();
    return Scaffold(
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(S.x5, S.x4, S.x5, S.x4),
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Step 2 of 2',
                      style: F.cap.copyWith(color: p.ink3)),
                ),
                const SizedBox(height: S.x5),
                Row(children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: p.fill(C.green), shape: BoxShape.circle),
                    child: Text(initial,
                        style: F.t1.copyWith(color: p.inkOnFill)),
                  ),
                  const SizedBox(width: S.x4),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Nice to meet you',
                              style: F.t1.copyWith(color: p.ink)),
                          const SizedBox(height: S.x1),
                          Text('A few details so your numbers fit you',
                              style: F.cap.copyWith(color: p.ink2)),
                        ]),
                  ),
                ]),
                const SizedBox(height: S.x5),
                _Tile(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Your name', style: F.cap.copyWith(color: p.ink3)),
                        TextField(
                          controller: _name,
                          textCapitalization: TextCapitalization.words,
                          style: F.head.copyWith(color: p.ink),
                          decoration: InputDecoration(
                            hintText: 'Your name',
                            hintStyle: F.head.copyWith(color: p.ink3),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding:
                                const EdgeInsets.symmetric(vertical: S.x2),
                          ),
                        ),
                      ]),
                ),
                const SizedBox(height: S.x3),
                _RulerTile(
                  label: 'Height',
                  unit: 'cm',
                  value: _heightCm,
                  min: 120,
                  max: 220,
                  onChanged: (v) => setState(() => _heightCm = v),
                ),
                const SizedBox(height: S.x3),
                _RulerTile(
                  label: 'Weight',
                  unit: 'kg',
                  value: _weightKg,
                  min: 30,
                  max: 200,
                  onChanged: (v) => setState(() => _weightKg = v),
                ),
                const SizedBox(height: S.x3),
                _RulerTile(
                  label: 'Age',
                  unit: 'yrs',
                  value: _age,
                  min: 10,
                  max: 90,
                  onChanged: (v) => setState(() => _age = v),
                ),
                const SizedBox(height: S.x3),
                _Tile(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Sex', style: F.cap.copyWith(color: p.ink3)),
                        const SizedBox(height: S.x2),
                        Row(children: [
                          for (final (code, label) in _sexes(c)) ...[
                            Expanded(
                              child: _Choice(
                                  label: label,
                                  on: _sex == code,
                                  onTap: () => setState(() => _sex = code)),
                            ),
                            if (code != 'other') const SizedBox(width: S.x2),
                          ],
                        ]),
                      ]),
                ),
                const SizedBox(height: S.x4),
                Row(children: [
                  Icon(LucideIcons.lock, size: 14, color: p.ink3),
                  const SizedBox(width: S.x2),
                  Expanded(
                    child: Text(
                        'Stays on your phone. Change anytime in Profile.',
                        style: F.cap.copyWith(color: p.ink3)),
                  ),
                ]),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(S.x5, 0, S.x5, S.x5),
            child: BigButton(l?.actionContinue ?? 'Continue',
                color: C.green, onTap: _continue),
          ),
        ]),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  final Widget child;
  const _Tile({required this.child});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Container(
      padding: const EdgeInsets.fromLTRB(S.x4, S.x3, S.x4, S.x3),
      decoration: BoxDecoration(
          color: p.card, borderRadius: BorderRadius.circular(20)),
      child: child,
    );
  }
}

/// A big number over a ruler you drag sideways. One tick per unit, a label
/// every 10, a light haptic each time the value crosses a whole unit.
class _RulerTile extends StatelessWidget {
  final String label, unit;
  final double value, min, max;
  final ValueChanged<double> onChanged;
  const _RulerTile({
    required this.label,
    required this.unit,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  static const _px = 10.0; // pixels per unit

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return _Tile(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Expanded(child: Text(label, style: F.cap.copyWith(color: p.ink3))),
          Text('${value.round()}', style: F.n48.copyWith(color: p.ink)),
          const SizedBox(width: S.x1),
          Padding(
            padding: const EdgeInsets.only(bottom: S.x2),
            child: Text(unit, style: F.body.copyWith(color: p.ink3)),
          ),
        ]),
        const SizedBox(height: S.x2),
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) {
            final next = (value - d.delta.dx / _px).clamp(min, max);
            if (next.round() != value.round()) {
              HapticFeedback.selectionClick();
            }
            onChanged(next);
          },
          onHorizontalDragEnd: (_) => onChanged(value.roundToDouble()),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: CustomPaint(
              painter: _RulerPainter(
                value: value,
                min: min,
                max: max,
                px: _px,
                tick: p.ink3,
                label: p.ink3,
                pointer: p.on(C.green),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _RulerPainter extends CustomPainter {
  final double value, min, max, px;
  final Color tick, label, pointer;
  _RulerPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.px,
    required this.tick,
    required this.label,
    required this.pointer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final paint = Paint()
      ..color = tick
      ..strokeWidth = 1;
    final first = (value - cx / px).floor();
    final last = (value + cx / px).ceil();
    for (var u = first; u <= last; u++) {
      if (u < min || u > max) continue;
      final x = cx + (u - value) * px;
      final major = u % 10 == 0, mid = u % 5 == 0;
      final h = major ? 22.0 : (mid ? 15.0 : 9.0);
      canvas.drawLine(Offset(x, 0), Offset(x, h), paint);
      if (major) {
        final tp = TextPainter(
          text: TextSpan(
              text: '$u', style: F.cap.copyWith(color: label, fontSize: 11)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(x - tp.width / 2, 28));
      }
    }
    final pp = Paint()
      ..color = pointer
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(cx, 0), Offset(cx, 26), pp);
  }

  @override
  bool shouldRepaint(_RulerPainter old) =>
      old.value != value || old.tick != tick || old.pointer != pointer;
}

class _Choice extends StatelessWidget {
  final String label;
  final bool on;
  final VoidCallback onTap;
  const _Choice({required this.label, required this.on, required this.onTap});

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: Container(
        constraints: const BoxConstraints(minHeight: S.tap),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: S.x2, vertical: S.x2),
        decoration: BoxDecoration(
          color: on ? p.wash(C.green) : p.card,
          borderRadius: R.rMd,
          border: Border.all(color: on ? p.on(C.green) : p.line),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: F.cap.copyWith(
                color: on ? p.on(C.green) : p.ink2,
                fontWeight: on ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label, unit, consequence;
  const _Field(this.controller, this.label, this.unit, this.consequence);

  @override
  Widget build(BuildContext c) {
    final p = P.of(c);
    return Padding(
      padding: const EdgeInsets.only(bottom: S.x4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label, style: F.over.copyWith(color: p.ink3))),
          Text(AppLocalizations.of(c)?.profileSetupOptional ?? 'OPTIONAL',
              style: F.over.copyWith(color: p.ink3)),
        ]),
        const SizedBox(height: S.x1),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: F.head.copyWith(color: p.ink),
          decoration: InputDecoration(
            hintText: unit,
            hintStyle: F.head.copyWith(color: p.ink3),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: S.x3),
            enabledBorder:
                UnderlineInputBorder(borderSide: BorderSide(color: p.line)),
            focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: p.on(C.green))),
          ),
        ),
        const SizedBox(height: S.x1),
        Text(consequence, style: F.cap.copyWith(color: p.ink3)),
      ]),
    );
  }
}

// No day-0 "unlock contract" card. There was one — locked headline, unlock
// date, nights banked, live HR beside it — and nothing ever built it. Day zero
// is carried by `StatusCard.forMetric`, which already says how many more
// nights the metric needs.

/// "Thu 4 Sep" — a date a person can hold, not an ISO string. Local by
/// construction; the app's day labels are local everywhere.
String formatDay(DateTime d, [AppLocalizations? l]) =>
    l?.localeName.startsWith('ru') == true
    ? localizedDate(d, l!.localeName, pattern: 'EEE d MMM')
    : '${weekdayShortName(d.weekday, l)} ${d.day} ${monthShortName(d.month, l)}';
