/// Web (and any target without `dart:io`): duration is not probed locally.
/// Callers still enforce the file-size cap.
Future<Duration?> probeVideoDuration(String path) async => null;
