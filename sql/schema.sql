/*
  compras_db: banco do agente de compras no WhatsApp (Postgres 15).
  Pode rodar mais de uma vez: tudo é IF NOT EXISTS ou OR REPLACE.
  Escrito para este repositório, a partir do desenho que os fluxos n8n usam.

  Convenção: tabela no singular, chave estrangeira como id_<tabela>,
  carimbos de tempo terminando em _em.
*/

-- -------------------------------------------------------------
-- Quem pode pedir cotação. Faz também o papel de lista de permitidos:
-- o roteador ignora número que não esteja nesta tabela nem em fornecedor.
-- conversa_id segue o formato do WAHA (5511900000000@c.us). conversa_lid
-- guarda o identificador "@lid" que algumas contas do WhatsApp usam para
-- receber mensagem; a mesma pessoa pode aparecer com os dois.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS engenheiro (
    id            SERIAL      PRIMARY KEY,
    nome          TEXT        NOT NULL,
    conversa_id   TEXT        NOT NULL UNIQUE,
    conversa_lid  TEXT        UNIQUE,
    ativo         BOOLEAN     NOT NULL DEFAULT TRUE,
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- -------------------------------------------------------------
-- Fornecedores. O fluxo v1 só olha "ativo". O agente (v2) escolhe por
-- status (somente 'homologado'), categoria e região de atendimento.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS fornecedor (
    id            SERIAL      PRIMARY KEY,
    nome          TEXT        NOT NULL,
    conversa_id   TEXT        NOT NULL UNIQUE,
    conversa_lid  TEXT        UNIQUE,
    telefone      TEXT,
    nome_contato  TEXT,
    email         TEXT,
    categorias    TEXT[]      NOT NULL DEFAULT '{}',
    regioes       TEXT[]      NOT NULL DEFAULT '{}',
    status        TEXT        NOT NULL DEFAULT 'pendente',
    ativo         BOOLEAN     NOT NULL DEFAULT TRUE,
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fornecedor_status_ck CHECK (status IN ('pendente', 'homologado', 'desomologado'))
);

-- -------------------------------------------------------------
-- Cotação aberta por um engenheiro.
-- Ciclo: rascunho -> aberta -> aguardando -> completa -> enviada (ou cancelada).
--   rascunho: o agente entendeu o pedido e ainda não há aprovação (veja
--             docs/aprovacao-humana-e-travas.md); os fluxos v1 nascem 'aberta'.
--   completa: aceito pelo CHECK, mas nenhum fluxo daqui grava; o v1 passa de
--             'aguardando' direto para 'enviada' quando todos respondem.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS cotacao (
    id              SERIAL      PRIMARY KEY,
    codigo          TEXT        NOT NULL UNIQUE,
    id_engenheiro   INTEGER     REFERENCES engenheiro (id),
    obra            TEXT,
    endereco        TEXT,
    texto_pedido    TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'aberta',
    limite_resposta TIMESTAMPTZ,
    arquivo_mapa    TEXT,
    registrado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    alterado_em     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT cotacao_status_ck
        CHECK (status IN ('rascunho', 'aberta', 'aguardando', 'completa', 'enviada', 'cancelada'))
);
CREATE INDEX IF NOT EXISTS ix_cotacao_por_status ON cotacao (status);

-- Lista original do pedido; é a primeira coluna do mapa.
CREATE TABLE IF NOT EXISTS cotacao_item (
    id          SERIAL        PRIMARY KEY,
    id_cotacao  INTEGER       NOT NULL REFERENCES cotacao (id) ON DELETE CASCADE,
    seq         INTEGER       NOT NULL,
    descricao   TEXT          NOT NULL,
    unidade     TEXT,
    quantidade  NUMERIC(14,3),
    CONSTRAINT cotacao_item_seq_uk UNIQUE (id_cotacao, seq)
);

-- Convite: quem foi chamado a cotar e se já respondeu. É daqui que sai o "faltam quantos?".
CREATE TABLE IF NOT EXISTS convite (
    id            SERIAL      PRIMARY KEY,
    id_cotacao    INTEGER     NOT NULL REFERENCES cotacao (id) ON DELETE CASCADE,
    id_fornecedor INTEGER     NOT NULL REFERENCES fornecedor (id),
    status        TEXT        NOT NULL DEFAULT 'enviado',
    convidado_em  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    respondeu_em  TIMESTAMPTZ,
    CONSTRAINT convite_status_ck CHECK (status IN ('enviado', 'respondido', 'recusado', 'expirado')),
    CONSTRAINT convite_par_uk UNIQUE (id_cotacao, id_fornecedor)
);
CREATE INDEX IF NOT EXISTS ix_convite_do_fornecedor ON convite (id_fornecedor, status);

-- Proposta de um fornecedor. A chave (cotação, fornecedor) é única: reenviar
-- troca a proposta anterior. texto_bruto guarda o original para auditar a extração.
CREATE TABLE IF NOT EXISTS proposta (
    id              SERIAL        PRIMARY KEY,
    id_cotacao      INTEGER       NOT NULL REFERENCES cotacao (id) ON DELETE CASCADE,
    id_fornecedor   INTEGER       NOT NULL REFERENCES fornecedor (id),
    total_proposta  NUMERIC(14,2),
    prazo_entrega   TEXT,
    prazo_servico   TEXT,
    forma_pagamento TEXT,
    validade        TEXT,
    frete           TEXT,
    valor_frete     NUMERIC(14,2),
    valor_imposto   NUMERIC(14,2),
    obs_imposto     TEXT,
    pct_desconto    NUMERIC(6,3),       -- em %, ou seja 5 = 5%
    valor_desconto  NUMERIC(14,2),
    observacoes     TEXT,
    texto_bruto     TEXT,
    extracao        JSONB,
    registrado_em   TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    CONSTRAINT proposta_par_uk UNIQUE (id_cotacao, id_fornecedor)
);

-- Itens da proposta. id_item_pedido NULL = item extra, ofertado fora do pedido (não é erro).
CREATE TABLE IF NOT EXISTS proposta_item (
    id             SERIAL        PRIMARY KEY,
    id_proposta    INTEGER       NOT NULL REFERENCES proposta (id) ON DELETE CASCADE,
    -- SET NULL: apagar o item pedido não pode ficar travado por causa do item casado
    id_item_pedido INTEGER       REFERENCES cotacao_item (id) ON DELETE SET NULL,
    descricao      TEXT          NOT NULL,
    marca          TEXT,
    unidade        TEXT,
    quantidade     NUMERIC(14,3),
    preco_unit     NUMERIC(14,4),
    preco_total    NUMERIC(14,2),
    observacao     TEXT
);
CREATE INDEX IF NOT EXISTS ix_proposta_item_da_proposta ON proposta_item (id_proposta);

-- Registro bruto do que entra pelo webhook. UNIQUE em id_msg_waha: se o WAHA
-- reenviar o mesmo webhook, a mensagem não é processada de novo.
CREATE TABLE IF NOT EXISTS log_mensagem (
    id            SERIAL      PRIMARY KEY,
    id_msg_waha   TEXT        UNIQUE,
    conversa_id   TEXT        NOT NULL,
    direcao       TEXT        NOT NULL,
    id_cotacao    INTEGER     REFERENCES cotacao (id) ON DELETE SET NULL,
    payload       JSONB,
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT log_mensagem_direcao_ck CHECK (direcao IN ('in', 'out'))
);
CREATE INDEX IF NOT EXISTS ix_log_mensagem_da_conversa ON log_mensagem (conversa_id, registrado_em DESC);

-- Dúvida de fornecedor que depende de decisão do engenheiro ("pode trocar X por Y?").
CREATE TABLE IF NOT EXISTS pergunta (
    id              SERIAL      PRIMARY KEY,
    id_cotacao      INTEGER     NOT NULL REFERENCES cotacao (id) ON DELETE CASCADE,
    id_fornecedor   INTEGER     NOT NULL REFERENCES fornecedor (id),
    texto_pergunta  TEXT        NOT NULL,
    status          TEXT        NOT NULL DEFAULT 'aberta',
    texto_resposta  TEXT,
    registrado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    respondeu_em    TIMESTAMPTZ,
    CONSTRAINT pergunta_status_ck CHECK (status IN ('aberta', 'respondida'))
);
CREATE INDEX IF NOT EXISTS ix_pergunta_por_status ON pergunta (status);

-- Sessão do agente por conversa, para retomar com `resume` (fluxo v2).
CREATE TABLE IF NOT EXISTS sessao_agente (
    conversa_id   TEXT        PRIMARY KEY,
    session_id    TEXT        NOT NULL,
    status        TEXT        NOT NULL DEFAULT 'aberta',
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    alterado_em   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Aprovação humana de uma cotação. Quem grava é o código do roteador, a partir da
-- resposta do próprio engenheiro; o agente não tem ferramenta que escreva aqui.
-- Os fluxos v1 não usam (veja docs/aprovacao-humana-e-travas.md).
CREATE TABLE IF NOT EXISTS aprovacao (
    id            SERIAL      PRIMARY KEY,
    id_cotacao    INTEGER     NOT NULL REFERENCES cotacao (id) ON DELETE CASCADE,
    id_engenheiro INTEGER     NOT NULL REFERENCES engenheiro (id),
    id_msg_waha   TEXT        NOT NULL UNIQUE,
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

/* ------------------------------------------------------------
   Views
   ------------------------------------------------------------ */

-- Uma linha por item pedido e por fornecedor convidado; o gerador do mapa faz o pivô.
CREATE OR REPLACE VIEW v_mapa_comparativo AS
SELECT
    cot.id                AS id_cotacao,
    cot.codigo            AS codigo_cotacao,
    it.seq                AS item_seq,
    it.descricao          AS item_descricao,
    it.unidade            AS item_unidade,
    it.quantidade         AS item_quantidade,
    fo.id                 AS id_fornecedor,
    fo.nome               AS nome_fornecedor,
    pri.descricao         AS ofertado_descricao,
    pri.marca             AS ofertado_marca,
    pri.preco_unit,
    pri.preco_total,
    pr.prazo_entrega,
    pr.forma_pagamento,
    pr.total_proposta     AS total_da_proposta
FROM cotacao cot
JOIN cotacao_item it        ON it.id_cotacao = cot.id
JOIN convite cv             ON cv.id_cotacao = cot.id
JOIN fornecedor fo          ON fo.id = cv.id_fornecedor
LEFT JOIN proposta pr       ON pr.id_cotacao = cot.id AND pr.id_fornecedor = fo.id
LEFT JOIN proposta_item pri ON pri.id_proposta = pr.id AND pri.id_item_pedido = it.id
ORDER BY cot.id, it.seq, fo.nome;

-- Cabeçalho e rodapé por fornecedor: contato, totais, imposto, desconto e condições.
CREATE OR REPLACE VIEW v_resumo_proposta AS
SELECT
    cot.id                AS id_cotacao,
    cot.codigo            AS codigo_cotacao,
    cot.obra,
    fo.id                 AS id_fornecedor,
    fo.nome               AS nome_fornecedor,
    fo.telefone,
    fo.nome_contato,
    pr.total_proposta,
    pr.valor_frete,
    pr.valor_imposto,
    pr.obs_imposto,
    pr.pct_desconto,
    pr.valor_desconto,
    pr.forma_pagamento,
    pr.prazo_servico,
    pr.prazo_entrega      AS prazo_material,
    pr.validade,
    pr.observacoes
FROM cotacao cot
JOIN convite cv       ON cv.id_cotacao = cot.id
JOIN fornecedor fo    ON fo.id = cv.id_fornecedor
LEFT JOIN proposta pr ON pr.id_cotacao = cot.id AND pr.id_fornecedor = fo.id
ORDER BY cot.id, fo.nome;

-- Cotações em que todos os convidados já responderam.
CREATE OR REPLACE VIEW v_cotacao_fechada AS
SELECT
    cot.id,
    cot.codigo,
    cot.status,
    COUNT(*)                                AS convidados,
    SUM((cv.status = 'respondido')::int)    AS respondidos
FROM cotacao cot
JOIN convite cv ON cv.id_cotacao = cot.id
GROUP BY cot.id, cot.codigo, cot.status
HAVING BOOL_AND(cv.status = 'respondido');
