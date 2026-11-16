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

# Braço "estilo pamflow" (15/11/2026)

Pergunta: o limiar do pipeline `detection_validation` do pamflow
(Betancourt et al. 2026, *Methods Ecol Evol*, doi:10.1111/2041-210x.70432)
falha mais ou menos que os do sheepdog nas mesmas populações?

## Desenho

`sim_pamflow.R` (resumo em `summarise_pamflow.R`; resultados em
`sim_pamflow.rds`, local). As populações, a amostra em dois estágios, o
limiar pontual (`sd_point`) e o conservador (`sd_cons`, quantil de 95% de
200 réplicas por gravação) são os de `sim_oob.R`. O pamflow foi
reimplementado em R a partir do código público
(`src/pamflow/pipelines/detection_validation/nodes.py` e
`species_detection/nodes.py`):

- **Sorteio do pamflow:** n segmentos entre todas as detecções, em 5 faixas
  de largura igual do score, com o mesmo n por faixa. Não guarda
  probabilidade de inclusão.
- **Ajuste:** logística sem pesos do acerto contra o score (na escala do
  score, o padrão, ou em logit). Sem limiar com n < 15, < 3 por classe,
  separação, teste de razão de verossimilhança com p ≥ 0,05 ou inclinação
  negativa.
- **Limiar t\*:** o score em que a P(TP) ajustada vale o alvo, isto é, a
  meta é **local**. Sem limiar quando t\* passa do maior score revisado.
- **Braços:**
  - `pf_same`: a logística do pamflow na nossa amostra em dois estágios;
  - `pf_native`: o pamflow com o sorteio dele;
  - `pf_native_logit`: o mesmo, com o score em logit.
- **Medidas:**
  - a precisão verdadeira acima do limiar (a meta do sheepdog), com falha
    abaixo de alvo − 0,02;
  - a P(TP) local verdadeira no limiar (a meta do pamflow: média dos TP da
    população a ± 0,02 do corte);
  - o recall mantido.
- **Tempo:** 4 min em 6 núcleos.

## Resultados (seleção; a tabela completa sai de `summarise_pamflow.R`)

"Falha" é a fração das amostras com limiar em que a precisão acima do
limiar fica abaixo de alvo − 0,02. "Tem" é a fração das amostras com algum
limiar.

| Cenário | n | Alvo | `sd_point` falha / recall | `sd_cons` falha / recall (tem) | `pf_native` falha / recall (tem) | `pf_native_logit` falha (tem) | `pf_native` falha local |
|---|---|---|---|---|---|---|---|
| indep | 200 | 0,90 | 0,23 / 0,45 | 0,01 / 0,21 (1,00) | 0,00 / 0,31 (1,00) | 0,00 (1,00) | 0,40 |
| indep | 800 | 0,95 | 0,08 / 0,28 | 0,00 / 0,12 (1,00) | 0,00 / 0,18 (1,00) | 0,00 (1,00) | 0,05 |
| clumped | 200 | 0,90 | 0,25 / 0,28 | 0,01 / 0,12 (1,00) | 0,00 / 0,18 (1,00) | 0,00 (1,00) | 0,32 |
| clumped | 800 | 0,95 | 0,06 / 0,15 | 0,00 / 0,08 (1,00) | 0,00 / 0,06 (1,00) | 0,00 (1,00) | 0,04 |
| plateau | 400 | 0,90 | 0,09 / 0,08 | 0,00 / 0,02 (0,82) | 0,01 / 0,10 (0,99) | 0,00 (1,00) | 0,15 |
| plateau | 400 | 0,95 | 0,25 / 0,02 | 0,03 / 0,01 (0,46) | 0,59 / 0,02 (0,42) | 0,70 (1,00) | 0,68 |
| plateau | 800 | 0,95 | 0,06 / 0,02 | 0,04 / 0,01 (0,24) | 0,52 / 0,01 (0,42) | 0,80 (1,00) | 0,55 |

