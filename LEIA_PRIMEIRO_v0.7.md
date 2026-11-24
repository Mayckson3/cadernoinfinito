# Caderno Infinito v0.7.0 — ZIP completo para compilar

Este é um **projeto-fonte integral e independente**, montado a partir da v0.6.1. Não é uma atualização incremental. Ele contém os arquivos `.dart` completos, dependências, testes, configuração da API e scripts para Windows e Android. As pastas nativas de cada plataforma são geradas na primeira compilação pelo Flutter.

**Comece pelo arquivo `LEIA_AQUI_BUILD_COMPLETO.txt` ou dê dois cliques em `04_VERIFICAR_NO_C.cmd`, depois em `01_COMPILAR_TUDO_NO_C.cmd`.** O script trabalha na pasta local `%USERPROFILE%\ci070_full`, não diretamente em unidades do Google Drive.

## Recursos incluídos do PDF EasyNotes (23/11/2026)

1. **Enquadrar conteúdo no zoom.** Botão `Enquadrar todos os objetos desenhados` perto do centralizador: ajusta visualização ao conteúdo visível com margens, em vez de mover os objetos.
2. **Prévia das camadas.** Miniaturas de cada camada exibem traços, formas, textos e imagens, com tamanho proporcional.
3. **Figuras pelo gesto prolongado.** Depois de desenhar e segurar 620 ms, retas, retângulos/quadrados, círculos/elipses e triângulos tornam-se vetores regulares. Retas preservam sua orientação; triângulos preservam seus três vértices. O reconhecimento é aproximado para desenhos muito irregulares.
4. **Arrastar para lixeira.** Ao arrastar a seleção, aparece um alvo vermelho na área inferior direita. Soltar lá remove apenas os objetos editáveis selecionados; é possível desfazer. Isso não apaga o desenho inteiro nem o caderno.
5. **Valores manuais.** Toque na indicação da espessura no rodapé ou abra ajustes de pincel. Digite espessura (0,2–500 px), opacidade e suavização. No menu `Editar seleção > Transformações e organização`, digite dimensões, rotação e tamanho de fonte.
6. **Posicionamento e caixas de texto.** Toque no ponto em que o texto deve começar. Caixa de seleção usa medidas com `TextPainter` em vez de largura fixa de 500 px. Ao alterar o texto ou fonte, a área é recalculada. Anotações antigas com largura padrão incorreta são ajustadas no editor.
7. **Tela cheia segura no Android.** A área usa `SafeArea` em cima e embaixo para evitar sobreposição com barra de status e navegação, inclusive em modo apresentação.

## Build e instalação

- Extraia o ZIP e clique `04_VERIFICAR_NO_C.cmd` (`flutter analyze` + `flutter test`).
- Clique `01_COMPILAR_TUDO_NO_C.cmd` (Windows e Android), `02_COMPILAR_EXE_NO_C.cmd` ou `03_COMPILAR_APK_NO_C.cmd`.
- EXE e APK ficam em `%USERPROFILE%\ci070_full\dist` depois de compilar. Distribua **a pasta Windows completa**, não só o EXE.
- Para Android, não desinstale a versão anterior sem exportar backup: a assinatura do APK precisa ser compatível para instalar por cima.
- Para o Google Drive, providencie credenciais válidas conforme `CONEXAO_GOOGLE.md`. A falta do Web Client ID não bloqueia a compilação, mas impede login sem configuração.

## Limitações de validação

O ZIP foi examinado estruturalmente e foram adicionados testes. **Não há Flutter SDK aqui; portanto, `flutter analyze`, `flutter test` e os builds finais ainda não foram executados.** Confira os resultados em seu Windows e reporte qualquer erro para correção.
