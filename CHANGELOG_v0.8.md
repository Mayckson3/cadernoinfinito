# Caderno Infinito v0.8.0 — melhorias integradas

Base: código-fonte completo v0.7.0. Os arquivos permanecem compatíveis com `.ci.json` antigos.

## Novidades implementadas
- Alinhamento magnético com outros objetos ao mover uma seleção. Detecta bordas e centros em qualquer zoom, mostra guias e pode ser desligado em **Grades e artboard**.
- **Shift + alças** no Windows preserva a proporção ao redimensionar a seleção.
- Traços da **caneta** usam largura por segmento quando o dispositivo fornece amostras de pressão. A preferência pode ser desativada.
- **Minimapa opcional** do quadro com toque/clique para navegar e contorno da área visível.
- **Índice do quadro**: salvar regiões e voltar a elas; ligar qualquer seleção a uma região e abrir pelo menu da seleção.
- **Buscar texto digitado** no caderno e navegar diretamente até a caixa encontrada (Ctrl+F no Windows).
- **Histórico local**: até 12 instantâneos anteriores por caderno, de até 16 MB cada, automáticos em intervalos de trabalho de aproximadamente 15 min. Permite criação manual e restauração confirmada.
- **Ferramenta compasso**: círculo com centro no primeiro toque e raio ao arrastar.
- **Ferramenta curva Bézier**: produz uma curva cúbica suavizada a partir da trajetória desenhada (os controles não são editados individualmente).
- Otimização da renderização: objetos visíveis agrupados por camada, evitando composição offscreen de camadas opacas; minimapa limitado a amostras em documentos muito extensos.
- Novos testes de encaixe, bookmarks, geometria e pressão; código-fonte completo com compiladores automatizados.

## Funcionalidades da v0.7 preservadas
- Camadas com miniaturas, opacidade, mesclar, duplicar, ocultar, bloquear e reordenar.
- Seleção por laço e caixa, agrupamento, espelhamento, transformação e exclusão por arraste na lixeira.
- Reconhecimento simples de formas ao segurar, importação/anotação visual de páginas de PDF, biblioteca de objetos, medição de distâncias/ângulos e exportações.
- Salvamento atômico local, backup separado, sincronização via Drive com cópia de conflitos e exclusões sincronizadas.

## Limitações importantes, sem promessas indevidas
- **OCR manuscrito** ainda não incluído; a pesquisa local encontra apenas texto digitado no editor.
- PDF importado permanece como base visual anotável; não edita nativamente o texto original do PDF.
- Curva Bézier não possui controle independente de âncoras; o compasso não possui painel numérico de raio.
- Marcadores ligam regiões do **mesmo caderno**; vínculos entre arquivos diferentes não foram concluídos.
- Histórico de versões é **local**, não é sincronizado com o Drive; sincronização com o app fechado não foi implementada.
- OAuth do Google Drive precisa ser cadastrado no projeto Google Cloud do usuário. Não estão incluídas credenciais pessoais.
- **Flutter não estava instalado neste ambiente**; foram verificados arquivos e delimitadores, mas `flutter analyze`, `flutter test` e builds EXE/APK devem ser executados no computador do usuário.
