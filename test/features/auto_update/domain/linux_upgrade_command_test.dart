import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/auto_update/domain/entities/linux_install_method.dart';
import 'package:submersion/features/auto_update/domain/linux_upgrade_command.dart';

void main() {
  bool never(String _) => false;
  bool Function(String) only(String present) =>
      (path) => path == present;

  test('a deb install upgrades with apt', () {
    expect(
      resolveUpgradeCommand(LinuxInstallMethod.deb, exists: never),
      'sudo apt upgrade submersion',
    );
  });

  test('an rpm install on Fedora upgrades with dnf', () {
    expect(
      resolveUpgradeCommand(LinuxInstallMethod.rpm, exists: never),
      'sudo dnf upgrade submersion',
    );
  });

  test('an rpm install on openSUSE upgrades with zypper', () {
    // One .rpm serves Fedora, RHEL, and openSUSE, but openSUSE does not ship
    // dnf by default, so the command must follow the host, not the format.
    expect(
      resolveUpgradeCommand(
        LinuxInstallMethod.rpm,
        exists: only('/usr/bin/zypper'),
      ),
      'sudo zypper update submersion',
    );
  });

  test('zypper wins over dnf when both are present', () {
    // openSUSE can have dnf installed alongside zypper; zypper still owns the
    // system's package database there.
    expect(
      resolveUpgradeCommand(
        LinuxInstallMethod.rpm,
        exists: (path) => path == '/usr/bin/zypper' || path == '/usr/bin/dnf',
      ),
      'sudo zypper update submersion',
    );
  });

  test('a tarball install has no package-manager command', () {
    expect(
      resolveUpgradeCommand(LinuxInstallMethod.tarball, exists: never),
      isNull,
    );
  });

  test('apt is never consulted about zypper', () {
    // A deb install must not change command based on unrelated binaries.
    expect(
      resolveUpgradeCommand(
        LinuxInstallMethod.deb,
        exists: only('/usr/bin/zypper'),
      ),
      'sudo apt upgrade submersion',
    );
  });
}
