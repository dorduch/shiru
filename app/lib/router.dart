import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'ui/kid_home_screen.dart';
import 'ui/pin_gate_screen.dart';
import 'ui/parent_list_screen.dart';
import 'ui/parent_edit_screen.dart';

final GoRouter appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const KidHomeScreen(),
    ),
    GoRoute(
      path: '/pin',
      builder: (context, state) => const PinGateScreen(),
    ),
    GoRoute(
      path: '/parent',
      builder: (context, state) => const ParentListScreen(),
      routes: [
        GoRoute(
          path: 'edit',
          builder: (context, state) {
            final cardId = state.extra as String?;
            return ParentEditScreen(cardId: cardId);
          }
        )
      ]
    ),
  ],
);
