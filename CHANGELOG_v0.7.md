# Alterações — v0.7.0 (23/11/2026)

Base: projeto-fonte completo v0.6.1, sem dependência de patches anteriores.

- Zoom: enquadramento real de objetos visíveis, com cálculo de zoom e deslocamento da câmera.
- Painel de camadas: miniaturas renderizadas por camada, para reconhecer o conteúdo.
- Caneta: reconhecimento e normalização de triângulos e refinamento de reta, retângulo/quadrado e elipse/círculo após toque prolongado.
- Seleção: alvo de exclusão por arrastar, com respeito a bloqueios e Desfazer.
- Campos numéricos: espessura, opacidade, suavização, largura/altura, rotação e fonte.
- Texto: dimensões reais calculadas com TextPainter, criação no ponto tocado, recálculo ao editar e migração visual do padrão anterior de 500 px.
- Tela cheia: proteção das áreas do sistema Android usando SafeArea.
- Testes adicionais de viewport, exclusão, reconhecimento e geometria de texto.
- Scripts de compilação usam pasta local `%USERPROFILE%\ci070_full` para evitar erros de link simbólico e caminho longo.

Não foram incluídos dados pessoais, desenhos existentes nem credenciais OAuth privadas.
