# v0.9.2 — Funcionalidades e desempenho

## Implementado

1. Otimizador de traços com algoritmo Ramer-Douglas-Peucker iterativo,
   preservacao de extremidades, cantos e variacao de pressao.
2. Diagnostico do caderno: objetos, traços, pontos, imagens, textos, camadas.
3. Opcao de captura fluida/economica de pontos (desativavel por caderno).
4. Cache limitado de layouts de textos, caminhos vetoriais e caixas geométricas.
5. Renderizacao condicional: evita pintar novamente o quadro sem mudanca.
6. Cursor do mouse com ValueNotifier (atualizacao de overlay independente).
7. Modo de foco sem serializacao/copia inteira do Sketch a cada gesto.
8. Minimapa com cache de marcadores e contorno de conteudo por revisao.
9. Grade com nivel de detalhe adaptativo ao zoom; imagens com filtro mais
   economico em zoom distante.
10. Registro do Desfazer do novo traco adiado ate a conclusao do gesto,
    evitando codificacao JSON no instante em que a caneta toca a tela.
11. Atalho Ctrl+0 para enquadrar o conteudo do caderno.
12. Novos testes de regressao para pontos, simplificacao e renderizacao.

## Protecoes

- A simplificacao manual nao altera objetos nem camadas bloqueadas.
- Nao simplifica diretamente formas geometricas especiais.
- Preserva o formato `.ci.json`, IDs de caderno e ferramentas.
- Nao inclui OAuth nem chaves pessoais em arquivos versionados.
- Guarda as tarefas de compilacao independentes dos patches antigos.

## Limites de validacao

Checagem estrutural e integridade de ZIP foram executadas. Este ambiente
nao possui o SDK Flutter; flutter analyze, flutter test e builds reais
precisam ser executados no computador do usuario.
