import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nav_si/core/router.dart';
import 'core/services/audio.dart';

void main() {
  // wrapping the app in a ProviderScope makes Riverpod providers
  runApp(const ProviderScope(child: MyApp()));
}

final Speaker textToSpeech = Speaker();
final Transcriber speechToText = Transcriber();
bool isListening = false;

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch the router provider to get the gorouter instance
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'NAV-SI',

      // routerConfig used to integrate fo_router with MaterialApp
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}