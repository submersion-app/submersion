import 'package:submersion/features/auto_update/domain/entities/linux_install_method.dart';

/// Path probed to tell an openSUSE host from a Fedora or RHEL one.
const _zypperPath = '/usr/bin/zypper';

/// The command that upgrades a packaged install, or null when no package
/// manager owns it.
///
/// The install method alone does not determine the command. One `.rpm`
/// installs on Fedora, RHEL, and openSUSE alike, but openSUSE's package
/// manager is zypper and it does not ship dnf by default, so telling an
/// openSUSE user to run dnf gives them a command that does not exist. The
/// host is probed rather than assumed.
///
/// [exists] is injected so this is testable without a real filesystem.
String? resolveUpgradeCommand(
  LinuxInstallMethod method, {
  required bool Function(String path) exists,
}) => switch (method) {
  LinuxInstallMethod.deb => 'sudo apt upgrade submersion',
  LinuxInstallMethod.rpm =>
    exists(_zypperPath)
        ? 'sudo zypper update submersion'
        : 'sudo dnf upgrade submersion',
  LinuxInstallMethod.tarball => null,
};
