import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SupplierHomePage extends StatelessWidget {
  const SupplierHomePage({super.key});

  // Stream Realtime
  Stream<List<Map<String, dynamic>>> _dashboardStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('supplier_id', userId)
        .order('created_at', ascending: true);
  }

  Future<String> _getShopName() async {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('shop_name')
          .eq('id', userId)
          .single();
      return data['shop_name'] ?? 'Toko Saya';
    } catch (e) {
      return 'Toko Saya';
    }
  }

  // --- LOGIC: CHART ---
  List<FlSpot> _getChartData(List<Map<String, dynamic>> orders) {
    Map<int, double> dailyTotals = {0: 0.0, 1: 0.0, 2: 0.0, 3: 0.0, 4: 0.0, 5: 0.0, 6: 0.0};
    final now = DateTime.now();

    for (var order in orders) {
      if (order['status'] == 'COMPLETED' || order['status'] == 'completed') {
        final createdAt = DateTime.parse(order['created_at']).toLocal();
        final amount = (order['total_amount'] as num).toDouble();
        
        final difference = now.difference(createdAt).inDays;
        
        if (difference >= 0 && difference < 7) {
          final chartIndex = 6 - difference; 
          dailyTotals[chartIndex] = (dailyTotals[chartIndex] ?? 0.0) + amount;
        }
      }
    }

    return List.generate(7, (index) {
      return FlSpot(index.toDouble(), dailyTotals[index]!);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50], 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text("Dashboard", style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Color(0xFF0F172A)),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Color(0xFF0F172A)),
            onPressed: () => context.push('/supplier/profile'),
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _dashboardStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          final allOrders = snapshot.data ?? [];

          // --- 1. HITUNG STATISTIK ---
          final pendingOrders = allOrders.where((o) => ['PAID', 'paid', 'PACKED', 'packed', 'paid_held'].contains(o['status'])).length;
          final completedOrders = allOrders.where((o) => o['status'] == 'COMPLETED' || o['status'] == 'completed');
          
          double totalEarnings = 0.0;
          for (var order in completedOrders) {
            totalEarnings += (order['total_amount'] as num).toDouble();
          }

          double avgOrderValue = 0.0;
          if (completedOrders.isNotEmpty) {
             avgOrderValue = totalEarnings / completedOrders.length.toDouble();
          }

          // --- 2. PERSIAPAN LIST PESANAN TERBARU ---
          // Ambil order yang statusnya BUKAN completed, balik urutan (terbaru di atas), ambil 3 teratas
          final recentOrders = allOrders
              .where((o) => !['COMPLETED', 'completed', 'CANCELLED', 'cancelled'].contains(o['status']))
              .toList()
              .reversed
              .take(3)
              .toList();

          final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER TOKO
                FutureBuilder<String>(
                  future: _getShopName(),
                  builder: (context, shopSnapshot) {
                    return Text(
                      "Halo, ${shopSnapshot.data ?? 'Juragan'} 👋",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.grey),
                    );
                  }
                ),
                const Gap(4),
                Text(currency.format(totalEarnings), style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Text("Total Pendapatan Bersih", style: TextStyle(fontSize: 12, color: Colors.grey)),
                const Gap(24),

                // GRAFIK
                Container(
                  height: 200,
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tren Penjualan (7 Hari)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      const Gap(20),
                      Expanded(
                        child: _SalesChart(dataPoints: _getChartData(allOrders)),
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                // GRID STATISTIK
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  // ✅ FIX: Ratio diperkecil agar kotak lebih tinggi & tidak overflow
                  childAspectRatio: 1.25, 
                  children: [
                    _buildStatCard("Perlu Proses", "$pendingOrders", Icons.inventory_2, Colors.orange),
                    _buildStatCard("Pesanan Selesai", "${completedOrders.length}", Icons.check_circle, Colors.green),
                    _buildStatCard("Rata-rata Order", _formatCompact(avgOrderValue), Icons.analytics, Colors.blue),
                    _buildStatCard("Produk Aktif", "Kelola", Icons.shopping_bag, Colors.purple, onTap: () => context.push('/supplier/add-product')),
                  ],
                ),
                const Gap(24),

                // ORDER TERBARU
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Pesanan Masuk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    // Tombol ini bisa diarahkan ke halaman list order full
                    TextButton(onPressed: (){}, child: const Text("Lihat Semua")),
                  ],
                ),
                
                if (recentOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text("Tidak ada pesanan aktif saat ini.", style: TextStyle(color: Colors.grey))),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentOrders.length,
                    separatorBuilder: (_,__) => const Gap(10),
                    itemBuilder: (context, index) {
                      final order = recentOrders[index];
                      
                      return Container(
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.blue[50],
                            child: const Icon(Icons.local_shipping, color: Colors.blue, size: 20),
                          ),
                          title: Text("Order #${order['id'].toString().substring(0,8)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Text(DateFormat('dd MMM HH:mm').format(DateTime.parse(order['created_at']).toLocal())),
                          trailing: Text(currency.format(order['total_amount']), style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      );
                    },
                  ),
                  
                const Gap(40),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatCompact(double number) {
    return NumberFormat.compactCurrency(locale: 'id', symbol: '', decimalDigits: 0).format(number);
  }

  // ✅ FIX: Update Stat Card agar aman dari Overflow
  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          // Menggunakan spaceBetween agar icon di atas, teks di bawah (mentok)
          mainAxisAlignment: MainAxisAlignment.spaceBetween, 
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // FittedBox: Otomatis mengecilkan font jika angka terlalu panjang
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value, 
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title, 
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SalesChart extends StatelessWidget {
  final List<FlSpot> dataPoints;
  const _SalesChart({required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    // Cek jika tidak ada data sama sekali agar tidak error
    if (dataPoints.isEmpty) return const SizedBox();

    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: false),
        titlesData: const FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 22)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints,
            isCurved: true,
            color: const Color(0xFF0F172A),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF0F172A).withOpacity(0.1),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  NumberFormat.compactCurrency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(spot.y),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}