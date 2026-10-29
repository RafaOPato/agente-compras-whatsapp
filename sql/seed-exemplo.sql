-- Dados FICTÍCIOS para experimentar os fluxos: nomes e números inventados.
-- Rode depois do schema.sql. Rodar de novo não duplica nada (ON CONFLICT).
--
-- ATENÇÃO: os números abaixo só têm o formato de telefone brasileiro. Antes de
-- ligar uma sessão REAL do WAHA, troque as conversa_id e os telefones pelos seus
-- números de teste: o agente escreve de verdade para a conversa_id cadastrada.

INSERT INTO engenheiro (conversa_id, nome)
VALUES ('5511900000010@c.us', 'Ana (engenheira)'),
       ('5511900000011@c.us', 'Carlos (comprador)')
ON CONFLICT (conversa_id) DO NOTHING;

INSERT INTO fornecedor (nome, status, conversa_id, telefone, nome_contato, categorias, regioes)
VALUES
    ('Fornecedor Alfa Ltda', 'homologado', '5511900000001@c.us', '+55 11 90000-0001', 'Atendimento Alfa',
        '{Elétrica,Material básico}', '{Capital,Região metropolitana}'),
    ('Fornecedor Beta ME', 'homologado', '5511900000002@c.us', '+55 11 90000-0002', 'Atendimento Beta',
        '{Elétrica,Material básico}', '{Capital}'),
    ('Fornecedor Gama Ltda', 'homologado', '5511900000003@c.us', '+55 11 90000-0003', 'Atendimento Gama',
        '{Elétrica,Material básico}', '{Capital,Litoral}'),
    ('Fornecedor Delta Ltda', 'desomologado', '5511900000004@c.us', '+55 11 90000-0004', 'Atendimento Delta',
        '{Elétrica}', '{Capital}')
ON CONFLICT (conversa_id) DO NOTHING;
