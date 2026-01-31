import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:nav_si/extensions/detection/object_detection/object_detection.dart';
import 'package:nav_si/extensions/detection/text_detection/text_detection.dart';

class PersistentShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const PersistentShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      // The body is now the navigationShell itself.
      // It handles displaying the correct page from the branch.
      body: navigationShell,
    );
  }
}

// Riverpod provider to create and expose the GoRouter instance
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/object_detection.dart',
    routes: [
      StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return PersistentShell(navigationShell: navigationShell);
          },
          branches: [
            StatefulShellBranch(
                routes: [

                  GoRoute(
                    path: '/object_detection.dart',
                    name: 'object_detection',
                    builder: (context, state) => const ObjectDetection(),
                  ),

                  GoRoute(
                    path: '/text_detection.dart',
                    name: 'text_detection',
                    builder: (context, state) => const TextDetection(),
                  ),

                ]
            )
          ]
      )
    ],
  );
});
