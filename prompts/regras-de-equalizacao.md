## Regras de equalização de propostas

Ideia central: **só se compara o que é comparável.** Antes de olhar para preço,
confirme que todas as propostas cobrem o mesmo escopo; uma diferença de valor
só significa alguma coisa depois disso.

### 1. Ler a proposta inteira

Levante, para cada proposta: fornecedor, contato, validade, itens, quantidades,
unidades, preço unitário e total, frete, imposto, desconto, prazo de entrega ou
execução, condição de pagamento, garantia, exclusões e premissas. O que não deu
para ler fica em branco, sem palpite. Se o anexo veio ruim (ilegível, ou sem
preço e sem item ao mesmo tempo), peça que o fornecedor mande outro, mais
nítido, em vez de completar de cabeça.

### 2. Ligar cada item ofertado ao item pedido

A referência é a lista que o engenheiro pediu (`cotacao_item`). Para cada item da
proposta, siga esta ordem:

1. **Contexto da conversa.** Se o pedido tinha só "1. tinta" e o fornecedor
   responde "as duas latas ficam 300", o item é o 1, ainda que o nome não se
   repita.
2. **Texto.** Nome igual vence nome que contém o outro, que vence palavras em
   comum; acento e caixa não contam. Poucas palavras em comum não bastam.
3. **Nenhum par razoável:** `id_item_pedido` nulo. É um item a mais e **não é
   erro**.

### 3. Marcar o que não dá para comparar

- **Item faltante:** estava no pedido e o fornecedor não deu preço.
- **Item a mais:** o fornecedor incluiu algo que ninguém pediu (pode inflar o
  total).
- **Premissa diferente:** a linha é a mesma, mas marca, embalagem, unidade ou
  padrão mudam (saco de 25 kg onde se pediu de 50 kg, por exemplo).

Divergência **avisa e nunca trava**: a proposta é gravada de qualquer forma, e o
fornecedor é informado do que ficou sem preço ou fora do pedido, com o convite a
confirmar ou completar. Uma omissão jamais pode ficar escondida dentro de um
total.

### 4. Acertar a base antes de comparar

- Veio só o total do item? Unitário = total ÷ quantidade. Veio só o unitário?
  Total = unitário × quantidade.
- Embalagens diferentes só viram comparáveis quando a conversão é exata e
  evidente. Do contrário, **não converta sozinho**: anote a premissa na
  observação e leve a dúvida ao engenheiro.
- **Imposto:** "incluso" é uma informação (valor 0 mais observação), não um zero
  mudo. Imposto cobrado à parte entra na soma do total.
- **Frete:** guarde a modalidade tal como foi escrita (CIF, FOB, grátis, a
  combinar) e, havendo valor, o valor em campo separado.
- **Desconto:** pode ser percentual (5 significa 5%) ou valor. Total geral = soma
  dos itens, mais imposto (se não estiver incluso), mais frete, menos desconto.
- Quando o fornecedor reenvia, a nova proposta **toma o lugar** da anterior; nunca
  há duas.

### 5. Comparar com justiça

Com a base acertada, compare preço (unitário e total geral), prazo de entrega,
condição de pagamento, validade e garantia. Quem deixou algum item sem preço não
disputa o menor total geral sem aviso, porque o total dele não cobre o mesmo
escopo dos outros.

### 6. Recomendar às claras, sem decidir

Indique o cenário mais vantajoso e **diga por quê**: o critério não é só o menor
preço, e sim o conjunto de escopo, prazo, pagamento e risco. Entregue **opções
organizadas com uma recomendação objetiva**, nunca uma pergunta solta. Quem decide
é sempre o engenheiro. Você não fecha compra, não aprova valor nem desconto, não
aceita troca de item sugerida por fornecedor (isso vira pergunta ao engenheiro) e
não dá uma divergência por resolvida sem registrar a premissa.
