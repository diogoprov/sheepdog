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
