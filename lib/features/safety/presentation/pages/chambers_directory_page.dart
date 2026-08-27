import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:submersion/features/safety/domain/entities/chamber_listing.dart';
import 'package:submersion/features/safety/presentation/providers/emergency_providers.dart';
import 'package:submersion/features/safety/presentation/widgets/chamber_tile.dart';
import 'package:submersion/l10n/l10n_extension.dart';

/// The full chamber directory.
///
/// The emergency card deliberately shows only the nearest few, because it is
/// read under stress. Everything the card leaves out stays reachable here,
/// searchable by name, city, or country.
class ChambersDirectoryPage extends ConsumerStatefulWidget {
  const ChambersDirectoryPage({super.key});

  @override
  ConsumerState<ChambersDirectoryPage> createState() =>
      _ChambersDirectoryPageState();
}

class _ChambersDirectoryPageState extends ConsumerState<ChambersDirectoryPage> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final listingsAsync = ref.watch(chamberListingsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.chambersDirectory_title)),
      body: listingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              l10n.common_error_tryAgain,
              textAlign: TextAlign.center,
            ),
          ),
        ),
        data: (listings) {
          final matches = _filter(listings, _query);
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: l10n.chambersDirectory_search,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    l10n.chambersDirectory_count(matches.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.chambersDirectory_empty),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: matches.length,
                        itemBuilder: (context, index) => ChamberTile(
                          listing: matches[index],
                          onCall: _call,
                          showActions: false,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Case-insensitive substring match across name, city, and country, the same
  /// shape `DiveSiteApiService` uses to filter its bundled sites.
  List<ChamberListing> _filter(List<ChamberListing> listings, String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return listings;
    return listings.where((listing) {
      final chamber = listing.chamber;
      return chamber.name.toLowerCase().contains(needle) ||
          (chamber.city?.toLowerCase().contains(needle) ?? false) ||
          chamber.country.toLowerCase().contains(needle);
    }).toList();
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
