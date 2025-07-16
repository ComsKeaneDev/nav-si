import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:all_brawn/router.dart';
import '../core/audio.dart';

void main() {
  // wrapping the app in a ProviderScope makes Riverpod providers
  runApp(const ProviderScope(child: MyApp()));
}

final speechToText = Transcriber();
final textToSpeech = Speaker();

// set size measurements
Size size = PlatformDispatcher.instance.views.first.physicalSize;
final ratio = PlatformDispatcher.instance.views.first.devicePixelRatio;
final width = size.width;
final height = size.height;

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch the router provider to get the gorouter instance
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'NAV-SI',

      // theme is managed by a provider for potential dynamic theming
      // theme: ref.watch(appThemeProvider),

      // routerConfig used to integrate fo_router with MaterialApp
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}