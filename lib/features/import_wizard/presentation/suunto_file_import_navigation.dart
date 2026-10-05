import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:submersion/core/services/suunto_cloud/suunto_json_file_reader.dart';

/// The Suunto JSON file import wizard (issue #1445).
const suuntoFileImportPath = '/transfer/import-file/suunto';

/// Opens the Suunto file import with [files] already chosen: the hand-off
/// from the universal wizard, a dropped file, or a batch summary row.
Future<void> openSuuntoFileImport(
  BuildContext context,
  List<SuuntoJsonFile> files,
) => context.push(suuntoFileImportPath, extra: files);
