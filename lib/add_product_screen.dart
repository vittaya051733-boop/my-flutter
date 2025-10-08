import 'package:flutter/material.dart';
import '../models/product_model.dart'; // Import the model

class AddProductScreen extends StatefulWidget {
  const AddProductScreen({super.key});

  @override
  _AddProductScreenState createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen> {
  // Controllers to get text from TextFields
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _colorsController = TextEditingController();
  final _sizesController = TextEditingController();
  final _weightController = TextEditingController();
  final _otherUnitController = TextEditingController();

  String? _selectedUnit = 'ชิ้น';
  final List<String> _units = ['ชิ้น', 'กรัม', 'กิโลกรัม', 'แพ็ค', 'กล่อง', 'อื่นๆ'];

  @override
  void dispose() {
    // Dispose controllers
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _colorsController.dispose();
    _sizesController.dispose();
    _weightController.dispose();
    _otherUnitController.dispose();
    super.dispose();
  }

  void _saveProduct() {
    // Basic validation
    if (_nameController.text.isEmpty || _priceController.text.isEmpty || _stockController.text.isEmpty) {
      // You can show a snackbar or dialog for error
      print("Please fill all required fields");
      return;
    }

    final newProduct = Product(
      name: _nameController.text,
      description: _descriptionController.text,
      price: double.tryParse(_priceController.text) ?? 0.0,
      stock: int.tryParse(_stockController.text) ?? 0,
      colors: _colorsController.text.split(',').map((e) => e.trim()).toList(),
      sizes: _sizesController.text.split(',').map((e) => e.trim()).toList(),
      weight: double.tryParse(_weightController.text),
      unit: _selectedUnit == 'อื่นๆ' ? _otherUnitController.text : _selectedUnit ?? '',
      // Dummy data for images for now
      imageUrls: ['https://via.placeholder.com/150'], 
    );

    // Pop the screen and return the new product
    Navigator.pop(context, newProduct);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มสินค้าใหม่'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24.0, 24.0, 24.0, 80.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Media section remains the same...
            const Text('รูปภาพและวิดีโอ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            // ... (rest of the media UI) ...
            const SizedBox(height: 32),

            const Text('รายละเอียดสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField(label: 'ชื่อสินค้า', controller: _nameController),
            const SizedBox(height: 16),
            _buildTextField(label: 'รายละเอียดสินค้า', controller: _descriptionController, maxLines: 5, hint: 'ใส่รายละเอียดคุณสมบัติของสินค้าที่นี่...'),
            const SizedBox(height: 32),

            const Text('ข้อมูลจำเพาะของสินค้า', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField(label: 'สี (คั่นด้วยจุลภาค)', controller: _colorsController, hint: 'เช่น แดง, ขาว, ดำ'),
            const SizedBox(height: 16),
            _buildTextField(label: 'ขนาด (คั่นด้วยจุลภาค)', controller: _sizesController, hint: 'เช่น S, M, L, XL'),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _buildTextField(label: 'น้ำหนัก', controller: _weightController, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
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
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                     ],
                  ),
                ),
              ],
            ),
            if (_selectedUnit == 'อื่นๆ')
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: _buildTextField(label: 'ระบุหน่วย (อื่นๆ)', controller: _otherUnitController, hint: 'เช่น หลอด, ขวด, ซอง'),
              ),
             const SizedBox(height: 16),
             Row(
              children: [
                Expanded(child: _buildTextField(label: 'ราคา', controller: _priceController, keyboardType: TextInputType.number)),
                const SizedBox(width: 16),
                Expanded(child: _buildTextField(label: 'สต็อกทั้งหมด', controller: _stockController, keyboardType: TextInputType.number)),
              ],
            ),

            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: _saveProduct, // Call the save function
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('บันทึกสินค้า', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({required String label, int maxLines = 1, TextInputType keyboardType = TextInputType.text, String? hint, TextEditingController? controller}) {
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
              borderRadius: BorderRadius.circular(8),
               borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.grey.shade400),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.orange.shade700, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
