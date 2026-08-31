import 'package:flutter/material.dart';

class ProductVariantColorOption {
  const ProductVariantColorOption({
    required this.hex,
    required this.labelTh,
  });

  final String hex;
  final String labelTh;

  Color get color => ProductVariantColorSupport.parseHex(hex) ?? Colors.grey;
}

/// Preset + hex storage for product variant colors.
class ProductVariantColorSupport {
  ProductVariantColorSupport._();

  static const List<ProductVariantColorOption> presets = <ProductVariantColorOption>[
    ProductVariantColorOption(hex: '#E53935', labelTh: 'แดง'),
    ProductVariantColorOption(hex: '#D81B60', labelTh: 'ชมพู'),
    ProductVariantColorOption(hex: '#8E24AA', labelTh: 'ม่วง'),
    ProductVariantColorOption(hex: '#3949AB', labelTh: 'น้ำเงินเข้ม'),
    ProductVariantColorOption(hex: '#1E88E5', labelTh: 'น้ำเงิน'),
    ProductVariantColorOption(hex: '#00ACC1', labelTh: 'ฟ้า'),
    ProductVariantColorOption(hex: '#00897B', labelTh: 'เขียวมิ้นท์'),
    ProductVariantColorOption(hex: '#43A047', labelTh: 'เขียว'),
    ProductVariantColorOption(hex: '#7CB342', labelTh: 'เขียวอ่อน'),
    ProductVariantColorOption(hex: '#FDD835', labelTh: 'เหลือง'),
    ProductVariantColorOption(hex: '#FB8C00', labelTh: 'ส้ม'),
    ProductVariantColorOption(hex: '#6D4C41', labelTh: 'น้ำตาล'),
    ProductVariantColorOption(hex: '#FFFFFF', labelTh: 'ขาว'),
    ProductVariantColorOption(hex: '#BDBDBD', labelTh: 'เทา'),
    ProductVariantColorOption(hex: '#212121', labelTh: 'ดำ'),
    ProductVariantColorOption(hex: '#FFD180', labelTh: 'ครีม'),
    ProductVariantColorOption(hex: '#FF7043', labelTh: 'คอรัล'),
    ProductVariantColorOption(hex: '#26C6DA', labelTh: 'เทอร์ควอยซ์'),
  ];

  static bool isHexColor(String? value) {
    final normalized = (value ?? '').trim();
    return RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(normalized);
  }

  static String normalizeHex(String? value) {
    final trimmed = (value ?? '').trim();
    if (!isHexColor(trimmed)) {
      return trimmed;
    }
    return trimmed.toUpperCase();
  }

  static Color? parseHex(String? value) {
    final normalized = normalizeHex(value);
    if (!isHexColor(normalized)) {
      return null;
    }
    final hex = normalized.substring(1);
    final intValue = int.tryParse(hex, radix: 16);
    if (intValue == null) {
      return null;
    }
    return Color(0xFF000000 | intValue);
  }

  static String encodeColor(Color color) {
    final rgb = color.toARGB32() & 0xFFFFFF;
    return '#${rgb.toRadixString(16).padLeft(6, '0').toUpperCase()}';
  }

  /// Hex preset, or legacy Thai color name saved as plain text.
  static Color? colorForStored(String? stored) {
    final parsed = parseHex(stored);
    if (parsed != null) {
      return parsed;
    }
    final value = (stored ?? '').trim();
    if (value.isEmpty) {
      return null;
    }
    for (final preset in presets) {
      if (preset.labelTh == value) {
        return preset.color;
      }
    }
    return null;
  }

  static String displayLabel(String? stored) {
    final value = (stored ?? '').trim();
    if (value.isEmpty) {
      return 'เลือกสี';
    }
    if (!isHexColor(value)) {
      return value;
    }
    final normalized = normalizeHex(value);
    for (final preset in presets) {
      if (preset.hex == normalized) {
        return preset.labelTh;
      }
    }
    return normalized;
  }

  static ProductVariantColorOption? presetForStored(String? stored) {
    final normalized = normalizeHex(stored);
    if (!isHexColor(normalized)) {
      return null;
    }
    for (final preset in presets) {
      if (preset.hex == normalized) {
        return preset;
      }
    }
    return null;
  }

  static Future<String?> pickColor(
    BuildContext context, {
    String? initialValue,
  }) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return _ProductVariantColorPickerSheet(initialValue: initialValue);
      },
    );
  }
}

class _ProductVariantColorPickerSheet extends StatefulWidget {
  const _ProductVariantColorPickerSheet({this.initialValue});

  final String? initialValue;

  @override
  State<_ProductVariantColorPickerSheet> createState() =>
      _ProductVariantColorPickerSheetState();
}

