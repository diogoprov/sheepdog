# v1: mistura com Markov dentro da noite (plano, 13/11/2026)

Etapa 2 do passo do Curiango (`README.md`, "Etapas"), agora sobre a mistura,
como decidido em `PLANO-identificacao-mistura.md`. **O desenho e os
critérios da validação ficam fixos depois da aprovação do Diogo.**

## Modelo

`model_v1.stan` = `model_mix.stan` com um termo de Markov de primeira ordem
no canto latente w, dentro da noite (sítio-noite):

- num sítio ocupado, logit P(w_k = 1) = η_k + ρ w_{k−1} quando a ocasião
  anterior é o passo anterior do mesmo sítio (`adj` = 1), e η_k na primeira
  ocasião e depois de uma lacuna;
- η_k = α₀ + α₁ d + α_h h, como no v0 e na mistura;
- emissões e priors da mistura sem mudança; ρ ~ N(0; 2,5);
- a verossimilhança soma os estados de w pelo algoritmo forward;
- quantidades derivadas, no centro das covariáveis: θ₀ = logit⁻¹(α₀) (taxa
  de canto depois de uma lacuna) e θ̄ = θ₀ / (1 − logit⁻¹(α₀ + ρ) + θ₀)
  (taxa estacionária numa sequência de ocasiões adjacentes). Sem Markov,
  θ₀ = θ̄.

No Curiango, os minutos são gravados a cada 15 min; 96,4% vêm logo depois
do minuto anterior da mesma noite (passo de 15 min), 1,8% depois de 30 min
e o resto é a primeira ocasião da noite. A regra de adjacência é a do
`fp_occu(markov = )` do crywolf: o passo é o menor intervalo do sítio.

## Conferências feitas (13/11/2026)

`check_v1.R`, 60 sítios × 20 ocasiões, mistura, PPS com 5%:

| Conferência | Resultado |
|---|---|
| log-verossimilhança por sítio, forward em R × Stan, em 50 draws | diferença máxima 1,7e-06 |
| com ρ = 0, forward em R × `loglik_mix()` (redução à mistura) | diferença máxima 7e-15 |
| o simulador gera sequências | P(w = 1) = 0,57 nos ocupados, P(w = 1 \| anterior = 1) = 0,76 |

Uma corrida curta de 50 draws deu ρ médio de 2,12 contra 2 simulado. Não é
validação.

## Validação em simulação (desenho fixado antes de rodar)

- Dados (`simulate_v1()`): 150 sítios × 20 ocasiões, lacuna antes de 4% das
  ocasiões, ψ = 0,5 no centro (β = (0; −0,8)), α₁ = 0,6, α_h = 1,
  c = logit(0,1), emissões da verdade mistura da ignorabilidade.
- **ρ (2 níveis):** 0 (sem dependência; θ₀ = 0,3) e 2 (θ₀ = 0,15, de modo que
  θ̄ = 0,26 fica perto do 0,3 das outras simulações).
- Verificação por PPS (S2), 5% e 2%; inclusão de 0,05 × média no tamanho,
  como em `select_ignorab()`.
- Em cada conjunto, dois ajustes com os mesmos dados e a mesma seleção:
  `model_v1.stan` e `model_mix.stan` (sem Markov). A comparação é pareada.
- **50 réplicas** por nível de ρ: 2 × 50 × 2 frações × 2 modelos =
  **400 ajustes**. 4 cadeias, 1.000 + 1.000, adapt_delta = 0,95. Inits
  genéricos (`inits_v1()`, ρ = 0).

## Critérios (fixados antes de rodar)

Intervalos de 95%; viés na escala de probabilidade (ρ na escala logit).
Erro-padrão de Monte Carlo da cobertura perto de 0,03 com 50 réplicas.

| # | Critério | Limiar | Papel |
|---|---|---|---|
| V1 | Convergência do v1, por célula | ≥ 95% dos ajustes com R-hat < 1,01 em todos os parâmetros salvos e sem divergências | bloqueia a leitura da célula |
| V2 | Calibração do v1: ψ, θ₀ e θ̄, nas 4 células (ρ × fração) | cobertura ≥ 0,90 e \|viés\| ≤ 0,05 | decide |
| V3 | ρ no v1 | relatado (viés, cobertura, largura) | |
| V4 | Mistura sem Markov em dados com ρ = 2 | relatado: viés e cobertura de ψ e do seu θ contra θ̄ | mostra o que se perde sem Markov |
| V5 | Custo do Markov com ρ = 0 | relatado: diferença pareada v1 − mistura e larguras | |

**Decisão:**

- V1 e V2 passam: o v1 vai para o Curiango (etapa 2 do `README.md`): ajuste
  no classificador próprio em logit(0,1), PPC de autocorrelação e por classe,
  depois as etapas 3 e 4.
- V2 reprova só com 2%: o v1 exige mais verificação com dependência entre
  minutos; relata-se o número de positivos verificados necessário.
- V2 reprova com 5%: diagnóstico antes do Curiango (priors, parametrização
  de ρ, identificação de ρ contra a forma de f₁).

## Etapas

| # | Etapa | Onde | Duração | Segue se |
|---|---|---|---|---|
| 0 | `model_v1.stan`, `v1.R`, `check_v1.R` | Mac | feito | conferências passam |
| 1 | Piloto: 1 réplica (8 ajustes) | Mac | feito | sem erros; tempo medido |
| 2 | Rodada completa (400 ajustes), `run_v1val.R` | AWS spot | ~45 h de CPU | aprovação do Diogo |
| 3 | `summarise_v1val.R` | Mac | minutos | |

## Limites conhecidos

- 20 ocasiões por sítio, contra 56 minutos por noite no Curiango; as
  sequências ficam mais curtas que as reais.
- Markov de primeira ordem e ρ constante; sem efeito do sítio na dependência.
- Os dados vêm da forma que o modelo assume (mistura e Markov); passar aqui
  não diz nada sobre o PPC no Curiango.
- O critério 5 (comparação com `fp_occu()` com Markov) e o 4 (insensibilidade
  a c) ficam para o Curiango.

## Etapa 1 feita (13/11/2026)

- **Piloto:** 8 ajustes, nenhum erro, todos com R-hat < 1,01 e sem
  divergências. Mediana de 373 s por ajuste (máximo 430 s), 0,81 h de CPU.
  A rodada completa fica em cerca de **45 h de CPU**; numa c7a.16xlarge spot
  com 64 workers, perto de 1,5 h de relógio e cerca de US$ 2. **Uma réplica
  não mede viés nem cobertura; os números do piloto não são interpretados.**
- Corrigido no `run_v1val.R` depois do piloto: os nomes de ψ, θ₀ e θ̄ saíam
  com os nomes das colunas dos draws; os arquivos do piloto foram
  renomeados à mão antes do resumo. Não muda nenhum ajuste.
- Na mistura sem Markov, o "θ₀" do resumo é o seu θ e só se compara a θ̄
  (V4); com ρ = 2 ele não estima θ₀.

## Etapas 2 e 3: resultados (13/11/2026)

