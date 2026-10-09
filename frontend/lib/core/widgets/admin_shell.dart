// admin_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';
import '../session/user_role.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';
import 'admin_ui.dart';
import 'nav_item.dart';

class AdminShell extends ConsumerWidget {
  const AdminShell({super.key, required this.child, required this.currentRoute});

  final Widget child;
  final String currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final colors = context.colors;
    final width = MediaQuery.sizeOf(context).width;
    final role = session.role;
    if (role == null) return const SizedBox.shrink();

    final navItems = kAllNavItems.where((item) => item.visibleTo(role)).toList();

    final isCompact = AppBreakpoints.isCompact(width);
    final isRailOnly = AppBreakpoints.isLaptopOrTabletLandscape(width);

    final brandSubtitle = role == UserRole.superAdmin
        ? 'Multi-Academy SaaS'
        : (session.firmName?.trim().isNotEmpty == true
            ? session.firmName!.trim()
            : 'Academy ERP');

    Widget sidebar(bool expanded) => _Sidebar(
      items: navItems,
      currentRoute: currentRoute,
      expanded: expanded,
      subtitle: brandSubtitle,
      roleLabel: _roleLabel(role),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      drawer: isCompact ? Drawer(width: 264, child: sidebar(true)) : null,
      body: Row(
        children: [
          if (!isCompact) sidebar(!isRailOnly),
          Expanded(
            child: Column(
              children: [
                _TopBar(showMenuButton: isCompact),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 1600),
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isCompact ? 16 : 32,
                        vertical: isCompact ? 20 : 28,
                      ),
                      child: child,
                    ),
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

String _roleLabel(UserRole? role) {
  return switch (role) {
    UserRole.superAdmin => 'Super Admin',
    UserRole.academyAdmin => 'Academy Admin',
    UserRole.teacher => 'Teacher',
    UserRole.student => 'Student',
    UserRole.firmStaff => 'Firm Staff',
    null => 'User',
  };
}

bool _isSelected(String itemRoute, String current) =>
    current == itemRoute || current.startsWith('$itemRoute/');

class _BrandMark extends StatelessWidget {
  const _BrandMark({super.key});

  static const double size = 38;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: kAdminGradient,
        borderRadius: BorderRadius.circular(size * 0.28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x404F46E5),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
<<<<<<< HEAD
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: Image.asset(
          'assets/images/vidyasetu_logo.jpg',
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: kAdminGradient,
              borderRadius: BorderRadius.circular(size * 0.28),
            ),
            child: Icon(
              Icons.school_rounded,
              color: Colors.white,
              size: size * 0.55,
            ),
          ),
        ),
      ),
=======
      child: Icon(Icons.school_rounded, color: Colors.white, size: size * 0.55),
>>>>>>> b38ee07af57210a3a2703edb3ef4d9ebe37879b1
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.items,
    required this.currentRoute,
    required this.expanded,
    required this.subtitle,
    required this.roleLabel,
  });

  final List<NavItem> items;
  final String currentRoute;
  final bool expanded;
  final String subtitle;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final width = expanded ? 264.0 : 72.0;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Brand
            SizedBox(
              height: 72,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 20 : 0),
                child: expanded
                    ? Row(
                  children: [
                    const _BrandMark(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
<<<<<<< HEAD
                          Text(
                            'VidyaSetu',
                            style: jakarta(
                              textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelMedium?.copyWith(
                              color: colors.textMuted,
=======
                          const _BrandMark(),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EduSphere',
                                  style: jakarta(
                                    textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.4,
                                      color: const Color(0xFF0F172A),
                                    ),
                                  ),
                                ),
                                Text(
                                  subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.labelMedium?.copyWith(
                                    color: colors.textMuted,
                                  ),
                                ),
                              ],
>>>>>>> b38ee07af57210a3a2703edb3ef4d9ebe37879b1
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                )
                    : const Center(child: _BrandMark()),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFEEF0F5)),
            if (expanded)
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                child: Text(
                  'Main menu',
                  style: textTheme.labelMedium?.copyWith(
                    color: const Color(0xFF94A3B8),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: expanded ? 12 : 10),
                children: [
                  for (final item in items)
                    _NavTile(
                      item: item,
                      expanded: expanded,
                      selected: _isSelected(item.route, currentRoute),
                    ),
                ],
              ),
            ),
            if (expanded)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF10B981),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Signed in as $roleLabel',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium?.copyWith(
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({required this.item, required this.expanded, required this.selected});

  final NavItem item;
  final bool expanded;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final fg = selected ? colors.primary : const Color(0xFF475569);

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: selected ? const Color(0xFFEEF0FF) : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? const Color(0xFFE0E3FF) : Colors.transparent,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          hoverColor: const Color(0xFFF1F5F9),
          onTap: () {
            if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
              Navigator.of(context).pop();
            }
            context.go(item.route);
          },
          child: SizedBox(
            height: 44,
            child: expanded
                ? Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(item.icon, size: 20, color: fg),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: selected
                            ? colors.primary
                            : const Color(0xFF334155),
                        fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (selected)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.primary,
                        shape: BoxShape.circle,
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x996366F1),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            )
                : Center(child: Icon(item.icon, size: 22, color: fg)),
          ),
        ),
      ),
    );

    if (!expanded) {
      return Tooltip(message: item.label, child: tile);
    }
    return tile;
  }
}

