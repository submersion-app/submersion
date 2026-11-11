import 'package:flutter/widgets.dart';

import 'package:submersion/l10n/l10n_extension.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// The name a dive's detail headers show for it: its own name when it has
/// one, otherwise its site's, otherwise "Unknown Site".
///
/// The phone app bar, the desktop pane's header and the hero card all title
/// the dive with this, so the layouts cannot drift apart (issue #4445).
String diveTitle(BuildContext context, Dive dive) =>
    dive.effectiveName ??
    dive.site?.name ??
    context.l10n.diveLog_listPage_unknownSite;
