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

### Estágio 2 com as emissões novas (19/11/2026)

`run_curiango_2stage.R`, 4 cadeias, 1.000 + 1.000, semente 2026, ~10 min
por ajuste no Mac. Saídas em `results/curiango_v1/ct12_m1/`, `ct12_m0/` e
`ct03r_m1/` (fit e PPC). Os três ajustes: sem divergências, sem treedepth
máximo, E-BFMI ≥ 0,92, R-hat ≤ 1,004, ESS bulk ≥ 2.400.

| Quantidade | (a) v1 | (a) sem Markov | (c) v1 | antigo v1 | antigo sem Markov |
|---|---|---|---|---|---|
| ψ no centro | 0,42 (0,39 a 0,45) | 0,29 | 0,35 | 0,48 | 0,35 |
| θ₀ | 0,036 | 0,144 | 0,033 | 0,047 | 0,204 |
| θ̄ | 0,152 | 0,144 | 0,118 | 0,211 | 0,204 |
| ρ | 4,66 (4,54 a 4,79) | | 4,50 | 4,54 | |
| ψ θ̄ | **0,064 (0,058 a 0,070)** | 0,041 | 0,041 (0,037 a 0,045) | 0,102 | 0,071 |

Intervalos de 90%. Referência ponderada só com ct01+ct02: 0,026 (Hájek).

PPC (y = 1 quando o score passa de logit 0,4; intervalo de 90% das réplicas):

| Estatística | Observado | (a) v1 | (a) sem Markov | (c) v1 | antigo v1 |
|---|---|---|---|---|---|
| Fração de minutos com y = 1 | 0,018 | 0,030 a 0,036 | 0,024 a 0,030 | 0,026 a 0,034 | 0,017 a 0,021 |
| P(y = 1 \| y = 1 antes) | 0,39 | 0,39 a 0,43 | 0,11 a 0,14 | 0,45 a 0,49 | 0,13 a 0,17 |
| Noites com alguma detecção | 0,25 | 0,31 a 0,36 | 0,25 a 0,31 | 0,30 a 0,35 | 0,34 a 0,41 |
| Variância de detecções por noite | 10,3 | 10,6 a 14,2 | 7,2 a 9,4 | 10,3 a 14,5 | 2,8 a 3,6 |

(As estatísticas t do PPC usam todos os positivos verificados sem peso,
inclusive o ct03, e por isso não servem para julgar a (a).)

Leitura:

- ψθ̄ cai de 0,102 para 0,064 na (a) e 0,041 na (c), na direção esperada
  (f₁ com mais massa nos scores altos). Ainda fica acima da referência
  ponderada (0,026), que também é incerta (43 positivos).
- O PPC troca de falha: a dependência entre minutos e a variância por noite
  agora batem (antes reprovavam por larga margem), mas a fração de minutos
  com y = 1 passa a sair alta (0,030 a 0,036 contra 0,018). Leitura
  (interpretação): f₁ com 29 positivos efetivos põe massa demais acima de
  logit 0,4, ou ψθ̄ ainda está alto; os dois juntos explicam o excesso.
- A incerteza do estágio 1 (peso do componente baixo de f₁ de 0,23 a 0,69)
  não entra nos intervalos acima, que estão estreitos demais. Com n
  efetivo 29, isso agora é o limite principal.
- (c) dá ψθ̄ menor que (a); as duas ficam bem abaixo do antigo, então a
  conclusão "o antigo superestimava" não depende da sensibilidade.

**[decidir] próximo passo:** propagar a incerteza do estágio 1 repetindo o
estágio 2 com réplicas do bootstrap (20 réplicas × ~10 min, 2 em paralelo
≈ 1h40 local; com mais réplicas, AWS), ou levar o bootstrap como priors
informativos para f₁ no ajuste conjunto.

### Respostas da Liliana sobre o ct03 (19/11/2026)

De memória, sem documentação:

1. Ouvia ou olhava o espectrograma antes de incluir no ct03? "Provavelmente".
2. Mesmo critério de anotação nos três conjuntos? Sim, todos anotados por
   ela.
3. Quadro do ct03: só as 6 pastas de 5%, e talvez só as 3 primeiras.

Consequências:

- A resposta 2 descarta a explicação por critério de anotação diferente. A
  resposta 1 é coerente com o teste (y ⟂ estágio | x falha): a escolha do
  ct03 dependeu do estado real. A opção (a) fica justificada.
- O quadro do ct03 seria 30% (fator 0,3) ou 15% (fator 0,15) do levantamento.
  Isso só afeta a sensibilidade (c), não a (a). A (c) já supõe deslocamento
  constante no log-odds, o que os dados não sustentam, então o fator não
  muda o que concluímos dela.
- Para o artigo do JAV, a frase "The supplementary files were inspected
  before inclusion" passa a ser verdadeira. A prova já foi devolvida; a
  inclusão é uma correção opcional ao editor de produção (decisão do Diogo
  e da Liliana).

### Ajuste conjunto com prior na f₁ (19/11/2026)

Decisão do Diogo: levar o bootstrap como prior em vez de repetir o estágio
2. `model_v1_prior1.stan` e `run_curiango_v1prior.R`: f₁ parametrizada como
u = (logit π₁, μ₁a, log gap, log σ₁a, log σ₁b), u ~ MVN com média e
covariância das 200 réplicas do bootstrap da (a); todos os minutos entram
como não verificados (os rótulos só pelo prior). 4 cadeias, 1.000 + 1.000,
~65 min. Saída em `results/curiango_v1/v1prior_ct12/`.

Convergência boa (sem divergências, R-hat ≤ 1,003, ESS bulk ≥ 2.000), mas
o posterior foge do prior e repete a falha do v1 conjunto antigo:

| Parâmetro de f₁ | prior (média) | posterior (mediana) |
|---|---|---|
| π₁ (peso do comp. baixo) | 0,44 | 0,867 |
| μ₁a | −1,58 | −1,945 |
| σ₁a | 0,38 | 0,253 |

O componente baixo de f₁ vai para cima de f₀ (λ₀ = −2,35), e o modelo passa a
chamar de canto a massa de minutos de score baixo: ψ = 0,92, θ̄ = 0,71,
ψθ̄ = 0,66 (0,64 a 0,67). PPC reprova em tudo (fração com y = 1: 0,026 a
0,029 contra 0,018; P(y | y antes): 0,04 a 0,06 contra 0,39; noites com
detecção: 0,68 a 0,73 contra 0,25; variância por noite: 1,9 a 2,2 contra
10,3).

Leitura: com ~97 mil minutos não rotulados, a verossimilhança da mistura
domina um prior tirado de 29 positivos efetivos; a não identificação entre
o componente baixo de f₁ e f₀ volta. O prior do bootstrap não basta. O
caminho viável continua sendo o de dois estágios (emissões fixadas pelos
verificados), e a incerteza do estágio 1 teria de entrar por réplicas do
bootstrap no estágio 2.
**[decidir]** repetir o estágio 2 com réplicas do bootstrap (20 réplicas ×
~10 min, 2 em paralelo ≈ 1h40 local) ou parar nos intervalos atuais com a
ressalva.

### Estágio 2 com réplicas do bootstrap do estágio 1 (20/11/2026)

