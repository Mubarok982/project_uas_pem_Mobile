import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class BuyerHomePage extends StatefulWidget {
  const BuyerHomePage({super.key});

  @override
  State<BuyerHomePage> createState() => _BuyerHomePageState();
}

class _BuyerHomePageState extends State<BuyerHomePage> {
  final _searchController = TextEditingController();
  String _searchKeyword = "";

  // Helper Format Rupiah
  String _formatCurrency(dynamic value) {
    return NumberFormat.currency(
      locale: 'id', symbol: 'Rp ', decimalDigits: 0
    ).format(value ?? 0);
  }

  // Stream Saldo & Nama User (Realtime update kalau saldo nambah)
  Stream<Map<String, dynamic>> _userProfileStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .eq('id', userId)
        .map((data) => data.first);
  }

  // Stream Produk Aktif
  Stream<List<Map<String, dynamic>>> _productsStream() {
    return Supabase.instance.client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('is_active', true)
        .order('created_at', ascending: false);
  }

  // Fitur Top Up Sederhana (Simulasi)
  void _showTopUpDialog() {
    final amountController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Top Up Saldo"),
        content: TextField(
          controller: amountController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: "Nominal",
            hintText: "Contoh: 50000",
            prefixText: "Rp ",
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Batal")),
          ElevatedButton(
            onPressed: () async {
              final amount = int.tryParse(amountController.text) ?? 0;
              if (amount > 0) {
                Navigator.pop(ctx);
                final userId = Supabase.instance.client.auth.currentUser!.id;
                
                // Ambil saldo lama dulu (cara cepat, idealnya pakai RPC function di postgres)
                final profile = await Supabase.instance.client.from('profiles').select('balance').eq('id', userId).single();
                final currentBalance = profile['balance'] ?? 0;

                // Update saldo
                await Supabase.instance.client.from('profiles').update({
                  'balance': currentBalance + amount
                }).eq('id', userId);

                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Top Up Berhasil!")));
              }
            },
            child: const Text("Top Up Sekarang"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Kita pakai CustomScrollView biar Header + Grid bisa discroll barengan dengan mulus
    return Scaffold(
      backgroundColor: Colors.grey[100], // Background sedikit abu biar konten pop-up
      body: CustomScrollView(
        slivers: [
          // 1. HEADER (Logo, Search, Wallet)
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none, // Biarkan kartu wallet keluar dari container biru
              children: [
                // Background Biru Gelap
                Container(
                  padding: const EdgeInsets.only(top: 50, left: 20, right: 20, bottom: 80),
                  decoration: const BoxDecoration(
                    color: Color(0xFF0F172A),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(24),
                      bottomRight: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Baris Atas: Sapaan & Cart Icon
                      StreamBuilder(
                        stream: _userProfileStream(),
                        builder: (context, snapshot) {
                          final name = snapshot.data?['full_name'] ?? 'Pelanggan';
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Selamat Datang,", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                  Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              IconButton(
                                onPressed: () {
                                  // Navigasi ke Keranjang (kalau ada logic routingnya)
                                  // context.push('/cart'); 
                                },
                                icon: const Icon(Icons.shopping_cart_outlined, color: Colors.white),
                              )
                            ],
                          );
                        }
                      ),
                      const Gap(16),
                      
                      // Search Bar
                      Container(
                        height: 45,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _searchKeyword = value),
                          decoration: const InputDecoration(
                            hintText: "Mau cari beras atau minyak?",
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 14),
                            prefixIcon: Icon(Icons.search, color: Colors.grey),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 11),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Kartu Wallet (Mengambang/Overlapping)
                Positioned(
                  bottom: -40,
                  left: 20,
                  right: 20,
                  child: StreamBuilder(
                    stream: _userProfileStream(),
                    builder: (context, snapshot) {
                      final balance = snapshot.data?['balance'] ?? 0;
                      
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blue[50],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.account_balance_wallet, color: Color(0xFF0F172A)),
                            ),
                            const Gap(12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("Saldo Veriaga", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  Text(_formatCurrency(balance), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ],
                              ),
                            ),
                            ElevatedButton(
                              onPressed: _showTopUpDialog,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0F172A),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                                minimumSize: const Size(0, 36)
                              ),
                              child: const Text("Top Up", style: TextStyle(fontSize: 12, color: Colors.white)),
                            )
                          ],
                        ),
                      );
                    }
                  ),
                ),
              ],
            ),
          ),

          // Spacer karena ada kartu wallet yang overlap ke bawah
          const SliverToBoxAdapter(child: SizedBox(height: 50)),

          // Judul Seksi
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Text("Rekomendasi Produk", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),

          // 2. GRID PRODUK (Pakai StreamBuilder di dalam Sliver)
          StreamBuilder(
            stream: _productsStream(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())));
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Produk kosong"))));
              }

              final allProducts = snapshot.data!;
              final products = allProducts.where((p) {
                final name = p['name'].toString().toLowerCase();
                return name.contains(_searchKeyword.toLowerCase());
              }).toList();

              if (products.isEmpty) {
                 return const SliverToBoxAdapter(child: Center(child: Padding(padding: EdgeInsets.all(20), child: Text("Tidak ditemukan"))));
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.7, // Card agak tinggi biar muat tombol
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final product = products[index];
                      return _buildProductCard(product);
                    },
                    childCount: products.length,
                  ),
                ),
              );
            },
          ),
          
          // Spacer bawah biar gak mentok
          const SliverToBoxAdapter(child: SizedBox(height: 20)),
        ],
      ),
    );
  }

  // WIDGET KARTU PRODUK YANG LEBIH CANTIK
  Widget _buildProductCard(Map<String, dynamic> product) {
    return GestureDetector(
      onTap: () => context.push('/buyer/product-detail', extra: product),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 5, spreadRadius: 1)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Gambar
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                    child: Image.network(
                      product['image_url'] ?? '',
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_,__,___) => Container(color: Colors.grey[200], child: const Icon(Icons.image)),
                    ),
                  ),
                  // Badge Stok (Opsional)
                  if ((product['stock'] as int) < 5)
                  Positioned(
                    top: 8, right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.red.withOpacity(0.9), borderRadius: BorderRadius.circular(4)),
                      child: const Text("Stok Menipis", style: TextStyle(color: Colors.white, fontSize: 9)),
                    ),
                  )
                ],
              ),
            ),
            
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product['name'],
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const Gap(4),
                  Text(
                    _formatCurrency(product['price']),
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  const Gap(8),
                  // Tombol 'Beli' Kecil
                  SizedBox(
                    width: double.infinity,
                    height: 30,
                    child: OutlinedButton(
                      onPressed: () => context.push('/buyer/product-detail', extra: product),
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: Color(0xFF0F172A)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6))
                      ),
                      child: const Text("Lihat", style: TextStyle(fontSize: 12, color: Color(0xFF0F172A))),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}