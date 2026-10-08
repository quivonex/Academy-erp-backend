import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';
import '../../../core/theme/app_colors.dart';
import 'widgets/student_ui.dart';

class StudentShell extends ConsumerWidget {
  const StudentShell({
    super.key,
    required this.child,
    required this.location,
  });

  final Widget child;
  final String location;

  String? get _backFallback {
    if (location.startsWith('/student/course-payment/')) {
      return '/student/courses';
    }

    if (location.startsWith('/student/courses/')) {
      return '/student/courses';
    }

    if (location.startsWith('/student/live-classes/')) {
      return '/student/live-classes';
    }

    if (location.startsWith('/student/assignments/') &&
        location.endsWith('/result')) {
      return location.substring(
        0,
        location.length - '/result'.length,
      );
    }

    if (location.startsWith('/student/materials/') ||
        location.startsWith('/student/assignments/')) {
      return '/student/courses';
    }

    if (location.startsWith('/student/fees') ||
        location.startsWith('/student/notifications')) {
      return '/student/courses';
    }

    return null;
  }

  String get _title {
    if (location.startsWith('/student/notifications')) {
      return 'Notifications';
    }

    if (location.startsWith('/student/fees')) {
      return 'My Fees';
    }

    if (location.startsWith('/student/course-payment/')) {
      return 'Fees & Enrollment';
    }

    if (location.startsWith('/student/profile')) {
      return 'Profile';
    }

    if (location.startsWith('/student/live-classes/')) {
      return 'Live Class';
    }

    if (location.startsWith('/student/live-classes')) {
      return 'Live Classes';
    }

    if (location.startsWith('/student/materials/')) {
      return 'Study Material';
    }

    if (location.startsWith('/student/assignments/') &&
        location.endsWith('/result')) {
      return 'Result';
    }

    if (location.startsWith('/student/assignments/')) {
      return 'Assignment';
    }

    if (location.startsWith('/student/courses/')) {
      return 'Course';
    }

    return 'My Courses';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final session = ref.watch(sessionControllerProvider);
    final backFallback = _backFallback;

    final selected = location.startsWith('/student/profile')
        ? 3
        : location.startsWith('/student/live-classes')
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
            : IconButton(
                tooltip: 'Back',
                icon: const Icon(
                  Icons.arrow_back_rounded,
                ),
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go(backFallback);
                  }
                },
              ),
        title: StudentBarTitle(
          eyebrow: session.firmName,
          title: _title,
        ),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Icon(
              location.startsWith('/student/notifications')
                  ? Icons.notifications_rounded
                  : Icons.notifications_outlined,
              color:
                  location.startsWith('/student/notifications')
                      ? colors.primary
                      : colors.textPrimary,
            ),
            onPressed: () {
              if (!location.startsWith('/student/notifications')) {
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