`emissions_boot_curiango.R` gera as densidades por minuto das 20 primeiras
réplicas do bootstrap por noite da (a). As densidades nas estimativas
pontuais batem com as do estágio 1 (diferença máxima 0). Cada réplica foi
ajustada com `run_curiango_2stage.R` (Markov, 4 cadeias, 1.000 + 1.000,
~24 min por par de réplicas em paralelo, ~3h50 no total), e
`pool_2stage_boot.R` empilha os draws das 20 com peso igual. Saídas em
`results/curiango_v1/boot_ct12/` (`b01` a `b20`, `pool.rds`).

Os 20 ajustes: sem divergências, sem treedepth máximo, E-BFMI ≥ 0,91,
R-hat ≤ 1,006, ESS bulk ≥ 2.480.

| Quantidade | emissões pontuais | agrupado (20 réplicas) |
|---|---|---|
| ψ no centro | 0,42 (0,39 a 0,45) | 0,42 (0,37 a 0,47) |
| θ₀ | 0,036 (0,033 a 0,039) | 0,037 (0,030 a 0,048) |
| θ̄ | 0,152 (0,139 a 0,165) | 0,140 (0,101 a 0,190) |
| ρ | 4,66 (4,54 a 4,79) | 4,47 (3,85 a 4,80) |
| ψ θ̄ | 0,064 (0,058 a 0,070) | **0,059 (0,038 a 0,088)** |

Intervalos de 90%. As medianas de ψθ̄ por réplica vão de 0,035 a 0,093;
correlação de 0,48 com o peso do componente baixo de f₁ na réplica.

Leitura:

- A incerteza do estágio 1 domina: o intervalo de ψθ̄ fica cerca de 4×
  mais largo. ψ quase não muda; quem absorve a incerteza é θ̄.
- A referência ponderada só com ct01+ct02 (0,026) continua abaixo do
  intervalo agrupado. A distância diminuiu, mas não some. Com 43 positivos,
  a referência também tem incerteza grande (não calculada aqui).
- Este é o resultado a reportar para o v1 de dois estágios no Curiango:
  ψθ̄ = 0,059 (0,038 a 0,088), com a ressalva de que 20 réplicas dão
  extremos do intervalo imprecisos.

### Sobreposição treino/teste do classificador custom (20/11/2026)

Listas de `01_training/compau` (377 clipes) e `noise` (342) da máquina da
Liliana, em `results/curiango_v1/treino/` (fora do git). Rodado com
`curiango_treino_sobreposicao.R`.

- Os clipes vêm de 414 gravações de origem, de set/2021 a jul/2024:
  curiango 6 em 2021, 180 em 2022, 191 em 2023; ruído 157 em 2022, 175 em
  2023, 10 em 2024. O depósito vai de 26/11/2023 a 27/02/2025.
- Só 1 gravação de curiango e 5 de ruído caem no período e no depósito.
  **Nenhuma está entre os 1.199 minutos verificados.** Logo, não há
  sobreposição treino/teste, e as métricas do custom não estão otimistas
  por esse motivo.
- 269 dos 377 nomes de `compau` começam com "teste.". É prefixo de nome de
  arquivo; nenhum desses clipes casa com um minuto verificado.

### Item 4: prevalência marginal do modelo × referência por desenho (20/11/2026)

`curiango_prevalencia_marginal.R`. O ψθ̄ = 0,059 é a prevalência de uma
noite típica (ψ com as covariáveis no centro, θ̄ na noite mediana). A
referência de Hájek é a média sobre todos os minutos. Para comparar a mesma
grandeza, calculei a prevalência marginal do modelo: para cada draw, a média
de ψᵢ · P(wₙ = 1 | zᵢ = 1) sobre os 97.806 minutos, com P(w = 1 | z = 1)
dada pela recursão de Markov sem as emissões. Foram 100 draws de cada uma
das 20 réplicas. A referência ganhou um bootstrap por sítio-noite (696
sítio-noites com verificados de ct01+ct02, π1 fixo, 2.000 réplicas).
Saída em `results/curiango_v1/boot_ct12/prevalencia_marginal.rds`.

| Quantidade | Mediana | 90% |
|---|---|---|
| Modelo, ψθ̄ (noite típica) | 0,059 | 0,038 a 0,088 |
| Modelo, prevalência marginal nos minutos | **0,062** | 0,043 a 0,086 |
| Referência de Hájek (ct01+ct02, n = 960, 43 positivos) | **0,026** | 0,019 a 0,035 |
| Proporção sem pesos | 0,045 | |

**Os intervalos não se sobrepõem.** Em todos os draws, a prevalência
marginal fica acima da referência. Corrigir a grandeza não fecha a
diferença: a média sobre os minutos sobe um pouco em relação à noite
típica.

Onde está o excesso. Minutos com canto por faixa do score custom: o modelo
dá prevalência × massa de f₁ na faixa × N; a referência dá a soma de
y / π1 em ct01+ct02.

| Faixa | Modelo (90%) | Referência HT | Positivos | Minutos no depósito |
|---|---|---|---|---|
| < 0,1 (censurado) | 193 (68 a 430) | 0 | 0 | 39.956 |
| 0,1 a 0,4 | 2.928 (1.489 a 4.917) | 1.343 | 23 | 56.094 |
| 0,4 a 0,7 | 1.572 (970 a 1.957) | 412 | 8 | 858 |
| ≥ 0,7 | 1.399 (859 a 1.816) | 817 | 12 | 898 |

- Nas faixas altas, o modelo prevê mais minutos com canto do que o
  depósito inteiro tem minutos (1.572 contra 858; 1.399 contra 898). É o
  mesmo excesso que o PPC de 19/11 mostrou (fração acima de logit 0,4:
  0,030 a 0,036 previsto, 0,018 observado), agora na escala da
  prevalência.
- A forma de f₁ concorda com a referência. A massa da referência por faixa
  (0,52 / 0,16 / 0,32 dos positivos ponderados acima de 0,1) se parece com
  a f₁ do estágio 1 (0,47 / 0,28 / 0,23).
- Estimativa só com as emissões, sem a estrutura dinâmica: dada a fração
  observada de minutos acima de 0,4 (0,018) e a massa de f₀ e f₁ acima
  desse corte, a prevalência implícita é 0,035 (0,029 a 0,051); com o corte
  em 0,7, 0,040 (0,030 a 0,067). Esse intervalo encosta no da referência e
  fica abaixo do modelo. (A mesma conta na fração censurada dá 0,13; ali
  f₀ põe 0,46 de massa e o depósito tem 0,41, de modo que as emissões
  também não fecham entre si na cauda baixa.)

Leitura (interpretação): o excesso vem do estágio 2, não da referência. Com
as emissões fixas, a estrutura latente (ψ por sítio-noite, θ com
covariáveis, ρ comum) parece não reproduzir ao mesmo tempo as sequências de
minutos e a contagem de scores altos. O ajuste fecha as sequências
(ρ ≈ 4,5) à custa de chamar de canto minutos de score baixo e médio:
2.928 na faixa de 0,1 a 0,4, contra 1.343 da referência. A incerteza de f₁
(29 positivos efetivos) agrava, mas não explica tudo: a estimativa só pelas
emissões já fica abaixo do modelo. Os falsos negativos da anotadora
puxariam a referência para baixo, mas teriam de ser mais da metade dos
cantos para fechar a diferença.

**Critério 1 do item 8 não cumprido.**

