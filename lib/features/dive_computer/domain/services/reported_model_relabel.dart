import 'package:submersion/features/dive_log/domain/entities/dive_computer.dart';

/// The saved [computer] relabeled to the product the device reported about
/// itself during a download (issue #422).
///
/// A Cressi Donatello behind Cressi's Bluetooth adapter advertises the
/// Cartesio's model code, so it is saved as a "Cressi Cartesio". The version
/// block read during the download names the real model; the native layer
/// resolves it to an exact libdivecomputer product string, which is what
/// later downloads match descriptors against.
///
/// The name is replaced only while it is still the default one the app gave
/// the computer (manufacturer then model); a name the diver chose is kept.
/// Returns [computer] itself when there is nothing to change.
DiveComputer relabelToReportedProduct(
  DiveComputer computer,
  String? reportedProduct,
) {
  final product = reportedProduct?.trim();
  if (product == null || product.isEmpty || product == computer.model) {
    return computer;
  }
  final hadDefaultName = computer.name.trim() == computer.fullName;
  final relabeled = computer.copyWith(model: product);
  return hadDefaultName
      ? relabeled.copyWith(name: relabeled.fullName)
      : relabeled;
}
