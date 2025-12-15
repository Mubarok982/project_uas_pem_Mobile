import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';

class BuyerProfilePage extends StatefulWidget {
  const BuyerProfilePage({super.key});

  @override
  State<BuyerProfilePage> createState() => _BuyerProfilePageState();
}

class _BuyerProfilePageState extends State<BuyerProfilePage> {
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  // Ambil data profil (termasuk alamat untuk pengiriman)
  Future<void> _fetchProfile() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser!.id;
      final data = await Supabase.instance.client
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      if (mounted) {
        setState(() {
          _profileData = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Fungsi Logout
  Future<void> _logout() async {
    // Tampilkan dialog konfirmasi dulu
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Keluar Aplikasi"),
        content: const Text("Yakin ingin keluar?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    // Fallback data jika kosong
    final name = _profileData?['full_name'] ?? _profileData?['username'] ?? 'User Veriaga';
    final email = Supabase.instance.client.auth.currentUser?.email ?? '-';
    final avatarUrl = _profileData?['avatar_url'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Profil Saya"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const Gap(20),
            // 1. Header Foto & Nama
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.blue[100],
                    backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                    child: avatarUrl == null 
                        ? const Icon(Icons.person, size: 50, color: Colors.blue) 
                        : null,
                  ),
                  const Gap(16),
                  Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  Text(email, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const Gap(30),

            // 2. Menu Options
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5)),
                ],
              ),
              child: Column(
                children: [
                  _buildMenuItem(
                    icon: Icons.edit,
                    title: "Edit Profil & Alamat",
                    subtitle: "Atur nama dan alamat pengiriman",
                    onTap: () async {
                      // Tunggu hasil dari halaman edit, lalu refresh data
                      await context.push('/buyer/edit-profile', extra: _profileData);
                      _fetchProfile(); // Refresh setelah kembali
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.history,
                    title: "Riwayat Transaksi",
                    subtitle: "Lihat status pesanan lama",
                    onTap: () {
                      // Bisa diarahkan ke tab Transaksi (index 2)
                      // Tapi karena ini IndexedStack di parent, user manual klik tab saja
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Silakan klik menu Transaksi di bawah")));
                    },
                  ),
                  const Divider(height: 1),
                  _buildMenuItem(
                    icon: Icons.help_outline,
                    title: "Bantuan",
                    subtitle: "Pusat bantuan & CS",
                    onTap: () {},
                  ),
                ],
              ),
            ),

            const Gap(20),

            // 3. Tombol Logout
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _logout,
                  icon: const Icon(Icons.logout),
                  label: const Text("Keluar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red[50],
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                  ),
                ),
              ),
            ),
            const Gap(20),
            const Text("Veriaga App v1.0", style: TextStyle(color: Colors.grey, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: Colors.blue),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}