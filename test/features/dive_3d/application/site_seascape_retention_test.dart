import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_3d/application/site_seascape_providers.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/dive_sites/presentation/providers/site_providers.dart';

/// The Site Details card builds a site's scene whenever the site is viewed,
/// so a scene must not outlive its viewers for the rest of the session. It
/// is kept for a window after it builds, so flipping the sites map back to
/// 3D or reopening fullscreen soon after stays instant.
void main() {
  // No coordinates: the scene resolves at once, without the bathymetry
  // pipeline, which is all a lifecycle test needs.
  const site = DiveSite(id: 'site-1', name: 'Blue Hole');

  ProviderContainer container() => ProviderContainer(
    overrides: [siteProvider(site.id).overrideWith((ref) async => site)],
  );

  void settle(FakeAsync async, Duration by) {
    async.elapse(by);
    async.flushMicrotasks();
  }

  test('an unwatched scene is kept within the retention window', () {
    fakeAsync((async) {
      final c = container();
      addTearDown(c.dispose);
      final sub = c.listen(siteSeascapeProvider(site.id), (_, _) {});
      settle(async, Duration.zero);
      expect(
        c.read(siteSeascapeProvider(site.id)).value,
        isA<SiteSeascapeNoCoordinates>(),
      );

      sub.close();
      settle(async, siteSeascapeRetention ~/ 2);

      expect(c.exists(siteSeascapeProvider(site.id)), isTrue);
    });
  });

  test('an unwatched scene is freed once the window has passed', () {
    fakeAsync((async) {
      final c = container();
      addTearDown(c.dispose);
      final sub = c.listen(siteSeascapeProvider(site.id), (_, _) {});
      settle(async, Duration.zero);

      sub.close();
      settle(async, siteSeascapeRetention + const Duration(seconds: 1));

      expect(c.exists(siteSeascapeProvider(site.id)), isFalse);
    });
  });

  test('a scene still watched outlives the window', () {
    fakeAsync((async) {
      final c = container();
      addTearDown(c.dispose);
      final sub = c.listen(siteSeascapeProvider(site.id), (_, _) {});
      addTearDown(sub.close);
      settle(async, siteSeascapeRetention * 2);

      expect(c.exists(siteSeascapeProvider(site.id)), isTrue);
    });
  });
}
