import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'firebase_options.dart';
import 'logic/auth_lifecycle_logic.dart';
import 'services/analytics_service.dart';
import 'services/app_paths.dart';
import 'providers/auth_provider.dart';
import 'providers/cards_provider.dart';
import 'providers/categories_provider.dart';
import 'router.dart';
import 'screenshot_mode.dart';
import 'services/screenshot_seed_service.dart';
import 'services/storytime_migration_service.dart';
import 'services/diagnostics_preferences_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppPaths.init();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Local-emulator mode for dev verification only:
  //   flutter run --dart-define=USE_EMULATOR=true [--dart-define=EMULATOR_HOST=127.0.0.1]
  // Points all Firebase SDKs at the local Emulator Suite, skips App Check (the
  // emulator doesn't enforce it), and signs in anonymously so callables get a uid.
  // Never enabled in a normal/release build (the define defaults to false).
  const useEmulator = bool.fromEnvironment('USE_EMULATOR');
  if (useEmulator) {
    const host = String.fromEnvironment('EMULATOR_HOST', defaultValue: '127.0.0.1');
    FirebaseFirestore.instance.useFirestoreEmulator(host, 8080);
    FirebaseFunctions.instance.useFunctionsEmulator(host, 5001);
    await FirebaseStorage.instance.useStorageEmulator(host, 9199);
    await FirebaseAuth.instance.useAuthEmulator(host, 9099);
    // A keychain-cached prod user must not be reused against the emulator (its
    // token/uid don't exist there) — including a cached *anonymous* user, whose
    // token the emulator also can't validate, which makes callables fail
    // client-side before they ever reach the emulator. Always reset to a fresh
    // anonymous emulator user so every platform tests the same clean state.
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
    await FirebaseAuth.instance.signInAnonymously();
  } else {
    // Force the App Check *debug* provider even in a release/profile build via
    //   flutter run --release --dart-define=FORCE_APPCHECK_DEBUG=true
    // Used to test release builds on a device without iOS App Attest (which only
    // works for TestFlight/App Store-signed builds). Defaults to false, so normal
    // release builds keep using App Attest / Play Integrity.
    const forceAppCheckDebug = bool.fromEnvironment('FORCE_APPCHECK_DEBUG');
    final useDebugAppCheck = kDebugMode || forceAppCheckDebug;
    await FirebaseAppCheck.instance.activate(
      providerAndroid: useDebugAppCheck
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: useDebugAppCheck
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  }
  await StorytimeMigrationService().runIfNeeded();
  final diagnosticsEnabled = await DiagnosticsPreferencesService().isEnabled();
  await AnalyticsService.instance.ensureConsent(enabled: diagnosticsEnabled);
  await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(
    diagnosticsEnabled,
  );
  FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
  PlatformDispatcher.instance.onError = (error, stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
    return true;
  };

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  WakelockPlus.enable();
  if (kStoreScreenshotMode) {
    await ScreenshotSeedService.ensureSeeded();
  }

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
    if (kStoreScreenshotMode) {
      return;
    }
    final isExternalFileFlowActive = ref.read(
      parentAuthExternalFileFlowProvider,
    );
    if (shouldResetParentAuthForLifecycle(
      state: state,
      isExternalFileFlowActive: isExternalFileFlowActive,
    )) {
      ref.read(parentAuthProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MaterialApp.router(
        title: 'Storytime',
        locale: const Locale('en'),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', '')],
        theme: StorytimeTheme.day,
        darkTheme: StorytimeTheme.bedtime,
        // Pin to the day theme. Bedtime is NOT an OS-following dark mode: it is
        // applied per-screen (story reader, player, recording, launch flow) via
        // Theme(data: StorytimeTheme.bedtime). Following the system would skin
        // every day-designed screen (child setup, parent, home) dark, where
        // their light `paper` tiles and default text become unreadable.
        themeMode: ThemeMode.light,
        routerConfig: _router,
      ),
    );
  }
}
