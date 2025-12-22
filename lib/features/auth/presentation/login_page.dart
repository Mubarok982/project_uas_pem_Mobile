import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';
import 'package:veriaga/core/utils/user_preferences.dart'; 
import 'package:veriaga/core/components/veriaga_logo.dart'; 

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

  // Warna Brand
  final Color primaryColor = const Color(0xFF0F172A); // Navy Blue
  final Color accentColor = const Color(0xFFFBBF24);  // Kuning Emas

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Menu akan segera tersedia"),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 2),
      ),
    );
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final supabase = Supabase.instance.client;
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (response.user != null) {
        final userId = response.user!.id;
        final data = await supabase.from('profiles').select('role').eq('id', userId).single();
        final role = data['role'] as String;
        await UserPreferences.saveRole(role);

        if (mounted) {
          if (role == 'supplier') {
            context.go('/supplier/home');
          } else {
            context.go('/dashboard');
          }
        }
      }
    } on AuthException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: Colors.red));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kesalahan koneksi"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 900; 

    return Scaffold(
      backgroundColor: Colors.white,
      // ✅ Ini penting: Tetap true agar UI naik saat keyboard muncul
      resizeToAvoidBottomInset: true, 
      body: Row(
        children: [
          // 1. BAGIAN KIRI (Desktop Only - Tetap Statis Full Height)
          if (isDesktop) 
            Expanded(
              flex: 5,
              child: Container(
                color: primaryColor,
                child: Stack(
                  children: [
                    Positioned(
                      top: -100, right: -100,
                      child: Container(width: 400, height: 400, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle)),
                    ),
                    Positioned(
                      bottom: 50, left: 50,
                      child: Container(width: 200, height: 200, decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), shape: BoxShape.circle)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(60),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const VeriagaLogo(size: 100, isColored: false),
                          const Gap(40),
                          const Text("Kelola Bisnis\nTanpa Batas.", style: TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold, height: 1.2)),
                          const Gap(20),
                          Text("Platform Supplier & Buyer terpercaya dengan sistem verifikasi canggih dan transaksi yang aman.", style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 18, height: 1.5)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 2. BAGIAN KANAN (FORM)
          Expanded(
            flex: isDesktop ? 4 : 1,
            child: Center( // ✅ CENTER: Biar form ada di tengah vertikal
              child: SingleChildScrollView( // ✅ SCROLL: Hanya aktif kalau layar kependekan/keyboard muncul
                padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isDesktop) ...[
                          const Center(child: VeriagaLogo(size: 80)),
                          const Gap(30),
                        ],

                        Text("Selamat Datang!", style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: primaryColor)),
                        const Gap(8),
                        const Text("Silakan login dengan akun Anda.", style: TextStyle(color: Colors.grey, fontSize: 16)),
                        const Gap(40),

                        _buildLabel("Email Address"),
                        TextFormField(
                          controller: _emailController,
                          validator: (v) => (v == null || !v.contains('@')) ? "Email tidak valid" : null,
                          decoration: _inputDecoration(hint: "nama@email.com", icon: Icons.email_outlined),
                        ),
                        const Gap(24),

                        _buildLabel("Password"),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _isObscure,
                          validator: (v) => (v == null || v.isEmpty) ? "Password wajib diisi" : null,
                          decoration: _inputDecoration(hint: "••••••••", icon: Icons.lock_outline, isPassword: true),
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showComingSoon,
                            child: const Text("Lupa Password?", style: TextStyle(color: Colors.grey, fontSize: 13)),
                          ),
                        ),
                        const Gap(24),

                        SizedBox(
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _login,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 2,
                            ),
                            child: _isLoading 
                                ? const CircularProgressIndicator(color: Colors.white) 
                                : const Text("Masuk", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),

                        const Gap(16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Belum punya akun?", style: TextStyle(color: Colors.grey)),
                            TextButton(
                              onPressed: () => context.go('/register'),
                              child: Text("Buat Akun Baru", style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),

                        const Gap(20),
                        
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text("atau", style: TextStyle(color: Colors.grey))),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const Gap(24),

                        SizedBox(
                          height: 56,
                          child: OutlinedButton.icon(
                            onPressed: _showComingSoon,
                            icon: const Icon(Icons.g_mobiledata, size: 30, color: Colors.black87),
                            label: const Text("Masuk dengan Google", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: Colors.grey.shade300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0F172A))),
    );
  }

  InputDecoration _inputDecoration({required String hint, required IconData icon, bool isPassword = false}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400),
      prefixIcon: Icon(icon, color: Colors.grey.shade400, size: 20),
      suffixIcon: isPassword 
          ? IconButton(
              icon: Icon(_isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: Colors.grey.shade400),
              onPressed: () => setState(() => _isObscure = !_isObscure),
            )
          : null,
      filled: true,
      fillColor: Colors.grey.shade50,
      contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade200)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF0F172A), width: 1.5)),
    );
  }
}