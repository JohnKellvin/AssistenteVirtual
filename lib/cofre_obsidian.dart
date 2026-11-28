import 'package:flutter/services.dart';

/// Acesso à pasta do cofre Obsidian escolhida pelo dono no seletor do Android.
class CofreObsidian {
  static const _canal = MethodChannel('jarvis/obsidian');

  static Future<String?> selecionar() async =>
      _canal.invokeMethod<String>('selecionarCofre');

  static Future<String> ler(String uri) async =>
      await _canal.invokeMethod<String>('lerMemoria', {'uri': uri}) ?? '';

  /// Procura nas notas do cofre (só leitura). Devolve até [max] trechos com título.
  static Future<List<Map<String, String>>> buscar(String uri, List<String> termos,
      {int max = 3}) async {
    final r = await _canal.invokeMethod<List<dynamic>>(
            'buscarNotas', {'uri': uri, 'termos': termos, 'max': max}) ??
        [];
    return r.map((e) => Map<String, String>.from(e as Map)).toList();
  }

  /// Grava uma nota do app (com [marca] de posse). Nunca sobrescreve nota alheia.
  static Future<void> salvarNota(String uri, String nome, String marca, String texto) async {
    await _canal.invokeMethod('salvarNota',
        {'uri': uri, 'nome': nome, 'marca': marca, 'texto': texto});
  }

  static Future<void> salvar(String uri, String texto) async {
    await _canal.invokeMethod<bool>('salvarMemoria', {'uri': uri, 'texto': texto});
  }
}
