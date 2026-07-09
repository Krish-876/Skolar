import 'package:Skolar/core/loading/loading_overlay.dart';
import 'package:Skolar/core/routing/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final RouteObserver<ModalRoute<void>> routeObserver =
    RouteObserver<ModalRoute<void>>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://nohxpwqlqdwqwptuvzyf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5vaHhwd3FscWR3cXdwdHV2enlmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzk3Nzk2NTcsImV4cCI6MjA5NTM1NTY1N30.eKdk942COAvD7368xtGYN3I06H0TvX0-60s8p6lKHiw',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  runApp(const ProviderScope(child: NovaApp()));
}

class NovaApp extends ConsumerWidget {
  const NovaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      routerConfig: goRouterProvider,
      title: 'Skolar',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        colorScheme: ColorScheme.dark(
          primary: Colors.deepPurple,
          surface: Colors.black,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => LoadingOverlay(child: child!),
    );
  }
}
