import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/booking_service.dart';
import '../../api/catalog_service.dart';
import '../../api/chat_service.dart';
import '../../models/install_area.dart';
import '../../models/product.dart';
import '../../models/product_recommendation.dart';
import '../../models/service_item.dart';
import '../../theme/app_theme.dart';
import '../booking/booking_flow.dart';
import 'booking_chat_screen.dart';

final NumberFormat _priceFormat = NumberFormat('#,###');

const _chatBackground = Color(0xFFF7F4F4);
const _bubbleBorder = Color(0xFFEDE4E4);

enum _BotState { awaitingService, awaitingArea, awaitingBudget, done }

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

  const _ChatEntry.areaChips()
      : kind = _EntryKind.areaChips,
        text = null,
        services = null,
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

enum _EntryKind {
  bot,
  user,
  serviceChips,
  areaChips,
  productCard,
  contactButton,
}

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
  String? _selectedInstallArea;
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

  bool _isFilmService(ServiceItem service) => service.name.contains('ฟิล์ม');

  void _onChipTap(ServiceItem service) {
    if (_state != _BotState.awaitingService) return;
    setState(() => _entries.add(_ChatEntry.user(service.name)));
    _chooseService(service);
  }

  void _chooseService(ServiceItem service) {
    setState(() {
      _selectedService = service;
      _selectedInstallArea = null;
      if (_isFilmService(service)) {
        _state = _BotState.awaitingArea;
        _entries.add(const _ChatEntry.bot('ต้องการติดฟิล์มบริเวณไหนครับ'));
        _entries.add(const _ChatEntry.areaChips());
      } else {
        _state = _BotState.awaitingBudget;
        _entries.add(const _ChatEntry.bot('งบประมาณเท่าไหร่ครับ'));
      }
    });
    _scrollToBottom();
  }

  void _onAreaChipTap(InstallAreaOption option) {
    if (_state != _BotState.awaitingArea) return;
    setState(() => _entries.add(_ChatEntry.user(option.label)));
    _chooseArea(option.value);
  }

  void _chooseArea(String value) {
    setState(() {
      _selectedInstallArea = value;
      _state = _BotState.awaitingBudget;
      _entries.add(const _ChatEntry.bot('งบประมาณเท่าไหร่ครับ'));
    });
    _scrollToBottom();
  }

  InstallAreaOption? _matchAreaByText(String text) {
    final trimmed = text.trim();
    for (final option in installAreaOptions) {
      if (option.label.contains(trimmed) || trimmed.contains(option.label)) {
        return option;
      }
    }
    return null;
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
      case _BotState.awaitingArea:
        _handleAreaText(text);
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

  void _handleAreaText(String text) {
    setState(() => _entries.add(_ChatEntry.user(text)));
    final match = _matchAreaByText(text);
    if (match != null) {
      _chooseArea(match.value);
    } else {
      setState(
        () => _entries.add(
          const _ChatEntry.bot('ไม่พบบริเวณที่ตรงกัน กรุณาเลือกจากตัวเลือกด้านบนครับ'),
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
          initialInstallArea: _isFilmService(service) ? _selectedInstallArea : null,
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
      backgroundColor: _chatBackground,
      appBar: _buildAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                itemCount: _entries.length + (_requestingRecommend ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index >= _entries.length) return const _TypingBubble();
                  return _buildEntry(_entries[index], index);
                },
              ),
            ),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      titleSpacing: 0,
      title: Row(
        children: [
          const _BotAvatar(size: 38),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'แชทบอทแนะนำบริการ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF22C55E),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'พร้อมแนะนำสินค้าให้คุณ',
                    style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _bubbleBorder),
      ),
    );
  }

  /// บอทเริ่มพูดต่อกันหลายฟองได้ แสดงรูปโปรไฟล์เฉพาะฟองแรกของชุด
  /// ที่เหลือเว้นที่ไว้เท่ากัน จะได้เรียงตรงกันโดยไม่รกตา
  bool _showsAvatar(int index) {
    if (index == 0) return true;
    return _entries[index - 1].kind != _EntryKind.bot;
  }

  Widget _buildEntry(_ChatEntry entry, int index) {
    switch (entry.kind) {
      case _EntryKind.bot:
        return _TextBubble(
          text: entry.text!,
          fromUser: false,
          showAvatar: _showsAvatar(index),
        );
      case _EntryKind.user:
        return _TextBubble(text: entry.text!, fromUser: true, showAvatar: false);
      case _EntryKind.serviceChips:
        return _ChipRow(
          // ชิปที่เลยขั้นตอนไปแล้วกดไม่ได้ ทำให้ดูจางลงด้วย ไม่งั้นกดแล้ว
          // เงียบหายเหมือนแอปค้าง
          enabled: _state == _BotState.awaitingService,
          children: entry.services!
              .map(
                (service) => _SuggestionChip(
                  label: service.name,
                  icon: _serviceIcon(service.name),
                  enabled: _state == _BotState.awaitingService,
                  onTap: () => _onChipTap(service),
                ),
              )
              .toList(),
        );
      case _EntryKind.areaChips:
        return _ChipRow(
          enabled: _state == _BotState.awaitingArea,
          children: installAreaOptions
              .map(
                (option) => _SuggestionChip(
                  label: option.label,
                  enabled: _state == _BotState.awaitingArea,
                  onTap: () => _onAreaChipTap(option),
                ),
              )
              .toList(),
        );
      case _EntryKind.productCard:
        return _ProductRecommendationCard(
          recommendation: entry.recommendation!,
          service: entry.service!,
          onBook: () => _bookProduct(entry.recommendation!, entry.service!),
        );
      case _EntryKind.contactButton:
        return Padding(
          padding: const EdgeInsets.fromLTRB(44, 10, 0, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _contactStaff,
              icon: const Icon(Icons.support_agent_outlined, size: 19),
              label: const Text('คุยกับเจ้าหน้าที่'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                backgroundColor: Colors.white,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                shape: const StadiumBorder(),
              ),
            ),
          ),
        );
    }
  }

  static IconData _serviceIcon(String name) {
    if (name.contains('ฟิล์ม')) return Icons.wb_sunny_outlined;
    if (name.contains('ล้าง')) return Icons.local_car_wash_outlined;
    if (name.contains('กระจก') || name.contains('ร้าว')) return Icons.handyman_outlined;
    return Icons.directions_car_outlined;
  }

  Widget _buildInputBar() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _bubbleBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              keyboardType: _state == _BotState.awaitingBudget
                  ? const TextInputType.numberWithOptions(decimal: true)
                  : TextInputType.text,
              decoration: InputDecoration(
                hintText: _state == _BotState.awaitingBudget
                    ? 'ระบุงบประมาณ เช่น 5000'
                    : 'พิมพ์ข้อความที่นี่',
                hintStyle: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                filled: true,
                fillColor: _chatBackground,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: _bubbleBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
                ),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
            ),
          ),
          const SizedBox(width: 10),
          _SendButton(onPressed: _loadingServices ? null : _handleSend),
        ],
      ),
    );
  }
}

