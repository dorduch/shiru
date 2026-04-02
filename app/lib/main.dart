import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'firebase_options.dart';
import 'services/analytics_service.dart';
import 'providers/auth_provider.dart';
import 'providers/cards_provider.dart';
import 'providers/categories_provider.dart';
import 'router.dart';
import 'theme/app_colors.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await AnalyticsService.instance.ensureConsent();
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  WakelockPlus.enable();

  runApp(const ProviderScope(child: ShiruApp()));
}

class ShiruApp extends ConsumerStatefulWidget {
  const ShiruApp({super.key});

  @override
  ConsumerState<ShiruApp> createState() => _ShiruAppState();
}

class _ShiruAppState extends ConsumerState<ShiruApp>
    with WidgetsBindingObserver {
  late final _router = createRouter(ref);
  bool _statsLogged = false;
  ProviderSubscription<dynamic>? _cardsSubscription;
  ProviderSubscription<dynamic>? _categoriesSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logLibraryStatsOnceLoaded();
  }

  void _logLibraryStatsOnceLoaded() {
    _cardsSubscription = ref.listenManual(cardsProvider, (previous, next) {
      _tryLogLibraryStats();
    });
    _categoriesSubscription = ref.listenManual(categoriesProvider, (
      previous,
      next,
    ) {
      _tryLogLibraryStats();
    });
    _tryLogLibraryStats();
  }

  void _tryLogLibraryStats() {
    if (_statsLogged) return;

    final cards = ref.read(cardsProvider).valueOrNull;
    final categories = ref.read(categoriesProvider).valueOrNull;
    if (cards == null || categories == null) return;

    _statsLogged = true;
    AnalyticsService.instance.logLibraryStats(
      cardCount: cards.length,
      categoryCount: categories.length,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cardsSubscription?.close();
    _categoriesSubscription?.close();
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
        supportedLocales: const [Locale('en', '')],
        theme: ThemeData(
          scaffoldBackgroundColor: AppColors.background,
          fontFamily: 'sans-serif',
        ),
        routerConfig: _router,
      ),
    );
  }
}
