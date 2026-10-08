import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/admin_ui.dart';

class SuperAdminProfileScreen extends ConsumerStatefulWidget {
  const SuperAdminProfileScreen({super.key});

  @override
  ConsumerState<SuperAdminProfileScreen> createState() =>
      _SuperAdminProfileScreenState();
}

class _SuperAdminProfileScreenState
    extends ConsumerState<SuperAdminProfileScreen> {
  late Future<Map<String, dynamic>> _profile;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _profile = _loadProfile();
  }

  Future<Map<String, dynamic>> _loadProfile() async {
    try {
      final response = await ref.read(dioProvider).get(
            ApiUrls.me,
          );

      final body = response.data;
      final data = body is Map ? body['data'] : null;

      if (data is! Map) {
        throw const ApiException('Invalid profile response.');
      }

      return Map<String, dynamic>.from(data);
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> _refresh() async {
    final next = _loadProfile();
    setState(() => _profile = next);

    try {
      await next;
    } catch (_) {
      // FutureBuilder displays the error.
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;
    setState(() => _loggingOut = true);

    try {
      await ref.read(sessionControllerProvider.notifier).logout();
      if (mounted) context.go('/login');
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Logout failed: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  String _value(Map<String, dynamic> profile, String key) {
    final value = profile[key]?.toString().trim() ?? '';
    return value.isEmpty ? 'Not provided' : value;
  }

  Future<void> _copy(String value, String label) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<Map<String, dynamic>>(
        future: _profile,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: const [
                SizedBox(height: 120),
                Center(child: CircularProgressIndicator()),
              ],
            );
          }

          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                AdminStateMessage(
                  icon: Icons.person_off_outlined,
                  title: 'Could not load profile',
                  message: '${snapshot.error}',
                  actionLabel: 'Retry',
                  onAction: _refresh,
                  isError: true,
                ),
              ],
            );
          }

          final profile = snapshot.data!;
          final fullName = _value(profile, 'full_name');
          final displayName = fullName == 'Not provided'
              ? _value(profile, 'email')
              : fullName;
          final email = _value(profile, 'email');
          final phone = _value(profile, 'phone');
          final role = _value(profile, 'user_type');
          final uuid = _value(profile, 'uuid');
          final joinedRaw = _value(profile, 'date_joined');
          final joined = DateTime.tryParse(joinedRaw)?.toLocal();

          TextStyle? missing(TextStyle? base, String value) =>
              value == 'Not provided'
                  ? base?.copyWith(
                      color: colors.textSubtle,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                    )
                  : base;

          final valueStyle = textTheme.titleMedium?.copyWith(
            color: const Color(0xFF0F172A),
            fontWeight: FontWeight.w600,
          );

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  // Breadcrumb
                  Row(
                    children: [
                      Text(
                        'System directory',
                        style: textTheme.labelLarge?.copyWith(
                          color: colors.textMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Icon(Icons.chevron_right_rounded,
                            size: 18, color: colors.textSubtle),
                      ),
                      Text(
                        'Identity & credentials',
                        style: textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Identity card
                  AdminCard(
                    gradientWash: true,
                    padding: const EdgeInsets.all(28),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 20,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      alignment: WrapAlignment.spaceBetween,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GradientAvatar(
                              label: adminInitials(displayName),
                              size: 76,
                              statusDot: const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 20),
                            Flexible(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayName,
                                    style: jakarta(
                                      textTheme.headlineSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: const Color(0xFF0F172A),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 10,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      SoftBadge(
                                        label: role,
                                        icon: Icons.shield_outlined,
                                      ),
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.mail_outline_rounded,
                                              size: 16,
                                              color: colors.textMuted),
                                          const SizedBox(width: 6),
                                          Text(
                                            email,
                                            style: textTheme.bodyMedium
                                                ?.copyWith(
                                              color:
                                                  const Color(0xFF334155),
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
                        AdminOutlineButton(
                          label: _loggingOut ? 'Logging out...' : 'Log out',
                          icon: Icons.logout_rounded,
                          danger: true,
                          onPressed: _loggingOut ? null : _logout,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detail tiles
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final twoCols = constraints.maxWidth >= 640;
                      const gap = 20.0;
                      final width = twoCols
                          ? (constraints.maxWidth - gap) / 2
                          : constraints.maxWidth;

                      return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          SizedBox(
                            width: width,
                            child: _DetailTile(
                              icon: Icons.alternate_email_rounded,
                              caption: 'Primary authentication',
                              label: 'Email',
                              child: SelectableText(email, style: valueStyle),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _DetailTile(
                              icon: Icons.call_outlined,
                              caption: 'Telephony',
                              label: 'Phone',
                              child: Text(
                                phone,
                                style: missing(valueStyle, phone),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _DetailTile(
                              icon: Icons.admin_panel_settings_outlined,
                              caption: 'Access role',
                              label: 'Account type',
                              iconBg: const Color(0xFFF5F3FF),
                              iconFg: const Color(0xFF7C3AED),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: SoftBadge(
                                  label: role,
                                  background: const Color(0xFFF5F3FF),
                                  foreground: const Color(0xFF7C3AED),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: width,
                            child: _DetailTile(
                              icon: Icons.fingerprint_rounded,
                              caption: 'UUID v4',
                              label: 'User ID',
                              iconBg: const Color(0xFFF0F9FF),
                              iconFg: const Color(0xFF0284C7),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: SelectableText(
                                      uuid,
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF334155),
                                      ),
                                    ),
                                  ),
                                  if (uuid != 'Not provided')
                                    IconButton(
                                      tooltip: 'Copy user ID',
                                      visualDensity: VisualDensity.compact,
                                      onPressed: () =>
                                          _copy(uuid, 'User ID'),
                                      icon: Icon(Icons.copy_rounded,
                                          size: 18,
                                          color: colors.textMuted),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Joined
                  AdminCard(
                    padding: const EdgeInsets.all(22),
                    child: Wrap(
                      spacing: 20,
                      runSpacing: 14,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const AdminIconTile(
                              icon: Icons.event_available_outlined,
                              size: 44,
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Joined', style: textTheme.bodySmall),
                                const SizedBox(height: 2),
                                Text(
                                  joined == null
                                      ? joinedRaw
                                      : DateFormat('MMM d, yyyy  ·  h:mm a')
                                          .format(joined),
                                  style: missing(valueStyle, joinedRaw),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (joined != null)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'ISO 8601 timestamp',
                                style: textTheme.labelMedium?.copyWith(
                                  color: colors.textSubtle,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                joinedRaw,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Icon(Icons.verified_user_outlined,
                          size: 18, color: colors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Signed in with platform-wide super admin access '
                          'across all EduSphere academies.',
                          style: textTheme.bodySmall?.copyWith(
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailTile extends StatelessWidget {
  const _DetailTile({
    required this.icon,
    required this.caption,
    required this.label,
    required this.child,
    this.iconBg,
    this.iconFg,
  });

  final IconData icon;
  final String caption;
  final String label;
  final Widget child;
  final Color? iconBg;
  final Color? iconFg;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return AdminCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AdminIconTile(
                icon: icon,
                size: 40,
                background: iconBg,
                foreground: iconFg,
              ),
              const Spacer(),
              Text(
                caption,
                style: textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(label, style: textTheme.bodySmall),
          const SizedBox(height: 4),
          SizedBox(height: 30, child: Align(
            alignment: Alignment.centerLeft,
            child: child,
          )),
        ],
      ),
    );
  }
}
