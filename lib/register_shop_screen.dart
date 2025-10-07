import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

class RegisterShopScreen extends StatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  State<RegisterShopScreen> createState() => _RegisterShopScreenState();
}

class _RegisterShopScreenState extends State<RegisterShopScreen> {
  final ImagePicker _picker = ImagePicker();
  XFile? _shopImage;
  XFile? _bankBookImage;
  GoogleMapController? _mapController;
  LatLng _shopLocation = const LatLng(13.7563, 100.5018); // Default to Bangkok
  final Set<Marker> _markers = {};

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

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    setState(() {
      _markers.add(
        Marker(
          markerId: const MarkerId('shop_location'),
          position: _shopLocation,
          infoWindow: const InfoWindow(
            title: 'ร้านของคุณ',
            snippet: 'ลากเพื่อเปลี่ยนตำแหน่ง',
          ),
          draggable: true,
          onDragEnd: (newPosition) {
            setState(() {
              _shopLocation = newPosition;
            });
          },
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ลงทะเบียนร้านของฉัน'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
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
                  color: Colors.grey[300],
                  child: _shopImage != null
                      ? Image.file(File(_shopImage!.path), fit: BoxFit.cover)
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 50),
                              Text('อัปโหลดรูปร้าน'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'ชื่อร้าน',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'ชื่อ-นามสกุล',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'ที่อยู่',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                height: 300,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: GoogleMap(
                  onMapCreated: _onMapCreated,
                  initialCameraPosition: CameraPosition(
                    target: _shopLocation,
                    zoom: 15,
                  ),
                  markers: _markers,
                ),
              ),
              const SizedBox(height: 20),
              const TextField(
                decoration: InputDecoration(
                  labelText: 'หมายเลขบัญชีธนาคาร',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              GestureDetector(
                onTap: () => _pickImage(ImageSource.gallery, isShopImage: false),
                child: Container(
                  height: 150,
                  width: double.infinity,
                  color: Colors.grey[300],
                  child: _bankBookImage != null
                      ? Image.file(File(_bankBookImage!.path), fit: BoxFit.cover)
                      : const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.camera_alt, size: 50),
                              Text('อัปโหลดภาพสมุดบัญชี'),
                            ],
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: const Text('บันทึก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
