import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/product_model.dart'; // Import the model
import 'utils/app_colors.dart';

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
  final _otherUnitController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  List<String> _existingImageUrls = [];
  final List<XFile> _newImageFiles = [];
  XFile? _videoFile;
  String? _existingVideoUrl;

  bool _isSaving = false;

  static const int _maxImageCount = 10;
  static const Duration _maxVideoDuration = Duration(minutes: 5);

  int get _currentImageCount => _existingImageUrls.length + _newImageFiles.length;

  String? _selectedUnit = 'ชิ้น';
  final List<String> _units = ['ชิ้น', 'มัด', 'ถุง', 'แพ็ค', 'กล่อง', 'อื่นๆ'];

  @override
  void initState() {
    super.initState();
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _descriptionController.text = p.description;
      _priceController.text = p.price.toString();
      _stockController.text = p.stock.toString();
      _colorsController.text = p.colors.join(', ');
      _sizesController.text = p.sizes.join(', ');
      _weightController.text = p.weight?.toString() ?? '';
      _selectedUnit = _units.contains(p.unit) ? p.unit : 'อื่นๆ';
      if (_selectedUnit == 'อื่นๆ') _otherUnitController.text = p.unit;
      _existingImageUrls = p.imageUrls;
      _existingVideoUrl = p.videoUrl;
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
    setState(() => _existingImageUrls.removeAt(index));
  }

  void _removeNewImageAt(int index) {
    setState(() => _newImageFiles.removeAt(index));
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
      _existingVideoUrl = null;
    });
  }

  Future<String?> _uploadImageToFirebase(XFile image) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception("User not logged in");

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('product_images')
          .child(user.uid) // Organize images by user
          .child(fileName);

      final uploadTask = ref.putFile(File(image.path));
      final snapshot = await uploadTask.whenComplete(() => {});
      final downloadUrl = await snapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูป: $e')));
      }
      // Rethrow to stop the save process
      return null;
    }
  }

  Future<String?> _uploadVideoToFirebase(XFile video) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${video.name}';
      final ref = FirebaseStorage.instance
          .ref()
          .child('product_videos')
          .child(user.uid)
          .child(fileName);

      final uploadTask = ref.putFile(File(video.path));
      final snapshot = await uploadTask.whenComplete(() => {});
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดวิดีโอ: $e')));
      }
      return null;
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
    // น้ำหนักสามารถเป็นตัวเลขหรือข้อความได้
    final String weightValue = _weightController.text.trim();

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
      if (_newImageFiles.isNotEmpty) {
        final uploads = await Future.wait(_newImageFiles.map(_uploadImageToFirebase));
        if (uploads.any((url) => url == null)) {
          throw Exception('การอัปโหลดรูปภาพบางรายการล้มเหลว');
        }
        imageUrls.addAll(uploads.whereType<String>());
      }

      if (imageUrls.length > _maxImageCount) {
        imageUrls.removeRange(_maxImageCount, imageUrls.length);
      }

      String? videoUrl = _existingVideoUrl;
      if (_videoFile != null) {
        final uploadedVideo = await _uploadVideoToFirebase(_videoFile!);
        if (uploadedVideo != null) {
          videoUrl = uploadedVideo;
        } else {
          throw Exception('การอัปโหลดวิดีโอล้มเหลว');
        }
      }

      final productData = {
        'name': _nameController.text,
        'description': _descriptionController.text,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'imageUrls': imageUrls,
        'colors': _colorsController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
        'sizes': _sizesController.text.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
  'weight': weightValue,
        'unit': _selectedUnit == 'อื่นๆ' ? _otherUnitController.text : _selectedUnit ?? '',
        'ownerUid': user.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (videoUrl != null) {
        productData['videoUrl'] = videoUrl;
      } else if (widget.productToEdit != null && widget.productToEdit!.videoUrl != null) {
        productData['videoUrl'] = FieldValue.delete();
      }

      if (widget.productToEdit == null) {
        productData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('products').add(productData);
      } else {
        await FirebaseFirestore.instance.collection('products').doc(widget.productToEdit!.id).update(productData);
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
        setState(() { _isSaving = false; });
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
            const SizedBox(height: 32),

            const Text('รายละเอียดสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: _buildTextField(label: 'ชื่อสินค้า', controller: _nameController)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(label: 'น้ำหนัก', controller: _weightController, keyboardType: TextInputType.number)),
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
      tiles.add(_buildImageTile(
        image: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            imageUrl,
            width: 110,
            height: 110,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => const ColoredBox(
              color: Colors.black12,
              child: Icon(Icons.broken_image, size: 40, color: Colors.grey),
            ),
          ),
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
    final String title = _videoFile != null
        ? _videoFile!.name
        : 'วิดีโอที่อัปโหลดแล้ว';

    return Card( 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: ListTile(
  leading: const Icon(Icons.play_circle_fill, color: AppColors.accent, size: 36),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('ความยาวไม่เกิน ${_maxVideoDuration.inMinutes} นาที'),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _removeVideo,
        ),
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