Rodada completa em `results/v1val` (`task_all.rds` e `summary.txt`): 400
ajustes, nenhum erro, mediana de 385 s por ajuste, 44,0 h de CPU, uma
c7a.16xlarge spot sem interrupção. Mediana de positivos verificados: 20 a 22
com 2% e 50 a 52 com 5%.

| Critério | Resultado |
|---|---|
| V1 | passa: 100% dos ajustes do v1 convergidos em todas as células, sem divergências |
| V2 | passa: 12 de 12 (ψ, θ₀ e θ̄ nas 4 células); \|viés\| ≤ 0,016 e cobertura de 0,94 a 1,00 |
| V3 | ρ com viés de 0,006 a 0,028 e cobertura de 0,90 a 0,96; intervalo de 0,77 a 0,91 na escala logit |
| V4 | a mistura sem Markov, com ρ = 2, superestima θ̄ (viés 0,032 e 0,042; cobertura 0,84 e 0,70) e subestima ψ (viés −0,025 e −0,033; cobertura 0,90 e 0,88) |
| V5 | com ρ = 0, o Markov não custa nada em viés (diferença pareada ≤ 0,002); intervalo de θ₀ 15% mais largo, o de ψ e θ̄ igual |

**Com ρ = 2, v1 contra a mistura sem Markov nos mesmos dados:**

| Fração | Parâmetro | v1: viés | v1: cobertura | Mistura: viés | Mistura: cobertura |
|---|---|---|---|---|---|
| 5% | ψ | 0,014 | 0,94 | −0,025 | 0,90 |
| 5% | θ̄ | −0,004 | 1,00 | 0,032 | 0,84 |
| 2% | ψ | 0,010 | 0,94 | −0,033 | 0,88 |
| 2% | θ̄ | −0,002 | 0,98 | 0,042 | 0,70 |

**Leitura:**

- O v1 recupera ψ, θ₀, θ̄ e ρ com dependência entre ocasiões e com 2% de
  verificação. A mistura dos clipes também segue identificada com o termo
  novo.
- Ignorar a dependência custa: a mistura sem Markov põe mais canto por
  ocasião e menos sítios ocupados, e a cobertura de θ̄ cai a 0,70 com 2%.
  A comparação é contra θ̄, a taxa estacionária; em sequências de 20
  ocasiões que começam em θ₀ a taxa média real fica um pouco abaixo de θ̄,
  então o viés da mistura contra a taxa realizada seria um pouco maior.
- Quando não há dependência, o termo de Markov não atrapalha: ρ fica perto
  de 0 e ψ e θ não mudam.

**Decisão pela regra fixada:** V1 e V2 passam; o v1 vai para o Curiango
(etapa 2 do `README.md`): ajuste no classificador próprio em logit(0,1), PPC
de autocorrelação e por classe, depois as etapas 3 e 4.

**Limites que continuam:** 20 ocasiões por sítio contra 56 no Curiango; ρ
constante; os dados vêm da forma que o modelo assume. O ajuste no Curiango
tem 97.806 ocasiões e deve levar bem mais que os 6 min por ajuste daqui;
o tempo precisa ser medido antes de planejar as etapas 3 e 4.

## Curiango: primeiro ajuste do v1 (13/11/2026)

`run_curiango_v1.R`, classificador próprio, c = logit(0,1), 1.753
sítios-noite, 97.806 minutos (96,4% adjacentes), 1.199 verificados (257
positivos). 4 cadeias, 1.000 + 1.000, 44 min no Mac. Resumo em
`results/curiango_v1/fit_v1_custom_0.1.rds` (draws a cada 8).

**Convergência:** sem divergências, sem treedepth máximo, E-BFMI 0,96 a
1,02, R-hat 1,00, ESS bulk ≥ 2.500.

**O ajuste não é plausível:**

| Quantidade | v1 | Referência |
|---|---|---|
| ψ no centro | 0,87 | 0,43 no v0 (piloto de 07/11) |
| θ̄ (canto por minuto nos ocupados) | 0,63 | 0,136 no v0 |
| fração de minutos com canto, ψ θ̄ | ≈ 0,55 | 0,107 pela estimativa ponderada dos verificados |
| ρ | 4,7 | |
| componente baixo de f₁ | 87% em N(−1,92; 0,26) | mediana dos negativos verificados não censurados: −1,96 |
| f₀ | 85% em N(−2,31; 0,19), quase todo abaixo de c = −2,20 | |

**PPC por classe nos verificados (critério 6), com as médias posteriores:**
78% dos negativos verificados não censurados têm f₁(s) > f₀(s), e 98% dos
positivos. Os negativos verificados têm 47% de scores censurados, e os não
censurados ficam entre −2,16 e −1,45 (percentis 10 e 90). O modelo pôs
essa faixa em f₁.

**Leitura (interpretação, não testada):** os scores sem canto logo acima de
c variam em sequências dentro da noite (ruído de fundo, outras espécies).
Sem outra forma de representar essa dependência, o termo de Markov e a
mistura de f₁ a absorvem como canto. Os 942 negativos verificados não
bastam contra os cerca de 58 mil minutos não censurados não verificados. A
simulação não pegou isso porque, nela, os scores sem canto são
independentes dado w.

Ainda não se sabe se o problema vem do Markov ou da mistura: o
`model_mix.stan` sem Markov nunca foi ajustado no Curiango.

## Curiango: mistura sem Markov, para isolar a causa (13/11/2026)

`run_curiango_v1.R ... mix` ajusta `model_mix.stan` com os mesmos dados, a
mesma semente e os mesmos inits genéricos (`inits_mixid()`). 4 cadeias,
1.000 + 1.000, 121 min no Mac, perto de três vezes o tempo do v1. Resumo em
`results/curiango_v1/fit_mix_custom_0.1.rds`; conferência em
`check_curiango_emissions.R`.

**Convergência:** sem divergências, sem treedepth máximo, E-BFMI 0,95 a
1,03, R-hat ≤ 1,004, ESS bulk ≥ 2.700.

| Quantidade | Mistura sem Markov | v1 | v0 (piloto de 07/11) |
|---|---|---|---|
| ψ no centro | 0,60 | 0,87 | 0,43 |
| θ (θ̄ no v1) | 0,60 | 0,63 | 0,136 |
| ψ θ | 0,36 | 0,55 | ≈ 0,06 |
| componente baixo de f₁ | 87% em N(−1,91; 0,30) | 87% em N(−1,92; 0,26) | (f₁ normal única) |
| f₀ | 76% em N(−2,25; 0,18) | 85% em N(−2,31; 0,19) | |
| negativos verificados não censurados com f₁ > f₀ | 67% | 78% | |
| positivos verificados com f₁ > f₀ | 97% | 98% | |

A estimativa ponderada dos verificados dá cerca de 0,107 de minutos com
canto.

**Leitura:**

- O problema vem da mistura, não do Markov: sem o termo de Markov, o
  componente baixo de f₁ continua sobre a faixa dos negativos logo acima de
  c (mediana −1,96), e a fração de minutos com canto fica em 0,36, mais de
  três vezes a estimativa ponderada.