### Atacando o desajuste do estágio 2 (21/11/2026)

Duas tentativas, as duas com 4 cadeias de 1000 + 1000, sem divergências,
sem treedepth máximo, E-BFMI > 0,9 e R-hat ≤ 1,004.

1. **Estágio 1 pelo censo** (`emissions_census_curiango.R`). f₀ e a fração
   p de minutos com canto são ajustadas por verossimilhança composta sobre
   os verificados de ct01+ct02 (só os negativos, com pesos 1/π₁) e todos os
   outros minutos do depósito. f₁ fica fixa pelos positivos: livre, ela não
   é identificada (p sobe a 0,129 e f₁ escorrega para os scores baixos). A
   massa censurada de f₀ cai de 0,46 para 0,427 (depósito: 0,409), e p =
   0,037.
2. **Estrutura de 3 estados** (`model_v1_3state.stan`, rho_comp = 0). Os
   componentes de f₁ persistem; com rho_comp = 0 o canto segue a mesma
   cadeia do v1, então a prevalência marginal se calcula do mesmo jeito.

| Ajuste | ψ_c · θ̄ | Prevalência marginal (90%) | y_rate do PPC (obs. 0,018) |
|---|---|---|---|
| v1, réplicas do bootstrap ct12 | 0,059 | 0,062 (0,043 a 0,086) | acima |
| v1, f₀ do censo (`census_m1`) | 0,054 | 0,057 (0,053 a 0,061) | 0,025 a 0,032 |
| 3 estados, emissões ct12 (`s3_ct12`) | 0,19 | 0,169 (0,161 a 0,177) | 0,017 a 0,021 |
| 3 estados, f₀ do censo (`s3_census`) | 0,17 | 0,155 (0,148 a 0,163) | 0,017 a 0,021 |
| Referência de Hájek | | 0,026 (0,019 a 0,035) | |

O censo tira pouco (0,062 → 0,057) e estreita o intervalo, mas não fecha.
O de 3 estados acerta a fração de minutos com score alto e triplica a
prevalência: ρ ≈ 4,95, θ̄ ≈ 0,32, componente baixo de f₁ com p_h ≈ 0,19.
Nos dois de 3 estados o PPC continua reprovando a variância entre noites
(obs. 10,3 contra 3,3 a 5,1), a fração de noites com algum score alto (obs.
0,25 contra 0,31 a 0,37) e P(y | anterior) (obs. 0,39 contra 0,44 a 0,51).

Dois fatos do dado:
* entre os verificados de ct12, os 20 minutos com score ≥ 0,4 são todos
  positivos; os 23 positivos restantes estão na faixa de 0,1 a 0,4
  (precisão ponderada 0,026), e nenhum abaixo de 0,1;
* dos 1.756 minutos com score ≥ 0,4 no depósito (1,8%), 98,7% têm um
  vizinho imediato também ≥ 0,4. *Correção em 21/11/2026: são 996, 56,7%;
  201 sítio-noites têm um único minuto ≥ 0,4. O 98,7% não se reproduz.*

Leitura (interpretação): os scores altos vêm em surtos curtos, concentrados
em poucas noites. O modelo só consegue produzir esse agrupamento pela cadeia
de canto, e a persistência que fecha os surtos (ρ alto) estende as
sequências de canto para os minutos de score baixo em volta. Dar mais
liberdade às emissões dentro do canto (3 estados) piora, porque o
componente baixo de f₁ se confunde com f₀ e vira um estado latente que o
modelo usa para qualquer agrupamento de scores. O que falta parece ser
heterogeneidade entre noites na intensidade e na duração dos surtos, não a
forma das emissões. **Critério 1 continua não cumprido.**

### Onde o modelo põe canto a mais: leave-one-out e ct03 (21/11/2026)

`curiango_teste_ct03.R`: forward-backward do ajuste com f₀ do censo
(`census_m1`) e do ajuste com emissões ct12 (`ct12_m1`), 200 draws. Calcula
P(canto | scores, rótulos) por minuto. Nos verificados do ct12, a posterior
é calculada sem o próprio rótulo (leave-one-out) e comparada com ele, com
pesos 1/π₁. O ct03 foi escolhido ouvindo o áudio, então a fração de
positivos nele não é estimável; entra só como descrição.

**Referência melhor.** O Hájek simples erra as faixas altas (20 verificados,
todos positivos, estimam 1.234 minutos onde há 1.756). Pós-estratificada em
três faixas de score (< 0,1; 0,1 a 0,4; ≥ 0,4), com os totais conhecidos do
depósito: **0,033 (90%: 0,027 a 0,039)**, bootstrap por sítio-noite. Passa a
ser a referência do critério 1.

Minutos com canto no depósito (posterior do `census_m1`):

| Faixa | Minutos | Modelo | Precisão do ct12 × minutos |
|---|---|---|---|
| < 0,1 | 39.956 | 71 | 0 |
| 0,1 a 0,4 | 56.094 | 4.040 | 1.442 |
| ≥ 0,4 | 1.756 | 1.708 | 1.756 |
| total | 97.806 | 5.819 (0,059) | 3.198 (0,033) |

Leave-one-out no ct12 (média ponderada; obs. contra pred.):

| Grupo | n | Positivos | Obs. | `census_m1` | `ct12_m1` |
|---|---|---|---|---|---|
| 0,1 a 0,2 | 460 | 14 | 0,013 | 0,042 | 0,049 |
| 0,2 a 0,3 | 32 | 6 | 0,155 | 0,337 | 0,394 |
| 0,3 a 0,4 | 9 | 3 | 0,290 | 0,416 | 0,487 |
| ≥ 0,4 | 20 | 20 | 1 | 1,000 | 1,000 |
| < 0,4, longe de surto | 899 | 11 | 0,0063 | 0,0166 | 0,0220 |
| < 0,4, vizinho de surto (≤ 2 min de um ≥ 0,4) | 41 | 12 | 0,193 | 0,487 | 0,511 |

* Todo o excesso está na faixa de 0,1 a 0,4: o modelo põe 2,8 vezes o canto
  da referência ali, e acerta as faixas acima de 0,4.
* O excesso é um fator quase constante (2,5 a 3 vezes) em todas as
  subfaixas e **tanto perto quanto longe dos surtos**. A razão vizinho/longe
  é a mesma no dado (31 vezes) e no modelo (29 vezes): a estrutura temporal
  reproduz o padrão relativo; o que está errado é o nível.
* ct03: nos minutos de 0,1 a 0,4, o modelo dá 0,35 a 0,74 onde a anotadora,
  que escolheu ouvindo, achou 0,65 a 0,88. A escolha enviesa para cima, então
  isso não contradiz o excesso; só mostra que os scores médios carregam
  pouca informação minuto a minuto (5 positivos do ct12 com posterior < 0,1).

Leitura (interpretação): um fator constante nas chances de canto, igual
perto e longe dos surtos, é o que se espera de uma razão f₁/f₀ inflada na
faixa de 0,1 a 0,4, não de estrutura temporal errada. Essa razão vem de 23
positivos nessa faixa (14 entre 0,1 e 0,2, onde f₀ é densa) e da forma
paramétrica (duas normais) das emissões. **Um HMM hierárquico de surtos não
ataca isso**: mexeria no padrão temporal, que já está certo, e manteria a
razão de emissões. O próximo teste é no estágio 1: emissões menos rígidas na
faixa média, por exemplo por faixas de score, com a razão f₁/f₀ por faixa
ancorada na precisão ponderada do ct12.

