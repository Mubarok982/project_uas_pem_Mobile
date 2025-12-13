import 'dart:io';
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
  File? _newAvatarFile;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // 1. Ambil Data Profil Saat Ini
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
        _avatarUrl = data['avatar_url']; // Bisa null kalau belum set
        _isInitialLoading = false;
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal load profil: $e")));
    }
  }

  // 2. Fungsi Ganti Foto Profil
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (picked != null) {
      setState(() => _newAvatarFile = File(picked.path));
    }
  }

  // 3. Simpan Perubahan
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final userId = Supabase.instance.client.auth.currentUser!.id;
    final supabase = Supabase.instance.client;

    try {
      String? finalAvatarUrl = _avatarUrl;

      // Upload Foto Baru jika ada
      if (_newAvatarFile != null) {
        final fileExt = _newAvatarFile!.path.split('.').last;
        final fileName = 'avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        // Pastikan bucket 'avatars' ada (Nanti kita buat di SQL)
        // Untuk sekarang kita tumpang di bucket 'products' dulu biar gampang, atau buat bucket baru.
        // Kita pakai bucket 'products' saja sementara.
        await supabase.storage.from('products').upload(fileName, _newAvatarFile!);
        finalAvatarUrl = supabase.storage.from('products').getPublicUrl(fileName);
      }

      // Update Database
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
        context.pop(); // Kembali ke Dashboard
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
              // Avatar Circle
              GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.grey[200],
                      backgroundImage: _newAvatarFile != null 
                        ? FileImage(_newAvatarFile!) 
                        : (_avatarUrl != null ? NetworkImage(_avatarUrl!) : null) as ImageProvider?,
                      child: (_newAvatarFile == null && _avatarUrl == null)
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
                decoration: const InputDecoration(labelText: "Alamat Lengkap (Untuk Penjemputan Paket)", border: OutlineInputBorder(), prefixIcon: Icon(Icons.map)),
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
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("SIMPAN PROFIL"),
                ),
              ),
              const Gap(24),
              
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Keluar Aplikasi", style: TextStyle(color: Colors.red)),
                onTap: _logout,
              ),
              const Gap(20),
              const Text("Versi 1.0.0 - Veriaga B2B", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}