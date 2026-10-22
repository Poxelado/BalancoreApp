import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:balancore/core/utils/input_limits.dart';

void main() {
  group('Validators.username', () {
    test('acepta un usuario válido y normaliza', () {
      expect(Validators.username('Isaias_90'), isNull);
      expect(Validators.cleanUsername('@Isaias_90 '), 'isaias_90');
    });

    test('rechaza vacío y muy corto', () {
      expect(Validators.username(''), isNotNull);
      expect(Validators.username('ab'), isNotNull);
    });

    test('rechaza caracteres inválidos', () {
      expect(Validators.username('con espacio'), isNotNull);
      expect(Validators.username('acentué'), isNotNull);
      expect(Validators.username('guion-medio'), isNotNull);
    });

    test('rechaza si supera el máximo', () {
      expect(Validators.username('a' * 22), isNotNull);
      expect(Validators.username('a' * 21), isNull);
    });
  });

  group('Validators.email', () {
    test('acepta correo válido', () {
      expect(Validators.email('a@b.cl'), isNull);
    });

    test('rechaza sin arroba o sin dominio', () {
      expect(Validators.email('correo'), isNotNull);
      expect(Validators.email('a@b'), isNotNull);
      expect(Validators.email('a b@c.cl'), isNotNull);
    });

    test('rechaza vacío', () {
      expect(Validators.email(''), isNotNull);
    });
  });

  group('Validators.password', () {
    test('exige mínimo y máximo', () {
      expect(Validators.password('12345'), isNotNull);
      expect(Validators.password('123456'), isNull);
      expect(Validators.password('a' * 73), isNotNull);
    });
  });

  group('Validators.intInRange', () {
    test('valida edad típica', () {
      expect(
        Validators.intInRange('25', min: 12, max: 100, label: 'Edad'),
        isNull,
      );
      expect(
        Validators.intInRange('5', min: 12, max: 100, label: 'Edad'),
        isNotNull,
      );
      expect(
        Validators.intInRange('999', min: 12, max: 100, label: 'Edad'),
        isNotNull,
      );
    });

    test('rechaza texto no numérico', () {
      expect(
        Validators.intInRange('abc', min: 0, max: 10),
        isNotNull,
      );
    });
  });

  group('Validators.doubleInRange', () {
    test('valida peso y acepta coma decimal', () {
      expect(
        Validators.doubleInRange('72,5', min: 30, max: 300, label: 'Peso'),
        isNull,
      );
      expect(
        Validators.doubleInRange('500', min: 30, max: 300, label: 'Peso'),
        isNotNull,
      );
    });
  });

  group('Validators.parseDouble', () {
    test('acepta punto y coma decimal', () {
      expect(Validators.parseDouble('72.5'), 72.5);
      expect(Validators.parseDouble('72,5'), 72.5);
      expect(Validators.parseDouble(' 70 '), 70);
    });

    test('lanza FormatException con mensaje claro en vez del crudo de Dart', () {
      expect(
        () => Validators.parseDouble('abc', label: 'peso'),
        throwsA(
          isA<FormatException>().having(
            (e) => e.message,
            'message',
            contains('peso'),
          ),
        ),
      );
    });
  });

  group('Validators.parseInt', () {
    test('acepta entero válido', () {
      expect(Validators.parseInt('25'), 25);
    });

    test('lanza FormatException con mensaje claro', () {
      expect(
        () => Validators.parseInt('x', label: 'edad'),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('InputFormatters.decimal', () {
    TextEditingValue apply(
      List<TextInputFormatter> formatters,
      String text,
    ) {
      const oldValue = TextEditingValue.empty;
      var value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
      for (final f in formatters) {
        value = f.formatEditUpdate(oldValue, value);
      }
      return value;
    }

    test('descarta letras y símbolos', () {
      final out = apply(
        InputFormatters.decimal(maxLength: 6),
        '12a3',
      );
      expect(out.text, '123');
    });

    test('permite un solo separador decimal', () {
      // Simula tecleo carácter a carácter: "12.3" se acepta, otro "." se rechaza.
      final formatters = InputFormatters.decimal(maxLength: 6);
      var value = TextEditingValue.empty;
      for (final ch in '12.3.4'.split('')) {
        final old = value;
        var next = TextEditingValue(
          text: '${old.text}$ch',
          selection: TextSelection.collapsed(offset: old.text.length + 1),
        );
        for (final f in formatters) {
          next = f.formatEditUpdate(old, next);
        }
        value = next;
      }
      expect(value.text, '12.34');
    });

    test('respeta el tope de longitud', () {
      final out = apply(
        InputFormatters.decimal(maxLength: 4),
        '123456',
      );
      expect(out.text.length, lessThanOrEqualTo(4));
    });
  });
}