### Estágio 1 por faixas de score (21/11/2026)

`emissions_bins_curiango.R`: f₀ e f₁ constantes por faixa (< 0,1
censurado; 0,1–0,2; 0,2–0,3; 0,3–0,4; ≥ 0,4). No estágio 2 só a razão
f₁/f₀ por faixa importa. Os minutos com canto de cada faixa são a precisão
ponderada do ct12 na faixa vezes os minutos da faixa no depósito (a
referência pós-estratificada, faixa a faixa); f₁ sai desses minutos e f₀ do
resto do censo, com 0,5 por faixa. Uma primeira versão tirou f₁ da fração
ponderada dos positivos (`emissions_bins_pos.rds`, ajuste `binspos_m1`):
os 20 positivos ≥ 0,4 dão 0,45 de f₁ nessa faixa, onde os 1.756 minutos
(precisão 1) dão 0,53.

Estágio 2 (`run_curiango_2stage.R`, Markov, 4 cadeias de 1.000 + 1.000,
12 min): sem divergências, sem treedepth máximo, E-BFMI ≥ 0,96, R-hat
1,00, ESS bulk ≥ 2.500. `ppc_curiango_2stage.R` passou a aceitar emissões
por faixa: sorteia a faixa por f_w e reamostra o score entre os minutos do
depósito naquela faixa.

| Ajuste | ψ_c | θ̄ | ρ | Prevalência marginal (90%) |
|---|---|---|---|---|
| f₀ do censo, paramétrico (`census_m1`) | 0,39 | 0,138 | 4,67 | 0,057 (0,053 a 0,061) |
| faixas, f₁ dos positivos (`binspos_m1`) | 0,42 | 0,116 | 4,49 | 0,053 (0,049 a 0,057) |
| faixas, f₁ do censo (`bins_m1`) | 0,41 | 0,102 | 4,28 | **0,047 (0,043 a 0,050)** |
| Referência pós-estratificada | | | | 0,033 (0,027 a 0,039) |

Leave-one-out no ct12 com `bins_m1` (obs. contra pred.): 0,1–0,2: 0,013
contra 0,023; 0,2–0,3: 0,155 contra 0,332 (6 positivos em 32); 0,3–0,4:
0,29 contra 0,44 (3 em 9); longe de surto: 0,0063 contra 0,0097; vizinho de
surto: 0,19 contra 0,39. No depósito, o modelo põe 4.742 minutos com canto
contra 3.198 da referência; 1.427 deles nos 3.264 vizinhos de surto, onde a
precisão do ct12 indica cerca de 630.

PPC: P(y | anterior) passa (0,39 contra 0,38 a 0,42), a variância por noite
quase passa (10,3 contra 6,7 a 10,0); y_rate (0,018 contra 0,022 a 0,028)
e noites com algum score alto (0,25 contra 0,27 a 0,32) ainda acima.

Leitura (interpretação): as emissões por faixa tiram cerca de 40% do
excesso (de 0,057 para 0,047) e melhoram o agrupamento entre noites. O que
sobra (1,4 vez a referência) está sobretudo nos vizinhos de surto e nas
faixas de 0,2 a 0,4, onde a precisão do ct12 se apoia em 9 positivos. Este
ajuste usa emissões pontuais; a incerteza do estágio 1 (29 positivos
efetivos) ainda não foi propagada, e nas réplicas do bootstrap paramétrico
ela alargou o intervalo de 0,053–0,061 para 0,043–0,086. Próximo passo:
réplicas do bootstrap por noite do estágio 1 por faixas, como em
`boot_ct12`. Se o intervalo agrupado não alcançar a referência, o excesso
nos vizinhos de surto e o y_rate acima são o alvo de um HMM com surtos.

### Estágio 1 por faixas com bootstrap por noite (21/11/2026)

`emissions_bins_boot.R`: 20 réplicas do estágio 1 por faixas, com
sítio-noites do depósito inteiro sorteados com reposição (semente 2026); f₁
na faixa ≥ 0,4 varia de 0,43 a 0,60 entre réplicas. Cada réplica ajustada
no estágio 2 (Markov, 4 cadeias de 1.000 + 1.000, ~14 min cada, duas por vez
no Mac, ~2,5 h). Diagnósticos nas 20: nenhuma divergência, nenhum
treedepth máximo, R-hat máximo 1,003, ESS bulk mínimo 2.263. Entre réplicas,
ψ_c vai de 0,39 a 0,43, θ̄ de 0,074 a 0,122 e ρ de 3,7 a 4,5.

| | Prevalência marginal (90%) |
|---|---|
| Modelo, 20 réplicas agrupadas (200 draws cada) | **0,047 (0,038 a 0,056)** |
| Referência pós-estratificada | 0,033 (0,027 a 0,039) |
| Referência de Hájek simples | 0,026 (0,019 a 0,035) |

* Os intervalos de 90% se sobrepõem por 0,001 (0,038 a 0,039): pela letra
  do critério 1, passa.
* A mediana do modelo é 1,42 vez a referência; P(modelo > referência
  pontual) = 0,996 e, contra o bootstrap da referência, 0,98. Em 19 das 20
  réplicas a mediana fica acima de 0,039. A propagação do estágio 1 alargou
  o intervalo sem mover o centro (0,047 com emissões pontuais e agrupado).
* A comparação não é independente: o estágio 1 por faixas ancora f₁ na
  mesma precisão ponderada do ct12 que a referência usa. Mesmo assim, o
  estágio 2 devolve 1,4 vez o canto que entrou pelas emissões, o que aponta
  para o estágio 2 (vizinhos de surto, y_rate do PPC acima), não para o
  estágio 1.

Leitura (interpretação): a sobreposição vem do alargamento do intervalo, não
de concordância no centro. O critério 1 passa no limite; o viés de cerca de
+40% na prevalência de minutos parece real e se concentra perto dos surtos.

### Simulação com surtos: desenho (21/11/2026, fixado antes de rodar)

Pergunta: o excesso de cerca de +40% do v1 no Curiango vem do procedimento em
dois estágios (aconteceria mesmo com o modelo certo) ou de estrutura latente
que o v1 não tem (surtos)? Decidido com o Diogo testar isso por simulação
antes de construir um HMM com surtos. `sim_surtos_curiango.R`.

* **Estrutura fixa do Curiango:** os mesmos 1.753 sítio-noites, passos,
  lacunas (`adj`) e covariáveis de ψ e θ.
* **Emissões verdadeiras:** as do estágio 1 por faixas (`emissions_bins.rds`);
  dado w, a faixa de score de cada minuto é sorteada de f₁ ou f₀,
  independente entre minutos. Assim o v1 está certo nas emissões e só a
  estrutura latente pode estar errada.
