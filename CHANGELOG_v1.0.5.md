# v1.0.5 — Estabilização extra forte

- Intensidade de 0 a 200%, padrão de 125% para ferramentas sem ajuste salvo. Predefinições anteriores mantidas; 100% já usa o novo filtro. 75% conserva o filtro anterior.
- Acima de 75%, filtro fino seguido de regressão quadrática local em janelas mais amplas, com 3–4 passagens, proteção de extremos, vértices, pequenos laços e lacunas grandes. Mantém coordenadas editáveis e atributos originais de pressão, inclinação e orientação.
- Captura de pontos mais densa no modo forte; ajuste final somente ao soltar.
- Contorno preenchido contínuo e largura suavizada em traços novos com pressão, dinâmicos e tinteiro. Reutiliza cache de caminhos durante navegação. Traços antigos não são remodelados.
- Quatro testes adicionais; simulações numéricas independentes, não testes Flutter. Sem dependências novas. Pasta isolada `ci105_full`.