class _ProductVariantColorPickerSheetState
    extends State<_ProductVariantColorPickerSheet> {
  late String? _selectedHex;

  @override
  void initState() {
    super.initState();
    final initial = (widget.initialValue ?? '').trim();
    if (ProductVariantColorSupport.isHexColor(initial)) {
      _selectedHex = ProductVariantColorSupport.normalizeHex(initial);
    } else {
      _selectedHex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = ProductVariantColorSupport.parseHex(_selectedHex);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'เลือกสี',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            if (selectedColor != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selectedColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.grey.shade400),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    ProductVariantColorSupport.displayLabel(_selectedHex),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: ProductVariantColorSupport.presets.map((preset) {
                final selected = _selectedHex == preset.hex;
                return InkWell(
                  onTap: () => setState(() => _selectedHex = preset.hex),
                  borderRadius: BorderRadius.circular(999),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: preset.color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? const Color(0xFF2563EB)
                                : Colors.grey.shade400,
                            width: selected ? 3 : 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        preset.labelTh,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(growable: false),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () async {
                final custom = await showDialog<Color>(
                  context: context,
                  builder: (dialogContext) => _CustomColorDialog(
                    initial: selectedColor ?? Colors.blue,
                  ),
                );
                if (custom != null && mounted) {
                  setState(() {
                    _selectedHex =
                        ProductVariantColorSupport.encodeColor(custom);
                  });
                }
              },
              icon: const Icon(Icons.palette_outlined),
              label: const Text('เลือกสีเอง'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(''),
                    child: const Text('ล้างสี'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedHex == null
                        ? null
                        : () => Navigator.of(context).pop(_selectedHex),
                    child: const Text('ใช้สีนี้'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomColorDialog extends StatefulWidget {
  const _CustomColorDialog({required this.initial});

  final Color initial;

  @override
  State<_CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<_CustomColorDialog> {
  late HSVColor _hsv;

  @override
  void initState() {
    super.initState();
    _hsv = HSVColor.fromColor(widget.initial);
  }

  @override
  Widget build(BuildContext context) {
    final color = _hsv.toColor();
    return AlertDialog(
      title: const Text('เลือกสีเอง'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade400),
            ),
          ),
          const SizedBox(height: 16),
          Text('เฉดสี', style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: _hsv.hue,
            min: 0,
            max: 360,
            onChanged: (value) => setState(() => _hsv = _hsv.withHue(value)),
          ),
          Text('ความสว่าง', style: Theme.of(context).textTheme.labelLarge),
          Slider(
            value: _hsv.value,
            min: 0.2,
            max: 1,
            onChanged: (value) => setState(() => _hsv = _hsv.withValue(value)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('ยกเลิก'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(color),
          child: const Text('ตกลง'),
        ),
      ],
    );
  }
}

/// Circle swatch for a stored variant color (hex or legacy label).
class ProductVariantColorSwatch extends StatelessWidget {
  const ProductVariantColorSwatch({
    super.key,
    required this.storedColor,
    this.size = 24,
    this.selected = false,
    this.onTap,
    this.lightBorder = false,
  });

  final String storedColor;
  final double size;
  final bool selected;
  final VoidCallback? onTap;
  final bool lightBorder;

  @override
  Widget build(BuildContext context) {
    final fill = ProductVariantColorSupport.colorForStored(storedColor);
    final borderColor = selected
        ? const Color(0xFF2563EB)
        : (lightBorder ? Colors.white70 : Colors.grey.shade400);

    final swatch = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill ?? Colors.grey.shade300,
        shape: BoxShape.circle,
        border: Border.all(
          color: borderColor,
          width: selected ? 2.5 : 1,
        ),
        boxShadow: lightBorder
            ? const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ]
            : null,
      ),
    );

    if (onTap == null) {
      return swatch;
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: swatch,
      ),
    );
  }
}

class ProductVariantColorSwatchRow extends StatelessWidget {
  const ProductVariantColorSwatchRow({
    super.key,
    required this.colors,
    this.size = 20,
    this.spacing = 6,
    this.selectedColor,
    this.onColorSelected,
    this.lightBorder = false,
  });

  final List<String> colors;
  final double size;
  final double spacing;
  final String? selectedColor;
  final ValueChanged<String>? onColorSelected;
  final bool lightBorder;

  @override
  Widget build(BuildContext context) {
    if (colors.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: spacing,
      runSpacing: spacing,
      children: colors
          .map(
            (color) => ProductVariantColorSwatch(
              storedColor: color,
              size: size,
              selected: selectedColor == color,
              lightBorder: lightBorder,
              onTap: onColorSelected == null
                  ? null
                  : () => onColorSelected!(color),
            ),
          )
          .toList(growable: false),
    );
  }
}
