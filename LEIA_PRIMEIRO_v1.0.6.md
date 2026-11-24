# Caderno Infinito v1.0.6 — projeto completo para EXE e APK

## Mapas mentais e vetores
1. Abra um caderno e use o ícone de árvore **Mapas mentais e vetores**. No celular ele fica na barra rolável de ferramentas; no computador, na barra lateral (role se necessário).
2. Escolha Nuvem, Balão de fala, Caixa arredondada, Cápsula ou Hexágono e arraste no quadro. Digite ou escreva dentro da forma com as ferramentas normais. Os textos/traços são objetos independentes; agrupe-os se desejar mover tudo junto.
3. Pressione V, selecione somente a forma e arraste um botão azul **+** para outra forma. Também pode escolher Conector curvo/reto/em cotovelo e arrastar diretamente entre duas formas. A extremidade se encaixa ao contorno e acompanha mudanças de posição. Para uma seta solta, solte em espaço vazio.
4. Selecione uma curva vetorial ou conector. As alças azuis alteram extremos; nas curvas, as duas alças laranja alteram as tangentes. Arraste a alça circular externa para girar. Conectores vinculados mantêm seus extremos presos; escolha Desvincular conectores selecionados para girá-los sem vínculo.
5. No mesmo menu, escolha contorno, preenchimento ou pontas de seta. Com vetores selecionados, o estilo também é aplicado a eles. Sem seleção, salva como padrão para próximos vetores do caderno. Use Reta tracejada para criar uma linha já tracejada.
6. Use **Inserir modelo radial com 4 ramos** para começar rapidamente um mapa vazio. F2 lista os novos atalhos Shift+1 a Shift+0.
7. Para exportar, prefira SVG, PDF comum ou PNG. SVG usa curvas cúbicas e aproxima os contornos das formas por segmentos. O PDF vetorial antigo não suporta esses novos vetores; DXF exporta segmentos sem estilos.


## Estabilização extra forte ao soltar a caneta
- Em **Ajustes precisos do pincel** ou **Estúdio de pincéis e cores**, selecione **Estabilização ao soltar**. O controle agora aceita 0–200%. Padrão 125% para ferramentas sem ajuste salvo; 100% já usa o filtro reforçado. Ajustes antigos são respeitados.
- 0% desliga o filtro de coordenadas; 75% mantém o filtro natural anterior; 125–150% oferece correção forte; 200% oferece o maior alcance. Em letras muito pequenas, se a forma ficar excessivamente arredondada, reduza a intensidade.
- O filtro fino é combinado com regressão quadrática local, com proteção de pontas e cantos. A amostragem é mais densa em níveis fortes. A edição continua vetorial e a pressão original é armazenada.
- Em níveis acima de 75%, o contorno das novas canetas sensíveis à pressão é preenchido continuamente, suavizando transições de largura. O ajuste não converte letras em retas e não atua sobre desenhos já salvos.
- Use **Guardar ajustes desta ferramenta** para conservar o nível neste caderno. Reconhecimento de formas, atalhos e demais recursos permanecem separados.

## Atalhos do teclado
- F2: referência de atalhos (também disponível na central de ações). F1: central de ações.
- B: caneta; P: lápis; E: borracha; M: marcador; V: selecionar; Q: laço; H: mover tela; T: texto; R: retângulo; O: elipse; L: reta; A: seta; I: conta-gotas.
- Ctrl+Z / Ctrl+Y ou Ctrl+Shift+Z: desfazer/refazer; Delete: excluir seleção; Ctrl+G / Ctrl+Shift+G: agrupar/desagrupar.
- Ctrl+0: enquadrar desenhos; Ctrl+1: centralizar; = / -: zoom; [ / ]: espessura; F11: tela cheia. Alt+R: girar o quadro (R agora é retângulo).
- Durante a edição de texto, teclas de ferramentas são desativadas. Ctrl+B/I/U formata; Ctrl+Shift+X aplica tachado, Ctrl+Shift+H aplica/remove destaque amarelo. Ctrl+Enter conclui; Esc cancela.
- Atalhos funcionam com teclado físico e foco no editor; não são globais no sistema.

