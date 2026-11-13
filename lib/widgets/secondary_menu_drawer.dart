import 'package:flutter/material.dart';

import '../screens/attendance_screen.dart';
import '../screens/gallery_screen.dart';
import '../screens/sponsors_screen.dart';
import '../services/supabase_service.dart';
import '../config/brand.dart';
import '../theme/colors.dart';

class _MenuItem {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;

  const _MenuItem({required this.label, required this.icon, required this.builder});
}

class SecondaryMenuDrawer extends StatefulWidget {
  const SecondaryMenuDrawer({super.key});

  @override
  State<SecondaryMenuDrawer> createState() => _SecondaryMenuDrawerState();
}

class _SecondaryMenuDrawerState extends State<SecondaryMenuDrawer> {
  late Future<List<_MenuItem>> _itemsFuture;

  @override
  void initState() {
    super.initState();
    _itemsFuture = _loadItems();
  }

  Future<List<_MenuItem>> _loadItems() async {
    if (supabase.auth.currentUser == null) {
      return const [
        _MenuItem(
          label: 'Sponsorlar',
          icon: Icons.business_center_outlined,
          builder: _sponsorsBuilder,
        ),
      ];
    }

    String? role;
    try {
      role = await fetchMyRole();
    } catch (_) {
      role = null;
    }

    if (isMezunRole(role)) {
      return const [];
    }

    return [
      const _MenuItem(
        label: 'Galeri',
        icon: Icons.photo_library_outlined,
        builder: _galleryBuilder,
      ),
      if (role != 'coordinator')
        const _MenuItem(
          label: 'Sponsorlar',
          icon: Icons.business_center_outlined,
          builder: _sponsorsBuilder,
        ),
      const _MenuItem(
        label: 'Yoklama',
        icon: Icons.qr_code_scanner_outlined,
        builder: _attendanceBuilder,
      ),
    ];
  }

  void _open(BuildContext context, _MenuItem item) {
    Navigator.of(context).pop();
    Navigator.of(context).push(MaterialPageRoute(builder: item.builder));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Drawer(
      backgroundColor: colors.background,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Row(
                children: [
                  Image.asset(Brand.logoAsset, width: 36, height: 36),
                  const SizedBox(width: 12),
                  Text(
                    Brand.shortName,
                    style: TextStyle(
                      color: colors.ink,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
            Divider(color: colors.faint, height: 1),
            Expanded(
              child: FutureBuilder<List<_MenuItem>>(
                future: _itemsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(
                      child: CircularProgressIndicator(color: buikBrand),
                    );
                  }
                  final items = snapshot.data ?? [];
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: items
                        .map(
                          (item) => ListTile(
                            leading: Icon(item.icon, color: buikBrand),
                            title: Text(
                              item.label,
                              style: TextStyle(
                                color: colors.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: () => _open(context, item),
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _galleryBuilder(BuildContext context) => const GalleryScreen();
Widget _sponsorsBuilder(BuildContext context) => const SponsorsScreen();
Widget _attendanceBuilder(BuildContext context) => const AttendanceScreen();
