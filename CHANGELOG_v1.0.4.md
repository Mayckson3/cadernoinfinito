# v1.0.4 — Escrita mais limpa

- Filtro adaptativo ao finalizar cada traço livre: 2 ou 3 passagens simétricas, peso por comprimento de arco, proteção de vértices, curvas, pontas e acentos curtos.
- Intensidade padrão 75%, ajustável de 0 a 100%, respeitando predefinições existentes. Sem reamostragem ou perda de pressão, inclinação e orientação.
- Caminho curvo conectado para canetas de pressão/dinâmica/tinteiro em traços estabilizados; corrige renderização de pontos isolados.
- Não remodela desenhos antigos, não interfere com o reconhecimento geométrico por pausa e não adiciona dependências.
- Sete testes novos em `test/stroke_stabilizer_test.dart`. Simulação numérica independente confirmada; testes Flutter e compilação pendentes no PC.
- Pasta de build isolada `ci104_full`.
