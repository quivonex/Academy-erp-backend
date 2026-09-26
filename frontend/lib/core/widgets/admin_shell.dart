import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../session/session_controller.dart';
import '../network/api_exception.dart';
import '../theme/app_colors.dart';
import '../theme/breakpoints.dart';
import 'nav_item.dart';

/// The shared shell for every authenticated screen. Implements the three
/// responsive states from DESIGN.md § Responsive Breakpoints:
///   >=1280px  fixed 260px sidebar
///   1024-1279 68px icon rail
///   <1024     off-canvas drawer
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

    return Scaffold(
      backgroundColor: colors.canvas,
      drawer: isCompact ? _Sidebar(items: navItems, currentRoute: currentRoute, expanded: true) : null,
      body: Row(
        children: [
          if (!isCompact)
            _Sidebar(items: navItems, currentRoute: currentRoute, expanded: !isRailOnly),
          Expanded(
            child: Column(
              children: [
                _TopBar(showMenuButton: isCompact),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 1600),
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(
                      horizontal: isCompact ? 16 : 24,
                      vertical: 24,
                    ),
                    child: child,
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

class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.items, required this.currentRoute, required this.expanded});

  final List<NavItem> items;
  final String currentRoute;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final width = expanded ? 260.0 : 68.0;

    return Container(
      width: width,
      color: colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: expanded
                  ? Row(
                      children: [
                        Icon(Icons.school, color: colors.primary),
                        const SizedBox(width: 8),
                        Text('EduSphere', style: Theme.of(context).textTheme.titleLarge),
                      ],
                    )
                  : Icon(Icons.school, color: colors.primary),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  for (final item in items)
                    _NavTile(item: item, expanded: expanded, selected: item.route == currentRoute),
                ],
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
    final tile = ListTile(
      leading: Icon(item.icon, color: selected ? colors.primary : colors.textMuted, size: 20),
      title: expanded
          ? Text(
              item.label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: selected ? colors.primary : colors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
              overflow: TextOverflow.ellipsis,
            )
          : null,
      selected: selected,
      selectedTileColor: colors.primary.withOpacity(0.08),
      dense: true,
      onTap: () {
        if (Scaffold.maybeOf(context)?.isDrawerOpen ?? false) {
          Navigator.of(context).pop();
        }
        context.go(item.route);
      },
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
    final session = ref.watch(sessionControllerProvider);

    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: colors.surface.withOpacity(0.9),
        border: Border(bottom: BorderSide(color: colors.borderSubtle)),
      ),
      child: Row(
        children: [
          if (showMenuButton)
            IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
          Expanded(
            child: _SearchField(),
          ),
          const SizedBox(width: 16),
          IconButton(icon: const Icon(Icons.notifications_outlined), onPressed: () {}),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'logout') return;
              try {
                await ref.read(sessionControllerProvider.notifier).logout();
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'logout', child: Text('Log out')),
            ],
            child: CircleAvatar(
              backgroundColor: colors.primary,
              child: Text(
                session.role?.apiValue.substring(0, 1).toUpperCase() ?? '?',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: TextField(
        decoration: InputDecoration(
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Center(
              widthFactor: 1,
              child: Text('⌘K', style: Theme.of(context).textTheme.labelSmall),
            ),
          ),
          hintText: 'Search students, teachers, invoices, batches...',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
    );
  }
}
