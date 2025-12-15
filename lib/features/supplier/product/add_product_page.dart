import 'dart:typed_data'; // ✅ Import Wajib untuk Uint8List
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';

class AddProductPage extends StatefulWidget {
  const AddProductPage({super.key});

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _priceController = TextEditingController();
  final _stockController = TextEditingController();
  final _categoryController = TextEditingController();

  // ✅ GANTI File JADI Uint8List AGAR BISA JALAN DI WEB & HP
  Uint8List? _imageBytes; 
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _priceController.dispose();
    _stockController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  // 1. Fungsi Ambil Gambar (Baca Bytes)
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70, // Kompres sedikit biar hemat kuota
    );

    if (pickedFile != null) {
      // ✅ BACA SEBAGAI BYTES, BUKAN PATH
      final bytes = await pickedFile.readAsBytes();
      setState(() {
        _imageBytes = bytes;
      });
    }
  }

  // 2. Fungsi Upload & Simpan ke DB
  Future<void> _submitProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wajib upload foto produk!")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final user = supabase.auth.currentUser;
      
      // A. Upload Gambar (Binary)
      // Gunakan timestamp agar nama file unik
      final fileName = '${user!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      await supabase.storage.from('products').uploadBinary(
        fileName,
        _imageBytes!, // Upload bytes
        fileOptions: const FileOptions(contentType: 'image/jpeg'),
      );

      // B. Dapatkan URL Public Gambar
      final imageUrl = supabase.storage.from('products').getPublicUrl(fileName);

      // C. Simpan Data Produk ke Tabel 'products'
      await supabase.from('products').insert({
        'supplier_id': user.id,
        'name': _nameController.text.trim(),
        'description': _descController.text.trim(),
        'price': int.parse(_priceController.text),
        'stock': int.parse(_stockController.text),
        'category': _categoryController.text.trim(),
        'image_url': imageUrl,
        'is_active': true,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Produk berhasil ditambahkan!")),
        );
        context.pop(); // Kembali ke Dashboard
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Produk Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Kotak Upload Foto
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[400]!),
                  ),
                  child: _imageBytes != null
                      // ✅ TAMPILKAN PAKAI Image.memory AGAR SUPPORT WEB
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                        )
                      : const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                            Gap(8),
                            Text("Ketuk untuk upload foto"),
                          ],
                        ),
                ),
              ),
              const Gap(24),

              // Form Input
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nama Produk", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const Gap(16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: "Harga (Rp)", 
                        border: OutlineInputBorder(),
                        prefixText: "Rp ",
                      ),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                  ),
                  const Gap(16),
                  Expanded(
                    child: TextFormField(
                      controller: _stockController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Stok", border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
                    ),
                  ),
                ],
              ),
              const Gap(16),

              TextFormField(
                controller: _categoryController,
                decoration: const InputDecoration(labelText: "Kategori (Misal: Sembako)", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const Gap(16),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Deskripsi Produk", border: OutlineInputBorder()),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const Gap(30),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitProduct,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text("SIMPAN PRODUK"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}