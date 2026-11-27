import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'cofre_obsidian.dart';

/// Memória do assistente, guardada só no aparelho.
/// - Fatos: coisas que o dono pediu para lembrar ("lembra que eu moro em Salvador").
/// - Conversa recente: as últimas trocas, para o modelo seguir o fio.
class Memoria {
  final SharedPreferences prefs;
  Memoria(this.prefs);

  static const _chaveFatos = 'memoria_fatos';
  static const _chaveConversa = 'memoria_conversa';
  static const chaveCofre = 'obsidian_vault_uri';
  static const chaveErroCofre = 'obsidian_vault_erro';
  static const _inicioDados = '<!-- JARVIS_DATA_START';
  static const _fimDados = 'JARVIS_DATA_END -->';
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
    await _sincronizarCofre();
  }

  /// Esquece fatos que contenham o trecho. Sem trecho, esquece tudo.
  Future<int> esquecer([String? trecho]) async {
    final f = fatos;
    if (trecho == null || trecho.trim().isEmpty) {
      await prefs.remove(_chaveFatos);
      await _sincronizarCofre();
      return f.length;
    }
    final antes = f.length;
    f.removeWhere((x) => x.toLowerCase().contains(trecho.toLowerCase().trim()));
    await prefs.setString(_chaveFatos, jsonEncode(f));
    await _sincronizarCofre();
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
    await _sincronizarCofre();
  }

  Future<void> novaConversa() async {
    await prefs.remove(_chaveConversa);
    await _sincronizarCofre();
  }

  /// Conecta um cofre local do Obsidian e importa a memória que já estiver na nota.
  Future<void> conectarCofre(String uri) async {
    await prefs.setString(chaveCofre, uri);
    await carregarDoCofre();
  }

  /// Recarrega a memória do cofre ao iniciar o app, mantendo os dados locais se ele falhar.
  Future<void> carregarDoCofre() async {
    final uri = prefs.getString(chaveCofre);
    if (uri == null || uri.isEmpty) return;
    try {
      final markdown = await CofreObsidian.ler(uri);
      final dados = _extrairDados(markdown);
      if (dados == null) {
        if (markdown.trim().isNotEmpty) {
          await prefs.setString(chaveErroCofre,
              'A nota com esse nome já existe, mas não pertence ao assistente. Renomeie-a para evitar substituir seu conteúdo.');
          return;
        }
        await _sincronizarCofre(uri: uri);
      } else {
        final obj = jsonDecode(dados) as Map<String, dynamic>;
        final f = (obj['facts'] as List? ?? const []).whereType<String>().toList();
        final c = (obj['conversation'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => Map<String, String>.from(e))
            .toList();
        await prefs.setString(_chaveFatos, jsonEncode(f));
        await prefs.setString(_chaveConversa, jsonEncode(c));
        final sobre = obj['about'];
        if (sobre is String) await prefs.setString('sobre', sobre);
      }
      await prefs.remove(chaveErroCofre);
    } catch (e) {
      await prefs.setString(chaveErroCofre, _erroCofre(
          e, 'Não consegui acessar o cofre. A memória local continua disponível.'));
    }
  }

  Future<void> desconectarCofre() async {
    await prefs.remove(chaveCofre);
    await prefs.remove(chaveErroCofre);
  }

  Future<void> sincronizarCofre() => _sincronizarCofre();

  Future<void> _sincronizarCofre({String? uri}) async {
    final destino = uri ?? prefs.getString(chaveCofre);
    if (destino == null || destino.isEmpty) return;
    try {
      await CofreObsidian.salvar(destino, _notaMarkdown());
      await prefs.remove(chaveErroCofre);
    } catch (e) {
      await prefs.setString(chaveErroCofre, _erroCofre(
          e, 'Não consegui atualizar o cofre. A memória local continua disponível.'));
    }
  }

  String _erroCofre(Object erro, String padrao) {
    final texto = erro.toString().toLowerCase();
    if (texto.contains('já existe uma nota') || texto.contains('renomeie-a')) {
      return 'Já existe uma nota com esse nome. Renomeie-a no Obsidian para o app criar a nota de memória.';
    }
    return padrao;
  }

  String? _extrairDados(String markdown) {
    final inicio = markdown.indexOf(_inicioDados);
    if (inicio < 0) return null;
    final inicioConteudo = markdown.indexOf('\n', inicio);
    final fim = markdown.indexOf(_fimDados, inicioConteudo < 0 ? inicio : inicioConteudo);
    if (inicioConteudo < 0 || fim < 0) return null;
    final codificado = markdown.substring(inicioConteudo + 1, fim).trim();
    try {
      return utf8.decode(base64Url.decode(base64Url.normalize(codificado)));
    } catch (_) {
      return null;
    }
  }

  String _notaMarkdown() {
    final sobre = (prefs.getString('sobre') ?? '').trim();
    final sobreMarkdown = sobre.isEmpty ? '- Ainda não foi preenchido.' : sobre.replaceAll('\n', ' ');
    final fatosMarkdown = fatos.isEmpty
        ? '- Ainda não há fatos guardados.'
        : fatos.map((f) => '- ${f.replaceAll('\n', ' ')}').join('\n');
    final conversasMarkdown = conversa.isEmpty
        ? '- Ainda não há conversa recente.'
        : conversa.map((t) =>
            '- **Você:** ${(t['u'] ?? '').replaceAll('\n', ' ')}\n  **Assistente:** ${(t['a'] ?? '').replaceAll('\n', ' ')}')
            .join('\n');
    final dados = base64Url.encode(utf8.encode(jsonEncode({
      'facts': fatos,
      'conversation': conversa,
      'about': sobre,
    })));
    return '# Memória do Assistente\n\n'
        'Esta nota é atualizada pelo assistente.\n\n'
        '## Sobre a pessoa\n$sobreMarkdown\n\n'
        '## Fatos lembrados\n$fatosMarkdown\n\n'
        '## Conversa recente\n$conversasMarkdown\n\n'
        '$_inicioDados\n$dados\n$_fimDados\n';
  }

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
