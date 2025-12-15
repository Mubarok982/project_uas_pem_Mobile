import 'dart:typed_data'; // ✅ Pakai Uint8List biar aman di Web
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';

class BuyerEditProfilePage extends StatefulWidget {
  final Map<String, dynamic>? currentData;
  const BuyerEditProfilePage({super.key, this.currentData});

  @override
  State<BuyerEditProfilePage> createState() => _BuyerEditProfilePageState();
}

class _BuyerEditProfilePageState extends State<BuyerEditProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _cityController;

  bool _isLoading = false;
  Uint8List? _newAvatarBytes; // Untuk simpan foto baru (Memory)

  @override
  void initState() {
    super.initState();
    // Isi form dengan data lama
    _nameController = TextEditingController(text: widget.currentData?['full_name'] ?? widget.currentData?['username'] ?? '');
    _phoneController = TextEditingController(text: widget.currentData?['phone'] ?? '');
    _addressController = TextEditingController(text: widget.currentData?['address'] ?? '');
    _cityController = TextEditingController(text: widget.currentData?['city'] ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      setState(() => _newAvatarBytes = bytes);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final userId = supabase.auth.currentUser!.id;
      
      String? avatarUrl = widget.currentData?['avatar_url'];

      // 1. Upload Foto (Jika ada baru)
      if (_newAvatarBytes != null) {
        final fileName = 'avatar_buyer_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('products').uploadBinary(
          fileName, 
          _newAvatarBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg')
        );
        avatarUrl = supabase.storage.from('products').getPublicUrl(fileName);
      }

      // 2. Update Database
      await supabase.from('profiles').update({
        'full_name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'avatar_url': avatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil berhasil disimpan!")));
        context.pop(); // Kembali
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Edit Profil")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.grey[200],
                  backgroundImage: _newAvatarBytes != null
                      ? MemoryImage(_newAvatarBytes!)
                      : (widget.currentData?['avatar_url'] != null ? NetworkImage(widget.currentData!['avatar_url']) : null) as ImageProvider?,
                  child: (_newAvatarBytes == null && widget.currentData?['avatar_url'] == null)
                      ? const Icon(Icons.camera_alt, color: Colors.grey)
                      : null,
                ),
              ),
              const Gap(8),
              const Text("Ganti Foto", style: TextStyle(color: Colors.blue)),
              const Gap(24),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const Gap(16),

              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "No. Handphone", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const Gap(16),

              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: "Kota", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
                validator: (v) => v!.isEmpty ? "Wajib diisi" : null,
              ),
              const Gap(16),

              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: "Alamat Lengkap Pengiriman", 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.map),
                  alignLabelWithHint: true,
                ),
                validator: (v) => v!.isEmpty ? "Alamat wajib diisi untuk pengiriman" : null,
              ),
              const Gap(30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.blue,
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