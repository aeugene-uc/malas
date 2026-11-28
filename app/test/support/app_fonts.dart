import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the app's own fonts, so a layout test measures real text. Without
/// it every letter is a full-width test glyph and nearly anything overflows.
Future<void> loadAppFonts() async {
  final filesByFamily = {
    'PlusJakartaSans': [
      'Regular',
      'Medium',
      'SemiBold',
      'Bold',
      'ExtraBold',
    ].map((weight) => 'assets/fonts/PlusJakartaSans-$weight.ttf'),
    'Phosphor': ['assets/fonts/Phosphor.ttf'],
    'PhosphorFill': ['assets/fonts/Phosphor-Fill.ttf'],
  };
  for (final MapEntry(key: family, value: files) in filesByFamily.entries) {
    final loader = FontLoader(family);
    for (final file in files) {
      final bytes = File(file).readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }
}
