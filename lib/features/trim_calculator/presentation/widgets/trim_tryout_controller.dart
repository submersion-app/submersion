import 'package:flutter/foundation.dart';

import 'package:submersion/core/buoyancy/trim/trim_moment.dart';
import 'package:submersion/core/buoyancy/trim/trim_pose.dart';
import 'package:submersion/core/buoyancy/trim/trim_spot.dart';
import 'package:submersion/features/dive_log/domain/services/trim/trim_scene_builder.dart';
import 'package:submersion/features/trim_calculator/domain/trim_fixes.dart';

export 'package:submersion/features/trim_calculator/domain/trim_fixes.dart'
    show kTrimTankShiftMaxM;

/// Builds the logged scene at a moment of the dive (null: the rest anchor).
typedef TrimSceneAt = TrimScene Function(int? timestamp);

/// The trim calculator's state (issue #5028): where the diver has moved each
/// element, the sides they gave them, the test items they added, the pose
/// and the moment of the dive. Nothing here is ever written anywhere; it
/// lives as long as the calculator shows one dive.
class TrimTryoutController extends ChangeNotifier {
  TrimTryoutController({required this.sceneAt, required this.openingTimestamp})
    : _timestamp = openingTimestamp;

  final TrimSceneAt sceneAt;
  final int? openingTimestamp;

  int? _timestamp;
  TrimPose _pose = TrimPose.standard;
  Map<String, ({TrimSpot spot, TrimLateral lateral})> _moves = const {};
  List<TrimElement> _tests = const [];
  double _tankShiftM = 0;
  TrimScene? _scene;
  TrimResult? _result;
  ({double step, List<TrimFix> fixes})? _fixes;

  /// Where a tank may go.
  static const tankSpots = [
    TrimSpot.backTank,
    TrimSpot.sidemount,
    TrimSpot.stageClip,
  ];

  int? get timestamp => _timestamp;
  TrimPose get pose => _pose;

  /// How far back-mounted tanks are slid along the band, metres toward the
  /// feet.
  double get tankShiftM => _tankShiftM;

  /// Whether a tank sits on the back, for the tank height slider to move.
  bool get hasBackTank => scene.elements.any(_slides);

  static bool _slides(TrimElement e) =>
      e.kind == TrimElementKind.tank && e.spot == TrimSpot.backTank;

  /// The logged scene at [timestamp] with every move and test item applied.
  TrimScene get scene => _scene ??= _build();
  TrimResult get result => _result ??= scene.trimIn(_pose);

  /// What would level the diver now, lead moving in [leadStepKg]; worked
  /// out once per scene and pose, not on every frame of a drag.
  List<TrimFix> fixes(double leadStepKg) {
    final cached = _fixes;
    if (cached != null && cached.step == leadStepKg) return cached.fixes;
    final found = suggestTrimFixes(scene, _pose, leadStepKg: leadStepKg);
    _fixes = (step: leadStepKg, fixes: found);
    return found;
  }

  TrimScene _build() {
    final base = sceneAt(_timestamp);
    final placed = [
      for (final e in base.elements)
        if (_moves[e.id] case final m?)
          // Its drawing belongs where it was; moved, it shows as its chip.
          TrimElement(
            id: e.id,
            label: e.label,
            kind: e.kind,
            sinkKg: e.sinkKg,
            spot: m.spot,
            lateral: m.lateral,
            itemId: e.itemId,
            weightType: e.weightType,
            color: e.color,
            movableTo: e.movableTo,
            valveSinkKg: e.valveSinkKg,
          )
        else
          e,
      ..._tests,
    ];
    return base.copyWith(
      elements: _tankShiftM == 0
          ? placed
          : [
              for (final e in placed)
                _slides(e) ? e.copyWith(shiftM: _tankShiftM) : e,
            ],
    );
  }

  void _changed() {
    _scene = null;
    _result = null;
    _fixes = null;
    notifyListeners();
  }

  /// Suits and anything with no spot on the body stay where they are, as
  /// does gear the gear figure offers no other spot for.
  bool canMove(TrimElement e) =>
      e.spot != TrimSpot.floatPoint && spotsFor(e).length > 1;

  /// The spots [e] may be dropped on: a tank's, gear's own (as the gear
  /// figure offers them), anywhere on the body for lead and test items.
  List<TrimSpot> spotsFor(TrimElement e) {
    if (e.spot == TrimSpot.floatPoint) return [e.spot];
    if (e.kind == TrimElementKind.tank) return tankSpots;
    if (e.movableTo case final spots?) {
      return spots.contains(e.spot) ? spots : [e.spot, ...spots];
    }
    return [
      for (final s in TrimSpot.values)
        if (s != TrimSpot.floatPoint) s,
    ];
  }

  TrimElement? _element(String id) {
    for (final e in scene.elements) {
      if (e.id == id) return e;
    }
    return null;
  }

  void move(String id, TrimSpot spot) {
    final e = _element(id);
    if (e == null || !spotsFor(e).contains(spot)) return;
    final lateral = spot.sided ? e.lateral : TrimLateral.centre;
    _set(e, spot, lateral);
  }

  /// Both, then left, then right, on a sided spot.
  void cycleSide(String id) {
    final e = _element(id);
    if (e == null || !e.spot.sided) return;
    final next = switch (e.lateral) {
      TrimLateral.centre => TrimLateral.left,
      TrimLateral.left => TrimLateral.right,
      TrimLateral.right => TrimLateral.centre,
    };
    _set(e, e.spot, next);
  }

  void setSide(String id, TrimLateral lateral) {
    final e = _element(id);
    if (e == null || !e.spot.sided) return;
    _set(e, e.spot, lateral);
  }

  void _set(TrimElement e, TrimSpot spot, TrimLateral lateral) {
    if (e.kind == TrimElementKind.test) {
      _tests = [
        for (final t in _tests)
          t.id == e.id ? t.copyWith(spot: spot, lateral: lateral) : t,
      ];
    } else {
      _moves = {..._moves, e.id: (spot: spot, lateral: lateral)};
    }
    _changed();
  }

  /// A test item of [kg] named [name], at the waist.
  void addTestItem(String name, double kg) {
    _tests = [
      ..._tests,
      TrimElement(
        id: 'test:${_tests.length}:$name',
        label: name,
        kind: TrimElementKind.test,
        sinkKg: kg,
        spot: TrimSpot.waist,
      ),
    ];
    _changed();
  }

  void setPose(TrimPose pose) {
    _pose = pose;
    _result = null;
    _fixes = null;
    notifyListeners();
  }

  /// Slides back-mounted tanks [m] along the band (toward the feet when
  /// positive), within [kTrimTankShiftMaxM].
  void setTankShift(double m) {
    _tankShiftM = m.clamp(-kTrimTankShiftMaxM, kTrimTankShiftMaxM);
    _changed();
  }

  void setTimestamp(int? timestamp) {
    _timestamp = timestamp;
    _changed();
  }

  void reset() {
    _moves = const {};
    _tests = const [];
    _tankShiftM = 0;
    _pose = TrimPose.standard;
    _timestamp = openingTimestamp;
    _changed();
  }
}
