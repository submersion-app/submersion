import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

void main() {
  test('path scene strings exist in English and German', () async {
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(en.dive3d_zAxis, 'Z axis');
    expect(en.dive3d_axis_depth('ft'), 'Depth (ft)');
    expect(en.dive3d_readout_tank(2), 'Tank 2');
    expect(en.dive3d_pose_side, 'Side (depth vs metric)');
    final de = await AppLocalizations.delegate.load(const Locale('de'));
    expect(de.dive3d_zAxis, 'Z-Achse');
    expect(de.dive3d_overlay_shadows, 'Wandschatten');
  });
}
