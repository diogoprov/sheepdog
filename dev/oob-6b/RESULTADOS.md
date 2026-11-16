# Pedido 6b: sinal de incerteza do limiar (simulação out-of-bag, 15/11/2026)

Pedido do estudo de desenho da revisão (`review-design-sim/dev/PEDIDOS-sheepdog.md`,
pedido 6b): um sinal que avise quando o limiar empírico pode não atingir o
alvo, por exemplo o limite inferior bootstrap da precisão no limiar abaixo
de alvo − 0,02. A preocupação era que o bootstrap com o limiar fixo fosse
otimista, porque o limiar é escolhido onde a precisão da amostra cruza o
alvo. Por isso comparei com uma versão out-of-bag.

## Desenho

`sim_oob.R` (resumo em `summarise_oob.R`; resultados em `sim_oob.rds`, local).

- **Populações:** 300 gravações × 40 detecções, com score no logito
  N(−1; 1,5) e só as detecções com score ≥ 0,1. P(TP) é logística no logito
  do score, com três cenários:
  - `indep`: sem efeito de gravação;
  - `clumped`: efeito de gravação N(0; 1,5) no log-odds, ou seja, FP agrupados;
  - `plateau`: como `clumped`, com P(TP) multiplicado por 0,955; a precisão
    estaciona perto de 0,95.
- **Amostra de revisão:** em dois estágios. Primeiro, n/4 gravações ao acaso.
  Depois, n/5 clipes por faixa de score (0,1; 0,3; 0,5; 0,7; 0,9; 1), com a
  probabilidade de inclusão dentro das gravações sorteadas. n = 100, 200,
  400 e 800, com 300 amostras por cenário × n.
- **Limiar:** o de `threshold_for()` (ponderado, sustentado, `min_n` = 15),
  para os alvos 0,90 e 0,95.
- **Bootstrap:** 200 réplicas por gravação. Em cada réplica:
  - o limiar da réplica, cujo quantil de 95% é o `boot_cons`, o
    `threshold_conservative` de `threshold_bootstrap()`;
  - a precisão ponderada no limiar pontual (bootstrap com o limiar fixo);
  - a precisão do limiar da réplica nas gravações que ficaram de fora
    (out-of-bag).
- **Falha:** a precisão verdadeira na população acima do limiar fica abaixo
  de alvo − 0,02.
- **Tempo:** 7 min em 6 núcleos.

## Resultados

Taxa de falha do limiar pontual e P(falha | sinal limpo) de cada sinal, nas
amostras com limiar. "Levanta" é a fração de amostras em que o sinal sobe.

| Cenário | n | Alvo | Falha do limiar pontual | LB 5% fixo: levanta | LB 5% fixo: falha se limpo | LB 5% OOB: levanta | Média OOB: levanta | `boot_cons`: falha |
|---|---|---|---|---|---|---|---|---|
| indep | 100 | 0,90 | 0,27 | 0,89 | 0,24 | 1,00 | 0,05 | 0,017 |
| indep | 200 | 0,90 | 0,23 | 0,94 | 0,24 | 1,00 | 0,00 | 0,003 |
| indep | 400 | 0,95 | 0,09 | 0,77 | 0,06 | 1,00 | 0,00 | 0,000 |
| indep | 800 | 0,95 | 0,05 | 0,49 | 0,07 | 1,00 | 0,00 | 0,000 |
| clumped | 100 | 0,95 | 0,31 | 0,25 | 0,17 | 1,00 | 0,52 | 0,141 |
| clumped | 200 | 0,90 | 0,24 | 0,89 | 0,03 | 1,00 | 0,00 | 0,010 |
| clumped | 400 | 0,95 | 0,12 | 0,72 | 0,13 | 1,00 | 0,00 | 0,003 |
| clumped | 800 | 0,90 | 0,11 | 0,89 | 0,09 | 1,00 | 0,00 | 0,007 |
| plateau | 200 | 0,95 | 0,71 | 0,51 | 0,60 | 1,00 | 0,42 | 0,263 |
| plateau | 400 | 0,90 | 0,10 | 0,85 | 0,00 | 1,00 | 0,09 | 0,000 |
| plateau | 800 | 0,95 | 0,13 | 0,70 | 0,10 | 1,00 | 0,22 | 0,044 |

A tabela completa, com as 24 combinações, sai de `summarise_oob.R`.

**Leitura:**

- **O limiar pontual não é enviesado.** A precisão verdadeira no limiar
  fica, em média, de 0,00 a 0,01 acima do alvo; no platô com alvo 0,95 e n
  pequeno, até 0,05 abaixo. Ele falha pela variância: o desvio-padrão da
  precisão realizada é 0,045 com n = 100 e 0,017 com n = 800. Com um corte
  de alvo − 0,02, de 5% a 30% das amostras falham.
- **A média out-of-bag estima bem a precisão do limiar** (viés de −0,015 a
  +0,028), mas como sinal não serve. Ela fica perto do alvo quase sempre,
  então quase nunca levanta, e a sensibilidade fica perto de 0.
- **O limite inferior de 5% out-of-bag levanta em 100% das amostras** em
  todas as combinações, e o de 20% em 68% a 100%. A precisão medida
  em ~37% das gravações é ruidosa demais para separar as amostras que
  falham.
- **O limite inferior com o limiar fixo também não discrimina.** Levanta em
  25% a 95% das amostras, e entre as que ficam limpas a falha ainda chega a
  24% (`indep`, alvo 0,90).
- **O que funciona é deslocar o limiar, não sinalizar o pontual.** O
  `boot_cons`, ou seja usar `threshold_conservative`, falha em ≤ 3% das
  amostras com n ≥ 200 em `indep` e `clumped`, e em ≤ 1% com n ≥ 400 no
  platô com alvo 0,90. As exceções:
  - n = 100: falha de 2% a 14%;
  - platô com alvo 0,95: 26% com n = 200, e só de 30% a 45% das amostras
    têm algum limiar;
  - o custo: o limiar conservador fica, em média, de 0,05 a 0,15 de score
    acima do pontual, e isso perde recall.

## Conclusão para o pedido 6b

Um sinal de incerteza sobre o limiar pontual não resolve, nem com o
bootstrap fixo nem com o out-of-bag. Como a falha vem da variância de um
estimador sem viés, nenhuma estatística de uma amostra separa bem as amostras
que vão falhar das que não vão. A recomendação que os dados sustentam é usar
o limiar conservador. Para o sheepdog, isso sugere:

1. não implementar o sinal out-of-bag;
2. recomendar `threshold_conservative` como limiar padrão para passar a
   `warning_signs()` e à exportação, deixando isso claro na documentação de
   `threshold_bootstrap()` e na vinheta;
3. se ainda se quiser um sinal: levantar quando o limiar usado está abaixo
   do `threshold_conservative` do bootstrap. Ele só diz "use o conservador",
   então é redundante com o item 2.

Isso bate com o que o estudo achou no Curiango (`boot_cons` funcionando, com
a ressalva de que só foi avaliado com 180 e 720 clipes). Com n = 100 nem o
`boot_cons` garante o alvo; isso entra na discussão do 6c (amostra
insuficiente).

**Limites:**

- É uma simulação sintética, com uma população por cenário e um único
  desenho de dois estágios por faixas.
- A falha é medida contra a precisão de uma população finita, que é a mesma
  em todas as amostras.
- O critério de alvo − 0,02 é o do estudo; com um critério estrito (abaixo
  do alvo), todas as taxas de falha sobem.
