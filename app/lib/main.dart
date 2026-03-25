import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'providers/auth_provider.dart';
import 'router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  WakelockPlus.enable();

  runApp(
    const ProviderScope(
      child: ShiruApp(),
    ),
  );
}

class ShiruApp extends ConsumerStatefulWidget {
  const ShiruApp({Key? key}) : super(key: key);

  @override
  ConsumerState<ShiruApp> createState() => _ShiruAppState();
}

class _ShiruAppState extends ConsumerState<ShiruApp> with WidgetsBindingObserver {
  late final _router = createRouter(ref);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      ref.read(parentAuthProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp.router(
        title: 'Shiru',
        locale: const Locale('en'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('en', ''),
        ],
        theme: ThemeData(
          scaffoldBackgroundColor: const Color(0xFFFFFBEB),
          fontFamily: 'sans-serif',
        ),
        routerConfig: _router,
      ),
    );
  }
}
