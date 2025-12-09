import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'widgets/cached_app_image.dart';
import 'widgets/product_video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import '../models/product_model.dart'; // Import the model
import 'utils/app_colors.dart';
import 'storage_helper.dart';
import 'services/product_cache_service.dart';
import 'services/media_cache_service.dart';

class _ProductImageUploadResult {
  final String originalUrl;
  final String thumbnailUrl;
  final String? originalLocalPath;
  final String? thumbnailLocalPath;

  const _ProductImageUploadResult({
    required this.originalUrl,
    required this.thumbnailUrl,
    this.originalLocalPath,
    this.thumbnailLocalPath,
  });
}

class _ProductVideoUploadResult {
  final String videoUrl;
  final String? thumbnailUrl;
  final String? localVideoPath;
  final String? localThumbnailPath;

  const _ProductVideoUploadResult({
    required this.videoUrl,
    this.thumbnailUrl,
    this.localVideoPath,
    this.localThumbnailPath,
  });
}

class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;
  const AddProductScreen({super.key, this.productToEdit});

  @override
  AddProductScreenState createState() => AddProductScreenState();
}

class AddProductScreenState extends State<AddProductScreen> {
  // Controllers to get text from TextFields
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _colorsController = TextEditingController();
  final _sizesController = TextEditingController();
  final _weightController = TextEditingController();
  String _weightUnit = 'g';
  final _otherUnitController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<String> _existingImageUrls = [];
  List<String> _existingThumbnailUrls = [];
  final List<XFile> _newImageFiles = [];
  XFile? _videoFile;
  String? _existingVideoUrl;
  String? _existingVideoThumbnailUrl;
  final Map<String, String> _localMediaPaths = {};
  final Set<String> _cacheLookupInProgress = {};

  bool _isSaving = false;
  double? _uploadProgress;
  String? _uploadStatusText;

  static const int _maxImageCount = 10;
  static const Duration _maxVideoDuration = Duration(minutes: 5);
  static const int _imageCompressionSkipThresholdBytes = 600 * 1024; // 600 KB
  static const int _videoCompressionSkipThresholdBytes = 15 * 1024 * 1024; // 15 MB

  int get _currentImageCount => _existingImageUrls.length + _newImageFiles.length;