- O Markov piora o quadro (0,36 → 0,55) porque os scores dessa faixa vêm em
  sequências dentro da noite, e ρ = 4,7 junta as sequências em "canto".
- O v0, com f₁ normal única, não tinha flexibilidade para pôr um componente
  estreito em −1,9 e ficou perto da estimativa ponderada. A flexibilidade
  que ajudou na simulação (M2 e M4 do `PLANO-identificacao-mistura.md`) é a
  que estraga o ajuste no Curiango, porque aqui os scores sem canto não
  seguem f₀ com uma só forma por todas as noites (interpretação, não
  testada).
- A tabela usa as médias posteriores; a fração de f₁ > f₀ não é um PPC
  completo por classe.

**Opções para a próxima etapa (decisão do Diogo):**

1. **Emissões em dois estágios:** estimar f₀ e f₁ só nos verificados, com
   os pesos 1/π, e fixá-las (ou usá-las como priors informativos estreitos)
   no ajuste de ocupação. Barato e direto; perde a propagação da incerteza
   das emissões, a menos que se usem priors.
2. **f₀ com variação por noite** (λ₀ aleatório por sítio-noite): ataca a
   causa interpretada; custo de 1.753 parâmetros a mais e risco de
   confundir com ψ.
3. **Restringir f₁:** f₁ normal única (como no v0) com Markov, ou
   componente baixo de f₁ com média acima de um limite. Rápido de testar,
   mas é uma restrição ad hoc.

## Curiango: emissões em dois estágios (13/11/2026)

Decisão do Diogo depois da seção anterior: opção 1.

- **Estágio 1** (`emissions_2stage_curiango.R`): f₀ e f₁ como misturas de
  duas normais censuradas, ajustadas só nos 1.199 minutos verificados, com
  pesos 1/(taxa de inclusão) em três estratos do score próprio (1,05%,
  2,85% e 11,5%), como em `emissions_weighted_curiango.R`. Bootstrap de 200
  réplicas por noite para a dispersão. n efetivo: 936 em f₀ e 120 em f₁.
- **Estágio 2** (`model_v1_2stage.stan`, `run_curiango_2stage.R`): as
  densidades log f₀(s) e log f₁(s) de cada minuto entram como dados; só β,
  α e ρ são estimados. `markov = 0` tira o termo de Markov. 4 cadeias,
  1.000 + 1.000, cerca de 30 min cada no Mac. Resumos em
  `results/curiango_v1/` (`emissions_2stage.rds`, `fit_2stage_m1.rds`,
  `fit_2stage_m0.rds`).

**Estágio 1, estimativas pontuais (intervalo de 90% do bootstrap):**

| Classe | peso do componente a | componente a | componente b |
|---|---|---|---|
| f₀ | 0,67 (0,49 a 0,89) | N(−2,18; 0,26) | N(−2,13; 0,61) |
| f₁ | 0,78 (0,73 a 0,83) | N(−1,45; 0,42) | N(0,91; 1,48) |

No ajuste conjunto, o componente baixo de f₁ ia para N(−1,91; 0,26–0,30);
com os verificados ponderados ele fica em −1,45 (−1,53 a −1,37).

**Estágio 2:** nos dois ajustes, sem divergências, sem treedepth máximo,
E-BFMI ≥ 0,98, R-hat ≤ 1,003, ESS bulk ≥ 2.700.

| Quantidade | 2 estágios, v1 | 2 estágios, sem Markov | v1 conjunto | mistura conjunta | v0 |
|---|---|---|---|---|---|
| ψ no centro | 0,48 (0,45 a 0,51) | 0,35 | 0,87 | 0,60 | 0,43 |
| θ₀ | 0,048 | 0,20 | 0,114 | 0,60 | 0,136 |
| θ̄ | 0,21 (0,20 a 0,23) | 0,20 | 0,63 | 0,60 | 0,136 |
| ρ | 4,54 (4,42 a 4,65) | | 4,71 | | |
| ψ θ̄ | **0,102 (0,095 a 0,109)** | 0,072 | 0,55 | 0,36 | ≈ 0,06 |

Intervalos de 90%. Referência: 0,107 de minutos com canto pela estimativa
ponderada dos verificados.

**Leitura:**

- Com as emissões fixadas pelos verificados, o v1 fica plausível: a fração
  de minutos com canto (0,102) bate com a estimativa ponderada (0,107), e
  ψ = 0,48 fica perto do v0.
- O padrão sem Markov repete o V4 da simulação: ψ cai (0,35 contra 0,48) e
  a fração de minutos com canto fica abaixo da referência.
- ρ continua alto (4,5): num sítio ocupado, P(canto | canto no minuto
  anterior) ≈ 0,82 e θ₀ ≈ 0,05. Os cantos vêm em sequências dentro da noite.

**Limites (não resolvidos):**

- A comparação com 0,107 não é independente: os dois usam os mesmos pesos
  e os mesmos verificados.
- Os pesos são provisórios: a inclusão também depende da hora e do sítio,
  e o mecanismo do sorteio não é conhecido (falta perguntar à Liliana). Se
  a seleção dependeu do estado real, as emissões do estágio 1 ficam
  enviesadas.
- A incerteza das emissões não entra no estágio 2: os intervalos acima são
  estreitos demais. Saídas: refazer o estágio 2 com algumas réplicas do
  bootstrap, ou usar o bootstrap como priors informativos no ajuste
  conjunto.
- O PPC de autocorrelação reprova (seção seguinte).
- O ψ θ̄ no centro das covariáveis é uma aproximação da fração média de
  minutos com canto.

## Curiango: PPC do v1 em dois estágios (13/11/2026)

`ppc_curiango_2stage.R`, com as mesmas estatísticas de `ppc_curiango_v0.R`:
y = 1 quando o score próprio passa de logit(0,4). 200 draws do estágio 2;
as emissões ficam nas estimativas pontuais do estágio 1. Leva segundos.
Saídas em `results/curiango_v1/ppc_2stage_m*.rds`.

| Estatística | Observado | 2 estágios, v1 | 2 estágios, sem Markov | v0 |
|---|---|---|---|---|
| P(y = 1 \| y = 1 no minuto anterior) | 0,39 | 0,13 a 0,17 | 0,04 a 0,06 | 0,07 a 0,09 |
| Fração de minutos com y = 1 | 0,018 | 0,017 a 0,021 | 0,015 a 0,019 | |
| Noites com alguma detecção | 0,25 | 0,34 a 0,41 | 0,30 a 0,37 | 0,36 a 0,42 |
| Variância de detecções por noite | 10,3 | 2,8 a 3,6 | 2,3 a 2,9 | 4,5 a 5,7 |
| Fração censurada (todos os minutos) | 0,41 | 0,42 a 0,43 | 0,43 a 0,44 | |
| Quantil de 90% do score (todos) | −1,32 | −1,20 a −1,14 | −1,24 a −1,18 | |

Intervalos de 95% das réplicas.

**Leitura:**

