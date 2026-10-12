import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/accounts/account_kind.dart';
import 'package:submersion/core/services/accounts/account_provider_adapter.dart';
import 'package:submersion/core/services/accounts/connected_account.dart';
import 'package:submersion/core/providers/account_providers.dart';
import 'package:submersion/core/services/shared_library/library_account_setup.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_membership_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_service.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/shared_library/shared_library_transport.dart';
import 'package:submersion/core/services/shared_library/shared_site_publisher.dart';
import 'package:submersion/core/services/shared_library/site_detacher.dart';
import 'package:submersion/core/services/shared_library/suggestion_service.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';

/// The device-local store for club libraries (issue #2567).
final sharedLibraryStoreProvider = Provider<SharedLibraryStore>(
  (ref) => SharedLibraryStore(),
);

/// Every library connected on this device, re-read on any library, member
/// or membership change.
final sharedLibrariesProvider = StreamProvider<List<SharedLibrary>>((
  ref,
) async* {
  final store = ref.watch(sharedLibraryStoreProvider);
  yield await store.getLibraries();
  await for (final _ in store.watchLibraries()) {
    yield await store.getLibraries();
  }
});

/// The active profile's memberships.
final currentMembershipsProvider =
    FutureProvider<List<SharedLibraryMembership>>((ref) async {
      final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
      if (diverId == null) return const [];
      // Re-read when a membership row changes.
      ref.watch(sharedLibrariesProvider);
      return ref.watch(sharedLibraryStoreProvider).membershipsForDiver(diverId);
    });

/// The active profile's membership of [libraryId], null when none.
final currentMembershipProvider =
    FutureProvider.family<SharedLibraryMembership?, String>((
      ref,
      libraryId,
    ) async {
      final all = await ref.watch(currentMembershipsProvider.future);
      for (final m in all) {
        if (m.libraryId == libraryId) return m;
      }
      return null;
    });

/// Whether [libraryId] is connected on this device (credentials present).
final libraryConnectedHereProvider = FutureProvider.family<bool, String>((
  ref,
  libraryId,
) async {
  final libraries = await ref.watch(sharedLibrariesProvider.future);
  return libraries.any((l) => l.id == libraryId);
});

/// The role the UI honours for the active profile in [libraryId]: the
/// listed role capped by read-only detection; reader when not a member or
/// not connected here.
final libraryRoleProvider = FutureProvider.family<SharedLibraryRole, String>((
  ref,
  libraryId,
) async {
  final membership = await ref.watch(
    currentMembershipProvider(libraryId).future,
  );
  if (membership == null) return SharedLibraryRole.reader;
  final libraries = await ref.watch(sharedLibrariesProvider.future);
  for (final l in libraries) {
    if (l.id == libraryId) {
      return effectiveRole(
        listed: l.roles.roleOf(membership.memberId),
        readOnlyDetected: l.readOnlyDetected,
      );
    }
  }
  return SharedLibraryRole.reader;
});

/// Member id to display name for [libraryId], from the member cache.
final libraryMemberNamesProvider =
    FutureProvider.family<Map<String, String>, String>((ref, libraryId) async {
      ref.watch(sharedLibrariesProvider);
      return ref.watch(sharedLibraryStoreProvider).memberNames(libraryId);
    });

/// The member cards of [libraryId].
final libraryMembersProvider =
    FutureProvider.family<List<SharedLibraryMember>, String>((
      ref,
      libraryId,
    ) async {
      ref.watch(sharedLibrariesProvider);
      return ref.watch(sharedLibraryStoreProvider).getMembers(libraryId);
    });

/// The per-site library state (clocks, last editor) of [siteId].
final siteLibraryStateProvider =
    FutureProvider.family<SharedSiteState?, String>((ref, siteId) async {
      final store = ref.watch(sharedLibraryStoreProvider);
      ref.watch(_siteStateTickProvider);
      return store.getSiteState(siteId);
    });

final _siteStateTickProvider = StreamProvider<void>((ref) async* {
  yield null;
  yield* ref.watch(sharedLibraryStoreProvider).watchSiteStates();
});

/// Connected accounts that can back a club library.
final eligibleLibraryAccountsProvider = FutureProvider<List<ConnectedAccount>>((
  ref,
) async {
  final accounts = ref.watch(connectedAccountsRepositoryProvider);
  ref.invalidateSelfWhen(accounts.watchAccountsChanges());
  final all = await accounts.getAll();
  return [
    for (final a in all)
      if (a.kind == AccountKind.s3 || a.kind == AccountKind.webdav) a,
  ];
});

