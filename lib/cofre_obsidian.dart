import 'package:flutter/services.dart';

/// Acesso à pasta do cofre Obsidian escolhida pelo dono no seletor do Android.
class CofreObsidian {
  static const _canal = MethodChannel('jarvis/obsidian');

  static Future<String?> selecionar() async =>
      _canal.invokeMethod<String>('selecionarCofre');

  static Future<String> ler(String uri) async =>
      await _canal.invokeMethod<String>('lerMemoria', {'uri': uri}) ?? '';

  static Future<void> salvar(String uri, String texto) async {
    await _canal.invokeMethod<bool>('salvarMemoria', {'uri': uri, 'texto': texto});
  }
}
