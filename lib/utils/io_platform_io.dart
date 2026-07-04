import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/widgets.dart';
import 'package:image_picker/image_picker.dart';

Future<String> uploadLocalFileToStorage(
  Reference ref,
  File file, {
  SettableMetadata? metadata,
}) async {
  final snapshot = await ref.putFile(file, metadata);
  return snapshot.ref.getDownloadURL();
}

Future<String> uploadXFilePathToStorage(
  Reference ref,
  String path, {
  SettableMetadata? metadata,
}) async {
  return uploadLocalFileToStorage(ref, File(path), metadata: metadata);
}

ImageProvider buildFileImageProvider(String path) {
  return FileImage(File(path));
}

Widget buildLocalFilePreview(
  String path, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return Image.file(
    File(path),
    width: width,
    height: height,
    fit: fit,
  );
}

Widget buildLocalFilePreviewFromXFile(
  XFile file, {
  double? width,
  double? height,
  BoxFit fit = BoxFit.cover,
}) {
  return buildLocalFilePreview(
    file.path,
    width: width,
    height: height,
    fit: fit,
  );
}

String fileNameFromPath(String path) {
  return path.split(Platform.pathSeparator).last;
}

String tempProductFilePath(String suffix) {
  return '${Directory.systemTemp.path}/product_${DateTime.now().microsecondsSinceEpoch}_$suffix';
}
