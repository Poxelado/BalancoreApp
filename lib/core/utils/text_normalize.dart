/// Normaliza texto para búsquedas: minúsculas y sin tildes/diacríticos.
///
/// Así "bíceps" y "biceps" (o "Pecho" y "pecho") coinciden. Útil para buscar
/// ejercicios, alimentos, etc. sin depender de la tilde exacta.
String normalizeSearch(String input) {
  final lower = input.toLowerCase().trim();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    buffer.writeCharCode(_fold[rune] ?? rune);
  }
  return buffer.toString();
}

/// ¿[haystack] (sin normalizar) contiene a [needle] ignorando tildes y mayúsculas?
bool matchesSearch(String haystack, String needle) {
  if (needle.trim().isEmpty) return true;
  return normalizeSearch(haystack).contains(normalizeSearch(needle));
}

const Map<int, int> _fold = {
  0x00E0: 0x61, // à -> a
  0x00E1: 0x61, // á -> a
  0x00E2: 0x61, // â -> a
  0x00E3: 0x61, // ã -> a
  0x00E4: 0x61, // ä -> a
  0x00E5: 0x61, // å -> a
  0x00E7: 0x63, // ç -> c
  0x00E8: 0x65, // è -> e
  0x00E9: 0x65, // é -> e
  0x00EA: 0x65, // ê -> e
  0x00EB: 0x65, // ë -> e
  0x00EC: 0x69, // ì -> i
  0x00ED: 0x69, // í -> i
  0x00EE: 0x69, // î -> i
  0x00EF: 0x69, // ï -> i
  0x00F1: 0x6E, // ñ -> n
  0x00F2: 0x6F, // ò -> o
  0x00F3: 0x6F, // ó -> o
  0x00F4: 0x6F, // ô -> o
  0x00F5: 0x6F, // õ -> o
  0x00F6: 0x6F, // ö -> o
  0x00F9: 0x75, // ù -> u
  0x00FA: 0x75, // ú -> u
  0x00FB: 0x75, // û -> u
  0x00FC: 0x75, // ü -> u
  0x00FD: 0x79, // ý -> y
  0x00FF: 0x79, // ÿ -> y
};
