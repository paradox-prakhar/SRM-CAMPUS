import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'application/app_state.dart';
import 'data/local_auth.dart';
import 'data/services.dart';
import 'presentation/explorer.dart';
import 'presentation/screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.initialize();
  await LocalAuth.restore();
  runApp(const ProviderScope(child: CampusApp()));
}

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (_, _) => const WelcomeScreen()),
    GoRoute(path: '/explore', builder: (_, _) => const ExplorerScreen()),
    GoRoute(path: '/auth', builder: (_, _) => const AuthScreen()),
    GoRoute(
      path: '/indoor/:id',
      builder: (_, s) => IndoorScreen(buildingId: s.pathParameters['id']!),
    ),
    GoRoute(path: '/sharing', builder: (_, _) => const SharingScreen()),
    GoRoute(path: '/friends', builder: (_, _) => const FriendsScreen()),
    GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    GoRoute(path: '/admin', builder: (_, _) => const AdminScreen()),
  ],
);

class CampusApp extends ConsumerWidget {
  const CampusApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp.router(
    title: 'SRM AP • Campus Navigator',
    debugShowCheckedModeBanner: false,
    theme: campusTheme(false),
    darkTheme: campusTheme(true),
    themeMode: ref.watch(appProvider).dark ? ThemeMode.dark : ThemeMode.light,
    routerConfig: _router,
  );
}
