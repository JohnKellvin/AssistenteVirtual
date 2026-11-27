import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'memoria.dart';
import 'modelo_local.dart';
import 'provedores.dart';

/// Uma ação que o app executa no Android.
class AcaoPedida {
  final String tipo; // alarme, timer, evento, ligar, abrir, anotar
  final Map<String, String> dados;
  AcaoPedida(this.tipo, this.dados);
}

class Resposta {
  final String fala;
  final AcaoPedida? acao;
  final bool dormir; // ordem de stand-by
  Resposta(this.fala, {this.acao, this.dormir = false});
}

/// Cérebro do assistente.
///
/// Camada 1 (agora): entende os pedidos mais comuns por regras, rápido e
/// 100% offline. Isso já cobre alarme, timer, calendário e abrir apps.
/// Camada 2: pesquisa na web e IAs online (precisa de internet e de ao menos uma chave).
/// Camada 3: modelo de linguagem local para responder sem internet.
class Cerebro {
  final SharedPreferences prefs;
  Cerebro(this.prefs);

  static const _numeros = {
    'um': 1, 'uma': 1, 'dois': 2, 'duas': 2, 'três': 3, 'tres': 3, 'quatro': 4,
    'cinco': 5, 'seis': 6, 'sete': 7, 'oito': 8, 'nove': 9, 'dez': 10,
    'onze': 11, 'doze': 12, 'quinze': 15, 'vinte': 20, 'trinta': 30,
    'quarenta': 40, 'cinquenta': 50, 'sessenta': 60,
  };

  int? _numeroEm(String t) {
    final m = RegExp(r'\d+').firstMatch(t);
    if (m != null) return int.parse(m.group(0)!);
    for (final p in t.split(RegExp(r'\s+'))) {
      if (_numeros.containsKey(p)) return _numeros[p];
    }
    return null;
  }

  /// Hora falada: "7", "7 e meia", "19:30", "7 e 15", "sete da noite".
  ({int hora, int minuto})? _horaEm(String t) {
    var m = RegExp(r'(\d{1,2})\s*(?::|h|horas?)\s*(\d{2})?').firstMatch(t);
    int? h;
    int min = 0;
    if (m != null) {
      h = int.parse(m.group(1)!);
      if (m.group(2) != null) min = int.parse(m.group(2)!);
    } else {
      m = RegExp(r'às?\s+(\d{1,2})').firstMatch(t);
      if (m != null) {
        h = int.parse(m.group(1)!);
      } else {
        for (final e in _numeros.entries) {
          if (RegExp('\\b${e.key}\\b').hasMatch(t) && e.value <= 12) {
            h = e.value;
            break;
          }
        }
      }
    }
    if (h == null) return null;
    if (t.contains('e meia')) min = 30;
    final e = RegExp(r'e\s+(\d{1,2})\b').firstMatch(t);
    if (e != null && min == 0 && m != null && !t.contains(':')) min = int.parse(e.group(1)!);
    if ((t.contains('noite') || t.contains('tarde')) && h < 12) h += 12;
    if (h > 23 || min > 59) return null;
    return (hora: h, minuto: min);
  }

  DateTime? _dataEm(String t) {
    final hoje = DateTime.now();
    final base = DateTime(hoje.year, hoje.month, hoje.day);
    if (t.contains('depois de amanhã') || t.contains('depois de amanha')) {
      return base.add(const Duration(days: 2));
    }
    if (t.contains('amanhã') || t.contains('amanha')) return base.add(const Duration(days: 1));
    if (t.contains('hoje')) return base;
    const dias = {
      'segunda': 1, 'terça': 2, 'terca': 2, 'quarta': 3, 'quinta': 4,
      'sexta': 5, 'sábado': 6, 'sabado': 6, 'domingo': 7,
    };
    for (final e in dias.entries) {
      if (t.contains(e.key)) {
        var d = (e.value - hoje.weekday) % 7;
        if (d == 0) d = 7;
        return base.add(Duration(days: d));
      }
    }
    final dm = RegExp(r'dia\s+(\d{1,2})').firstMatch(t);
    if (dm != null) {
      final dia = int.parse(dm.group(1)!);
      var d = DateTime(hoje.year, hoje.month, dia);
      if (d.isBefore(base)) d = DateTime(hoje.year, hoje.month + 1, dia);
      return d;
    }
    return null;
  }

