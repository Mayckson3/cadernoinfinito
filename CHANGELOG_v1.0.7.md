# v1.0.7 — Correção de análise dos mapas mentais

- Corrige expressão condicional no cálculo do raio de cápsulas e caixas arredondadas (`mind_map_vectors.dart`). Literais decimais explícitos evitam a interpretação como operador de acesso condicional.
- Acrescenta teste de regressão para os dois raios, sem remover ou enfraquecer testes existentes.
- Preserva as ferramentas de mapas mentais, conectores, curvas vetoriais, atalhos e estabilização da v1.0.6. Sem alteração de dependências.
- Pasta isolada de compilação `ci107_full`. Flutter/Dart não disponíveis no ambiente de preparação; análise, testes e builds devem ser executados no PC.
