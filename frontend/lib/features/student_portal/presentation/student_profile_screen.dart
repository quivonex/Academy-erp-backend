import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/api_urls.dart';
import '../../../core/network/dio_provider.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/student_ui.dart';

String _prettyRole(String raw) {
  final value = raw.replaceAll('_', ' ').trim().toLowerCase();
  if (value.isEmpty || value == 'not provided') return 'Student';
  return value
      .split(' ')
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1))
      .join(' ');
}

class StudentProfileScreen
    extends ConsumerStatefulWidget {
  const StudentProfileScreen({super.key});

  @override
  ConsumerState<StudentProfileScreen> createState() =>
      _StudentProfileScreenState();
}

class _StudentProfileScreenState
    extends ConsumerState<StudentProfileScreen> {
  late Future<Map<String, dynamic>> _profile;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    _profile = _fetchProfile();
  }

  Future<Map<String, dynamic>> _fetchProfile() async {
    try {
      final response = await ref
          .read(dioProvider)
          .get(ApiUrls.me);

      final body = response.data;

      if (body is! Map || body['data'] is! Map) {
        throw const ApiException(
          'Invalid profile response.',
        );
      }

      return Map<String, dynamic>.from(
        body['data'] as Map,
      );
    } on DioException catch (error) {
      throw ApiException.fromDioException(error);
    }
  }

  Future<void> _refresh() async {
    final next = _fetchProfile();

    setState(() => _profile = next);

    try {
      await next;
    } catch (_) {
      // FutureBuilder खाली error दाखवेल.
    }
  }

  Future<void> _logout() async {
    if (_loggingOut) return;

    setState(() => _loggingOut = true);

    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .logout();

      // Session बदलल्यावर router login/explore कडे नेईल.
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Logout failed: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _loggingOut = false);
      }
    }
  }

  String _value(
      Map<String, dynamic> profile,
      String key,
      ) {
    final value =
        profile[key]?.toString().trim() ?? '';

    return value.isEmpty ? 'Not provided' : value;
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
                SizedBox(height: 100),
                Center(
                  child: CircularProgressIndicator(),
                ),
              ],
            );
          }

          if (snapshot.hasError) {
            return StudentPageFrame(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(kStudentPagePadding),
                children: [
                  StudentStateMessage(
                    icon: Icons.person_off_outlined,
                    title: 'Profile could not load',
                    message: '${snapshot.error}',
                    actionLabel: 'Try again',
                    onAction: _refresh,
                    isError: true,
                  ),
                  const SizedBox(height: 8),
                  _LogoutButton(loggingOut: _loggingOut, onPressed: _logout),
                ],
              ),
            );
          }

          final profile = snapshot.data!;

          final fullName = [
            profile['first_name']?.toString() ?? '',
            profile['last_name']?.toString() ?? '',
          ].where(
            (part) => part.trim().isNotEmpty,
          ).join(' ');

          final displayName =
              fullName.isEmpty ? _value(profile, 'email') : fullName;
          final firm = _value(profile, 'firm_name');
          final role = _prettyRole(_value(profile, 'user_type'));

          return StudentPageFrame(
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                kStudentPagePadding,
                4,
                kStudentPagePadding,
                28,
              ),
              children: [
                // Identity card
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: colors.borderSubtle),
                    boxShadow: colors.cardShadow,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Stack(
                      children: [
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          height: 86,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: colors.heroGradient,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 34, 20, 22),
                          child: Column(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Container(
                                    width: 96,
                                    height: 96,
                                    decoration: BoxDecoration(
                                      color: colors.primaryTonal,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 4,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      initialsOf(displayName, fallback: 'S'),
                                      style: textTheme.displayMedium?.copyWith(
                                        color: colors.primaryDeep,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 2,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: colors.success,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 3,
                                        ),
                                      ),
                                      child: const Icon(
                                        Icons.check_rounded,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on_outlined,
                                    size: 16,
                                    color: colors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      firm,
                                      overflow: TextOverflow.ellipsis,
                                      style: textTheme.bodyMedium?.copyWith(
                                        color: colors.textMuted,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              TonalPill(
                                label: role,
                                icon: Icons.school_rounded,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 10),
                  child: Text(
                    'Account details',
                    style: textTheme.titleSmall?.copyWith(
                      color: colors.textMuted,
                    ),
                  ),
                ),
                PremiumCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    children: [
                      _DetailRow(
                        icon: Icons.mail_outline_rounded,
                        label: 'Email address',
                        value: _value(profile, 'email'),
                      ),
                      _DetailRow(
                        icon: Icons.call_outlined,
                        label: 'Phone number',
                        value: _value(profile, 'phone'),
                      ),
                      _DetailRow(
                        icon: Icons.account_balance_outlined,
                        label: 'Academy',
                        value: firm,
                      ),
                      _DetailRow(
                        icon: Icons.badge_outlined,
                        label: 'Account type',
                        value: role,
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: colors.primaryDeep,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            role,
                            style: textTheme.labelSmall?.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                        showDivider: false,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _LogoutButton(loggingOut: _loggingOut, onPressed: _logout),
                const SizedBox(height: 14),
                Center(
                  child: Text(
                    'Pull down to refresh your profile',
                    style: textTheme.bodySmall?.copyWith(
                      color: colors.textSubtle,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.trailing,
    this.showDivider = true,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget? trailing;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final missing = value == 'Not provided';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              IconTile(icon: icon, size: 44, radius: 14),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: textTheme.labelMedium),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color:
                            missing ? colors.textSubtle : colors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing!,
              ],
            ],
          ),
        ),
        if (showDivider)
          Padding(
            padding: const EdgeInsets.only(left: 74, right: 16),
            child: Divider(height: 1, color: colors.borderSubtle),
          ),
      ],
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton({required this.loggingOut, required this.onPressed});

  final bool loggingOut;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: colors.dangerBg,
          foregroundColor: colors.danger,
          disabledBackgroundColor: colors.dangerBg.withValues(alpha: 0.6),
          disabledForegroundColor: colors.danger.withValues(alpha: 0.6),
          shape: const StadiumBorder(),
        ),
        onPressed: loggingOut ? null : onPressed,
        icon: loggingOut
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: colors.danger,
                ),
              )
            : const Icon(Icons.logout_rounded),
        label: Text(loggingOut ? 'Logging out…' : 'Log out'),
      ),
    );
  }
}
