# ASTREND HUB v2.1 (branch de revisão)

## Carregamento

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/MRzinyt/ASTREND-HUB/refs/heads/feature/astrend-hub-v2-review/main.lua"))()
```

A branch principal (`main`) não recebeu essas alterações. Revise o [PR #1](https://github.com/MRzinyt/ASTREND-HUB/pull/1).

## Correções e novos controles

- ESP 2D: caixa de personagem projetada dos oito cantos de `GetBoundingBox()`, com ocultação fora da tela e limpeza de instâncias.
- Interface: o botão de minimizar mostra `MIN` e `ABRIR` para evitar confusão com `+`.
- Silent: prévia com círculo FOV separado (azul), tamanho e alcance próprios; não modifica acertos.
- Logo: campo `Settings > Logo > ID da logo ASTREND`; informar um **Image Asset ID** válido do Roblox. Sem ID, permanece o ícone temporário com a letra A.
- `Player`: botões de fome e sede e resposta do servidor.

## Integração para experiências próprias

O arquivo `AstrendServer.server.lua` deve ser colocado em `ServerScriptService` numa experiência que você controla. O servidor restringe as ações por `UserId`/criador, valida parâmetros e confirma comandos via `AstrendHubAction`.

Fome e sede: o módulo usa `NEED_PATHS` e `FULL_VALUE`; ajuste esses nomes e valores conforme seu sistema. Vida, munição, nível, fome e sede **não** podem ser concedidos pelo script local se o servidor do jogo não suporta as ações.

## Logo

Faça upload de `ASTREND-LOGO-UPLOAD.png` pelo Roblox Creator Dashboard como imagem; copie o Asset ID e aplique no menu Settings. O arquivo PNG também está no [pacote de revisão](https://github.com/MRzinyt/ASTREND-HUB/pull/1), mas o ID precisa ser obtido no Roblox.

## Testes e limites

A versão foi verificada quanto à presença das alterações no GitHub, mas **não foi testada no cliente Roblox**. Não inclui bypass, ocultação, nem desativação do anti-cheat de terceiros.
