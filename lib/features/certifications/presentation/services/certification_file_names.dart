import 'package:submersion/core/services/export/shared/export_file_name.dart';

/// The two images a certification is shared as.
enum CertificationImage { card, certificate }

/// `certification_<title>_<image>.png`, the title as a [fileNameSegment] in
/// its own case.
String certificationImageFileName(String title, CertificationImage image) =>
    exportFileName([
      'certification',
      fileNameSegment(title),
      image.name,
    ], 'png');
