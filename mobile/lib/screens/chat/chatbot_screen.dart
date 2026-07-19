import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../api/catalog_service.dart';
import '../../api/chat_service.dart';
import '../../models/product.dart';
import '../../models/product_recommendation.dart';
import '../../models/service_item.dart';
import '../../theme/app_theme.dart';
import '../booking/booking_flow.dart';
import 'booking_chat_screen.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

enum _BotState { awaitingService, awaitingBudget, done }

/// One entry in the chat transcript — either a plain text bubble (bot or
/// user), the row of service chips shown while the bot is waiting for a
/// service pick, a recommended-product card, or the trailing "คุยกับ
/// เจ้าหน้าที่" button.
class _ChatEntry {
  const _ChatEntry.bot(String this.text)
      : kind = _EntryKind.bot,
        services = null,
        recommendation = null,
        service = null;

  const _ChatEntry.user(String this.text)
      : kind = _EntryKind.user,
        services = null,
        recommendation = null,
        service = null;

  const _ChatEntry.serviceChips(List<ServiceItem> this.services)
      : kind = _EntryKind.serviceChips,
        text = null,
        recommendation = null,
        service = null;

  const _ChatEntry.productCard(
    ProductRecommendation this.recommendation,
    ServiceItem this.service,
  )   : kind = _EntryKind.productCard,
        text = null,
        services = null;

  const _ChatEntry.contactButton()
      : kind = _EntryKind.contactButton,
        text = null,
        services = null,
        recommendation = null,
        service = null;

  final _EntryKind kind;
  final String? text;
  final List<ServiceItem>? services;
  final ProductRecommendation? recommendation;
  final ServiceItem? service;
}

enum _EntryKind { bot, user, serviceChips, productCard, contactButton }

