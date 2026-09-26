import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/session/session_controller.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backFallback = _backFallback;

    final selected = location.startsWith('/student/profile')
        ? 3
        : location.startsWith('/student/live-classes')
        ? 2
        : 1;

    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: backFallback == null
            ? null
            : IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(backFallback);
            }
          },
        ),
        title: const Text('Academy Learning'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value != 'logout') return;

              try {
                await ref
                    .read(sessionControllerProvider.notifier)
                    .logout();
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
                child: Text(session.firmName ?? 'Student'),
              ),
              const PopupMenuItem(
                value: 'logout',
                child: Text('Log out'),
              ),
            ],
          ),
        ],
      ),
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selected,
        onDestinationSelected: (index) {
          switch (index) {
            case 0:
              context.go('/explore');
              break;
            case 1:
              context.go('/student/courses');
              break;
            case 2:
              context.go('/student/live-classes');
              break;
            case 3:
              context.go('/student/profile');
              break;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'My Courses',
          ),
          NavigationDestination(
            icon: Icon(Icons.video_camera_front_outlined),
            label: 'Classes',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}