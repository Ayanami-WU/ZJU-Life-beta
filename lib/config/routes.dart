import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../screens/main_shell.dart';
import '../screens/home/home_screen.dart';
import '../screens/canteen/canteen_screen.dart';
import '../screens/bus/bus_screen.dart';
import '../screens/study/study_screen.dart';
import '../screens/study/library_webview_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/auth/login_screen.dart';
import '../screens/auth/cas_webview_screen.dart';

final GlobalKey<NavigatorState> _rootNavigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<NavigatorState> _shellNavigatorKey = GlobalKey<NavigatorState>();

final GoRouter appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: '/',
  routes: [
    // Main Shell with Bottom Navigation
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: '/',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: HomeScreen(),
          ),
        ),
        GoRoute(
          path: '/canteen',
          pageBuilder: (context, state) {
            final canteenId = state.uri.queryParameters['canteenId'];
            final windowId = state.uri.queryParameters['windowId'];
            return NoTransitionPage(
              child: CanteenScreen(
                highlightCanteenId: canteenId,
                highlightWindowId: windowId,
              ),
            );
          },
        ),
        GoRoute(
          path: '/bus',
          pageBuilder: (context, state) {
            final routeId = state.uri.queryParameters['routeId'];
            final stopId = state.uri.queryParameters['stopId'];
            return NoTransitionPage(
              child: BusScreen(
                highlightRouteId: routeId,
                highlightStopId: stopId,
              ),
            );
          },
        ),
        GoRoute(
          path: '/study',
          pageBuilder: (context, state) {
            final roomId = state.uri.queryParameters['roomId'];
            final seatId = state.uri.queryParameters['seatId'];
            return NoTransitionPage(
              child: StudyScreen(
                highlightRoomId: roomId,
                highlightSeatId: seatId,
              ),
            );
          },
        ),
        GoRoute(
          path: '/profile',
          pageBuilder: (context, state) => const NoTransitionPage(
            child: ProfileScreen(),
          ),
        ),
      ],
    ),
    
    // Auth Routes (outside shell)
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: '/cas-auth',
      builder: (context, state) => const CasWebViewScreen(),
    ),
    
    // WebView Routes
    GoRoute(
      path: '/library-webview',
      builder: (context, state) => const LibraryWebViewScreen(),
    ),
  ],
);
