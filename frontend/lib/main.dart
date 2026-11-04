import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    );
  }
}