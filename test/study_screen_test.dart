import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zjulife/models/library.dart';
import 'package:zjulife/providers/auth_provider.dart';
import 'package:zjulife/providers/favorites_provider.dart';
import 'package:zjulife/screens/study/study_room_screen.dart';
import 'package:zjulife/screens/study/study_screen.dart';
import 'package:zjulife/services/library_service.dart';

void main() {
  testWidgets('Study screen asks for CAS login before loading library data', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final router = _buildRouter();

    await tester.pumpWidget(_TestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('登录后查看座位'), findsOneWidget);
    expect(find.text('去登录'), findsOneWidget);
  });

  testWidgets('Study screen loads injected rooms without login prompt', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeLibraryService();
    final router = _buildRouter(service: service);

    await tester.pumpWidget(_TestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.text('登录后查看座位'), findsNothing);
    expect(find.text('阅览室 A'), findsOneWidget);
    expect(find.text('座位概览'), findsOneWidget);
  });

  testWidgets('Tapping a room opens the room map page', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeLibraryService();
    final router = _buildRouter(service: service);

    await tester.pumpWidget(_TestApp(router: router));
    await tester.pumpAndSettle();

    await tester.tap(find.text('阅览室 A'));
    await tester.pumpAndSettle();

    expect(find.text('暂无可用地图，已切换为座位列表'), findsOneWidget);
    expect(find.text('001'), findsOneWidget);
    expect(find.text('空闲'), findsWidgets);
  });

  testWidgets('Room page renders map viewer and seat points with a map', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final service = _FakeLibraryService(
      map: const LibraryRoomMap(config: 'https://example.com/map.png'),
    );
    final router = _buildRouter(
      service: service,
      initialLocation: '/study/room/room-1',
    );

    await tester.pumpWidget(_TestApp(router: router));
    await tester.pumpAndSettle();

    expect(find.byType(InteractiveViewer), findsOneWidget);
    expect(find.byTooltip('001 · 空闲'), findsOneWidget);
  });
}

GoRouter _buildRouter({
  LibraryService? service,
  String initialLocation = '/study',
}) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(
        path: '/study',
        builder: (context, state) => service == null
            ? const StudyScreen()
            : StudyScreen(libraryService: service),
      ),
      GoRoute(
        path: '/study/room/:roomId',
        builder: (context, state) {
          final roomId = state.pathParameters['roomId'] ?? '';
          if (service == null) return StudyRoomScreen(roomId: roomId);
          return StudyRoomScreen(roomId: roomId, libraryService: service);
        },
      ),
    ],
  );
}

class _TestApp extends StatelessWidget {
  final GoRouter router;

  const _TestApp({required this.router});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => FavoritesProvider()),
      ],
      child: MaterialApp.router(routerConfig: router),
    );
  }
}

class _FakeLibraryService extends LibraryService {
  final LibraryRoomMap map;

  _FakeLibraryService({this.map = const LibraryRoomMap()}) : super();

  static const room = LibraryRoomNode(
    id: 'room-1',
    name: '阅览室 A',
    libraryName: '紫金港图书馆',
    floorName: '一楼',
  );

  static const seats = [
    LibrarySeatDetail(
      id: '1',
      no: '001',
      name: '001',
      area: 'room-1',
      status: '1',
      statusName: '空闲',
      pointX: 20,
      pointY: 30,
    ),
    LibrarySeatDetail(
      id: '2',
      no: '002',
      name: '002',
      area: 'room-1',
      status: '2',
      statusName: '占用',
      pointX: 60,
      pointY: 45,
    ),
  ];

  @override
  Future<List<LibrarySeat>> fetchAllSeats({bool useCache = true}) async {
    return [LibrarySeat.fromRoom(room: room, seats: seats)];
  }

  @override
  Future<LibraryRoomDetail> fetchRoomDetail(
    String roomId, {
    bool useCache = true,
  }) async {
    return LibraryRoomDetail(
      room: room,
      seats: seats,
      map: map,
    );
  }
}