- O Markov em w triplica a autocorrelação replicada (de 0,05 para 0,15),
  mas fica longe de 0,39. Com ρ = 4,5 os cantos já vêm em sequências; o
  que falta parece estar no score: dado w = 1, 78% dos minutos caem no
  componente baixo de f₁ (abaixo de logit(0,4)), sorteado de forma
  independente a cada minuto. No dado, um minuto alto parece puxar o
  seguinte para alto, como se a intensidade do canto (ou a distância ao
  gravador) persistisse dentro da sequência. É uma interpretação, não foi
  testada.
- As detecções se concentram em menos noites do que o modelo produz
  (25% contra 34% a 41%), com variância três vezes maior. O v1 de dois
  estágios fica pior que o v0 nisso. Falta heterogeneidade entre noites
  além das covariáveis: um efeito aleatório de noite (ou de sítio) em θ.
- A distribuição global do score também não fecha: o modelo põe massa
  demais acima de −1,3. As estatísticas dos negativos verificados passam,
  então f₀ descreve os verificados, mas não a massa dos minutos não
  verificados. Isso é consistente com a seleção dos verificados depender
  de hora e sítio além do score (os pesos só corrigem o score).
- As estatísticas por classe nos verificados (`t_*`, `f_*`) não valem
  aqui: a réplica sorteia s de novo nos mesmos minutos, sem a seleção pelo
  score que formou o conjunto verificado. Os positivos reprovam por isso.

**O que isso muda:** ψ θ̄ = 0,102 bate com a referência, mas o modelo não
reproduz a estrutura temporal nem a heterogeneidade entre noites, então os
intervalos de ψ e θ̄ são otimistas mesmo antes de propagar a incerteza das
emissões. Candidatos, em ordem de custo: (1) efeito aleatório de noite em
θ; (2) dependência no score dentro da sequência (um estado latente de
intensidade, ou f₁ com dois estados persistentes no lugar da mistura
independente); (3) pesos de inclusão por hora e sítio no estágio 1.

## Curiango: efeito aleatório de noite em θ (13/11/2026)

Candidato 1 da seção anterior. `model_v1_2stage.stan` ganhou `night_re`: um
efeito aleatório da data (noite de calendário) em θ, não centrado, com
σ ~ N⁺(0, 1). Usei a data, e não o sítio-noite: há 7 sítios e 460 datas
(cerca de 3,8 sítios por data), e a data concentra a variação das detecções
(ANOVA das detecções por sítio-noite: F = 5,4 para data, 19,9 para sítio,
com 6 gl). Um efeito por sítio-noite se confundiria com z.

Só um teste curto: 2 cadeias, 150 + 150, com Markov. Levou 30 min (o
ajuste sem o efeito leva 30 min com 1.000 + 1.000), então o ajuste completo
custaria cerca de 3 h e iria para a AWS. Sem divergências, R-hat ≤ 1,01 nos
parâmetros fixos e ≤ 1,08 nos u, ESS de σ = 124.

- σ_noite = 0,32 (0,25 a 0,38), pequeno na escala logit. ψ = 0,50,
  θ̄ = 0,19 e ρ = 4,47, praticamente iguais ao ajuste sem o efeito.
- PPC (`ppc_curiango_2stage.R`, 200 draws, efeitos novos ou os posteriores
  de cada noite, mesmo resultado):

| Estatística | Observado | sem efeito | com efeito de data |
|---|---|---|---|
| P(y = 1 \| y = 1 antes) | 0,39 | 0,13 a 0,17 | 0,13 a 0,17 |
| Noites com detecção | 0,25 | 0,34 a 0,41 | 0,34 a 0,40 |
| Variância por noite | 10,3 | 2,8 a 3,6 | 2,8 a 3,9 |

**Leitura:** a heterogeneidade entre noites não parece estar na taxa de
canto. ψ já tem temperatura e umidade da data, e z por sítio-noite absorve
parte do resto. O que concentra as detecções (score acima de logit(0,4)) em
poucas noites parece ser o score dado o canto: em algumas noites os cantos
saem altos, em outras ficam no componente baixo de f₁. Isso aponta de novo
para o candidato 2 (o componente de f₁ variando por noite ou persistindo
na sequência). É interpretação; o teste direto é ajustar esse modelo.

Não rodei o ajuste completo.

## Curiango: componente de f₁ persistente na sequência (13/11/2026)

Candidato 2. No dado, depois de um minuto com score ≥ logit(0,4), o
seguinte também passa em 39% dos casos; depois de um minuto entre
logit(0,2) e logit(0,4), em 6,6%; depois de um abaixo de logit(0,2), em
0,8%. Entre sítios-noite com pelo menos 5 minutos acima de logit(0,2), a
fração dos que passam de logit(0,4) tem 2,5 vezes a variância binomial.

**Modelo** (`model_v1_3state.stan`, `run_curiango_3state.R`): três estados
por minuto, sem canto, canto no componente baixo de f₁ (L) e canto no alto
(H). As densidades dos dois componentes de f₁ e de f₀ ficam fixas no
estágio 1; o peso dos componentes passa a ser estimado e depende do minuto
anterior: P(H | canto) = logit⁻¹(ξ) depois de silêncio ou lacuna,
logit⁻¹(ξ + τ_H) depois de H e logit⁻¹(ξ + τ_L) depois de L. O canto segue
o Markov do v1 (ρ). Com τ_H = τ_L = 0 a verossimilhança por sítio-noite
coincide com a do `model_v1_2stage.stan` (conferido com as funções
expostas, inclusive em sítios com positivos verificados), e com τ ≠ 0
coincide com um forward escrito em R.

4 cadeias, 1.000 + 1.000, 41 min no Mac. Sem divergências, E-BFMI ≥ 0,91,
R-hat 1,00, ESS bulk ≥ 3.000. Resumo em `results/curiango_v1/fit_3state.rds`.

| Quantidade | Estimativa (90%) |
|---|---|
| ψ no centro | 0,50 (0,48 a 0,53) |
| θ₀ | 0,050 (0,046 a 0,053) |
| θ̄ | 0,23 (0,21 a 0,24) |
| ρ | 4,53 (4,42 a 4,64) |
| P(H) depois de silêncio | 0,22 (0,20 a 0,25) |
| P(H) depois de H | 0,77 (0,75 a 0,80) |
| P(H) depois de L | 0,040 (0,034 a 0,045) |
| ψ θ̄ | 0,114 (0,105 a 0,122) |

P(H) depois de silêncio (0,22) bate com o peso do componente alto de f₁
estimado nos verificados (1 − 0,78), embora aqui venha sobretudo dos não
verificados. ψ θ̄ = 0,114 fica perto da referência de 0,107.

**PPC** (200 draws):

| Estatística | Observado | 2 estágios, v1 | 3 estados |
|---|---|---|---|
| P(y = 1 \| y = 1 antes) | 0,39 | 0,13 a 0,17 | 0,47 a 0,53 |
| Fração de minutos com y = 1 | 0,018 | 0,017 a 0,021 | 0,016 a 0,020 |
| Noites com detecção | 0,25 | 0,34 a 0,41 | 0,28 a 0,34 |
| Variância por noite | 10,3 | 2,8 a 3,6 | 3,6 a 5,4 |
| Quantil de 90% do score (todos) | −1,32 | −1,20 a −1,14 | −1,19 a −1,13 |

