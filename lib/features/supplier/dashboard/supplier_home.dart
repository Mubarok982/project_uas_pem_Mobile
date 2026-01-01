import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

class SupplierHomePage extends StatelessWidget {
  const SupplierHomePage({super.key});

  // --- STREAM 1: ORDER DATA ---
  Stream<List<Map<String, dynamic>>> _dashboardStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('orders')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true)
        .map((data) {
          // FILTER MANUAL DI SINI (Pengganti .eq)
          return data.where((order) => order['supplier_id'] == userId).toList();
        });
  }

  // --- STREAM 2: PRODUCT DATA ---
  Stream<List<Map<String, dynamic>>> _productStream() {
    final userId = Supabase.instance.client.auth.currentUser!.id;
    return Supabase.instance.client
        .from('products')
        .stream(primaryKey: ['id'])
        .map((data) {
          // FILTER MANUAL DI SINI (Pengganti .eq)
          // Hanya ambil produk milik user INI dan yang statusnya AKTIF
          return data.where((product) => 
            product['supplier_id'] == userId && 
            product['is_active'] == true
          ).toList();
        });
  }

  // --- LOGIC: NAMA TOKO ---
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

  // --- LOGIC: CHART (30 HARI) ---
  List<FlSpot> _getChartData(List<Map<String, dynamic>> orders) {
    List<double> dailyTotals = List.filled(30, 0.0);
    final now = DateTime.now();

    for (var order in orders) {
      if (order['status'] == 'COMPLETED' || order['status'] == 'completed') {
        final createdAt = DateTime.parse(order['created_at']).toLocal();
        final amount = (order['total_amount'] as num).toDouble();
        
        final difference = now.difference(createdAt).inDays;
        
        if (difference >= 0 && difference < 30) {
          final chartIndex = 29 - difference; 
          dailyTotals[chartIndex] += amount;
        }
      }
    }

    return List.generate(30, (index) {
      return FlSpot(index.toDouble(), dailyTotals[index]);
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'id', symbol: 'Rp ', decimalDigits: 0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), 
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          "Dashboard", 
          style: TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w700),
        ),
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

          // --- STATISTIK ORDER ---
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

          // --- RECENT ORDERS ---
          final recentOrders = allOrders
              .where((o) => !['COMPLETED', 'completed', 'CANCELLED', 'cancelled'].contains(o['status']))
              .toList()
              .reversed
              .take(3)
              .toList();

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER TOKO
                FutureBuilder<String>(
                  future: _getShopName(),
                  builder: (context, shopSnapshot) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Halo, ${shopSnapshot.data ?? 'Juragan'} 👋",
                          style: TextStyle(fontSize: 16, color: Colors.grey[600], fontWeight: FontWeight.w500),
                        ),
                        const Gap(4),
                        Text(
                          currency.format(totalEarnings),
                          style: const TextStyle(
                            fontSize: 32, 
                            fontWeight: FontWeight.w800, 
                            color: Color(0xFF0F172A),
                            letterSpacing: -1,
                          ),
                        ),
                        const Text("Total Pendapatan Bersih", style: TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    );
                  }
                ),
                
                const Gap(24),

                // --- CHART ---
                Container(
                  height: 240,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0F172A).withOpacity(0.06),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Tren Penjualan (30 Hari)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      const Gap(20),
                      Expanded(
                        child: _SalesChart(dataPoints: _getChartData(allOrders)),
                      ),
                    ],
                  ),
                ),
                const Gap(24),

                // --- GRID STAT CARDS ---
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.1, 
                  children: [
                    _buildStatCard("Perlu Proses", "$pendingOrders", Icons.inventory_2_rounded, Colors.orange),
                    _buildStatCard("Pesanan Selesai", "${completedOrders.length}", Icons.check_circle_rounded, Colors.green),
                    _buildStatCard("Rata-rata Order", _formatCompact(avgOrderValue), Icons.analytics_rounded, Colors.blue),
                    
                    // --- CARD PRODUK AKTIF (DENGAN STREAM FIX) ---
                    StreamBuilder<List<Map<String, dynamic>>>(
                      stream: _productStream(),
                      builder: (context, productSnap) {
                        final activeCount = productSnap.data?.length ?? 0;
                        return _buildStatCard(
                          "Produk Aktif", 
                          "$activeCount", 
                          Icons.shopping_bag_rounded, 
                          Colors.purple, 
                          onTap: () => context.push('/supplier/add-product')
                        );
                      },
                    ),
                  ],
                ),
                const Gap(30),

                // --- RECENT ORDERS ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Pesanan Masuk", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        context.push('/supplier/orders'); 
                      }, 
                      child: const Text("Lihat Semua")
                    ),
                  ],
                ),
                
                if (recentOrders.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white, 
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100),
                    ),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.inbox_outlined, size: 40, color: Colors.grey[300]),
                          const Gap(8),
                          Text("Belum ada pesanan baru", style: TextStyle(color: Colors.grey[400])),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: recentOrders.length,
                    separatorBuilder: (_,__) => const Gap(12),
                    itemBuilder: (context, index) {
                      final order = recentOrders[index];
                      
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white, 
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(color: Colors.grey.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                          ]
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.local_shipping_rounded, color: Colors.blue, size: 20),
                          ),
                          title: Text("Order #${order['id'].toString().substring(0,8)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Text(DateFormat('dd MMM HH:mm').format(DateTime.parse(order['created_at']).toLocal()), style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                          ),
                          trailing: Text(currency.format(order['total_amount']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
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

  // --- WIDGET CARD BARU
  Widget _buildStatCard(String title, String value, IconData icon, Color color, {VoidCallback? onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withOpacity(0.06),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Icon Besar Pudar
              Positioned(
                right: -5,
                top: -5,
                child: Icon(icon, size: 80, color: color.withOpacity(0.7)),
              ),
              
              Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontSize: 28, 
                        fontWeight: FontWeight.w800, 
                        color: Color(0xFF0F172A),
                        letterSpacing: -1,
                        height: 1.0,
                      ),
                    ),
                  ),
                  const Gap(4),
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// --- WIDGET CHART ---
class _SalesChart extends StatelessWidget {
  final List<FlSpot> dataPoints;
  const _SalesChart({required this.dataPoints});

  @override
  Widget build(BuildContext context) {
    if (dataPoints.isEmpty) return const SizedBox();

    final List<Color> gradientColors = [
      const Color(0xFF0F172A).withOpacity(0.3),
      const Color(0xFF0F172A).withOpacity(0.0),
    ];

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: 1000000, 
          getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 5,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(
                    value.toInt().toString(),
                    style: TextStyle(color: Colors.grey[400], fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 29,
        lineBarsData: [
          LineChartBarData(
            spots: dataPoints,
            isCurved: true,
            curveSmoothness: 0.35,
            color: const Color(0xFF0F172A),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (touchedSpot) => const Color(0xFF0F172A),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((spot) {
                return LineTooltipItem(
                  NumberFormat.compactCurrency(locale: 'id', symbol: 'Rp', decimalDigits: 0).format(spot.y),
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                );
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
        ),
      ),
    );
  }
}