/// รูปแทนตัวบอท ใช้ทั้งบน AppBar และหน้าฟองข้อความ
class _BotAvatar extends StatelessWidget {
  const _BotAvatar({this.size = 30});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primary, AppColors.primaryDarker],
        ),
      ),
      child: Icon(Icons.smart_toy_outlined, size: size * 0.55, color: Colors.white),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              )
            : null,
        color: enabled ? null : Colors.grey.shade300,
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.32),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: IconButton(
        onPressed: onPressed,
        color: Colors.white,
        disabledColor: Colors.white,
        icon: const Icon(Icons.send, size: 20),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children, required this.enabled});

  final List<Widget> children;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // เยื้องให้ตรงกับฟองข้อความของบอทที่มีรูปโปรไฟล์อยู่ข้างหน้า
      padding: const EdgeInsets.fromLTRB(44, 6, 0, 6),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: enabled ? 1 : 0.45,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Wrap(spacing: 8, runSpacing: 8, children: children),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({
    required this.label,
    required this.enabled,
    required this.onTap,
    this.icon,
  });

  final String label;
  final IconData? icon;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: StadiumBorder(
        side: BorderSide(
          color: enabled ? AppColors.primary.withValues(alpha: 0.45) : _bubbleBorder,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: AppColors.primaryDark),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextBubble extends StatelessWidget {
  const _TextBubble({
    required this.text,
    required this.fromUser,
    required this.showAvatar,
  });

  final String text;
  final bool fromUser;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: fromUser ? null : Colors.white,
        gradient: fromUser
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDark],
              )
            : null,
        border: fromUser ? null : Border.all(color: _bubbleBorder),
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(fromUser ? 18 : 6),
          bottomRight: Radius.circular(fromUser ? 6 : 18),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: fromUser ? 0.10 : 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: fromUser ? Colors.white : const Color(0xFF2B2B2B),
          fontSize: 14.5,
          height: 1.4,
        ),
      ),
    );

    if (fromUser) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: 36,
            child: showAvatar
                ? const Align(
                    alignment: Alignment.centerLeft,
                    child: _BotAvatar(),
                  )
                : null,
          ),
          Flexible(child: bubble),
        ],
      ),
    );
  }
}

