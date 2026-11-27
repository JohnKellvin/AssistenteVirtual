import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'memoria.dart';
import 'modelo_local.dart';
import 'provedores.dart';
import 'versao.dart';

class TelaConfig extends StatefulWidget {
  final SharedPreferences prefs;
  const TelaConfig({super.key, required this.prefs});

  @override
  State<TelaConfig> createState() => _TelaConfigState();
}

class _TelaConfigState extends State<TelaConfig> {
  late final TextEditingController _nome;
  late final TextEditingController _tratamento;
  late final TextEditingController _sobre;
  final Map<String, TextEditingController> _chaves = {};
  late final TextEditingController _hf;
  bool _modeloOk = false;
  int? _progresso;
  String _msgModelo = '';
  bool _janelinha = true;

  // Buscadores gratuitos (opcionais). Wikipedia e DuckDuckGo funcionam sem chave.
  static const _buscadores = {
    'tavily': 'Tavily (tavily.com, 1.000 buscas/mês)',
    'serper': 'Serper (serper.dev, 2.500 buscas grátis)',
    'brave': 'Brave Search (brave.com/search/api)',
  };

  @override
  void initState() {
    super.initState();
    final p = widget.prefs;
    _nome = TextEditingController(text: p.getString('nome') ?? 'Jarvis');
    _tratamento = TextEditingController(text: p.getString('tratamento') ?? 'Senhor');
    _sobre = TextEditingController(text: p.getString('sobre') ?? '');
    _hf = TextEditingController(text: p.getString('chave_huggingface') ?? '');
    _janelinha = p.getBool('janelinha') ?? true;
    ModeloLocal.instalado(p).then((v) {
      if (mounted) setState(() => _modeloOk = v);
    });
    for (final pr in provedoresIA) {
      _chaves[pr.id] = TextEditingController(text: p.getString('chave_${pr.id}') ?? '');
    }
    for (final id in _buscadores.keys) {
      _chaves[id] = TextEditingController(text: p.getString('chave_$id') ?? '');
    }
  }

  Future<void> _salvar() async {
    final p = widget.prefs;
    await p.setString('nome', _nome.text.trim().isEmpty ? 'Jarvis' : _nome.text.trim());
    await p.setString('tratamento', _tratamento.text.trim().isEmpty ? 'Senhor' : _tratamento.text.trim());
    await p.setString('sobre', _sobre.text.trim());
    for (final e in _chaves.entries) {
      await p.setString('chave_${e.key}', e.value.text.trim());
    }
    await p.setString('chave_huggingface', _hf.text.trim());
    await p.setBool('janelinha', _janelinha);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _baixarModelo() async {
    await widget.prefs.setString('chave_huggingface', _hf.text.trim());
    setState(() {
      _progresso = 0;
      _msgModelo = '';
    });
    final erro = await ModeloLocal.baixar(widget.prefs, (p) {
      if (mounted) setState(() => _progresso = p);
    });
    if (!mounted) return;
    final ok = await ModeloLocal.instalado(widget.prefs);
    setState(() {
      _progresso = null;
      _modeloOk = ok;
      _msgModelo = erro ?? 'Modelo instalado. Ele já responde sem internet.';
    });
  }

  Future<void> _apagarMemoria() async {
    final m = Memoria(widget.prefs);
    await m.esquecer();
    await m.novaConversa();
    if (mounted) setState(() => _msgModelo = 'Memória apagada.');
  }

  Widget _campo(String rotulo, TextEditingController c,
      {String? dica, int linhas = 1, bool segredo = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: c,
        maxLines: linhas,
        obscureText: segredo,
        autocorrect: false,
        decoration: InputDecoration(
          labelText: rotulo,
          helperText: dica,
          helperMaxLines: 3,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _titulo(String t, [String? sub]) => Padding(
        padding: const EdgeInsets.only(top: 14, bottom: 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(t, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          if (sub != null)
            Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(sub, style: const TextStyle(color: Colors.white54, fontSize: 13))),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configurações'), backgroundColor: Colors.black),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _campo('Nome do assistente', _nome, dica: 'Ex.: Jarvis, Sexta-feira.'),
          _campo('Como ele te chama', _tratamento, dica: 'Ex.: Senhor, Senhora, ou o seu nome.'),
          _campo('Sobre você (opcional)', _sobre,
              dica: 'Quem você é e o que costuma pedir.', linhas: 3),
          _titulo('IAs gratuitas',
              'Coloque a chave de uma ou mais. Se uma atingir o limite, ele usa a próxima, nesta ordem.'),
          for (final pr in provedoresIA)
            _campo(pr.nome, _chaves[pr.id]!, segredo: true, dica: 'Chave grátis em ${pr.ondeCriarChave}'),
          _titulo('Buscadores gratuitos',
              'Opcionais. Sem chave ele usa a Wikipedia e o DuckDuckGo, que respondem menos.'),
          for (final e in _buscadores.entries) _campo(e.value, _chaves[e.key]!, segredo: true),
          _titulo('Modelo offline',
              'Gemma 3 de 1 bilhão de parâmetros, cerca de 550 MB. Baixa uma vez, com internet, e depois responde sem internet.'),
          _campo('Token do Hugging Face', _hf,
              segredo: true,
              dica: 'Grátis. Crie conta em huggingface.co, aceite a licença do Gemma em '
                  'huggingface.co/litert-community/Gemma3-1B-IT e crie um token de leitura.'),
          if (_progresso != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: LinearProgressIndicator(value: (_progresso! / 100).clamp(0.0, 1.0)),
            ),
          OutlinedButton(
            onPressed: _progresso != null ? null : _baixarModelo,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_modeloOk ? 'Baixar de novo o modelo offline' : 'Baixar modelo offline'),
            ),
          ),
          if (_msgModelo.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_msgModelo, style: const TextStyle(color: Colors.white60, fontSize: 13)),
            ),
          _titulo('Janelinha e memória'),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Mostrar bolinha ao sair do app'),
            subtitle: const Text('Branca = ativo, cinza = stand-by. Precisa da permissão de sobrepor apps.'),
            value: _janelinha,
            onChanged: (v) => setState(() => _janelinha = v),
          ),
          TextButton(onPressed: _apagarMemoria, child: const Text('Apagar memória e conversa')),
          const SizedBox(height: 8),
          FilledButton(
              onPressed: _salvar,
              child: const Padding(padding: EdgeInsets.all(12), child: Text('Salvar'))),
          const SizedBox(height: 24),
          Center(child: Text('Versão $versaoApp', style: const TextStyle(color: Colors.white38, fontSize: 12))),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
