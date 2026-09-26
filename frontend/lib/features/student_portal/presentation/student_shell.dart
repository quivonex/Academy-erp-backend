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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
    location.startsWith('/student/courses') ? 1 : 0;
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        leading: location.startsWith('/student/courses/')
            ? IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () =>
              context.go('/student/courses'),
        )
            : null,
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
        onDestinationSelected: (index) => context.go(
          index == 0 ? '/explore' : '/student/courses',
        ),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            label: 'Explore',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            label: 'My Courses',
          ),
        ],
      ),
    );
  }
}