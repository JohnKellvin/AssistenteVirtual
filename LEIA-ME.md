# Jarvis para Android, beta 2.2

Assistente de voz em Flutter para Android: esfera, voz em português, janelinha flutuante,
stand-by, memória, pesquisa pela internet e modelo offline dentro do celular.
Nome do assistente e tratamento ("Senhor") configuráveis.

## 1. Gerar e baixar o APK

1. Cada envio para a branch `main` inicia o fluxo **Gerar APK**.
2. Para baixar um build de teste, abra **Actions**, selecione a execução e baixe `jarvis-apk` em **Artifacts**.
3. Depois que a compilação passar, envie a tag `v2.2.0-beta.1` para publicar a versão Beta 2.2:

   ```bash
   git tag v2.2.0-beta.1
   git push origin v2.2.0-beta.1
   ```

   O fluxo compila o APK e o anexa à pré-release **Assistente Beta 2.2** em **Releases**.
4. Instale o `app-release.apk` (o Android pode pedir para liberar fontes desconhecidas).

Se a compilação falhar, abra o passo que ficou vermelho e envie o texto do erro.

## 2. Primeira abertura

1. Escolha o nome do assistente e como ele te chama.
2. Libere o microfone e a permissão "sobrepor outros apps" (para a bolinha).
3. Para funcionar sem internet, baixe o pacote de português do reconhecimento de voz:
   Configurações do Android > Aplicativos > Google > Reconhecimento de fala offline.

## 3. Como usar

- **Um toque** no botão: começa a ouvir. Depois de 3 s de silêncio ele envia sozinho.
  Outro toque durante a escuta envia na hora. Toque enquanto ele fala ou pensa: ele para.
- **Stand-by**: diga "stand-by" ou "pode parar". A esfera apaga. Toque no botão para acordar.
- **Bolinha**: ao sair do app, aparece por cima das outras telas. Branca = ativo, cinza "zZ" = stand-by.
  Arraste para mover, toque para voltar ao Jarvis.
- O stand-by NÃO escuta o microfone em segundo plano (o Android só permite isso com escuta
  contínua e notificação fixa, que gasta bateria). Ele só ouve com o app aberto e depois de um toque.

## 4. O que ele faz

**Sem internet (por regras, rápido):** alarme, timer, calendário, que horas são, abrir qualquer app
instalado (Play Store, APK ou modificado, pelo nome), abrir configurações (Wi-Fi, Bluetooth, brilho,
bateria, som...), rota no mapa.
Exemplos: "alarme às sete e meia", "timer de cinco minutos", "marca dentista amanhã às 15",
"abre o YouTube", "abre as configurações do Wi-Fi", "como chego em Copacabana".

**Memória (só no aparelho):** "lembra que eu moro em Salvador", "o que você sabe", "esquece Salvador",
"esquece tudo", "conversa nova". Ele também segue o fio das últimas 8 trocas.

Se quiser usar o Obsidian, abra Configurações > Obsidian como memória e escolha a pasta do cofre.
O app cria a nota `Assistente - Memoria.md` com o perfil, fatos lembrados e conversa recente, importa
esses dados ao abrir e continua com a cópia local se a pasta ficar indisponível. As chaves de API ficam
nas configurações do app, fora da nota.

**Perguntas livres com internet:** em Configurações, cole chaves de uma ou mais IAs. Ele tenta na ordem
e, se uma falhar, usa a próxima: Gemini (aistudio.google.com), Groq (console.groq.com), Mistral,
OpenRouter, Cerebras, Cohere, NVIDIA. A disponibilidade de planos grátis e modelos muda com o tempo.
Buscadores opcionais: Tavily, Serper, Brave. Sem chave de busca, ele usa Wikipedia e DuckDuckGo,
que respondem menos.

**Perguntas livres sem internet:** modelo Gemma 3 de 1 bilhão de parâmetros dentro do celular
(cerca de 584 MB). Em Configurações > Modelo offline, cole um token do Hugging Face e toque em baixar.
O Gemma é um modelo protegido: crie conta grátis em huggingface.co, aceite a licença em
huggingface.co/litert-community/Gemma3-1B-IT e crie um token de leitura.
No A17 de 4 GB de RAM, a resposta pode levar vários segundos e ele erra mais que as IAs da internet.
O token do Hugging Face é diferente das chaves das IAs online. A licença do Gemma precisa ser aceita
na página do modelo antes do download. Se uma chave online falhar, o app informa se ela foi recusada,
se o limite acabou ou se o serviço/modelo está indisponível.

## 5. Avisos

- Limites e modelos das camadas gratuitas mudam. Se um provedor parar, o nome do modelo fica em
  `lib/provedores.dart`.
- Confira o plano antes de usar uma chave: provedores podem mudar limites e cobrar quando a conta
  tem faturamento ativado. Algumas camadas gratuitas usam o conteúdo para melhorar os produtos; não
  envie informações pessoais nas perguntas pela internet.
- As chaves ficam criptografadas no armazenamento protegido do Android. Na primeira abertura, as
  chaves salvas por versões antigas são migradas automaticamente. Ao abrir Configurações, os campos
  ficam vazios: deixar vazio mantém a chave; a lixeira apaga a chave depois de tocar em Salvar.
- O app não inclui suas chaves no código nem no ZIP. Ainda assim, um app móvel que chama APIs
  diretamente não consegue esconder totalmente uma chave de alguém com controle avançado do aparelho.
  Use chaves suas, com limites e restrições ativados; não publique APKs que contenham suas chaves.
- A pergunta enviada pela internet vai ao provedor da chave usada. A memória fica no aparelho ou na pasta Obsidian que
  você escolheu; se essa pasta sincronizar com outros dispositivos, as notas também podem ser enviadas.
  Não coloque chaves de API no cofre e não deixe o celular destravado com outras pessoas.
- Pacotes de IA local mudam de API com frequência. Se o passo do modelo local der erro de compilação,
  o problema provavelmente está em `lib/modelo_local.dart`: me mande o erro.

## 6. O que fica para a próxima versão

- Mexer dentro de outros apps (tocar botões) exige o serviço de acessibilidade.
- Versão para computador, com o Claude Code como núcleo.
