import 'package:equatable/equatable.dart';

/// One extra copy of a backup (issue #3782): the roster row of the account
/// it went to, and the file id that account gave it.
class ExtraCloudCopy extends Equatable {
  const ExtraCloudCopy({
    required this.accountId,
    required this.fileId,
    this.plaintext = false,
  });

  final String accountId;
  final String fileId;

  /// A plaintext copy re-encryption could not replace (its account was
  /// unreachable, or the upload failed) though the record itself is now
  /// encrypted: a later re-encryption run replaces it.
  final bool plaintext;

  Map<String, dynamic> toJson() => {
    'accountId': accountId,
    'fileId': fileId,
    if (plaintext) 'plaintext': true,
  };

  /// Null for anything that is not a well-formed entry.
  static ExtraCloudCopy? fromJson(Object? json) {
    if (json is! Map) return null;
    final accountId = json['accountId'];
    final fileId = json['fileId'];
    if (accountId is! String || fileId is! String) return null;
    return ExtraCloudCopy(
      accountId: accountId,
      fileId: fileId,
      plaintext: json['plaintext'] == true,
    );
  }

  @override
  List<Object?> get props => [accountId, fileId, plaintext];
}
