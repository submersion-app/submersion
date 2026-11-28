import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/opening_hours/opening_hours.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';

import '../../../../helpers/test_database.dart';

/// A site's address, contact details and opening hours (issue #5073) are
/// stored, cleared and searched.
void main() {
  late SiteRepository sites;

  final hours = OpeningHours(
    note: 'Book slots by phone',
    schedules: [
      OpeningSchedule(
        name: 'Summer',
        season: const YearlyDateRange(
          start: MonthDay(4, 1),
          end: MonthDay(10, 31),
        ),
        days: {
          DateTime.saturday: DayHours.ranges(const [
            TimeRange(480, 720),
            TimeRange(780, 1020),
          ]),
        },
      ),
    ],
  );

  final stoney = DiveSite(
    id: 's1',
    name: 'Stoney Cove',
    address: 'Stoney Cove\nStoney Stanton\nLE9 4DW',
    phone: '+44 1455 273089',
    email: 'info@stoneycove.com',
    website: 'stoneycove.com',
    openingHours: hours,
  );

  setUp(() async {
    await setUpTestDatabase();
    sites = SiteRepository();
  });

  tearDown(tearDownTestDatabase);

  test('create round-trips every field', () async {
    await sites.createSite(stoney);
    final read = (await sites.getSiteById('s1'))!;
    expect(read.address, stoney.address);
    expect(read.phone, stoney.phone);
    expect(read.email, stoney.email);
    expect(read.website, stoney.website);
    expect(read.openingHours, hours);
    expect(read.hasContactInfo, isTrue);
  });

  test('update changes and clears them', () async {
    await sites.createSite(stoney);
    final site = (await sites.getSiteById('s1'))!;
    await sites.updateSite(
      site.copyWith(
        phone: '+44 1455 000000',
        clearOpeningHours: true,
        clearWebsite: true,
      ),
    );
    final read = (await sites.getSiteById('s1'))!;
    expect(read.phone, '+44 1455 000000');
    expect(read.openingHours, isNull);
    expect(read.website, isNull);
    expect(read.address, stoney.address);
  });

  test('search matches the address, phone, email and website', () async {
    await sites.createSite(stoney);
    await sites.createSite(const DiveSite(id: 's2', name: 'Other'));
    for (final query in ['LE9', '1455', 'stoneycove.com', 'info@']) {
      final found = await sites.searchSites(query);
      expect(found.map((s) => s.id), ['s1'], reason: query);
    }
  });
}
