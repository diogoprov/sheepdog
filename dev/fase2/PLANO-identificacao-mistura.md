# Simulação de identificação do model_mix.stan (plano, 13/11/2026)

Próximo passo decidido em `PLANO-ignorabilidade.md` (decisão de 13/11/2026).
**Este plano é escrito antes da rodada completa; os critérios abaixo ficam
fixos depois da aprovação do Diogo.**

## Por que agora

A simulação estava suspensa desde 07/11 (seção "O que o artigo diz", no
`README.md`) até sabermos como o teste do Curiango foi sorteado, porque a
forma da mistura e os pesos dependiam disso. Dois fatos mudam isso:

- A ignorabilidade mostrou que, se a seleção depende só do score
  observado, a verossimilhança conjunta não precisa de pesos (I2 passa com
  PPS e "top" na verdade normal). A simulação não usa o sorteio do
  Curiango: usa os desenhos S1 (aleatório) e S2 (PPS).
- A verdade "mistura" é a mesma da ignorabilidade: uma forma plausível,
  não uma estimativa do Curiango. Os valores de `em_curiango` em `mix.R`
  (ajuste sem pesos) não entram.

Continua dependendo da Liliana: se a seleção do Curiango dependeu do estado
w (S5), nenhum dos dois modelos fica protegido. Esta simulação não responde
isso.

## Pergunta

Sob a verdade mistura, o v0 subcobriu θ com qualquer desenho, inclusive S1
e sem verificação (cobertura 0,78 a 0,86 com S1 e S2). A simulação mede:

1. se o `model_mix.stan` recupera ψ e θ quando f₀ e f₁ são de fato misturas,
   com 5% e 2% de verificação, ao acaso (S1) e por PPS (S2);
2. se os parâmetros das emissões são identificados com tão poucos positivos
   verificados (cerca de 12 com 2%);
3. quanto custa usar a mistura quando a verdade é normal: componentes não
   identificados (π₀ e π₁ sem informação), divergências, intervalos mais
   largos.

## Desenho

- Dados: os mesmos de `sim_ignorab.R`, com as mesmas sementes
  (`ig_seed_data`, `ig_seed_sel`). 150 sítios × 20 ocasiões, ψ = 0,5 e
  θ = 0,3 no centro, θ ~ d + h, c = logit(0,1). Verdades normal e mistura.
- Por conjunto: 2 frações (5% e 2%) × 2 desenhos (S1, S2) + 1 sem
  verificação = 5 ajustes. **50 réplicas** por verdade: 2 × 50 × 5 =
  **500 ajustes**.
- "Top" (S3) e os braços não ignoráveis (S4, S5) ficam de fora: a decisão
  já tirou o "top", e a não ignorabilidade é uma questão de seleção, não da
  forma de f.
- Modelo: `model_mix.stan` como está, com θ ~ d + h e os priors atuais
  (provisórios; ficam fixos nesta rodada). Inits genéricos, longe da verdade
  (`inits_mixid()`), para não esconder multimodalidade.
- Cada ajuste tem o par no v0 (`results/ignorab_v0`): mesmos dados, mesma
  seleção. A comparação com o v0 é pareada, sem reajustar o v0.
- 4 cadeias, 1.000 + 1.000 iterações, adapt_delta = 0,95.

## Critérios (fixados antes da rodada completa)

Intervalos de 95%; viés na escala de probabilidade; ψ e θ no centro
(h = 0). Com 50 réplicas, o erro-padrão de Monte Carlo da cobertura é cerca
de 0,03 perto de 0,95, e isso é relatado junto.

