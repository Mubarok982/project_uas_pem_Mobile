import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:gap/gap.dart';

class SupplierChatListPage extends StatefulWidget {
  const SupplierChatListPage({super.key});

  @override
  State<SupplierChatListPage> createState() => _SupplierChatListPageState();
}

class _SupplierChatListPageState extends State<SupplierChatListPage> {
  final myId = Supabase.instance.client.auth.currentUser!.id;

  // Stream pesan yang melibatkan Supplier ini (sebagai pengirim atau penerima)
  Stream<List<Map<String, dynamic>>> _inboxStream() {
    return Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((data) {
          // Filter hanya pesan milik saya
          return data.where((msg) => 
            msg['sender_id'] == myId || msg['receiver_id'] == myId
          ).toList();
        });
  }

  // Fungsi helper untuk mengambil nama user lain (Pembeli)
  Future<String> _getBuyerName(String userId) async {
    try {
      final data = await Supabase.instance.client
          .from('profiles')
          .select('full_name')
          .eq('id', userId)
          .single();
      return data['full_name'] ?? "User Tanpa Nama";
    } catch (e) {
      return "Pembeli";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pesan Masuk"),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: StreamBuilder(
        stream: _inboxStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final allMessages = snapshot.data ?? [];
          
          if (allMessages.isEmpty) {
            return const Center(child: Text("Belum ada pesan masuk."));
          }

          // --- LOGIKA GROUPING (PENGELOMPOKAN CHAT) ---
          // Kita butuh satu item per Pembeli. Ambil pesan terakhir saja.
          final Map<String, Map<String, dynamic>> conversations = {};

          for (var msg in allMessages) {
            // Tentukan siapa lawan bicaranya
            final otherUserId = (msg['sender_id'] == myId) 
                ? msg['receiver_id'] 
                : msg['sender_id'];

            // Jika belum ada di map, masukkan (karena list urut dari baru, yang pertama masuk adalah pesan terbaru)
            if (!conversations.containsKey(otherUserId)) {
              conversations[otherUserId] = msg;
            }
          }

          final conversationList = conversations.entries.toList();

          return ListView.separated(
            itemCount: conversationList.length,
            separatorBuilder: (_,__) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = conversationList[index];
              final partnerId = entry.key; // ID Pembeli
              final lastMsg = entry.value; // Pesan Terakhir
              final time = DateFormat('dd MMM, HH:mm').format(DateTime.parse(lastMsg['created_at']).toLocal());
              
              // FutureBuilder untuk ambil nama Pembeli tiap baris
              return FutureBuilder<String>(
                future: _getBuyerName(partnerId),
                builder: (context, snapName) {
                  final displayName = snapName.data ?? "Memuat nama...";
                  
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: CircleAvatar(
                      backgroundColor: Colors.blue[50],
                      child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : "?", 
                        style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                    ),
                    title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      lastMsg['content'], 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    trailing: Text(time, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    onTap: () {
                      // Buka Chat Page (Re-use halaman chat yang sama)
                      context.push('/chat', extra: {
                        'partnerId': partnerId, // ID Pembeli
                        'partnerName': displayName, // Nama Pembeli
                      });
                    },
                  );
                }
              );
            },
          );
        },
      ),
    );
  }
}