# v1.0.8 — Correção do teste de mapas mentais

- Importa `Rect` explicitamente de `dart:ui` no teste `mind_map_vectors_test.dart`.
- Preserva todas as verificações, código de produção e dependências da v1.0.7.
- Nova pasta isolada `ci108_full`. Análise, testes e builds pendentes no PC.

# v1.0.7 — Correção de análise dos mapas mentais

- Corrige expressão condicional no cálculo do raio de cápsulas e caixas arredondadas (`mind_map_vectors.dart`). Literais decimais explícitos evitam a interpretação como operador de acesso condicional.
- Acrescenta teste de regressão para os dois raios, sem remover ou enfraquecer testes existentes.
- Preserva as ferramentas de mapas mentais, conectores, curvas vetoriais, atalhos e estabilização da v1.0.6. Sem alteração de dependências.
- Pasta isolada de compilação `ci107_full`. Flutter/Dart não disponíveis no ambiente de preparação; análise, testes e builds devem ser executados no PC.

# v1.0.6 — Mapas mentais e vetores

- Menu dedicado (ícone de árvore), 10 ferramentas novas, 44 no total. Nuvem, balão de fala, caixa arredondada, cápsula, hexágono, reta tracejada, curva vetorial cúbica, conectores curvo, reto e em cotovelo.
- Selecione uma forma (V): arraste os botões azuis + para criar um conector. Ou selecione um conector no menu e arraste de uma forma para outra. Vínculos por IDs persistem no documento; atualizam quando as formas se movem, giram ou mudam de tamanho. Uma forma apagada solta a extremidade correspondente. Conectores não fazem roteamento automático de obstáculos.
- Curvas: selecione para arrastar as duas âncoras azuis e os dois controles laranja. Conectores retos/cotovelo possuem duas âncoras. Alças externas de seleção giram/redimensionam a geometria. Para girar livremente uma curva vinculada, desvincule-a primeiro; Shift encaixa a rotação em 15 graus.
- Estilos contínuo, tracejado, pontilhado e traço-ponto; preenchimentos com opacidade; pontas de seta em uma ou ambas as extremidades; aplicáveis à seleção ou como padrão do caderno. A reta tracejada começa tracejada.
- Modelo radial vazio com quatro ramos vinculados e três modelos novos na biblioteca de objetos. Texto e escrita livre continuam independentes das formas; agrupe-os manualmente para mover juntos. Sem novo plugin.
- Copiar/colar e duplicar remapeiam IDs de nós incluídos na seleção; links externos são removidos. SVG exporta curvas cúbicas e contornos aproximados de formas; PDF comum/PNG preservam a aparência. PDF vetorial antigo avisa para usar PDF comum ou SVG quando há vetores novos. DXF aproxima curvas por segmentos, sem estilos.
- Seis testes novos; análise/compilação Flutter e teste de interação real pendentes. Pasta isolada ci106_full.

# v1.0.5 — Estabilização extra forte

- Intensidade de 0 a 200%, padrão de 125% para ferramentas sem ajuste salvo. Predefinições anteriores mantidas; 100% já usa o novo filtro. 75% conserva o filtro anterior.
- Acima de 75%, filtro fino seguido de regressão quadrática local em janelas mais amplas, com 3–4 passagens, proteção de extremos, vértices, pequenos laços e lacunas grandes. Mantém coordenadas editáveis e atributos originais de pressão, inclinação e orientação.
- Captura de pontos mais densa no modo forte; ajuste final somente ao soltar.
- Contorno preenchido contínuo e largura suavizada em traços novos com pressão, dinâmicos e tinteiro. Reutiliza cache de caminhos durante navegação. Traços antigos não são remodelados.
- Quatro testes adicionais; simulações numéricas independentes, não testes Flutter. Sem dependências novas. Pasta isolada `ci105_full`.

# v1.0.4 — Escrita mais limpa

- Filtro adaptativo ao finalizar cada traço livre: 2 ou 3 passagens simétricas, peso por comprimento de arco, proteção de vértices, curvas, pontas e acentos curtos.
- Intensidade padrão 75%, ajustável de 0 a 100%, respeitando predefinições existentes. Sem reamostragem ou perda de pressão, inclinação e orientação.
- Caminho curvo conectado para canetas de pressão/dinâmica/tinteiro em traços estabilizados; corrige renderização de pontos isolados.
- Não remodela desenhos antigos, não interfere com o reconhecimento geométrico por pausa e não adiciona dependências.
- Sete testes novos em `test/stroke_stabilizer_test.dart`. Simulação numérica independente confirmada; testes Flutter e compilação pendentes no PC.
- Pasta de build isolada `ci104_full`.

# v1.0.3

Atalhos de teclado para as 34 ferramentas, edição, navegação e texto. Consulte `CHANGELOG_v1.0.3.md`.

# v1.0.2

Colagem nativa de imagens PNG/DIB do Windows, com Ctrl+V e ações no editor. Consulte `CHANGELOG_v1.0.2.md`.

# v1.0.1

Corrige a criação do campo de texto embutido (textBaseline obrigatório com inherit: false). Veja `CHANGELOG_v1.0.1.md`.

# v1.0.0

Texto direto no quadro, tamanho padrão e formatação por trecho. Consulte `CHANGELOG_v1.0.0.md`.

# Caderno Infinito v0.9.9 — seleção múltipla nas pastas

Base: v0.9.8 (97 testes passaram no computador do usuário; EXE e APK compilaram com sucesso).

## Mudanças

- `Selecionar vários` em qualquer pasta e em `Todos os desenhos`.
- Toque longo em um cartão para entrar diretamente no modo seleção; toques seguintes marcam/desmarcam itens.
- Checkbox visível sobre cada miniatura no modo seleção.
- `Selecionar todos` / `Desmarcar todos` da lista **atualmente exibida**.
- `Mover selecionados para a Lixeira`, com confirmação e contagem exata.
- `Mover todos desta pasta para a Lixeira`: inclui somente desenhos ativos diretamente na pasta, **não subpastas**; ignora a busca para mover todos os itens da pasta, não apenas os resultados filtrados.
- Na tela `Todos`, `Mover todos para a Lixeira` abrange as pastas ativas, com confirmação explícita.
- Na Lixeira, restaurar ou excluir definitivamente vários de uma vez.
- Mudança de pasta encerra a seleção; alterações no filtro de busca limpam a seleção para evitar apagar itens ocultos.
- Operações em lote não executam ao mesmo tempo que uma sincronização ou edição, e só sincronizam após terminar os salvamentos locais.
- Mantido o formato `.ci.json`, as pastas e os marcadores de exclusão permanente no Google Drive.
- Testes de regressão para pasta, subpasta, busca e itens da Lixeira.
- Pasta de compilação isolada `ci099_full`.

## Segurança dos desenhos

**Mover para a Lixeira não exclui definitivamente.** Os arquivos continuam recuperáveis na Lixeira até o usuário escolher exclusão definitiva. Todas as operações de exclusão em lote pedem confirmação. Ao usar o Drive, as alterações locais serão sincronizadas depois, quando houver conexão.

## Validação

Checagem da árvore de arquivos, scripts e integridade do ZIP realizada. Não houve execução do Flutter neste ambiente. Execute `04_VERIFICAR_NO_C.cmd` para verificar análise e testes; depois `01_COMPILAR_TUDO_NO_C.cmd` para compilar.
