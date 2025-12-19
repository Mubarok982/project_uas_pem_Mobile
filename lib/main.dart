import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flex_color_scheme/flex_color_scheme.dart'; // ✅ Library Warna
import 'package:google_fonts/google_fonts.dart'; // ✅ Library Font

import 'package:veriaga/core/constants/app_constants.dart';
import 'package:veriaga/core/router/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inisialisasi Supabase
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
    return MaterialApp.router(
      title: 'Veriaga',
      debugShowCheckedModeBanner: false,
      
      // ✅ 1. TEMA LIGHT (Siang) - Modern Blue
      theme: FlexThemeData.light(
        scheme: FlexScheme.blueWhale, // Warna Biru Elegan (Mirip branding awalmu)
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 7,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 10,
          blendOnColors: false,
          useTextTheme: true,
          useM2StyleDividerInM3: true,
          alignedDropdown: true,
          useInputDecoratorThemeInDialogs: true,
          // Bikin tombol radiusnya membulat dikit biar modern
          defaultRadius: 12.0, 
          elevatedButtonSchemeColor: SchemeColor.onPrimary,
          elevatedButtonSecondarySchemeColor: SchemeColor.primary,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        // ✅ GANTI FONT JADI POPPINS
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),

      // ✅ 2. TEMA DARK (Malam) - Otomatis aktif kalau HP user mode gelap
      darkTheme: FlexThemeData.dark(
        scheme: FlexScheme.blueWhale,
        surfaceMode: FlexSurfaceMode.levelSurfacesLowScaffold,
        blendLevel: 13,
        subThemesData: const FlexSubThemesData(
          blendOnLevel: 20,
          useTextTheme: true,
          useM2StyleDividerInM3: true,
          defaultRadius: 12.0,
        ),
        visualDensity: FlexColorScheme.comfortablePlatformDensity,
        useMaterial3: true,
        swapLegacyOnMaterial3: true,
        fontFamily: GoogleFonts.poppins().fontFamily,
      ),
      
      themeMode: ThemeMode.system, // Mengikuti pengaturan sistem HP
      routerConfig: appRouter, // Pastikan variabel 'appRouter' ada di app_router.dart
    );
  }
}