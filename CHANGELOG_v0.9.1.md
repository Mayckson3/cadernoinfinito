# Caderno Infinito v0.9.1 — correções após auditoria do código

## Segurança e dados
- `LocalStore.restoreBackup`: elimina acesso nulo quando ID restaurado foi excluído definitivamente; restaura com ID novo.
- `LocalStore._validJson`: diferencia desenhos, índice do Drive e marcadores de exclusão (lista JSON); permite recuperar arquivos .tmp/.bak corretamente.
- `LocalStore._writeUnlocked`: protege o último backup válido ao salvar após corrupção do arquivo principal.
- `LocalStore.get`: valida correspondência entre ID do arquivo e ID interno do desenho.

## Editor e organização
- Impede alterações destrutivas em objetos/camadas bloqueados na seleção, mesmo que previamente selecionados.
- Colar valida conteúdo, tamanho máximo, limite de 500 elementos e desbloqueia apenas as novas cópias; grupos colados/duplicados não se misturam aos originais.
- A exclusão de camada exige confirmação e entra no histórico Desfazer/Refazer. Duplicação preserva opacidade, visibilidade e bloqueio da camada.
- Salva trecho do traço em andamento quando um segundo toque inicia um gesto multitoque.
- Evita divisão por zero no encaixe na grade e zoom indevido em rolagem horizontal.
- Defende Desfazer/Refazer contra dados antigos com lista de camadas vazia.

## Drive e experiência
- Cancelamento de autorização no navegador Windows gera mensagem clara em vez de acessar código OAuth inexistente.

## Compilação e testes
- `COMPILAR_NO_C.ps1` usa destino isolado `ci091_full`.
- Adicionados 5 testes regressivos para backup, exclusões, corrupção e identificação de arquivos.
- Sem alteração no formato `.ci.json`, IDs originais, pacote Android ou permissões.
- Verificação estrutural concluída; `flutter analyze`, `flutter test`, builds e sincronização real **pendentes de execução no seu computador**.
