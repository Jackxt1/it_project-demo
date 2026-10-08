import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/catalog_service.dart';
import '../../models/product.dart';
import '../../models/service_item.dart';
import '../../theme/app_theme.dart';
import '../../widgets/bot_mark.dart';
import '../../widgets/product_thumbnail.dart';
import '../chat/chatbot_screen.dart';

const String _comingSoonMessage = 'เร็วๆ นี้';

final NumberFormat _priceFormat = NumberFormat('#,###');

class _QuickAction {
  const _QuickAction(this.label, this.icon, {required this.matchKeyword});

  final String label;
  final IconData icon;

  /// Keyword used to find the matching [ServiceItem] by substring — e.g.
  /// "ฟิล์ม" matches a backend service named "ติดฟิล์มกรองแสงรถยนต์" or just
  /// "ติดฟิล์ม" regardless of how admins phrased the full name.
  final String matchKeyword;
}

const List<_QuickAction> _quickActions = [
  _QuickAction('ติดฟิล์มรถ', Icons.tonality, matchKeyword: 'ฟิล์ม'),
  _QuickAction('ซ่อมกระจก', Icons.car_repair, matchKeyword: 'ซ่อม'),
  _QuickAction('ล้างรถ', Icons.local_car_wash, matchKeyword: 'ล้าง'),
];

