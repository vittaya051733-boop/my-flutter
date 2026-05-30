import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'widgets/cached_app_image.dart';
import 'widgets/product_video_player.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:video_compress/video_compress.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:http/http.dart' as http;
import '../models/product_model.dart'; // Import the model
import 'utils/app_colors.dart';
import 'utils/shop_profile_resolver.dart';
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

class _AiProductAnalysisResult {
  const _AiProductAnalysisResult({
    this.productName,
    this.description,
    this.taxStatus,
    this.taxReason,
    this.productCategory,
    this.productType,
    this.isLegalInThailand,
    this.legalReason,
    this.isFreshProduct,
    this.isProcessed,
    this.canShipNationwide,
    this.nationwideShippingReason,
  });

  final String? productName;
  final String? description;
  final String? taxStatus;
  final String? taxReason;
  final String? productCategory;
  final String? productType;
  final bool? isLegalInThailand;
  final String? legalReason;
  final bool? isFreshProduct;
  final bool? isProcessed;
  final bool? canShipNationwide;
  final String? nationwideShippingReason;
}

/// แอดมิน (van4) อัปโหลดสินค้าแทนร้าน — ใช้ UI เดียวกับฝั่งร้านค้า
class AdminProductUploadContext {
  const AdminProductUploadContext({
    required this.ownerUid,
    required this.shopName,
    required this.serviceType,
  });

  final String ownerUid;
  final String shopName;
  final String serviceType;
}

class AddProductScreen extends StatefulWidget {
  final Product? productToEdit;
  final AdminProductUploadContext? adminUploadContext;

  const AddProductScreen({
    super.key,
    this.productToEdit,
    this.adminUploadContext,
  });

  @override
  AddProductScreenState createState() => AddProductScreenState();
}

class AddProductScreenState extends State<AddProductScreen> {
  static const double _gpRate = 0.18;

  bool get _isAdminDelegatedUpload => widget.adminUploadContext != null;

  String? get _effectiveOwnerUid =>
      widget.adminUploadContext?.ownerUid ??
      FirebaseAuth.instance.currentUser?.uid;

  // Controllers to get text from TextFields
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _productDescriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _preparationTimeController = TextEditingController(text: '10');
  final _colorsController = TextEditingController();
  final _sizesController = TextEditingController();
  final _weightController = TextEditingController();
  final _parcelLengthController = TextEditingController();
  final _parcelWidthController = TextEditingController();
  final _parcelHeightController = TextEditingController();
  final FocusNode _priceFocusNode = FocusNode();
  final FocusNode _toppingsFocusNode = FocusNode();
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
  bool _isResolvingServiceType = true;
  bool _showPriceGuidance = false;
  bool _showPreparationTimeGuidance = false;
  bool _showToppingsGuidance = false;
  bool _priceGuidanceDismissedWhileFocused = false;
  bool _isGeneratingAiDescription = false;
  bool _isAnalyzingProductWithAi = false;
  bool _hasUsedAiDescriptionForProduct = false;
  bool _hasUsedAiProductAnalysisForProduct = false;
  String? _aiTaxAnalysisReason;
  bool _hasAiTaxAnalysis = false;
  bool? _aiIsLegalInThailand;
  String? _aiLegalAnalysisReason;
  String? _aiProductType;
  bool? _aiCanShipNationwide;
  String? _aiNationwideShippingReason;
  bool _manualCanShipNationwide = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _aiQueueSubscription;
  String? _aiQueueStatusText;
  bool _aiQueueExternalRecommendation = false;
  double? _uploadProgress;
  String? _uploadStatusText;

  static const int _shopMaxImageCount = 10;
  static const int _defaultMaxImageCount = 1;
  static const Duration _maxVideoDuration = Duration(minutes: 5);
  int? _adminMaxImageCount;
  bool? _adminCanUploadVideo;
  static const int _videoCompressionSkipThresholdBytes =
      15 * 1024 * 1024; // 15 MB
  static const int _pickerImageQuality = 75;
  static const int _uploadImageQuality = 78;
  static const int _thumbnailImageQuality = 60;
  String? _serviceType;

  int get _currentImageCount =>
      _existingImageUrls.length + _newImageFiles.length;
  bool get _isShopServiceType =>
      _normalizeServiceType(_serviceType) == 'ร้านค้า';
  bool get _canAddVideo {
    if (_adminCanUploadVideo != null) {
      return _adminCanUploadVideo!;
    }
    return _isShopServiceType;
  }

  int get _maxImageCount {
    if (_adminMaxImageCount != null && _adminMaxImageCount! > 0) {
      return _adminMaxImageCount!;
    }
    return _isShopServiceType ? _shopMaxImageCount : _defaultMaxImageCount;
  }

  String? _selectedUnit = 'ชิ้น';
  final List<String> _units = ['ชิ้น', 'มัด', 'ถุง', 'แพ็ค', 'กล่อง', 'อื่นๆ'];
  String? _selectedProductCategory;
  bool _isFreshProduct = false;
  bool _isProcessed = false;
  bool _pharmacyIsTaxable = true;
  final List<String> _productCategories = [
    'ของสด',
    'อาหารแปรรูป',
    'สินค้าทั่วไป',
    'ร้านขายยาและเวชภัณฑ์',
    'สินค้าเกษตร',
  ];

