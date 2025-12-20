import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';

class ChatPage extends StatefulWidget {
  final String partnerId; // ID Lawan Bicara (Supplier/Buyer)
  final String? partnerName; // Nama Lawan Bicara (Opsional)
  final String? initialMessage; // Pesan awalan (misal ID Order)

  const ChatPage({
    super.key, 
    required this.partnerId, 
    this.partnerName,
    this.initialMessage
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final myId = Supabase.instance.client.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    // Jika ada pesan awalan (misal dari copy ID), langsung masukkan ke textfield
    if (widget.initialMessage != null) {
      _messageController.text = widget.initialMessage!;
    }
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    try {
      await Supabase.instance.client.from('chat_messages').insert({
        'sender_id': myId,
        'receiver_id': widget.partnerId,
        'content': text,
      });
      // Scroll ke bawah setelah kirim
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal kirim: $e")));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0, // Karena kita pakai reverse: true di ListView
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOut
      );
    }
  }

  Stream<List<Map<String, dynamic>>> _chatStream() {
    return Supabase.instance.client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false) // Paling baru di atas (karena reverse list)
        .map((data) => data.where((msg) => 
            (msg['sender_id'] == myId && msg['receiver_id'] == widget.partnerId) ||
            (msg['sender_id'] == widget.partnerId && msg['receiver_id'] == myId)
        ).toList());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.partnerName ?? "Chat", style: const TextStyle(fontSize: 16)),
            const Text("Online", style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder(
              stream: _chatStream(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text("Belum ada pesan. Sapa penjual sekarang!"));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true, // Chat mulai dari bawah
                  itemCount: messages.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isMe = msg['sender_id'] == myId;
                    final time = DateFormat('HH:mm').format(DateTime.parse(msg['created_at']).toLocal());

                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                        decoration: BoxDecoration(
                          color: isMe ? const Color(0xFF0F172A) : Colors.grey[200],
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(12),
                            topRight: const Radius.circular(12),
                            bottomLeft: isMe ? const Radius.circular(12) : Radius.zero,
                            bottomRight: isMe ? Radius.zero : const Radius.circular(12),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              msg['content'],
                              style: TextStyle(color: isMe ? Colors.white : Colors.black87),
                            ),
                            const Gap(4),
                            Text(
                              time,
                              style: TextStyle(fontSize: 10, color: isMe ? Colors.white70 : Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          
          // Input Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, -5))]
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: "Tulis pesan...",
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                    ),
                  ),
                ),
                const Gap(8),
                CircleAvatar(
                  backgroundColor: const Color(0xFF0F172A),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 20),
                    onPressed: _sendMessage,
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}