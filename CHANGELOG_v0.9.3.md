# Caderno Infinito v0.9.3 — Atalhos de escrita com caneta digital

## Funções implementadas

1. **Borracha temporária pelo botão lateral da caneta**: mantenha o primeiro
   botão pressionado enquanto toca o quadro. Ao levantar, volta ao pincel
   anterior sem escolher ferramentas em menus.
2. **Borracha pela ponta invertida** (`PointerDeviceKind.invertedStylus`),
   nos equipamentos que enviam essa informação ao Flutter.
3. **Segundo botão da caneta para laço** quando disponível. Após selecionar,
   o app entra em `Selecionar` para mover ou redimensionar os elementos.
4. **Borracha temporária mais confortável**: durante o gesto de apagar, o
   tamanho é no mínimo 13 px. A espessura anterior é restaurada ao terminar.
5. **Barra de ações rápidas** discreta e retrátil sobre o quadro. Inclui
   última caneta ou marcador, marcador, borracha, selecionar, navegar com
   dedo, desfazer/refazer, quatro espessuras prontas e acesso rápido à paleta.
6. **Toque rápido com dois dedos para Desfazer**, verificado ao soltar os
   dedos. Zoom por pinça e gestos demorados não acionam a função.
7. **Gestos opcionais com três ou quatro dedos**, reconhecidos na liberação,
   e não quando se inicia um gesto de zoom. Configuráveis em Precisão.
8. **Modo dedo navega / caneta escreve** salvo por caderno. Evita rabiscos
   acidentais ao apoiar a mão e tocar a tela.
9. **Atalhos Windows**: Alt+B (último pincel), Alt+E (borracha),
   Alt+V (selecionar), preservando Ctrl+V para colar.
10. **Reconhecimento de toques na barra flutuante**: impede que um toque nos
    botões da barra produza um ponto acidental no quadro.
11. **Minimapa e barra sem sobreposição**: com minimapa ativo, a barra de
    atalhos passa para baixo dele.

## Testes e compatibilidade

- Novo serviço independente `lib/services/stylus_shortcuts.dart`.
- Testes `test/stylus_shortcuts_test.dart` para botões, ponta invertida,
  gestos sem movimento, zoom, cancelamento e limite de tempo.
- Configurações adicionais persistidas em `doc.gestures`, mantendo a
  estrutura de arquivo `.ci.json` e documentos antigos compatíveis.
- Nenhum recurso de OAuth foi alterado. É necessário continuar a configurar
  o Google Cloud para utilizar o Drive.

## Limitações honestas

- A resposta de botões físicos depende do hardware, driver e sistema.
  Nem todo dispositivo informa à aplicação a pressão de um botão lateral.
- A barra rápida é uma interface nova, não uma calibração de latência.
- A verificação foi estrutural e dos arquivos; **flutter analyze**, **flutter test**,
  builds e testes reais com caneta precisam ser executados no PC do usuário.
