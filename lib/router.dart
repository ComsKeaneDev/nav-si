import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:all_brawn/features/yolo_object_detection.dart';
import 'package:all_brawn/features/text_detection.dart';

class PersistentShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const PersistentShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // final pageTitle = ref.watch(pageTitleProvider);

    return Scaffold(
      // appBar: AppBar(
        // automaticallyImplyLeading: false,
      // ),
      // drawer: const AppDrawer(),
      // The body is now the navigationShell itself.
      // It handles displaying the correct page from the branch.
      body: navigationShell,
    );
  }
}

// provider holds the title for the current page
// widgets can read this to get the current title and pages can update its state
// wrt the title in the persistent appbar
// final pageTitleProvider = StateProvider<String>((ref) => '');

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
                    path: '/text_detection.dart',
                    name: 'text_detection',
                    builder: (context, state) => const TextDetection(),
                  ),

                  GoRoute(
                    path: '/object_detection.dart',
                    name: 'object_detection',
                    builder: (context, state) => const YoloObjectDetection(),
                  ),

                ]
            )
          ]
      )
    ],
  );
});