/// Builds the folder transport for a connected account and prefix from
/// the account registry (S3 and WebDAV adapters build a provider per
/// account, so two libraries on one device keep separate credentials).
final sharedLibraryAccountTransportProvider = Provider<LibraryTransportFactory>(
  (ref) {
    final registry = ref.watch(accountProviderRegistryProvider);
    return ({required account, required prefix}) async {
      final capable = registry.capabilityFor<SyncCapable>(account.kind);
      if (capable == null) {
        throw StateError('${account.kind.name} accounts cannot back a library');
      }
      return SharedLibraryTransport(
        capable.syncProvider(account),
        prefix: prefix,
      );
    };
  },
);

/// The transport for a connected library, by its stored account id.
// no-tick: a factory function, not data; it reads the account at call time.
final sharedLibraryTransportFactoryProvider =
    Provider<Future<SharedLibraryTransport> Function(SharedLibrary)>((ref) {
      final accounts = ref.watch(connectedAccountsRepositoryProvider);
      final byAccount = ref.watch(sharedLibraryAccountTransportProvider);
      return (library) async {
        final account = await accounts.getById(library.connectedAccountId);
        if (account == null) {
          throw StateError(
            'The account for ${library.name} is no longer on this device',
          );
        }
        return byAccount(account: account, prefix: library.prefix);
      };
    });

final sharedLibraryServiceProvider = Provider<SharedLibraryService>(
  (ref) => SharedLibraryService(
    store: ref.watch(sharedLibraryStoreProvider),
    transportFor: ref.watch(sharedLibraryTransportFactoryProvider),
    remover: ({required siteId, required ownerDiverId}) async {
      await SiteDetacher(
        store: ref.read(sharedLibraryStoreProvider),
      ).detachOrRemove(siteId: siteId, ownerDiverId: ownerDiverId);
    },
  ),
);

// no-tick: a service object; its account lookup runs at action time.
final sharedLibraryMembershipServiceProvider =
    Provider<SharedLibraryMembershipService>(
      (ref) => SharedLibraryMembershipService(
        store: ref.watch(sharedLibraryStoreProvider),
        transportFor: ref.watch(sharedLibraryAccountTransportProvider),
        accountById: (id) =>
            ref.read(connectedAccountsRepositoryProvider).getById(id),
      ),
    );

final suggestionServiceProvider = Provider<SuggestionService>(
  (ref) => SuggestionService(
    store: ref.watch(sharedLibraryStoreProvider),
    transportFor: ref.watch(sharedLibraryTransportFactoryProvider),
  ),
);

// no-tick: a service object; it writes accounts at action time.
final libraryAccountSetupProvider = Provider<LibraryAccountSetup>(
  (ref) => LibraryAccountSetup(
    accounts: ref.watch(connectedAccountsRepositoryProvider),
    credentials: ref.watch(accountCredentialsStoreProvider),
  ),
);

final sharedSitePublisherProvider = Provider<SharedSitePublisher>(
  (ref) => SharedSitePublisher(store: ref.watch(sharedLibraryStoreProvider)),
);

final _suggestionTickProvider = StreamProvider<void>((ref) async* {
  yield null;
  yield* ref.watch(sharedLibraryStoreProvider).watchSuggestions();
});

/// Reader suggestions waiting for an owner's review in [libraryId].
final incomingSuggestionsProvider =
    FutureProvider.family<List<SharedSiteSuggestion>, String>((
      ref,
      libraryId,
    ) async {
      ref.watch(_suggestionTickProvider);
      return ref
          .watch(sharedLibraryStoreProvider)
          .suggestions(
            libraryId,
            direction: SharedSiteSuggestion.incoming,
            status: SharedSiteSuggestion.pending,
          );
    });

/// How many suggestions wait in [libraryId], for the badge.
final pendingIncomingSuggestionCountProvider =
    FutureProvider.family<int, String>((ref, libraryId) async {
      final list = await ref.watch(
        incomingSuggestionsProvider(libraryId).future,
      );
      return list.length;
    });

/// Field name to (stored value, proposed value) for the review sheet.
// no-tick: a one-shot diff computed when the sheet opens; auto-disposed with
// the sheet, so the next opening compares against the site as it is then.
final suggestionDiffProvider = FutureProvider.autoDispose
    .family<Map<String, (Object?, Object?)>, String>((ref, suggestionId) async {
      final s = await ref
          .watch(sharedLibraryStoreProvider)
          .getSuggestion(suggestionId);
      if (s == null) return const {};
      return ref.watch(suggestionServiceProvider).diff(s);
    });
