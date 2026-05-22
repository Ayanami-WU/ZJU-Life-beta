import 'package:flutter_test/flutter_test.dart';
import 'package:zjulife/models/canteen.dart';

void main() {
  group('CanteenApiResponse', () {
    test('parses BOM-prefixed payload with string capacities', () {
      final response = CanteenApiResponse.fromRawJson(
        '\ufeff{"data":{"canteen_name":["紫金港东一"],'
        '"canteen_no":["1"],'
        '"canteen_num":["12"],'
        '"canteen_allowance":["1800"]}}',
      );

      expect(response.canteens, hasLength(1));
      expect(response.canteens.first.name, '紫金港东一');
      expect(response.canteens.first.currentCount, 12);
      expect(response.canteens.first.capacity, 1800);
    });

    test('parses numeric capacities', () {
      final response = CanteenApiResponse.fromJson({
        'data': {
          'canteen_name': ['紫金港东二'],
          'canteen_no': ['2'],
          'canteen_num': [34],
          'canteen_allowance': [1600],
        },
      });

      expect(response.canteens.first.currentCount, 34);
      expect(response.canteens.first.capacity, 1600);
    });

    test('throws for missing data object', () {
      expect(
        () => CanteenApiResponse.fromJson({'data': null}),
        throwsFormatException,
      );
    });
  });
}
