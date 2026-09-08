import 'dart:io';

import 'package:submersion/features/auto_update/domain/entities/linux_install_method.dart';

/// Reads the install-method marker that the Linux packages ship.
///
/// The marker sits beside the executable at /usr/lib/submersion/INSTALL_METHOD.
/// The tarball ships no marker, so its absence is the tarball case rather than
/// an error.
class LinuxInstallMethodReader {
  const LinuxInstallMethodReader({required this.executablePath});

  final String executablePath;

  LinuxInstallMethod read() {
    try {
      final marker = File('${File(executablePath).parent.path}/INSTALL_METHOD');
      if (!marker.existsSync()) return LinuxInstallMethod.tarball;
      return switch (marker.readAsStringSync().trim()) {
        'deb' => LinuxInstallMethod.deb,
        'rpm' => LinuxInstallMethod.rpm,
        _ => LinuxInstallMethod.tarball,
      };
    } on FileSystemException {
      return LinuxInstallMethod.tarball;
    }
  }
}
