import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nav_si/state/router.dart';

void main() {
  // adding ProviderScope enables Riverpod for entire app
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch the router provider to get the GoRouter instance
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'NAV-SI',

      // routerConfig used to integrate GoRouter with MaterialApp
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}