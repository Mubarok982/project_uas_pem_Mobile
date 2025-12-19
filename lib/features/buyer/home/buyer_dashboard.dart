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

  // Stream Produk: Ambil yang AKTIF saja
  Stream<List<Map<String, dynamic>>> _productsStream() {
    var query = Supabase.instance.client
        .from('products')
        .stream(primaryKey: ['id'])
        .eq('is_active', true) // Hanya barang aktif
        .order('created_at', ascending: false);

    return query;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Container(
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
          ),
          child: TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _searchKeyword = value),
            decoration: const InputDecoration(
              hintText: "Cari beras, minyak...",
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: _productsStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada produk tersedia."));
          }

          // Filter Manual untuk Search (Supabase Stream tidak support ILIKE direct filter dengan mudah di SDK lama)
          final allProducts = snapshot.data!;
          final products = allProducts.where((p) {
            final name = p['name'].toString().toLowerCase();
            return name.contains(_searchKeyword.toLowerCase());
          }).toList();

          if (products.isEmpty) {
            return const Center(child: Text("Produk tidak ditemukan."));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // 2 Kolom
              childAspectRatio: 0.75, // Perbandingan lebar:tinggi kartu
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
            ),
            itemCount: products.length,
            itemBuilder: (context, index) {
              final product = products[index];
              final price = NumberFormat.currency(
                locale: 'id', symbol: 'Rp ', decimalDigits: 0
              ).format(product['price']);

              return GestureDetector(
                onTap: () {
                  // Nanti kita arahkan ke Detail Produk
                   context.push('/buyer/product-detail', extra: product);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Gambar Produk
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                          child: Image.network(
                            product['image_url'] ?? '',
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                          ),
                        ),
                      ),
                      
                      // Info Produk
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product['name'],
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Gap(4),
                            Text(
                              price,
                              style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            const Gap(4),
                            Row(
                              children: [
                                const Icon(Icons.store, size: 12, color: Colors.grey),
                                const Gap(4),
                                Expanded(
                                  child: Text(
                                    "Stok: ${product['stock']}", 
                                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}