  @override
  void initState() {
    super.initState();
    _priceFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        if (_priceFocusNode.hasFocus) {
          _showPriceGuidance = !_priceGuidanceDismissedWhileFocused;
          _showToppingsGuidance = false;
        } else {
          _priceGuidanceDismissedWhileFocused = false;
          _showPriceGuidance = false;
        }
      });
    });
    _toppingsFocusNode.addListener(() {
      if (!mounted) return;
      setState(() {
        _showToppingsGuidance = _toppingsFocusNode.hasFocus;
        if (_toppingsFocusNode.hasFocus) {
          _showPriceGuidance = false;
          _showPreparationTimeGuidance = false;
        }
      });
    });
    if (widget.adminUploadContext != null) {
      _serviceType = widget.adminUploadContext!.serviceType;
      _isResolvingServiceType = false;
    } else {
      _loadCurrentServiceType();
    }
    unawaited(_loadAdminMediaSettings());
    if (widget.productToEdit != null) {
      final p = widget.productToEdit!;
      _nameController.text = p.name;
      _productDescriptionController.text = p.description;
      final existingToppings = p.toppings?.trim();
      // Fall back to the old description value if this product was created before toppings existed.
      _descriptionController.text =
          (existingToppings != null && existingToppings.isNotEmpty)
          ? existingToppings
          : p.description;
      _priceController.text = p.price.toString();
      _stockController.text = p.stock.toString();
      _preparationTimeController.text = p.preparationTimeMinutes.toString();
      _colorsController.text = p.colors.join(', ');
      _sizesController.text = p.sizes.join(', ');
      _weightController.text = p.weight?.toString() ?? '';
      if (p.weight != null) {
        _weightController.text = p.weight!.toString();
        _weightUnit = 'kg';
      }
      _parcelLengthController.text = p.parcelLengthCm?.toString() ?? '';
      _parcelWidthController.text = p.parcelWidthCm?.toString() ?? '';
      _parcelHeightController.text = p.parcelHeightCm?.toString() ?? '';
      _selectedUnit = _units.contains(p.unit) ? p.unit : 'อื่นๆ';
      if (_selectedUnit == 'อื่นๆ') _otherUnitController.text = p.unit;
      _selectedProductCategory = _productCategories.contains(p.productCategory)
          ? p.productCategory
          : null;
      _isFreshProduct = p.isFreshProduct;
      _isProcessed = p.isProcessed;
      _pharmacyIsTaxable = p.taxStatus != 'exempt';
      _hasUsedAiDescriptionForProduct = p.aiDescriptionRequested;
      _hasUsedAiProductAnalysisForProduct = p.aiProductAnalysisRequested;
      _aiTaxAnalysisReason = p.taxAiReason;
      _hasAiTaxAnalysis = (p.taxAiReason ?? '').trim().isNotEmpty;
      _aiIsLegalInThailand = p.aiIsLegalInThailand;
      _aiLegalAnalysisReason = p.aiLegalAnalysisReason;
      _aiProductType = p.aiProductType;
      _aiCanShipNationwide = p.canShipNationwide;
      _aiNationwideShippingReason = p.nationwideShippingReason;
      _manualCanShipNationwide = p.canShipNationwide ?? false;
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
    _priceFocusNode.dispose();
    _toppingsFocusNode.dispose();
    _stockController.dispose();
    _preparationTimeController.dispose();
    _colorsController.dispose();
    _sizesController.dispose();
    _weightController.dispose();
    _parcelLengthController.dispose();
    _parcelWidthController.dispose();
    _parcelHeightController.dispose();
    _otherUnitController.dispose();
    _aiQueueSubscription?.cancel();
    super.dispose();
  }

  double? get _enteredPrice {
    final rawValue = _priceController.text.trim().replaceAll(',', '');
    if (rawValue.isEmpty) {
      return null;
    }
    return double.tryParse(rawValue);
  }

  double? get _netPriceAfterGp {
    final enteredPrice = _enteredPrice;
    if (enteredPrice == null) {
      return null;
    }
    return enteredPrice * (1 - _gpRate);
  }

  String _formatPriceDisplay(double value) {
    if (value == value.roundToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _hideFieldGuidance() {
    if (!_showPriceGuidance &&
        !_showPreparationTimeGuidance &&
        !_showToppingsGuidance) {
      return;
    }
    setState(() {
      _showPriceGuidance = false;
      _showPreparationTimeGuidance = false;
      _showToppingsGuidance = false;
    });
  }

  Widget _buildDismissibleGuidance({required String message, Widget? footer}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: AppColors.accentLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accent.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            message,
            textAlign: TextAlign.start,
            softWrap: true,
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF7C2D12),
              fontWeight: FontWeight.w600,
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Align(alignment: Alignment.centerLeft, child: footer),
          ],
        ],
      ),
    );
  }

  Widget _buildGuidedFieldOverlay({
    required Widget field,
    required bool showGuidance,
    required String guidanceMessage,
    Widget? footer,
  }) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        field,
        if (showGuidance)
          Positioned(
            left: 2,
            right: 2,
            bottom: 58,
            child: _buildDismissibleGuidance(
              message: guidanceMessage,
              footer: footer,
            ),
          ),
      ],
    );
  }

  bool get _isPharmacyCategory =>
      _selectedProductCategory == 'ร้านขายยาและเวชภัณฑ์';

  String get _computedTaxStatus {
    if (_isPharmacyCategory) {
      return _pharmacyIsTaxable ? 'taxable' : 'exempt';
    }
    return (_isFreshProduct && !_isProcessed) ? 'exempt' : 'taxable';
  }

  String get _taxStatusLabel => _computedTaxStatus == 'exempt'
      ? 'สินค้านี้ยกเว้นภาษี'
      : 'สินค้านี้เสียภาษี';

  Color get _taxStatusColor => _computedTaxStatus == 'exempt'
      ? const Color(0xFF2E7D32)
      : const Color(0xFFC62828);

  String get _taxReason {
    final aiReason = _aiTaxAnalysisReason?.trim();
    if (aiReason != null && aiReason.isNotEmpty) {
      return aiReason;
    }
    if (_isPharmacyCategory) {
      return _pharmacyIsTaxable
          ? 'ร้านค้าระบุว่ายาหรือเวชภัณฑ์รายการนี้อยู่ในกลุ่มที่เสียภาษี'
          : 'ร้านค้าระบุว่ายาหรือเวชภัณฑ์รายการนี้อยู่ในกลุ่มที่ยกเว้นภาษี';
    }
    if (_isFreshProduct && !_isProcessed) {
      return 'ของสดที่ยังไม่ผ่านการแปรรูป';
    }
    if (_isFreshProduct && _isProcessed) {
      return 'ของสดที่ผ่านการแปรรูปแล้ว';
    }
    return 'สินค้าไม่ได้เข้ากลุ่มของสดไม่แปรรูป';
  }

  bool get _resolvedCanShipNationwide =>
      _aiCanShipNationwide ?? _manualCanShipNationwide;

  String get _resolvedNationwideShippingReason {
    final aiReason = _aiNationwideShippingReason?.trim();
    if (_aiCanShipNationwide != null &&
        aiReason != null &&
        aiReason.isNotEmpty) {
      return aiReason;
    }
    return _manualCanShipNationwide
        ? 'ร้านค้าระบุว่าสินค้านี้เหมาะกับการส่งทั่วประเทศ'
        : 'ร้านค้าระบุว่าสินค้านี้ไม่เหมาะกับการส่งทั่วประเทศ';
  }

  String? _normalizeServiceType(String? rawValue) {
    final value = rawValue?.trim();
    switch (value) {
      case 'market':
      case 'ตลาดสด':
        return 'ตลาด';
      case 'shop':
      case 'store':
        return 'ร้านค้า';
      case 'restaurant':
        return 'ร้านอาหาร';
      case 'pharmacy':
        return 'ร้านขายยา';
      case 'agriculture':
      case 'farm':
      case 'สินค้าเกษตร':
        return 'สินค้าเกษตร';
      default:
        return value;
    }
  }

  String? _readServiceTypeFromData(Map<String, dynamic>? data) {
    if (data == null) return null;
    const keys = <String>['serviceType', 'service_type', 'category', 'type'];
    for (final key in keys) {
      final value = data[key]?.toString();
      final normalized = _normalizeServiceType(value);
      if (normalized != null && normalized.isNotEmpty) {
        return normalized;
      }
    }
    return null;
  }

  String? _resolveStringField(Map<String, dynamic>? data, List<String> keys) {
    if (data == null) return null;
    for (final key in keys) {
      final value = data[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  double? _parseDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  Map<String, double?> _extractLocation(Map<String, dynamic>? data) {
    final dynamic locationValue =
        data?['location'] ??
        data?['coordinates'] ??
        data?['geo'] ??
        data?['position'] ??
        data?['shopLocation'];

    if (locationValue is GeoPoint) {
      return <String, double?>{
        'latitude': locationValue.latitude,
        'longitude': locationValue.longitude,
      };
    }

    if (locationValue is Map) {
      final map = Map<String, dynamic>.from(locationValue);
      final lat = _parseDouble(map['latitude'] ?? map['lat'] ?? map['y']);
      final lng = _parseDouble(
        map['longitude'] ?? map['lng'] ?? map['long'] ?? map['x'],
      );
      return <String, double?>{'latitude': lat, 'longitude': lng};
    }

    return <String, double?>{
      'latitude': _parseDouble(data?['latitude'] ?? data?['lat'] ?? data?['y']),
      'longitude': _parseDouble(
        data?['longitude'] ?? data?['lng'] ?? data?['long'] ?? data?['x'],
      ),
    };
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findShopDocInCollection(
    String collection,
    String userId,
    String? email,
  ) async {
    final col = FirebaseFirestore.instance.collection(collection);

    try {
      final directDoc = await col.doc(userId).get();
      if (directDoc.exists) {
        return directDoc;
      }

      final ownerQuery = await col
          .where('ownerId', isEqualTo: userId)
          .limit(1)
          .get();
      if (ownerQuery.docs.isNotEmpty) {
        return ownerQuery.docs.first;
      }

      final normalizedEmail = email?.trim().toLowerCase();
      if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
        final emailQuery = await col
            .where('email', isEqualTo: normalizedEmail)
            .limit(1)
            .get();
        if (emailQuery.docs.isNotEmpty) {
          return emailQuery.docs.first;
        }
        final rawEmailQuery = await col
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (rawEmailQuery.docs.isNotEmpty) {
          return rawEmailQuery.docs.first;
        }
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
      debugPrint(
        'Skipping inaccessible registration collection $collection: ${e.message ?? e.code}',
      );
    }

    return null;
  }

  Future<Map<String, dynamic>?> _resolveShopProfileData(
    String userId,
    String? normalizedServiceType,
    String? email,
  ) async {
    const collectionByType = <String, String>{
      'ตลาด': 'market_registrations',
      'ร้านค้า': 'shop_registrations',
      'ร้านอาหาร': 'restaurant_registrations',
      'ร้านขายยา': 'pharmacy_registrations',
      'สินค้าเกษตร': 'agriculture_registrations',
    };

    const serviceByCollection = <String, String>{
      'market_registrations': 'ตลาด',
      'shop_registrations': 'ร้านค้า',
      'restaurant_registrations': 'ร้านอาหาร',
      'pharmacy_registrations': 'ร้านขายยา',
      'agriculture_registrations': 'สินค้าเกษตร',
    };

    String? hintedServiceType = normalizedServiceType;
    try {
      final contractDoc = await FirebaseFirestore.instance
          .collection('contracts')
          .doc(userId)
          .get();
      hintedServiceType =
          _normalizeServiceType(
            contractDoc.data()?['serviceType']?.toString(),
          ) ??
          hintedServiceType;
    } catch (_) {
      // Ignore contract read failures and continue with available hints.
    }

    final prioritizedCollections = <String>[
      if (hintedServiceType != null &&
          collectionByType.containsKey(hintedServiceType))
        collectionByType[hintedServiceType]!,
      ...collectionByType.values,
    ];

    final visited = <String>{};
    for (final collection in prioritizedCollections) {
      if (!visited.add(collection)) continue;
      final doc = await _findShopDocInCollection(collection, userId, email);
      if (doc == null) continue;

      final data = Map<String, dynamic>.from(doc.data() ?? <String, dynamic>{});
      data.putIfAbsent('serviceType', () => serviceByCollection[collection]);
      return data;
    }

    // Fallback for accounts whose registration docs are unavailable/incomplete.
    // These documents are self-owned and allowed by current rules.
    final fallbackCollections = <String>['public_shops', 'users', 'contracts'];
    Map<String, dynamic>? mergedFallback;
    for (final collection in fallbackCollections) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(collection)
            .doc(userId)
            .get();
        if (!doc.exists || doc.data() == null) {
          continue;
        }

        final data = Map<String, dynamic>.from(doc.data()!);
        mergedFallback ??= <String, dynamic>{};
        mergedFallback.addAll(data);
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
        debugPrint(
          'Skipping inaccessible fallback profile collection $collection: ${e.message ?? e.code}',
        );
      }
    }

    if (mergedFallback != null) {
      if (email != null && email.trim().isNotEmpty) {
        mergedFallback.putIfAbsent('email', () => email.trim());
      }
      if (normalizedServiceType != null) {
        mergedFallback.putIfAbsent('serviceType', () => normalizedServiceType);
      }
      return mergedFallback;
    }

    return null;
  }

  Future<String?> _resolveServiceTypeFromRegistrations(String userId) async {
    const registrationCollections = <MapEntry<String, String>>[
      MapEntry<String, String>('market_registrations', 'ตลาด'),
      MapEntry<String, String>('shop_registrations', 'ร้านค้า'),
      MapEntry<String, String>('restaurant_registrations', 'ร้านอาหาร'),
      MapEntry<String, String>('pharmacy_registrations', 'ร้านขายยา'),
      MapEntry<String, String>('agriculture_registrations', 'สินค้าเกษตร'),
    ];

    for (final entry in registrationCollections) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection(entry.key)
            .doc(userId)
            .get();
        if (!doc.exists) continue;
        return _readServiceTypeFromData(doc.data()) ?? entry.value;
      } on FirebaseException catch (e) {
        if (e.code != 'permission-denied') {
          rethrow;
        }
        debugPrint(
          'Skipping inaccessible service registration ${entry.key}: ${e.message ?? e.code}',
        );
      }
    }

    return null;
  }

  Future<void> _loadCurrentServiceType() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() {
        _serviceType = null;
        _isResolvingServiceType = false;
      });
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      String? serviceType = _readServiceTypeFromData(userDoc.data());

      if (serviceType == null) {
        final contractDoc = await FirebaseFirestore.instance
            .collection('contracts')
            .doc(user.uid)
            .get();
        serviceType = _readServiceTypeFromData(contractDoc.data());
      }

      serviceType ??= await _resolveServiceTypeFromRegistrations(user.uid);

      if (!mounted) return;
      setState(() {
        _serviceType = serviceType;
        _isResolvingServiceType = false;
      });
    } catch (e, stack) {
      debugPrint('Failed to resolve service type for product media rules: $e');
      debugPrint('$stack');
      if (!mounted) return;
      setState(() {
        _serviceType = null;
        _isResolvingServiceType = false;
      });
    }
  }

  Future<void> _loadAdminMediaSettings() async {
    final ownerUid = _effectiveOwnerUid;
    if (ownerUid == null) {
      return;
    }

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('public_shops')
          .doc(ownerUid)
          .get();
      final data = snapshot.data();
      if (!mounted || data == null) {
        return;
      }

      final maxImagesRaw = data['adminMaxImageCount'];
      final maxImages = maxImagesRaw is num
          ? maxImagesRaw.toInt()
          : int.tryParse(maxImagesRaw?.toString() ?? '');
      final canUploadVideo = data['adminCanUploadVideo'];

      setState(() {
        if (maxImages != null && maxImages > 0) {
          _adminMaxImageCount = maxImages.clamp(1, 30);
        }
        if (canUploadVideo is bool) {
          _adminCanUploadVideo = canUploadVideo;
        }
      });
    } catch (error) {
      debugPrint('Failed to load admin media settings: $error');
    }
  }

  Future<void> _pickImagesFromGallery() async {
    if (_isResolvingServiceType) return;

    final remainingSlots = _maxImageCount - _currentImageCount;
    if (remainingSlots <= 0) {
      _showSnack('ใส่รูปได้สูงสุด $_maxImageCount รูป');
      return;
    }

    final List<XFile> picks;
    if (_maxImageCount == 1) {
      final singlePick = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: _pickerImageQuality,
      );
      picks = singlePick == null ? <XFile>[] : <XFile>[singlePick];
    } else {
      picks = await _picker.pickMultiImage(imageQuality: _pickerImageQuality);
    }
    if (picks.isEmpty) return;

    final imagesToAdd = picks.take(remainingSlots).toList();
    final compressedToAdd = await _compressPickedImages(imagesToAdd);
    if (compressedToAdd.isEmpty) return;
    setState(() => _newImageFiles.addAll(compressedToAdd));
    unawaited(_analyzeProductWithAi(automatic: true));

    if (picks.length > remainingSlots) {
      _showSnack(
        'ระบบเพิ่มรูปได้เพียง $_maxImageCount รูป แสดงเฉพาะ ${imagesToAdd.length} รูปแรก',
      );
    }
  }

  Future<void> _captureImage() async {
    if (_isResolvingServiceType) return;

    if (_currentImageCount >= _maxImageCount) {
      _showSnack('ใส่รูปได้สูงสุด $_maxImageCount รูป');
      return;
    }

    final XFile? photo = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: _pickerImageQuality,
    );
    if (photo == null) return;
    final compressed = await _compressPickedImages(<XFile>[photo]);
    if (compressed.isEmpty) return;
    setState(() => _newImageFiles.add(compressed.first));
    unawaited(_analyzeProductWithAi(automatic: true));
  }

  Future<List<XFile>> _compressPickedImages(List<XFile> picks) async {
    final compressed = <XFile>[];
    for (final pick in picks) {
      try {
        final sourceFile = File(pick.path);
        final compressedFile = await _compressImageFile(
          sourceFile,
          forThumbnail: false,
          qualityOverride: _uploadImageQuality,
          minDimensionOverride: 1400,
          suffixOverride: 'pick',
        );
        if (compressedFile.path == sourceFile.path) {
          compressed.add(pick);
        } else {
          compressed.add(XFile(compressedFile.path, name: pick.name));
        }
      } catch (e) {
        debugPrint('Failed to pre-compress picked image: $e');
        compressed.add(pick);
      }
    }
    return compressed;
  }

  Future<void> _pickVideo() async {
    if (_isResolvingServiceType || !_canAddVideo) {
      _showSnack('เพิ่มวิดีโอได้เฉพาะประเภทร้านค้า');
      return;
    }

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

    final XFile? video = await _picker.pickVideo(
      source: source,
      maxDuration: _maxVideoDuration,
    );
    if (video == null) return;

    setState(() {
      _videoFile = video;
      _existingVideoUrl = null;
      _existingVideoThumbnailUrl = null;
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
    setState(() {
      _newImageFiles.removeAt(index);
    });
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

  Future<File> _compressImageFile(
    File sourceFile, {
    required bool forThumbnail,
    int? qualityOverride,
    int? minDimensionOverride,
    String? suffixOverride,
  }) async {
    final suffix = suffixOverride ?? (forThumbnail ? 'thumb' : 'full');
    final targetPath =
        '${Directory.systemTemp.path}/product_${DateTime.now().microsecondsSinceEpoch}_$suffix.webp';
    final minDimension = minDimensionOverride ?? (forThumbnail ? 600 : 1600);
    final quality =
        qualityOverride ??
        (forThumbnail ? _thumbnailImageQuality : _uploadImageQuality);

    try {
      final compressed = await FlutterImageCompress.compressAndGetFile(
        sourceFile.path,
        targetPath,
        format: CompressFormat.webp,
        minWidth: minDimension,
        minHeight: minDimension,
        quality: quality,
      );
      if (compressed != null) {
        final compressedFile = File(compressed.path);
        if (await compressedFile.exists()) {
          return compressedFile;
        }
      }
    } catch (e, stack) {
      debugPrint('Image compression failed ($suffix): $e');
      debugPrint('$stack');
    }

    try {
      final sourceBytes = await sourceFile.readAsBytes();
      final compressedBytes = await FlutterImageCompress.compressWithList(
        sourceBytes,
        format: CompressFormat.webp,
        minWidth: minDimension,
        minHeight: minDimension,
        quality: quality,
      );
      if (compressedBytes.isNotEmpty) {
        return _writeBytesToTempFile(compressedBytes, suffix: '$suffix.webp');
      }
    } catch (e, stack) {
      debugPrint('Image byte compression failed ($suffix): $e');
      debugPrint('$stack');
    }

    return sourceFile;
  }

  Future<File> _writeBytesToTempFile(
    Uint8List data, {
    required String suffix,
  }) async {
    final tempPath =
        '${Directory.systemTemp.path}/product_${DateTime.now().microsecondsSinceEpoch}_$suffix';
    final file = File(tempPath);
    await file.writeAsBytes(data, flush: true);
    return file;
  }

  Future<String> _uploadFileWithOptionalProgress(
    Reference ref,
    File file, {
    bool trackProgress = false,
    SettableMetadata? metadata,
  }) async {
    final uploadTask = ref.putFile(file, metadata);
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

  String _extensionFromPath(String path, {required String fallback}) {
    final fileName = path.split(Platform.pathSeparator).last;
    final dotIndex = fileName.lastIndexOf('.');
    if (dotIndex == -1 || dotIndex == fileName.length - 1) {
      return fallback;
    }
    return fileName.substring(dotIndex + 1).toLowerCase();
  }

  String _imageContentTypeFromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'webp':
        return 'image/webp';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }

  String _mimeTypeFromPathOrUrl(String pathOrUrl) {
    final normalized = pathOrUrl.toLowerCase();
    if (normalized.endsWith('.png')) return 'image/png';
    if (normalized.endsWith('.webp')) return 'image/webp';
    if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'image/jpeg';
  }

  Future<Uint8List> _downloadBytes(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      throw Exception('URL รูปภาพไม่ถูกต้อง');
    }
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('ดาวน์โหลดรูปไม่สำเร็จ (${response.statusCode})');
    }
    return response.bodyBytes;
  }

  String _createAiRequestId() {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    final millis = DateTime.now().millisecondsSinceEpoch;
    return '${uid}_${millis}_${DateTime.now().microsecondsSinceEpoch}'
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
  }

  String _formatAiWait(int seconds) {
    if (seconds <= 0) return 'อีกสักครู่';
    if (seconds < 60) return 'ประมาณ $seconds วินาที';
    final minutes = (seconds / 60).ceil();
    return 'ประมาณ $minutes นาที';
  }

  String _buildAiQueueText(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    final position = data['position'] is num
        ? (data['position'] as num).toInt()
        : null;
    final estimatedSeconds = data['estimatedWaitSeconds'] is num
        ? (data['estimatedWaitSeconds'] as num).toInt()
        : null;
    final message = (data['message'] ?? '').toString().trim();

    if (status == 'queued') {
      final positionText = position != null && position > 0
          ? 'คิวที่ $position'
          : 'กำลังรอคิว';
      final waitText = estimatedSeconds != null
          ? ' ${_formatAiWait(estimatedSeconds)}'
          : '';
      return '$positionText$waitText';
    }
    if (status == 'processing') {
      return 'ถึงคิวแล้ว กำลังประมวลผล AI...';
    }
    if (status == 'rejected') {
      return message.isNotEmpty
          ? message
          : 'คิว AI เยอะมาก กรุณาลองวิเคราะห์สินค้าใหม่ภายหลัง';
    }
    if (status == 'failed') {
      return message.isNotEmpty ? message : 'AI ประมวลผลไม่สำเร็จ';
    }
    if (status == 'completed') {
      return 'ประมวลผล AI สำเร็จ';
    }
    return 'กำลังส่งคำขอ AI...';
  }

  void _listenAiQueueStatus(String requestId) {
    _aiQueueSubscription?.cancel();
    if (mounted) {
      setState(() {
        _aiQueueStatusText = 'กำลังส่งคำขอ AI...';
        _aiQueueExternalRecommendation = false;
      });
    }

    _aiQueueSubscription = FirebaseFirestore.instance
        .collection('ai_processing_queue')
        .doc(requestId)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted || !snapshot.exists) return;
            final data = snapshot.data() ?? <String, dynamic>{};
            setState(() {
              _aiQueueStatusText = _buildAiQueueText(data);
              _aiQueueExternalRecommendation =
                  data['externalAiRecommended'] == true;
            });
          },
          onError: (_) {
            if (!mounted) return;
            setState(() {
              _aiQueueStatusText = 'กำลังเข้าคิว AI...';
              _aiQueueExternalRecommendation = false;
            });
          },
        );
  }

  void _clearAiQueueStatus() {
    _aiQueueSubscription?.cancel();
    _aiQueueSubscription = null;
    if (!mounted) return;
    setState(() {
      _aiQueueStatusText = null;
      _aiQueueExternalRecommendation = false;
    });
  }

  String _aiFunctionErrorMessage(FirebaseFunctionsException e) {
    final details = e.details;
    if (details is Map && details['externalAiRecommended'] == true) {
      final position = details['queuePosition'] is num
          ? (details['queuePosition'] as num).toInt()
          : null;
      final estimatedSeconds = details['estimatedWaitSeconds'] is num
          ? (details['estimatedWaitSeconds'] as num).toInt()
          : null;
      final queueText = position != null
          ? 'คิวที่ $position'
          : 'คิว AI เยอะมาก';
      final waitText = estimatedSeconds != null
          ? ' ${_formatAiWait(estimatedSeconds)}'
          : '';
      return '$queueText$waitText ระบบ AI ยังไม่พร้อม กรุณาลองใหม่ภายหลัง';
    }
    return e.message ?? 'AI วิเคราะห์สินค้าไม่สำเร็จ (${e.code})';
  }

  Future<_AiProductAnalysisResult> _requestProductAnalysis({
    required Uint8List imageBytes,
    required String mimeType,
  }) async {
    final requestId = _createAiRequestId();
    _listenAiQueueStatus(requestId);
    final callable = FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('analyzeProductWithAi');
    try {
      final response = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'imageBase64': base64Encode(imageBytes),
        'mimeType': mimeType,
        'productName': _nameController.text.trim(),
        'description': _productDescriptionController.text.trim(),
        'category': (_selectedProductCategory ?? '').trim(),
        'price': _priceController.text.trim(),
        'unit': _selectedUnit == 'อื่นๆ'
            ? _otherUnitController.text.trim()
            : (_selectedUnit ?? '').trim(),
      });
      final data = response.data;
      if (data is! Map) {
        throw Exception('รูปแบบข้อมูลจาก AI ไม่ถูกต้อง');
      }
      return _AiProductAnalysisResult(
        productName: (data['productName'] ?? '').toString().trim(),
        description: (data['description'] ?? '').toString().trim(),
        taxStatus: (data['taxStatus'] ?? '').toString().trim(),
        taxReason: (data['taxReason'] ?? '').toString().trim(),
        productCategory: (data['productCategory'] ?? '').toString().trim(),
        productType: (data['productType'] ?? '').toString().trim(),
        isLegalInThailand: data['isLegalInThailand'] is bool
            ? data['isLegalInThailand'] as bool
            : null,
        legalReason: (data['legalReason'] ?? '').toString().trim(),
        isFreshProduct: data['isFreshProduct'] is bool
            ? data['isFreshProduct'] as bool
            : null,
        isProcessed: data['isProcessed'] is bool
            ? data['isProcessed'] as bool
            : null,
        canShipNationwide: data['canShipNationwide'] is bool
            ? data['canShipNationwide'] as bool
            : null,
        nationwideShippingReason: (data['nationwideShippingReason'] ?? '')
            .toString()
            .trim(),
      );
    } finally {
      _clearAiQueueStatus();
    }
  }

  Future<({Uint8List bytes, String mimeType})?> _readProductImageForAi() async {
    if (_newImageFiles.isNotEmpty) {
      final file = _newImageFiles.first;
      return (
        bytes: await File(file.path).readAsBytes(),
        mimeType: _mimeTypeFromPathOrUrl(file.path),
      );
    }

    if (_existingImageUrls.isNotEmpty) {
      final sourceUrl = _existingThumbnailUrls.isNotEmpty
          ? _existingThumbnailUrls.first
          : _existingImageUrls.first;
      return (
        bytes: await _downloadBytes(sourceUrl),
        mimeType: _mimeTypeFromPathOrUrl(sourceUrl),
      );
    }

    if (_videoFile != null) {
      final thumbBytes = await VideoCompress.getByteThumbnail(
        _videoFile!.path,
        quality: 75,
        position: -1,
      );
      if (thumbBytes != null && thumbBytes.isNotEmpty) {
        return (bytes: thumbBytes, mimeType: 'image/jpeg');
      }
    }

    if ((_existingVideoThumbnailUrl ?? '').isNotEmpty) {
      return (
        bytes: await _downloadBytes(_existingVideoThumbnailUrl!),
        mimeType: _mimeTypeFromPathOrUrl(_existingVideoThumbnailUrl!),
      );
    }

    return null;
  }

  void _applyAiProductAnalysis(_AiProductAnalysisResult result) {
    final productName = result.productName?.trim();
    final description = result.description?.trim();
    final category = result.productCategory?.trim();
    final productType = result.productType?.trim();
    final taxStatus = result.taxStatus?.trim().toLowerCase();
    final taxReason = result.taxReason?.trim();
    final legalReason = result.legalReason?.trim();
    final nationwideReason = result.nationwideShippingReason?.trim();

    setState(() {
      if (productName != null &&
          productName.isNotEmpty &&
          _nameController.text.trim().isEmpty) {
        _nameController.text = productName;
      }

      if (description != null && description.isNotEmpty) {
        _productDescriptionController.text = description;
        _hasUsedAiDescriptionForProduct = true;
      }

      if (category != null &&
          category.isNotEmpty &&
          _productCategories.contains(category)) {
        _selectedProductCategory = category;
      } else if ((_selectedProductCategory ?? '').isEmpty) {
        _selectedProductCategory = taxStatus == 'exempt'
            ? 'ของสด'
            : 'สินค้าทั่วไป';
      }

      if (_isPharmacyCategory) {
        _isFreshProduct = false;
        _isProcessed = false;
        if (taxStatus == 'taxable' || taxStatus == 'exempt') {
          _pharmacyIsTaxable = taxStatus == 'taxable';
        }
      } else if (result.isFreshProduct != null || result.isProcessed != null) {
        _isFreshProduct = result.isFreshProduct ?? _isFreshProduct;
        _isProcessed = result.isProcessed ?? _isProcessed;
      } else if (taxStatus == 'exempt') {
        _isFreshProduct = true;
        _isProcessed = false;
      } else if (taxStatus == 'taxable') {
        _isFreshProduct = false;
        _isProcessed = true;
      }

      if (taxReason != null && taxReason.isNotEmpty) {
        _aiTaxAnalysisReason = taxReason;
      }

      if (productType != null && productType.isNotEmpty) {
        _aiProductType = productType;
      }

      if (result.isLegalInThailand != null) {
        _aiIsLegalInThailand = result.isLegalInThailand;
      }
      if (legalReason != null && legalReason.isNotEmpty) {
        _aiLegalAnalysisReason = legalReason;
      }

      if (taxStatus == 'taxable' ||
          taxStatus == 'exempt' ||
          (taxReason != null && taxReason.isNotEmpty)) {
        _hasAiTaxAnalysis = true;
      }

      if (result.canShipNationwide != null) {
        _aiCanShipNationwide = result.canShipNationwide;
      }
      if (nationwideReason != null && nationwideReason.isNotEmpty) {
        _aiNationwideShippingReason = nationwideReason;
      }
    });
  }

  Future<void> _analyzeProductWithAi({bool automatic = false}) async {
    if (_hasUsedAiProductAnalysisForProduct) {
      if (automatic) return;
      _showSnack(
        'สินค้านี้ใช้ AI วิเคราะห์สินค้าไปแล้ว ใช้ได้ 1 ครั้งต่อสินค้า',
      );
      return;
    }

    final productName = _nameController.text.trim();
    if (!automatic && productName.isEmpty) {
      _showSnack('กรุณากรอกชื่อสินค้าก่อนให้ AI วิเคราะห์');
      return;
    }

    final source = await _readProductImageForAi();
    if (source == null || source.bytes.isEmpty) {
      _showSnack('กรุณาเพิ่มรูปสินค้าก่อนให้ AI วิเคราะห์');
      return;
    }

    setState(() {
      _isAnalyzingProductWithAi = true;
      _hasUsedAiProductAnalysisForProduct = true;
    });
    await _persistProductAiUsageFlag('aiProductAnalysisRequested');

    try {
      final result = await _requestProductAnalysis(
        imageBytes: source.bytes,
        mimeType: source.mimeType,
      );
      if (!mounted) return;
      _applyAiProductAnalysis(result);
      if (!automatic) {
        _showSnack('AI วิเคราะห์สินค้าเรียบร้อยแล้ว');
      }
    } on FirebaseFunctionsException catch (e) {
      if (automatic && mounted) {
        setState(() => _hasUsedAiProductAnalysisForProduct = false);
      }
      if (!automatic) {
        _showSnack(_aiFunctionErrorMessage(e));
      }
    } catch (e) {
      if (automatic && mounted) {
        setState(() => _hasUsedAiProductAnalysisForProduct = false);
      }
      if (!automatic) {
        _showSnack('AI วิเคราะห์สินค้าไม่สำเร็จ: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAnalyzingProductWithAi = false);
      }
    }
  }

  Future<void> _persistProductAiUsageFlag(String field) async {
    final targetId = widget.productToEdit?.id;
    if (targetId == null || targetId.isEmpty) return;

    try {
      await FirebaseFirestore.instance
          .collection('products')
          .doc(targetId)
          .update(<String, dynamic>{
            field: true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      debugPrint('Failed to persist $field on product $targetId: $e');
    }
  }

  Future<_ProductImageUploadResult?> _uploadImageToFirebase(XFile image) async {
    try {
      final ownerUid = _effectiveOwnerUid;
      if (ownerUid == null) throw Exception("User not logged in");

      final sanitizedBase = image.name
          .split('.')
          .first
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');

      final sourceFile = File(image.path);
      final originalUploadFile = _isPrecompressedProductImage(sourceFile.path)
          ? sourceFile
          : await _compressImageFile(sourceFile, forThumbnail: false);
      final thumbnailBase = originalUploadFile;
      final compressedThumbnail = await _compressImageFile(
        thumbnailBase,
        forThumbnail: true,
      );
      final originalExtension = _extensionFromPath(
        originalUploadFile.path,
        fallback: 'jpg',
      );
      final thumbnailExtension = _extensionFromPath(
        compressedThumbnail.path,
        fallback: 'jpg',
      );
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_$sanitizedBase.$originalExtension';
      final thumbnailFileName =
          '${timestamp}_${sanitizedBase}_thumb.$thumbnailExtension';
      final originalMetadata = SettableMetadata(
        contentType: _imageContentTypeFromExtension(originalExtension),
      );
      final thumbnailMetadata = SettableMetadata(
        contentType: _imageContentTypeFromExtension(thumbnailExtension),
      );

      final baseRef = StorageHelper.instance
          .ref()
          .child('product_images')
          .child(ownerUid);

      final originalUrl = await _uploadFileWithOptionalProgress(
        baseRef.child(fileName),
        originalUploadFile,
        trackProgress: true,
        metadata: originalMetadata,
      );
      final thumbnailUrl = await _uploadFileWithOptionalProgress(
        baseRef.child('thumbnails').child(thumbnailFileName),
        compressedThumbnail,
        metadata: thumbnailMetadata,
      );

      final cachedOriginal = await MediaCacheService.instance.cacheUploadedFile(
        source: originalUploadFile,
        url: originalUrl,
        bucket: MediaCacheBucket.image,
      );
      final cachedThumbnail = await MediaCacheService.instance
          .cacheUploadedFile(
            source: compressedThumbnail,
            url: thumbnailUrl,
            bucket: MediaCacheBucket.thumbnail,
          );

      try {
        if (originalUploadFile.path != sourceFile.path &&
            await originalUploadFile.exists()) {
          await originalUploadFile.delete();
        }
        if (compressedThumbnail.path != sourceFile.path &&
            await compressedThumbnail.exists()) {
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดรูป: $e')),
        );
      }
      setState(() {
        _uploadProgress = null;
      });
      return null;
    }
  }

  bool _isPrecompressedProductImage(String path) {
    final normalized = path.toLowerCase();
    return normalized.endsWith('.webp') &&
        normalized.contains('product_') &&
        normalized.contains('_pick');
  }

  Future<_ProductVideoUploadResult?> _uploadVideoToFirebase(XFile video) async {
    File? compressedFile;
    File? rawThumbFile;
    File? compressedThumbFile;
    try {
      final ownerUid = _effectiveOwnerUid;
      if (ownerUid == null) throw Exception('User not logged in');

      final sanitizedBase = video.name
          .split('.')
          .first
          .replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final videoFileName = '${timestamp}_$sanitizedBase.mp4';
      final refBase = StorageHelper.instance
          .ref()
          .child('product_videos')
          .child(ownerUid);

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
          rawThumbFile = await _writeBytesToTempFile(
            thumbBytes,
            suffix: 'video_thumb.jpg',
          );
          compressedThumbFile = await _compressImageFile(
            rawThumbFile,
            forThumbnail: true,
          );
          final thumbExtension = _extensionFromPath(
            compressedThumbFile.path,
            fallback: 'jpg',
          );
          final thumbName =
              '${timestamp}_${sanitizedBase}_thumb.$thumbExtension';
          thumbnailUrl = await _uploadFileWithOptionalProgress(
            refBase.child('thumbnails').child(thumbName),
            compressedThumbFile,
            metadata: SettableMetadata(
              contentType: _imageContentTypeFromExtension(thumbExtension),
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการอัปโหลดวิดีโอ: $e')),
        );
      }
      setState(() {
        _uploadProgress = null;
      });
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

  Future<void> _generateAiDescription() async {
    if (_hasUsedAiDescriptionForProduct) {
      _showSnack('สินค้านี้ใช้ AI เขียนคำอธิบายไปแล้ว ใช้ได้ 1 ครั้งต่อสินค้า');
      return;
    }

    final productName = _nameController.text.trim();
    if (productName.isEmpty) {
      _showSnack('กรุณากรอกชื่อสินค้าก่อนให้ AI ช่วยเขียนคำอธิบาย');
      return;
    }

    final category = (_selectedProductCategory ?? '').trim();
    final price = _priceController.text.trim();
    final unit = _selectedUnit == 'อื่นๆ'
        ? _otherUnitController.text.trim()
        : (_selectedUnit ?? '').trim();
    final stock = _stockController.text.trim();

    setState(() {
      _isGeneratingAiDescription = true;
      _hasUsedAiDescriptionForProduct = true;
    });
    await _persistProductAiUsageFlag('aiDescriptionRequested');

    final requestId = _createAiRequestId();
    _listenAiQueueStatus(requestId);
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-southeast1',
      ).httpsCallable('askGeminiFlash');
      final response = await callable.call(<String, dynamic>{
        'requestId': requestId,
        'prompt':
            'ช่วยเขียนคำอธิบายสินค้าเป็นภาษาไทยประมาณ 2 บรรทัด อ่านเป็นธรรมชาติ น่าเชื่อถือ และเน้นการขายสำหรับร้านค้าออนไลน์',
        'productName': productName,
        'category': category,
        'price': price,
        'unit': unit,
        'stock': stock,
      });

      final data = response.data;
      final text = data is Map<String, dynamic>
          ? (data['text']?.toString().trim() ?? '')
          : '';

      if (text.isEmpty) {
        _showSnack('AI ไม่ได้ส่งข้อความกลับมา ลองอีกครั้ง');
        return;
      }

      _productDescriptionController.text = text;
      _showSnack('เติมคำอธิบายสินค้าจาก AI แล้ว');
    } on FirebaseFunctionsException catch (e) {
      _showSnack(_aiFunctionErrorMessage(e));
    } catch (e) {
      _showSnack('เรียก AI ไม่สำเร็จ: $e');
    } finally {
      _clearAiQueueStatus();
      if (mounted) {
        setState(() => _isGeneratingAiDescription = false);
      }
    }
  }

  Future<void> _saveProduct() async {
    // Basic validation
    if (_currentImageCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณาเพิ่มรูปสินค้าอย่างน้อย 1 รูป')),
      );
      return;
    }

    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกชื่อสินค้า')));
      return;
    }

    if (_weightController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกน้ำหนักสินค้า')));
      return;
    }
    final String weightValue = '${_weightController.text.trim()} $_weightUnit';
    final weightAmount = double.tryParse(_weightController.text.trim()) ?? 0;
    final parcelWeightGrams = _weightUnit == 'kg'
        ? (weightAmount * 1000).round()
        : weightAmount.round();
    final parcelLengthCm = double.tryParse(_parcelLengthController.text.trim());
    final parcelWidthCm = double.tryParse(_parcelWidthController.text.trim());
    final parcelHeightCm = double.tryParse(_parcelHeightController.text.trim());

    if (_priceController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกราคา')));
      return;
    }

    if ((_selectedProductCategory ?? '').trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกข้อมูลภาษีสินค้าและเลือกประเภทสินค้า'),
        ),
      );
      return;
    }

    if (_stockController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรุณากรอกสต็อกทั้งหมด')));
      return;
    }

    final preparationTimeMinutes = int.tryParse(
      _preparationTimeController.text.trim(),
    );
    if (preparationTimeMinutes == null ||
        preparationTimeMinutes <= 0 ||
        preparationTimeMinutes > 240) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('กรุณากรอกเวลาเตรียมสินค้า 1-240 นาที')),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้ กรุณาล็อกอินใหม่')),
      );
      return;
    }

    final ownerUid = _effectiveOwnerUid;
    if (ownerUid == null || ownerUid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลร้านที่ต้องการอัปโหลด')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await _backfillProductActiveFieldsForOwner(ownerUid);

      final List<String> imageUrls = List<String>.from(_existingImageUrls);
      final List<String> thumbnailUrls = List<String>.from(
        _existingThumbnailUrls,
      );
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
            _localMediaPaths[uploadedVideo.videoUrl] =
                uploadedVideo.localVideoPath!;
          }
          if (uploadedVideo.localThumbnailPath != null &&
              uploadedVideo.thumbnailUrl != null) {
            _localMediaPaths[uploadedVideo.thumbnailUrl!] =
                uploadedVideo.localThumbnailPath!;
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
      final colors = _colorsController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final sizes = _sizesController.text
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      final resolvedUnit = _selectedUnit == 'อื่นๆ'
          ? _otherUnitController.text.trim()
          : (_selectedUnit ?? '');
      final taxStatus = _computedTaxStatus;
      final canShipNationwide = _resolvedCanShipNationwide;
      final nationwideShippingReason = _resolvedNationwideShippingReason;
      final normalizedServiceType = _normalizeServiceType(_serviceType);
      final shopProfileData = await _resolveShopProfileData(
        ownerUid,
        normalizedServiceType,
        _isAdminDelegatedUpload ? null : user.email,
      );
      if (shopProfileData == null) {
        throw Exception(
          'ไม่พบข้อมูลร้านจากคอลเลกชันที่ลงทะเบียน กรุณาตรวจสอบข้อมูลการสมัครร้าน',
        );
      }
      final shopName =
          ShopProfileResolver.resolveName(shopProfileData) ??
          _resolveStringField(shopProfileData, const <String>[
            'shopName',
            'name',
            'displayName',
            'businessName',
            'storeName',
          ]);
      final String? shopImageUrl = ShopProfileResolver.resolveImageUrl(
        shopProfileData,
      );
      final String shopQrCode =
          ownerUid; // Wallet QR in this app is the shop UID.
      if (shopName == null || shopName.trim().isEmpty) {
        throw Exception(
          'ไม่พบชื่อร้านจากข้อมูลที่สมัคร กรุณาแก้ไขข้อมูลร้านก่อนบันทึกสินค้า',
        );
      }
      final shopLocation = _extractLocation(shopProfileData);
      final latitude = shopLocation['latitude'];
      final longitude = shopLocation['longitude'];
      if (latitude == null || longitude == null) {
        throw Exception(
          'ไม่พบพิกัดร้านจากข้อมูลที่สมัคร กรุณาแก้ไขพิกัดร้านก่อนบันทึกสินค้า',
        );
      }
      final resolvedProductServiceType =
          _readServiceTypeFromData(shopProfileData) ??
          normalizedServiceType ??
          '';

      await _upsertPublicShopProfile(
        ownerUid: ownerUid,
        shopName: shopName,
        shopImageUrl: shopImageUrl,
        latitude: latitude,
        longitude: longitude,
        serviceType: resolvedProductServiceType,
      );

      final productData = <String, dynamic>{
        'name': _nameController.text,
        'description': productDescription.isNotEmpty
            ? productDescription
            : toppingsText,
        'productCategory': _selectedProductCategory,
        'isFreshProduct': _isFreshProduct,
        'isProcessed': _isProcessed,
        'taxStatus': taxStatus,
        'taxStatusLabel': _taxStatusLabel,
        'price': double.tryParse(_priceController.text) ?? 0.0,
        'stock': int.tryParse(_stockController.text) ?? 0,
        'preparationTimeMinutes': preparationTimeMinutes,
        'preparingDuration': preparationTimeMinutes * 60 * 1000,
        'imageUrls': imageUrls,
        'thumbnailUrls': thumbnailUrls,
        'colors': colors,
        'sizes': sizes,
        'weight': weightValue,
        if (parcelWeightGrams > 0) 'parcelWeightGrams': parcelWeightGrams,
        if (parcelLengthCm != null) 'parcelLengthCm': parcelLengthCm,
        if (parcelWidthCm != null) 'parcelWidthCm': parcelWidthCm,
        if (parcelHeightCm != null) 'parcelHeightCm': parcelHeightCm,
        'unit': resolvedUnit,
        'shopName': shopName,
        if (shopImageUrl != null && shopImageUrl.trim().isNotEmpty)
          'shopImageUrl': shopImageUrl,
        'shopQrCode': shopQrCode,
        'location': <String, double?>{
          'latitude': latitude,
          'longitude': longitude,
        },
        'serviceType': resolvedProductServiceType,
        'ownerUid': ownerUid,
        if (_isAdminDelegatedUpload) ...<String, dynamic>{
          'uploadedByAdmin': true,
          'adminUploadedBy': user.uid,
        },
        'aiDescriptionRequested': _hasUsedAiDescriptionForProduct,
        'aiProductAnalysisRequested': _hasUsedAiProductAnalysisForProduct,
        'aiIsLegalInThailand': _aiIsLegalInThailand,
        if ((_aiLegalAnalysisReason ?? '').trim().isNotEmpty)
          'aiLegalAnalysisReason': _aiLegalAnalysisReason!.trim(),
        if ((_aiProductType ?? '').trim().isNotEmpty)
          'aiProductType': _aiProductType!.trim(),
        if ((_aiTaxAnalysisReason ?? '').trim().isNotEmpty)
          'taxAiReason': _aiTaxAnalysisReason!.trim(),
        'canShipNationwide': canShipNationwide,
        'nationwideShippingReason': nationwideShippingReason,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (toppingsText.isNotEmpty) {
        productData['toppings'] = toppingsText;
      } else if (widget.productToEdit != null) {
        productData['toppings'] = FieldValue.delete();
      }

      if (videoUrl != null) {
        productData['videoUrl'] = videoUrl;
      } else if (widget.productToEdit != null &&
          widget.productToEdit!.videoUrl != null) {
        productData['videoUrl'] = FieldValue.delete();
      }

      if (videoThumbnailUrl != null) {
        productData['videoThumbnailUrl'] = videoThumbnailUrl;
      } else if (widget.productToEdit != null &&
          widget.productToEdit!.videoThumbnailUrl != null) {
        productData['videoThumbnailUrl'] = FieldValue.delete();
      }

      final specificationsData = <String, dynamic>{
        'description': productDescription,
        'toppings': toppingsText,
        'productCategory': _selectedProductCategory,
        'isFreshProduct': _isFreshProduct,
        'isProcessed': _isProcessed,
        'taxStatus': taxStatus,
        'taxStatusLabel': _taxStatusLabel,
        'taxReason': _taxReason,
        'aiIsLegalInThailand': _aiIsLegalInThailand,
        if ((_aiLegalAnalysisReason ?? '').trim().isNotEmpty)
          'aiLegalAnalysisReason': _aiLegalAnalysisReason!.trim(),
        if ((_aiProductType ?? '').trim().isNotEmpty)
          'aiProductType': _aiProductType!.trim(),
        'preparationTimeMinutes': preparationTimeMinutes,
        'preparingDuration': preparationTimeMinutes * 60 * 1000,
        'canShipNationwide': canShipNationwide,
        'nationwideShippingReason': nationwideShippingReason,
        'colors': colors,
        'sizes': sizes,
        'unit': resolvedUnit,
        'weight': weightValue,
        if (parcelWeightGrams > 0) 'parcelWeightGrams': parcelWeightGrams,
        if (parcelLengthCm != null) 'parcelLengthCm': parcelLengthCm,
        if (parcelWidthCm != null) 'parcelWidthCm': parcelWidthCm,
        if (parcelHeightCm != null) 'parcelHeightCm': parcelHeightCm,
        'headings': <String, String>{
          'description': 'คำอธิบายสินค้า',
          'toppings': 'ท็อปปิ้ง',
          'productCategory': 'ประเภทสินค้า',
          'isFreshProduct': 'เป็นของสด',
          'isProcessed': 'ผ่านการแปรรูปแล้ว',
          'taxStatus': 'สถานะภาษี',
          'aiIsLegalInThailand': 'ถูกกฎหมายในประเทศไทย',
          'aiLegalAnalysisReason': 'เหตุผลด้านกฎหมายจาก AI',
          'aiProductType': 'ประเภทสินค้าที่ AI วิเคราะห์',
          'preparationTimeMinutes': 'เวลาเตรียมสินค้า (นาที)',
          'preparingDuration': 'เวลาเตรียมสินค้า (มิลลิวินาที)',
          'canShipNationwide': 'ส่งได้ทั่วไทย',
          'nationwideShippingReason': 'เหตุผลการส่งทั่วไทย',
          'colors': 'สี',
          'sizes': 'ขนาด',
          'unit': 'หน่วย',
          'weight': 'น้ำหนัก',
          'parcelWeightGrams': 'น้ำหนักพัสดุ (กรัม)',
          'parcelLengthCm': 'ความยาวพัสดุ (ซม.)',
          'parcelWidthCm': 'ความกว้างพัสดุ (ซม.)',
          'parcelHeightCm': 'ความสูงพัสดุ (ซม.)',
        },
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (widget.productToEdit == null) {
        specificationsData['createdAt'] = FieldValue.serverTimestamp();
      }

      if (_aiIsLegalInThailand == false) {
        final reviewData = Map<String, dynamic>.from(productData)
          ..['adminReviewStatus'] = 'pending'
          ..['submittedAt'] = FieldValue.serverTimestamp()
          ..['submittedByUid'] = user.uid
          ..['reviewType'] = widget.productToEdit == null ? 'create' : 'update'
          ..['specificationsPayload'] = specificationsData;
        reviewData.remove('isActive');
        reviewData.remove('activeAt');
        if (widget.productToEdit?.id != null &&
            widget.productToEdit!.id!.trim().isNotEmpty) {
          reviewData['targetProductId'] = widget.productToEdit!.id!.trim();
        }

        await FirebaseFirestore.instance
            .collection('product_admin_reviews')
            .add(reviewData);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'AI ประเมินว่าสินค้านี้อาจผิดกฎหมาย — ส่งให้แอดมินตรวจสอบแล้ว จะขึ้นขายหลังได้รับการอนุมัติ',
              ),
            ),
          );
          Navigator.pop(context, true);
        }
        return;
      }

      final productsRef = FirebaseFirestore.instance.collection('products');
      DocumentReference<Map<String, dynamic>> docRef;
      if (widget.productToEdit == null) {
        productData['createdAt'] = FieldValue.serverTimestamp();
        productData['isActive'] = true;
        productData['activeAt'] = FieldValue.serverTimestamp();
        docRef = await productsRef.add(productData);
      } else {
        final targetId = widget.productToEdit!.id;
        if (targetId == null || targetId.isEmpty) {
          throw Exception('ไม่สามารถระบุรหัสสินค้าที่ต้องการแก้ไขได้');
        }
        docRef = productsRef.doc(targetId);
        await docRef.update(productData);
      }

      specificationsData['productId'] = docRef.id;
      specificationsData['ownerUid'] = ownerUid;

      await docRef
          .collection('specifications')
          .doc('main')
          .set(specificationsData, SetOptions(merge: true));

      final latestSnapshot = await docRef.get();
      final latestData = latestSnapshot.data();
      if (latestData != null) {
        await ProductCacheService.instance.saveProducts(ownerUid, [
          CachedProduct(id: docRef.id, data: latestData),
        ]);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกสินค้าเรียบร้อยแล้ว')),
        );
        Navigator.pop(context, true);
      }
    } on FirebaseException catch (e) {
      final message = switch (e.code) {
        'permission-denied' =>
          'ไม่มีสิทธิ์อ่านข้อมูลร้านหรือบันทึกสินค้า กรุณาตรวจสอบสิทธิ์ Firestore แล้วลองใหม่',
        'unavailable' || 'network-request-failed' =>
          'ไม่สามารถเชื่อมต่อ Firebase ได้ชั่วคราว กรุณาตรวจสอบอินเทอร์เน็ตแล้วลองใหม่',
        _ => 'เกิดข้อผิดพลาดในการบันทึก: $e',
      };
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('เกิดข้อผิดพลาดในการบันทึก: $e')),
        );
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

  Future<void> _upsertPublicShopProfile({
    required String ownerUid,
    required String shopName,
    String? shopImageUrl,
    required double latitude,
    required double longitude,
    required String serviceType,
  }) async {
    final publicData = <String, dynamic>{
      'ownerUid': ownerUid,
      'ownerId': ownerUid,
      'shopName': shopName,
      'name': shopName,
      'serviceType': serviceType,
      'location': <String, double>{
        'latitude': latitude,
        'longitude': longitude,
      },
      'shopLocation': <String, double>{
        'latitude': latitude,
        'longitude': longitude,
      },
      'shopLatitude': latitude,
      'shopLongitude': longitude,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final normalizedShopImageUrl = shopImageUrl?.trim();
    if (normalizedShopImageUrl != null && normalizedShopImageUrl.isNotEmpty) {
      publicData['shopImageUrl'] = normalizedShopImageUrl;
    }

    await FirebaseFirestore.instance
        .collection('public_shops')
        .doc(ownerUid)
        .set(publicData, SetOptions(merge: true));
  }

  Future<void> _backfillProductActiveFieldsForOwner(String ownerUid) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('products')
          .where('ownerUid', isEqualTo: ownerUid)
          .get();

      if (snapshot.docs.isEmpty) return;

      WriteBatch batch = FirebaseFirestore.instance.batch();
      int operationCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final Map<String, dynamic> updates = <String, dynamic>{};
        final dynamic isActiveRaw = data['isActive'];
        final bool isActive = isActiveRaw is bool ? isActiveRaw : true;

        if (isActiveRaw is! bool) {
          updates['isActive'] = isActive;
        }

        if (isActive) {
          if (data['activeAt'] == null) {
            updates['activeAt'] = FieldValue.serverTimestamp();
          }
          if (data.containsKey('inactiveAt') && data['inactiveAt'] != null) {
            updates['inactiveAt'] = FieldValue.delete();
          }
        } else if (data['inactiveAt'] == null) {
          updates['inactiveAt'] = FieldValue.serverTimestamp();
        }

        if (updates.isEmpty) continue;

        updates['updatedAt'] = FieldValue.serverTimestamp();
        batch.update(doc.reference, updates);
        operationCount++;

        if (operationCount >= 450) {
          await batch.commit();
          batch = FirebaseFirestore.instance.batch();
          operationCount = 0;
        }
      }

      if (operationCount > 0) {
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Failed to backfill active fields in products: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.productToEdit == null ? 'เพิ่มสินค้าใหม่' : 'แก้ไขสินค้า',
        ),
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
            if (_isAdminDelegatedUpload) ...<Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF3E0),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFCC80)),
                ),
                child: Text(
                  'อัปโหลดให้ร้าน: ${widget.adminUploadContext!.shopName}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFE65100),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'รูปภาพและวิดีโอ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
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

            const Text(
              'รายละเอียดสินค้า',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    label: 'ชื่อสินค้า',
                    controller: _nameController,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(child: _buildWeightField()),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildGuidedFieldOverlay(
                        showGuidance: _showPriceGuidance,
                        guidanceMessage:
                            'ระบบจะหักค่า GP 18% จากราคาที่ระบุ แนะนำให้บวกราคาเพิ่มจากราคาขายหน้าร้านปกติ ตามราคาที่เหมาะสม',
                        footer: Text(
                          _netPriceAfterGp == null
                              ? 'ราคาที่จะได้รับ: ระบุราคาก่อน'
                              : 'ราคาที่จะได้รับ: ${_formatPriceDisplay(_netPriceAfterGp!)} บาท',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: AppColors.accentDark,
                          ),
                        ),
                        field: _buildTextField(
                          label: 'ราคา',
                          controller: _priceController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          focusNode: _priceFocusNode,
                          onTap: () {
                            setState(() {
                              _showPreparationTimeGuidance = false;
                              _priceGuidanceDismissedWhileFocused = false;
                              _showPriceGuidance = true;
                            });
                          },
                          onChanged: (_) {
                            if (!mounted) return;
                            if (_showPriceGuidance) {
                              setState(() {});
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildGuidedFieldOverlay(
                        showGuidance: _showPreparationTimeGuidance,
                        guidanceMessage:
                            'เวลาที่ระบุจะแสดงต่อลูกค้า และมีผลต่อการสั่งสินค้า รวมถึงค่าปรับหากเตรียมออเดอร์ช้าเกินเวลาที่ตั้งไว้ โดยคิดช้านาทีละ 1 บาทและหักจากยอดเครดิต กรุณาระบุเวลาเตรียมที่เหมาะสม',
                        field: _buildTextField(
                          label: 'เวลาเตรียมสินค้า/ออเดอร์ (นาที)',
                          controller: _preparationTimeController,
                          keyboardType: TextInputType.number,
                          hint: 'เช่น 10',
                          onTap: () => setState(() {
                            _showPriceGuidance = false;
                            _priceGuidanceDismissedWhileFocused = false;
                            _showPreparationTimeGuidance = true;
                          }),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildTextField(
                    label: 'สต็อกทั้งหมด',
                    controller: _stockController,
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildProductAnalysisSection(),
            const SizedBox(height: 24),
            _buildNationwideShippingSection(),
            if (_resolvedCanShipNationwide) ...[
              const SizedBox(height: 12),
              _buildParcelDimensionFields(),
            ],
            const SizedBox(height: 24),
            _buildTaxSection(),
            const SizedBox(height: 32),

            OutlinedButton.icon(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (context) => _buildSpecificationSheet(),
                );
              },
              icon: const Icon(Icons.tune),
              label: const Text(
                'ข้อมูลจำเพาะสินค้า (ท็อปปิ้ง, สี, ขนาด, หน่วย)',
                style: TextStyle(fontSize: 14),
              ),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                side: BorderSide(color: AppColors.accent, width: 1.5),
                foregroundColor: AppColors.accent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: (_isSaving || _isGeneratingAiDescription)
                  ? null
                  : _saveProduct, // Disable button while saving
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text(
                      'บันทึกสินค้า',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSection() {
    final bool hasImages = _currentImageCount > 0;
    final bool hasVideo =
        _videoFile != null || (_existingVideoUrl?.isNotEmpty ?? false);
    final bool showVideoControls = _canAddVideo || hasVideo;

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

    final bool showCombinedRow = !hasImages && !hasVideo && showVideoControls;

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
                onPressed: _isResolvingServiceType ? null : _captureImage,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('ถ่ายรูป'),
              ),
              ElevatedButton.icon(
                onPressed: _isResolvingServiceType
                    ? null
                    : _pickImagesFromGallery,
                icon: const Icon(Icons.photo_library_outlined),
                label: Text('เลือกรูป (${_currentImageCount}/$_maxImageCount)'),
              ),
              if (_canAddVideo)
                ElevatedButton.icon(
                  onPressed: _isResolvingServiceType ? null : _pickVideo,
                  icon: const Icon(Icons.videocam_outlined),
                  label: const Text('เพิ่มวิดีโอ'),
                ),
            ],
          ),
          if (_isResolvingServiceType) ...[
            const SizedBox(height: 8),
            const Text(
              'กำลังตรวจสอบประเภทร้านเพื่อกำหนดสิทธิ์การเพิ่มรูปและวิดีโอ',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ] else if (!_isShopServiceType) ...[
            const SizedBox(height: 8),
            Text(
              'ประเภทร้าน ${_serviceType ?? 'ทั่วไป'} เพิ่มรูปสินค้าได้ 1 รูป และไม่รองรับวิดีโอ',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
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
            if (showVideoControls) ...[
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
        ],
      ),
    );
  }

  Widget _buildImagePreviewContent() {
    final List<Widget> tiles = <Widget>[];

    for (int i = 0; i < _existingImageUrls.length; i++) {
      final imageUrl = _existingImageUrls[i];
      final displayUrl = i < _existingThumbnailUrls.length
          ? _existingThumbnailUrls[i]
          : imageUrl;
      tiles.add(
        _buildImageTile(
          image: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: _buildCachedImage(displayUrl),
          ),
          onRemove: () => _removeExistingImageAt(i),
        ),
      );
    }

    for (int i = 0; i < _newImageFiles.length; i++) {
      final file = _newImageFiles[i];
      tiles.add(
        _buildImageTile(
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
        ),
      );
    }

    return Wrap(spacing: 12, runSpacing: 12, children: tiles);
  }

  Widget _buildPlaceholderSquare({
    required IconData icon,
    required String label,
  }) {
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
    if (url.isEmpty ||
        _localMediaPaths.containsKey(url) ||
        _cacheLookupInProgress.contains(url)) {
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

  Widget _buildImageTile({
    required Widget image,
    required VoidCallback onRemove,
  }) {
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
    final String? videoUrl = _videoFile != null ? null : _existingVideoUrl;
    final bool hasVideo = _videoFile != null || (videoUrl?.isNotEmpty ?? false);
    final String? cachedVideoPath = videoUrl != null
        ? _localMediaPaths[videoUrl]
        : null;
    final String? thumbnailUrl = _videoFile != null
        ? null
        : _existingVideoThumbnailUrl;
    final String? cachedThumbnailPath = thumbnailUrl != null
        ? _localMediaPaths[thumbnailUrl]
        : null;
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 1,
      child: Column(
        children: [
          ListTile(
            leading: const Icon(
              Icons.play_circle_fill,
              color: AppColors.accent,
              size: 36,
            ),
            title: Text(
              _videoFile != null ? _videoFile!.name : 'วิดีโอที่อัปโหลดแล้ว',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              'ความยาวไม่เกิน ${_maxVideoDuration.inMinutes} นาที',
            ),
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
                    ? ProductVideoPlayer(
                        videoUrl: _videoFile!.path,
                      ) // ส่วนนี้ถูกต้องแล้ว
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
    FocusNode? focusNode,
    VoidCallback? onTap,
    ValueChanged<String>? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: keyboardType,
          maxLines: maxLines,
          onTap: () {
            _hideFieldGuidance();
            onTap?.call();
          },
          onChanged: onChanged,
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
              borderSide: const BorderSide(
                color: AppColors.accentDark,
                width: 2,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'น้ำหนัก',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'ใส่น้ำหนัก',
                    border: InputBorder.none,
                    isCollapsed: true,
                  ),
                ),
              ),
              Container(width: 1, height: 28, color: Colors.grey.shade300),
              const SizedBox(width: 12),
              DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _weightUnit,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: Colors.black54,
                  ),
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

  Widget _buildParcelDimensionFields() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ข้อมูลพัสดุสำหรับส่งทั่วประเทศ',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'เตรียมไว้สำหรับเชื่อมต่อ ShipPop ภายหลัง ระบุขนาดโดยประมาณของพัสดุหลังแพ็ก',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  label: 'ยาว (ซม.)',
                  controller: _parcelLengthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  label: 'กว้าง (ซม.)',
                  controller: _parcelWidthController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTextField(
                  label: 'สูง (ซม.)',
                  controller: _parcelHeightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTaxSummaryCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _taxStatusColor.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _taxStatusColor.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _taxStatusLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _taxStatusColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _taxReason,
            style: const TextStyle(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  Widget _buildNationwideShippingSummaryCard() {
    final canShip = _aiCanShipNationwide == true;
    final color = canShip ? const Color(0xFF2E7D32) : const Color(0xFFC62828);
    final reason = (_aiNationwideShippingReason ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withAlpha(18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canShip
                ? 'สินค้านี้ส่งได้ทั่วไทย'
                : 'สินค้านี้ไม่เหมาะกับการส่งทั่วไทย',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              reason,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductAnalysisSection() {
    final legalKnown = _aiIsLegalInThailand != null;
    final legalColor = _aiIsLegalInThailand == false
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);
    final legalReason = (_aiLegalAnalysisReason ?? '').trim();
    final productType = (_aiProductType ?? '').trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'วิเคราะห์สินค้า',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed:
                  (_isAnalyzingProductWithAi ||
                      _hasUsedAiProductAnalysisForProduct)
                  ? null
                  : _analyzeProductWithAi,
              icon: _isAnalyzingProductWithAi
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _isAnalyzingProductWithAi
                    ? 'AI กำลังวิเคราะห์สินค้า...'
                    : (_hasUsedAiProductAnalysisForProduct
                          ? 'ใช้ AI วิเคราะห์สินค้าแล้ว'
                          : 'วิเคราะห์สินค้า'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.accent,
                side: BorderSide(color: AppColors.accent.withOpacity(0.6)),
              ),
            ),
          ),
          if (_isAnalyzingProductWithAi &&
              (_aiQueueStatusText ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _aiQueueStatusText!,
              style: TextStyle(
                fontSize: 12,
                color: _aiQueueExternalRecommendation
                    ? const Color(0xFFC62828)
                    : Colors.black54,
              ),
            ),
          ],
          if (legalKnown || productType.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (legalKnown)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: legalColor.withAlpha(18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: legalColor.withAlpha(90)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _aiIsLegalInThailand == true
                          ? 'AI ประเมินว่าเป็นสินค้าที่ขายได้ตามกฎหมายไทย'
                          : 'AI ประเมินว่าอาจเป็นสินค้าที่ห้ามหรือจำกัดการขายในไทย',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: legalColor,
                      ),
                    ),
                    if (legalReason.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        legalReason,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            if (productType.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.accentLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.accent.withOpacity(0.35)),
                ),
                child: Text(
                  'ประเภทสินค้า: $productType',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildManualNationwideShippingCheckbox() {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      controlAffinity: ListTileControlAffinity.leading,
      title: const Text('เหมาะกับการส่งทั่วประเทศ'),
      subtitle: const Text('ติ๊กถูกถ้าสินค้านี้แพ็กและจัดส่งไปต่างจังหวัดได้'),
      value: _manualCanShipNationwide,
      onChanged: (value) {
        setState(() {
          _manualCanShipNationwide = value ?? false;
        });
      },
      activeColor: AppColors.accent,
    );
  }

  Widget _buildNationwideShippingSection() {
    if (_aiCanShipNationwide != null) {
      return _buildNationwideShippingSummaryCard();
    }
    return _buildManualNationwideShippingCheckbox();
  }

  Widget _buildTaxSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ภาษีสินค้า',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_hasAiTaxAnalysis) ...[
            _buildTaxSummaryCard(),
          ] else ...[
            const Text(
              'ประเภทสินค้า',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedProductCategory,
              items: _productCategories.map((category) {
                return DropdownMenuItem<String>(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedProductCategory = value;
                  if (_isPharmacyCategory) {
                    _isFreshProduct = false;
                    _isProcessed = false;
                  }
                });
              },
              decoration: InputDecoration(
                hintText: 'เลือกประเภทสินค้า',
                helperText: 'จำเป็นต้องเลือกก่อนบันทึกสินค้า',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.accentDark,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
              ),
            ),
            if (_isPharmacyCategory) ...[
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('เสียภาษี'),
                subtitle: const Text(
                  'ปิดสวิตช์หากยาหรือเวชภัณฑ์รายการนี้เป็นสินค้ายกเว้นภาษี',
                ),
                value: _pharmacyIsTaxable,
                onChanged: (value) {
                  setState(() {
                    _pharmacyIsTaxable = value;
                    _isFreshProduct = false;
                    _isProcessed = false;
                  });
                },
                activeColor: AppColors.accent,
              ),
            ] else ...[
              const SizedBox(height: 12),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('เป็นของสด'),
                subtitle: const Text('เช่น ผัก ผลไม้ เนื้อสด อาหารทะเลสด'),
                value: _isFreshProduct,
                onChanged: (value) {
                  setState(() {
                    _isFreshProduct = value;
                  });
                },
                activeColor: AppColors.accent,
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('ผ่านการแปรรูปแล้ว'),
                subtitle: const Text(
                  'เช่น หั่น หมัก ปรุง บรรจุพร้อมขาย หรือแปรรูปจากสภาพสด',
                ),
                value: _isProcessed,
                onChanged: (value) {
                  setState(() {
                    _isProcessed = value;
                  });
                },
                activeColor: AppColors.accent,
              ),
            ],
            const SizedBox(height: 12),
            _buildTaxSummaryCard(),
          ],
        ],
      ),
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
                const Text(
                  'ข้อมูลจำเพาะสินค้า',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
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
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed:
                    (_isGeneratingAiDescription ||
                        _hasUsedAiDescriptionForProduct)
                    ? null
                    : _generateAiDescription,
                icon: _isGeneratingAiDescription
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: Text(
                  _isGeneratingAiDescription
                      ? 'AI กำลังเขียนคำอธิบาย...'
                      : (_hasUsedAiDescriptionForProduct
                            ? 'ใช้ AI เขียนคำอธิบายแล้ว'
                            : 'ให้ AI ช่วยเขียนคำอธิบายสินค้า'),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.accent,
                  side: BorderSide(color: AppColors.accent.withOpacity(0.6)),
                ),
              ),
            ),
            if (_isGeneratingAiDescription &&
                (_aiQueueStatusText ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                _aiQueueStatusText!,
                style: TextStyle(
                  fontSize: 12,
                  color: _aiQueueExternalRecommendation
                      ? const Color(0xFFC62828)
                      : Colors.black54,
                ),
              ),
            ],
            const SizedBox(height: 16),
            _buildTextField(
              label: 'ท็อปปิ้ง',
              controller: _descriptionController,
              focusNode: _toppingsFocusNode,
              hint: 'เช่น (ระดับความเผ็ด) +เผ็ดน้อย+ เผ็ด+ กลาง+เผ็ดมาก',
              onTap: () => setState(() {
                _showPriceGuidance = false;
                _showPreparationTimeGuidance = false;
                _showToppingsGuidance = true;
              }),
            ),
            if (_showToppingsGuidance) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'วิธีกรอกท็อปปิ้ง',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF9A3412),
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '1. ถ้าใส่วงเล็บ () จะใช้เป็นหัวข้อ',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '2. ถ้าใส่เครื่องหมาย + นำหน้า และลงท้ายด้วย + จะใช้เป็นตัวเลือก',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '3. ตัวอย่าง: (ระดับความเผ็ด) +เผ็ดน้อย+ เผ็ด+ กลาง+เผ็ดมาก (เพิ่ม)+หอย 20+ เพิ่มกุ้ง 20+เพิ่มแคบหมู 10+',
                      style: TextStyle(fontSize: 12, color: Color(0xFF7C2D12)),
                    ),
                  ],
                ),
              ),
            ],
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
            const Text(
              'หน่วย',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedUnit,
              items: _units.map((String unit) {
                return DropdownMenuItem<String>(value: unit, child: Text(unit));
              }).toList(),
              onChanged: (newValue) {
                setState(() {
                  _selectedUnit = newValue;
                });
              },
              decoration: InputDecoration(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: BorderSide(color: Colors.grey.shade400),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(40),
                  borderSide: const BorderSide(
                    color: AppColors.accentDark,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 14,
                ),
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
              child: const Text(
                'บันทึก',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
