import 'package:shared_preferences/shared_preferences.dart';

import 'cofre_obsidian.dart';
import 'memoria.dart';
import 'versao.dart';

/// O que o assistente faz e não faz na versão instalada.
/// Serve para três coisas: responder "o que você sabe fazer?", orientar a IA para ela
/// não prometer o que o app não cumpre, e gerar a nota do Obsidian.
/// Ao lançar uma versão nova, atualize as listas abaixo e o histórico.
class Capacidades {
  static const nomeNota = 'Assistente - O que eu faço.md';
  static const marca = 'ASSISTENTE_CAPACIDADES';

  static const fazSemInternet = [
    'Marcar alarme e timer.',
    'Abrir a agenda já preenchida com um compromisso (você confirma lá).',
    'Dizer as horas.',
    'Abrir qualquer aplicativo instalado pelo nome, da Play Store ou de APK.',
    'Abrir configurações do aparelho: Wi-Fi, Bluetooth, brilho, bateria, som, localização, rede, armazenamento, aplicativos e Não perturbe.',
    'Abrir o mapa com uma rota para um destino.',
    'Abrir o discador (sem escolher o número).',
    'Guardar e esquecer lembranças: "lembra que...", "esquece...", "o que você sabe", "conversa nova".',
    'Entrar em stand-by e acordar, por toque, pelos botões da notificação ou chamando o nome (com o app aberto).',
  ];

  static const fazComInternet = [
    'Responder perguntas livres com IAs gratuitas, usando a próxima da fila se uma falhar.',
    'Pesquisar na web em perguntas de fatos, notícias, clima, preços e resultados.',
    'Usar trechos das suas notas do Obsidian, se a opção estiver ligada.',
  ];

  static const fazSemInternetModelo = [
    'Responder perguntas simples com o modelo offline, se ele foi baixado.',
  ];

  static const naoFaz = [
    'Enviar mensagens ou e-mails.',
    'Ligar para contatos ou ler a sua lista de contatos.',
    'Tocar em botões ou digitar dentro de outros aplicativos.',
    'Ler notificações, mensagens ou e-mails.',
    'Controlar música ou vídeo.',
    'Confirmar compromissos sozinho: ele só abre a agenda.',
    'Fazer compras ou pagamentos.',
    'Ouvir ou acordar com o app fechado ou a tela apagada.',
  ];

  static const historico = {
    '1.0': 'Esfera, voz, alarme, timer, calendário, abrir apps e horas.',
    'beta 2.0': 'Modelo offline, memória, stand-by, pesquisa com IAs gratuitas.',
    'beta 2.2': 'Chaves protegidas, erros claros das IAs, Obsidian como memória.',
    'beta 3': 'Indicador estilo player de mídia, notas do Obsidian, salvar ao sair, atalho com o nome.',
    'beta 3.1': 'Esta nota, escolha da voz e acordar chamando o nome.',
  };

  /// Texto curto que entra no prompt da IA.
  static String paraPrompt() =>
      'Neste app você abre aplicativos e configurações, marca alarme, timer e compromisso, '
      'mostra rotas, guarda lembranças e responde perguntas. Você NÃO envia mensagens, não liga '
      'para contatos, não toca em botões de outros apps e não lê contatos, e-mails ou notificações: '
      'se pedirem isso, diga que ainda não consegue. Não afirme poderes que não estão aqui.';

  /// Resposta falada para "o que você sabe fazer?".
  static String resumoFalado(String tratamento) =>
      'Eu marco alarmes, timers e compromissos, abro aplicativos e configurações, traço rotas, '
      'guardo o que o $tratamento pedir para lembrar e respondo perguntas, com internet ou com o '
      'modelo offline. Não envio mensagens nem mexo dentro de outros aplicativos.';

  static String markdown(String nome) {
    final b = StringBuffer()
      ..writeln('# $nome: o que eu faço ($versaoApp)')
      ..writeln()
      ..writeln('Esta nota é reescrita pelo app a cada versão. Não edite aqui: suas mudanças serão perdidas.')
      ..writeln()
      ..writeln('## Eu faço, sem internet');
    for (final f in fazSemInternet) {
      b.writeln('- $f');
    }
    b..writeln()..writeln('## Eu faço, com internet');
    for (final f in fazComInternet) {
      b.writeln('- $f');
    }
    b..writeln()..writeln('## Eu faço, sem internet, com o modelo offline');
    for (final f in fazSemInternetModelo) {
      b.writeln('- $f');
    }
    b..writeln()..writeln('## Eu não faço');
    for (final f in naoFaz) {
      b.writeln('- $f');
    }
    b..writeln()..writeln('## Histórico de versões');
    historico.forEach((v, d) => b.writeln('- **$v**: $d'));
    b..writeln()..writeln('<!-- $marca -->');
    return b.toString();
  }

  /// Grava a nota no cofre conectado, se ainda não está na versão atual.
  static Future<void> sincronizar(SharedPreferences prefs, {bool forcar = false}) async {
    final uri = prefs.getString(Memoria.chaveCofre) ?? '';
    if (uri.isEmpty) return;
    final selo = '$uri|$versaoApp';
    if (!forcar && prefs.getString('capacidades_gravada') == selo) return;
    try {
      final nome = prefs.getString('nome') ?? 'Assistente';
      await CofreObsidian.salvarNota(uri, nomeNota, marca, markdown(nome));
      await prefs.setString('capacidades_gravada', selo);
    } catch (_) {
      // Se já existe uma nota com esse nome que não é do app, ela é preservada.
    }
  }
}
