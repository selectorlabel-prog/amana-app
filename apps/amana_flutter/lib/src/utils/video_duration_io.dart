import 'dart:async';
import 'dart:io';

import 'package:video_player/video_player.dart';

/// Reads the container duration of a local clip. Throws [StateError] when the
/// file cannot be opened. The caller enforces [shortVideoMaxSeconds].
Future<Duration?> probeVideoDuration(String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) {
    throw StateError('تعذّر قراءة ملف الفيديو.');
  }

  final controller = VideoPlayerController.file(File(trimmed));
  try {
    try {
      await controller.initialize().timeout(const Duration(seconds: 12));
    } on TimeoutException {
      throw StateError(
        'تعذّر قراءة مدة الفيديو. جرّب مقطعاً أقصر بصيغة MP4.',
      );
    }
    if (!controller.value.isInitialized) {
      throw StateError('تعذّر قراءة مدة الفيديو. جرّب حفظه بصيغة MP4.');
    }
    return controller.value.duration;
  } finally {
    await controller.dispose();
  }
}
