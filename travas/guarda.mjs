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