* **Cenários (8 conjuntos cada):**
  - `v1`: gerado pelo próprio v1, com as medianas de `bins_m1` (controle do
    procedimento; também é uma parte do critério 2);
  - `het`: Markov com persistência variando entre sítio-noites,
    ρᵢ = ρ̄ + σuᵢ, uᵢ ~ N(0, 1), σ = 2 (noites de coro longo e noites de canto
    isolado);
  - `semi`: surtos com duração menos dispersa que a geométrica (1 + Poisson
    de média L − 1 passos), com pelo menos um passo sem canto entre surtos.
  `het` e `semi` são calibrados (Nelder–Mead, números aleatórios comuns)
  para reproduzir no score ≥ 0,4 do Curiango a taxa por minuto, P(y | y
  anterior), a fração de noites com algum y e a prevalência de 0,033 da
  referência pós-estratificada. A variância por noite fica como checagem.
  O v1 também é calibrado do mesmo jeito, só como diagnóstico: se não
  consegue reproduzir essas estatísticas com prevalência 0,033, isso já
  indica desajuste.
* **Rótulos:** sorteio estratificado por faixa com os tamanhos do ct12
  (439, 460, 32, 9, 20), pesos N_b/n_b; mais um conjunto que imita o ct03
  (43, 28, 16, 152 minutos nas faixas ≥ 0,1, com seleção que favorece canto
  na razão de 30 para 1). Os dois entram em v no estágio 2, como no
  Curiango; só o primeiro entra no estágio 1.
* **Procedimento:** estágio 1 por faixas (`emis_bins`) em cada conjunto,
  estágio 2 Markov com 4 cadeias de 500 + 500.
* **Alvo:** prevalência realizada (média de w) de cada conjunto. Mede-se o
  viés relativo da mediana da prevalência marginal, a cobertura do intervalo
  de 90% e, para comparação, o mesmo para a referência pós-estratificada
  calculada nos rótulos simulados.
* **Leitura combinada antes de rodar:** se `v1` sai sem viés e `het` ou
  `semi` reproduzem um excesso perto de +40%, o desajuste de surtos explica
  o Curiango, e o HMM se justifica. Se `v1` já sai com excesso, o problema é
  o procedimento, e o HMM não resolveria. Se nenhum cenário tem excesso, as
  duas hipóteses perdem força.
* **Custo:** 24 ajustes de ~6 min, dois por vez no Mac (8 núcleos), ~1,5 h.

**Adição depois da calibração, antes dos ajustes.** Médias de 10 simulações,
estatísticas do score ≥ 0,4:

| Gerador | Taxa por minuto | P(y \| y anterior) | Noites com algum y | Variância por noite | Prevalência |
|---|---|---|---|---|---|
| Curiango (prev. = referência) | 0,0180 | 0,394 | 0,253 | 10,3 | 0,033 |
| v1 com as medianas de `bins_m1` | 0,0247 | 0,405 | 0,294 | 8,2 | 0,047 |
| v1 calibrado | 0,0177 | 0,398 | 0,251 | 5,3 | 0,033 |
| `het` (σ = 2) | 0,0166 | 0,411 | 0,253 | 6,5 | 0,031 |
| `semi` (L = 4,3) | 0,0185 | 0,418 | 0,261 | 4,7 | 0,035 |
| `het2` (σ_ρ = 3,8) | 0,0177 | 0,425 | 0,235 | 8,9 | 0,033 |
| `hett` (σ_θ = 0,95) | 0,0179 | 0,414 | 0,232 | 8,3 | 0,033 |

O v1 calibrado reproduz taxa, dependência e noites com canto com prevalência
0,033; o que nenhum dos geradores fixados antes reproduz é a variância por
noite. O v1 ajustado ao Curiango chega a 8,2 subindo a prevalência para
0,047 (interpretação: parece trocar nível por dispersão). Por isso entraram
dois cenários calibrados também na variância por noite: `het2` (σ da
persistência livre) e `hett` (ρ comum e efeito de sítio-noite em θ,
N(0, σ)), 6 conjuntos cada. Total: 36 ajustes, ~2 h no Mac.

### Simulação com surtos: resultados (21/11/2026)

36 ajustes (4 cadeias de 500 + 500, ~6 min cada, dois por vez no Mac): sem
divergências, R-hat ≤ 1,011, ESS bulk ≥ 820. `sim_surtos_curiango.R resumo`.

| Cenário | Conjuntos | Viés relativo, modelo | Cobertura 90%, modelo | Viés relativo, referência | Cobertura 90%, referência |
|---|---|---|---|---|---|
| `v1` (controle) | 8 | 0,000 | 7/8 | +0,013 | 8/8 |
| `het` | 8 | +0,039 | 7/8 | +0,045 | 8/8 |
| `semi` | 8 | −0,013 | 8/8 | −0,032 | 8/8 |
| `het2` | 6 | +0,054 | 4/6 | +0,078 | 6/6 |
| `hett` | 6 | −0,010 | 6/6 | +0,011 | 6/6 |

* Nenhum cenário chega perto dos +40% do Curiango. Por conjunto, o viés do
  modelo vai de −9% a +13%.
* Razão modelo/referência pós-estratificada nos 36 conjuntos: 0,89 a 1,14
  (média 1,00). No Curiango é 1,42, fora do que qualquer conjunto simulado
  produziu. O erro do modelo acompanha o da referência (correlação 0,81),
  porque os dois se apoiam nos mesmos rótulos do ct12.
* O intervalo do modelo sem o bootstrap do estágio 1 é estreito (largura
  ~15% da verdade, contra ~40% da referência). Isso explica as coberturas
  de 4/6 a 7/8: o critério 2 vai precisar do bootstrap do estágio 1, como
  já previsto.

Leitura (interpretação): caiu o terceiro caso do desenho. Com as emissões
certas, o procedimento em dois estágios não infla a prevalência, e as
formas de desajuste latente testadas também não: surtos de duração menos
dispersa, persistência heterogênea e θ heterogêneo entre sítio-noites. Um
HMM de surtos ou com mais heterogeneidade entre noites provavelmente não
fecharia a diferença. O que todas as simulações mantêm certo, e o Curiango
pode violar, é o modelo de emissões: scores independentes dado w e f₁ igual
em todos os minutos com canto. O ajuste real prevê mais minutos ≥ 0,4 do
que os observados (PPC: 0,022 a 0,028 contra 0,018), o que nunca acontece
nas simulações. Isso é compatível com cantos de score mais baixo
concentrados perto dos surtos (f₁ que depende da posição no surto) ou com
scores dependentes entre minutos vizinhos dado w.

### Teste das emissões: independência dado w (21/11/2026)

`curiango_teste_emissoes.R`. No v1, dado w, a faixa de score de um minuto
não depende dos scores dos outros minutos. Então, nos verificados do ct12,
P(faixa | w, contexto) deve ser igual nos dois contextos, quando o contexto
depende só dos vizinhos: "surto" (algum minuto a até K passos, sem lacuna,
com score ≥ 0,4, sem contar o próprio) ou "longe". Pesos 1/π₁; bootstrap
por sítio-noite (2.000, semente 2026). Com K = 2 (K = 1 entre parênteses):

| | < 0,1 | 0,1–0,2 | 0,2–0,3 | 0,3–0,4 | ≥ 0,4 |
|---|---|---|---|---|---|
| w = 1, longe (16 positivos) | 0 | 0,34 | 0,39 | 0 | 0,27 |
| w = 1, surto (27 positivos) | 0 | 0,21 | 0,08 | 0,13 | 0,57 |
| w = 0, longe (888 negativos) | 0,47 | 0,50 | 0,02 | 0,01 | 0 |
| w = 0, surto (29 negativos) | 0,22 | 0,65 | 0,14 | 0 | 0 |