**Leitura:**

- **Com a curva suave (`indep` e `clumped`), o pamflow quase nunca falha na
  precisão acumulada** (0 a 5%). Com alvo 0,90, mantém mais recall que o `sd_cons` (por
  exemplo, 0,31 contra 0,21 em `indep`, n = 200); com alvo 0,95 em
  `clumped`, mantém um pouco menos (0,06 contra 0,08 com n = 800). Isso
  não vem de tratar a incerteza: a meta local é mais exigente que a
  acumulada, então o t\* fica acima do limiar pontual do sheepdog, e a
  logística usa toda a faixa de scores, não só os clipes acima do corte.
  Quando a logística está bem especificada, ela é mais eficiente que a
  contagem ponderada com o deslocamento do bootstrap.
- **Na meta dele próprio (a P(TP) local), o pamflow falha com frequência:**
  de 19% a 46% em `indep` e `clumped` com alvo 0,90 e escala do score,
  e de 8% a 30% em logit. Não há intervalo para t\*, e a logística na
  escala do score está mal especificada nessas populações.
- **Quando a precisão estaciona perto do alvo (`plateau`, alvo 0,95), a
  logística falha muito e não melhora com n:** 52% a 79% de falha com o
  sorteio dele, e 70% a 82% em logit, que sempre devolve um limiar. É o
  modo de falha do pedido 7a: a forma logística força a curva a passar do
  alvo. O `sd_cons` falha em 3% a 4% com n ≥ 400, porque, quando o alvo
  não é atingível com segurança, ele deixa de dar limiar (tem = 0,24 a
  0,46).
- **`pf_same` e `pf_native` dão resultados parecidos.** Sortear em dois
  estágios ou pelas faixas do pamflow pouco muda a logística sem pesos,
  como se espera quando o sorteio depende só do score.

## Conclusão para a diferenciação

1. O argumento não é "a logística falha": com a curva bem comportada, ela
   cumpre a meta acumulada, em geral com mais recall que o
   `threshold_conservative`.
2. A diferença está na robustez. Quando a precisão estaciona (FP de score
   alto), a logística dá limiares que falham na maioria das amostras, sem
   aviso, e em logit dá limiar sempre. A contagem ponderada com bootstrap
   se recusa a dar limiar. Detectar esse caso é o papel de
   `compare_calibration_curves()` (7a e 7b).
3. Um fluxo em dois ramos (logística quando `compare_calibration_curves()`
   dá `keep_logistic`, `threshold_conservative` caso contrário) foi testado
   abaixo e não se sustenta.

**Limites:**

- Uma população por cenário, e a curva verdadeira é logística no logit
  do score (a favor do `pf_native_logit` fora do platô).
- O pamflow foi reimplementado em R, não executado; as regras seguem o
  código lido em 15/11/2026.
- A P(TP) local verdadeira é estimada numa janela de ± 0,02, então tem
  ruído próprio.

# Fluxo em dois ramos (15/11/2026)

Pergunta: guiar a escolha do limiar pelo veredito de
`compare_calibration_curves()` junta o recall da logística, quando a curva
é suave, com a segurança do `threshold_conservative`, quando a precisão
estaciona?

## Desenho

Em `sim_pamflow.R` (função `two_branch()`): em cada amostra em dois estágios,
`compare_calibration_curves()` com a logística e o GAM monótono, sem
validação cruzada, com bootstrap da discordância (`n_boot = 100`).

- Com `keep_logistic`:
  - `two_branch`: o `threshold_precision` da logística (meta acumulada);
  - `two_branch_ptp`: o `threshold_p_tp` (meta local, como o pamflow).
- Com `use_monotone_or_weighted`: o `sd_cons`.
- Nos outros vereditos: nenhum limiar.
- **Tempo:** 8 min em 6 núcleos.

## Resultados

**Veredito.** A fração de amostras com `keep_logistic` é de 0,87 a 0,97 em
`indep` e `clumped`. No platô, é de 0,54 com alvo 0,90 e de 0,20 com alvo
0,95.

