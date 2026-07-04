import 'dart:typed_data';

class File {
  File(this.path);

  final String path;

  Future<Uint8List> readAsBytes() async => Uint8List(0);

  Future<bool> exists() async => false;

  Future<File> delete() async => this;

  Future<int> length() async => 0;

  Future<File> writeAsBytes(
    List<int> bytes, {
    bool flush = false,
  }) async =>
      this;
}

class Directory {
  Directory(this.path);

  final String path;

  static String get systemTemp => '/tmp';
}
