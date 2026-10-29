// Rodar: node --test   (testado com Node 24; sem dependências)
import assert from 'node:assert/strict';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import test, { after } from 'node:test';
import { criaGuarda, lerAprovacao } from './guarda.mjs';

// a pasta é compartilhada (como a dos anexos no n8n): o anexo desta mensagem e o de outro remetente moram nela
const pasta = fs.mkdtempSync(path.join(os.tmpdir(), 'anexos-'));
const dentro = path.join(pasta, 'proposta.pdf');
const deOutro = path.join(pasta, 'proposta-de-outro-fornecedor.pdf');
fs.writeFileSync(dentro, 'x');
fs.writeFileSync(deOutro, 'x');
fs.mkdirSync(path.join(pasta, 'sub'));
const fora = path.join(os.tmpdir(), `fora-${process.pid}.txt`);
fs.writeFileSync(fora, 'x');

// aprovação registrada só para a cotação 10 do engenheiro 1
const aprovacoes = { existe: async (cot, eng) => cot === 10 && eng === 1 };
const engenheiro = criaGuarda({ papel: 'engenheiro', remetenteId: 1, arquivoAnexo: dentro, aprovacoes });
const CHAT7 = 'chat-do-fornecedor-7';
const fornecedor = criaGuarda({ papel: 'fornecedor', remetenteId: 7, chatId: CHAT7, arquivoAnexo: dentro, aprovacoes });
const T = (n) => `mcp__compras__${n}`;

test('envio ao fornecedor só com aprovação registrada', async () => {
  assert.equal((await engenheiro(T('enviar_cotacao'), { id_cotacao: 11 })).behavior, 'deny');
  assert.match((await engenheiro(T('enviar_cotacao'), { id_cotacao: 11 })).message, /Aguardando aprovação/);
  assert.equal((await engenheiro(T('enviar_cotacao'), { id_cotacao: 10 })).behavior, 'allow');
  assert.equal((await engenheiro(T('enviar_cotacao'), {})).behavior, 'deny');
});

test('aprovação de outro engenheiro não vale', async () => {
  const outro = criaGuarda({ papel: 'engenheiro', remetenteId: 2, arquivoAnexo: dentro, aprovacoes });
  assert.equal((await outro(T('enviar_cotacao'), { id_cotacao: 10 })).behavior, 'deny');
});

test('ferramenta fora da lista é negada (Bash, Write, WebFetch, MCP alheio)', async () => {
  for (const nome of ['Bash', 'Write', 'WebFetch', 'mcp__outro__qualquer', T('apagar_tudo')]) {
    assert.equal((await engenheiro(nome, {})).behavior, 'deny', nome);
  }
});

test('cada papel só alcança a própria lista de ferramentas', async () => {
  const doFornecedor = ['salvar_proposta', 'registrar_pergunta', 'minhas_cotacoes', 'responder_fornecedor'];
  const doEngenheiro = ['consultar_fornecedores', 'rascunhar_cotacao', 'gerar_mapa', 'responder_engenheiro'];
  for (const nome of doFornecedor) {
    assert.equal((await engenheiro(T(nome), {})).behavior, 'deny', `engenheiro não pode ${nome}`);
  }
  for (const nome of doEngenheiro) {
    assert.equal((await fornecedor(T(nome), {})).behavior, 'deny', `fornecedor não pode ${nome}`);
  }
});

test('só vale o prefixo exato do servidor de ferramentas (não basta o tamanho)', async () => {
  const nomeDeTamanhoIgual = 'x'.repeat(T('').length) + 'enviar_cotacao';
  assert.equal((await engenheiro(nomeDeTamanhoIgual, { id_cotacao: 10 })).behavior, 'deny');
});

test('fornecedor não alcança ferramenta de engenheiro nem fala por outro fornecedor', async () => {
  assert.equal((await fornecedor(T('enviar_cotacao'), { id_cotacao: 10 })).behavior, 'deny');
  assert.equal((await fornecedor(T('salvar_proposta'), { id_fornecedor: 8 })).behavior, 'deny');
  const ok = await fornecedor(T('salvar_proposta'), { id_cotacao: 10 });
  assert.equal(ok.behavior, 'allow');
  assert.equal(ok.updatedInput.id_fornecedor, 7); // o id vem do roteador, não do modelo
});

test('fornecedor só escreve no próprio chat', async () => {
  assert.equal((await fornecedor(T('responder_fornecedor'), { conversa_id: 'chat-de-outro', texto: 'oi' })).behavior, 'deny');
  const ok = await fornecedor(T('responder_fornecedor'), { texto: 'oi' });
  assert.equal(ok.behavior, 'allow');
  assert.equal(ok.updatedInput.conversa_id, CHAT7); // o chat também vem do roteador
  assert.equal((await fornecedor(T('responder_fornecedor'), { conversa_id: CHAT7, texto: 'oi' })).behavior, 'allow');
});