* **f₁ depende do contexto.** P(≥ 0,4 | w = 1): 0,57 perto de surto contra
  0,27 longe; diferença 0,30 (90%: 0,02 a 0,56; K = 1: 0,35, 0,05 a 0,59).
* **f₀ também.** Os negativos perto de surto têm scores mais altos: 0,79
  deles na faixa de 0,1 a 0,4 (90%: 0,63 a 0,91), contra 0,53 longe (0,49
  a 0,57), e só 0,22 abaixo de 0,1, contra 0,47 longe.
* Juntando: na faixa de 0,1 a 0,4, a razão f₁/f₀ perto de surto é
  exp(−0,93) ≈ 0,40 vez a de longe (90%: 0,21 a 0,71; K = 1: 0,38, 0,19 a
  0,74). Um score médio ao lado de um surto indica canto cerca de 2,5 vezes
  menos do que o mesmo score isolado.
* A referência pós-estratificada por faixa × contexto quase não muda:
  0,031 (90%: 0,026 a 0,036) contra 0,033 por faixa.
* ct03 (descritivo): há 4 negativos com score ≥ 0,4 (3 longe, 1 perto), o
  que o ct12 não mostrou; a precisão 1 na faixa alta é aproximada.

Os números são pequenos (27 positivos e 29 negativos verificados perto de
surto), mas as duas violações vão no mesmo sentido e os intervalos excluem
zero.

Leitura (interpretação): o v1 usa uma razão f₁/f₀ única por faixa, tirada
sobretudo de minutos longe de surto, e a cadeia de Markov já sobe a chance
a priori de canto ao lado de um surto. Perto de surto, a mesma razão conta
o contexto duas vezes: os minutos de score médio ali são em boa parte
negativos com score inflado (cauda do canto vizinho, outra espécie no mesmo
evento), não canto. Isso explica onde estava o excesso (1.427 minutos com
canto nos vizinhos de surto contra cerca de 630 pela precisão do ct12) e o
y_rate acima no PPC, e é compatível com a simulação, que mantinha as
emissões independentes e não reproduzia o viés. O conserto natural fica no
estágio 1 e não exige mudar o Stan, que já recebe log-emissões por minuto:
emissões por faixa × contexto. Usando só o minuto anterior como contexto,
p(sₙ | wₙ, sₙ₋₁), a verossimilhança continua própria (HMM autorregressivo);
usando os dois lados, vira verossimilhança composta.

### Estágio 1 por faixa × minuto anterior (21/11/2026)

`emissions_binsctx_curiango.R`: emissões p(bₙ | wₙ, cₙ), com cₙ = 1 quando o
minuto anterior (contíguo) tem score ≥ 0,4. A verossimilhança continua
própria (HMM autorregressivo) e o Stan não muda. A precisão por faixa ×
contexto vem de uma regressão logística ponderada (1/π₁) nos verificados do
ct12 de faixa média, y ~ faixa + contexto (contexto: +4,2 no logito, EP
0,95); 0 abaixo de 0,1 e 1 a partir de 0,4. As emissões implicam 3.456
minutos com canto (0,035). A razão f₁/f₀ nas faixas médias fica 0,69 a 0,79
vez menor depois de um minuto ≥ 0,4.

Estágio 2 (`binsctx_m1`, Markov, 4 cadeias de 1.000 + 1.000, 10 min): sem
divergências, sem treedepth máximo, E-BFMI ≥ 0,93, R-hat ≤ 1,002, ESS bulk
≥ 2.859. ρ = 4,06, ψ_c = 0,41, θ̄ = 0,104. `prev_marg_curiango.R` calcula a
prevalência marginal de qualquer ajuste; o PPC aceita as emissões novas.

| | `bins_m1` | `binsctx_m1` | Referência |
|---|---|---|---|
| Prevalência marginal (90%) | 0,047 (0,043 a 0,050) | 0,049 (0,046 a 0,052) | 0,033 (0,027 a 0,039) |
| Canto no depósito, 0,1 a 0,4 | ~3.000 | 3.170 | 1.348 (Hájek por faixa) |
| Canto nos vizinhos de surto | 1.427 | 1.335 | ~630 |
| LOO, vizinho de surto (obs. 0,19) | 0,39 | 0,36 | |
| LOO, longe (obs. 0,0063) | 0,0097 | 0,0112 | |
| PPC y_rate (obs. 0,018) | 0,022 a 0,028 | 0,021 a 0,028 | |
| PPC P(y \| anterior) (obs. 0,39) | 0,38 a 0,42 | 0,41 a 0,45 | |

O contexto pelo minuto anterior não fecha nada: a prevalência sobe um pouco,
o excesso nas faixas médias e perto dos surtos fica, e o PPC piora em P(y |
anterior).

Leitura (interpretação): a correção no estágio 1 é fraca (razão 0,7 a 0,8
contra os 0,4 do teste com os dois lados), porque o minuto anterior vê só
metade da vizinhança e porque a regressão aditiva põe o efeito do contexto
na precisão, que o estágio 2 já reproduz pela cadeia. O problema parece
estar na conta do estágio 2: para gerar o agrupamento observado dos scores
altos (P(y | anterior) = 0,39; 56,7% com vizinho alto, não 98,7%) com f₁(≥ 0,4) ≈ 0,5
independente entre minutos, o modelo precisa de sequências de canto longas
(ρ ≈ 4: P(canto | canto anterior) ≈ 0,86, contra ~0,68 pela precisão do
ct12 nos minutos depois de um score alto), e essas sequências passam pelos
minutos de score médio em volta. No dado, o agrupamento dos scores altos
parece vir em parte da persistência do próprio score dentro do canto (o
nível do score se mantém de um minuto para o outro), não só da duração do
canto. A simulação não tinha isso. Um modelo que separe as duas coisas
precisaria de emissões com dependência dentro do canto, por exemplo f₁(b |
faixa anterior) só para minutos com canto, o que exige rótulos de minutos
vizinhos que o ct12 quase não tem (sorteio aleatório).

### Validação por noite: v1 contra fp_occu() com limiar (21/11/2026)

Alvo do v1 redefinido com o Diogo: ocupação por sítio-noite, como os outros
modelos do crywolf (estático, multiespécie e dinâmico). A prevalência de
minutos deixa de ser o alvo. `curiango_validacao_noite.R`.

Noites G+: 16 sítio-noites sem nenhum minuto ≥ 0,4 e com canto confirmado
por ouvido (13 do ct03, 3 do ct12; score máximo de 0,20 a 0,39). Os dois
modelos foram reajustados sem os 29 rótulos dessas noites:
* v1 de dois estágios, emissões por faixa, Markov (`validacao_noite/v1`,
  10 min): sem divergências, R-hat ≤ 1,003, ESS ≥ 3.087; ψ_c = 0,39,
  prevalência marginal 0,046. As emissões usaram o ct12 inteiro, com 3
  positivos de noites G+ (vazamento pequeno);
* `fp_occu()` do crywolf instalado, limiar 0,40, `markov = "time"`, a
  especificação do `ind_mk` da vinheta dynamic (22 min): sem divergências,
  R-hat ≤ 1,008, ESS ≥ 886.

