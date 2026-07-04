import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

Future<String> uploadXFilePathToStorage(
  Reference ref,
  String path, {
  SettableMetadata? metadata,
}) async {
  throw UnsupportedError('uploadXFilePathToStorage is mobile-only');
}

ImageProvider buildFileImageProvider(String path) {
  return NetworkImage(path);
}

Future<String> uploadLocalFileToStorage(
  Reference ref,
  Object file, {
  SettableMetadata? metadata,
}) async {
  throw UnsupportedError('uploadLocalFileToStorage is mobile-only');
}

Widget buildLocalFilePreview(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return const SizedBox.shrink();
}

Widget buildLocalFilePreviewFromXFile(
  XFile file, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return const SizedBox.shrink();
}

String fileNameFromPath(String path) {
  final normalized = path.replaceAll('\\', '/');
  return normalized.split('/').last;
}

String tempProductFilePath(String suffix) {
  return 'product_${DateTime.now().microsecondsSinceEpoch}_$suffix';
}