**Leitura:**

- A persistência do componente é forte e explica a maior parte da
  dependência que o Markov em w deixava de fora: a autocorrelação passa de
  0,15 para 0,50, agora acima do observado (0,39). O excesso parece vir de
  supor que todo canto em H tem a mesma distribuição de score: com
  P(canto continua) ≈ 0,82, P(H | H) = 0,77 e 81% de N(0,91; 1,48) acima de
  logit(0,4), a réplica dá ≈ 0,5. Os scores dentro de uma sequência em H
  parecem variar mais que isso (interpretação).
- Concentração entre noites melhora (0,31 contra 0,37 de noites com
  detecção; variância 4,5 contra 3,2), mas continua abaixo do observado.
- A distribuição global do score continua sem fechar (f₀ dos verificados
  contra a massa dos não verificados), como antes.
- ψ e θ̄ mudam pouco em relação ao v1 de dois estágios (0,48 e 0,21):
  a estrutura das emissões afeta mais o PPC que as quantidades de
  interesse, ao menos com as emissões fixas.

**Próximos passos possíveis:** ρ diferente por componente (canto em H
pode durar mais), ou persistência como estado latente contínuo no lugar
de dois componentes; pesos de inclusão por hora e sítio (candidato 3); e
propagar a incerteza do estágio 1.

## Curiango: ρ por componente no modelo de três estados (14/11/2026)

`rho_comp = 1` em `model_v1_3state.stan`: o termo de Markov do canto
depende do componente do minuto anterior (ρ_H depois de H, ρ_L depois de
L). θ̄ passa a ser a fração estacionária de minutos com canto da cadeia de
três estados no centro (com `rho_comp = 0` dá o mesmo valor da fórmula
anterior). Verossimilhança conferida contra o forward em R com ρ_H ≠ ρ_L,
inclusive num sítio-noite com positivo verificado.

4 cadeias, 1.000 + 1.000, 59 min no Mac. Sem divergências, E-BFMI ≥ 0,95,
R-hat ≤ 1,01, ESS bulk ≥ 2.200. Resumo em
`results/curiango_v1/fit_3state_rc.rds`.

| Quantidade | ρ comum | ρ por componente |
|---|---|---|
| ψ no centro | 0,50 | 0,50 (0,47 a 0,53) |
| θ̄ | 0,23 | 0,23 (0,21 a 0,24) |
| ρ_H | 4,53 | 3,97 (3,82 a 4,11) |
| ρ_L | 4,53 | 4,82 (4,69 a 4,95) |
| P(H) depois de silêncio | 0,22 | 0,25 |
| P(H) depois de H | 0,77 | 0,81 |
| P(H) depois de L | 0,040 | 0,038 |
| ψ θ̄ | 0,114 | 0,114 (0,106 a 0,122) |

| PPC | Observado | ρ comum | ρ por componente |
|---|---|---|---|
| P(y = 1 \| y = 1 antes) | 0,39 | 0,47 a 0,53 | 0,44 a 0,50 |
| Fração de minutos com y = 1 | 0,018 | 0,016 a 0,020 | 0,015 a 0,019 |
| Noites com detecção | 0,25 | 0,28 a 0,34 | 0,29 a 0,34 |
| Variância por noite | 10,3 | 3,6 a 5,4 | 3,0 a 4,7 |

**Leitura:**

- Ao contrário do que eu supunha, o canto em H não dura mais: ρ_H < ρ_L.
  No centro, P(canto continua) é 0,73 depois de H e 0,86 depois de L. As
  sequências em L são mais longas.
- O PPC melhora pouco: a autocorrelação desce para 0,44 a 0,50, ainda
  acima de 0,39, e a variância por noite piora um pouco. ψ, θ̄ e ψ θ̄ não
  mudam.
- O excesso de autocorrelação, então, não parece vir da duração do canto.
  Fica a hipótese da seção anterior: o score dentro de uma sequência em H
  varia mais do que um único N(0,91; 1,48) com componente persistente
  permite (por exemplo, minutos de H com score abaixo de logit(0,4)
  quebrando a sequência de y). É interpretação.
- As quantidades de interesse estão estáveis entre as variantes de três
  estados (ψ θ̄ = 0,114 nas duas), o que sugere que o detalhe das emissões
  importa mais para o PPC do que para ψ e θ̄.

## Curiango: incerteza das emissões propagada ao modelo de três estados (14/11/2026)

O estágio 2 foi refeito no modelo de três estados com ρ comum para as 20
primeiras réplicas do bootstrap por noite do estágio 1 (`emis$boot`, b = 1
a 20, na ordem do sorteio). Em cada réplica, e0, e1a e e1b foram recalculados
a partir dos parâmetros dela (`run_curiango_3state.R`, argumento BOOT). Cada
réplica: 2 cadeias, 500 + 500, semente 2026, 35 a 45 min, 5 réplicas por vez
no Mac (10 núcleos). As amostras foram juntadas com o mesmo peso por réplica
(`pool_curiango_3state_boot.R`). A variância de cada quantidade foi separada
em duas partes: a média das variâncias dentro de cada réplica (emissões
fixas) e a variância das médias entre réplicas (incerteza das emissões).
Resumo em `results/curiango_v1/pool_3state_boot.rds`.

Diagnósticos: nenhuma divergência nem árvore no limite nas 20 réplicas,
R-hat ≤ 1,02, ESS bulk ≥ 458 e ESS tail ≥ 350 em cada uma.

| Quantidade | Emissões fixas (mediana, 90%) | Réplicas juntadas (mediana, 90%) | Parte da variância entre réplicas |
|---|---|---|---|
| ψ no centro | 0,50 (0,48 a 0,53) | 0,52 (0,47 a 0,55) | 0,63 |
| θ̄ | 0,23 (0,21 a 0,24) | 0,23 (0,19 a 0,27) | 0,87 |
| ψ θ̄ | 0,114 (0,106 a 0,122) | 0,121 (0,091 a 0,143) | 0,91 |
| θ₀ | 0,050 (0,046 a 0,053) | 0,051 (0,045 a 0,056) | 0,58 |
| ρ | 4,53 (4,42 a 4,64) | 4,54 (4,22 a 4,80) | 0,85 |
| P(H) depois de silêncio | 0,22 (0,20 a 0,25) | 0,21 (0,16 a 0,27) | 0,86 |
| P(H) depois de H | 0,77 (0,75 a 0,80) | 0,77 (0,71 a 0,82) | 0,79 |

**Leitura:**

- A incerteza das emissões domina. Ela responde por 91% da variância de
  ψ θ̄, e o intervalo de 90% fica 3,2 vezes mais largo (0,052 contra
  0,016). Os intervalos com as emissões fixas, nesta e nas seções
  anteriores, são otimistas.
