# Caderno Infinito v0.6.1 — lixeira

- **Lixeira**: cada desenho oferece **Restaurar** e **Excluir definitivamente**.
- **Esvaziar lixeira**: apaga todos os desenhos marcados para exclusão com confirmação explícita.
- A remoção local exclui o arquivo `.ci.json`, o backup `.bak` e o temporário `.tmp`.
- Exclusões feitas offline são mantidas como marcadores locais e propagadas ao Google Drive na próxima sincronização.
- A pasta do aplicativo no Drive recebe pequenos marcadores `.ci.deleted`. Eles bloqueiam a recuperação automática de arquivos apagados por outro dispositivo, mesmo que ele ainda tenha uma cópia local.
- Os arquivos `.ci.json` correspondentes são removidos do Drive quando a exclusão é sincronizada. Se ocorrer falha de internet, a exclusão será tentada novamente.
- Importar um backup antigo de um desenho já excluído gera novo identificador, permitindo restauração intencional sem conflitar com o bloqueio da nuvem.

## Instalação

Este é o **projeto inteiro**, não um patch. Extraia-o em `C:\Users\mayckson\ci061` (disco C:, fora do Google Drive) e execute `VERIFICAR_PROJETO.cmd`, seguido de `COMPILAR_TUDO.cmd`.

Os arquivos gerados estarão na pasta `dist`. Fazer backup de seus desenhos antes de instalar ou substituir versões é recomendado.

**Importante:** não inclui APK nem EXE pré-compilado. A análise, os testes e as compilações precisam ser executados no seu computador com Flutter. Uma exclusão definitiva sincronizada não é restaurável pelo aplicativo, embora cópias de segurança independentes continuem existindo.