| P(ocupada) média | n | v1 | fp_occu |
|---|---|---|---|
| noites com algum score ≥ 0,4 | 444 | 0,996 | 0,593 |
| G+ (rótulos removidos) | 16 | 0,260 | 0,055 |
| outras noites sem score alto | 1.293 | 0,141 | 0,023 |
| ocupação média no depósito | 1.753 | 0,358 | 0,168 |
| piso: fração de noites com score ≥ 0,4 | | 0,253 | |

* **Discriminação das G+ entre as noites sem score alto: empate.** AUC 0,75
  (v1) contra 0,78 (fp_occu); entre as de máximo 0,2 a 0,4, 0,71 contra
  0,81. O v1 dá às G+ 1,8 vez a média das outras; o fp_occu, 2,4 vezes,
  num nível muito mais baixo. Nenhum dos dois recupera bem essas noites.
* **A diferença de ψ vem das noites com score alto.** O fp_occu dá 0,22
  às 201 noites com um único minuto ≥ 0,4 (o v1, 0,99) e 0,36 às noites
  com score alto e só negativos verificados (o v1, 0,99). Sua ocupação
  média (0,168) fica abaixo do piso de 0,253.
* **Precisão dos minutos altos isolados, pelos verificados:** com vizinho
  alto, 119 de 119 positivos; isolados em noites com outros altos, 36 de
  39; únicos na noite, 13 de 14 (todos do ct03, escolhido ouvindo, então
  enviesado para cima). Um minuto ≥ 0,4 isolado é quase sempre canto.

Leitura (interpretação): o teste das G+ não separa os modelos; os dois só
sobem um pouco a chance de noites com scores médios. O que separa é o
tratamento das detecções altas. No `ind_mk`, uma detecção depois de
lacuna é ambígua (fp_gap = 2,86: p₁₀ ≈ p₁₁ ≈ 0,04 após lacuna), e cada
minuto verificado negativo entra como uma visita do método verificado
que não detectou (p_verified = 0,70), o que derruba a ocupação de noites
com detecções reais. Os rótulos do Curiango são minutos sorteados, não
visitas de um especialista ao sítio: o modelo de verificação do crywolf
parece não servir para esse desenho. O v1 usa os rótulos como w conhecido
no minuto, que é o que eles são, e dá ψ acima do piso. Essa comparação não
mostra que o v1 acerta ψ (não há referência por desenho para a noite), mas
mostra que o limiar com o modelo de verificação atual erra para baixo de
um jeito que os verificados contradizem. Fica como achado para a sessão do
crywolf (sem mexer no repositório daqui).

### Simulação de ψ: desenho (21/11/2026, fixado antes de rodar)

Pergunta: as violações das emissões achadas no Curiango enviesam ψ, agora
que o alvo do v1 é a ocupação por sítio-noite? `sim_psi_curiango.R`.

* Estrutura fixa do Curiango. Canto latente do v1 (Markov), com ψ, θ e ρ
  partindo das medianas de `bins_m1` e calibrados. Faixas de score pelas
  emissões por faixa (`emissions_bins.rds`).
* Cenários:
  - `ind`: faixas independentes dado w (controle);
  - `pers`: num minuto com canto logo depois de outro com canto, a faixa
    repete a anterior com probabilidade κ, senão sai de f₁ (a marginal de
    f₁ não muda);
  - `pers0`: `pers`, e os minutos sem canto a até 2 passos de um minuto
    com canto na faixa ≥ 0,4 tiram a faixa da distribuição ponderada dos
    negativos do ct12 perto de surto (0,215; 0,64; 0,135; 0,01; 0).
* Calibração (Nelder–Mead, números aleatórios comuns) nos scores ≥ 0,4 do
  Curiango: taxa, P(y | anterior), fração de noites com algum y, fração de
  minutos altos com vizinho alto (0,567), fração de noites com um único
  minuto alto (0,115), e a prevalência 0,033 da referência
  pós-estratificada. Parâmetros: deslocamento de ψ, de θ, ρ e κ.
* Rótulos como na simulação com surtos (ct12 estratificado por faixa, ct03
  com chance 30:1 para canto). Estágio 1 por faixas nos rótulos simulados,
  estágio 2 com Markov, 4 cadeias de 500 + 500.
* 8 conjuntos por cenário (24 ajustes, ~1,2 h no Mac, dois por vez).
* Estimando: ψ médio sobre os sítio-noites, logit⁻¹(Xβ). Medidas: viés da
  mediana (absoluto e relativo) e cobertura de 90%. Sem bootstrap do
  estágio 1, a cobertura sai otimista; ela fica para a AWS se o viés for
  pequeno.
* O mesmo resumo de ψ é aplicado aos 36 conjuntos da simulação com surtos
  (desajuste latente), que já guardam o deslocamento de ψ.
* Leitura combinada antes: viés de ψ ≤ 0,05 (absoluto) em `pers` e
  `pers0` → as violações das emissões não comprometem ψ, e o passo
  seguinte é a cobertura com bootstrap na AWS. Viés maior → o v1 precisa
  de emissões com dependência antes de ir ao crywolf.

### Simulação de ψ: resultados (21/11/2026)

Calibração (média de 10 simulações): os três geradores ficam perto do
Curiango em y_rate (0,016 contra 0,018), P(y | anterior) (0,37 a 0,38
contra 0,39), minutos altos com vizinho alto (0,58 a 0,59 contra 0,567) e
noites com um único minuto alto (0,097 a 0,099 contra 0,115), mas passam
na fração de noites com algum minuto alto (0,30 a 0,32 contra 0,25).
`ind`: ρ = 4,63, ψ̄ = 0,56. `pers` e `pers0` (os mesmos parâmetros, porque
a f₀ perto de surto não mexe nos scores ≥ 0,4): κ = 0,51, ρ = 2,94,
ψ̄ = 0,44.

24 ajustes (4 cadeias de 500 + 500): sem divergências, R-hat ≤ 1,01, ESS
bulk ≥ 766. `sim_psi_curiango.R resumo`.

| Cenário | ψ̄ verdadeiro | Viés absoluto de ψ̄ | Viés relativo | Cobertura 90% | ρ estimado | Modelo / referência (minutos) |
|---|---|---|---|---|---|---|
| `ind` | 0,560 | −0,012 | −2,1% | 6/8 | 4,54 | 1,02 (0,92 a 1,07) |
| `pers` | 0,441 | −0,009 | −2,0% | 7/8 | 3,10 | 1,00 (0,94 a 1,05) |
| `pers0` | 0,441 | −0,007 | −1,6% | 6/8 | 3,46 | 1,04 (0,96 a 1,15) |

Por conjunto, o viés absoluto de ψ̄ vai de −0,047 a +0,026. A cobertura
sem o bootstrap do estágio 1 sai abaixo de 0,90, como esperado.

ψ̄ nos 36 conjuntos da simulação com surtos (mesmo resumo):

| Cenário | ψ̄ verdadeiro | Viés absoluto | Cobertura 90% |
|---|---|---|---|
| `v1` | 0,369 | +0,002 | 7/8 |
| `het` | 0,499 | +0,004 | 7/8 |
| `semi` | 0,362 | −0,014 | 6/8 |
| `het2` | 0,467 | −0,023 | 6/6 |
| `hett` | 0,488 | **−0,162** | 0/6 |

* **As violações das emissões não enviesam ψ.** Persistência do score
  dentro do canto e f₀ elevada perto de surto: viés ≤ 0,01 em média e
  ≤ 0,05 em todo conjunto. Pelo critério fixado, passa.