  String? _selectedUnit = 'ชิ้น';
  final List<String> _units = ['ชิ้น', 'มัด', 'ถุง', 'แพ็ค', 'กล่อง', 'อื่นๆ'];

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
          _productDescriptionController.text = p.description;
          final existingToppings = p.toppings?.trim();
          // Fall back to the old description value if this product was created before toppings existed.
        _descriptionController.text = (existingToppings != null && existingToppings.isNotEmpty)
          ? existingToppings
          : p.description;
      _priceController.text = p.price.toString();
      _stockController.text = p.stock.toString();
      _colorsController.text = p.colors.join(', ');
      _sizesController.text = p.sizes.join(', ');
      _weightController.text = p.weight?.toString() ?? '';
      if (p.weight != null) {
        _weightController.text = p.weight!.toString();
        _weightUnit = 'kg';
      }
      _selectedUnit = _units.contains(p.unit) ? p.unit : 'อื่นๆ';
      if (_selectedUnit == 'อื่นๆ') _otherUnitController.text = p.unit;
        _existingImageUrls = List<String>.from(p.imageUrls);
        _existingThumbnailUrls = p.thumbnailUrls.isNotEmpty
          ? List<String>.from(p.thumbnailUrls)
          : List<String>.from(p.imageUrls);
      _existingVideoUrl = p.videoUrl;
      _existingVideoThumbnailUrl = p.videoThumbnailUrl;
      _prefetchExistingMedia();
    }
  }

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _productDescriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _colorsController.dispose();
    _sizesController.dispose();
    _weightController.dispose();
    _otherUnitController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _pickImagesFromGallery() async {
    final remainingSlots = _maxImageCount - _currentImageCount;
    if (remainingSlots <= 0) {
      _showSnack('ใส่รูปได้สูงสุด $_maxImageCount รูป');
      return;
    }

    final List<XFile> picks = await _picker.pickMultiImage(imageQuality: 70);
    if (picks.isEmpty) return;

    final imagesToAdd = picks.take(remainingSlots).toList();
    setState(() => _newImageFiles.addAll(imagesToAdd));

    if (picks.length > remainingSlots) {
      _showSnack('ระบบเพิ่มรูปได้เพียง $_maxImageCount รูป แสดงเฉพาะ ${imagesToAdd.length} รูปแรก');
    }
  }

  Future<void> _captureImage() async {
    if (_currentImageCount >= _maxImageCount) {
      _showSnack('ใส่รูปได้สูงสุด $_maxImageCount รูป');
      return;
    }

    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (photo == null) return;
    setState(() => _newImageFiles.add(photo));
  }

  Future<void> _pickVideo() async {
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('ถ่ายวิดีโอ'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('เลือกจากแกลเลอรี'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final XFile? video = await _picker.pickVideo(source: source, maxDuration: _maxVideoDuration);
    if (video == null) return;

    setState(() {
      _videoFile = video;
      _existingVideoUrl = null;
    });
  }

  void _removeExistingImageAt(int index) {
    setState(() {
      if (index >= 0 && index < _existingImageUrls.length) {
        _localMediaPaths.remove(_existingImageUrls[index]);
        _existingImageUrls.removeAt(index);
      }
      if (index >= 0 && index < _existingThumbnailUrls.length) {
        _localMediaPaths.remove(_existingThumbnailUrls[index]);
        _existingThumbnailUrls.removeAt(index);
      }
    });
  }

  void _removeNewImageAt(int index) {
    setState(() => _newImageFiles.removeAt(index));
  }

  void _removeVideo() {
    setState(() {
      if (_existingVideoUrl != null) {
        _localMediaPaths.remove(_existingVideoUrl);
      }
      if (_existingVideoThumbnailUrl != null) {
        _localMediaPaths.remove(_existingVideoThumbnailUrl);
      }
      _videoFile = null;
      _existingVideoUrl = null;
      _existingVideoThumbnailUrl = null;
    });
  }

  void _prefetchExistingMedia() {
    for (final url in _existingImageUrls) {
      _tryWarmLocalCache(url);
    }
    for (final thumb in _existingThumbnailUrls) {
      _tryWarmLocalCache(thumb);
    }
    if (_existingVideoUrl != null) {
      _tryWarmLocalCache(_existingVideoUrl!);
    }
    if (_existingVideoThumbnailUrl != null) {
      _tryWarmLocalCache(_existingVideoThumbnailUrl!);
    }
  }

  Future<File> _compressImageFile(File sourceFile, {required bool forThumbnail}) async {
    final suffix = forThumbnail ? 'thumb' : 'full';
    final targetPath = '${Directory.systemTemp.path}/product_${DateTime.now().microsecondsSinceEpoch}_$suffix.webp';

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        sourceFile.path,
        targetPath,
        format: CompressFormat.webp,
        minWidth: forThumbnail ? 600 : 1600,
        minHeight: forThumbnail ? 600 : 1600,
        quality: forThumbnail ? 60 : 82,
      );
      if (compressed != null) {
        final compressedFile = File(compressed.path);
        final originalLength = await sourceFile.length();
        final compressedLength = await compressedFile.length();
        if (compressedLength < originalLength || forThumbnail) {
          return compressedFile;
        }
      }
    } catch (e, stack) {
      debugPrint('Image compression failed ($suffix): $e');
      debugPrint('$stack');
    }

    return sourceFile;
  }

  Future<File> _writeBytesToTempFile(Uint8List data, {required String suffix}) async {
    final tempPath = '${Directory.systemTemp.path}/product_${DateTime.now().microsecondsSinceEpoch}_$suffix';
    final file = File(tempPath);
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  Future<String> _uploadFileWithOptionalProgress(
    Reference ref,
    File file, {
    bool trackProgress = false,
  }) async {
    final uploadTask = ref.putFile(file);
    if (trackProgress) {
      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          setState(() {
            _uploadProgress = event.bytesTransferred / event.totalBytes;
          });
        }
      });
    }

    final snapshot = await uploadTask.whenComplete(() => {});

    if (trackProgress) {
      setState(() {
        _uploadProgress = null;
      });
    }

    return snapshot.ref.getDownloadURL();
  }

  Future<_ProductImageUploadResult?> _uploadImageToFirebase(XFile image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final sanitizedBase = image.name.split('.').first.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_$sanitizedBase.webp';

      final sourceFile = File(image.path);
      final sourceSize = await sourceFile.length();
      final shouldCompressOriginal = sourceSize > _imageCompressionSkipThresholdBytes;

      File originalUploadFile = sourceFile;
      if (shouldCompressOriginal) {
        originalUploadFile = await _compressImageFile(sourceFile, forThumbnail: false);
      }

      final thumbnailBase = shouldCompressOriginal ? originalUploadFile : sourceFile;
      final compressedThumbnail = await _compressImageFile(thumbnailBase, forThumbnail: true);

      final baseRef = StorageHelper.instance
          .ref()
          .child('product_images')
          .child(user.uid);

      final originalUrl = await _uploadFileWithOptionalProgress(
        baseRef.child(fileName),
        originalUploadFile,
        trackProgress: true,
      );
      final thumbnailUrl = await _uploadFileWithOptionalProgress(
        baseRef.child('thumbnails').child(fileName),
        compressedThumbnail,
      );

      final cachedOriginal = await MediaCacheService.instance.cacheUploadedFile(
        source: originalUploadFile,
        url: originalUrl,
        bucket: MediaCacheBucket.image,
      );
      final cachedThumbnail = await MediaCacheService.instance.cacheUploadedFile(
        source: compressedThumbnail,
        url: thumbnailUrl,
        bucket: MediaCacheBucket.thumbnail,
      );

      try {
        if (originalUploadFile.path != sourceFile.path && await originalUploadFile.exists()) {
          await originalUploadFile.delete();
        }
        if (compressedThumbnail.path != sourceFile.path && await compressedThumbnail.exists()) {
          await compressedThumbnail.delete();
        }
      } catch (cleanupError) {
        debugPrint('Failed to delete temp files: $cleanupError');
      }

      return _ProductImageUploadResult(
        originalUrl: originalUrl,
        thumbnailUrl: thumbnailUrl,
        originalLocalPath: cachedOriginal?.path,
        thumbnailLocalPath: cachedThumbnail?.path,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูป: $e')));
      }
      setState(() {
        _uploadProgress = null;
      });
      return null;
    }
  }

  Future<_ProductVideoUploadResult?> _uploadVideoToFirebase(XFile video) async {
    File? compressedFile;
    File? rawThumbFile;
    File? compressedThumbFile;
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final sanitizedBase = video.name.split('.').first.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoFileName = '${timestamp}_$sanitizedBase.mp4';
      final refBase = StorageHelper.instance.ref().child('product_videos').child(user.uid);

      final originalFile = File(video.path);
      final originalSize = await originalFile.length();
      File fileToUpload = originalFile;

      if (originalSize > _videoCompressionSkipThresholdBytes) {
        await VideoCompress.setLogLevel(0);
        final mediaInfo = await VideoCompress.compressVideo(
          video.path,
          quality: VideoQuality.LowQuality,
          includeAudio: true,
          deleteOrigin: false,
        );

        if (mediaInfo?.path != null) {
          compressedFile = File(mediaInfo!.path!);
          fileToUpload = compressedFile;
        }
      }

      final videoUrl = await _uploadFileWithOptionalProgress(
        refBase.child(videoFileName),
        fileToUpload,
        trackProgress: true,
      );

      String? thumbnailUrl;
      File? cachedVideoFile;
      File? cachedVideoThumb;
      try {
        final thumbBytes = await VideoCompress.getByteThumbnail(
          fileToUpload.path,
          quality: 70,
          position: -1,
        );
        if (thumbBytes != null) {
          rawThumbFile = await _writeBytesToTempFile(thumbBytes, suffix: 'video_thumb.jpg');
          compressedThumbFile = await _compressImageFile(rawThumbFile, forThumbnail: true);
          final thumbName = '${timestamp}_${sanitizedBase}_thumb.webp';
          thumbnailUrl = await _uploadFileWithOptionalProgress(
            refBase.child('thumbnails').child(thumbName),
            compressedThumbFile,
          );
        }
      } catch (thumbError, stack) {
        debugPrint('Video thumbnail generation failed: $thumbError');
        debugPrint('$stack');
      }

      cachedVideoFile = await MediaCacheService.instance.cacheUploadedFile(
        source: fileToUpload,
        url: videoUrl,
        bucket: MediaCacheBucket.video,
      );
      if (thumbnailUrl != null && compressedThumbFile != null) {
        cachedVideoThumb = await MediaCacheService.instance.cacheUploadedFile(
          source: compressedThumbFile,
          url: thumbnailUrl,
          bucket: MediaCacheBucket.videoThumbnail,
        );
      }

      return _ProductVideoUploadResult(
        videoUrl: videoUrl,
        thumbnailUrl: thumbnailUrl,
        localVideoPath: cachedVideoFile?.path,
        localThumbnailPath: cachedVideoThumb?.path,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดวิดีโอ: $e')));
      }
      setState(() { _uploadProgress = null; });
      return null;
    } finally {
      try {
        if (compressedFile != null && await compressedFile.exists()) {
          await compressedFile.delete();
        }
        if (rawThumbFile != null && await rawThumbFile.exists()) {
          await rawThumbFile.delete();
        }
        if (compressedThumbFile != null && await compressedThumbFile.exists()) {
          await compressedThumbFile.delete();
        }
        await VideoCompress.deleteAllCache();
      } catch (cleanupError) {
        debugPrint('Video temp cleanup failed: $cleanupError');
      }
    }
  }

  Future<void> _saveProduct() async {
    // Basic validation
    if (_currentImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาเพิ่มรูปสินค้าอย่างน้อย 1 รูป')));
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อสินค้า')));
      return;
    }

    if (_weightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกน้ำหนักสินค้า')));
      return;
    }
    final String weightValue = '${_weightController.text.trim()} $_weightUnit';

    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกราคา')));
      return;
    }

    if (_stockController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกสต็อกทั้งหมด')));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่')));
      return;
    }

    setState(() { _isSaving = true; });

    try {
      final List<String> imageUrls = List<String>.from(_existingImageUrls);
      final List<String> thumbnailUrls = List<String>.from(_existingThumbnailUrls);
      if (_newImageFiles.isNotEmpty) {
        for (var index = 0; index < _newImageFiles.length; index++) {
          if (mounted) {
            setState(() {
              _uploadStatusText = 'รูป ${index + 1}/${_newImageFiles.length}';
            });
          }
          final result = await _uploadImageToFirebase(_newImageFiles[index]);
          if (result == null) {
            throw Exception('การอัปโหลดรูปภาพบางรายการล้มเหลว');
          }
          imageUrls.add(result.originalUrl);
          thumbnailUrls.add(result.thumbnailUrl);
          if (result.originalLocalPath != null) {
            _localMediaPaths[result.originalUrl] = result.originalLocalPath!;
          }
          if (result.thumbnailLocalPath != null) {
            _localMediaPaths[result.thumbnailUrl] = result.thumbnailLocalPath!;
          }
        }
      }
      if (mounted) {
        setState(() => _uploadStatusText = null);
      }

      if (imageUrls.length > _maxImageCount) {
        imageUrls.removeRange(_maxImageCount, imageUrls.length);
        if (thumbnailUrls.length > _maxImageCount) {
          thumbnailUrls.removeRange(_maxImageCount, thumbnailUrls.length);
        }
      }

      // Ensure thumbnail list mirrors images for legacy data edge cases.
      while (thumbnailUrls.length < imageUrls.length) {
        thumbnailUrls.add(imageUrls[thumbnailUrls.length]);
      }
      if (thumbnailUrls.length > imageUrls.length) {
        thumbnailUrls.removeRange(imageUrls.length, thumbnailUrls.length);
      }

      String? videoUrl = _existingVideoUrl;
      String? videoThumbnailUrl = _existingVideoThumbnailUrl;
      if (_videoFile != null) {
        if (mounted) {
          setState(() {
            _uploadStatusText = 'กำลังอัปโหลดวิดีโอ';
          });
        }
        final uploadedVideo = await _uploadVideoToFirebase(_videoFile!);
        if (uploadedVideo != null) {
          videoUrl = uploadedVideo.videoUrl;
          videoThumbnailUrl = uploadedVideo.thumbnailUrl;
          if (uploadedVideo.localVideoPath != null) {
            _localMediaPaths[uploadedVideo.videoUrl] = uploadedVideo.localVideoPath!;
          }
          if (uploadedVideo.localThumbnailPath != null && uploadedVideo.thumbnailUrl != null) {
            _localMediaPaths[uploadedVideo.thumbnailUrl!] = uploadedVideo.localThumbnailPath!;
          }
        } else {
          throw Exception('การอัปโหลดวิดีโอล้มเหลว');
        }
        if (mounted) {
          setState(() => _uploadStatusText = null);
        }
      }

      final productDescription = _productDescriptionController.text.trim();
      final toppingsText = _descriptionController.text.trim();

      final productData = <String, dynamic>{
        'name': _nameController.text,
        'description': productDescription.isNotEmpty ? productDescription : toppingsText,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'imageUrls': imageUrls,
        'thumbnailUrls': thumbnailUrls,
        'colors': _colorsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          'sizes': _sizesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
          'weight': weightValue,
        'unit': _selectedUnit == 'อื่นๆ' ? _otherUnitController.text : _selectedUnit ?? '',
        'ownerUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (toppingsText.isNotEmpty) {
        productData['toppings'] = toppingsText;
      } else if (widget.productToEdit != null) {
        productData['toppings'] = FieldValue.delete();
      }

      if (videoUrl != null) {
        productData['videoUrl'] = videoUrl;
      } else if (widget.productToEdit != null && widget.productToEdit!.videoUrl != null) {
        productData['videoUrl'] = FieldValue.delete();
      }

      if (videoThumbnailUrl != null) {
        productData['videoThumbnailUrl'] = videoThumbnailUrl;
      } else if (widget.productToEdit != null && widget.productToEdit!.videoThumbnailUrl != null) {
        productData['videoThumbnailUrl'] = FieldValue.delete();
      }

      final productsRef = FirebaseFirestore.instance.collection('products');
      DocumentReference<Map<String, dynamic>> docRef;
      if (widget.productToEdit == null) {
        productData['createdAt'] = FieldValue.serverTimestamp();
        docRef = await productsRef.add(productData);
      } else {
        final targetId = widget.productToEdit!.id;
        if (targetId == null || targetId.isEmpty) {
          throw Exception('ไม่สามารถระบุรหัสสินค้าที่ต้องการแก้ไขได้');
        }
        docRef = productsRef.doc(targetId);
        await docRef.update(productData);
      }

      final latestSnapshot = await docRef.get();
      final latestData = latestSnapshot.data();
      if (latestData != null) {
        await ProductCacheService.instance.saveProducts(
          user.uid,
          [CachedProduct(id: docRef.id, data: latestData)],
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('บันทึกสินค้าเรียบร้อยแล้ว')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _uploadProgress = null;
          _uploadStatusText = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.productToEdit == null ? 'เพิ่มสินค้าใหม่' : 'แก้ไขสินค้า'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('รูปภาพและวิดีโอ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            _buildMediaSection(),
            if (_uploadProgress != null || _uploadStatusText != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: _uploadProgress),
                    const SizedBox(height: 8),
                    Text(
                      _uploadProgress != null
                          ? '${_uploadStatusText ?? 'กำลังอัปโหลด'}: ${(100 * _uploadProgress!).toStringAsFixed(0)}%'
                          : (_uploadStatusText ?? 'กำลังอัปโหลด'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 32),

            const Text('รายละเอียดสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(label: 'ชื่อสินค้า', controller: _nameController)),
                const SizedBox(width: 16),
                Expanded(child: _buildWeightField()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(label: 'ราคา', controller: _priceController, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(label: 'สต็อกทั้งหมด', controller: _stockController, keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (context) => _buildSpecificationSheet(),
                );
              },
              icon: const Icon(Icons.tune),
              label: const Text('ข้อมูลจำเพาะสินค้า (ท็อปปิ้ง, สี, ขนาด, หน่วย)', style: TextStyle(fontSize: 14)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: AppColors.accent, width: 1.5),
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _isSaving ? null : _saveProduct, // Disable button while saving
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('บันทึกสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),

          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    final bool hasImages = _currentImageCount > 0;
    final bool hasVideo = _videoFile != null || (_existingVideoUrl?.isNotEmpty ?? false);

    final Widget imageContent = hasImages
        ? _buildImagePreviewContent()
        : _buildPlaceholderSquare(
            icon: Icons.photo_library_outlined,
            label: 'ยังไม่มีรูปภาพ',
          );

    final Widget videoContent = hasVideo
        ? _buildVideoPreviewContent()
        : _buildPlaceholderSquare(
            icon: Icons.videocam_outlined,
            label: 'ยังไม่มีวิดีโอ',
          );

    final bool showCombinedRow = !hasImages && !hasVideo;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade400),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              ElevatedButton.icon(
                onPressed: _captureImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('ถ่ายรูป'),
              ),
              ElevatedButton.icon(
                onPressed: _pickImagesFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('เลือกรูป (${_currentImageCount}/$_maxImageCount)'),
              ),
              ElevatedButton.icon(
                onPressed: _pickVideo,
                icon: const Icon(Icons.videocam_outlined),
                label: const Text('เพิ่มวิดีโอ'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (showCombinedRow)
            Row(
              children: [
                Expanded(child: imageContent),
                const SizedBox(width: 12),
                Expanded(child: videoContent),
              ],
            )
          else ...[
            if (hasImages)
              imageContent
            else
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 120, child: imageContent),
              ),
            const SizedBox(height: 16),
            if (hasVideo)
              videoContent
            else
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(width: 120, child: videoContent),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildImagePreviewContent() {
    final List<Widget> tiles = <Widget>[];

    for (int i = 0; i < _existingImageUrls.length; i++) {
      final imageUrl = _existingImageUrls[i];
      final displayUrl = i < _existingThumbnailUrls.length ? _existingThumbnailUrls[i] : imageUrl;
      tiles.add(_buildImageTile(
        image: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _buildCachedImage(displayUrl),
        ),
        onRemove: () => _removeExistingImageAt(i),
      ));
    }

    for (int i = 0; i < _newImageFiles.length; i++) {
      final file = _newImageFiles[i];
      tiles.add(_buildImageTile(
        image: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(file.path),
            width: 110,
            height: 110,
            fit: BoxFit.cover,
          ),
        ),
        onRemove: () => _removeNewImageAt(i),
      ));
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: tiles,
    );
  }

  Widget _buildPlaceholderSquare({required IconData icon, required String label}) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade400),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.grey[500], size: 36),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCachedImage(String url) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Colors.black12,
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      );
    }
    final localPath = _localMediaPaths[url];
    if (localPath != null) {
      return Image.file(
        File(localPath),
        width: 110,
        height: 110,
        fit: BoxFit.cover,
      );
    }
    _tryWarmLocalCache(url);
    return CachedAppImage(
      imageUrl: url,
      width: 110,
      height: 110,
      fit: BoxFit.cover,
      errorWidget: const ColoredBox(
        color: Colors.black12,
        child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
      ),
    );
  }

  void _tryWarmLocalCache(String url) {
    if (url.isEmpty || _localMediaPaths.containsKey(url) || _cacheLookupInProgress.contains(url)) {
      return;
    }
    _cacheLookupInProgress.add(url);
    MediaCacheService.instance.getCachedPath(url).then((path) {
      _cacheLookupInProgress.remove(url);
      if (!mounted || path == null) return;
      if (_localMediaPaths[url] == path) return;
      setState(() {
        _localMediaPaths[url] = path;
      });
    });
  }

  Widget _buildImageTile({required Widget image, required VoidCallback onRemove}) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SizedBox(width: 110, height: 110, child: image),
        Positioned(
          top: -8,
          right: -8,
          child: InkWell(
            onTap: onRemove,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withAlpha(166),
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close, size: 16, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoPreviewContent() {
    final String? videoUrl = _videoFile != null
        ? null
        : _existingVideoUrl;
    final bool hasVideo = _videoFile != null || (videoUrl?.isNotEmpty ?? false);
    final String? cachedVideoPath = videoUrl != null ? _localMediaPaths[videoUrl] : null;
    final String? thumbnailUrl = _videoFile != null ? null : _existingVideoThumbnailUrl;
    final String? cachedThumbnailPath = thumbnailUrl != null ? _localMediaPaths[thumbnailUrl] : null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 36),
            title: Text(_videoFile != null ? _videoFile!.name : 'วิดีโอที่อัปโหลดแล้ว', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text('ความยาวไม่เกิน ${_maxVideoDuration.inMinutes} นาที'),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: _removeVideo,
            ),
          ),
          if (hasVideo)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: SizedBox(
                height: 220,
                child: _videoFile != null
                    ? ProductVideoPlayer(videoUrl: _videoFile!.path) // ส่วนนี้ถูกต้องแล้ว
                    : (videoUrl != null
                        ? ProductVideoPlayer(
                            videoUrl: cachedVideoPath ?? videoUrl,
                            thumbnailUrl: cachedThumbnailPath ?? thumbnailUrl,
                          )
                        : const Text('ไม่พบวิดีโอ')),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    String? hint,
    TextEditingController? controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(40),
              borderSide: const BorderSide(color: AppColors.accentDark, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('น้ำหนัก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.grey.shade400),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: 'ใส่น้ำหนัก',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 28,
                color: Colors.grey.shade300,
              ),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _weightUnit,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.black54),
                  style: const TextStyle(fontSize: 16, color: Colors.black87),
                  onChanged: (value) {
                    if (value == null) return;
                    setState(() => _weightUnit = value);
                  },
                  items: const [
                    DropdownMenuItem(value: 'g', child: Text('g')),
                    DropdownMenuItem(value: 'kg', child: Text('kg')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSpecificationSheet() {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ข้อมูลจำเพาะสินค้า', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildTextField(
              label: 'คำอธิบายสินค้า',
              controller: _productDescriptionController,
              hint: 'อธิบายรายละเอียดสินค้า',
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'ท็อปปิ้ง',
              controller: _descriptionController,
              hint: 'เช่น ไข่ดาว+10',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'สี (คั่นด้วยจุลภาค)',
              controller: _colorsController,
              hint: 'เช่น แดง, ขาว, ดำ',
            ),
            const SizedBox(height: 16),
            _buildTextField(
              label: 'ขนาด (คั่นด้วยจุลภาค)',
              controller: _sizesController,
              hint: 'เช่น S, M, L, XL',
            ),
            const SizedBox(height: 16),
            const Text('หน่วย', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              items: _units.map((String unit) {
                return DropdownMenuItem<String>(
                  value: unit,
                  child: Text(unit),
                );
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedUnit = newValue;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(40)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(color: AppColors.accentDark, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              ),
            ),
            if (_selectedUnit == 'อื่นๆ') ...[
              const SizedBox(height: 16),
              _buildTextField(
                label: 'ระบุหน่วย (อื่นๆ)',
                controller: _otherUnitController,
                hint: 'เช่น หลอด, ขวด, ซอง',
              ),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
              ),
              child: const Text('บันทึก', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
