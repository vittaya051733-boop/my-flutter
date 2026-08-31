import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'models/product_variant.dart';
import 'utils/app_colors.dart';
import 'utils/product_variant_color.dart';
import 'widgets/cached_app_image.dart';

class ProductVariantSetupScreen extends StatefulWidget {
  const ProductVariantSetupScreen({
    super.key,
    required this.productName,
    required this.existingImageUrls,
    required this.existingThumbnailUrls,
    required this.localImageFiles,
    required this.initialDrafts,
    this.isEditMode = false,
  });

  final String productName;
  final List<String> existingImageUrls;
  final List<String> existingThumbnailUrls;
  final List<XFile> localImageFiles;
  final List<ProductVariantDraft> initialDrafts;
  final bool isEditMode;

  @override
  State<ProductVariantSetupScreen> createState() =>
      _ProductVariantSetupScreenState();
}

class _ProductVariantSetupScreenState extends State<ProductVariantSetupScreen> {
  late List<ProductVariantDraft> _drafts;

  int get _imageCount =>
      widget.existingImageUrls.length + widget.localImageFiles.length;

  @override
  void initState() {
    super.initState();
    _drafts = widget.initialDrafts
        .map(
          (draft) => ProductVariantDraft(
            id: draft.id,
            imageIndex: draft.imageIndex,
            size: draft.size,
            color: draft.color,
            priceText: draft.priceText,
            stockText: draft.stockText,
          ),
        )
        .toList(growable: true);
    if (_drafts.isEmpty && _imageCount > 0) {
      _drafts.add(ProductVariantDraft(imageIndex: 0));
    }
  }

  void _addDraftForImage(int imageIndex) {
    setState(() {
      _drafts.add(ProductVariantDraft(imageIndex: imageIndex));
    });
  }

  void _removeDraft(String id) {
    setState(() {
      _drafts.removeWhere((draft) => draft.id == id);
    });
  }

  void _finish() {
    final error = ProductVariantSupport.validateDrafts(_drafts);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error)),
      );
      return;
    }
    Navigator.of(context).pop(_drafts);
  }

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<ProductVariantDraft>>{};
    for (final draft in _drafts) {
      grouped.putIfAbsent(draft.imageIndex, () => <ProductVariantDraft>[]).add(
            draft,
          );
    }

    final priceValues = _drafts
        .map((d) => double.tryParse(d.priceText.trim()))
        .whereType<double>()
        .where((v) => v > 0)
        .toList(growable: false);
    final totalStock = _drafts
        .map((d) => int.tryParse(d.stockText.trim()) ?? 0)
        .fold<int>(0, (sum, v) => sum + v);

    return Scaffold(
      appBar: AppBar(
        title: const Text('กำหนดตัวเลือกสินค้า'),
        backgroundColor: AppColors.accent,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.white,
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                Text(
                  widget.productName.trim().isEmpty
                      ? 'สินค้าใหม่'
                      : widget.productName.trim(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'กำหนดขนาด สี ราคา และสต็อกต่อรูป — ลูกค้าจะเลือกตัวเลือกนี้ใน van2',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
                const SizedBox(height: 20),
                for (var imageIndex = 0; imageIndex < _imageCount; imageIndex++)
                  _buildImageGroup(
                    imageIndex: imageIndex,
                    drafts: grouped[imageIndex] ?? const <ProductVariantDraft>[],
                  ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (priceValues.isNotEmpty)
                  Text(
                    'ช่วงราคา: ฿${priceValues.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)}'
                    '${priceValues.length > 1 ? ' – ฿${priceValues.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)}' : ''}'
                    ' · สต็อกรวม: $totalStock · ${_drafts.length} ตัวเลือก',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.accentDark,
                    ),
                  ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('ย้อนกลับ'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _finish,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 48),
                        ),
                        child: Text(
                          widget.isEditMode ? 'บันทึกตัวเลือก' : 'บันทึกสินค้า',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImageGroup({
    required int imageIndex,
    required List<ProductVariantDraft> drafts,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _buildImagePreview(imageIndex),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'รูปที่ ${imageIndex + 1} · ${drafts.length} ตัวเลือก',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (drafts.isEmpty)
            Text(
              'ยังไม่มีตัวเลือกสำหรับรูปนี้',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          for (final draft in drafts) _buildDraftRow(draft),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _addDraftForImage(imageIndex),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('เพิ่มตัวเลือกของรูปนี้'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.accent,
              side: BorderSide(color: AppColors.accent.withValues(alpha: 0.6)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftRow(ProductVariantDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _miniField(
                  label: 'ขนาด',
                  hint: 'S, M, L',
                  value: draft.size,
                  onChanged: (v) => draft.size = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildColorPickerField(draft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _miniField(
                  label: 'ราคา (฿)',
                  hint: '299',
                  value: draft.priceText,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => draft.priceText = v,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _miniField(
                  label: 'สต็อก',
                  hint: '10',
                  value: draft.stockText,
                  keyboardType: TextInputType.number,
                  onChanged: (v) => draft.stockText = v,
                ),
              ),
              IconButton(
                onPressed: () => _removeDraft(draft.id),
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                tooltip: 'ลบตัวเลือก',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildColorPickerField(ProductVariantDraft draft) {
    final swatchColor = ProductVariantColorSupport.parseHex(draft.color);
    final label = ProductVariantColorSupport.displayLabel(draft.color);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'สี',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        InkWell(
          onTap: () async {
            final picked = await ProductVariantColorSupport.pickColor(
              context,
              initialValue: draft.color,
            );
            if (picked == null || !mounted) {
              return;
            }
            setState(() => draft.color = picked);
          },
          borderRadius: BorderRadius.circular(24),
          child: InputDecorator(
            decoration: InputDecoration(
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: swatchColor ?? Colors.grey.shade200,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade400),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: draft.color.trim().isEmpty
                          ? Colors.grey.shade600
                          : Colors.black87,
                    ),
                  ),
                ),
                Icon(Icons.palette_outlined, size: 18, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniField({
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        TextFormField(
          initialValue: value,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
          ),
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildImagePreview(int imageIndex) {
    if (imageIndex < widget.existingImageUrls.length) {
      final url = widget.existingImageUrls[imageIndex];
      final thumb = imageIndex < widget.existingThumbnailUrls.length
          ? widget.existingThumbnailUrls[imageIndex]
          : url;
      return CachedAppImage(
        imageUrl: thumb.isNotEmpty ? thumb : url,
        fit: BoxFit.cover,
      );
    }
    final localIndex = imageIndex - widget.existingImageUrls.length;
    if (localIndex >= 0 && localIndex < widget.localImageFiles.length) {
      return Image.file(
        File(widget.localImageFiles[localIndex].path),
        fit: BoxFit.cover,
      );
    }
    return ColoredBox(
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_outlined),
    );
  }
}
