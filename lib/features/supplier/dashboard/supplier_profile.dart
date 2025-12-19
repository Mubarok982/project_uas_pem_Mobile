import 'dart:typed_data'; // ✅ Tambahkan ini
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:gap/gap.dart';

class SupplierProfilePage extends StatefulWidget {
  const SupplierProfilePage({super.key});

  @override
  State<SupplierProfilePage> createState() => _SupplierProfilePageState();
}

class _SupplierProfilePageState extends State<SupplierProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _cityController = TextEditingController();

  bool _isLoading = false;
  bool _isInitialLoading = true;
  String? _avatarUrl;
  
  // ✅ GANTI File JADI Uint8List
  Uint8List? _newAvatarBytes;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      setState(() {
        _shopNameController.text = data['shop_name'] ?? '';
        _phoneController.text = data['phone'] ?? '';
        _addressController.text = data['address'] ?? '';
        _cityController.text = data['city'] ?? '';
        _avatarUrl = data['avatar_url'];
        _isInitialLoading = false;
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal load profil: $e")));
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      // ✅ BACA SEBAGAI BYTES
      final bytes = await picked.readAsBytes();
      setState(() => _newAvatarBytes = bytes);
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final supabase = Supabase.instance.client;

    try {
      String? finalAvatarUrl = _avatarUrl;

      // Upload Foto Baru (Binary)
      if (_newAvatarBytes != null) {
        final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        await supabase.storage.from('products').uploadBinary(
          fileName, 
          _newAvatarBytes!,
          fileOptions: const FileOptions(contentType: 'image/jpeg')
        );
        finalAvatarUrl = supabase.storage.from('products').getPublicUrl(fileName);
      }

      await supabase.from('profiles').update({
        'shop_name': _shopNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'address': _addressController.text.trim(),
        'city': _cityController.text.trim(),
        'avatar_url': finalAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil Toko Berhasil Disimpan!")));
        context.pop();
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal simpan: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitialLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text("Pengaturan Toko")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      // ✅ TAMPILKAN DARI MEMORY ATAU URL
                      backgroundImage: _newAvatarBytes != null 
                        ? MemoryImage(_newAvatarBytes!) 
                        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                      child: (_newAvatarBytes == null && _avatarUrl == null)
                          ? const Icon(Icons.store, size: 50, color: Colors.grey)
                          : null,
                    ),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Color(0xFF0F172A), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    )
                  ],
                ),
              ),
              const Gap(24),
              // ... (SISA KODE SAMA DENGAN YANG LAMA) ...
              TextFormField(
                controller: _shopNameController,
                decoration: const InputDecoration(labelText: "Nama Toko", border: OutlineInputBorder(), prefixIcon: Icon(Icons.storefront)),
                validator: (v) => v!.isEmpty ? "Nama toko wajib diisi" : null,
              ),
              const Gap(16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: "Nomor Telepon / WA", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                validator: (v) => v!.isEmpty ? "Nomor telepon wajib diisi" : null,
              ),
              const Gap(16),
              TextFormField(
                controller: _cityController,
                decoration: const InputDecoration(labelText: "Kota", border: OutlineInputBorder(), prefixIcon: Icon(Icons.location_city)),
                validator: (v) => v!.isEmpty ? "Kota wajib diisi" : null,
              ),
              const Gap(16),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Alamat Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
                validator: (v) => v!.isEmpty ? "Alamat wajib diisi" : null,
              ),
              const Gap(30),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("SIMPAN PROFIL"),
                ),
              ),
              const Gap(24),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Keluar Aplikasi", style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
            ],
          ),
        ),
      ),
    );
  }
}