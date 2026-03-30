import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'logic/parent_flow_logic.dart';
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
import 'ui/change_pin_screen.dart';
import 'ui/bulk_import_screen.dart';

OnEnterResult _handleParentAreaTransition(
  WidgetRef ref,
  GoRouterState currentState,
  GoRouterState nextState,
) {
  final isLeavingParentArea = shouldResetParentAuth(
    currentLocation: currentState.uri.toString(),
    nextLocation: nextState.uri.toString(),
  );

  if (isLeavingParentArea) {
    ref.read(parentAuthProvider.notifier).state = false;
  }

  return const Allow();
}

String? _protectAdultRoute(WidgetRef ref, GoRouterState state) {
  return protectAdultRoute(
    isAuthenticated: ref.read(parentAuthProvider),
    nextLocation: state.uri.toString(),
  );
}

GoRouter createRouter(WidgetRef ref) {
  return GoRouter(
    initialLocation: '/',
    onEnter: (context, currentState, nextState, router) =>
        _handleParentAreaTransition(ref, currentState, nextState),
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
        ],
      ),
    ],
  );
}
