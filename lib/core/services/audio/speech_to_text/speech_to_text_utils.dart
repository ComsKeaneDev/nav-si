import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;

/// Convert a list of bytes to a Float32 list.
///
/// Parameters:
///   bytes: the data to convert
///   endian (optional, default = Little Endian): the endian encoding type
///
/// Returns: the converted Float32 list
Float32List convertBytesToFloat32(Uint8List bytes, [endian = Endian.little]) {
  final values = Float32List(bytes.length ~/ 2);

  final data = ByteData.view(bytes.buffer);

  for (var i = 0; i < bytes.length; i += 2) {
    int short = data.getInt16(i, endian);
    values[ i ~/ 2] = short / 32768.0;
  }

  return values;
}

/// Copy an asset file.
///
/// Parameters:
///   source: the file's current location
///   destination (optional): the file's destination location
///
/// Returns: the path of the file's new location
Future<String> copyAssetFile(String source, [String? destination]) async {
  final Directory directory = await getApplicationSupportDirectory();

  destination ??= basename(source); // assign if null

  final target = join(directory.path, destination);
  bool exists = await File(target).exists();

  final data = await rootBundle.load(source);

  if (!exists || File(target).lengthSync() != data.lengthInBytes) {
    final List <int> bytes = data.buffer.asUint8List(
        data.offsetInBytes, data.lengthInBytes);
    await File(target).writeAsBytes(bytes);
  }
  return target;
}