class _TopBar extends ConsumerWidget {
  const _TopBar({required this.showMenuButton});

  final bool showMenuButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final session = ref.watch(sessionControllerProvider);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final roleLabel = _roleLabel(session.role);
    final initial = roleLabel.substring(0, 1).toUpperCase();

    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: const BoxDecoration(
        color: Color(0xF2FFFFFF),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),
      child: Row(
        children: [
          if (showMenuButton) ...[
            IconButton(
              tooltip: 'Menu',
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(width: 4),
          ],
          const Spacer(),
          if ((session.firmUuid ?? '').isNotEmpty)
            IconButton(
              tooltip: 'Notifications',
              icon: Icon(
                Icons.notifications_none_rounded,
                color: colors.textMuted,
              ),
              onPressed: () => context.push('/notifications'),
            ),
          if (wide)
            Container(
              width: 1,
              height: 28,
              margin: const EdgeInsets.symmetric(horizontal: 12),
              color: const Color(0xFFE2E8F0),
            )
          else
            const SizedBox(width: 8),
          PopupMenuButton<String>(
            tooltip: 'Account',
            offset: const Offset(0, 52),
            onSelected: (value) async {
              if (value == 'profile') {
                context.go('/super-admin/profile');
                return;
              }

              if (value != 'logout') return;

              final confirm = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Log out?'),
                  content: const Text(
                    'Are you sure you want to log out of VidyaSetu?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: colors.danger,
                      ),
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Log out'),
                    ),
                  ],
                ),
              );

              if (confirm != true || !context.mounted) return;

              try {
                await ref.read(sessionControllerProvider.notifier).logout();
              } on ApiException catch (error) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(error.message)),
                  );
                }
              }
            },
            itemBuilder: (context) => [
              if (session.role == UserRole.superAdmin)
                const PopupMenuItem(
                  value: 'profile',
                  child: Row(
                    children: [
                      Icon(Icons.person_outline_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('My profile'),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded, size: 18, color: colors.danger),
                    const SizedBox(width: 10),
                    Text('Log out', style: TextStyle(color: colors.danger)),
                  ],
                ),
              ),
            ],
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        gradient: kAdminGradient,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: Text(
                        initial,
                        style: jakarta(
                          const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
                if (wide) ...[
                  const SizedBox(width: 12),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        roleLabel,
                        style: textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 180),
                        child: Text(
                          session.firmName?.trim().isNotEmpty == true
                              ? session.firmName!.trim()
                              : 'EduSphere',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.labelMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.expand_more_rounded,
                      size: 20, color: colors.textMuted),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}