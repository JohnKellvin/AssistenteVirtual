import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Memória do assistente, guardada só no aparelho.
/// - Fatos: coisas que o dono pediu para lembrar ("lembra que eu moro em Salvador").
/// - Conversa recente: as últimas trocas, para o modelo seguir o fio.
class Memoria {
  final SharedPreferences prefs;
  Memoria(this.prefs);

  static const _chaveFatos = 'memoria_fatos';
  static const _chaveConversa = 'memoria_conversa';
  static const maxFatos = 40;
  static const maxTrocas = 8;

  List<String> get fatos {
    try {
      return (jsonDecode(prefs.getString(_chaveFatos) ?? '[]') as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> guardarFato(String fato) async {
    final f = fatos..removeWhere((x) => x.toLowerCase() == fato.toLowerCase());
    f.add(fato.trim());
    while (f.length > maxFatos) {
      f.removeAt(0);
    }
    await prefs.setString(_chaveFatos, jsonEncode(f));
  }

  /// Esquece fatos que contenham o trecho. Sem trecho, esquece tudo.
  Future<int> esquecer([String? trecho]) async {
    final f = fatos;
    if (trecho == null || trecho.trim().isEmpty) {
      await prefs.remove(_chaveFatos);
      return f.length;
    }
    final antes = f.length;
    f.removeWhere((x) => x.toLowerCase().contains(trecho.toLowerCase().trim()));
    await prefs.setString(_chaveFatos, jsonEncode(f));
    return antes - f.length;
  }

  List<Map<String, String>> get conversa {
    try {
      return (jsonDecode(prefs.getString(_chaveConversa) ?? '[]') as List)
          .map((e) => Map<String, String>.from(e as Map))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> anotarTroca(String voce, String resposta) async {
    final c = conversa..add({'u': voce, 'a': resposta});
    while (c.length > maxTrocas) {
      c.removeAt(0);
    }
    await prefs.setString(_chaveConversa, jsonEncode(c));
  }

  Future<void> novaConversa() async => prefs.remove(_chaveConversa);

  /// Texto pronto para entrar no sistema do modelo.
  String paraPrompt() {
    final f = fatos;
    if (f.isEmpty) return '';
    return 'Coisas que o dono pediu para você lembrar: ${f.join('; ')}.';
  }

  String historicoParaPrompt() {
    final c = conversa;
    if (c.isEmpty) return '';
    return c.map((t) => 'Dono: ${t['u']}\nVocê: ${t['a']}').join('\n');
  }
}
