import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/router/app_router.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/setup_wizard/presentation/widgets/steps/finish_step.dart';

import '../../../../../helpers/mock_providers.dart';

/// Collects absolute paths from the route tree, resolving relative child
/// paths against their parent (go_router stores them relative).
Set<String> _absolutePaths(List<RouteBase> routes, [String prefix = '']) {
  final out = <String>{};
  for (final route in routes) {
    if (route is GoRoute) {
      final full = route.path.startsWith('/')
          ? route.path
          : '$prefix/${route.path}';
      out.add(full);
      out.addAll(_absolutePaths(route.routes, full));
    } else if (route is ShellRoute) {
      out.addAll(_absolutePaths(route.routes, prefix));
    }
  }
  return out;
}

void main() {
  test(
    'every finish-screen feature route resolves in the app router',
    () async {
      final overrides = await getBaseOverrides();
      final container = ProviderContainer(
        overrides: [
          ...overrides,
          hasAnyDiversProvider.overrideWith((ref) async => true),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);
      final paths = _absolutePaths(router.configuration.routes);

      for (final route in kSetupFinishFeatureRoutes) {
        expect(
          paths,
          contains(route),
          reason: 'Finish-screen link "$route" has no matching route',
        );
      }
    },
  );
}
