import 'dart:typed_data'; // WAJIB ADA
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class BuyerAiVerificationPage extends StatefulWidget {
  final Map<String, dynamic> order;
  const BuyerAiVerificationPage({super.key, required this.order});

  @override
  State<BuyerAiVerificationPage> createState() => _BuyerAiVerificationPageState();
}

class _BuyerAiVerificationPageState extends State<BuyerAiVerificationPage> {
  // Gunakan Uint8List agar jalan di WEB dan HP
  Uint8List? _imageBytes; 
  bool _isAnalyzing = false;
  String? _analysisResult; 
  String? _analysisReason; 

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    // Kompresi 40% biar ringan & cepat
    final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 40); 
    
    if (picked != null) {
      // BACA SEBAGAI BYTES (MEMORY), BUKAN FILE PATH
      final bytes = await picked.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _analysisResult = null;
        _analysisReason = null;
      });
    }
  }

  Future<void> _analyzeWithGemini() async {
    if (_imageBytes == null) return;
    setState(() => _isAnalyzing = true);

    try {
      final supabase = Supabase.instance.client;
      
      // 1. Ambil Nama Produk
      final orderItems = await supabase
          .from('order_items')
          .select('*, products(name)')
          .eq('order_id', widget.order['id'])
          .limit(1)
          .maybeSingle();
      
      final productName = orderItems?['products']['name'] ?? 'Barang ini';

      // 2. Encode gambar ke Base64 String
      final String base64Image = base64Encode(_imageBytes!);

      // 3. Panggil Edge Function
      final response = await supabase.functions.invoke(
        'verify-image',
        body: {
          'productName': productName,
          'imageBase64': base64Image,
        },
      );

      // 4. Cek Response
      if (response.status == 200) {
        final data = response.data;
        // Parsing hasil: valid|alasan
        final textResponse = data['result'] as String;
        final parts = textResponse.split('|');
        
        setState(() {
          _isAnalyzing = false;
          _analysisResult = parts[0].trim().toLowerCase();
          _analysisReason = parts.length > 1 ? parts[1].trim() : "Tanpa alasan";
        });
      } else {
        // Tangkap error detail dari server
        final dynamic errorData = response.data;
        final String errorMessage = (errorData is Map && errorData['error'] != null) 
            ? errorData['error'] 
            : errorData.toString();
        throw Exception(errorMessage);
      }

    } catch (e) {
      setState(() {
        _isAnalyzing = false;
        _analysisResult = 'error';
        _analysisReason = "Gagal: $e";
      });
    }
  }

  Future<void> _finishOrder() async {
    setState(() => _isAnalyzing = true);
    final supabase = Supabase.instance.client;
    final orderId = widget.order['id'];

    try {
      await supabase.from('orders').update({'status': 'completed'}).eq('id', orderId);
      await supabase.from('transactions').update({'status': 'released'}).eq('order_id', orderId);

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text("Transaksi Selesai! 🎉"),
            content: const Text("Dana diteruskan ke Penjual."),
            actions: [
              TextButton(onPressed: () => context.go('/dashboard'), child: const Text("OK"))
            ],
          ),
        );
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      setState(() => _isAnalyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Verifikasi AI (Final)")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
             GestureDetector(
              onTap: _takePhoto,
              child: Container(
                height: 300,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey),
                ),
                child: _imageBytes == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                          Gap(8),
                          Text("Ketuk Kamera"),
                        ],
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        // PENTING: Pakai Image.memory untuk Web & HP
                        child: Image.memory(_imageBytes!, fit: BoxFit.cover),
                      ),
              ),
            ),
            const Gap(30),

            if (_isAnalyzing) ...[
              const CircularProgressIndicator(),
              const Gap(16),
              const Text("AI sedang berpikir..."),
            ] else if (_analysisResult == 'valid') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  children: [
                    const Text("BARANG VALID!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    Text(_analysisReason ?? ""),
                  ],
                ),
              ),
              const Gap(16),
              ElevatedButton(onPressed: _finishOrder, child: const Text("TERIMA BARANG")),
            ] else if (_analysisResult == 'invalid') ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red),
                ),
                child: Column(
                  children: [
                    const Text("AI MENOLAK!", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
                    Text(_analysisReason ?? ""),
                  ],
                ),
              ),
              const Gap(16),
              ElevatedButton(onPressed: _takePhoto, child: const Text("Foto Ulang")),
            ] else if (_imageBytes != null) ...[
              ElevatedButton.icon(
                onPressed: _analyzeWithGemini,
                icon: const Icon(Icons.cloud_upload),
                label: const Text("ANALISIS SEKARANG"),
              ),
            ],
            
            if(_analysisResult == 'error')
              Padding(padding: const EdgeInsets.only(top: 20), child: Text(_analysisReason ?? "Error", style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
    );
  }
}