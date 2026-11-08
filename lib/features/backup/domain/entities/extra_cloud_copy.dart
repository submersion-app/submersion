import 'package:equatable/equatable.dart';

/// One extra copy of a backup (issue #3782): the roster row of the account
/// it went to, and the file id that account gave it.
class ExtraCloudCopy extends Equatable {
  const ExtraCloudCopy({required this.accountId, required this.fileId});

  final String accountId;
  final String fileId;

  Map<String, dynamic> toJson() => {'accountId': accountId, 'fileId': fileId};

  /// Null for anything that is not a well-formed entry.
  static ExtraCloudCopy? fromJson(Object? json) {
    if (json is! Map) return null;
    final accountId = json['accountId'];
    final fileId = json['fileId'];
    if (accountId is! String || fileId is! String) return null;
    return ExtraCloudCopy(accountId: accountId, fileId: fileId);
  }

  @override
  List<Object?> get props => [accountId, fileId];
}