## Colar imagens do Windows
1. Copie uma imagem (por exemplo, clique direito > Copiar imagem no navegador) ou capture uma região com Win+Shift+S.
2. Abra um desenho, encerre qualquer edição de texto e use Ctrl+V. Não é necessário selecionar a ferramenta Imagem nem abrir o gerenciador de arquivos.
3. A imagem será inserida na camada ativa, no centro da área visível, proporcional ao tamanho original, e ficará selecionada para mover, girar ou redimensionar.
4. Também pode usar Editar seleção ou Todas as ações do caderno > Colar imagem do Windows. Ctrl+Z desfaz a inserção, respeitando o limite de histórico do aplicativo.
5. O comando continua aceitando objetos internos copiados. Durante a edição de texto, Ctrl+V mantém o comportamento de colar texto do sistema.
6. Funciona com PNG e bitmaps RGB/DIB de 16, 24 e 32 bits nos formatos suportados. Copiar apenas um endereço ou arquivo no Explorer não é igual a copiar pixels; nesses casos use a importação existente. A colagem nativa de imagens é específica do Windows, não do Android.
7. O app não lê o clipboard em segundo plano. A leitura e conversão acontecem somente ao colar, em um isolate separado. PNGs preservam os bytes originais; bitmaps são convertidos para PNG. Limites de segurança: 64 MiB de bytes e 24 Mi de pixels por imagem.

## Correção anterior preservada
O campo de texto declara a linha de base alfabética exigida pelo Flutter. A edição no quadro e a formatação por trecho permanecem.

## Compilar
1. Extraia todo o ZIP (não sobreponha um projeto anterior).
2. Execute `04_VERIFICAR_NO_C.cmd`. Se análise e testes passarem, execute `01_COMPILAR_TUDO_NO_C.cmd`.
3. Pasta de compilação local: `%USERPROFILE%\ci106_full`. O Flutter prepara as pastas nativas quando ausentes.
4. Resultados: `%USERPROFILE%\ci106_full\dist\CadernoInfinito_Windows\caderno_infinito.exe` (copie a pasta inteira) e `%USERPROFILE%\ci106_full\dist\CadernoInfinito_Android.apk`.
5. Faça backup dos cadernos antes de atualizar. As credenciais OAuth devem ser configuradas separadamente; não compartilhe JSONs de credenciais.

## Texto no quadro
1. Selecione **Inserir texto**. Na barra inferior (ou no botão de tamanho em tela cheia), toque em **Fonte padrão** e informe o tamanho antes de digitar.
2. Toque com a caneta ou mouse no lugar onde o texto começa; em modo dedo para navegar, use a caneta para escrever.
3. Digite diretamente no quadro. A barra contextual tem B/I/U, tachado, destaque, cor e tamanho de trecho. Deslize horizontalmente para acessar mais ícones no celular.
4. Selecione caracteres usando a seleção normal do campo de texto; toque no ícone para formatar só o trecho. Sem seleção, os estilos se aplicam à próxima digitação. O botão de tamanho à esquerda altera toda a caixa. O ícone Tamanho do trecho ajusta só a seleção ou a digitação seguinte.
5. Toque no ✓ ou em uma área vazia para concluir; X ou Esc cancela. Ctrl+Enter conclui no PC. Uma anotação vazia não é criada; para apagar uma caixa existente, use Selecionar → Excluir.
6. Para editar texto existente, toque nele com a ferramenta Texto, ou selecione o objeto e use Editar texto. Para mover, redimensionar e girar, use Selecionar. A formatação é salva no arquivo editável.

## Observações
- Fonte padrão inicial: 18 px do quadro. O tamanho visual acompanha o zoom. A preferência é por caderno.
- A interface usa as fontes do sistema; diferenças de fonte/métricas entre Windows e Android ou em leitores SVG são possíveis.
- A exportação PDF vetorial de linhas e formas mantém sua restrição anterior (não aceita textos); use PDF comum ou SVG para texto.
- A nova execução dos testes Flutter está pendente neste ambiente. Verifique no seu PC antes de substituir a versão anterior.
