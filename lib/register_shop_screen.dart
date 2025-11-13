import 'dart:io';
import 'package:flutter/material.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart'; // Comment out for now
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'utils/app_colors.dart';

class RegisterShopScreen extends StatefulWidget {
  final String? serviceType;
  final DocumentSnapshot? shopData;
  const RegisterShopScreen({super.key, this.serviceType, this.shopData});
  
  @override
  State<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends State<RegisterShopScreen> {
  String? _shopImageUrl;
  String? _bankBookImageUrl;

  @override
  void initState() {
    super.initState();
    // ถ้ามีข้อมูลร้านค้าเดิม ให้เติมลงในฟอร์ม
    final data = widget.shopData?.data() as Map<String, dynamic>?;
    if (data != null) {
      _shopNameController.text = data['shopName'] ?? '';
      _ownerNameController.text = data['ownerName'] ?? '';
      _addressController.text = data['address'] ?? '';
      _bankAccountController.text = data['bankAccount'] ?? '';
      // โหลดรูปภาพร้านค้าเดิม
      if (data['shopImageUrl'] != null && data['shopImageUrl'].toString().isNotEmpty) {
        _shopImage = null; // จะใช้ url ในการแสดงแทน
        _shopImageUrl = data['shopImageUrl'];
      }
      if (data['bankBookImageUrl'] != null && data['bankBookImageUrl'].toString().isNotEmpty) {
        _bankBookImage = null;
        _bankBookImageUrl = data['bankBookImageUrl'];
      }
    }
  }
  final _shopNameController = TextEditingController();
  final _ownerNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _bankAccountController = TextEditingController();

  final ImagePicker _picker = ImagePicker();
  XFile? _shopImage;
  XFile? _bankBookImage;
  // GoogleMapController? _mapController;
  // LatLng _shopLocation = const LatLng(13.7563, 100.5018); // Default to Bangkok
  // final Set<Marker> _markers = {};

  bool _isSaving = false;

  // --- Lifecycle Methods ---

  Future<void> _pickImage(ImageSource source, {required bool isShopImage}) async {
    final XFile? pickedFile = await _picker.pickImage(source: source);
    setState(() {
      if (isShopImage) {
        _shopImage = pickedFile;
      } else {
        _bankBookImage = pickedFile;
      }
    });
  }

  // void _onMapCreated(GoogleMapController controller) {
  //   _mapController = controller;
  //   setState(() {
  //     _markers.add(
  //       Marker(
  //         markerId: const MarkerId('shop_location'),
  //         position: _shopLocation,
  //         infoWindow: const InfoWindow(
  //           title: 'ร้านของคุณ',
  //           snippet: 'ลากเพื่อเปลี่ยนตำแหน่ง',
  //         ),
  //         draggable: true,
  //         onDragEnd: (newPosition) {
  //           setState(() {
  //             _shopLocation = newPosition;
  //           });
  //         },
  //       ),
  //     );
  //   });
  // }

  Future<String?> _uploadImage(XFile imageFile, String path) async {
    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}_${imageFile.name}';
      final ref = FirebaseStorage.instance.ref().child(path).child(fileName);
      await ref.putFile(File(imageFile.path));
      return await ref.getDownloadURL();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูป: $e')));
      }
      return null;
    }
  }

  Future<void> _saveShopData() async {
    if (_shopNameController.text.isEmpty || _ownerNameController.text.isEmpty || _addressController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณากรอกข้อมูลร้านค้าให้ครบถ้วน')));
      return;
    }
    if (_shopImage == null && _shopImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('กรุณาอัปโหลดรูปร้านค้า')));
      return;
    }

    setState(() => _isSaving = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่อีกครั้ง');
      }

      if (widget.serviceType == null || widget.serviceType!.isEmpty) {
        throw Exception('ไม่พบประเภทบริการ กรุณากลับไปเลือกประเภทบริการใหม่อีกครั้ง');
      }

      String? shopImageUrl = _shopImageUrl;
      String? bankBookImageUrl = _bankBookImageUrl;
      if (_shopImage != null) {
        shopImageUrl = await _uploadImage(_shopImage!, 'shop_images');
      }
      if (_bankBookImage != null) {
        bankBookImageUrl = await _uploadImage(_bankBookImage!, 'bank_book_images');
      }

      if (shopImageUrl == null) {
        throw Exception('ไม่สามารถอัปโหลดรูปร้านค้าได้');
      }

      await FirebaseFirestore.instance.collection('shops').doc(user.uid).set({
        'shopName': _shopNameController.text,
        'ownerName': _ownerNameController.text,
        'address': _addressController.text,
        'bankAccount': _bankAccountController.text,
        'shopImageUrl': shopImageUrl,
        'bankBookImageUrl': bankBookImageUrl,
        'ownerUid': user.uid,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ ลงทะเบียนร้านค้าสำเร็จ!'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('เกิดข้อผิดพลาด: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_left, size: 32),
          tooltip: 'ย้อนกลับ',
          onPressed: () => Navigator.of(context).maybePop(),
        ), 
  title: const Text('ลงทะเบียนร้านของฉัน'),
  backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery, isShopImage: true),
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _shopImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_shopImage!.path), fit: BoxFit.cover))
                      : (_shopImageUrl != null)
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_shopImageUrl!, fit: BoxFit.cover))
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
                                  Text('อัปโหลดรูปร้าน'),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 20),
              _buildTextField(label: 'ชื่อร้าน', controller: _shopNameController, icon: Icons.storefront),
              const SizedBox(height: 20),
              _buildTextField(label: 'ชื่อ-นามสกุล เจ้าของร้าน', controller: _ownerNameController, icon: Icons.person_outline),
              const SizedBox(height: 20),
              _buildTextField(
                label: 'ที่อยู่',
                controller: _addressController,
                maxLines: 3,
                hint: 'บ้านเลขที่, ถนน, ตำบล, อำเภอ, จังหวัด, รหัสไปรษณีย์',
              ),
              // --- Google Maps Placeholder ---
              const SizedBox(height: 20),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey[200],
                ),
                child: const Center(
                  child: Text(
                    'ฟีเจอร์แผนที่จะพร้อมใช้งานเร็วๆ นี้',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              // --- Bank Account Section ---
              const SizedBox(height: 20),
              _buildTextField(label: 'หมายเลขบัญชีธนาคาร (สำหรับรับเงิน)', controller: _bankAccountController, keyboardType: TextInputType.number, icon: Icons.account_balance),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery, isShopImage: false),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                  child: _bankBookImage != null
                      ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_bankBookImage!.path), fit: BoxFit.cover))
                      : (_bankBookImageUrl != null)
                          ? ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.network(_bankBookImageUrl!, fit: BoxFit.cover))
                          : const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo_outlined, size: 50, color: Colors.grey),
                                  Text('อัปโหลดภาพสมุดบัญชี'),
                                ],
                              ),
                            ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveShopData,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('บันทึกข้อมูลร้านค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? hint, TextEditingController? controller, IconData? icon}) {
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
            prefixIcon: icon != null ? Icon(icon) : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
