// ============================================================
// 모이쇼 디자인시스템 v2 — Flutter 위젯 카탈로그
// components.css 와 1:1. HTML 클래스 ↔ 위젯 대응표는 맨 아래.
// ============================================================

import 'package:flutter/material.dart';
import 'moisho_theme.dart';

/// 색 출입 권한을 강제하는 화면 래퍼.
/// CSS의 .surface-money / .surface-community 에 대응.
/// money 화면에서 MoishoButton.warm() 등을 쓰면 assert 로 잡는다.
enum Surface { money, community }

class MoishoSurface extends InheritedWidget {
  const MoishoSurface({super.key, required this.surface, required super.child});
  final Surface surface;

  static Surface of(BuildContext c) =>
      c.dependOnInheritedWidgetOfExactType<MoishoSurface>()?.surface ?? Surface.money;

  @override
  bool updateShouldNotify(MoishoSurface old) => old.surface != surface;
}

/// 버튼 — CSS .btn--primary / --warm / --secondary
class MoishoButton extends StatelessWidget {
  const MoishoButton.primary(this.label, {super.key, this.onTap, this.block = false})
      : _kind = _Kind.primary;
  const MoishoButton.warm(this.label, {super.key, this.onTap, this.block = false})
      : _kind = _Kind.warm;
  const MoishoButton.secondary(this.label, {super.key, this.onTap, this.block = false})
      : _kind = _Kind.secondary;

  final String label;
  final VoidCallback? onTap;
  final bool block;
  final _Kind _kind;

  @override
  Widget build(BuildContext context) {
    // [규칙] 색 권한: money 화면에서 warm 버튼 금지
    assert(!(_kind == _Kind.warm && MoishoSurface.of(context) == Surface.money),
        'money 화면에서는 코랄(warm) 버튼을 쓸 수 없습니다. 돈 이동 CTA는 .primary 를 쓰세요.');

    final (bg, fg, shadow) = switch (_kind) {
      _Kind.primary   => (MoishoColors.primary, Colors.white, MoishoShadow.glowBlue),
      _Kind.warm      => (MoishoColors.warm, Colors.white, MoishoShadow.glowWarm),
      _Kind.secondary => (MoishoColors.primarySoft, MoishoColors.primary, const <BoxShadow>[]),
    };
    final btn = DecoratedBox(
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(MoishoRadius.md), boxShadow: shadow),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        child: Text(label, textAlign: TextAlign.center,
            style: TextStyle(color: fg, fontSize: 14.5, fontWeight: FontWeight.w700)),
      ),
    );
    return GestureDetector(
      onTap: onTap,
      child: block ? SizedBox(width: double.infinity, child: btn) : btn,
    );
  }
}
enum _Kind { primary, warm, secondary }

/// 배지 — CSS .badge--*
class MoishoBadge extends StatelessWidget {
  const MoishoBadge(this.text, {super.key, required this.bg, required this.fg});
  const MoishoBadge.progress(String t, {Key? k}) : this(t, key: k, bg: MoishoColors.primarySoft, fg: MoishoColors.primary);
  const MoishoBadge.done(String t, {Key? k}) : this(t, key: k, bg: MoishoColors.successSoft, fg: MoishoColors.successStrong);
  const MoishoBadge.waiting(String t, {Key? k}) : this(t, key: k, bg: MoishoColors.warmSoft, fg: MoishoColors.warmStrong);

  final String text; final Color bg; final Color fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(MoishoRadius.pill)),
    child: Text(text, style: TextStyle(color: fg, fontSize: 11, fontWeight: FontWeight.w600)),
  );
}

/// 에스크로 스테퍼 — CSS .stepper
class EscrowStepper extends StatelessWidget {
  const EscrowStepper({super.key, required this.steps, required this.current});
  final List<String> steps; // ['예치','락','동의','출금','정산','완료']
  final int current;        // 0-based 현재 단계

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < steps.length; i++)
        Expanded(child: _node(i)),
    ],
  );

  Widget _node(int i) {
    final done = i < current, cur = i == current;
    final color = (done || cur) ? MoishoColors.primary : const Color(0xFFE7EBF3);
    return Column(children: [
      Stack(alignment: Alignment.center, children: [
        if (i > 0) Positioned(left: 0, right: 0, top: 12, child: Container(height: 3, color: done || cur ? MoishoColors.primary : const Color(0xFFE7EBF3))),
        Container(
          width: 27, height: 27,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: done ? MoishoColors.primary : (cur ? Colors.white : const Color(0xFFE7EBF3)),
            border: cur ? Border.all(color: MoishoColors.primary, width: 3) : null,
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check, size: 14, color: Colors.white)
              : Text('${i + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cur ? MoishoColors.primary : MoishoColors.textFaint)),
        ),
      ]),
      const SizedBox(height: 7),
      Text(steps[i], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: (done || cur) ? (cur ? MoishoColors.primary : MoishoColors.textBody) : MoishoColors.textFaint)),
    ]);
  }
}

/// 블루 슬랩 — CSS .slab (money 화면의 최중요 정보 블록)
class BlueSlab extends StatelessWidget {
  const BlueSlab({super.key, required this.label, required this.figure, this.child});
  final String label; final String figure; final Widget? child;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: MoishoColors.primary, borderRadius: BorderRadius.circular(MoishoRadius.xl), boxShadow: MoishoShadow.glowSlab),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Color(0xFFCBD6FF), fontSize: 12, fontWeight: FontWeight.w600)),
      const SizedBox(height: 6),
      Text(figure, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, fontFeatures: kTabular)),
      if (child != null) ...[const SizedBox(height: 14), child!],
    ]),
  );
}

// ============================================================
// HTML 클래스 ↔ Flutter 위젯 대응
// .btn--primary/--warm/--secondary  → MoishoButton.primary/.warm/.secondary
// .badge--progress/--done/--waiting  → MoishoBadge.progress/.done/.waiting
// .stepper                           → EscrowStepper
// .slab                              → BlueSlab
// .surface-money/.surface-community  → MoishoSurface(surface: Surface.money/community)
// .card                              → Card (themed)
// .field__input                      → TextField (inputDecorationTheme)
// 금액 텍스트 fontFeatures: kTabular  ↔ class="num"
// ============================================================
