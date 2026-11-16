import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/admin_ui.dart';
import '../data/banner_repository.dart';

class BannersListScreen extends ConsumerStatefulWidget {
  const BannersListScreen({
    super.key,
  });

  @override
  ConsumerState<BannersListScreen> createState() =>
      _BannersListScreenState();
}

class _BannersListScreenState extends ConsumerState<BannersListScreen> {
  late Future<HomeBannerPage> result;

  int page = 1;

  @override
  void initState() {
    super.initState();
    reload();
  }

  void reload() {
    result = ref.read(bannerRepositoryProvider).list(
      page: page,
    );
  }

  void refresh() {
    setState(reload);
  }

  Future<void> _openCreate() async {
    await context.push('/banners/create');
    if (mounted) refresh();
  }

  String _date(DateTime? value) {
    if (value == null) return '';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final local = value.toLocal();
    return '${local.day} ${months[local.month - 1]} ${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      color: const Color(0xFFF8FAFC),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header matching screenshot ("Banners" + refresh + "+ Add banner" + subtitle)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Banners',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: jakarta(
                          textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Refresh',
                      onPressed: refresh,
                      icon: const Icon(
                        Icons.refresh_rounded,
                        size: 20,
                        color: Color(0xFF64748B),
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                    const SizedBox(width: 6),
                    FilledButton.icon(
                      onPressed: _openCreate,
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Add banner'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3730A3),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 11,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        textStyle: textTheme.labelLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Promotional banners shown on the student Explore page.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: FutureBuilder<HomeBannerPage>(
              future: result,
              builder: (context, snapshot) {
                final state = adminFutureState(
                  snapshot,
                  noun: 'banners',
                  onRetry: refresh,
                );
                final data = state == null ? snapshot.data : null;
                final rows = data?.results ?? const <HomeBanner>[];
                final active = rows.where((b) => b.isActive).length;
                final linked = rows.where((b) => b.courseName != null).length;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                  children: [
                    // 2x2 / Responsive KPI grid matching screenshot
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final w = constraints.maxWidth;
                        final columns = w >= 1100
                            ? 4
                            : w >= 640
                            ? 2
                            : 2;
                        const gap = 12.0;
                        final cardWidth = (w - gap * (columns - 1)) / columns;

                        return Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            SizedBox(
                              width: cardWidth,
                              child: _BannerStatCard(
                                label: 'Total banners',
                                value: data == null ? '…' : '${data.count}',
                                icon: Icons.table_chart_outlined,
                                iconColor: const Color(0xFF4F46E5),
                                iconBg: const Color(0xFFEEF2FF),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _BannerStatCard(
                                label: 'Live now',
                                value: data == null ? '…' : '$active',
                                icon: Icons.wifi_rounded,
                                iconColor: const Color(0xFF059669),
                                iconBg: const Color(0xFFECFDF5),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _BannerStatCard(
                                label: 'Inactive',
                                value: data == null
                                    ? '…'
                                    : '${rows.length - active}',
                                icon: Icons.visibility_off_outlined,
                                iconColor: const Color(0xFF64748B),
                                iconBg: const Color(0xFFF1F5F9),
                              ),
                            ),
                            SizedBox(
                              width: cardWidth,
                              child: _BannerStatCard(
                                label: 'Linked to course',
                                value: data == null ? '…' : '$linked',
                                icon: Icons.link_rounded,
                                iconColor: const Color(0xFF9333EA),
                                iconBg: const Color(0xFFFAF5FF),
                              ),
                            ),
                          ],
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // Section title row ("ACTIVE BANNERS [count]" + "Order priority")
                    Row(
                      children: [
                        Text(
                          'ACTIVE BANNERS',
                          style: jakarta(
                            textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF334155),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEEF2FF),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            data == null ? '…' : '$active',
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF3730A3),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.swap_vert_rounded,
                          size: 16,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Order priority',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    if (state != null)
                      state
                    else if (rows.isEmpty)
                      AdminStateMessage(
                        icon: Icons.add_photo_alternate_outlined,
                        title: 'No banners yet',
                        message: 'Create a banner to promote a course on the '
                            'student app.',
                        actionLabel: 'Add banner',
                        onAction: _openCreate,
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final columns = w >= 1100
                              ? 3
                              : w >= 640
                              ? 2
                              : 1;
                          const gap = 16.0;
                          final cardWidth =
                              (w - gap * (columns - 1)) / columns;

                          return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: [
                              for (final banner in rows)
                                SizedBox(
                                  width: cardWidth,
                                  child: _BannerCard(
                                    banner: banner,
                                    schedule: [
                                      _date(banner.startsAt),
                                      _date(banner.endsAt),
                                    ].where((d) => d.isNotEmpty).join(' → '),
                                    onTap: () async {
                                      await context.push(
                                        '/banners/${banner.uuid}',
                                      );
                                      if (mounted) refresh();
                                    },
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _BannerStatCard extends StatelessWidget {
  const _BannerStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF475569),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: jakarta(
                    textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF0F172A),
                      fontSize: 28,
                      letterSpacing: -0.6,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
        ],
      ),
    );
  }
}

class _BannerCard extends StatelessWidget {
  const _BannerCard({
    required this.banner,
    required this.schedule,
    required this.onTap,
  });

  final HomeBanner banner;
  final String schedule;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final hasCourse = banner.courseName != null && banner.courseName!.isNotEmpty;
    final captionText = hasCourse
        ? '1200 × 600 • ${banner.courseName!.toUpperCase()}'
        : '1200 × 600 • GENERAL ANNOUNCEMENT';

    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF312E81),
            Color(0xFF4F46E5),
            Color(0xFF1E1B4B),
          ],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.image_outlined,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            captionText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: jakarta(
              textTheme.labelSmall?.copyWith(
                color: Colors.white.withOpacity(0.92),
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(18)),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (banner.imageUrl.isNotEmpty)
                        Image.network(
                          banner.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => placeholder,
                        )
                      else
                        placeholder,
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Order ${banner.displayOrder}',
                            style: textTheme.labelSmall?.copyWith(
                              color: const Color(0xFF0F172A),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        top: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: banner.isActive
                                ? const Color(0xFF15803D)
                                : const Color(0xFF475569),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                banner.isActive ? 'Live' : 'Inactive',
                                style: textTheme.labelSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            banner.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: jakarta(
                              textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.edit_outlined,
                          size: 17,
                          color: Color(0xFF64748B),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          banner.isActive
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          size: 17,
                          color: const Color(0xFF64748B),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.more_vert_rounded,
                          size: 18,
                          color: Color(0xFF64748B),
                        ),
                      ],
                    ),
                    if (banner.subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        banner.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF475569),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 14,
                      runSpacing: 6,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.school_outlined,
                              size: 15,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              banner.courseName ?? 'No linked course',
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        if (schedule.isNotEmpty)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.event_outlined,
                                size: 15,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                schedule,
                                style: textTheme.bodySmall?.copyWith(
                                  color: const Color(0xFF475569),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              banner.actionLabel.isNotEmpty
                                  ? Icons.link_rounded
                                  : Icons.open_in_new_rounded,
                              size: 15,
                              color: const Color(0xFF64748B),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              banner.actionLabel.isNotEmpty
                                  ? banner.actionLabel
                                  : 'Informational only',
                              style: textTheme.bodySmall?.copyWith(
                                color: const Color(0xFF475569),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
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