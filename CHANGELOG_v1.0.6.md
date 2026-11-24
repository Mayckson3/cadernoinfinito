# v1.0.6 — Mapas mentais e vetores

- Menu dedicado (ícone de árvore), 10 ferramentas novas, 44 no total. Nuvem, balão de fala, caixa arredondada, cápsula, hexágono, reta tracejada, curva vetorial cúbica, conectores curvo, reto e em cotovelo.
- Selecione uma forma (V): arraste os botões azuis + para criar um conector. Ou selecione um conector no menu e arraste de uma forma para outra. Vínculos por IDs persistem no documento; atualizam quando as formas se movem, giram ou mudam de tamanho. Uma forma apagada solta a extremidade correspondente. Conectores não fazem roteamento automático de obstáculos.
- Curvas: selecione para arrastar as duas âncoras azuis e os dois controles laranja. Conectores retos/cotovelo possuem duas âncoras. Alças externas de seleção giram/redimensionam a geometria. Para girar livremente uma curva vinculada, desvincule-a primeiro; Shift encaixa a rotação em 15 graus.
- Estilos contínuo, tracejado, pontilhado e traço-ponto; preenchimentos com opacidade; pontas de seta em uma ou ambas as extremidades; aplicáveis à seleção ou como padrão do caderno. A reta tracejada começa tracejada.
- Modelo radial vazio com quatro ramos vinculados e três modelos novos na biblioteca de objetos. Texto e escrita livre continuam independentes das formas; agrupe-os manualmente para mover juntos. Sem novo plugin.
- Copiar/colar e duplicar remapeiam IDs de nós incluídos na seleção; links externos são removidos. SVG exporta curvas cúbicas e contornos aproximados de formas; PDF comum/PNG preservam a aparência. PDF vetorial antigo avisa para usar PDF comum ou SVG quando há vetores novos. DXF aproxima curvas por segmentos, sem estilos.
- Seis testes novos; análise/compilação Flutter e teste de interação real pendentes. Pasta isolada ci106_full.