/// หน้าแรก (Home) ตาม Figma page 7.
///
/// แสดงโลโก้ร้าน, ปุ่มจองบริการ/ติดตามสถานะ, ช่องค้นหาที่กรอง "บริการยอดนิยม",
/// แบนเนอร์, การ์ด "บริการด่วน" 3 ใบ และ grid สินค้ายอดนิยมจาก [CatalogService.instance].
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onBookService,
    this.onBookProduct,
    this.onTrackStatus,
    this.onOpenNotifications,
    this.unreadNotificationCount = 0,
  });

  /// เรียกเมื่อผู้ใช้กด "จองบริการ", แบนเนอร์ "จองเลย" หรือการ์ด
  /// "บริการด่วน" — ส่ง [ServiceItem] ที่ match จากชื่อบริการ หรือ
  /// null เมื่อไม่ได้ระบุบริการเจาะจง (Task 4 จะผูกไป flow จองจริง).
  final void Function(ServiceItem?)? onBookService;

  /// เรียกเมื่อผู้ใช้แตะการ์ดสินค้าใน "บริการยอดนิยม" — ส่งทั้งบริการที่
  /// สินค้านั้นสังกัด (match จาก [Product.serviceId]) และตัวสินค้าเอง เพื่อ
  /// ข้ามหน้าเลือกสินค้าใน step 2 ไปเลย (พรีเซ็ตฟิล์ม/แพ็กเกจที่กดมา).
  final void Function(ServiceItem service, Product product)? onBookProduct;

  /// เรียกเมื่อผู้ใช้กด "ติดตามสถานะ" — ปกติ MainShell จะสลับไปแท็บการจอง.
  final VoidCallback? onTrackStatus;

  /// เรียกเมื่อผู้ใช้แตะไอคอนกระดิ่งแจ้งเตือน — ปกติ MainShell จะเปิดหน้า
  /// แจ้งเตือนแบบ push (ไม่ใช่แท็บล่างอีกต่อไป).
  final VoidCallback? onOpenNotifications;

  /// จำนวนแจ้งเตือนที่ยังไม่อ่าน แสดงเป็น badge บนไอคอนกระดิ่ง.
  final int unreadNotificationCount;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ServiceItem> _services = [];
  List<Product> _products = [];
  bool _loading = true;
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        CatalogService.instance.fetchServices(),
        CatalogService.instance.fetchProducts(),
      ]);
      if (!mounted) return;
      setState(() {
        _services = results[0] as List<ServiceItem>;
        _products = results[1] as List<Product>;
        _loading = false;
      });
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

  void _showComingSoon() {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(_comingSoonMessage)));
  }

  void _openChatbot() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const ChatbotScreen()));
  }

  /// จับคู่คีย์เวิร์ดของการ์ด "บริการด่วน" (เช่น "ฟิล์ม") กับบริการจริงจาก
  /// backend โดยดูว่าชื่อบริการมีคีย์เวิร์ดเป็น substring หรือไม่ — ทนทาน
  /// ต่อชื่อเต็มที่แอดมินตั้งไว้ต่างกัน (เช่น "ติดฟิล์มกรองแสงรถยนต์").
  ServiceItem? _matchService(String keyword) {
    for (final service in _services) {
      if (service.name.contains(keyword)) {
        return service;
      }
    }
    return null;
  }

  void _handleQuickAction(_QuickAction action) {
    widget.onBookService?.call(_matchService(action.matchKeyword));
  }

  void _handleProductTap(Product product) {
    for (final service in _services) {
      if (service.id == product.serviceId) {
        widget.onBookProduct?.call(service, product);
        return;
      }
    }
  }

  /// "สินค้ายอดนิยม" แสดงเฉพาะฟิล์ม (ไม่รวมแพ็กเกจล้างรถ ฯลฯ) — match จาก
  /// [Product.serviceId] ของบริการที่ชื่อมีคำว่า "ฟิล์ม" เหมือน [_matchService].
  List<Product> get _filmProducts {
    final filmService = _matchService('ฟิล์ม');
    if (filmService == null) return const [];
    return _products.where((p) => p.serviceId == filmService.id).toList();
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final films = _filmProducts;
    if (query.isEmpty) return films;
    return films.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final products = _filteredProducts;

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _TopBar(
                        onNotificationsTap:
                            widget.onOpenNotifications ?? _showComingSoon,
                        onProfileTap: _showComingSoon,
                        unreadNotificationCount: widget.unreadNotificationCount,
                      ),
                      const SizedBox(height: 16),
                      _ActionButtons(
                        onBookService: () => widget.onBookService?.call(null),
                        onTrackStatus: widget.onTrackStatus ?? _showComingSoon,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 16),
                      const _PromoCarousel(),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'บริการด่วน',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickActionsRow(onTap: _handleQuickAction),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'สินค้ายอดนิยม',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          TextButton(
                            onPressed: _showComingSoon,
                            child: const Text('ดูทั้งหมด'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                )
              else if (_error != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text(_error!)),
                  ),
                )
              else if (products.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(child: Text('ไม่พบบริการ')),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.78,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _ProductCard(
                        product: products[index],
                        onTap: () => _handleProductTap(products[index]),
                      ),
                      childCount: products.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          // ไล่สีกับเงาให้ปุ่มลอยเด่นขึ้นมาจากพื้นหลัง และใช้เครื่องหมายเดียว
          // กับรูปโปรไฟล์บอทในหน้าแชท ปุ่มที่กดกับตัวที่คุยด้วยจะได้เป็นสิ่งเดียวกัน
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.primary, AppColors.primaryDarker],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              heroTag: 'home_chat_fab',
              backgroundColor: Colors.transparent,
              elevation: 0,
              focusElevation: 0,
              hoverElevation: 0,
              highlightElevation: 0,
              shape: const CircleBorder(),
              onPressed: _openChatbot,
              tooltip: 'ผู้ช่วยแนะนำบริการ',
              child: const BotMark(size: 25),
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onNotificationsTap,
    required this.onProfileTap,
    this.unreadNotificationCount = 0,
  });

  final VoidCallback onNotificationsTap;
  final VoidCallback onProfileTap;
  final int unreadNotificationCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'assets/image/red_logo_cropped.png',
              height: 40,
              fit: BoxFit.contain,
            ),
          ),
        ),
        IconButton(
          onPressed: onNotificationsTap,
          icon: Badge(
            label: Text('$unreadNotificationCount'),
            isLabelVisible: unreadNotificationCount > 0,
            backgroundColor: AppColors.primary,
            textColor: Colors.white,
            child: const Icon(Icons.notifications_none),
          ),
        ),
        InkWell(
          onTap: onProfileTap,
          customBorder: const CircleBorder(),
          child: const CircleAvatar(
            backgroundColor: AppColors.surfaceLight,
            child: Icon(Icons.person, color: AppColors.primary),
          ),
        ),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.onBookService,
    required this.onTrackStatus,
  });

  final VoidCallback onBookService;
  final VoidCallback onTrackStatus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: onBookService,
            child: const Text('จองบริการ'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Colors.black26),
            ),
            onPressed: onTrackStatus,
            child: const Text('ติดตามสถานะ'),
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'ค้นหาบริการ...',
        prefixIcon: const Icon(Icons.search),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PromoSlide {
  const _PromoSlide({
    required this.title,
    required this.image,
    required this.keyword,
  });

  /// Accessibility label only — the image itself carries all visible copy.
  final String title;

  final String image;

  /// Keyword used to match this promo to a real [ServiceItem] — same
  /// substring-matching convention as [_QuickAction.matchKeyword].
  final String keyword;
}

