import 'package:flutter_test/flutter_test.dart';
import 'package:rallychamp/features/rallies/data/checkpoint.dart';

void main() {
  group('nextCheckpointCode', () {
    test('continues a simple numeric sequence', () {
      expect(nextCheckpointCode(['R1', 'R2', 'R3']), 'R4');
    });

    test('keeps a multi-letter prefix', () {
      expect(nextCheckpointCode(['RSV1', 'RSV2']), 'RSV3');
    });

    test('continues from the highest number, not the count', () {
      // A deleted R2 shouldn't make the next one collide with R5.
      expect(nextCheckpointCode(['R1', 'R5']), 'R6');
    });

    test('prefers the prefix in most use', () {
      expect(nextCheckpointCode(['R1', 'R2', 'R3', 'BOX1']), 'R4');
    });

    test('ignores codes with no number to continue', () {
      expect(nextCheckpointCode(['Start', 'Finish', 'R7']), 'R8');
    });

    test('gives up rather than guessing when nothing is numbered', () {
      expect(nextCheckpointCode(['Start', 'Finish']), isNull);
      expect(nextCheckpointCode([]), isNull);
    });

    test('handles numbers inside the prefix', () {
      expect(nextCheckpointCode(['SS2-R4']), 'SS2-R5');
    });

    test('rolls over digit widths', () {
      expect(nextCheckpointCode(['R9']), 'R10');
    });
  });
}
