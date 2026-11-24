# v1.0.0 — Texto editável diretamente no quadro

- Ferramenta Texto: toque no ponto do quadro, digite ali e confirme. O tamanho padrão é independente do pincel e é guardado no caderno.
- Edição de texto existente por toque com a ferramenta Texto ou pelo menu Editar seleção → Editar texto.
- Barra contextual de ícones: negrito, itálico, sublinhado, tachado, destaque (cores), cor do trecho, tamanho do trecho e limpar formatação. Com seleção de caracteres, altera somente a seleção; com cursor sem seleção, define o estilo da próxima digitação.
- Tamanho da caixa de texto e tamanho de trecho são ajustáveis em px do quadro. Formatação persiste em `meta.richRuns` e acompanha a transformação do objeto; texto simples de versões anteriores continua legível.
- Medição e pintura compartilham os estilos, e o cache diferencia textos de formatação distinta. O editor não repinta todo o quadro a cada tecla. Exportação PNG/PDF comum utiliza o renderizador; SVG usa texto editável e retângulos de destaque, com possíveis diferenças de métricas em leitores externos.
- Ao abrir teclado, o quadro pode deslocar-se para manter o cursor visível, sem modificar a posição do objeto. Barra contextual horizontal rolável para telas estreitas. Ctrl+B/I/U e Ctrl+Enter no PC; Esc cancela.
- Cinco novos testes definidos para estilos, edição, serialização, métricas/SVG e widget de texto embutido. Nenhuma dependência nova. A análise, os testes e os builds Flutter ainda não foram executados nesta versão.
