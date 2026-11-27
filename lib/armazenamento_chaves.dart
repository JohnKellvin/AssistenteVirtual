import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guarda credenciais no armazenamento criptografado do sistema.
///
/// A leitura também migra, sob demanda, valores salvos por versões antigas em
/// SharedPreferences. Se a criptografia do aparelho falhar, o app ainda pode
/// usar a chave antiga, mas sinaliza que a migração não foi concluída.
class ArmazenamentoChaves {
  static const FlutterSecureStorage _cofre = FlutterSecureStorage();

  static const List<String> ids = [
    'gemini',
    'groq',
    'mistral',
    'openrouter',
    'cerebras',
    'cohere',
    'nvidia',
    'tavily',
    'serper',
    'brave',
    'huggingface',
  ];

  static bool falhaMigracao = false;

  static String _nome(String id) => 'chave_$id';

  static Future<void> migrarLegado(SharedPreferences prefs) async {
    for (final id in ids) {
      await ler(id, prefs: prefs);
    }
  }

  static Future<String?> ler(String id, {SharedPreferences? prefs}) async {
    final nome = _nome(id);
    String? protegido;
    try {
      protegido = (await _cofre.read(key: nome))?.trim();
    } catch (_) {
      falhaMigracao = true;
    }

    if (protegido != null && protegido.isNotEmpty) {
      await _removerLegado(prefs, nome);
      return protegido;
    }

    final antigo = prefs?.getString(nome)?.trim();
    if (antigo == null || antigo.isEmpty) {
      await _removerLegado(prefs, nome);
      return null;
    }

    try {
      await _cofre.write(key: nome, value: antigo);
      await _removerLegado(prefs, nome);
    } catch (_) {
      falhaMigracao = true;
    }
    return antigo;
  }

  static Future<void> salvar(
    String id,
    String valor, {
    SharedPreferences? prefs,
  }) async {
    final limpo = valor.trim();
    if (limpo.isEmpty) throw ArgumentError('A chave não pode ficar vazia.');
    final nome = _nome(id);
    await _cofre.write(key: nome, value: limpo);
    await _removerLegado(prefs, nome);
  }

  static Future<void> apagar(String id, {SharedPreferences? prefs}) async {
    final nome = _nome(id);
    await _cofre.delete(key: nome);
    await _removerLegado(prefs, nome);
  }

  static Future<void> _removerLegado(
    SharedPreferences? prefs,
    String nome,
  ) async {
    try {
      if (prefs != null && prefs.containsKey(nome)) {
        await prefs.remove(nome);
      }
    } catch (_) {
      falhaMigracao = true;
    }
  }
}