| # | Critério | Limiar | Papel |
|---|---|---|---|
| M1 | Convergência, verdade mistura, por célula | ≥ 95% dos ajustes com R-hat < 1,01 em todos os parâmetros salvos e sem divergências | bloqueia a leitura da célula |
| M2 | Verdade mistura, S1 e S2, 5% e 2% | cobertura ≥ 0,90 e \|viés\| ≤ 0,05 em ψ e θ | decide abaixo |
| M3 | Emissões na verdade mistura | relatado (viés, cobertura, largura dos 9 parâmetros); não bloqueia | mostra o que a verificação identifica |
| M4 | Verdade normal, S1 e S2 | mesmo limiar de M2 em ψ e θ; convergência e divergências relatadas | mede o custo da mistura quando não é preciso |
| M5 | Sem verificação | relatado | mostra se a mistura se identifica só pelos scores |

Relatados junto: diferença pareada para o v0 em ψ e θ, cobertura do v0 na
mesma célula e razão das larguras dos intervalos (mistura/v0).

**Decisão:**

- M2 e M4 passam: o `model_mix.stan` passa a ser a f padrão da fase 2 (v1
  com Markov sobre a mistura), com PPS.
- M2 passa e M4 reprova: a família de f é escolhida por classe pelo PPC
  (critério 6 do `README.md`): normal quando ela passa, mistura quando não.
- M2 passa com 5% e reprova com 2%: a mistura exige uma verificação mínima;
  relata-se o número de positivos verificados a partir do qual ela cobre, e
  isso vira recomendação de tamanho de amostra.
- M2 reprova com 5%: a mistura não se identifica com estes tamanhos.
  Alternativas a avaliar, sem decisão prévia: emissões estimadas em dois
  estágios só nos verificados, prior informativo a partir de outros
  conjuntos, ou mais verificação (camada aleatória da fase 3).

## Etapas

| # | Etapa | Onde | Duração | Segue se |
|---|---|---|---|---|
| 0 | `sim_mixid.R` (dados do Stan, inits, grade, verdades), `run_mixid.R`, `summarise_mixid.R`. A log-verossimilhança R × Stan da mistura já foi conferida em `check_mix.R` | Mac | minutos | |
| 1 | Piloto: 1 réplica de cada braço nas duas verdades (10 ajustes), 10 workers | Mac | a medir | sem erros; tempo por ajuste medido |
| 2 | Rodada completa (500 ajustes), retomável por tarefa | AWS spot | a refazer após o piloto | aprovação do Diogo com o custo |
| 3 | Resumo por critério, pareado com o v0 | Mac | minutos | |

## Limites conhecidos

- Uma só forma de mistura, com f₀ de mesma média e f₁ com componentes
  ordenados, como no modelo. Se a mistura real tiver outra forma, nada aqui
  garante.
- Sem Markov dentro da noite, como no v0.
- 150 × 20 é bem menor que o Curiango; o teste de 07/11 com 300 × 56 e 1,2%
  de verificação (`results/mix_probe`) é um único conjunto e não mede viés.
- Priors das emissões provisórios. Se M2 reprovar, parte da falha pode vir
  deles; um prior predictive check da mistura não foi feito.

## Etapas 0 e 1 feitas (13/11/2026)

- `sim_mixid.R`, `run_mixid.R` e `summarise_mixid.R`. O resumo lê o v0 de
  `results/ignorab_v0` e pareia por verdade, conjunto, fração e desenho; o
  pareamento só fica completo com 50 réplicas, porque o número do conjunto
  depende do número de réplicas (no piloto só a verdade normal pareia).
- **Piloto:** 10 ajustes, nenhum erro, todos com R-hat < 1,01 e sem
  divergências, inclusive na verdade normal. Mediana de 371 s por ajuste
  (máximo 693 s), 1,08 h de CPU: cerca de duas vezes o v0. A rodada
  completa fica em cerca de **55 h de CPU**; numa c7a.16xlarge spot com 64
  workers, perto de 2 h de relógio e US$ 2 a 3. **Uma réplica não mede viés
  nem cobertura; os números do piloto não são interpretados.**

## Etapas 2 e 3: resultados (13/11/2026)

