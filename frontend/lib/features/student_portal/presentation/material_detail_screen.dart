import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/open_external_link.dart';
import '../data/student_portal_repository.dart';
import 'tracked_video_player.dart';
import 'widgets/student_ui.dart';

String _typeLabel(String raw) {
  final value = raw.replaceAll('_', ' ').trim().toLowerCase();
  if (value.isEmpty) return 'Material';
  return value[0].toUpperCase() + value.substring(1);
}

IconData _typeIcon(String raw) {
  final type = raw.toUpperCase();
  if (type.contains('VIDEO')) return Icons.smart_display_outlined;
  if (type.contains('PDF') || type.contains('DOC')) {
    return Icons.picture_as_pdf_outlined;
  }
  if (type.contains('LINK') || type.contains('URL')) return Icons.link_rounded;
  if (type.contains('AUDIO')) return Icons.headphones_rounded;
  return Icons.description_outlined;
}

class MaterialDetailScreen extends ConsumerStatefulWidget {
  const MaterialDetailScreen({
    super.key,
    required this.materialUuid,
  });

  final String materialUuid;

  @override
  ConsumerState<MaterialDetailScreen> createState() =>
      _MaterialDetailScreenState();
}

class _MaterialDetailScreenState
    extends ConsumerState<MaterialDetailScreen> {
  late Future<Map<String, dynamic>> _material;
  late Future<Map<String, dynamic>> _progress;

  @override
  void initState() {
    super.initState();

    final api = ref.read(
      studentPortalRepositoryProvider,
    );

    _material = api.material(
      widget.materialUuid,
    );

    _progress = api.materialProgress(
      widget.materialUuid,
    );
  }

  void _retryMaterial() {
    final api = ref.read(studentPortalRepositoryProvider);

    setState(() {
      _material = api.material(widget.materialUuid);
      _progress = api.materialProgress(widget.materialUuid);
    });
  }

  void _retryProgress() {
    setState(() {
      _progress = ref
          .read(studentPortalRepositoryProvider)
          .materialProgress(widget.materialUuid);
    });
  }

  Future<void> _copyLink(String url) async {
    await Clipboard.setData(
      ClipboardData(text: url),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Link copied',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return FutureBuilder<Map<String, dynamic>>(
      future: _material,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return StudentPageFrame(
            child: ListView(
              padding: const EdgeInsets.all(kStudentPagePadding),
              children: [
                StudentStateMessage(
                  icon: Icons.wifi_off_rounded,
                  title: 'Material could not load',
                  message: '${snapshot.error}',
                  actionLabel: 'Try again',
                  onAction: _retryMaterial,
                  isError: true,
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }

        final material = snapshot.data!;
        final url = material['content_url']?.toString() ?? '';
        final contentUri = Uri.tryParse(url);

        final hasContent = contentUri != null &&
            (contentUri.scheme == 'http' ||
                contentUri.scheme == 'https') &&
            contentUri.host.isNotEmpty;

        final rawType = material['material_type']?.toString() ?? 'MATERIAL';
        final isVideo = material['material_type'] == 'VIDEO';
        final description = material['description']?.toString() ?? '';

        return StudentPageFrame(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              kStudentPagePadding,
              4,
              kStudentPagePadding,
              28,
            ),
            children: [
              if (hasContent && isVideo) ...[
                TrackedVideoPlayer(
                  materialUuid: widget.materialUuid,
                  url: url,
                  onProgressChanged: () {
                    if (!mounted) return;

                    setState(() {
                      _progress = ref
                          .read(studentPortalRepositoryProvider)
                          .materialProgress(widget.materialUuid);
                    });
                  },
                ),
                const SizedBox(height: 18),
              ] else ...[
                Container(
                  height: 150,
                  decoration: BoxDecoration(
                    gradient: colors.heroGradient,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: colors.heroShadow,
                  ),
                  child: Center(
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Icon(
                        _typeIcon(rawType),
                        size: 38,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ],
              Align(
                alignment: Alignment.centerLeft,
                child: TonalPill(
                  label: _typeLabel(rawType),
                  icon: _typeIcon(rawType),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                material['title']?.toString() ?? 'Study material',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (description.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: textTheme.bodyLarge?.copyWith(
                    color: colors.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              FutureBuilder<Map<String, dynamic>>(
                future: _progress,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return PremiumCard(
                      child: Row(
                        children: [
                          IconTile(
                            icon: Icons.error_outline_rounded,
                            background: colors.dangerBg,
                            foreground: colors.danger,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Could not load progress: ${snapshot.error}',
                              style: textTheme.bodySmall,
                            ),
                          ),
                          TextButton(
                            onPressed: _retryProgress,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const PremiumCard(
                      child: LinearProgressIndicator(minHeight: 8),
                    );
                  }

                  final progress = snapshot.data!;

                  final completed = progress['is_completed'] == true;

                  final materialType =
                      material['material_type']?.toString().toUpperCase() ??
                          '';

                  final rawDuration = material['duration_seconds'];
                  final durationSeconds = rawDuration is num
                      ? rawDuration.toInt()
                      : int.tryParse(rawDuration?.toString() ?? '') ?? 0;

                  final isVideoMaterial =
                      materialType == 'VIDEO' && durationSeconds > 0;

                  final percentage =
                      progress['completion_percentage']?.toString() ?? '0';
                  final percentValue = completed
                      ? 100.0
                      : (double.tryParse(percentage) ?? 0)
                          .clamp(0.0, 100.0)
                          .toDouble();

                  return PremiumCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            IconTile(
                              icon: completed
                                  ? Icons.check_circle_rounded
                                  : Icons.donut_large_rounded,
                              background:
                                  completed ? colors.successBg : null,
                              foreground: completed ? colors.success : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Your progress',
                                    style: textTheme.titleMedium,
                                  ),
                                  Text(
                                    completed
                                        ? 'Completed'
                                        : isVideoMaterial
                                            ? 'Updates as you watch'
                                            : 'Open the material to study',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              completed
                                  ? 'Done'
                                  : '${percentValue.toStringAsFixed(0)}% done',
                              style: textTheme.titleMedium?.copyWith(
                                color: completed
                                    ? colors.success
                                    : colors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: percentValue / 100,
                            minHeight: 8,
                            backgroundColor: colors.primaryTonal,
                            color:
                                completed ? colors.success : colors.primary,
                          ),
                        ),
                        if (isVideoMaterial && !completed) ...[
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Icon(
                                Icons.play_circle_outline_rounded,
                                size: 18,
                                color: colors.textMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Watch the video to track your progress. '
                                  'Completion is recorded automatically.',
                                  style: textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (completed) ...[
                          const SizedBox(height: 14),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              backgroundColor: colors.successBg,
                              foregroundColor: colors.success,
                              side: BorderSide(color: colors.successBg),
                            ),
                            onPressed: null,
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Completed'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 4),
              if (hasContent)
                Row(
                  children: [
                    if (!isVideo) ...[
                      Expanded(
                        child: _ActionTile(
                          icon: Icons.open_in_new_rounded,
                          title: 'Open material',
                          subtitle: _typeLabel(rawType),
                          onTap: () => openExternalLink(context, url),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: _ActionTile(
                        icon: Icons.link_rounded,
                        title: 'Copy link',
                        subtitle: 'Share or save',
                        onTap: () => _copyLink(url),
                      ),
                    ),
                  ],
                )
              else
                PremiumCard(
                  child: Row(
                    children: [
                      IconTile(
                        icon: Icons.link_off_rounded,
                        background: const Color(0xFFF1F2F8),
                        foreground: colors.textSubtle,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Content link is not available.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      onTap: onTap,
      child: Column(
        children: [
          IconTile(icon: icon, size: 42, radius: 21),
          const SizedBox(height: 10),
          Text(title, style: textTheme.titleSmall),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
