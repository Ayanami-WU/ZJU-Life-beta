import 'package:flutter_test/flutter_test.dart';
import 'package:zjulife/models/library.dart';
import 'package:zjulife/services/library_service.dart';

void main() {
  group('LibraryService seat API parsing', () {
    test('flattens room nodes and inherits library and floor names', () {
      final rooms = LibraryService.flattenRoomTree([
        {
          'id': 'lib-1',
          'name': '紫金港图书馆',
          'levels': '1',
          'children': [
            {
              'id': 'floor-1',
              'name': '一楼',
              'levels': '2',
              'children': [
                {
                  'id': 'room-1',
                  'name': '阅览室 A',
                  'levels': '3',
                  'type': '1',
                  'image_url': '/map/a.png',
                },
                {'id': 'room-2', 'name': '设备区', 'levels': '3', 'type': '2'},
              ],
            },
          ],
        },
      ]);

      expect(rooms, hasLength(1));
      expect(rooms.single.id, 'room-1');
      expect(rooms.single.libraryName, '紫金港图书馆');
      expect(rooms.single.floorName, '一楼');
      expect(rooms.single.imageUrl, 'https://booking.lib.zju.edu.cn/map/a.png');
    });

    test('summarizes total seats, free seats, and status counts', () {
      const room = LibraryRoomNode(
        id: 'room-1',
        name: '阅览室 A',
        libraryName: '紫金港图书馆',
        floorName: '一楼',
      );
      const seats = [
        LibrarySeatDetail(
          id: '1',
          no: '001',
          name: '001',
          area: 'room-1',
          status: '1',
          statusName: '空闲',
        ),
        LibrarySeatDetail(
          id: '2',
          no: '002',
          name: '002',
          area: 'room-1',
          status: '2',
          statusName: '占用',
        ),
      ];

      final summary = LibraryService.summarizeRoom(room, seats);

      expect(summary.totalNum, 2);
      expect(summary.freeNum, 1);
      expect(summary.statusCounts, {'空闲': 1, '占用': 1});
    });

    test('parses reserve room list response with code 0 shape', () {
      final rooms = LibraryService.parseReserveRoomList({
        'code': 0,
        'data': {
          'list': [
            {
              'id': '58',
              'name': '二层南',
              'nameMerge': '主馆-二层-二层南',
              'type_name': '普通座位',
              'storeyName': '二层',
              'premisesName': '主馆',
              'firstimg': '/home/images/first/area/58/2FS.jpg',
              'total_num': 32,
              'free_num': 2,
            },
          ],
          'count': 1,
        },
        'msg': '成功',
      });

      expect(rooms, hasLength(1));
      expect(rooms.single.id, '58');
      expect(rooms.single.location, '主馆 · 二层');
      expect(rooms.single.totalNum, 32);
      expect(rooms.single.freeNum, 2);
    });

    test('builds official reserve list payload for ordinary seats', () {
      const query = LibrarySeatQuery(day: '2026-05-21');

      expect(query.toReserveListPayload(page: 1, size: 10), {
        'id': '1',
        'date': '2026-05-21',
        'categoryIds': ['1'],
        'members': 0,
        'page': 1,
        'size': 10,
      });
    });

    test('formats query date in China timezone', () {
      expect(
        LibraryService.formatChinaDate(DateTime.utc(2026, 5, 21, 15, 59)),
        '2026-05-21',
      );
      expect(
        LibraryService.formatChinaDate(DateTime.utc(2026, 5, 21, 16)),
        '2026-05-22',
      );
    });

    test('normalizes library authorization to official bearer format', () {
      expect(
        LibraryService.normalizeAuthorizationHeader('abc.def.ghi'),
        'bearerabc.def.ghi',
      );
      expect(
        LibraryService.normalizeAuthorizationHeader('bearerabc.def.ghi'),
        'bearerabc.def.ghi',
      );
      expect(
        LibraryService.normalizeAuthorizationHeader('Bearer abc.def.ghi'),
        'bearerabc.def.ghi',
      );
    });

    test('selects map image in config, free, imageUrl order', () {
      expect(
        const LibraryRoomMap(
          config: 'config.png',
          free: 'free.png',
          imageUrl: 'fallback.png',
        ).preferredImageUrl,
        'config.png',
      );
      expect(
        const LibraryRoomMap(
          free: 'free.png',
          imageUrl: 'fallback.png',
        ).preferredImageUrl,
        'free.png',
      );
      expect(
        const LibraryRoomMap(imageUrl: 'fallback.png').preferredImageUrl,
        'fallback.png',
      );
    });

    test('keeps unknown status labels displayable', () {
      final seat = LibrarySeatDetail.fromJson({
        'id': '9',
        'no': '009',
        'area': 'room-1',
        'status': '9',
        'status_name': '维护中',
      });

      expect(seat.isFree, isFalse);
      expect(seat.statusLabel, '维护中');
      expect(seat.displayName, '009');
    });
  });
}
