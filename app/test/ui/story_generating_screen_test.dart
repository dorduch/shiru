import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shiru/models/storytime_models.dart';
import 'package:shiru/providers/storytime_providers.dart';
import 'package:shiru/services/auth_repository.dart';
import 'package:shiru/services/key_value_store.dart';
import 'package:shiru/services/story_generation_repository.dart';
import 'package:shiru/theme/app_theme.dart';
import 'package:shiru/ui/storytime_screens.dart';

class _FakeKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key}) async => data[key];

  @override
  Future<void> write({required String key, required String value}) async {
    data[key] = value;
  }

  @override
  Future<void> delete({required String key}) async {
    data.remove(key);
  }
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository(this._user);
  final AuthUser _user;

  @override
  Stream<AuthUser?> authStateChanges() => Stream.value(_user);

  @override
  AuthUser? get currentUser => _user;

  @override
  Future<void> createWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithEmail(String email, String password) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signInWithApple() async {}

  @override
  Future<void> sendPasswordReset(String email) async {}

  @override
  Future<void> signOut() async {}

  @override
  Future<void> deleteCurrentUser() async {}
}

/// Records `createJob` calls and lets the test drive `watchJob` streams by
/// job id, so a single fake exercises both the expired-job dead-end (1.3)
/// and the duplicate-in-flight-job guard (2.2).
class _FakeStoryGenerationRepository implements StoryGenerationRepository {
  int createJobCallCount = 0;
  String? lastWatchedJobId;
  final Map<String, StreamController<StoryJob>> _controllers = {};

  StreamController<StoryJob> controllerFor(String jobId) =>
      _controllers.putIfAbsent(
        jobId,
        () => StreamController<StoryJob>.broadcast(),
      );

  @override
  Future<CreateStoryJobResult> createJob({
    required StoryDraft draft,
    required AgeBand ageBand,
    required String idempotencyKey,
  }) async {
    createJobCallCount++;
    return const CreateStoryJobResult(jobId: 'freshly-minted-job', remaining: 9);
  }

  @override
  Stream<StoryJob> watchJob(String uid, String jobId) {
    lastWatchedJobId = jobId;
    return controllerFor(jobId).stream;
  }

  @override
  Future<void> confirmImported(String jobId) async {}

  @override
  Future<void> joinFamilyVoiceWaitlist() async {}

  @override
  Future<void> deleteAccountData() async {}
}

/// Pumps several frames so a chain of provider futures (auth state → child
/// profile → active-job marker, each a hop through the microtask queue) has
/// enough turns to fully resolve. A bare `pumpAndSettle` won't do here while
/// the loading state is showing an indeterminate `LinearProgressIndicator`
/// (it never "settles").
Future<void> _drain(WidgetTester tester, {int times = 12}) async {
  for (var i = 0; i < times; i++) {
    // A non-zero duration (rather than a bare `pump()`) also advances the
    // fake-async zone's virtual clock, which some `StreamSubscription
    // .cancel()` implementations need a tick of in addition to a microtask
    // flush.
    await tester.pump(const Duration(milliseconds: 20));
  }
}

const _uid = 'u1';
const _user = AuthUser(uid: _uid, email: 'parent@example.com', providerIds: ['password']);

Future<void> _seedChildProfile(_FakeKeyValueStore store) => store.write(
      key: 'storytime_child_profile_$_uid',
      value: jsonEncode(
        const ChildProfile(
          name: 'Ari',
          ageBand: AgeBand.early,
          avatarSpriteKey: 'sunny-fox',
        ).toJson(),
      ),
    );

GoRouter _buildRouter(String initialLocation) => GoRouter(
      initialLocation: initialLocation,
      routes: [
        GoRoute(
          path: '/generate',
          builder: (context, state) => StoryGeneratingScreen(
            existingJobId: state.uri.queryParameters['jobId'],
          ),
        ),
        GoRoute(
          path: '/compose',
          builder: (context, state) => const Scaffold(body: Text('COMPOSER')),
        ),
        GoRoute(
          path: '/home',
          builder: (context, state) => const Scaffold(body: Text('HOME')),
        ),
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(body: SizedBox()),
        ),
      ],
    );

void main() {
  testWidgets(
    '1.3: a ready job with a missing download URL shows a dead end and '
    'clears the active-job marker, instead of looping',
    (tester) async {
      final store = _FakeKeyValueStore();
      await _seedChildProfile(store);
      await store.write(key: 'storytime_active_job_$_uid', value: 'job1');
      final repo = _FakeStoryGenerationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository(_user)),
            storyGenerationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
            theme: StorytimeTheme.bedtime,
            routerConfig: _buildRouter('/generate?jobId=job1'),
          ),
        ),
      );
      // Let initState's Future.microtask(_start) run and subscribe.
      await _drain(tester);

      repo.controllerFor('job1').add(
            const StoryJob(
              id: 'job1',
              status: StoryJobStatus.ready,
              theme: StoryTheme.bedtime,
              narratorKey: NarratorKey.wizardWally,
              title: 'An old story',
              downloadUrl: null,
            ),
          );
      // The dead-end swaps out the indeterminate `LinearProgressIndicator`,
      // so once it lands, no more frames are scheduled and this settles.
      await tester.pumpAndSettle();

      expect(find.text('Make it again'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
      expect(await store.read(key: 'storytime_active_job_$_uid'), isNull);

      await tester.tap(find.text('Make it again'));
      await tester.pumpAndSettle();
      expect(find.text('COMPOSER'), findsOneWidget);
    },
  );

  testWidgets(
    '2.2: with no jobId in the route but a live marker, resumes the marked '
    'job instead of minting a new one',
    (tester) async {
      final store = _FakeKeyValueStore();
      await _seedChildProfile(store);
      await store.write(key: 'storytime_active_job_$_uid', value: 'marked-job');
      final repo = _FakeStoryGenerationRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            keyValueStoreProvider.overrideWithValue(store),
            authRepositoryProvider.overrideWithValue(_FakeAuthRepository(_user)),
            storyGenerationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp.router(
            theme: StorytimeTheme.bedtime,
            routerConfig: _buildRouter('/generate'),
          ),
        ),
      );
      await _drain(tester);

      expect(repo.createJobCallCount, 0);
      expect(repo.lastWatchedJobId, 'marked-job');
      // The non-error (loading) state now has its own "Back home" control
      // (spec §2.2), not just the error branch.
      expect(find.text('Back home'), findsOneWidget);
    },
  );
}