const List<_PromoSlide> _promoSlides = [
  _PromoSlide(
    title: 'ติดฟิล์มกรองแสง',
    image: 'assets/image/promo_film.jpg',
    keyword: 'ฟิล์ม',
  ),
  _PromoSlide(
    title: 'ซ่อมรอยร้าวกระจก',
    image: 'assets/image/promo_repair.png',
    keyword: 'ซ่อม',
  ),
  _PromoSlide(
    title: 'ล้างรถครบวงจร',
    image: 'assets/image/promo_wash.jpg',
    keyword: 'ล้าง',
  ),
];

const Duration _promoAutoSlideInterval = Duration(seconds: 5);

/// แบนเนอร์โปรโมชั่นหน้าแรก เลื่อนอัตโนมัติทุก 5 วิ วนตาม [_promoSlides]
/// (ติดฟิล์ม → ซ่อมกระจก → ล้างรถ) ปัดนิ้วเปลี่ยนเองได้เช่นกัน — รูปเต็มใบ
/// โชว์เฉยๆ ไม่มีการนำทางเมื่อแตะ.
class _PromoCarousel extends StatefulWidget {
  const _PromoCarousel();

  @override
  State<_PromoCarousel> createState() => _PromoCarouselState();
}

class _PromoCarouselState extends State<_PromoCarousel> {
  final PageController _controller = PageController();
  Timer? _timer;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restartTimer();
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(_promoAutoSlideInterval, (_) {
      final next = (_page + 1) % _promoSlides.length;
      _controller.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  void _onPageChanged(int page) {
    setState(() => _page = page);
    _restartTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PageView.builder(
            controller: _controller,
            onPageChanged: _onPageChanged,
            itemCount: _promoSlides.length,
            itemBuilder: (context, index) => _PromoSlideCard(
              slide: _promoSlides[index],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _promoSlides.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 20 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? AppColors.primary : Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _PromoSlideCard extends StatelessWidget {
  const _PromoSlideCard({required this.slide});

  final _PromoSlide slide;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Semantics(
        key: ValueKey('promo_slide_${slide.keyword}'),
        label: slide.title,
        image: true,
        child: Container(
          color: AppColors.primary,
          width: double.infinity,
          height: double.infinity,
          child: Image.asset(
            slide.image,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            errorBuilder: (context, error, stackTrace) => Center(
              child: Text(
                slide.title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickActionsRow extends StatelessWidget {
  const _QuickActionsRow({required this.onTap});

  final void Function(_QuickAction action) onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < _quickActions.length; i++) ...[
          if (i > 0) const SizedBox(width: 12),
          Expanded(
            child: _QuickActionCard(
              action: _quickActions[i],
              onTap: () => onTap(_quickActions[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.primary),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(action.icon, color: AppColors.primary, size: 26),
              const SizedBox(height: 6),
              Text(
                action.label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: ProductThumbnail(product: product)),
              Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_priceFormat.format(product.price)} บาท',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
}