/// หน้าแชทบอทแนะนำสินค้า (Task 9, Figma page 15): บอทถาม "สนใจบริการไหนครับ"
/// พร้อมชิปชื่อบริการ → "งบประมาณเท่าไหร่ครับ" → เรียก
/// `POST /api/chatbot/recommend` → การ์ดสินค้าแนะนำพร้อมปุ่ม "จองตัวนี้"
/// (เปิด [BookingFlowScreen] พร้อม service+product ที่แนะนำ) และปุ่ม
/// "คุยกับเจ้าหน้าที่" ท้ายแชท (เปิด [BookingChatScreen] ของการจองล่าสุด
/// ถ้ามี ไม่งั้นแจ้งให้จองก่อน). ช่องพิมพ์ล่างรับข้อความอิสระที่สุดท้าย
/// route ไปตาม state ปัจจุบันของบอท (เลือกบริการ / กรอกงบ / คุยเล่นหลังจบ).
class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<_ChatEntry> _entries = [
    const _ChatEntry.bot('สวัสดีครับ ผมเป็นผู้ช่วยแนะนำบริการของ BKK CAR GLASS & FILM'),
  ];
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<ServiceItem> _services = [];
  ServiceItem? _selectedService;
  _BotState _state = _BotState.awaitingService;
  bool _loadingServices = true;
  bool _requestingRecommend = false;

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadServices() async {
    try {
      final services = await CatalogService.instance.fetchServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _loadingServices = false;
        _entries.add(const _ChatEntry.bot('สนใจบริการไหนครับ'));
        _entries.add(_ChatEntry.serviceChips(services));
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingServices = false;
        _entries.add(_ChatEntry.bot(e.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadingServices = false;
        _entries.add(const _ChatEntry.bot('โหลดรายการบริการไม่สำเร็จ'));
      });
    }
    _scrollToBottom();
  }

  void _onChipTap(ServiceItem service) {
    if (_state != _BotState.awaitingService) return;
    setState(() => _entries.add(_ChatEntry.user(service.name)));
    _chooseService(service);
  }

  void _chooseService(ServiceItem service) {
    setState(() {
      _selectedService = service;
      _state = _BotState.awaitingBudget;
      _entries.add(const _ChatEntry.bot('งบประมาณเท่าไหร่ครับ'));
    });
    _scrollToBottom();
  }

  ServiceItem? _matchServiceByText(String text) {
    final trimmed = text.trim();
    for (final service in _services) {
      if (service.name.contains(trimmed) || trimmed.contains(service.name)) {
        return service;
      }
    }
    return null;
  }

  void _handleSend() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    switch (_state) {
      case _BotState.awaitingService:
        _handleServiceText(text);
        break;
      case _BotState.awaitingBudget:
        _handleBudgetText(text);
        break;
      case _BotState.done:
        setState(() {
          _entries.add(_ChatEntry.user(text));
          _entries.add(
            const _ChatEntry.bot(
              'หากต้องการสอบถามเพิ่มเติม กดปุ่ม "คุยกับเจ้าหน้าที่" ได้เลยครับ',
            ),
          );
        });
        _scrollToBottom();
        break;
    }
  }

  void _handleServiceText(String text) {
    setState(() => _entries.add(_ChatEntry.user(text)));
    final match = _matchServiceByText(text);
    if (match != null) {
      _chooseService(match);
    } else {
      setState(
        () => _entries.add(
          const _ChatEntry.bot('ไม่พบบริการที่ตรงกัน กรุณาเลือกจากรายการด้านบนครับ'),
        ),
      );
      _scrollToBottom();
    }
  }

  Future<void> _handleBudgetText(String text) async {
    setState(() => _entries.add(_ChatEntry.user(text)));
    final budget = double.tryParse(text.replaceAll(',', '').trim());
    if (budget == null || budget <= 0) {
      setState(
        () => _entries.add(const _ChatEntry.bot('กรุณาระบุงบประมาณเป็นตัวเลขครับ')),
      );
      _scrollToBottom();
      return;
    }
    await _requestRecommend(budget);
  }

  Future<void> _requestRecommend(double budget) async {
    final service = _selectedService;
    if (service == null) return;
    setState(() => _requestingRecommend = true);
    _scrollToBottom();
    try {
      final result = await ChatService.instance.recommend(
        serviceId: service.id,
        budget: budget,
      );
      if (!mounted) return;
      setState(() {
        _requestingRecommend = false;
        _state = _BotState.done;
        if (result.recommendations.isEmpty) {
          _entries.add(const _ChatEntry.bot('ขออภัยครับ ไม่พบสินค้าที่เหมาะสมในงบนี้'));
        } else {
          _entries.add(const _ChatEntry.bot('นี่คือสินค้าที่แนะนำครับ'));
          for (final recommendation in result.recommendations) {
            _entries.add(_ChatEntry.productCard(recommendation, service));
          }
        }
        _entries.add(const _ChatEntry.contactButton());
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _requestingRecommend = false;
        _entries.add(_ChatEntry.bot(e.message));
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _requestingRecommend = false;
        _entries.add(const _ChatEntry.bot('เรียกดูคำแนะนำไม่สำเร็จ'));
      });
    }
    _scrollToBottom();
  }

  void _bookProduct(ProductRecommendation recommendation, ServiceItem service) {
    final product = Product(
      id: recommendation.productId,
      serviceId: service.id,
      serviceName: service.name,
      name: recommendation.name,
      brand: recommendation.brand,
      grade: recommendation.grade,
      heatRejectionPct: recommendation.heatRejectionPct,
      uvRejectionPct: recommendation.uvRejectionPct,
      vltPct: recommendation.vltPct,
      price: recommendation.price,
      active: true,
    );
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BookingFlowScreen(
          initialService: service,
          initialProduct: product,
        ),
      ),
    );
  }

  Future<void> _contactStaff() async {
    try {
      final bookings = await BookingService.instance.fetchMine();
      if (!mounted) return;
      if (bookings.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(content: Text('กรุณาจองบริการก่อน')));
        return;
      }
      // The backend already returns bookings newest-first (see
      // BookingService.fetchMine), so the first entry is the latest.
      final latest = bookings.first;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BookingChatScreen(bookingId: latest.id),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('เกิดข้อผิดพลาด')));
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
      appBar: AppBar(title: const Text('แชทบอทแนะนำบริการ')),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: _entries.length + (_requestingRecommend ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _entries.length) {
                    return const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    );
                  }
                  return _buildEntry(_entries[index]);
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEntry(_ChatEntry entry) {
    switch (entry.kind) {
      case _EntryKind.bot:
        return _TextBubble(text: entry.text!, fromUser: false);
      case _EntryKind.user:
        return _TextBubble(text: entry.text!, fromUser: true);
      case _EntryKind.serviceChips:
        return Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: entry.services!
                  .map(
                    (service) => ActionChip(
                      label: Text(service.name),
                      backgroundColor: AppColors.surfaceLight,
                      onPressed: () => _onChipTap(service),
                    ),
                  )
                  .toList(),
            ),
          ),
        );
      case _EntryKind.productCard:
        return _ProductRecommendationCard(
          recommendation: entry.recommendation!,
          service: entry.service!,
          onBook: () => _bookProduct(entry.recommendation!, entry.service!),
        );
      case _EntryKind.contactButton:
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OutlinedButton.icon(
            onPressed: _contactStaff,
            icon: const Icon(Icons.support_agent_outlined),
            label: const Text('คุยกับเจ้าหน้าที่'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryDark,
              side: const BorderSide(color: AppColors.primary),
            ),
          ),
        );
    }
  }

  Widget _buildInputBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: _state == _BotState.awaitingBudget
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
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
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _loadingServices ? null : _handleSend,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.send),
          ),
        ],
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({required this.text, required this.fromUser});

  final String text;
  final bool fromUser;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: fromUser ? AppColors.primary : Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(color: fromUser ? Colors.white : Colors.black87),
        ),
      ),
    );
  }
}

class _ProductRecommendationCard extends StatelessWidget {
  const _ProductRecommendationCard({
    required this.recommendation,
    required this.service,
    required this.onBook,
  });

  final ProductRecommendation recommendation;
  final ServiceItem service;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        width: MediaQuery.of(context).size.width * 0.8,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recommendation.name,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(
              '${_priceFormat.format(recommendation.price)} บาท',
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (recommendation.reason != null &&
                recommendation.reason!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                recommendation.reason!,
                style: const TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ],
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                onPressed: onBook,
                child: const Text('จองตัวนี้'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
