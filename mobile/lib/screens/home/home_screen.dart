import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../api/api_client.dart';
import '../../api/auth_service.dart';
import '../../api/catalog_service.dart';
import '../../models/product.dart';
import '../../models/service_item.dart';
import '../../theme/app_theme.dart';

const String _comingSoonMessage = 'เร็วๆ นี้';

final NumberFormat _priceFormat = NumberFormat('#,###');

class _QuickAction {
  const _QuickAction(this.label, this.icon, {this.matchKeyword});

  final String label;
  final IconData icon;

  /// Keyword used to find the matching [ServiceItem] by substring — e.g.
  /// "ฟิล์ม" matches a backend service named "ติดฟิล์มกรองแสงรถยนต์" or just
  /// "ติดฟิล์ม" regardless of how admins phrased the full name. Null for
  /// actions (like "รีวิว") that don't book a service.
  final String? matchKeyword;
}

const List<_QuickAction> _quickActions = [
  _QuickAction('ติดฟิล์มกรองแสง', Icons.window_outlined, matchKeyword: 'ฟิล์ม'),
  _QuickAction('ซ่อมกระจก', Icons.build_outlined, matchKeyword: 'ซ่อม'),
  _QuickAction('ล้างรถ', Icons.local_car_wash_outlined, matchKeyword: 'ล้าง'),
  _QuickAction('รีวิว', Icons.star_outline),
];

/// หน้าแรก (Home) ตาม Figma page 7.
///
/// แสดงคำทักทายจาก [AuthService.instance.session], ปุ่มจองบริการ/ติดตาม
/// สถานะ, ช่องค้นหาที่กรอง "บริการยอดนิยม", แบนเนอร์, การ์ด "บริการด่วน" 4
/// ใบ และ grid สินค้ายอดนิยมจาก [CatalogService.instance].
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.onBookService, this.onTrackStatus});

  /// เรียกเมื่อผู้ใช้กด "จองบริการ", แบนเนอร์ "จองเลย" หรือการ์ด
  /// "บริการด่วน" 3 ใบแรก — ส่ง [ServiceItem] ที่ match จากชื่อบริการ หรือ
  /// null เมื่อไม่ได้ระบุบริการเจาะจง (Task 4 จะผูกไป flow จองจริง).
  final void Function(ServiceItem?)? onBookService;

  /// เรียกเมื่อผู้ใช้กด "ติดตามสถานะ" — ปกติ MainShell จะสลับไปแท็บการจอง.
  final VoidCallback? onTrackStatus;

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
    final keyword = action.matchKeyword;
    if (keyword == null) {
      _showComingSoon();
      return;
    }
    widget.onBookService?.call(_matchService(keyword));
  }

  List<Product> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return _products;
    return _products
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final fullName = AuthService.instance.session?.fullName ?? '';

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
                      _TopBar(fullName: fullName, onIconTap: _showComingSoon),
                      const SizedBox(height: 16),
                      _ActionButtons(
                        onBookService: () =>
                            widget.onBookService?.call(null),
                        onTrackStatus:
                            widget.onTrackStatus ?? _showComingSoon,
                      ),
                      const SizedBox(height: 16),
                      _SearchField(
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                      ),
                      const SizedBox(height: 16),
                      _Banner(onBookNow: () => widget.onBookService?.call(null)),
                      const SizedBox(height: 24),
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'บริการด่วน',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _QuickActionsRow(onTap: _handleQuickAction),
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'บริการยอดนิยม',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700),
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
                      (context, index) =>
                          _ProductCard(product: products[index]),
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
          child: FloatingActionButton(
            heroTag: 'home_chat_fab',
            backgroundColor: AppColors.primary,
            shape: const CircleBorder(),
            onPressed: _showComingSoon,
            child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.fullName, required this.onIconTap});

  final String fullName;
  final VoidCallback onIconTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'สวัสดี, $fullName',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              const Text(
                'BKK CAR GLASS & FLIM',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onIconTap,
          icon: const Icon(Icons.notifications_none),
        ),
        InkWell(
          onTap: onIconTap,
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
        fillColor: AppColors.surfaceLight,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.onBookNow});

  final VoidCallback onBookNow;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'BKK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
                Text(
                  'CAR GLASS & FILM',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onBookNow,
                  child: const Text('จองเลย'),
                ),
              ],
            ),
          ),
          const Icon(Icons.directions_car, color: Colors.white, size: 56),
        ],
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
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: _quickActions
          .map((action) => _QuickActionCard(
                action: action,
                onTap: () => onTap(action),
              ))
          .toList(),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action, required this.onTap});

  final _QuickAction action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 76,
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppColors.surfaceLight,
              child: Icon(action.icon, color: AppColors.primary),
            ),
            const SizedBox(height: 8),
            Text(
              action.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final imageUrl = product.imageUrl;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: imageUrl != null && imageUrl.isNotEmpty
                ? Image.network(imageUrl, fit: BoxFit.cover, width: double.infinity)
                : Container(color: Colors.grey.shade300),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
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
    );
  }
}
