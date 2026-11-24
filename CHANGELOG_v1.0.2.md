# v1.0.2 — Colar imagens do Windows

- Ctrl+V usa PNG ou DIB/DIBV5 (RGB e máscaras de cor) quando o clipboard contém uma imagem; caso contrário mantém a colagem de objetos internos.
- Ação dedicada no menu de seleção e central de ações, exibida no Windows.
- Centralização na área visível, proporção preservada, seleção imediata, salvamento editável e histórico existente.
- PNG nativo preservado; bitmaps convertidos em isolate separado; acesso Win32 via dart:ffi, com dependência direta ffi já transitiva.
- Proteção contra colagem concorrente, mudanças de camada, documentos trocados, gestos ativos e imagens grandes/inválidas.
- Cache de imagens mantém novas colagens durante carregamentos assíncronos; não recarrega todas as imagens ao colar.
- Seis testes adicionais de conversão, segurança e posicionamento.
- Android mantém a importação e a colagem de objetos; edição de texto preserva o Ctrl+V textual.
- Pasta local de compilação ci102_full.

Validação de execução do Flutter e clipboard real pendente no Windows.
