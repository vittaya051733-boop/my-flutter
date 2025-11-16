import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Immutable description of an available application update.
class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersionCode,
    required this.latestVersionCode,
    required this.latestVersionName,
    required this.minSupportedVersionCode,
    required this.apkUrl,
    required this.isMandatory,
    this.releaseNotes,
    this.sha256Checksum,
    this.sizeBytes,
  });

  final int currentVersionCode;
  final int latestVersionCode;
  final String latestVersionName;
  final int minSupportedVersionCode;
  final String apkUrl;
  final bool isMandatory;
  final String? releaseNotes;
  final String? sha256Checksum;
  final int? sizeBytes;

  String get displayVersion => 'v$latestVersionName ($latestVersionCode)';

  String? get humanReadableSize {
    final bytes = sizeBytes;
    if (bytes == null || bytes <= 0) {
      return null;
    }
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    final mb = kb / 1024;
    if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(1)} GB';
  }

  String get suggestedFileName => 'vanmerchant-$latestVersionName.apk';
}

/// Reads update metadata from Firestore and determines whether the running build
/// must prompt users to install a new APK from Firebase Storage.
class AppUpdateService {
  const AppUpdateService({FirebaseFirestore? firestore})
      : _firestore = firestore;

  final FirebaseFirestore? _firestore;

  static const String _collection = 'app_updates';
  static const String _docId = 'android';

  Future<AppUpdateInfo?> getUpdateForCurrentBuild() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentCode = int.tryParse(packageInfo.buildNumber) ?? 0;

    final firestore = _firestore ?? FirebaseFirestore.instance;

    final snapshot = await firestore
        .collection(_collection)
        .doc(_docId)
        .get(const GetOptions(source: Source.serverAndCache));

    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    final latestCode = (data['latestVersionCode'] as num?)?.toInt();
    final apkUrl = (data['apkUrl'] as String?)?.trim();
    if (latestCode == null || apkUrl == null || apkUrl.isEmpty) {
      return null;
    }

    final minSupported =
        (data['minSupportedVersionCode'] as num?)?.toInt() ?? latestCode;
    final latestName = (data['latestVersionName'] as String?)?.trim();
    final releaseNotes = data['releaseNotes'] as String?;
    final forceUpdate = data['forceUpdate'] as bool? ?? false;
    final checksum = (data['sha256'] as String?)?.trim();
    final sizeBytes = (data['sizeBytes'] as num?)?.toInt();

    if (currentCode >= latestCode) {
      return null;
    }

    final isMandatory = forceUpdate || currentCode < minSupported;

    return AppUpdateInfo(
      currentVersionCode: currentCode,
      latestVersionCode: latestCode,
      latestVersionName: latestName?.isNotEmpty == true
          ? latestName!
          : latestCode.toString(),
      minSupportedVersionCode: minSupported,
      apkUrl: apkUrl,
      releaseNotes: releaseNotes,
      isMandatory: isMandatory,
      sha256Checksum: checksum?.isNotEmpty == true ? checksum : null,
      sizeBytes: sizeBytes,
    );
  }
}
