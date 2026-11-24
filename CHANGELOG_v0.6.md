# Alterações da v0.6.0 sobre a v0.5.2

- Adicionada transformação visual com oito alças de dimensionamento e um controle externo para girar a seleção.
- Movimentação de múltiplos objetos arrastando o interior da seleção.
- Cálculos de coordenadas independentes do zoom, rotação e deslocamento da câmera; seleção em unidades de tela.
- Alterações feitas a partir de cópias originais dos elementos durante um gesto para prevenir distorções cumulativas; histórico Desfazer/Refazer preservado.
- Proteção contra inversão do retângulo ao arrastar uma alça para além do lado oposto.
- Rotação em passos de 15° com Shift no teclado Windows; suporte a giros além de 180° num mesmo gesto.
- A seleção respeita o bloqueio das camadas e dos elementos: alças não alteram elementos bloqueados.
- Novos testes de transformação, geometria e preservação de IDs.
- Novo fluxo de compilação em um clique via `.cmd`; geração automática das pastas nativas (quando ausentes) e cópia dos resultados para `dist/`.
- Mantidos biblioteca, Drive, importação e exportação, pastas, editor e demais recursos da v0.5.2.

Não foi alterado o formato dos desenhos nem adicionado um serviço proprietário de nuvem. As credenciais Google permanecem responsabilidade do dono do projeto.