- A média de ψ θ̄ por réplica vai de 0,089 a 0,147. Ela acompanha sobretudo
  a média do componente baixo de f₁ (correlação de −0,89 entre réplicas):
  quando esse componente fica mais baixo e se sobrepõe mais a f₀, mais
  minutos de score baixo passam a ser atribuídos ao canto. É uma leitura
  da correlação entre réplicas, não um teste. O componente baixo de f₁
  vem de poucos verificados positivos (n efetivo de f₁ = 120).
- A mediana conjunta (0,121) fica um pouco acima da estimativa com as
  emissões pontuais (0,114). O intervalo com as emissões pontuais cabe
  dentro do conjunto.

**Limites:**

- A distribuição do bootstrap é tratada como se fosse a posterior das
  emissões. É uma aproximação, não um ajuste conjunto.
- Os pesos de inclusão ficam fixos nas réplicas: a incerteza das taxas
  de inclusão por estrato não entra, e o mecanismo do sorteio dos
  verificados continua desconhecido.
- Com 20 réplicas, o desvio-padrão entre réplicas tem ~19 graus de
  liberdade, e as caudas do intervalo conjunto são aproximadas.
- O PPC continua reprovando a autocorrelação e a variância por noite.
  Propagar a incerteza das emissões não corrige a falta de ajuste.
- Para reduzir a incerteza, mais verificados positivos, sobretudo de
  score baixo, parecem render mais do que mais réplicas.

## Curiango: mecanismo de inclusão dos verificados (17/11/2026)

A Liliana descreveu como o conjunto verificado foi montado (resumo do
mecanismo, sem citar a conversa):

- foi um conjunto de teste de ~1% dos minutos, escolhido antes de rodar
  qualquer modelo (portanto sem score) e anotado à mão para presença e
  ausência;
- a estratificação foi só por localidade, proporcional ao áudio disponível
  em cada uma, nas mesmas horas;
- ela pode ter complementado localidades com poucas presenças ou ausências.
  O script está no computador da faculdade e ela vai conferir.

Os verificados por faixa do score próprio (`curiango_v0("custom")`):

| score | minutos | verificados | positivos | inclusão | esperado a 1,05% | excesso |
|---|---|---|---|---|---|---|
| < 0,3 | 95.176 | 1.002 | 72 | 1,05% | 1.002 | 0 |
| 0,3 a 0,5 | 1.226 | 35 | 26 | 2,85% | 13 | 22 |
| ≥ 0,5 | 1.404 | 162 | 159 | 11,5% | 15 | 147 |

O esperado usa a taxa da faixa baixa, então o excesso zero nela vale por
construção. Por sítio, a inclusão vai de 0,80% a 1,62% e os positivos de
24 a 43. Há também efeito da hora mesmo com score baixo (cerca de 1,5 a
1,9% entre 18 e 22 h, cerca de 0,9% entre 0 e 5 h, 0,11% às 6 h), coerente
com o sorteio restrito a certas horas.

**Leitura (interpretação, não teste):**

- O sorteio de ~1% bate com o relato dela na faixa baixa.
- Sobram ~169 minutos verificados de score alto, quase todos positivos.
  Isso é coerente com uma complementação dirigida a presenças, ou seja, uma
  seleção que depende do estado real.
- Se a complementação tivesse sido feita só de ouvido, sem score, os extras
  cairiam na maior parte abaixo de 0,3 (onde estão 72 dos ~98 positivos
  sorteados) e a inclusão nessa faixa passaria de 1%. Não passou. Isso
  sugere que os extras foram escolhidos com ajuda do score.

**Consequências para o estágio 1:**

- Se, dentro da faixa alta, os minutos complementados foram sorteados ao
  acaso, os pesos 1/inclusão por faixa de score corrigem o essencial.
- Se ela ficou com minutos que já sabia serem presenças, os falsos
  positivos de score alto ficam sub-representados (só 3 negativos acima de
  0,5): f₀ no topo fica subestimada, f₁ distorcida, e a precisão de ~98%
  acima de 0,5 fica inflada. Nesse caso os minutos complementados precisam
  ser identificados e tirados (ou tratados à parte) antes de refazer o
  estágio 1, e a comparação com 0,107 deixa de valer.
- ψθ̄ depende sobretudo de f₁ (r = −0,89 com mu_a de f₁), então o segundo
  caso mexe no resultado principal.

**Perguntas para o script:**

1. Os minutos complementados vieram das detecções do modelo ou de áudio
   ouvido sem score?
2. Dentro do complementado, foi sorteio ou escolha de presenças conhecidas?
3. Em quais localidades houve complementação, e com quantos minutos? Dá
   para marcar quais minutos entraram por ela?

Até a resposta, os resultados do estágio 1 e do estágio 2 ficam
provisórios. A sensibilidade (estágio 1 sem pesos, ou sem os minutos
complementados) fica para depois de saber como foi a complementação.

## Curiango: conjuntos de teste reconstruídos (19/11/2026)

O script de seleção da Liliana se perdeu. Ela guardou no NAS as saídas do
BirdNET e do custom (`Compau_DiverSons`) de cada conjunto de teste
(`Cjto-Teste_01` a `_03`) e a anotação por janela de 3 s (`Evaluation/`).
Cruzamento em `curiango_conjuntos_teste.R`; os arquivos ficam fora do
repositório.

**Composição.** 484, 483 e 241 arquivos (1.208). As 1.199 verificadas do
depósito estão todas em algum conjunto; sobram 7 arquivos sem verificado, e
2 positivos aparecem em ct03 e também em ct01 ou ct02. Sem repetição: 960
gravações sorteadas (43 positivas) e 239 só da complementação (214
positivas), 257 positivos no total.

Os 7 arquivos sem verificado estão todos em ct01/ct02 e no `Evaluation/`
com uma única janela de 3 s (áudio truncado, provavelmente), por isso
ficaram fora. O `Evaluation/` cobre só ct01+ct02 (967 arquivos) e concorda
100% com o `y` do depósito nos 962 em comum; a anotação do ct03 não está nele.

| Conjunto | n | positivos | BirdNET > 0 | custom ≥ 0,4 |
|---|---|---|---|---|
| ct01 | 477 | 3,8% (18) | 5,5% | 1,5% |
| ct02 | 483 | 5,2% (25) | 6,8% | 2,7% |
| ct03 | 241 | 89,6% (216) | 92% | 64% |
| população | 97.806 | — | 7,3% | 1,8% |

**ct01 e ct02 são o sorteio.**

- Contagens por sítio quase iguais nos dois, cerca de 1% de cada sítio (XAR
  0,76%).
- A inclusão varia com o mês: 1,5 a 2% em dez/2023–jan/2024 e em
  ago/2024–jan/2025, cerca de 0,6% de fev a jul/2024. Também varia com a
  hora: 18 a 22 h acima, 16, 17 e 23 h abaixo. É coerente com uma base
  aleatória somada às pastas filtradas por janela do relato dela.
