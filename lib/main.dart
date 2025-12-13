import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:veriaga/core/constants/app_constants.dart';
import 'package:veriaga/core/router/app_router.dart'; // Import Router

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: AppConstants.supabaseUrl,
    anonKey: AppConstants.supabaseAnonKey,
  );

  runApp(const ProviderScope(child: VeriagaApp()));
}

class VeriagaApp extends ConsumerWidget {
  const VeriagaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ubah jadi MaterialApp.router
    return MaterialApp.router(
      title: 'Veriaga',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A), 
          primary: const Color(0xFF0F172A),
          secondary: const Color(0xFF22C55E),
        ),
        useMaterial3: true,
        // Font Google (Optional, kalau error hapus aja baris ini)
        // textTheme: GoogleFonts.interTextTheme(), 
      ),
      routerConfig: appRouter, // Pasang Router di sini
    );
  }
}