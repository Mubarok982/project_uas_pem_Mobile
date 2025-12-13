import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class SupplierDisputePage extends StatefulWidget {
  final String orderId;
  const SupplierDisputePage({super.key, required this.orderId});

  @override
  State<SupplierDisputePage> createState() => _SupplierDisputePageState();
}

class _SupplierDisputePageState extends State<SupplierDisputePage> {
  bool _isLoading = false;

  // Ambil Data Dispute dari Database
  Future<Map<String, dynamic>> _fetchDisputeDetail() async {
    final supabase = Supabase.instance.client;
    
    // 1. Ambil data Dispute berdasarkan Order ID
    final disputeData = await supabase
        .from('disputes')
        .select()
        .eq('order_id', widget.orderId)
        .single(); // Asumsi 1 Order punya 1 Dispute aktif

    return disputeData;
  }

  // Opsi 1: Terima Komplain (Refund Buyer)
  Future<void> _acceptRefund() async {
    setState(() => _isLoading = true);
    final supabase = Supabase.instance.client;

    try {
      // A. Update Status Order jadi CANCELLED (Batal)
      await supabase.from('orders').update({'status': 'CANCELLED'}).eq('id', widget.orderId);

      // B. Update Transaksi jadi REFUNDED (Uang balik ke Buyer)
      // Di real app, ini trigger API Midtrans Refund. Disini kita update DB saja.
      await supabase.from('transactions')
          .update({'status': 'refunded'})
          .eq('order_id', widget.orderId);

      // C. Update Dispute jadi RESOLVED
      await supabase.from('disputes')
          .update({'status': 'RESOLVED_REFUND'})
          .eq('order_id', widget.orderId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Refund disetujui. Dana dikembalikan ke Buyer.")));
        context.pop();
      }
    } catch (e) {
      // Error handling
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Opsi 2: Tolak Komplain (Minta Admin Cek / Banding)
  Future<void> _rejectDispute() async {
    // Logika mirip di atas, tapi status dispute jadi 'RESOLVED_APPEAL'
    // Dan status order tetap 'DISPUTED' sampai Admin turun tangan.
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Banding diajukan ke Admin Salaman Apps.")));
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Resolusi Masalah")),
      body: FutureBuilder(
        future: _fetchDisputeDetail(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          
          if (snapshot.hasError) {
             return const Center(child: Text("Data komplain tidak ditemukan."));
          }

          final dispute = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Peringatan
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red[200]!)),
                  child: const Row(
                    children: [
                      Icon(Icons.report_problem, color: Colors.red),
                      SizedBox(width: 12),
                      Expanded(child: Text("Dana transaksi ini DITAHAN sementara karena ada laporan dari Pembeli.", style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ),
                const Gap(24),

                const Text("Alasan Komplain:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Gap(8),
                Text(dispute['reason'] ?? "-", style: const TextStyle(fontSize: 16)),
                const Gap(24),

                const Text("Bukti Foto:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const Gap(12),
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(12)),
                  child: dispute['proof_image_url'] != null
                      ? Image.network(dispute['proof_image_url'], fit: BoxFit.cover)
                      : const Center(child: Text("Tidak ada foto")),
                ),
                const Gap(40),

                // Tombol Keputusan
                const Text("Keputusan Anda:", style: TextStyle(fontWeight: FontWeight.bold)),
                const Gap(12),
                
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _rejectDispute,
                        style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                        child: const Text("Tolak & Banding"),
                      ),
                    ),
                    const Gap(16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _acceptRefund,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("Refund Dana"),
                      ),
                    ),
                  ],
                ),
                const Gap(12),
                const Text(
                  "Pilih 'Refund Dana' jika kesalahan memang dari pihak toko. Uang akan dikembalikan 100% ke Pembeli.",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}