import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/utils/text_normalize.dart';

void main() {
  group('normalizeSearch', () {
    test('quita tildes y baja a minúsculas', () {
      expect(normalizeSearch('Bíceps'), 'biceps');
      expect(normalizeSearch('Antebrazos'), 'antebrazos');
      expect(normalizeSearch('Cuádriceps'), 'cuadriceps');
      expect(normalizeSearch('  Hombros '), 'hombros');
      expect(normalizeSearch('GEMELOS'), 'gemelos');
    });

    test('respeta la eñe convertida a n', () {
      expect(normalizeSearch('muñeca'), 'muneca');
    });
  });

  group('matchesSearch', () {
    test('encuentra sin tilde lo que está con tilde', () {
      expect(matchesSearch('Curl de muñeca', 'muneca'), isTrue);
      expect(matchesSearch('Elevación de talones', 'elevacion'), isTrue);
      expect(matchesSearch('Press banca', 'BANCA'), isTrue);
    });

    test('devuelve true con aguja vacía', () {
      expect(matchesSearch('lo que sea', ''), isTrue);
      expect(matchesSearch('lo que sea', '   '), isTrue);
    });

    test('false si no coincide', () {
      expect(matchesSearch('Press banca', 'sentadilla'), isFalse);
    });
  });
}
