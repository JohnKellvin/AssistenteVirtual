/// Reconhece o chamado "<nome>, acorde" no que foi ouvido em stand-by.
class Despertar {
  static String normalizar(String s) {
    const de = 'áàâãäéèêëíìîïóòôõöúùûüçñ';
    const para = 'aaaaaeeeeiiiiooooouuuucn';
    final b = StringBuffer();
    for (final c in s.toLowerCase().split('')) {
      final i = de.indexOf(c);
      b.write(i >= 0 ? para[i] : c);
    }
    return b.toString().replaceAll(RegExp(r'[^a-z0-9 ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Precisa do nome do assistente e de uma palavra de chamado (acorde, desperte, ative, volte).
  static bool chamou(String ouvido, String nome) {
    final t = normalizar(ouvido);
    final n = normalizar(nome);
    if (n.isEmpty || !t.contains(n)) return false;
    return RegExp(r'\b(acord|despert|ativ|volt)').hasMatch(t);
  }
}
