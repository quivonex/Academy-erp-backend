import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/back_button.dart';
import 'widgets/student_ui.dart';

class StudentShell extends ConsumerWidget {
  const StudentShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  String? _getBackFallback(String loc) {
    final path = loc.split('?').first;
    if (path == '/student/courses' || path == '/student/courses/') {
      return null;
    }

    if (path.startsWith('/student/live-classes/')) {
      return '/student/live-classes';
    }

    if (path.startsWith('/student/assignments/') &&
        path.endsWith('/result')) {
      return path.substring(
        0,
        path.length - '/result'.length,
      );
    }

    return '/student/courses';
  }

  String _getTitle(String loc) {
    final path = loc.split('?').first;

    if (path.startsWith('/student/notifications')) {
      return 'Notifications';
    }

    if (path.startsWith('/student/fees')) {
      return 'My Fees';
    }

    if (path.startsWith('/student/course-payment/')) {
      return 'Fees & Enrollment';
    }

    if (path.startsWith('/student/profile')) {
      return 'Profile';
    }

    if (path.startsWith('/student/live-classes/')) {
      return 'Live Class';
    }

    if (path.startsWith('/student/live-classes')) {
      return 'Live Classes';
    }

    if (path.startsWith('/student/materials/')) {
      return 'Study Material';
    }

    if (path.startsWith('/student/assignments/') &&
        path.endsWith('/result')) {
      return 'Result';
    }

    if (path.startsWith('/student/assignments/')) {
      return 'Assignment';
    }

    if (path.startsWith('/student/courses/')) {
      return 'Course Details';
    }

    return 'My Courses';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider);

    String currentPath;
    try {
      currentPath = GoRouterState.of(context).uri.path;
    } catch (_) {
      currentPath = location;
    }

    final backFallback = _getBackFallback(currentPath);
    final title = _getTitle(currentPath);

    final selected = currentPath.startsWith('/student/profile')
        ? 3
        : currentPath.startsWith('/student/live-classes')
            ? 2
            : 1;

    PopupMenuItem<String> menuItem({
      required String value,
      required String label,
      required IconData icon,
      bool danger = false,
    }) {
      return PopupMenuItem<String>(
        value: value,
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: danger
                  ? colors.danger
                  : colors.textPrimary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: danger
                    ? colors.danger
                    : colors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        toolbarHeight: 68,
        leadingWidth: backFallback == null ? 68 : 56,
        titleSpacing: backFallback == null ? 4 : 0,
        leading: backFallback == null
            ? const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Center(
                  child: AcademyMark(size: 40),
                ),
              )
            : AppBackButton(
                fallbackRoute: backFallback,
                color: colors.textPrimary,
                iconSize: 24,
              ),
        title: StudentBarTitle(
          eyebrow: session.firmName,
          title: title,
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Icon(
              currentPath.startsWith('/student/notifications')
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              color:
                  currentPath.startsWith('/student/notifications')
                      ? colors.primary
                      : colors.textPrimary,
            ),
            onPressed: () {
              if (!currentPath.startsWith('/student/notifications')) {
                context.go('/student/notifications');
              }
            },
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(
              Icons.more_vert_rounded,
              color: colors.textPrimary,
            ),
            onSelected: (value) async {
              switch (value) {
                case 'courses':
                  context.go('/student/courses');
                  return;
                case 'fees':
                  context.go('/student/fees');
                  return;
                case 'notifications':
                  context.go('/student/notifications');
                  return;
                case 'live-classes':
                  context.go('/student/live-classes');
                  return;
                case 'profile':
                  context.go('/student/profile');
                  return;
                case 'logout':
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
                    await ref
                        .read(sessionControllerProvider.notifier)
                        .logout();
                  } catch (error) {
                    if (!context.mounted) return;

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          error is ApiException
                              ? error.message
                              : 'Could not log out. Please retry.',
                        ),
                      ),
                    );
                  }
                  return;
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Row(
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 18,
                      color: colors.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        session.firmName ?? 'Student',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              menuItem(
                value: 'courses',
                label: 'My Courses',
                icon: Icons.menu_book_outlined,
              ),
              menuItem(
                value: 'fees',
                label: 'My Fees',
                icon: Icons.receipt_long_outlined,
              ),
              menuItem(
                value: 'notifications',
                label: 'Notifications',
                icon: Icons.notifications_outlined,
              ),
              menuItem(
                value: 'live-classes',
                label: 'Live Classes',
                icon: Icons.video_camera_front_outlined,
              ),
              menuItem(
                value: 'profile',
                label: 'Profile',
                icon: Icons.person_outline_rounded,
              ),
              const PopupMenuDivider(),
              menuItem(
                value: 'logout',
                label: 'Log out',
                icon: Icons.logout_rounded,
                danger: true,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(
              right: 16,
              left: 2,
            ),
            child: Center(
              child: Tooltip(
                message: 'Profile',
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    context.go('/student/profile');
                  },
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: selected == 3
                        ? colors.primaryTonal
                        : colors.primaryDeep,
                    child: Icon(
                      Icons.person_rounded,
                      size: 22,
                      color: selected == 3
                          ? colors.primary
                          : Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: StudentBottomNav(
        selectedIndex: selected,
      ),
    );
  }
}
