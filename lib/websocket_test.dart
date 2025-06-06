import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';

class WebsocketTest extends StatefulWidget {
  const WebsocketTest({super.key});

  @override
  _WebsocketTestState createState() => _WebsocketTestState();
}

class _WebsocketTestState extends State<WebsocketTest> {
  late final WebSocket _socket;
  StreamSubscription? _subscription;
  Uint8List? _latestImage;
  int _messageCount = 0;

  @override
  void initState() {
    super.initState();
    _connectAndListen();
  }

  static final _headerBytes  = utf8.encode("VIDO");
  static const   _headerLength = 4;

  Future<void> _connectAndListen() async {
  try {
    _socket = await WebSocket.connect('ws://172.20.10.4:81')
        .timeout(const Duration(seconds: 5));

    _subscription = _socket.listen((dynamic message) {
      Uint8List bytes;

      if (message is List<int>) {
        bytes = Uint8List.fromList(message);
      } else if (message is String) {
        try {
          bytes = base64Decode(message);
        } catch (_) {
          debugPrint('✖️ Received String but not valid Base64: ${message.substring(0,20)}');
          return;
        }
      } else {
        debugPrint('✖️ Unknown frame type: ${message.runtimeType}');
        return;
      }

      final headerSnippet = bytes.length >= 8
        ? bytes.sublist(0, 8).map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ')
        : bytes.map((b) => b.toRadixString(16).padLeft(2,'0')).join(' ');
      debugPrint('📥 Raw frame (#${_messageCount + 1}) first bytes: $headerSnippet');


      if (bytes.length <= _headerLength) {
        debugPrint('✖️ Frame too short (${bytes.length} bytes)');
        return;
      }

      var matches = true;
      for (var i = 0; i < _headerLength; i++) {
        if (bytes[i] != _headerBytes[i]) {
          matches = false;
          break;
        }
      }
      if (!matches) {
        debugPrint('✖️ Header mismatch; skipping frame');
        return;
      }

      final imageBytes = bytes.sublist(_headerLength);
      setState(() {
        _messageCount++;
        _latestImage = imageBytes;
      });
      debugPrint('✔️ Frame #$_messageCount accepted (${imageBytes.length} bytes)');
    },
    onError: (e) {
      debugPrint('⚠️ onError: $e');
    },
    onDone: () {
      debugPrint('🔌 onDone: closed by server');
    });
  } on TimeoutException {
    debugPrint('❌ WebSocket handshake timed out');
  } catch (e) {
    debugPrint('❌ connection failed: $e');
  }
}

  @override
  void dispose() {
    _subscription?.cancel();
    _socket.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('WebSocket JPEG Stream')),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Messages received: $_messageCount'),
          const SizedBox(height: 16),
          Expanded(
            child: _latestImage != null
                ? Image.memory(
                    _latestImage!,
                    gaplessPlayback: true,
                    fit: BoxFit.contain,
                  )
                : const Text('Waiting for image…'),
          ),
        ],
      ),
    );
  }
}
