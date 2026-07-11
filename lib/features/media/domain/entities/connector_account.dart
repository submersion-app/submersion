import 'package:equatable/equatable.dart';

/// A configured external media service connection (Lightroom, Immich, ...).
/// Per-device: the backing table is intentionally not synced, each device
/// signs in independently. `credentialsRef` points at a secure-storage
/// entry; the secret itself never touches the database.
class ConnectorAccount extends Equatable {
  const ConnectorAccount({
    required this.id,
    required this.connectorType,
    required this.displayName,
    required this.credentialsRef,
    required this.addedAt,
    this.baseUrl,
    this.accountIdentifier,
    this.lastUsedAt,
  });

  final String id;
  final String connectorType;
  final String displayName;
  final String? baseUrl;

  /// Service-specific account scope. For Lightroom this is the catalog id.
  final String? accountIdentifier;
  final String credentialsRef;
  final DateTime addedAt;
  final DateTime? lastUsedAt;

  @override
  List<Object?> get props => [
    id,
    connectorType,
    displayName,
    baseUrl,
    accountIdentifier,
    credentialsRef,
    addedAt,
    lastUsedAt,
  ];
}
