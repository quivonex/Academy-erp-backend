import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'firebase_options.dart';

// Firebase is independent of REST authentication. Its initialization must not
// prevent the first Flutter frame or the public course catalogue from loading.
final firebaseInitializationProvider = FutureProvider<FirebaseApp>((ref) {
  return Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
});

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: RolexAcademyApp()));
}

class RolexAcademyApp extends ConsumerWidget {
  const RolexAcademyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(firebaseInitializationProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'THE ROLEX ACADEMY',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      builder: (context, child) => _ExitConfirmation(
        router: router,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

/// Handles Android system back consistently across admin, student and public
/// screens. Back always returns to the dashboard; only the dashboard itself
/// requires a second press to close the app.
class _ExitConfirmation extends StatefulWidget {
  const _ExitConfirmation({
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  State<_ExitConfirmation> createState() => _ExitConfirmationState();
}

class _ExitConfirmationState extends State<_ExitConfirmation> {
  DateTime? _lastBackPressAt;

  Future<bool> _onWillPop() async {
    final currentPath =
        widget.router.routerDelegate.currentConfiguration.uri.path;

    // Every in-app back action returns to the dashboard instead of reopening
    // the previous screen in the navigation history.
    if (currentPath != '/dashboard') {
      widget.router.go('/dashboard');
      return false;
    }

    final now = DateTime.now();
    final pressedRecently = _lastBackPressAt != null &&
        now.difference(_lastBackPressAt!) < const Duration(seconds: 2);

    if (pressedRecently) return true;

    _lastBackPressAt = now;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: widget.child,
    );
  }
}
