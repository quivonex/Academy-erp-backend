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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminPageHeader(
          eyebrow: const AdminEyebrow(
            section: 'Student app',
            detail: 'Home screen banners',
          ),
          title: 'Banners',
          subtitle: 'Promotional banners shown on the student Explore page.',
          titleTrailing: [
            IconButton(
              tooltip: 'Refresh',
              onPressed: refresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
          actions: [
            GradientButton(
              label: 'Add banner',
              icon: Icons.add_photo_alternate_outlined,
              onPressed: _openCreate,
            ),
          ],
        ),
        const SizedBox(height: 20),
        Expanded(
          child: FutureBuilder<HomeBannerPage>(
            future: result,
            builder: (context, snapshot) {
              final state = adminFutureState(
                snapshot,
                noun: 'banners',
                onRetry: refresh,
              );
              final data = snapshot.data;
              final rows = data?.results ?? const <HomeBanner>[];
              final active = rows.where((b) => b.isActive).length;
              final linked = rows.where((b) => b.courseName != null).length;

              return ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  AdminKpiGrid(
                    children: [
                      AdminKpiCard(
                        label: 'Total banners',
                        value: data == null ? '…' : '${data.count}',
                        icon: Icons.view_carousel_outlined,
                      ),
                      AdminKpiCard(
                        label: 'Live now',
                        value: data == null ? '…' : '$active',
                        icon: Icons.podcasts_rounded,
                        iconBackground: const Color(0xFFECFDF5),
                        iconForeground: const Color(0xFF059669),
                      ),
                      AdminKpiCard(
                        label: 'Inactive',
                        value: data == null ? '…' : '${rows.length - active}',
                        icon: Icons.visibility_off_outlined,
                        iconBackground: const Color(0xFFF8FAFC),
                        iconForeground: const Color(0xFF64748B),
                      ),
                      AdminKpiCard(
                        label: 'Linked to a course',
                        value: data == null ? '…' : '$linked',
                        icon: Icons.link_rounded,
                        iconBackground: const Color(0xFFF5F3FF),
                        iconForeground: const Color(0xFF7C3AED),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
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
                        const gap = 18.0;
                        final cardWidth = (w - gap * (columns - 1)) / columns;

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

    final placeholder = Container(
      decoration: const BoxDecoration(gradient: kAdminGradient),
      alignment: Alignment.center,
      child: const Icon(Icons.image_outlined, color: Colors.white, size: 40),
    );

    return AdminCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(15)),
            child: AspectRatio(
              aspectRatio: 16 / 7,
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
                    top: 10,
                    left: 10,
                    child: SoftBadge(
                      label: 'Order ${banner.displayOrder}',
                      background: Colors.white,
                      foreground: const Color(0xFF334155),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    right: 10,
                    child: ActiveBadge(
                      active: banner.isActive,
                      activeLabel: 'Live',
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
                Text(
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
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    MetaChip(
                      icon: Icons.school_outlined,
                      label: banner.courseName ?? 'No linked course',
                    ),
                    if (schedule.isNotEmpty)
                      MetaChip(
                        icon: Icons.event_outlined,
                        label: schedule,
                      ),
                    if (banner.actionLabel.isNotEmpty)
                      MetaChip(
                        icon: Icons.ads_click_rounded,
                        label: banner.actionLabel,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
