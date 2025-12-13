import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';

class EditProductPage extends StatefulWidget {
  // Kita butuh data produk lama untuk diedit
  final Map<String, dynamic> product;

  const EditProductPage({super.key, required this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _descController;
  late TextEditingController _priceController;
  late TextEditingController _stockController;
  late TextEditingController _categoryController;

  File? _newImageFile;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Isi controller dengan data lama
    _nameController = TextEditingController(text: widget.product['name']);
    _descController = TextEditingController(text: widget.product['description']);
    _priceController = TextEditingController(text: widget.product['price'].toString());
    _stockController = TextEditingController(text: widget.product['stock'].toString());
    _categoryController = TextEditingController(text: widget.product['category']);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (pickedFile != null) {
      setState(() => _newImageFile = File(pickedFile.path));
    }
  }

  Future<void> _updateProduct() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      String? imageUrl = widget.product['image_url'];

      // 1. Jika ada gambar baru, upload dulu
      if (_newImageFile != null) {
        final fileExt = _newImageFile!.path.split('.').last;
        final fileName = '${widget.product['supplier_id']}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await supabase.storage.from('products').upload(
          fileName,
          _newImageFile!,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
        
        imageUrl = supabase.storage.from('products').getPublicUrl(fileName);
      }

      // 2. Update Data di Database
      await supabase.from('products').update({
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': int.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'category': _categoryController.text.trim(),
        'image_url': imageUrl,
        'updated_at': DateTime.now().toIso8601String(), // Update timestamp
      }).eq('id', widget.product['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Produk berhasil diperbarui!")));
        context.pop(); // Kembali ke list
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Produk")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Preview Gambar (Lama atau Baru)
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey),
                  ),
                  child: _newImageFile != null
                      ? Image.file(_newImageFile!, fit: BoxFit.cover)
                      : Image.network(widget.product['image_url'] ?? '', fit: BoxFit.cover, errorBuilder: (_,__,___) => const Icon(Icons.broken_image)),
                ),
              ),
              const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Ketuk gambar untuk mengganti"))),
              const Gap(20),

              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: "Nama Produk", border: OutlineInputBorder())),
              const Gap(16),
              
              Row(children: [
                Expanded(child: TextFormField(controller: _priceController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Harga", prefixText: "Rp ", border: OutlineInputBorder()))),
                const Gap(16),
                Expanded(child: TextFormField(controller: _stockController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stok", border: OutlineInputBorder()))),
              ]),
              const Gap(16),
              
              TextFormField(controller: _categoryController, decoration: const InputDecoration(labelText: "Kategori", border: OutlineInputBorder())),
              const Gap(16),
              
              TextFormField(controller: _descController, maxLines: 3, decoration: const InputDecoration(labelText: "Deskripsi", border: OutlineInputBorder())),
              const Gap(30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProduct,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN PERUBAHAN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}