- Dados ano-mês, hora e sítio, os scores quase não predizem a inclusão
  (LRT = 5,3, 2 gl, p = 0,07; coeficiente do custom levemente negativo). A
  seleção desses 960 é ignorável dadas covariáveis do depósito; π sai de um
  modelo logístico com esses três termos (aproximado, não exato como as
  listas das 6 pastas dariam).
- Com esses pesos: Kish n_eff = 494 de 960; prevalência de Hájek 0,026
  (0,045 sem peso).

**ct03 é a complementação.** 241 gravações, 90% positivas, nenhuma de Mimosa,
muitas de junho, escolhidas pelo BirdNET. A probabilidade de inclusão não é
recuperável. Fora as 2 repetidas, são 239 gravações e 214 dos 257 positivos
verificados, cerca de 40 por sítio (ARA 29, BEP 50), sem proporção ao
esforço.

**BirdNET da Liliana ≠ BirdNET do depósito.** O máximo por minuto das
saídas dela (divisão em 600 s, sem sobreposição, filtro 0 a 4 kHz) bate com
`conf_birdnet` do depósito em 82% dos 1.208 minutos (correlação 0,88),
em geral maior na versão dela. Existem pelo menos duas rodadas do BirdNET;
não dá para saber qual guiou a escolha do ct03. A tabela completa do
levantamento que ela guardou (`var+detc.csv`) tem os mesmos scores do
depósito.

**Leitura (interpretação, não teste):**

- A referência de prevalência cai para 0,026 nos conjuntos sorteados, contra
  0,107 (pesos por faixa do custom, seção anterior) e 0,059 (Hájek da sessão
  do crywolf, com ct03). O ψθ̄ = 0,114 do modelo de três estados fica longe
  da referência.
- Estágio 1 só com ct01+ct02: sem viés de seleção, mas 43 positivos
  identificam mal o f₁. Com ct03: os positivos voltam, mas o f₁ é puxado
  para scores altos, porque a escolha foi pelo score.
- **[decidir]** (Diogo): ct03 como camada não probabilística no modelo, ou
  só como sensibilidade; e se vale pedir à Liliana as listas das 6 pastas
  para tornar π de ct01+ct02 exato.

### Rodada do BirdNET usada pela Liliana e critério do ct03 (19/11/2026)

O Diogo trouxe do NAS a rodada `03_output_Birdnet-Clima_noite` (consolidado,
lista e parâmetros). Cruzamento em `curiango_rodada_clima.R`.

- A rodada cobre os 97.806 minutos do depósito, com os mesmos parâmetros das
  pastas dos conjuntos (divisão em 600 s, sem sobreposição, filtro 0 a
  4 kHz). O máximo por minuto é **idêntico** ao das pastas ct01 a ct03 em
  100% dos arquivos, e difere do `conf_birdnet` do depósito em 3% dos
  minutos (correlação 0,90). O `conf_birdnet` do depósito vem de outra
  rodada.
- Dos 239 do ct03, 220 têm detecção nessa rodada. A chance de escolha sobe
  com o score: 0,5% entre 0,1 e 0,2, 2,9% entre 0,3 e 0,7, 7,9% acima de
  0,7 (entre os 7.046 minutos com detecção fora do sorteio).
- Os outros 19 são todos de BEP, de nov/2023 a abr/2024, com custom entre
  0,10 e 0,75 (4 positivos). BEP tem só 131 minutos com detecção do BirdNET:
  parece que a cota de BEP foi completada com o custom.
- Cota de cerca de 40 por sítio (ARA 29, BEP 50), nenhum de Mimosa. Nenhum
  escolhido em jan–fev/2024, ago–set/2024 e de nov/2024 em diante, que são
  justamente os meses mais representados no sorteio; 110 dos 239 são de
  junho/2024. Parece uma complementação dirigida aos meses pouco cobertos
  (interpretação).
- Dado o score dessa rodada, sítio, ano-mês e hora, o BirdNET do depósito
  quase não acrescenta (LRT 3,8, p = 0,05), mas o custom ainda prediz a
  escolha (LRT 73). Ou seja: a escolha usou os dois classificadores, e não um
  BirdNET diferente do depósito.

**Consequência.** Com a rodada `Clima_noite` e o custom, todas as variáveis
que guiaram a escolha do ct03 parecem observadas, então um modelo de
seleção com os dois scores, sítio, ano-mês e hora dá π aproximadas também
para o ct03. Não dá para testar se a escolha dependeu ainda do estado real
(se ela ouviu antes de escolher), porque `y` só existe nos escolhidos. Fica
**[decidir]** se o estágio 1 usa o ct03 com esses pesos, com sensibilidade
sem ele. A frase da prova do JAV precisa dizer que a complementação usou o
BirdNET e, em um sítio, o classificador custom.

### Diário e planejamento da Liliana (19/11/2026)

O Diogo trouxe do NAS o `Diário.docx`, o `Planejamento.docx` e o material da
fase piloto de 2024 (`Curiango/Analises`). O diário diz, em resumo:

- de `Audios_Clima` (97.456 áudios), 6 pastas com 5% cada, sorteadas;
- da pasta 1, 975 áudios (1% do total), filtrando de julho a fevereiro e de
  18 h a 4h45;
- como esse conjunto tinha pouco curiango, ela tentou filtrar as 6 pastas
  por mês 7 a 11 e hora 18 a 3 h antes de sortear 975, e "só deu 258";
- por fim, passou o BirdNET nos conjuntos de teste "para achar mais
  ocorrência de curiango onde ainda tenho pouco" (o ct03).

**Confronto com os dados:**

- ct01+ct02 têm 967 arquivos, perto dos 975 do diário. Mas 309 deles estão
  fora da janela julho–fevereiro × 18h–4h45. A inclusão é 1,45% dentro da
  janela e 0,59% fora: parece uma parte sorteada sem filtro somada a uma
  parte filtrada (interpretação).
- A janela agosto–janeiro ajusta melhor que julho–fevereiro (julho e
  fevereiro ficam com a taxa de fora), e a hora 23 fica baixa mesmo dentro
  da janela. Nenhuma janela simples explica tudo (LRT de ano-mês + hora além
  da janela ≈ 200, 29 gl). As π de ct01+ct02 seguem do modelo empírico com
  ano-mês, hora e sítio, que já se mostrou ignorável em relação aos scores.
- A tentativa das "258" não aparece nos conjuntos.
- O diário diz que a complementação veio dos conjuntos de teste (as 6
  pastas, 30%), mas a rodada `Clima_noite` cobre todos os 97.806 minutos. Se
  o quadro do ct03 foi só os 30%, as π do ct03 levam um fator 0,3 a mais,
  sem mudar a forma do modelo. **[confirmar com a Liliana]**

**Treino do custom.** O `Planejamento.docx` registra os clipes de treino em
`D:/art-cur/IA/01_training`: 377 de curiango (42 a 59 por sítio, inclusive
Mimosa) e 342 de ruído, tirados das gravações do próprio levantamento
(prefixo `DIVSPTS01`). Ainda não foi checado se algum arquivo dos conjuntos
de teste também deu clipe de treino; para isso falta a lista de nomes de
`art-cur/IA/01_training`. O material de `Curiango/Analises` é da fase piloto
(gravações de 2023 do Arara), anterior ao levantamento.

