import 'package:flutter/services.dart';

/// Controla a janelinha flutuante (feita em Kotlin, na pasta android_extra/kotlin).
class Janela {
  static const _canal = MethodChannel('jarvis/janela');

  static Future<bool> temPermissao() async {
    try {
      return await _canal.invokeMethod<bool>('temPermissao') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> pedirPermissao() async {
    try {
      await _canal.invokeMethod('pedirPermissao');
    } catch (_) {}
  }

  /// Mostra ou atualiza a bolinha: branca = ativo, cinza = stand-by.
  static Future<bool> mostrar({required bool standby, required String nome}) async {
    try {
      return await _canal.invokeMethod<bool>('mostrar', {'standby': standby, 'nome': nome}) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> esconder() async {
    try {
      await _canal.invokeMethod('esconder');
    } catch (_) {}
  }
}
