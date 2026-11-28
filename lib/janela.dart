import 'package:flutter/services.dart';

/// Ponte com o indicador fixo do assistente (notificação feita em Kotlin).
class Janela {
  static const _canal = MethodChannel('jarvis/janela');

  /// Liga os avisos que vêm do Android: botões da notificação.
  static void ouvir({
    void Function(String acao)? aoAcao,
    void Function(bool ativo)? aoStandby,
    void Function()? aoEncerrar,
  }) {
    _canal.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'acao':
          aoAcao?.call('${call.arguments}');
          break;
        case 'standby':
          aoStandby?.call(call.arguments == true);
          break;
        case 'encerrar':
          aoEncerrar?.call();
          break;
      }
      return null;
    });
  }

  /// Ação pedida pelo botão da notificação quando o app abriu do zero.
  static Future<String?> acaoPendente() async {
    try {
      return await _canal.invokeMethod<String>('acaoPendente');
    } catch (_) {
      return null;
    }
  }

  /// Mostra ou atualiza o indicador. [estado]: ativo, ouvindo, pensando, falando ou standby.
  static Future<bool> mostrar({
    required String estado,
    required String nome,
    required bool midia,
  }) async {
    try {
      return await _canal.invokeMethod<bool>(
              'mostrar', {'estado': estado, 'nome': nome, 'midia': midia}) ??
          false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> esconder() async {
    try {
      await _canal.invokeMethod('esconder');
    } catch (_) {}
  }

  /// Pede ao Android um atalho na tela inicial com o nome escolhido.
  static Future<String> criarAtalho(String nome) async {
    try {
      return await _canal.invokeMethod<String>('criarAtalho', {'nome': nome}) ??
          'Não consegui criar o atalho.';
    } catch (_) {
      return 'Não consegui criar o atalho.';
    }
  }
}
