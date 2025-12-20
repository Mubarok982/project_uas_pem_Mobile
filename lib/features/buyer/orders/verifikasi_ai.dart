import 'dart:typed_data'; // ✅ Pakai ini buat ganti dart:io
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class VerifikasiAI extends StatefulWidget {
  final Map<String, dynamic> data; 

  const VerifikasiAI({super.key, required this.data});

  @override
  State<VerifikasiAI> createState() => _VerifikasiAIState();
}

class _VerifikasiAIState extends State<VerifikasiAI> {
  final ImagePicker _picker = ImagePicker();
  
  // Melacak status verifikasi tiap barang
  // Format: { index_barang: status_bool }
  Map<int, bool> _verificationStatus = {};
  bool _isGlobalLoading = false;

  late Map<String, dynamic> order;
  late List<Map<String, dynamic>> items;

  @override
  void initState() {
    super.initState();
    order = widget.data['order'];
    items = widget.data['items'] as List<Map<String, dynamic>>;
  }

  // ✅ LOGIC AMAN UNTUK WEB & HP
  Future<void> _verifyItem(int index) async {
    // 1. Ambil Foto
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera, imageQuality: 50);
    if (photo == null) return;

    setState(() => _isGlobalLoading = true);

    try {
      // 2. Baca Data Gambar (Byte) - CARA AMAN (Tanpa dart:io)
      final Uint8List imageBytes = await photo.readAsBytes();
      final String base64Image = base64Encode(imageBytes);

      // 3. Panggil AI (Edge Function)
      final supabase = Supabase.instance.client;
      final productName = items[index]['products']['name'];
      
      final response = await supabase.functions.invoke(
        'verify-image',
        body: {
          'productName': productName,
          'imageBase64': base64Image, // Kirim sebagai base64 string
        },
      );
      
      // 4. Cek Hasil AI
      if (response.status == 200) {
        final data = response.data;
        // Asumsi format response: { "result": "valid|Barang sesuai" }
        final textResponse = data['result'] as String;
        final parts = textResponse.split('|');
        final status = parts[0].trim().toLowerCase();
        final reason = parts.length > 1 ? parts[1].trim() : "";

        if (status == 'valid') {
          setState(() {
            _verificationStatus[index] = true; // ✅ Tandai Hijau
          });
          _showSnack("✅ Barang sesuai: $reason", Colors.green);
        } else {
          _showSnack("❌ Ditolak AI: $reason", Colors.red);
        }
      } else {
         throw Exception("Server Error: ${response.data}");
      }

    } catch (e) {
      _showSnack("Gagal verifikasi: $e", Colors.red);
    } finally {
      setState(() => _isGlobalLoading = false);
    }
  }

  Future<void> _completeOrder() async {
    setState(() => _isGlobalLoading = true);
    final supabase = Supabase.instance.client;
    
    try {
      // Update Status Order
      await supabase.from('orders').update({
        'status': 'COMPLETED',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', order['id']);

      // Update Transaksi (Pencairan Dana)
      await supabase.from('transactions').update({
        'status': 'released' // Dana diteruskan ke penjual
      }).eq('order_id', order['id']);

      if (mounted) {
        _showDialogSuccess();
      }
    } catch (e) {
      _showSnack("Gagal update order: $e", Colors.red);
      setState(() => _isGlobalLoading = false);
    }
  }

  void _showDialogSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Pesanan Selesai! 🎉"),
        content: const Text("Terima kasih sudah berbelanja. Dana telah diteruskan ke penjual."),
        actions: [
          ElevatedButton(
            onPressed: () => context.go('/dashboard'), 
            child: const Text("Kembali ke Home")
          )
        ],
      ),
    );
  }

  void _fileDispute(int index) {
     _showSnack("Fitur komplain akan segera hadir.", Colors.orange);
  }

  void _showSnack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: color));
  }

  @override
  Widget build(BuildContext context) {
    // Cek apakah semua barang sudah terverifikasi
    bool allVerified = true;
    for (int i = 0; i < items.length; i++) {
      if (_verificationStatus[i] != true) {
        allVerified = false;
        break;
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Checklist Barang")),
      body: Stack(
        children: [
          Column(
            children: [
              // Header Info
              Container(
                padding: const EdgeInsets.all(16),
                color: Colors.blue[50],
                child: const Row(
                  children: [
                    Icon(Icons.checklist, color: Colors.blue),
                    Gap(10),
                    Expanded(child: Text("Foto barang satu per satu. Pesanan hanya bisa diselesaikan jika semua barang lolos verifikasi.")),
                  ],
                ),
              ),
              
              // List Barang Checklist
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  separatorBuilder: (_,__) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final productName = item['products']['name'];
                    final imageUrl = item['products']['image_url'];
                    final isVerified = _verificationStatus[index] == true;

                    return Card(
                      elevation: isVerified ? 0 : 2,
                      color: isVerified ? Colors.green[50] : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: isVerified ? const BorderSide(color: Colors.green) : BorderSide.none
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            // Foto Produk (Kecil)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 60, height: 60,
                                color: Colors.grey[200],
                                child: imageUrl != null 
                                  ? Image.network(imageUrl, fit: BoxFit.cover, errorBuilder: (_,__,___)=>const Icon(Icons.image))
                                  : const Icon(Icons.image),
                              ),
                            ),
                            const Gap(16),
                            
                            // Nama Produk & Status
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(productName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                  const Gap(4),
                                  if (isVerified)
                                    const Row(children: [Icon(Icons.check_circle, size: 14, color: Colors.green), Gap(4), Text("Lolos Verifikasi", style: TextStyle(color: Colors.green, fontSize: 12))])
                                  else 
                                    const Text("Belum diperiksa", style: TextStyle(color: Colors.grey, fontSize: 12)),
                                ],
                              ),
                            ),

                            // Tombol Aksi
                            if (!isVerified)
                              ElevatedButton(
                                onPressed: () => _verifyItem(index),
                                style: ElevatedButton.styleFrom(
                                  shape: const CircleBorder(), 
                                  padding: const EdgeInsets.all(12),
                                  backgroundColor: const Color(0xFF0F172A),
                                  foregroundColor: Colors.white
                                ),
                                child: const Icon(Icons.camera_alt),
                              )
                            else
                              const Padding(
                                padding: EdgeInsets.all(12.0),
                                child: Icon(Icons.check_circle, color: Colors.green, size: 32),
                              )
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Bottom Button
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black12, offset: Offset(0, -5))]
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: allVerified ? _completeOrder : null, // Hanya aktif jika semua hijau
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      disabledBackgroundColor: Colors.grey[300],
                    ),
                    child: Text(
                      allVerified ? "SELESAIKAN PESANAN" : "Verifikasi ${items.length - _verificationStatus.length} Barang Lagi",
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            ],
          ),

          // Loading Overlay
          if (_isGlobalLoading)
            Container(
              color: Colors.black54,
              child: const Center(child: CircularProgressIndicator(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}