**Decisão do Diogo (19/11/2026):** o ct03 entra no estágio verificado com π
estimadas. As π do ct03 vêm de um modelo de seleção com o score da rodada
`Clima_noite`, o custom, sítio, ano-mês e hora (com o fator 0,3 se o quadro
foi só as 6 pastas); as de ct01+ct02 vêm do modelo do sorteio (ano-mês, hora
e sítio). Fica registrada a ressalva de que a dependência da seleção no
estado real não é testável. A rodada `Clima_noite` precisa entrar no
depósito ou no compêndio. O estágio 1 refeito com essas π ainda não rodou.

### π do ct03 e teste da ignorabilidade (19/11/2026)

Scripts: `dev/fase2/curiango_pi_ct03.R` (π, pesos, sensibilidades) e
`dev/fase2/curiango_treino_sobreposicao.R` (clipes de treino × verificados,
aguardando a lista completa de `01_training/compau` e `noise`).

π1 = glm(inc ~ ano-mês + hora + sítio) nos 97.806 minutos; π3 = glm(sel ~
sítio + ano-mês + hora + Clima_noite + [Clima_noite = 0] + custom) no quadro
fora do ct01+ct02; π = π1 + (1 − π1) π3.

- Pesos 1/π: ct01+ct02 vão de 26 a 1.742 (mediana 75, soma 97.452); ct03
  vão de 1 a 215 (mediana 7, soma 3.337). Os 10 maiores pesos somam 6% do
  total. Os pesos extremos estão no sorteio, não no ct03.
- Prevalência (Hájek): 0,026 só ct01+ct02; 0,046 com todos e π; 0,050 com
  truncagem no p95; 0,075 com o fator 0,3; 0,214 sem peso.
- P(y = 1 | BirdNET 0,1–0,3): 0,24 só ct01+ct02; 0,42 com todos e π; 0,55
  com o fator 0,3. Nas faixas do custom a diferença é pequena acima de 0,5.

**Teste parcial do pressuposto.** Se a escolha do ct03 é ignorável dado os
scores, y ⟂ estágio | x entre os verificados. Não é:

- glm(y ~ Clima_noite + [= 0] + custom + sítio + mês + hora): acrescentar o
  indicador do ct03 dá LRT 27,8 (1 gl), coeficiente 6,0 (EP 1,5).
- Com o número de janelas do Clima_noite por minuto (todas e ≥ 0,3) no
  modelo, o LRT fica em 21,9 e o coeficiente em 5,7 (EP 1,5).
- Bruto, com custom < 0,3 e BirdNET > 0,1: ct03 tem 49 positivos em 57
  (86%), ct01+ct02 tem 8 em 39 (21%). Dos 220 do ct03 com detecção do
  BirdNET, só 10 são negativos.

Leitura (interpretação): a escolha do ct03 usou informação sobre o estado
real além dos scores, provavelmente a escuta ou a inspeção do espectrograma
antes de incluir o arquivo. Outra possibilidade é critério de anotação
diferente no ct03. Nos dois casos as π estimadas não corrigem o viés, e a
curva P(y | score) com o ct03 sai inflada nos scores baixos.
**[decidir: o Diogo precisa rever a decisão de 19/11; o estágio 1 não
roda até lá. Opções: (a) estágio 1 só com ct01+ct02 (960, 43 positivos) e o
ct03 como checagem externa; (b) ct03 só para a sensibilidade/especificidade
condicional ao positivo, não para a prevalência nem a curva.]**

**Decisão do Diogo (19/11/2026, revista):** opção (a), estágio 1 só com
ct01+ct02 e pesos 1/π1; (c) como sensibilidade. Substitui a decisão
anterior do mesmo dia. Rascunho no Gmail para a Liliana com três
perguntas: ela ouviu antes de incluir no ct03? mesmo critério de anotação?
quadro do ct03 = 6 pastas?

### Estágio 1 refeito (19/11/2026)

`emissions_ct12_curiango.R` (π de `results/curiango_v1/pi_verificados.csv`,
gerado por `curiango_pi_ct03.R`). `emis_2stage()` ganhou `use`, `w` e
`min_sd`, com defaults que mantêm o comportamento antigo.

- (a) ct01+ct02, pesos 1/π1. Com 43 positivos (n efetivo 29), a mistura de
  f₁ colapsava num pico (sd 0,03) em três scores de peso alto; `min_sd =
  0,2` nos dois ajustes novos.
- (c) os 1.199, com π do ct03 corrigida pela seleção no estado real:
  π3 · P(y | x, ct03) / P(y | x, população), x = (Clima_noite, [= 0],
  custom), ajustes com `brglm2` (o glm comum separa). Supõe deslocamento
  constante no log-odds, o que o teste da interação não sustenta.
- Bootstrap de 200 réplicas por noite, com os pesos fixos.

| | f₁: peso do comp. baixo | f₁: comp. baixo | f₁: comp. alto | P(s > logit 0,4 \| y = 1) | n efetivo f₁ |
|---|---|---|---|---|---|
| (a) ct01+ct02 | 0,38 (0,23 a 0,69) | N(−1,67; 0,37) | N(0,49; 1,05) | 0,50 | 29 |
| (c) com ct03 corrigido | 0,26 (0,16 a 0,42) | N(−1,63; 0,38) | N(0,67; 1,10) | 0,62 | 65 |
| antigo (estratos do custom) | 0,78 (0,73 a 0,83) | N(−1,45; 0,42) | N(0,91; 1,48) | 0,18 | 120 |

f₀ quase não muda (P(s > logit 0,4 | y = 0) de 0,0003 a 0,0015).

Leitura: o peso alto do componente baixo de f₁ no estágio 1 antigo vinha
do ct03 (positivos de custom baixo escolhidos pelo BirdNET e pela escuta).
Sem ele, f₁ põe metade da massa acima de logit 0,4. Como ψθ̄ depende
sobretudo de f₁ (r = −0,89 com mu_a), o estágio 2 deve mudar: espera-se
fração de minutos com canto menor que 0,102 (interpretação; a referência
ponderada agora é 0,026 só com ct01+ct02).

### Plano do estágio 2 (a confirmar com o Diogo)

`run_curiango_2stage.R` com as emissões novas, 4 cadeias, 1.000 + 1.000,
semente 2026, ~30 min por ajuste no Mac (4 núcleos cada, 2 ajustes em
paralelo = 8 núcleos):

1. (a) com Markov (principal) e (a) sem Markov.
2. (c) com Markov (sensibilidade).
3. PPC (`ppc_curiango_2stage.R`) dos três, segundos cada.

Total ~1 h local (abaixo das 2 h; sem AWS). Diagnósticos: divergências,
treedepth, E-BFMI, R-hat, ESS. A incerteza do estágio 1 continua fora do
estágio 2; com n efetivo 29 em f₁ isso pesa mais que antes, e a saída
seria repetir o estágio 2 com algumas réplicas do bootstrap (fica para
depois).
