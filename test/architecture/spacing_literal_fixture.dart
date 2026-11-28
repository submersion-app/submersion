import 'package:flutter/material.dart';

/// A widget written the way unmigrated code is, for
/// `spacing_literals_test.dart` to prove the scanner still finds bare
/// spacing and radius numbers in a real, compiling file (issue #4971).
///
/// Never migrate it: the literals are the point. Keep the expectations in
/// that test in step with this file.
class SpacingLiteralFixture extends StatelessWidget {
  const SpacingLiteralFixture({super.key});

  /// A named constant: the scanner must not report this.
  static const double _named = 20;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
      child: const Column(
        spacing: 4,
        children: [
          SizedBox(height: 8),
          // Sizes its child, so it is not a gap and must not be reported.
          SizedBox(width: 120, child: Text('label')),
          SizedBox(height: _named),
          Padding(
            padding: EdgeInsetsDirectional.only(start: 6),
            child: ClipRRect(
              borderRadius: BorderRadius.all(Radius.circular(2)),
              child: Text('body'),
            ),
          ),
        ],
      ),
    );
  }
}
