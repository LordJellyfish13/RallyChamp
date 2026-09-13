import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/core/active_rally/my_rallies_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('MyRalliesStore', () {
    test('starts empty', () async {
      expect(await MyRalliesStore.rallyIds(), isEmpty);
    });

    test('recordVisit puts the newest rally first', () async {
      await MyRalliesStore.recordVisit('a');
      await MyRalliesStore.recordVisit('b');
      expect(await MyRalliesStore.rallyIds(), ['b', 'a']);
    });

    test('revisiting promotes without duplicating', () async {
      await MyRalliesStore.recordVisit('a');
      await MyRalliesStore.recordVisit('b');
      await MyRalliesStore.recordVisit('a');
      expect(await MyRalliesStore.rallyIds(), ['a', 'b']);
    });

    test('forget drops just that rally, keeping the rest in order', () async {
      await MyRalliesStore.recordVisit('a');
      await MyRalliesStore.recordVisit('b');
      await MyRalliesStore.recordVisit('c');
      await MyRalliesStore.forget('b');
      expect(await MyRalliesStore.rallyIds(), ['c', 'a']);
    });

    test('forgetting the active rally promotes the next one', () async {
      await MyRalliesStore.recordVisit('a');
      await MyRalliesStore.recordVisit('b');
      await MyRalliesStore.forget('b');
      // The switcher treats first-in-list as active, so unfollowing what
      // you were watching has to leave a valid rally in that slot.
      expect(await MyRalliesStore.rallyIds(), ['a']);
    });

    test('forgetting the last one leaves nothing, not a stale entry', () async {
      await MyRalliesStore.recordVisit('a');
      await MyRalliesStore.forget('a');
      expect(await MyRalliesStore.rallyIds(), isEmpty);
    });

    test('forgetting a rally that was never followed is a no-op', () async {
      await MyRalliesStore.recordVisit('a');
      await MyRalliesStore.forget('nope');
      expect(await MyRalliesStore.rallyIds(), ['a']);
    });
  });
}
