import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/chat_service.dart';
import '../../models/chat_message.dart';
import '../../theme/app_theme.dart';

final DateFormat _timeFormat = DateFormat('HH:mm');

/// หน้าแชทกับเจ้าหน้าที่ของการจองหนึ่งรายการ (Task 9): โหลดประวัติผ่าน
/// `GET /api/chat/bookings/{id}/messages`, ส่งข้อความผ่าน
/// `POST /api/chat/bookings/{id}/messages`, subscribe STOMP เพื่อรับข้อความ
/// ใหม่ realtime (fallback เป็น polling ทุก 5 วิเงียบๆ ถ้าต่อ WS ไม่ได้),
/// และ mark read ตอนเปิดหน้า.
///
/// [socketConnector] is injectable so widget tests can supply a no-op fake
/// instead of ever opening a real socket; production code leaves it null and
/// gets a real [StompChatSocketConnector].
class BookingChatScreen extends StatefulWidget {
  const BookingChatScreen({
    super.key,
    required this.bookingId,
    this.socketConnector,
  });

  final int bookingId;
  final ChatSocketConnector? socketConnector;

  @override
  State<BookingChatScreen> createState() => _BookingChatScreenState();
}

class _BookingChatScreenState extends State<BookingChatScreen> {
  late final ChatSocketConnector _socket =
      widget.socketConnector ?? StompChatSocketConnector();

  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ChatMessage> _messages = [];
  bool _loading = true;
  String? _error;
  bool _sending = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _socket.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final messages = await ChatService.instance.fetchHistory(
        widget.bookingId,
      );
      if (!mounted) return;
      setState(() {
        _messages = messages;
        _loading = false;
      });
      _connectSocket();
      // Best-effort — a failed mark-read isn't worth surfacing an error for.
      unawaited(
        ChatService.instance.markRead(widget.bookingId).catchError((_) {}),
      );
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'โหลดข้อมูลไม่สำเร็จ';
        _loading = false;
      });
    }
  }

  void _connectSocket() {
    _socket.connect(
      bookingId: widget.bookingId,
      onMessage: _handleIncoming,
      onError: _startFallbackPolling,
    );
  }

  void _handleIncoming(ChatMessage message) {
    if (!mounted) return;
    if (_messages.any((m) => m.id == message.id)) return;
    setState(() => _messages = [..._messages, message]);
    _scrollToBottom();
  }

  /// Silent fallback: only kicks in once the socket has reported an error,
  /// and keeps re-fetching the full history every 5s from then on.
  void _startFallbackPolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  Future<void> _poll() async {
    try {
      final messages = await ChatService.instance.fetchHistory(
        widget.bookingId,
      );
      if (!mounted) return;
      setState(() => _messages = messages);
    } catch (_) {
      // Silent by design — this is a background fallback, not a
      // user-initiated action.
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    _controller.clear();
    try {
      final message = await ChatService.instance.sendMessage(
        widget.bookingId,
        text,
      );
      if (!mounted) return;
      setState(() {
        if (!_messages.any((m) => m.id == message.id)) {
          _messages = [..._messages, message];
        }
        _sending = false;
      });
      _scrollToBottom();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('ส่งข้อความไม่สำเร็จ')));
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แชทกับเจ้าหน้าที่')),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 96),
            Center(
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );
    }
    return Column(
      children: [
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'ยังไม่มีข้อความ',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) =>
                      _ChatBubble(message: _messages[index]),
                ),
        ),
        _buildInputBar(),
      ],
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความที่นี่',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isCustomer = message.isFromCustomer;
    return Align(
      // Distinct key per side so tests can unambiguously assert alignment
      // for a customer vs. admin/bot message.
      key: ValueKey(
        isCustomer ? 'customer_msg_${message.id}' : 'staff_msg_${message.id}',
      ),
      alignment: isCustomer ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isCustomer ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isCustomer && message.senderName != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  message.senderName!,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ),
            Text(
              message.message,
              style: TextStyle(
                color: isCustomer ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              _timeFormat.format(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isCustomer ? Colors.white70 : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
