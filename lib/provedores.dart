import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Um provedor gratuito de IA (todos usam o formato "chat completions" da OpenAI,
/// exceto o Gemini, que tem formato próprio).
class ProvedorIA {
  final String id;
  final String nome;
  final String url;
  final String modelo;
  final String ondeCriarChave;
  final bool gemini;
  const ProvedorIA(this.id, this.nome, this.url, this.modelo, this.ondeCriarChave, {this.gemini = false});
}

/// Lista de provedores com camada gratuita. Os modelos e limites mudam com frequência:
/// se um deixar de funcionar, troque o campo "modelo" aqui ou nas configurações.
const provedoresIA = <ProvedorIA>[
  ProvedorIA('gemini', 'Google Gemini',
      'https://generativelanguage.googleapis.com/v1beta/models/', 'gemini-2.5-flash',
      'aistudio.google.com', gemini: true),
  ProvedorIA('groq', 'Groq', 'https://api.groq.com/openai/v1/chat/completions',
      'llama-3.3-70b-versatile', 'console.groq.com'),
  ProvedorIA('mistral', 'Mistral', 'https://api.mistral.ai/v1/chat/completions',
      'mistral-small-latest', 'console.mistral.ai'),
  ProvedorIA('openrouter', 'OpenRouter (modelos gratuitos)',
      'https://openrouter.ai/api/v1/chat/completions', 'meta-llama/llama-3.3-70b-instruct:free',
      'openrouter.ai'),
  ProvedorIA('cerebras', 'Cerebras', 'https://api.cerebras.ai/v1/chat/completions',
      'llama-3.3-70b', 'cloud.cerebras.ai'),
  ProvedorIA('cohere', 'Cohere (chave de teste)', 'https://api.cohere.ai/compatibility/v1/chat/completions',
      'command-r-plus', 'dashboard.cohere.com'),
  ProvedorIA('nvidia', 'NVIDIA', 'https://integrate.api.nvidia.com/v1/chat/completions',
      'meta/llama-3.3-70b-instruct', 'build.nvidia.com'),
];

class ResultadoBusca {
  final String titulo, trecho, url;
  ResultadoBusca(this.titulo, this.trecho, this.url);
}

/// Núcleo de pesquisa: busca na web (vários buscadores gratuitos) e pede a um
/// provedor de IA gratuito para resumir. Se um falhar ou o limite acabar, passa pro próximo.
class NucleoPesquisa {
  final SharedPreferences prefs;
  NucleoPesquisa(this.prefs);

  String? chave(String id) {
    final c = prefs.getString('chave_$id')?.trim();
    return (c == null || c.isEmpty) ? null : c;
  }

  // ------------------------------------------------------------- busca
  Future<List<ResultadoBusca>> buscar(String consulta) async {
    final fontes = <Future<List<ResultadoBusca>> Function()>[
      if (chave('tavily') != null) () => _tavily(consulta),
      if (chave('serper') != null) () => _serper(consulta),
      if (chave('brave') != null) () => _brave(consulta),
      () => _wikipedia(consulta), // sem chave, sempre disponível
      () => _duckduckgo(consulta), // sem chave, respostas curtas
    ];
    for (final f in fontes) {
      try {
        final r = await f().timeout(const Duration(seconds: 8));
        if (r.isNotEmpty) return r;
      } catch (_) {
        // tenta o próximo
      }
    }
    return [];
  }

  Future<List<ResultadoBusca>> _tavily(String q) async {
    final r = await http.post(Uri.parse('https://api.tavily.com/search'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${chave('tavily')}'},
        body: jsonEncode({'query': q, 'max_results': 4, 'search_depth': 'basic'}));
    if (r.statusCode != 200) throw Exception('tavily ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return [
      for (final x in (d['results'] as List))
        ResultadoBusca('${x['title']}', '${x['content']}', '${x['url']}')
    ];
  }

  Future<List<ResultadoBusca>> _serper(String q) async {
    final r = await http.post(Uri.parse('https://google.serper.dev/search'),
        headers: {'Content-Type': 'application/json', 'X-API-KEY': chave('serper')!},
        body: jsonEncode({'q': q, 'gl': 'br', 'hl': 'pt-br', 'num': 4}));
    if (r.statusCode != 200) throw Exception('serper ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return [
      for (final x in ((d['organic'] ?? []) as List))
        ResultadoBusca('${x['title']}', '${x['snippet']}', '${x['link']}')
    ];
  }

  Future<List<ResultadoBusca>> _brave(String q) async {
    final r = await http.get(
        Uri.parse('https://api.search.brave.com/res/v1/web/search?count=4&country=br&q=${Uri.encodeComponent(q)}'),
        headers: {'X-Subscription-Token': chave('brave')!, 'Accept': 'application/json'});
    if (r.statusCode != 200) throw Exception('brave ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return [
      for (final x in ((d['web']?['results'] ?? []) as List))
        ResultadoBusca('${x['title']}', '${x['description']}', '${x['url']}')
    ];
  }

  Future<List<ResultadoBusca>> _wikipedia(String q) async {
    final u = Uri.parse('https://pt.wikipedia.org/w/api.php?action=query&format=json&generator=search'
        '&gsrlimit=3&prop=extracts&exintro=1&explaintext=1&exchars=700&gsrsearch=${Uri.encodeComponent(q)}');
    final r = await http.get(u, headers: {'User-Agent': 'AssistenteAndroid/1.0'});
    if (r.statusCode != 200) throw Exception('wikipedia ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    final paginas = (d['query']?['pages'] as Map?)?.values.toList() ?? [];
    return [
      for (final p in paginas)
        ResultadoBusca('${p['title']}', '${p['extract'] ?? ''}',
            'https://pt.wikipedia.org/?curid=${p['pageid']}')
    ];
  }

  Future<List<ResultadoBusca>> _duckduckgo(String q) async {
    final r = await http.get(Uri.parse(
        'https://api.duckduckgo.com/?format=json&no_html=1&skip_disambig=1&q=${Uri.encodeComponent(q)}'));
    if (r.statusCode != 200) throw Exception('ddg ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    final txt = '${d['AbstractText'] ?? ''}';
    if (txt.isEmpty) return [];
    return [ResultadoBusca('${d['Heading']}', txt, '${d['AbstractURL']}')];
  }

  // ------------------------------------------------- resumo pela IA
  /// Tenta cada provedor com chave, na ordem. Devolve null se nenhum respondeu.
  Future<String?> perguntar(String sistema, String pergunta, {List<ResultadoBusca> fontes = const []}) async {
    final contexto = fontes.isEmpty
        ? pergunta
        : 'Pergunta: $pergunta\n\nResultados da busca:\n' +
            fontes.map((f) => '- ${f.titulo}: ${f.trecho}').join('\n') +
            '\n\nResponda só com base nesses resultados. Se não bastarem, diga isso.';
    for (final p in provedoresIA) {
      final k = chave(p.id);
      if (k == null) continue;
      try {
        final r = await (p.gemini ? _gemini(p, k, sistema, contexto) : _openai(p, k, sistema, contexto))
            .timeout(const Duration(seconds: 20));
        if (r != null && r.trim().isNotEmpty) return r.trim();
      } catch (_) {
        // limite acabou ou erro: passa pro próximo provedor
      }
    }
    return null;
  }

  Future<String?> _openai(ProvedorIA p, String k, String sistema, String texto) async {
    final r = await http.post(Uri.parse(p.url),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $k'},
        body: jsonEncode({
          'model': prefs.getString('modelo_${p.id}') ?? p.modelo,
          'max_tokens': 300,
          'messages': [
            {'role': 'system', 'content': sistema},
            {'role': 'user', 'content': texto},
          ],
        }));
    if (r.statusCode != 200) throw Exception('${p.id} ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return d['choices'][0]['message']['content'] as String?;
  }

  Future<String?> _gemini(ProvedorIA p, String k, String sistema, String texto) async {
    final modelo = prefs.getString('modelo_${p.id}') ?? p.modelo;
    final r = await http.post(Uri.parse('${p.url}$modelo:generateContent?key=$k'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'systemInstruction': {'parts': [{'text': sistema}]},
          'contents': [{'role': 'user', 'parts': [{'text': texto}]}],
          'generationConfig': {'maxOutputTokens': 300},
        }));
    if (r.statusCode != 200) throw Exception('gemini ${r.statusCode}');
    final d = jsonDecode(utf8.decode(r.bodyBytes));
    return d['candidates'][0]['content']['parts'][0]['text'] as String?;
  }
}
