class File {
  File(this.path);
  final String path;
  Future<bool> exists() async => false;
  Future<File> delete() async => this;
  Future<int> length() async => 0;
}

class Directory {
  Directory(this.path);
  final String path;
  static Directory get systemTemp => Directory('/tmp');
}

class Platform {
  static bool get isAndroid => false;
  static bool get isIOS => false;
  static String get pathSeparator => '/';
}