**`two_branch`.** Falha como o limiar pontual (11% a 35% em `indep`, alvo
0,90). É uma estimativa pontual da meta acumulada, sem o deslocamento do
bootstrap.

**`two_branch_ptp`.** Falha e recall, comparados ao `sd_cons`:

| Cenário | n | Alvo | `two_branch_ptp` falha / recall | `sd_cons` falha / recall |
|---|---|---|---|---|
| indep | 200 | 0,90 | 0,00 / 0,28 | 0,01 / 0,21 |
| indep | 800 | 0,90 | 0,00 / 0,28 | 0,00 / 0,37 |
| indep | 800 | 0,95 | 0,00 / 0,16 | 0,00 / 0,13 |
| clumped | 800 | 0,95 | 0,00 / 0,07 | 0,00 / 0,08 |
| plateau | 400 | 0,90 | 0,01 / 0,08 | 0,00 / 0,02 |
| plateau | 400 | 0,95 | 0,51 / 0,03 | 0,03 / 0,01 |
| plateau | 800 | 0,95 | 0,32 / 0,02 | 0,04 / 0,01 |

**Onde vaza.** No platô com alvo 0,95, o veredito mantém a logística em 10%
a 32% das amostras. Nelas, o limiar falha em 70% a 84%. Num diagnóstico
com 100 amostras por combinação e n ≥ 200, no platô com alvo 0,95:

| | `keep_logistic` | falha com `keep_logistic` | falha geral |
|---|---|---|---|
| tolerância fixa (`n_boot = 0`) | 0,06 | 0,47 | 0,23 |
| com o resgate do 7b (`n_boot = 100`) | 0,26 | 0,81 | 0,58 |

Fora do platô, a tolerância fixa mantém a logística em só 36% a 39% das
amostras, contra 93% a 98% com o resgate do 7b.

Exigir também que o `sd_cons` exista não resolve: no platô com alvo 0,95,
a falha continua em 32% a 64% com n ≥ 200.

## Leitura

- **Curva suave:** o fluxo com a meta local é tão seguro quanto o
  `sd_cons`. O ganho de recall não é uniforme: é maior com n pequeno, e com
  n = 800 e alvo 0,90 o `sd_cons` mantém mais (0,37 contra 0,28), porque o
  deslocamento do bootstrap encolhe com n, e a meta local não.
- **Platô suave perto do alvo:** o veredito não o reconhece com
  segurança, e o fluxo herda a falha da logística. É um nivelamento perto
  do alvo, não uma queda no topo, que é o que o veredito foi feito para
  detectar (7a).
- **O resgate do 7b** aumenta muito a fração de `keep_logistic` nas curvas
  suaves, mas também no platô, onde dobra a falha. A tolerância fixa é
  mais segura no platô e rejeita a logística em ~60% das curvas suaves.
  Nenhuma das duas versões serve para escolher o limiar.

## Conclusão

1. Não adotar o fluxo em dois ramos. A recomendação do PR #150 se mantém:
   o `threshold_conservative` como limiar a aplicar.
2. A documentação de `compare_calibration_curves()` poderia dizer que
   `keep_logistic` não garante o alvo quando a precisão estaciona perto
   dele. O veredito vale como diagnóstico da forma, não como escolha do
   limiar.
3. Para a diferenciação com o pamflow: a logística (dele ou do sheepdog)
   é eficiente quando a forma está certa, mas falha sem aviso quando a
   precisão estaciona perto do alvo, e nenhum diagnóstico de forma
   testado aqui a protege. O limiar conservador com bootstrap por gravação
   é a parte robusta.

**Limites.** Valem os da seção anterior. Além disso:
- o platô simulado é um caso só (teto de 0,955, alvo 0,95);
- `compare_calibration_curves()` rodou sem o GAM livre nem a quadrática, e
  sem validação cruzada, que o veredito não usa.
