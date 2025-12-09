import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/app_update_service.dart';

/// Wraps the main application with an update check that runs as soon as the
/// widget tree is ready. When Firestore reports a newer APK in Firebase Storage
/// the user is prompted to download and install it before proceeding.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.child,
    this.service = const AppUpdateService(),
    this.allowSkipForMandatory = false,
    this.showCheckingOverlay = false,
  });

  final Widget child;
  final AppUpdateService service;
  final bool allowSkipForMandatory;
  final bool showCheckingOverlay;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checking = false;
  bool _dialogVisible = false;
  bool _isInstalling = false;
  int? _progress;
  String? _errorMessage;
  StreamSubscription<OtaEvent>? _otaSubscription;
  StateSetter? _dialogSetState;
  SharedPreferences? _prefs;
  int? _skippedVersionCode;

  static const String _kSkippedVersionKey = 'app_update_skipped_version_code';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_initializeAndCheck());
    });
  }

  @override
  void dispose() {
    _otaSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initializeAndCheck() async {
    if (_checking || kIsWeb) {
      return;
    }
    setState(() => _checking = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _prefs = prefs;
          _skippedVersionCode = prefs.getInt(_kSkippedVersionKey);
        });
      }
      await _kickOffCheck();
    } catch (e) {
      debugPrint('AppUpdateGate init failed: $e');
    } finally {
      if (mounted) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _kickOffCheck() async {
    if (kIsWeb) {
      return;
    }
    try {
      final update = await widget.service.getUpdateForCurrentBuild();
      if (!mounted || update == null) {
        return;
      }
      await _resetSkipIfNeeded(update);
      final skipped = _skippedVersionCode;
      final shouldSkipOptional =
          skipped != null && skipped == update.latestVersionCode && !update.isMandatory;
      if (shouldSkipOptional) {
        return;
      }
      _showUpdateDialog(update);
    } catch (e) {
      debugPrint('App update check failed: $e');
    }
  }

  void _showUpdateDialog(AppUpdateInfo info) {
    if (_dialogVisible || !mounted) {
      return;
    }
    _dialogVisible = true;
    final canSkip = !info.isMandatory || widget.allowSkipForMandatory;
    showDialog<void>(
      context: context,
      barrierDismissible: canSkip && !_isInstalling,
      builder: (dialogContext) {
        return PopScope(
          canPop: canSkip && !_isInstalling,
          child: StatefulBuilder(
            builder: (context, setState) {
              _dialogSetState = setState;
              return AlertDialog(
                title: Text(info.isMandatory ? 'จำเป็นต้องอัปเดต' : 'มีเวอร์ชันใหม่'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('เวอร์ชันล่าสุด: ${info.displayVersion}'),
                    if (info.humanReadableSize != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('ขนาดไฟล์: ${info.humanReadableSize}'),
                      ),
                    if (info.releaseNotes != null && info.releaseNotes!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          info.releaseNotes!,
                          style: const TextStyle(height: 1.4),
                        ),
                      ),
                    if (_isInstalling) ...[
                      const SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: _progress != null ? _progress!.clamp(0, 100) / 100 : null,
                      ),
                      if (_progress != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text('กำลังดาวน์โหลด ${_progress!.clamp(0, 100)}%'),
                        ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
                actions: [
                  if (!_isInstalling && canSkip)
                    TextButton(
                      onPressed: () {
                        _rememberSkipForVersion(info.latestVersionCode);
                        Navigator.of(dialogContext).pop();
                      },
                      child: const Text('ภายหลัง'),
                    ),
                  TextButton(
                    onPressed: _isInstalling ? null : () => _startDownload(info),
                    child: const Text('อัปเดต'),
                  ),
                ],
              );
            },
          ),
        );
      },
    ).whenComplete(() {
      _dialogVisible = false;
      _dialogSetState = null;
      if (mounted && !_isInstalling) {
        setState(() {
          _errorMessage = null;
          _progress = null;
        });
      }
    });
  }

  Future<void> _startDownload(AppUpdateInfo info) async {
    final permissionsGranted = await _ensureOtaPermissions();
    if (!permissionsGranted) {
      _handleOtaError(
        OtaStatus.PERMISSION_NOT_GRANTED_ERROR,
        'กรุณาอนุญาตการติดตั้งจากแหล่งอื่นและการเขียนไฟล์ก่อนเริ่มอัปเดต',
      );
      return;
    }

    setState(() {
      _isInstalling = true;
      _errorMessage = null;
      _progress = 0;
    });
    _dialogSetState?.call(() {});

    try {
      await _otaSubscription?.cancel();
      await _clearSkipRecord();
      final stream = OtaUpdate().execute(
        info.apkUrl,
        destinationFilename: info.suggestedFileName,
        sha256checksum: info.sha256Checksum,
      );

      _otaSubscription = stream.listen(
        (event) {
          if (!mounted) {
            return;
          }
          switch (event.status) {
            case OtaStatus.DOWNLOADING:
              final value = int.tryParse(event.value ?? '');
              setState(() => _progress = value);
              _dialogSetState?.call(() {});
              break;
            case OtaStatus.INSTALLING:
              // Download complete, Android installer will take over
              debugPrint('OTA: Download complete, launching installer');
              if (mounted && _dialogVisible) {
                // Show brief message then close dialog
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('ดาวน์โหลดเสร็จแล้ว กรุณาติดตั้งและเปิดแอปใหม่'),
                    duration: Duration(seconds: 3),
                  ),
                );
                Navigator.of(context, rootNavigator: true).pop();
              }
              setState(() {
                _isInstalling = false;
                _progress = null;
                _errorMessage = null;
              });
              break;
            case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
            case OtaStatus.ALREADY_RUNNING_ERROR:
            case OtaStatus.INTERNAL_ERROR:
            case OtaStatus.DOWNLOAD_ERROR:
            case OtaStatus.CHECKSUM_ERROR:
            case OtaStatus.CANCELED:
              _handleOtaError(event.status, event.value);
              break;
          }
        },
        onError: (error) => _handleOtaError(null, error.toString()),
      );
    } catch (e) {
      _handleOtaError(null, e.toString());
    }
  }

  Future<bool> _ensureOtaPermissions() async {
    if (!Platform.isAndroid) {
      return true;
    }
    final results = await <Permission>[
      Permission.manageExternalStorage,
      Permission.storage,
      Permission.requestInstallPackages,
    ].request();

    final storageGranted =
        (results[Permission.manageExternalStorage]?.isGranted ?? false) ||
            (results[Permission.storage]?.isGranted ?? false);
    final installerGranted = results[Permission.requestInstallPackages]?.isGranted ?? false;
    return storageGranted && installerGranted;
  }

  void _handleOtaError(OtaStatus? status, String? message) {
    debugPrint('OTA update error: $status -> $message');
    if (!mounted) return;
    setState(() {
      _isInstalling = false;
      _progress = null;
      _errorMessage = message ?? 'ไม่สามารถอัปเดตได้';
    });
    _dialogSetState?.call(() {});
    if (status == OtaStatus.PERMISSION_NOT_GRANTED_ERROR) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาอนุญาตให้แอปติดตั้งไฟล์จากแหล่งอื่นใน Settings แล้วลองใหม่'),
        ),
      );
    }
  }

  bool get _showOverlay => _checking && !_dialogVisible && !_isInstalling;
  bool get _shouldRenderOverlay => widget.showCheckingOverlay && _showOverlay;

  @override
  Widget build(BuildContext context) {
    final overlay = _shouldRenderOverlay
        ? Container(
            key: const ValueKey('app-update-overlay'),
            color: Colors.black54,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                SizedBox(width: 32, height: 32, child: CircularProgressIndicator()),
                SizedBox(height: 12),
                Text(
                  'กำลังตรวจสอบอัปเดต...',
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          )
        : const SizedBox.shrink();

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            ignoring: !_shouldRenderOverlay,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: overlay,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _resetSkipIfNeeded(AppUpdateInfo info) async {
    final skipped = _skippedVersionCode;
    if (skipped != null && skipped != info.latestVersionCode) {
      await _prefs?.remove(_kSkippedVersionKey);
      if (!mounted) return;
      setState(() => _skippedVersionCode = null);
    }
  }

  Future<void> _rememberSkipForVersion(int versionCode) async {
    await _prefs?.setInt(_kSkippedVersionKey, versionCode);
    if (!mounted) return;
    setState(() => _skippedVersionCode = versionCode);
  }

  Future<void> _clearSkipRecord() async {
    if (_skippedVersionCode == null) {
      return;
    }
    await _prefs?.remove(_kSkippedVersionKey);
    if (!mounted) return;
    setState(() => _skippedVersionCode = null);
  }
}
