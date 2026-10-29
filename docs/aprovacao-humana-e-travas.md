# Aprovação humana e travas

Regra do projeto: **nada sai para um fornecedor sem o OK do engenheiro**. O
desenho é que quem garanta isso seja código, não o prompt. O que já está pronto
neste repositório e o que falta ligar (o serviço do agente) está na tabela e na
seção "Como ligar".

O prompt ensina o agente a se comportar e decide o tom da recusa. Mas uma
mensagem insistente, uma proposta com instrução escondida ou uma reformulação
esperta podem fazer o modelo errar. Então o que **não pode** acontecer precisa
falhar na camada de dados, antes da ferramenta rodar. O SDK do Claude tem um gancho
para isso, o `canUseTool`: é chamado antes de qualquer ferramenta, com o nome e
os argumentos reais, e responde `allow` ou `deny`.

## O que existia na versão que rodou e o que este repositório acrescenta

Esta tabela é o resumo honesto. O texto abaixo explica cada linha.

| Trava | Na versão que rodou | Neste repositório |
|---|---|---|
| Quem pode falar com o agente (whitelist) | Em código: o roteador só aceita número cadastrado como engenheiro ou fornecedor. | Igual (`n8n/`). |
| Papel decidido pelo número, não pelo texto | Em código. | Igual. |
| Modo fornecedor (gente de fora) | Em código: sem Bash, 4 ferramentas presas ao `id_fornecedor` e ao `conversa_id`, `Read` só do anexo desta mensagem. | Descrito aqui e reproduzido no guarda de exemplo. |
| Confirmar com o engenheiro antes de gravar e enviar o pedido | **No prompt**: o agente mandava um resumo e esperava o "pode seguir". | **Desenho em código** no guarda de exemplo: `enviar_cotacao` é negado sem aprovação registrada (com testes). Não está ligado a nenhum serviço aqui, e foi escrito para o repositório, não é o código de produção. |
| Aprovação feita pelo próprio agente | Dependia do prompt, porque o agente decidia o que era um "sim". | O roteador v2 grava a aprovação a partir do `OK COT-…` do engenheiro (nós `Mensagem e um OK?` e `Registrar Aprovacao`, testados no n8n com um Postgres local). **Falta o outro lado**: o agente não deveria ter ferramenta que escreva em `aprovacao`, mas o serviço do agente não está aqui e o prompt do engenheiro (que dá SQL genérico) só manda o agente não escrever na tabela. |

Em uma frase: a parte "gente de fora não alcança nada além das próprias
ferramentas" estava em código; a parte "aprovar antes de enviar" era instrução de
prompt, e este repositório mostra o desenho para trocá-la por código.

## Três camadas

1. **Quem é quem, no roteador.** O n8n descobre o papel pelo número que mandou a
   mensagem (`engenheiro` ou `fornecedor`). Número desconhecido não passa. O
   `id_engenheiro` ou `id_fornecedor` e o `conversa_id` entram no pedido ao serviço do
   agente (corpo do nó "Chamar Claude") por esse caminho, e o `papel` escolhe a
   `persona`; o texto da mensagem não consegue alterá-los.
2. **Ferramentas estreitas por papel.** O fornecedor não tem shell. Ele tem
   `minhas_cotacoes` (sem preço de concorrente), `registrar_pergunta`,
   `salvar_proposta` e `responder_fornecedor` (só para o próprio chat). O pior que
   uma injeção de prompt consegue é bagunçar a proposta dele ou mandar mensagem
   para si mesmo.
3. **Aprovação registrada fora do agente.** `enviar_cotacao` só passa se existir
   uma linha em `aprovacao` para aquela cotação e aquele engenheiro, e a cotação
   ainda em `rascunho`. Quem grava a linha é o roteador, quando a mensagem do
   engenheiro é exatamente `OK COT-AAMMDD-####` (nós `Mensagem e um OK?` e
   `Registrar Aprovacao` de `00-roteador-agente.json`). Quem confere é o guarda, no
   serviço do agente (que não está aqui; veja "Como ligar").

## Armadilhas de permissão do SDK

Vieram da construção do sistema original. Este repositório não executa o SDK, então
valem como lição, não como teste reproduzível aqui.

- **`permissionMode: 'dontAsk'` não chama o `canUseTool`.** O SDK nega por conta
  própria, numa camada interna, e a mensagem de erro é a genérica do SDK, não a
  sua. O modo que delega ao callback é o `'default'`. Sinal de que o callback está
  mesmo sendo consultado: a recusa volta com a *sua* mensagem.
- **`bypassPermissions` ignora o `canUseTool` de propósito.** Nesse modo não há
  trava por código nenhuma. Só serve para um usuário confiável e identificado;
  nunca para um agente que lê texto de gente de fora.
