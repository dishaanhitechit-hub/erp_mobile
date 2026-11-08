import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/app_theme.dart';
import 'services/api_service.dart';
import 'services/call_service.dart';
import 'services/offline_store.dart';
import 'screens/auth/login_screen.dart';
import 'screens/shell/main_shell.dart';
import 'widgets/offline_banner.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await ThemeController.instance.load(); // also sets the status-bar style
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final loggedIn = await ApiService.instance.isLoggedIn();
  await Outbox.instance.load();
  NetworkStatus.instance.start();
  runApp(ErpApp(initialRoute: loggedIn ? '/home' : '/login'));
}

class ErpApp extends StatelessWidget {
  final String initialRoute;
  const ErpApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeController.instance,
      builder: (context, palette, _) => MaterialApp(
        title: 'PRAX ERP',
        navigatorKey: appNavigatorKey,
        theme: AppTheme.theme,
        debugShowCheckedModeBanner: false,
        initialRoute: initialRoute,
        builder: (context, child) => OfflineBanner(child: child ?? const SizedBox()),
        routes: {
          '/login': (_) => const LoginScreen(),
          '/home':  (_) => const MainShell(),
        },
      ),
    );
  }
}
