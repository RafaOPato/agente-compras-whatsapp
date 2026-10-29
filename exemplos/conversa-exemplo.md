# Conversa de exemplo

Tudo aqui é inventado: empresa, obra, pessoas, fornecedores, telefones e valores.
Os números são os mesmos de
[`mapa-concorrencia/exemplo-entrada.json`](../mapa-concorrencia/exemplo-entrada.json),
que gera [`exemplo-saida.xlsx`](../mapa-concorrencia/exemplo-saida.xlsx).

As linhas em itálico começando com **bastidores** não vão para o WhatsApp: mostram
o que o sistema faz naquele passo. Elas seguem o desenho: o roteador v2 deste
repositório já grava a aprovação, mas o serviço do agente (onde o guarda roda e onde
existiriam `enviar_cotacao`, `salvar_proposta` e as outras ferramentas citadas) não
está aqui. Esta conversa nunca foi executada de ponta a ponta, e os nomes de
ferramenta são os da lista do guarda (`travas/guarda.mjs`), não os que o prompt do
engenheiro descreve hoje.

Personagens: **Ana** (engenheira da obra Residencial Aurora), **Fornecedor Alfa
Ltda**, **Fornecedor Beta ME** e **Fornecedor Gama Ltda**.

---

## 1. Pedido e aprovação (conversa com a Ana)

**Ana:** preciso de 30 sacos de cimento CP-II 50kg, 10 rolos de fio flexível
2,5mm², 6 rolos de eletroduto corrugado 3/4" e 12 unidades de fita isolante 20m
pra Residencial Aurora. Manda pra 3 fornecedores

*bastidores: o roteador achou o número da Ana em `engenheiro` (papel =
engenheiro). O agente leu "3 fornecedores" como número de fornecedores a
consultar, não como quantidade de item. Como o pedido cruza duas categorias,
buscou uma por vez, na região Capital: fornecedores homologados de Elétrica
(fio, eletroduto, fita) e de Material básico (cimento).
Ficou com os que têm as duas e deixou de fora o Fornecedor Delta Ltda, que está
desomologado. Gravou a cotação com status `rascunho`.*

**Agente:** Entendi que você quer cotar para a Residencial Aurora:
1. Cimento CP-II 50kg - 30 sacos
2. Fio flexível 2,5mm² - 10 rolos
3. Eletroduto corrugado 3/4" - 6 rolos
4. Fita isolante 20m - 12 unidades

Fornecedores que encontrei (todos homologados, atendem a Capital): Fornecedor
Alfa Ltda, Fornecedor Beta ME e Fornecedor Gama Ltda, todos de Elétrica e
de Material básico.

Responda *OK COT-260115-0001* para eu enviar o pedido a eles, ou me diga o que
mudar.

*bastidores: até aqui nenhum fornecedor foi avisado. Se o agente tentasse
`enviar_cotacao` agora, o guarda devolveria "Aguardando aprovação" (no desenho).*

**Ana:** OK COT-260115-0001

*bastidores: o roteador reconhece a frase exata, confere que a cotação é da Ana e
está em rascunho, e grava em `aprovacao` (esta parte existe neste repositório). O
agente não escreve nessa tabela. Pelo desenho, com a aprovação o guarda libera
`enviar_cotacao`, que passa a cotação para `aberta` e gasta a aprovação; o agente
manda um pedido por fornecedor, 60 segundos entre um e outro.*

**Agente:** Pedido enviado. COT-260115-0001: 4 itens, acionei Fornecedor Alfa,
Fornecedor Beta e Fornecedor Gama. Te mando o mapa assim que as propostas
chegarem.

---

## 2. O que cada fornecedor recebe

> *Solicitação de cotação COT-260115-0001*
> Obra: Residencial Aurora
>
> 1. Cimento CP-II 50kg - 30 sacos
> 2. Fio flexível 2,5mm² - 10 rolos
> 3. Eletroduto corrugado 3/4" - 6 rolos
> 4. Fita isolante 20m - 12 unidades
>
> Responda nesta conversa com o preço unitário, o prazo de entrega e a
> condição de pagamento. Prazo para responder: 24 horas.

---

## 3. Fornecedor Beta: dúvida antes da proposta

**Fornecedor Beta:** Estamos sem fita isolante 20m no momento, pode ser fita crepe?

*bastidores: papel = fornecedor, então quem atende é o modo sem Bash. Não é
proposta (nenhum preço), é pergunta. `registrar_pergunta` grava em
`pergunta` e avisa a Ana. O fornecedor recebe "dúvida repassada".
Trocar o item não é decisão do agente.*

**Agente (para a Ana):** Chegou uma dúvida do Fornecedor Beta ME sobre a
COT-260115-0001:
"Estamos sem fita isolante 20m no momento, pode ser fita crepe?"
Me diga SIM, NÃO ou escreva uma frase curta, e eu levo a resposta até ele.

