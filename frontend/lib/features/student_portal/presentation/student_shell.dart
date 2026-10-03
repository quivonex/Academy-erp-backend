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

    return null;
  }

  String get _title {
    if (location.startsWith('/student/profile')) return 'Profile';
    if (location.startsWith('/student/live-classes/')) return 'Live Class';
    if (location.startsWith('/student/live-classes')) return 'Live Classes';
    if (location.startsWith('/student/materials/')) return 'Study Material';
    if (location.startsWith('/student/assignments/') &&
        location.endsWith('/result')) {
      return 'Result';
    }
    if (location.startsWith('/student/assignments/')) return 'Assignment';
    if (location.startsWith('/student/courses/')) return 'Course';
    return 'My Courses';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backFallback = _backFallback;
    final colors = context.colors;

    final selected = location.startsWith('/student/profile')
        ? 3
        : location.startsWith('/student/live-classes')
            ? 2
            : 1;

    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        toolbarHeight: 68,
        leadingWidth: backFallback == null ? 68 : 56,
        titleSpacing: backFallback == null ? 4 : 0,
        leading: backFallback == null
            ? const Padding(
                padding: EdgeInsets.only(left: 16),
                child: Center(child: AcademyMark(size: 40)),
              )
            : IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'Back',
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
          PopupMenuButton<String>(
            tooltip: 'More',
            icon: Icon(Icons.more_vert_rounded, color: colors.textPrimary),
            onSelected: (value) async {
              if (value != 'logout') return;

              try {
                await ref.read(sessionControllerProvider.notifier).logout();
              } on ApiException catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.message)),
                  );
                }
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                enabled: false,
                child: Row(
                  children: [
                    Icon(Icons.apartment_rounded,
                        size: 18, color: colors.textMuted),
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
              PopupMenuItem(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.logout_rounded,
                        size: 18, color: colors.danger),
                    const SizedBox(width: 10),
                    Text('Log out', style: TextStyle(color: colors.danger)),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 2),
            child: Center(
              child: Tooltip(
              message: 'Profile',
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => context.go('/student/profile'),
                child: CircleAvatar(
                  radius: 20,
                  backgroundColor: selected == 3
                      ? colors.primaryTonal
                      : colors.primaryDeep,
                  child: Icon(
                    Icons.person_rounded,
                    size: 22,
                    color: selected == 3 ? colors.primary : Colors.white,
                  ),
                ),
              ),
            ),
            ),
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: StudentBottomNav(selectedIndex: selected),
    );
  }
}