  Future<Resposta> responder(String fala, {required String nome, required String tratamento}) async {
    final t = fala.toLowerCase().trim();

    // Timer: "timer de 5 minutos", "me avisa em 10 minutos"
    if (t.contains('timer') || t.contains('cronômetro') || RegExp(r'(me avisa|me lembra).*em\s').hasMatch(t)) {
      final n = _numeroEm(t);
      if (n != null) {
        final seg = t.contains('hora') ? n * 3600 : t.contains('segundo') ? n : n * 60;
        return Resposta('Timer ligado, $tratamento.',
            acao: AcaoPedida('timer', {'segundos': '$seg'}));
      }
    }

    // Alarme: "alarme às 7", "me acorda às 6 e meia"
    if (t.contains('alarme') || t.contains('me acorda') || t.contains('despertador')) {
      final h = _horaEm(t);
      if (h != null) {
        return Resposta('Alarme marcado, $tratamento.',
            acao: AcaoPedida('alarme', {'hora': '${h.hora}', 'minuto': '${h.minuto}'}));
      }
      return Resposta('Para que horas, $tratamento?');
    }

    // Calendário: "marca reunião amanhã às 15", "agenda dentista dia 20"
    if (RegExp(r'\b(marca|marcar|agenda|agendar|compromisso|evento|lembrete)\b').hasMatch(t)) {
      final data = _dataEm(t);
      final h = _horaEm(t);
      var titulo = t
          .replaceAll(RegExp(r'\b(marca|marcar|agenda|agendar|no calendário|na agenda|um|uma|para|pra|compromisso|evento)\b'), ' ')
          .replaceAll(RegExp(r'(amanhã|amanha|hoje|depois de amanhã|segunda|terça|quarta|quinta|sexta|sábado|domingo|dia\s+\d+|às?\s+\d+.*)'), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (titulo.isEmpty) titulo = 'Compromisso';
      final quando = (data ?? DateTime.now()).add(Duration(hours: h?.hora ?? 9, minutes: h?.minuto ?? 0));
      return Resposta('Abrindo o calendário com isso, $tratamento.',
          acao: AcaoPedida('evento', {'titulo': titulo, 'inicio': quando.millisecondsSinceEpoch.toString()}));
    }

    // Memória: "lembra que eu moro em Salvador", "esquece isso", "conversa nova"
    final mem = Memoria(prefs);
    final lembrar = RegExp(r'^(lembra|lembre|anota|guarda|memoriza)( que| de que)?\s+(.+)$').firstMatch(t);
    if (lembrar != null && !t.contains('me lembra') && !t.contains('me lembre')) {
      await mem.guardarFato(lembrar.group(3)!);
      return Resposta('Guardado, $tratamento.');
    }
    final esquecer = RegExp(r'^(esquece|esqueça|apaga da memória|esquecer)\s*(.*)$').firstMatch(t);
    if (esquecer != null) {
      final trecho = esquecer.group(2)!.replaceAll(RegExp(r'^(que|sobre|o que|tudo)\s*'), '').trim();
      final n = await mem.esquecer(t.contains('tudo') ? null : trecho);
      return Resposta(n == 0 ? 'Não achei nada disso, $tratamento.' : 'Esquecido, $tratamento.');
    }
    if (t.contains('conversa nova') || t.contains('nova conversa') || t.contains('recomeça')) {
      await mem.novaConversa();
      return Resposta('Conversa nova, $tratamento.');
    }
    if (RegExp(r'o que (você|vc) (sabe|lembra)').hasMatch(t)) {
      final f = mem.fatos;
      return Resposta(f.isEmpty ? 'Ainda não guardei nada, $tratamento.' : 'Sei que ${f.join(', ')}.');
    }

    // Stand-by
    if (RegExp(r'\b(stand ?by|pode parar|fica quieto|vai dormir|desativar|desativa)\b').hasMatch(t)) {
      return Resposta('Entrando em stand-by, $tratamento.', dormir: true);
    }

    // Configurações do aparelho
    const ajustes = {
      'wi-fi': 'wifi', 'wifi': 'wifi', 'bluetooth': 'bluetooth', 'brilho': 'brilho',
      'bateria': 'bateria', 'som': 'som', 'volume': 'som', 'localização': 'localizacao',
      'localizacao': 'localizacao', 'rede': 'rede', 'armazenamento': 'armazenamento',
      'aplicativos': 'apps', 'não perturbe': 'naoperturbe', 'nao perturbe': 'naoperturbe',
    };
    if (RegExp(r'\b(configura|configuração|configuracoes|configurações|ajustes|abre as|abrir as)\b').hasMatch(t) ||
        t.contains('wi-fi') || t.contains('wifi') || t.contains('bluetooth')) {
      for (final e in ajustes.entries) {
        if (t.contains(e.key)) {
          return Resposta('Abrindo as configurações, $tratamento.',
              acao: AcaoPedida('ajuste', {'qual': e.value}));
        }
      }
      return Resposta('Abrindo as configurações, $tratamento.', acao: AcaoPedida('ajuste', {'qual': 'geral'}));
    }

    // Mensagem no WhatsApp: "manda mensagem pro João"
    if (t.contains('whatsapp') && (t.contains('manda') || t.contains('mensagem'))) {
      return Resposta('Abrindo o WhatsApp, $tratamento.', acao: AcaoPedida('abrir', {'nome': 'whatsapp'}));
    }

    // Navegação
    final rota = RegExp(r'(como chego|rota para|rota pra|navegar para|navegar pra|me leva (para|pra))\s+(.+)').firstMatch(t);
    if (rota != null) {
      return Resposta('Abrindo o mapa, $tratamento.', acao: AcaoPedida('mapa', {'destino': rota.group(rota.groupCount)!}));
    }

    // Ligar
    if (t.startsWith('ligar') || t.startsWith('liga para') || t.startsWith('liga pra')) {
      return Resposta('Abrindo o discador, $tratamento.',
          acao: AcaoPedida('ligar', {'busca': t}));
    }

    // Abrir app / site
    final ab = RegExp(r'^(abre|abrir|abra)\s+(o|a)?\s*(.+)$').firstMatch(t);
    if (ab != null) {
      return Resposta('Abrindo, $tratamento.', acao: AcaoPedida('abrir', {'nome': ab.group(3)!.trim()}));
    }

    // Horas e data (offline, sem modelo)
    if (t.contains('que horas')) {
      final a = DateTime.now();
      final mm = a.minute.toString().padLeft(2, '0');
      return Resposta('São ${a.hour} e $mm, $tratamento.');
    }

    // Camada 2: perguntas livres. Com internet: busca + IAs online. Sem: modelo local.
    final nucleo = NucleoPesquisa(prefs);
    final sobre = prefs.getString('sobre') ?? '';
    final lembrancas = mem.paraPrompt();
    final historico = mem.historicoParaPrompt();
    final sistema = 'Você é $nome, assistente de voz brasileiro: sério, preciso, com humor seco ocasional. '
        'Trate o dono por $tratamento. Responda em português, em no máximo 2 frases curtas (até 35 palavras), '
        'sem markdown, lista, emoji ou link, com números do jeito que se fala. Nunca invente dados. '
        '${sobre.isEmpty ? '' : 'Sobre o dono: $sobre. '}$lembrancas'
        '${historico.isEmpty ? '' : '\nConversa recente:\n$historico'}';

    final precisaBuscar = RegExp(
        r'\b(quem|quando|onde|quanto|qual|quais|notícia|noticias|notícias|cotação|clima|tempo|previsão|resultado|jogo|preço|preco|pesquis)')
        .hasMatch(t);

    String? resposta;
    ResultadoIA? diagnosticoIA;
    final temInternet = await _temInternet();
    if (temInternet) {
      final fontes = precisaBuscar ? await nucleo.buscar(fala) : <ResultadoBusca>[];
      diagnosticoIA = await nucleo.perguntar(sistema, fala, fontes: fontes);
      resposta = diagnosticoIA.resposta;
      if (resposta == null && fontes.isNotEmpty) {
        final bruto = '${fontes.first.titulo}: ${fontes.first.trecho}';
        resposta = bruto.substring(0, bruto.length.clamp(0, 280));
      }
    }
    // Sem internet, ou nenhuma IA online respondeu: modelo dentro do celular.
    resposta ??= await ModeloLocal.responder(prefs, sistema: sistema, pergunta: fala);
    if (resposta != null) {
      await mem.anotarTroca(fala, resposta);
      return Resposta(resposta);
    }
    final instalado = await ModeloLocal.instalado(prefs);
    if (!temInternet && !instalado) {
      return Resposta('Estou sem internet, $tratamento, e o modelo offline ainda não foi baixado. Dá para baixar nas configurações.');
    }
    if (temInternet && (diagnosticoIA?.chavesConfiguradas ?? 0) == 0) {
      return Resposta(instalado
          ? 'Não encontrei nenhuma chave de IA salva, $tratamento, e o modelo offline também não respondeu. Revise as configurações.'
          : 'Não encontrei nenhuma chave de IA salva, $tratamento. Cole uma chave nas configurações e toque em Salvar.');
    }
    if (temInternet) {
      final causas = diagnosticoIA?.falhas.take(2).join('; ') ?? '';
      return Resposta(causas.isEmpty
          ? 'As IAs configuradas não responderam, $tratamento. Confira a conexão e as configurações.'
          : 'Encontrei as chaves, $tratamento, mas as IAs falharam: $causas. Revise as configurações.');
    }
    return Resposta('O modelo offline está instalado, mas falhou ao responder. Feche e abra o app e tente novamente.');
  }

  Future<bool> _temInternet() async {
    try {
      final r = await InternetAddress.lookup('example.com').timeout(const Duration(seconds: 2));
      return r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      return false;
    }
  }
}