**Ana:** Não, só fita isolante mesmo. Pode ser de marca própria.

**Agente (para o Fornecedor Beta):** Sobre a sua dúvida na COT-260115-0001
("pode ser fita crepe?"), o responsável pela cotação disse:
Não, só fita isolante mesmo. Pode ser de marca própria.
Pode mandar a proposta já levando isso em conta.

---

## 4. Propostas

**Fornecedor Alfa:** cimento 32,00 a unidade, fio 185,00 o rolo, eletroduto 94,00
o rolo e fita 4,50. Impostos inclusos. Frete 80,00 à parte. Desconto de 5% no
total. Entrega em 3 dias úteis, pagamento em 28 dias, proposta vale 10 dias.

**Agente (para o Fornecedor Alfa):** Registrei sua proposta na COT-260115-0001:
4 itens, imposto incluso, frete R$ 80,00, desconto de 5%, entrega em 3 dias
úteis, pagamento em 28 dias, validade de 10 dias. Obrigado!

*bastidores: `salvar_proposta` casou os 4 itens com o pedido e regenerou o mapa. A
Ana recebe o Excel com a legenda que o nó "Montar Legenda do Mapa" do fluxo v1
monta: "Mapa de concorrencia da cotacao COT-260115-0001 atualizado: 1 de 3
fornecedores ja responderam."*

**Fornecedor Beta** (foto de um orçamento no papel): *lido da imagem:* cimento
30,50, fio 190,00 o rolo (1.900,00 no total), eletroduto 570,00 pelos 6 rolos,
fita 4,20. Imposto à parte R$ 120,00, frete CIF, desconto de R$ 20,00. Entrega em
5 dias úteis, pagamento 30/60 dias, proposta vale 7 dias.

*bastidores: do eletroduto veio só o total, então o mapa calcula o unitário (total
÷ quantidade = 570,00 ÷ 6 = 95,00). O imposto veio destacado à parte, então entra
na soma. No Alfa e no Gama ele foi dito "incluso": só por isso o mapa não soma de
novo. Se o fornecedor tivesse ficado calado, a célula ficaria "Não informado".*

**Fornecedor Gama:** *(PDF)* cimento 33,00, fio 175,00, fita isolante 60,00 pelas
12 unidades, cola para eletroduto 18,00. Impostos inclusos. Frete a combinar. À
vista, entrega em 2 dias úteis, proposta vale 5 dias.

**Agente (para o Fornecedor Gama):** Recebi sua proposta, mas duas coisas:
- Pedimos eletroduto corrugado 3/4" (6 rolos) e não vi preço dele.
- Você cotou cola para eletroduto, que não estava no pedido.
Esses dois pontos estão certos? Se faltou algo, é só mandar o complemento.

*bastidores: divergência avisa, nunca bloqueia: a proposta já está gravada. Item
pedido sem preço vira "não cotou" no mapa, e a cola entra em "itens ofertados fora
do pedido". A fita veio só com total, então o unitário sai da conta (60,00 ÷ 12 =
5,00).*

**Fornecedor Gama:** Eletroduto estamos sem estoque. A cola é opcional.

---

## 5. A Ana pede uma leitura

**Ana:** qual compensa?

*bastidores: o agente segue as regras de equalização: compara só o que cobre o
mesmo escopo, não esconde a omissão do Gama dentro do total e não decide pela Ana.*

**Agente:** Total geral, já com frete, imposto e desconto:
- Alfa: R$ 3.336,60 (28 dias, entrega em 3 dias úteis)
- Beta: R$ 3.535,40 (30/60 dias, entrega em 5 dias úteis)
- Gama: R$ 2.800,00, mas sem o eletroduto e com frete a combinar

O Gama parece o mais barato e não é comparável: faltam 6 rolos de eletroduto.
Se eu completar com o menor preço dos outros (R$ 94,00 por rolo, R$ 564,00), ele
vai a R$ 3.364,00 antes do frete, acima do Alfa.

Minha recomendação é o Alfa: menor total entre quem cotou tudo, prazo de entrega
mais curto entre os dois e 28 dias de pagamento. O Beta fica R$ 198,80 mais
caro, mas tem prazo de pagamento maior. A decisão é sua. Quer que eu pergunte ao
Gama se há previsão para o eletroduto?

*bastidores: o agente não fecha compra nem avisa fornecedor de que "ganhou". Esse
passo é da Ana, fora do sistema.*

**Ana:** fecha com o Alfa, eu mesma aviso lá.

**Agente:** Combinado. Deixei a COT-260115-0001 registrada com as 3 propostas. O
fechamento com o Alfa fica com você.
