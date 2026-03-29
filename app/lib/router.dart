import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'providers/auth_provider.dart';
import 'ui/kid_home_screen.dart';
import 'ui/age_gate_screen.dart';
import 'ui/pin_gate_screen.dart';
import 'ui/parent_access_screen.dart';
import 'ui/parent_list_screen.dart';
import 'ui/parent_edit_screen.dart';
import 'ui/parent_categories_screen.dart';
import 'ui/parent_category_edit_screen.dart';
import 'models/category.dart';
import 'ui/story_builder_screen.dart';
import 'ui/change_pin_screen.dart';
import 'ui/voice_profiles_screen.dart';
import 'ui/voice_record_screen.dart';
import 'ui/bulk_import_screen.dart';

String _routeWithNext(String path, String nextLocation) {
  return Uri(path: path, queryParameters: {'next': nextLocation}).toString();
}

String? _protectAdultRoute(WidgetRef ref, GoRouterState state) {
  final nextLocation = state.uri.toString();
  final isAuthenticated = ref.read(parentAuthProvider);
  if (!isAuthenticated) {
    return _routeWithNext('/parent-access', nextLocation);
  }

  return null;
}

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const KidHomeScreen()),
      GoRoute(
        path: '/parent-access',
        builder: (context, state) => ParentAccessScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/age-check',
        builder: (context, state) => AgeGateScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/pin',
        builder: (context, state) => PinGateScreen(
          nextLocation: state.uri.queryParameters['next'] ?? '/parent',
        ),
      ),
      GoRoute(
        path: '/story-builder',
        redirect: (context, state) => _protectAdultRoute(ref, state),
        builder: (context, state) => const StoryBuilderScreen(),
      ),
      GoRoute(
        path: '/parent',
        redirect: (context, state) => _protectAdultRoute(ref, state),
        builder: (context, state) => const ParentListScreen(),
        routes: [
          GoRoute(
            path: 'edit',
            builder: (context, state) {
              final cardId = state.extra as String?;
              return ParentEditScreen(cardId: cardId);
            },
          ),
          GoRoute(
            path: 'change-pin',
            builder: (context, state) => const ChangePinScreen(),
          ),
          GoRoute(
            path: 'bulk-import',
            builder: (context, state) => const BulkImportScreen(),
          ),
          GoRoute(
            path: 'categories',
            builder: (context, state) => const ParentCategoriesScreen(),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) {
                  final category = state.extra as Category?;
                  return ParentCategoryEditScreen(category: category);
                },
              ),
            ],
          ),
          GoRoute(
            path: 'voices',
            builder: (context, state) => const VoiceProfilesScreen(),
            routes: [
              GoRoute(
                path: 'record',
                builder: (context, state) => const VoiceRecordScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
