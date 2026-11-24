# Caderno Infinito v0.9.9 — seleção múltipla nas pastas

Base: v0.9.8 (97 testes passaram no computador do usuário; EXE e APK compilaram com sucesso).

## Mudanças

- `Selecionar vários` em qualquer pasta e em `Todos os desenhos`.
- Toque longo em um cartão para entrar diretamente no modo seleção; toques seguintes marcam/desmarcam itens.
- Checkbox visível sobre cada miniatura no modo seleção.
- `Selecionar todos` / `Desmarcar todos` da lista **atualmente exibida**.
- `Mover selecionados para a Lixeira`, com confirmação e contagem exata.
- `Mover todos desta pasta para a Lixeira`: inclui somente desenhos ativos diretamente na pasta, **não subpastas**; ignora a busca para mover todos os itens da pasta, não apenas os resultados filtrados.
- Na tela `Todos`, `Mover todos para a Lixeira` abrange as pastas ativas, com confirmação explícita.
- Na Lixeira, restaurar ou excluir definitivamente vários de uma vez.
- Mudança de pasta encerra a seleção; alterações no filtro de busca limpam a seleção para evitar apagar itens ocultos.
- Operações em lote não executam ao mesmo tempo que uma sincronização ou edição, e só sincronizam após terminar os salvamentos locais.
- Mantido o formato `.ci.json`, as pastas e os marcadores de exclusão permanente no Google Drive.
- Testes de regressão para pasta, subpasta, busca e itens da Lixeira.
- Pasta de compilação isolada `ci099_full`.

## Segurança dos desenhos

**Mover para a Lixeira não exclui definitivamente.** Os arquivos continuam recuperáveis na Lixeira até o usuário escolher exclusão definitiva. Todas as operações de exclusão em lote pedem confirmação. Ao usar o Drive, as alterações locais serão sincronizadas depois, quando houver conexão.

## Validação

Checagem da árvore de arquivos, scripts e integridade do ZIP realizada. Não houve execução do Flutter neste ambiente. Execute `04_VERIFICAR_NO_C.cmd` para verificar análise e testes; depois `01_COMPILAR_TUDO_NO_C.cmd` para compilar.
