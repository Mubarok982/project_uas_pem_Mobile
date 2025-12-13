import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  
  // Controller input text
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isObscure = true; // Untuk sembunyikan password

  // ✅ KOREKSI 1: Wajib Dispose Controller untuk mencegah Memory Leak
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

      // 1. Proses Login ke Auth Supabase
      final AuthResponse response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Jika sukses login, Cek Role user ini di tabel 'profiles'
      if (response.user != null) {
        final userId = response.user!.id;
        
        // Query ke database untuk ambil role
        // Pastikan RLS di Supabase mengizinkan user membaca profilnya sendiri
        final data = await supabase
            .from('profiles')
            .select('role')
            .eq('id', userId)
            .single(); // single() karena kita cuma butuh 1 baris data

        final role = data['role'] as String;

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Login Berhasil sebagai $role!")),
          );
          
          // 3. Redirect ke Dashboard dengan membawa info Role
          // (Pastikan '/dashboard' sudah ada di app_router.dart)
          context.go('/dashboard', extra: role);
        }
      }

    } on AuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message), // Pesan error spesifik (salah password/email)
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terjadi kesalahan jaringan atau server"), 
            backgroundColor: Colors.red
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo atau Icon
                const Icon(Icons.lock_person_outlined, size: 80, color: Color(0xFF0F172A)),
                const Gap(20),
                
                const Text(
                  "Selamat Datang Kembali",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const Text(
                  "Masuk untuk melanjutkan transaksi",
                  style: TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const Gap(40),

                // Input Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  // ✅ KOREKSI 2: Validasi Format Email agar lebih aman
                  validator: (v) => (v == null || !v.contains('@')) 
                      ? "Format email tidak valid" 
                      : null,
                ),
                const Gap(16),

                // Input Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isObscure,
                  decoration: InputDecoration(
                    labelText: "Password",
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.lock_outlined),
                    suffixIcon: IconButton(
                      icon: Icon(_isObscure ? Icons.visibility : Icons.visibility_off),
                      onPressed: () => setState(() => _isObscure = !_isObscure),
                    ),
                  ),
                  validator: (v) => (v == null || v.isEmpty) 
                      ? "Password wajib diisi" 
                      : null,
                ),
                const Gap(10),

                // Lupa Password (Tombol Dummy)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                       // Fitur Reset Password bisa ditambahkan nanti
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text("Fitur Reset Password segera hadir!")),
                       );
                    },
                    child: const Text("Lupa Password?"),
                  ),
                ),
                const Gap(20),

                // Tombol Login
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: _isLoading 
                    ? const SizedBox(
                        height: 20, width: 20, 
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      ) 
                    : const Text("MASUK", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),

                const Gap(20),
                
                // Link ke Register
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Belum punya akun?"),
                    TextButton(
                      onPressed: () => context.go('/register'),
                      child: const Text("Daftar Sekarang"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}