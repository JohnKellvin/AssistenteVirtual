import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'acoes.dart';
import 'cerebro.dart';
import 'esfera.dart';
import 'janela.dart';
import 'modelo_local.dart';
import 'versao.dart';
import 'tela_config.dart';

class TelaPrincipal extends StatefulWidget {
  final SharedPreferences prefs;
  const TelaPrincipal({super.key, required this.prefs});

  @override
  State<TelaPrincipal> createState() => _TelaPrincipalState();
}

class _TelaPrincipalState extends State<TelaPrincipal> with WidgetsBindingObserver {
  final SpeechToText _ouvido = SpeechToText();
  final FlutterTts _boca = FlutterTts();
  late final Cerebro _cerebro;
  EstadoAssistente _estado = EstadoAssistente.pronto;
  bool _standby = false;
  String _voce = '';
  String _resposta = '';
  String _aviso = '';
  bool _ouvidoPronto = false;
  bool _enviando = false;

  String get nome => widget.prefs.getString('nome') ?? 'Jarvis';
  String get tratamento => widget.prefs.getString('tratamento') ?? 'Senhor';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _cerebro = Cerebro(widget.prefs);
    ModeloLocal.iniciar(widget.prefs).catchError((_) {});
    _iniciar();
  }

  // Ao sair do app, ele para de ouvir (nada fica escutando em segundo plano).
  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) {
      Janela.esconder();
    } else {
      if (widget.prefs.getBool('janelinha') ?? true) {
        Janela.mostrar(standby: _standby, nome: nome);
      }
      _ouvido.cancel();
      _boca.stop();
      if (mounted && _estado != EstadoAssistente.pronto) {
        setState(() => _estado = EstadoAssistente.pronto);
      }
    }
  }

  Future<void> _iniciar() async {
    await _boca.setLanguage('pt-BR');
    await _boca.setSpeechRate(0.5);
    _boca.setCompletionHandler(() {
      if (mounted) setState(() => _estado = EstadoAssistente.pronto);
    });
    final mic = await Permission.microphone.request();
    if (mic.isGranted) {
      _ouvidoPronto = await _ouvido.initialize(
        onStatus: (s) {
          // O Android encerra a escuta sozinho depois de uma pausa na fala: é aí que enviamos.
          if ((s == 'done' || s == 'notListening') && _estado == EstadoAssistente.ouvindo) {
            _enviar();
          }
        },
        onError: (e) {
          if (!mounted) return;
          setState(() {
            _aviso = 'Não ouvi nada. Toque e fale de novo.';
            _estado = EstadoAssistente.pronto;
          });
        },
      );
    }
    if (!_ouvidoPronto && mounted) {
      setState(() => _aviso = 'Libere o microfone nas configurações do Android.');
    }
    if (widget.prefs.getString('nome') == null && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _abrirConfig());
    }
    if ((widget.prefs.getBool('janelinha') ?? true) && !await Janela.temPermissao()) {
      await Janela.pedirPermissao();
    }
  }

  // Um toque: começa a ouvir. Outro toque durante a escuta: envia na hora.
  // Toque enquanto ele fala ou pensa: interrompe.
  Future<void> _tocar() async {
    if (_standby) {
      setState(() {
        _standby = false;
        _aviso = '';
        _resposta = '';
      });
      await _boca.speak('Às ordens, $tratamento.');
      return;
    }
    switch (_estado) {
      case EstadoAssistente.pronto:
        await _comecarAOuvir();
        break;
      case EstadoAssistente.ouvindo:
        await _ouvido.stop();
        await _enviar();
        break;
      case EstadoAssistente.falando:
      case EstadoAssistente.pensando:
        await _boca.stop();
        setState(() => _estado = EstadoAssistente.pronto);
        break;
    }
  }

  Future<void> _comecarAOuvir() async {
    if (!_ouvidoPronto) {
      setState(() => _aviso = 'Libere o microfone nas configurações do Android.');
      return;
    }
    await _boca.stop();
    setState(() {
      _estado = EstadoAssistente.ouvindo;
      _voce = '';
      _aviso = '';
      _enviando = false;
    });
    await _ouvido.listen(
      localeId: 'pt_BR',
      onResult: (r) => setState(() => _voce = r.recognizedWords),
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 3), // para sozinho depois de 3 s de silêncio
      listenOptions: SpeechListenOptions(partialResults: true),
    );
  }

  Future<void> _enviar() async {
    if (_enviando) return;
    _enviando = true;
    final texto = _voce.trim();
    if (texto.isEmpty) {
      if (mounted) setState(() => _estado = EstadoAssistente.pronto);
      _enviando = false;
      return;
    }
    await _processar(texto);
    _enviando = false;
  }

  Future<void> _processar(String texto) async {
    setState(() {
      _estado = EstadoAssistente.pensando;
      _resposta = '';
    });
    final r = await _cerebro.responder(texto, nome: nome, tratamento: tratamento);
    String fala = r.fala;
    if (r.acao != null) {
      final erro = await Acoes.executar(r.acao!);
      if (erro != null) fala = erro;
    }
    if (!mounted) return;
    setState(() {
      _resposta = fala;
      _estado = EstadoAssistente.falando;
      if (r.dormir) _standby = true;
    });
    await _boca.speak(fala);
  }

  Future<void> _abrirConfig() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => TelaConfig(prefs: widget.prefs)),
    );
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ouvido.cancel();
    _boca.stop();
    ModeloLocal.liberar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rotulo = _standby
        ? 'stand-by'
        : {
            EstadoAssistente.pronto: 'ativo',
            EstadoAssistente.ouvindo: 'ouvindo',
            EstadoAssistente.pensando: 'pensando',
            EstadoAssistente.falando: 'falando',
          }[_estado]!;
    final textoBotao = _standby
        ? 'toque\npara acordar'
        : _estado == EstadoAssistente.ouvindo
            ? 'toque\npara enviar'
            : _estado == EstadoAssistente.pronto
                ? 'toque\ne fale'
                : 'toque\npara parar';
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 280,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 400),
                opacity: _standby ? 0.18 : 1,
                child: Esfera(estado: _standby ? EstadoAssistente.pronto : _estado),
              ),
            ),
            Positioned(
              top: 12,
              left: 20,
              right: 8,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(nome.toUpperCase(),
                        style: const TextStyle(letterSpacing: 4, fontWeight: FontWeight.w600)),
                    Text(versaoApp, style: const TextStyle(color: Colors.white30, fontSize: 10)),
                  ]),
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _standby ? Colors.white24 : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(rotulo, style: const TextStyle(color: Colors.white54)),
                  ]),
                  IconButton(
                      icon: const Icon(Icons.settings, color: Colors.white54), onPressed: _abrirConfig),
                ],
              ),
            ),
            Positioned(
              left: 20,
              right: 20,
              bottom: 150,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_voce.isNotEmpty && !_standby)
                    Text('“$_voce”',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white60, fontSize: 15)),
                  const SizedBox(height: 10),
                  Text(_standby ? '' : _resposta,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, height: 1.3)),
                  if (_aviso.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_aviso, style: const TextStyle(color: Colors.white54, fontSize: 13)),
                    ),
                ],
              ),
            ),
            Positioned(
              bottom: 36,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _tocar,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: _estado == EstadoAssistente.ouvindo ? 110 : 96,
                    height: _estado == EstadoAssistente.ouvindo ? 110 : 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(_estado == EstadoAssistente.ouvindo ? 0.22 : 0.06),
                      border: Border.all(
                          color: _standby ? Colors.white12 : Colors.white24, width: 1.5),
                    ),
                    alignment: Alignment.center,
                    child: Text(textoBotao,
                        textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