test('Read só abre o anexo desta mensagem, não os outros da mesma pasta', async () => {
  assert.equal((await fornecedor('Read', { file_path: dentro })).behavior, 'allow');
  const outraGrafia = `${path.join(pasta, 'sub')}${path.sep}..${path.sep}proposta.pdf`; // o mesmo arquivo, escrito com "../"
  assert.equal((await fornecedor('Read', { file_path: outraGrafia })).behavior, 'allow');
  assert.equal((await fornecedor('Read', { file_path: deOutro })).behavior, 'deny'); // mesma pasta, outro remetente
  assert.equal((await fornecedor('Read', { file_path: pasta })).behavior, 'deny');
  assert.equal((await fornecedor('Read', { file_path: fora })).behavior, 'deny');
  assert.equal((await fornecedor('Read', { file_path: path.join(pasta, '..', path.basename(fora)) })).behavior, 'deny');
  assert.equal((await fornecedor('Read', { file_path: path.join(pasta, 'nao-existe.pdf') })).behavior, 'deny');
  assert.equal((await fornecedor('Read', {})).behavior, 'deny');
});

test('mensagem sem anexo: Read negado até para arquivos da pasta', async () => {
  const semAnexo = criaGuarda({ papel: 'fornecedor', remetenteId: 7, chatId: CHAT7, aprovacoes });
  assert.equal((await semAnexo('Read', { file_path: dentro })).behavior, 'deny');
});

test('Read não segue link simbólico para outro arquivo', async (t) => {
  const link = path.join(pasta, 'atalho.txt');
  try {
    fs.symlinkSync(fora, link);
  } catch {
    return t.skip('sem permissão para criar link simbólico neste sistema');
  }
  assert.equal((await fornecedor('Read', { file_path: link })).behavior, 'deny');
});

test('id_cotacao que não é número inteiro é negado, mesmo se a aprovação "existisse"', async () => {
  const sempre = criaGuarda({ papel: 'engenheiro', remetenteId: 1, aprovacoes: { existe: async () => true } });
  for (const id of ['abc', '1.5', undefined, {}]) {
    const r = await sempre(T('enviar_cotacao'), { id_cotacao: id });
    assert.equal(r.behavior, 'deny', String(id));
    assert.match(r.message, /id_cotacao/);
  }
  assert.equal((await sempre(T('enviar_cotacao'), { id_cotacao: '10' })).behavior, 'allow'); // o SDK entrega número como texto
});

test('o envio recebe o número aprovado, não o texto cru que o modelo escreveu', async () => {
  // aprovação só para a cotação 10: todas estas grafias valem 10 para Number(), mas parseInt('1e1') daria 1 e parseInt('0xA') daria 0
  for (const id of ['1e1', '0xA', ' 10 ', [10], '10.0', '10', 10]) {
    const r = await engenheiro(T('enviar_cotacao'), { id_cotacao: id, observacao: 'x' });
    assert.equal(r.behavior, 'allow', JSON.stringify(id));
    assert.strictEqual(r.updatedInput.id_cotacao, 10, JSON.stringify(id)); // número, igual ao que foi conferido
    assert.equal(r.updatedInput.observacao, 'x'); // o resto da entrada segue como veio
  }
  for (const id of ['1e0', '0x1', ' 11 ', [11]]) {
    assert.equal((await engenheiro(T('enviar_cotacao'), { id_cotacao: id })).behavior, 'deny', JSON.stringify(id)); // 1 e 11 não estão aprovados
  }
});

test('a aprovação vale para um envio só (mock com estado, como o SQL com status = rascunho)', async () => {
  const cotacao = { status: 'rascunho' }; // enviar_cotacao passa 'rascunho' -> 'aberta' na mesma transação
  const g = criaGuarda({ papel: 'engenheiro', remetenteId: 1, aprovacoes: { existe: async () => cotacao.status === 'rascunho' } });
  assert.equal((await g(T('enviar_cotacao'), { id_cotacao: 10 })).behavior, 'allow');
  cotacao.status = 'aberta'; // o envio aconteceu
  const segundo = await g(T('enviar_cotacao'), { id_cotacao: 10 });
  assert.equal(segundo.behavior, 'deny');
  assert.match(segundo.message, /Aguardando aprovação/);
});

test('lerAprovacao aceita só "OK <código>" exato', () => {
  assert.equal(lerAprovacao('OK COT-260115-0001'), 'COT-260115-0001');
  assert.equal(lerAprovacao('  ok cot-260115-0001 '), 'COT-260115-0001');
  for (const t of ['ok', 'pode mandar', 'OK COT-260115-0001 e manda urgente', 'agora ok COT-260115-0001', 'xok COT-260115-0001', 'OK COT-1', '', null, undefined]) {
    assert.equal(lerAprovacao(t), null, String(t));
  }
});

test('papel inválido não cria guarda', () => {
  assert.throws(() => criaGuarda({ papel: 'admin', remetenteId: 1, arquivoAnexo: dentro, aprovacoes }));
  assert.throws(() => criaGuarda({ papel: 'engenheiro', remetenteId: 'x', arquivoAnexo: dentro, aprovacoes }));
  assert.throws(() => criaGuarda({ papel: 'fornecedor', remetenteId: 7, arquivoAnexo: dentro, aprovacoes })); // sem chatId
});

after(() => {
  fs.rmSync(pasta, { recursive: true, force: true });
  fs.rmSync(fora, { force: true });
});
