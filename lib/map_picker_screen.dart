import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

import 'utils/app_colors.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLatitude;
  final double? initialLongitude;

  const MapPickerScreen({
    super.key,
    this.initialLatitude,
    this.initialLongitude,
  });

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  GoogleMapController? _mapController;
  LatLng _selectedPosition = const LatLng(13.7563, 100.5018); // กรุงเทพ default
  bool _isLoadingLocation = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedPosition = LatLng(widget.initialLatitude!, widget.initialLongitude!);
    } else {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);

    try {
      // ตรวจสอบ permission
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('กรุณาเปิด GPS');
        setState(() => _isLoadingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('กรุณาอนุญาตการใช้งาน GPS');
          setState(() => _isLoadingLocation = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackBar('กรุณาเปิดการอนุญาต GPS ในการตั้งค่า');
        setState(() => _isLoadingLocation = false);
        return;
      }

      // ดึงตำแหน่งปัจจุบัน
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _selectedPosition = LatLng(position.latitude, position.longitude);
        _isLoadingLocation = false;
      });

      // เลื่อนแผนที่ไปยังตำแหน่งปัจจุบัน
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_selectedPosition, 16),
      );
    } catch (e) {
      _showSnackBar('ไม่สามารถดึงตำแหน่งได้: $e');
      setState(() => _isLoadingLocation = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เลือกตำแหน่งร้านค้า'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: () {
              // ส่งพิกัดกลับ
              Navigator.of(context).pop({
                'latitude': _selectedPosition.latitude,
                'longitude': _selectedPosition.longitude,
              });
            },
            tooltip: 'ยืนยันตำแหน่ง',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ค้นหาสถานที่หรือที่อยู่...',
                  prefixIcon: Icon(Icons.search),
                  suffixIcon: _isSearching
                      ? Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : (_searchController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 8),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (value) async {
                  if (value.trim().isEmpty) return;
                  setState(() => _isSearching = true);
                  try {
                    final locations = await locationFromAddress(value);
                    if (locations.isNotEmpty) {
                      final loc = locations.first;
                      final newPos = LatLng(loc.latitude, loc.longitude);
                      setState(() {
                        _selectedPosition = newPos;
                      });
                      _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));
                    } else {
                      _showSnackBar('ไม่พบตำแหน่งที่ค้นหา');
                    }
                  } catch (e) {
                    _showSnackBar('ค้นหาสถานที่ไม่สำเร็จ: $e');
                  }
                  setState(() => _isSearching = false);
                },
                onChanged: (value) => setState(() {}),
              ),
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                // ...existing code for GoogleMap, info card, buttons...
                // Google Map
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: _selectedPosition,
                    zoom: 16,
                  ),
                  onMapCreated: (controller) {
                    _mapController = controller;
                  },
                  onTap: (position) {
                    setState(() {
                      _selectedPosition = position;
                    });
                  },
                  markers: {
                    Marker(
                      markerId: const MarkerId('selected'),
                      position: _selectedPosition,
                      draggable: true,
                      onDragEnd: (position) {
                        setState(() {
                          _selectedPosition = position;
                        });
                      },
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        BitmapDescriptor.hueOrange,
                      ),
                    ),
                  },
                  myLocationEnabled: true,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                ),

                // ข้อมูลพิกัด (เลื่อนลงมาใต้ช่องค้นหา)
                Positioned(
                  top: 10, // Adjusted position
                  left: 16,
                  right: 16,
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'พิกัดที่เลือก:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${_selectedPosition.latitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          Text(
                            'Lng: ${_selectedPosition.longitude.toStringAsFixed(6)}',
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            '💡 แตะบนแผนที่เพื่อเลือกตำแหน่ง\nหรือลากหมุดเพื่อปรับ',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ปุ่มตำแหน่งปัจจุบัน
                Positioned(
                  bottom: 80,
                  right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    onPressed: _isLoadingLocation ? null : _getCurrentLocation,
                    child: _isLoadingLocation
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(
                            Icons.my_location,
                            color: AppColors.accent,
                          ),
                  ),
                ),

                // ปุ่มยืนยัน
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop({
                        'latitude': _selectedPosition.latitude,
                        'longitude': _selectedPosition.longitude,
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text(
                      'ยืนยันตำแหน่งนี้',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

    @override
    void dispose() {
      _searchController.dispose();
      _mapController?.dispose();
      super.dispose();
    }
}