- **O `Read` nativo enxerga mais do que parece.** Com `Read` liberado, uma persona
  restrita pode abrir o ambiente do processo e arquivos de outras conversas. Libere
  só `Read`, e só para a pasta dos anexos recebidos, conferindo com `realpath`
  (resolve `../` e link simbólico).
- **A pasta de trabalho é lida sem perguntar.** O Claude lê o que está no `cwd`
  sem passar pelo `canUseTool`. Com o `cwd` apontando para a pasta compartilhada,
  uma persona restrita pode ler arquivos de outra. A saída: cada persona restrita
  roda numa pasta vazia só dela, e ignora o `cwd` que o n8n manda.
- **`tools: []` tira a ferramenta do contexto do modelo.** É diferente de negar
  depois: ela nem aparece como opção. Para "só decide, não age", use isso, não
  `permissionMode: 'plan'` (que é o modo de planejamento do Claude Code, com outro
  comportamento).
- **O texto do `deny` é lido pelo modelo.** Redija a recusa pensando em quem vai
  recebê-la no WhatsApp ("Aguardando aprovação: peça ao engenheiro responder OK
  …"). Com isso o modelo repassa a explicação em vez de tentar de novo, e uma
  única regra entrega o bloqueio e a resposta educada.
- **Filtrar no n8n é camada de custo, não de segurança.** Um filtro de palavra-chave
  antes do agente escapa fácil ("quanto o pessoal ganha" não casa com "salário"), e
  um filtro depois chega tarde: o dado já foi buscado. A trava de verdade fica onde
  o dado é buscado.
- **Falha depois de gravar vira aviso, não erro.** Se a proposta já foi salva e só o
  envio do mapa falhou, a ferramenta devolve um aviso. Um erro faria o modelo gravar
  de novo, ou dizer ao fornecedor que nada foi salvo.
- **Pelo SDK, argumento numérico chega como string** (`"6"` em vez de `6`) e array
  chega como JSON em texto. Valide e converta na entrada da ferramenta, antes de
  qualquer outra checagem.

## O guarda de exemplo

Código em [`travas/guarda.mjs`](../travas/guarda.mjs), testes em
[`travas/guarda.test.mjs`](../travas/guarda.test.mjs). Escrito do zero para este
repositório; não é o código de produção.

```js
// Trava em código para o agente de compras (exemplo escrito para este repositório).
//
// Duas funções:
//   lerAprovacao(texto)  -> "COT-…" se a mensagem for exatamente "OK COT-…", senão null.
//                           Roda no roteador (n8n), com o remetente já identificado pelo número.
//   criaGuarda(contexto) -> o `canUseTool` do SDK: decide ANTES de cada chamada de ferramenta.
//
// O contexto (papel, ids) vem do roteador, nunca do texto da mensagem. O modelo pode
// pedir qualquer coisa; o que não passar por aqui não acontece.
import fs from 'node:fs';

const PREFIXO = 'mcp__compras__';

// allowlist por papel (o que não está na lista é negado)
const PERMITIDAS = {
  engenheiro: ['consultar_fornecedores', 'rascunhar_cotacao', 'enviar_cotacao', 'gerar_mapa', 'responder_engenheiro'],
  fornecedor: ['minhas_cotacoes', 'registrar_pergunta', 'salvar_proposta', 'responder_fornecedor'],
};
// ferramentas que mandam mensagem para fora da empresa: só com aprovação registrada
const EFEITO_EXTERNO = new Set(['enviar_cotacao']);

const recusa = (message) => ({ behavior: 'deny', message });
const permite = (updatedInput) => ({ behavior: 'allow', updatedInput });

export function lerAprovacao(texto) {
  const m = /^\s*ok\s+(COT-\d{6}-\d{4})\s*$/i.exec(String(texto ?? ''));
  return m ? m[1].toUpperCase() : null;
}

// é o mesmo arquivo, depois de resolver "../" e link simbólico (não basta estar na mesma pasta)
function mesmoArquivo(permitido, pedido) {
  try {
    return fs.realpathSync.native(permitido) === fs.realpathSync.native(pedido);
  } catch {
    return false;
  }
}

/**
 * @param {object} ctx
 * @param {'engenheiro'|'fornecedor'} ctx.papel        identificado pelo número, no roteador
 * @param {number} ctx.remetenteId                     id em engenheiros ou fornecedores
 * @param {string} [ctx.chatId]                        chat do fornecedor, do roteador (obrigatório no papel fornecedor)
 * @param {string} [ctx.arquivoAnexo]                  caminho do anexo DESTA mensagem: o único arquivo que o Read abre
 *                                                     (sem anexo, Read negado; uma pasta compartilhada não serve, vazaria o anexo de outro remetente)
 * @param {{existe(cotacaoId:number, engenheiroId:number):Promise<boolean>}} ctx.aprovacoes
 */
export function criaGuarda({ papel, remetenteId, chatId, arquivoAnexo, aprovacoes }) {
  const permitidas = PERMITIDAS[papel];
  if (!permitidas || !Number.isInteger(remetenteId)) throw new Error('papel ou remetente inválido');
  if (papel === 'fornecedor' && !chatId) throw new Error('chatId do fornecedor é obrigatório');

  return async function canUseTool(toolName, input = {}) {
    if (toolName === 'Read') {
      return arquivoAnexo && mesmoArquivo(arquivoAnexo, String(input.file_path ?? ''))
        ? permite(input)
        : recusa('Só dá para ler o arquivo que chegou nesta mensagem.');
    }
    if (!toolName.startsWith(PREFIXO)) return recusa('Ferramenta não liberada.');
    const nome = toolName.slice(PREFIXO.length);
    if (!permitidas.includes(nome)) return recusa('Ferramenta não liberada para este papel.');

    if (papel === 'fornecedor') {
      // o fornecedor e o chat são os que o roteador identificou; o modelo não escolhe de quem fala nem para quem escreve
      if (input.id_fornecedor !== undefined && Number(input.id_fornecedor) !== remetenteId) {
        return recusa('Você só pode agir em nome do fornecedor desta conversa.');
      }
      if (input.conversa_id !== undefined && input.conversa_id !== chatId) {
        return recusa('Você só pode escrever no chat desta conversa.');
      }
      return permite({ ...input, id_fornecedor: remetenteId, conversa_id: chatId });
    }

    if (EFEITO_EXTERNO.has(nome)) {
      const cotacaoId = Number(input.id_cotacao);
      if (!Number.isInteger(cotacaoId)) return recusa('Informe id_cotacao.');
      if (!(await aprovacoes.existe(cotacaoId, remetenteId))) {
        return recusa('Aguardando aprovação: peça ao engenheiro para responder "OK <código da cotação>". Não tente enviar de outro jeito.');
      }
      // a ferramenta recebe o número que foi conferido, não o texto cru: "1e1", "0xA", " 10 " ou [10] viram 10
      // (um parseInt do outro lado leria 1, 0 e 10, e o envio sairia para outra cotação)
      return permite({ ...input, id_cotacao: cotacaoId });
    }
    return permite(input);
  };
}
```

Os testes (`node --test`, 15) cobrem: envio negado sem aprovação e liberado com ela;
aprovação de outro engenheiro não vale; `id_cotacao` que não é inteiro negado mesmo
com um `existe` que sempre diz sim; a ferramenta recebe o número que foi conferido
(`'1e1'`, `'0xA'`, `' 10 '`, `[10]` e `'10.0'` chegam como `10`, e `'1e0'` ou
`' 11 '` continuam negados por não terem aprovação); aprovação de um envio só (mock com estado: depois
do envio a cotação deixa de ser `rascunho` e o segundo envio é negado); `Bash`,
`Write`, `WebFetch`, MCP alheio e um nome com o tamanho do prefixo mas outro texto
negados; fornecedor sem acesso a ferramenta de engenheiro, sem poder falar por outro
fornecedor nem escrever em outro chat (o `id_fornecedor` e o `conversa_id` são
sobrescritos pelos do roteador); `Read` só do anexo desta mensagem (outro arquivo da
mesma pasta, a pasta, `../`, arquivo inexistente e link simbólico negados, e sem
anexo nada é lido); `lerAprovacao` aceitando só a frase exata (sem texto antes
nem depois do código); e papel inválido, remetente que não é inteiro e fornecedor
sem `chatId` não criando o guarda.

## Como ligar ao n8n e ao serviço do agente

O passo 1 já está no roteador v2 deste repositório; o passo 2 **não está feito**,
porque o serviço do agente não está aqui. O fluxo `01-agente-compras.json` já manda
`id_engenheiro` (ou `id_fornecedor`) e `conversa_id` no corpo da chamada e escreve o
caminho do anexo no fim do prompt, que é o que o guarda precisa.

1. **No roteador (v2)**, depois de identificar o remetente, um nó IF
   (`Mensagem e um OK?`) com a regex `^\s*ok\s+(COT-\d{6}-\d{4})\s*$` (a mesma de
   `lerAprovacao`), só para quem o número identificou como engenheiro. Se casar, o
   nó Postgres `Registrar Aprovacao` grava a aprovação só se a cotação for daquele
   engenheiro e ainda estiver como rascunho; qualquer outra mensagem segue direto
   para o agente. Em qualquer caso o agente recebe a mensagem. O SQL:

   ```sql
   INSERT INTO aprovacao (id_cotacao, id_engenheiro, id_msg_waha)
   SELECT cot.id, cot.id_engenheiro, $3
     FROM cotacao cot
    WHERE cot.codigo = $1
      AND cot.id_engenheiro = $2
      AND cot.status = 'rascunho'
   ON CONFLICT (id_msg_waha) DO NOTHING;
   ```

2. **No serviço do agente**, para cada chamada, monte as opções do SDK com o
   guarda. O `existe` consulta a mesma tabela e só aceita cotação ainda em
   rascunho, o que faz a aprovação valer para um envio só:

   ```js
   const guarda = criaGuarda({
     papel, remetenteId,
     chatId,                                  // só no papel fornecedor
     arquivoAnexo: caminhoDoAnexoDestaMensagem, // o mesmo caminho que o n8n escreve no prompt; undefined se não há anexo
     aprovacoes: { existe: async (cotacaoId, engenheiroId) =>
       (await pool.query(
         `SELECT 1 FROM aprovacao a JOIN cotacao c ON c.id = a.id_cotacao
           WHERE a.id_cotacao = $1 AND a.id_engenheiro = $2 AND c.id_engenheiro = $2
             AND c.status = 'rascunho'`,
         [cotacaoId, engenheiroId])).rowCount > 0 },
   });
   const opcoes = { permissionMode: 'default', tools: ['Read'], cwd: pastaVazia, canUseTool: guarda };
   ```

   O fluxo salva um arquivo por mensagem: o n8n grava em
   `/files/whatsapp-uploads/<id da mensagem>.<extensão>`, que o `agente-service`
   enxerga como `/shared/whatsapp-uploads/<id da mensagem>.<extensão>` (é a mesma
   pasta do host montada nos dois containers; o que o n8n precisa para gravar
   ali está no passo 5 do README). Passar a pasta inteira ao `Read` deixaria um
   fornecedor ler o anexo de outro; por isso o guarda compara o caminho exato
   (depois de resolver link simbólico).

3. **A ferramenta `enviar_cotacao` não recebe destinatário.** Ela lê os convidados
   da própria cotação (`convite`). O modelo não escolhe para quem a
   mensagem vai, só qual cotação já aprovada será enviada. Na mesma transação em
   que cria os convites, ela passa a cotação de `rascunho` para `aberta`
   (`UPDATE … WHERE id = $1 AND status = 'rascunho'`; se nenhuma linha mudou, não
   envia, para duas chamadas ao mesmo tempo não passarem as duas). É isso que gasta
   a aprovação: o `existe` do passo 2 deixa de achar a cotação.

## O que a trava não resolve

- Ela não impede o agente de **pedir** algo dentro do que está liberado. Por isso o
  modo fornecedor tem ferramentas tão estreitas e o texto do fornecedor entra
  sempre delimitado como dado.
- Se o WhatsApp do engenheiro for tomado por outra pessoa, o `OK COT-…` dela vale.
  A aprovação é tão boa quanto a identificação pelo número.
- A aprovação não fica presa ao conteúdo aprovado. Ela vale para um envio só (depois
  do envio a cotação deixa de ser `rascunho`), mas, entre o `OK` e o envio, o agente
  ainda pode editar o rascunho (itens, quantidades, fornecedores convidados) e o
  guarda deixa passar. Fechar isso pede apagar a aprovação a cada edição do rascunho
  (um gatilho no banco, por exemplo) ou gravar com ela um resumo do que foi
  aprovado; não está feito.
- O formato `OK COT-…` é menos natural que "pode seguir". Troquei naturalidade por
  uma frase que o código consegue conferir sem adivinhar.
- Na versão que rodou, a confirmação do modo engenheiro era regra de prompt. Este
  repositório mostra o desenho com trava em código; ligá-lo é o próximo passo e
  está fora do que foi construído aqui.
- O prompt do engenheiro (`prompts/agente-compras.md`) descreve as ferramentas do
  sistema original (SQL, `enviar_texto`, `enviar_arquivo`, `gerar_mapa`,
  `verificar_whatsapp`), não a lista do guarda (`consultar_fornecedores`,
  `rascunhar_cotacao`, `enviar_cotacao`, `gerar_mapa`, `responder_engenheiro`). Só
  `gerar_mapa` coincide. Para usar o guarda, o serviço precisa expor as ferramentas da
  lista e o prompt precisa ser reescrito para elas; do contrário o guarda nega quase
  tudo, ou, com SQL genérico liberado, não barra nada (o agente poderia até gravar
  em `aprovacao`).
