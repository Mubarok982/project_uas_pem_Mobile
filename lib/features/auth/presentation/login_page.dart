import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';
import 'package:veriaga/core/utils/user_preferences.dart'; 
import 'package:veriaga/core/components/veriaga_logo.dart'; // ✅ Pastikan import ini ada

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isObscure = true; 

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;

      // 1. Login Supabase
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Cek Role
      if (response.user != null) {
        final userId = response.user!.id;
        
        final data = await supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single();

        final role = data['role'] as String;

        // 3. Simpan Role
        await UserPreferences.saveRole(role);

        if (mounted) {
          // 4. Navigasi
          if (role == 'supplier') {
            context.go('/supplier/home');
          } else {
            context.go('/dashboard');
          }
        }
      }

    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: ${e.message}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kesalahan koneksi"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Brand Color (Biru Veriaga)
    const brandColor = Color(0xFF0F172A); 

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        // Tombol Back (Hanya muncul jika bisa kembali)
        leading: context.canPop() 
            ? IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.black54),
                onPressed: () => context.pop(),
              )
            : null,
        actions: [
          // Tombol Daftar di Pojok Kanan Atas
          TextButton(
            onPressed: () => context.go('/register'),
            child: const Text(
              "Daftar",
              style: TextStyle(
                color: brandColor, 
                fontWeight: FontWeight.bold,
                fontSize: 16
              ),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Gap(20),
                
                // ✅ KOREKSI UTAMA: Menggunakan Widget Logo Veriaga
                // Menggantikan container icon manual yang lama
                const Center(
                  child: VeriagaLogo(size: 110), 
                ),
                
                const Gap(30),

                const Text(
                  "Masuk ke Veriaga",
                  style: TextStyle(
                    fontSize: 26, 
                    fontWeight: FontWeight.bold, 
                    color: Colors.black87
                  ),
                ),
                const Gap(8),
                const Text(
                  "Selamat datang kembali! Silakan masukkan data akun Anda.",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const Gap(40),

                // INPUT: Email
                const Text("Email", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                const Gap(8),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || !v.contains('@')) ? "Email tidak valid" : null,
                  decoration: InputDecoration(
                    hintText: "Contoh: user@email.com",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: brandColor, width: 2)),
                  ),
                ),
                
                const Gap(24),

                // INPUT: Password
                const Text("Kata Sandi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black54)),
                const Gap(8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  validator: (v) => (v == null || v.isEmpty) ? "Password wajib diisi" : null,
                  decoration: InputDecoration(
                    hintText: "Masukkan kata sandi",
                    hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.grey[300]!)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: brandColor, width: 2)),
                  ),
                ),

                // Lupa Password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Fitur Reset Password segera hadir!")),
                       );
                    },
                    child: const Text("Lupa Kata Sandi?", style: TextStyle(color: brandColor, fontWeight: FontWeight.bold)),
                  ),
                ),
                
                const Gap(20),

                // TOMBOL MASUK
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: brandColor,
                      foregroundColor: Colors.white,
                      elevation: 0, 
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Text("Masuk", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const Gap(30),

                // Divider
                Row(
                  children: [
                    Expanded(child: Divider(color: Colors.grey[300])),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text("atau masuk dengan", style: TextStyle(color: Colors.grey, fontSize: 12)),
                    ),
                    Expanded(child: Divider(color: Colors.grey[300])),
                  ],
                ),
                
                const Gap(24),

                // Tombol Google (Dummy)
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: _isLoading ? null : () {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Login Google (Coming Soon)")));
                    },
                    icon: const Icon(Icons.g_mobiledata, size: 28, color: Colors.black87), 
                    label: const Text("Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ),
                
                const Gap(30),
                
                // Footer
                Center(
                  child: GestureDetector(
                    onTap: () {},
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                        children: [
                          TextSpan(text: "Butuh bantuan? "),
                          TextSpan(text: "Hubungi Veriaga Care", style: TextStyle(color: brandColor, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                const Gap(20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}