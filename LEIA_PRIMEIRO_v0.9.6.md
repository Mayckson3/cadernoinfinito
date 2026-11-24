# Caderno Infinito v0.9.6 — Projeto completo para compilar

## O que mudou
No menu radial, o **centro não mostra nenhum ícone**. Ele exibe somente um texto curto (“Arraste”, nome da ferramenta apontada ou última ação). Os ícones das ferramentas continuam ao redor, com destaque quando a caneta se aproxima.

## Compilar
1. Extraia o ZIP integral em qualquer pasta, sem misturá-lo a uma versão anterior.
2. Execute `04_VERIFICAR_NO_C.cmd` para rodar `flutter analyze` e `flutter test`.
3. Execute `01_COMPILAR_TUDO_NO_C.cmd` para gerar EXE e APK, ou escolha os scripts individuais.
4. O script copia a fonte para `%USERPROFILE%\ci096_full` no disco C:, evitando o erro de links simbólicos ocorrido ao compilar dentro do Google Drive em E:.
5. Os arquivos compilados serão copiados para `%USERPROFILE%\ci096_full\dist` quando a compilação for bem-sucedida.

**Observação:** a configuração do login Google depende de OAuth. Antes de instalar outra versão no Android, faça backup dos cadernos. O ZIP traz o código-fonte completo e os scripts, não EXE e APK prontos. A configuração de plataformas nativas é gerada pelo Flutter quando necessário.
