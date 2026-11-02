import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/open_external_link.dart';
import '../../student_portal/presentation/widgets/student_ui.dart';
import '../data/certificate_repository.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _prettyDate(String raw) {
  final date = DateTime.tryParse(raw.trim())?.toLocal();
  if (date == null) return raw;
  return '${date.day} ${_months[date.month - 1]} ${date.year}';
}

class StudentCertificatesScreen extends ConsumerStatefulWidget {
  const StudentCertificatesScreen({super.key});

  @override
  ConsumerState<StudentCertificatesScreen> createState() =>
      _StudentCertificatesScreenState();
}

class _StudentCertificatesScreenState
    extends ConsumerState<StudentCertificatesScreen> {
  List<Certificate>? _certificates;
  bool _loading = true;
  String? _error;

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
      final result =
          await ref.read(certificateRepositoryProvider).studentCertificates();
      if (!mounted) return;
      setState(() {
        _certificates = result;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _download(Certificate cert) async {
    try {
      final url = await ref
          .read(certificateRepositoryProvider)
          .certificateDownloadUrl(cert.uuid);

      if (!mounted || url.isEmpty) return;
      openExternalLink(context, url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not download certificate.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _load,
      child: StudentPageFrame(
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            kStudentPagePadding, 4, kStudentPagePadding, 24,
          ),
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              decoration: BoxDecoration(
                gradient: colors.heroGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: colors.heroShadow,
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: -6,
                    top: -4,
                    child: Icon(
                      Icons.workspace_premium_rounded,
                      size: 88,
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TonalPill(
                        label: 'Achievements',
                        icon: Icons.emoji_events_rounded,
                        background: Colors.white.withValues(alpha: 0.18),
                        foreground: Colors.white,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'My Certificates',
                        style: textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Certificates earned for completed courses.',
                        style: textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFFDAD7FF),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            SectionHeader(
              title: 'Certificates',
              icon: Icons.verified_outlined,
              trailing: _certificates != null && _certificates!.isNotEmpty
                  ? TonalPill(label: '${_certificates!.length} earned')
                  : null,
            ),
            if (_loading)
              const StudentLoading()
            else if (_certificates == null && _error != null)
              StudentStateMessage(
                icon: Icons.wifi_off_rounded,
                title: 'Could not load certificates',
                message: _error!,
                actionLabel: 'Try again',
                onAction: _load,
                isError: true,
              )
            else if (_certificates!.isEmpty)
              const StudentStateMessage(
                icon: Icons.workspace_premium_outlined,
                title: 'No certificates yet',
                message:
                    'Complete your courses and clear pending fees to earn certificates.',
              )
            else
              for (final cert in _certificates!)
                _CertificateCard(
                  certificate: cert,
                  onDownload: cert.fileAvailable ? () => _download(cert) : null,
                ),
          ],
        ),
      ),
    );
  }
}

class _CertificateCard extends StatelessWidget {
  const _CertificateCard({
    required this.certificate,
    this.onDownload,
  });

  final Certificate certificate;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconTile(
                icon: certificate.isRevoked
                    ? Icons.cancel_outlined
                    : Icons.workspace_premium_rounded,
                size: 52,
                radius: 16,
                background: certificate.isRevoked
                    ? colors.dangerBg
                    : colors.primaryTonal,
                foreground: certificate.isRevoked
                    ? colors.danger
                    : colors.primary,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      certificate.courseName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      certificate.certificateNumber,
                      style: textTheme.bodySmall?.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              TonalPill(
                label: 'Issued ${_prettyDate(certificate.issuedAt)}',
                icon: Icons.calendar_today_rounded,
              ),
              if (certificate.isRevoked)
                TonalPill(
                  label: 'Revoked',
                  icon: Icons.block_rounded,
                  background: colors.dangerBg,
                  foreground: colors.danger,
                )
              else
                TonalPill(
                  label: 'Valid',
                  icon: Icons.verified_rounded,
                  background: colors.successBg,
                  foreground: colors.success,
                ),
            ],
          ),
          if (onDownload != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: colors.primaryDeep,
                  minimumSize: const Size(0, 44),
                ),
                onPressed: onDownload,
                icon: const Icon(Icons.download_rounded),
                label: const Text('Download Certificate'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