Rodada completa em `results/mixid_v0` (`task_all.rds` e `summary.txt`):
500 ajustes, nenhum erro, mediana de 526 s por ajuste, 67,9 h de CPU, uma
c7a.16xlarge spot sem interrupção. Mediana de positivos verificados por
conjunto: 15 a 17 com 2% e 40 a 43 com 5%.

| Critério | Resultado |
|---|---|
| M1 | passa: 4 de 4 células da verdade mistura com ≥ 95% convergidos (98% a 100%), nenhuma divergência em nenhuma célula |
| M2 | passa: 8 de 8 células; \|viés\| ≤ 0,011 e cobertura de 0,90 a 0,96 em ψ e θ |
| M3 | relatado: f₀ e o componente baixo de f₁ bem identificados; o componente alto de f₁ não (abaixo) |
| M4 | passa: 8 de 8 células; \|viés\| ≤ 0,012 e cobertura de 0,94 a 1,00 |
| M5 | relatado: sem verificação, θ na mistura tem viés 0,025 e cobertura 0,92, com intervalo 1,5 vez o do v0 |

**θ na verdade mistura, mistura contra v0 nos mesmos dados:**

| Fração | Desenho | Viés | Cobertura | Cobertura do v0 | Diferença pareada para o v0 | Largura / v0 |
|---|---|---|---|---|---|---|
| 5% | S1 | 0,001 | 0,96 | 0,78 | 0,021 | 0,98 |
| 5% | S2 | 0,007 | 0,94 | 0,86 | 0,019 | 1,04 |
| 2% | S1 | 0,011 | 0,90 | 0,80 | 0,029 | 1,13 |
| 2% | S2 | 0,011 | 0,96 | 0,84 | 0,026 | 1,17 |
| — | sem verificação | 0,025 | 0,92 | 0,78 | 0,044 | 1,50 |

ψ fica com viés ≤ 0,005 nas duas verdades. Na mistura, a cobertura de ψ é
0,92 (a do v0 era 0,96 a 0,98); está acima do limiar, a cerca de um
erro-padrão de Monte Carlo de 0,95.

**Leitura:**

- A subcobertura de θ que o v0 tinha sob a mistura some quando f tem a
  forma certa, com S1 e com S2. Isso confirma a interpretação registrada na
  ignorabilidade: o problema era a forma de f, não a seleção.
- PPS (S2) e aleatório (S1) dão o mesmo resultado nas duas frações, como
  esperado se a seleção pelo score é ignorável.
- Na verdade normal, a mistura não custa viés nem cobertura; os intervalos
  de θ ficam de 5% a 18% mais largos que os do v0. A convergência fica
  entre 94% e 100% por célula (S1 com 5% em 0,94, as outras ≥ 0,96); M1 só
  bloqueia as células da mistura, mas isso é anotado.
- O componente alto de f₁ (μ₁b, σ₁b) é mal identificado: viés de −0,23 a
  −0,27 em μ₁b, intervalo de cerca de 1,4 a 1,6 na escala logit, cobertura
  0,90 a 0,92. Ele tem só 22% das chamadas, que são
  poucas e espalhadas (σ 1,42). Isso não chega a ψ e θ aqui. Não se deve
  interpretar μ₁b nem σ₁b de um ajuste real.
- Sem verificação, a mistura ainda recupera θ (cobertura 0,92), com
  intervalo bem mais largo. Pela estrutura do modelo (f₀ com uma só média e
  f₁ ordenada acima dela), a forma é identificada pelos scores; a
  verificação estreita o intervalo de θ (0,17 → 0,10 a 0,13).

**Decisão pela regra fixada:** M2 e M4 passam, então o `model_mix.stan` passa
a ser a f padrão da fase 2: o v1 com Markov dentro da noite é construído
sobre a mistura, com verificação por PPS.

**Limites que continuam:** uma só forma de mistura (a mesma que gerou os
dados, com as mesmas restrições do modelo); priors das emissões
provisórios, sem prior predictive check; sem Markov; 150 × 20. Se a
seleção do Curiango dependeu do estado w (pergunta à Liliana), nada disso
protege.