* **O que enviesa ψ é θ heterogêneo entre sítio-noites (`hett`):** −0,16
  (−33%), em todos os conjuntos. É o problema clássico de heterogeneidade
  de detecção em ocupação: noites ocupadas com pouco canto parecem vazias.
  No Curiango, o efeito aleatório da data (noite de calendário, comum aos
  sítios) em θ estimou σ = 0,32 (seção de 13/11), bem abaixo do σ = 0,95
  de `hett`. Um efeito por sítio-noite, que é o de `hett`, se confunde
  com z e não é identificável com estes dados.
* Nenhum gerador reproduz o excesso de minutos do Curiango (1,42): aqui a
  razão fica entre 0,92 e 1,15. A causa da prevalência de minutos inflada
  continua sem explicação completa; para ψ ela parece não importar.

Leitura (interpretação): para o alvo de ocupação, o v1 resiste às
violações das emissões que vimos no Curiango, e a fraqueza que aparece é
a de qualquer modelo de ocupação, a heterogeneidade de detecção. Próximos
passos: (i) cobertura de ψ com o bootstrap do estágio 1 (AWS), que é o
critério 2 reescrito; (ii) medir quanto da heterogeneidade de θ entre
sítio-noites as covariáveis e um efeito de sítio (7 sítios) explicam, já
que o efeito por sítio-noite não é identificável; (iii) FrogNet.

### Cobertura de ψ: desenho (22/11/2026, fixado antes de rodar)

Critério 2 reescrito para o alvo de ocupação. `run_simpsi_boot.R` na AWS.

* Os mesmos geradores calibrados da simulação de ψ (`ind`, `pers`,
  `pers0`), agora em `sim_psi_core.R`. Os conjuntos 1 a 8 de cada cenário
  são idênticos aos já ajustados (conferido nos rótulos e na prevalência).
* **50 conjuntos por cenário** (erro-padrão de Monte Carlo da cobertura
  perto de 0,04) × **10 réplicas** do estágio 1 por conjunto: sítio-noites
  do depósito sorteados com reposição, estágio 1 por faixas na réplica e
  emissões aplicadas a todos os minutos, como em `emissions_bins_boot.R`.
  Cada réplica ajustada no estágio 2 com Markov, 2 cadeias de 500 + 500.
  Por conjunto, os 10.000 draws de ψ̄ das réplicas são agrupados.
* 1.500 ajustes, ~7 min cada num núcleo (medido no Mac): ~175 h de CPU.
  Uma c7a.32xlarge spot com 128 workers, ~1,5 a 2 h, limite de 4 h; custo
  estimado de US$ 3 a 6.
* Estimando: ψ̄, a média de logit⁻¹(Xβ) sobre os sítio-noites. Medidas por
  cenário: viés da mediana, cobertura de 90% e de 95%, largura.
* **Critério:** cobertura de 90% ≥ 0,85 (0,90 menos ~1 erro-padrão de
  Monte Carlo) e |viés| ≤ 0,05 nos três cenários, e nenhum ajuste com
  divergências em mais de 5% das tarefas. Passa → falta o critério 3
  (FrogNet). Cobertura baixa com viés pequeno → o intervalo precisa de
  outra fonte de incerteza (por exemplo, mais réplicas ou a incerteza dos
  rótulos). Viés grande → volta para as emissões.
* Fora do desenho: θ heterogêneo entre sítio-noites (`hett`), que já
  mostrou viés de −0,16 sem precisar de cobertura.

### Cobertura de ψ: resultados (22/11/2026)

Rodada `simpsi-boot-1` na AWS (c7a.32xlarge spot, 128 workers), em duas
partes: a primeira parou no limite de 3 h com 918 tarefas; a segunda,
com limite de 4 h, retomou e terminou as 1.500 (cerca de 29 min por
ajuste na instância, contra ~7 min no Mac). `summarise_simpsi_boot.R`:

| Cenário | Conjuntos | ψ̄ | Viés (EP) | Cob. 90% (EP) | Cob. 95% | Largura 90% |
|---|---|---|---|---|---|---|
| `ind` | 50 | 0,560 | −0,009 (0,004) | 0,88 (0,05) | 0,96 | 0,11 |
| `pers` | 50 | 0,441 | 0,006 (0,003) | 0,94 (0,03) | 0,98 | 0,07 |
| `pers0` | 50 | 0,441 | −0,004 (0,002) | 0,94 (0,03) | 0,94 | 0,06 |

* Nenhuma tarefa com erro e nenhuma com divergências. R-hat > 1,01 em 183
  das 1.500 tarefas (12%), com ESS mínimo de 298: as cadeias curtas
  (500 + 500) bastam para ψ̄, mas um ajuste final deve usar mais
  iterações.
* Entre réplicas do estágio 1, o desvio-padrão de ψ̄ (0,009 a 0,023) é da
  mesma ordem que o de dentro de cada ajuste (0,016 a 0,025): o bootstrap
  do estágio 1 responde por um quarto a metade da variância de ψ̄
  (26% em `pers0`, 46% em `ind`), e sem ele o intervalo ficaria estreito
  demais (interpretação minha, não testada sem o bootstrap).
* **O critério passa nos três cenários** (cobertura de 90% ≥ 0,85,
  |viés| ≤ 0,05, divergências em menos de 5% das tarefas). O critério 2,
  para ψ̄, está cumprido; falta o critério 3 (FrogNet).

## Critério para levar o v1 de dois estágios ao crywolf (20/11/2026)

Decidido com o Diogo: o v1 fica em `dev/fase2` até cumprir os três
critérios abaixo. Cumpridos, o pedido vai à sessão do crywolf como
`fp_occu_score()` experimental. Não se mexe no `~/GitHub/crywolf` daqui.

1. **Concordância com a referência por desenho:** a prevalência marginal do
   modelo e a referência de Hájek (com bootstrap por sítio-noite) têm
   intervalos de 90% que se sobrepõem, no Curiango ct01+ct02. *Situação em
   20/11: reprova (0,043 a 0,086 contra 0,019 a 0,035). Em 21/11, com
   f₀ do censo e com 3 estados, continua reprovando. A referência passa a
   ser a pós-estratificada por faixa de score, 0,033 (0,027 a 0,039); o
   modelo com f₀ do censo dá 0,057 (0,053 a 0,061), e com emissões por
   faixa 0,047 (0,043 a 0,050), ainda fora, sem propagar o estágio 1.
   Com as 20 réplicas do estágio 1 por faixas: 0,047 (0,038 a 0,056),
   sobreposição de 0,001 com a referência; passa no limite, com a mediana
   1,4 vez a referência (P(modelo > referência) = 0,98).*
2. **Cobertura do procedimento em dois estágios:** uma simulação com o
   estágio 1 ponderado, o bootstrap por noite e o estágio 2 com réplicas
   cobre ψ, θ̄ e ψθ̄, pelas regras V1/V2 da validação do v1.
   *Situação em 22/11: cumprido para ψ̄ (o alvo do v1), na rodada
   `simpsi-boot-1`: cobertura de 90% de 0,88 a 0,94 e |viés| ≤ 0,01 nos
   três cenários, sem divergências.*
3. **Segundo conjunto:** o procedimento funciona na rodada aleatória do
   FrogNet (com o Massao), com convergência, PPC e o critério 1.