/// จุดสามจุดกระพริบระหว่างรอคำแนะนำ แทน spinner เปล่าๆ เพื่อให้รู้สึกว่า
/// "บอทกำลังพิมพ์" เหมือนแชทที่ผู้ใช้คุ้นเคย
class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          const SizedBox(
            width: 36,
            child: Align(alignment: Alignment.centerLeft, child: _BotAvatar()),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: _bubbleBorder),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(6),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  // เลื่อนเฟสของแต่ละจุดให้ไล่กันเป็นคลื่น
                  final t = (_controller.value - i * 0.18) % 1.0;
                  final lift = t < 0.5 ? (0.5 - t) * 2 : (t - 0.5) * 2;
                  return Padding(
                    padding: EdgeInsets.only(right: i == 2 ? 0 : 6),
                    child: Opacity(
                      opacity: 0.35 + 0.65 * lift,
                      child: Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
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
    final subtitle = [recommendation.brand, recommendation.grade]
        .where((v) => v != null && v.isNotEmpty)
        .join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(44, 6, 0, 6),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.78,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _bubbleBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(17),
                    topRight: Radius.circular(17),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.auto_awesome,
                        size: 15, color: AppColors.primaryDark),
                    const SizedBox(width: 6),
                    Text(
                      'แนะนำสำหรับคุณ',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark.withValues(alpha: 0.9),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recommendation.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15.5,
                        height: 1.3,
                      ),
                    ),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          _priceFormat.format(recommendation.price),
                          style: const TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 24,
                            height: 1,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'บาท',
                          style: TextStyle(
                            color: AppColors.primaryDark,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    if (_specs.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(spacing: 6, runSpacing: 6, children: _specs),
                    ],
                    if (recommendation.reason != null &&
                        recommendation.reason!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF8E6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.lightbulb_outline,
                                size: 15, color: Color(0xFFB7791F)),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                recommendation.reason!,
                                style: const TextStyle(
                                  fontSize: 12.5,
                                  height: 1.45,
                                  color: Color(0xFF7A5A14),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          minimumSize: const Size.fromHeight(46),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: onBook,
                        child: const Text('จองตัวนี้'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// สเปคฟิล์มที่มีค่าเท่านั้น — สินค้าอย่างแพ็กเกจล้างรถไม่มีสเปคพวกนี้
  /// ถ้าแสดงช่องว่างไว้จะดูเหมือนข้อมูลหาย
  List<Widget> get _specs => [
        if (recommendation.heatRejectionPct != null)
          _SpecPill(
            icon: Icons.thermostat,
            label: 'กันร้อน ${recommendation.heatRejectionPct}%',
          ),
        if (recommendation.uvRejectionPct != null)
          _SpecPill(
            icon: Icons.shield_outlined,
            label: 'กัน UV ${recommendation.uvRejectionPct}%',
          ),
        if (recommendation.vltPct != null)
          _SpecPill(
            icon: Icons.opacity,
            label: 'ความเข้ม ${recommendation.vltPct}%',
          ),
      ];
}

class _SpecPill extends StatelessWidget {
  const _SpecPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: _chatBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey.shade700),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade800),
          ),
        ],
      ),
    );
  }
}
