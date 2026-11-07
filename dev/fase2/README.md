# Fase 2: protótipo do modelo conjunto score–ocupação

Protótipo fora do pacote (`dev/` está no `.Rbuildignore`). A migração para
o `fp_occu_score()` do crywolf vem depois de validado. Leia antes
`dev/dag/NOTAS-fase2.md` e a fase 2 de `dev/roadmap-integration.md`.

**Objetivo (definido pelo Diogo em 05/11/2026, recebido pela sessão do
crywolf):** o modelo de score deve dispensar a escolha do limiar. Ganhar em
elpd não é necessário; basta chegar à mesma inferência sem ninguém escolher
um limiar.

## Arquivos

| Arquivo | O que é |
|---|---|
| `model_v0.stan` | programa do v0: um score por ocasião, z e w marginalizados |
| `score_emissions.stanfunctions` | emissões, à parte, no formato de `fp_emissions.stanfunctions` do crywolf |
| `v0.R` | simulador, log-verossimilhança de referência em R e Miller |
| `check_v0.R` | conferências; `Rscript dev/fase2/check_v0.R [recovery]` |
| `run_val_v0.R` | validação em simulação; `Rscript dev/fase2/run_val_v0.R OUT_DIR [N_WORKERS] [N_REPS]` |
| `summarise_val_v0.R`, `diagnose_val_v0.R` | resumo pelos critérios e decomposição das reprovações; recebem `OUT_DIR` |
| `run_diag_v0.R` | reajustes do diagnóstico do critério 1; `Rscript dev/fase2/run_diag_v0.R OUT_DIR [N_WORKERS]` |
| `run_val2_v0.R` | segunda validação; `Rscript dev/fase2/run_val2_v0.R OUT_DIR [N_WORKERS]` |
| `summarise_diag_v0.R` | compara os reajustes com os ajustes originais; recebe `OUT_DIR` |
| `results/diag_v0/refit_all.rds` | os 38 reajustes do diagnóstico; serve de `OUT_DIR` para `summarise_diag_v0.R` |
| `results/val_v0/task_all.rds` | os 1.020 ajustes da validação; serve de `OUT_DIR` para os dois scripts |
| `probe_cell_v0.R`, `summarise_probe_v0.R`, `probe_same_sets_v0.R` | investigação da célula que reprovou, por máxima verossimilhança |
| `results/probe_v0/ml_all.rds` | os 8.000 conjuntos da sonda, com as emissões livres e fixas |
| `results/val2_v0/task_all.rds` | os 720 ajustes da segunda validação; serve de `OUT_DIR` para os dois scripts |
| `prior_check_v0.R` | prior predictive check das emissões |
| `run_cell_v0.R` | repetição da célula que reprovou; `Rscript dev/fase2/run_cell_v0.R OUT_DIR [N_WORKERS] [N_SETS]` |
| `summarise_cell_v0.R` | resumo da repetição; `Rscript dev/fase2/summarise_cell_v0.R OUT_DIR [VAL2_DIR]` |
| `results/cell_v0/task_all.rds` | os 160 ajustes da repetição, com a máxima verossimilhança |
| `results/val3_v0/task_all.rds` | os 720 ajustes da terceira validação (prior C); serve de `OUT_DIR` para `summarise_val_v0.R` |
| `curiango_v0.R` | dados do Curiango no formato do v0 |
| `emissions_curiango_v0.R`, `emissions_family_curiango.R` | etapa 0: normal censurada por classe nos minutos verificados e comparação com mistura, por noite |
| `selection_curiango.R` | inclusão dos minutos verificados por score e estimativas ponderadas |
| `run_curiango_v0.R`, `ppc_curiango_v0.R` | piloto base do v0 no Curiango e seus PPC |
| `model_mix.stan`, `score_emissions_mix.stanfunctions`, `mix.R`, `check_mix.R`, `probe_mix.R` | modelo com mistura em f₀ e f₁, ainda sem justificativa firme (ver a correção) |
| `emissions_weighted_curiango.R` | etapa 0 com pesos de inclusão, provisória, e inclusão por hora e sítio |
| `aws/` | execução em spot; `dev/fase2/aws/launch.sh BUCKET RUN [TIPO] [WORKERS] [HORAS] [PREÇO]` |

## Modelo v0

z_i ~ Bernoulli(ψ_i); w_ik | z_i ~ Bernoulli(z_i θ_ik); s_ik | w_ik normal
no logit, com μ_1 = λ_0 + Δ, Δ > 0 e σ_0 ≠ σ_1. O score é censurado abaixo
de c (registro do classificador) e acima de c_hi (scores colados em 1).
Verificações por ocasião entram em v_ik, como em `recordings_verified` e nos
clipes do Curiango, que são o minuto inteiro. Sem Markov e sem covariáveis
no score. Os priors de λ_0, Δ, σ_0 e σ_1 vêm do prior predictive check abaixo.

## Conferências feitas (05/11/2026)

| Conferência | Resultado |
|---|---|
| log-verossimilhança por sítio, R × Stan, em cada draw | diferença máxima 6,6e-07 |
| score dicotomizado, Stan × Miller em R, em cada draw (comparação de log-verossimilhança, não de posteriores) | diferença máxima 4,9e-07 |
| Miller em R × `unmarked::occuFP`, no ótimo | −1558,333 nos dois |

Sanidade, **não é validação** e rodou antes dos critérios abaixo: 5
conjuntos simulados (150 sítios × 20 ocasiões, 5% verificado, ao acaso),
R-hat máximo 1,005, ESS mínimo 939, sem divergências, médias perto dos
valores simulados. Cinco conjuntos não medem cobertura. Essa simulação usa
a forma verdadeira de f₀ e f₁ e não diz nada sobre dados reais.

## Critérios (escritos antes das simulações de validação)

Limiares aprovados pelo Diogo em 05/11/2026. Os itens 1 a 3 seguem
`dev/dyn-val/README.md` do crywolf. Cobertura de intervalos de 95%; viés na
escala de probabilidade.

| # | Critério | Limiar |
|---|---|---|
| 1 | Convergência | por célula, ao menos 95% dos ajustes com R-hat < 1,01 e sem divergências |
| 2 | Calibração de ψ e θ | cobertura ≥ 0,90 e viés absoluto ≤ 0,05 |
| 3 | Espécie rara (θ baixo, poucos positivos verificados) | relatado como limite; não bloqueia |
| 4 | Insensibilidade a c | ao variar c, ψ e θ mudam ≤ 0,05 em simulação e no Curiango. Se mudarem mais, o limiar só mudou de lugar. c só pode subir a partir do `min_conf` registrado |
| 5 | Faixa de limiares | no Curiango, ψ, γ e ε do modelo de score ficam a ≤ 0,05 dos do melhor limiar do `fp_occu_dyn()`, numa varredura de limiares. O modelo não recebe a informação de que a vinheta usa `conf_custom >= 0.40` |
| 6 | Forma de f₀ e f₁ | PPC da distribuição do score por classe nos clipes revisados, antes de confiar em θ; sem vereditos a mistura se identifica sobretudo pela forma assumida |
| 7 | Dois classificadores | critério do roadmap: a diferença entre eles nos coeficientes de ocupação fica menor que entre MaxF1 e MaxPrecision |

## Validação do v0 em simulação (desenho fixado antes de rodar)

`run_val_v0.R`, 150 sítios × 20 ocasiões, ψ = 0,5 no centro da covariável,
λ_0 = −4, σ_0 = σ_1 = 1,5. Cada conjunto simulado é ajustado nos três cortes
c = logit(0,1), logit(0,3), logit(0,5), com os mesmos scores, de modo que a
comparação entre cortes é pareada. 30 conjuntos por combinação nas células
principais e 10 nas de limite, para caber em cerca de 2 horas (340 conjuntos,
1.020 ajustes).

| Fator | Níveis |
|---|---|
| θ no centro da covariável | 0,6; 0,3; 0,1 |
| fração verificada, ao acaso | 0,20; 0,05; 0 |
| classificador (Δ) | 5 (bom); 3 (fraco) |

- **Células principais (critérios 1 e 2):** θ ∈ {0,6; 0,3} e verificação
  ∈ {0,20; 0,05}, em cada Δ e c. Viés e cobertura de ψ = logit⁻¹(β_0) e
  θ = logit⁻¹(α_0), agrupando as 30 réplicas de cada célula e, para a
  decisão, os três cortes de cada combinação θ × verificação × Δ (90
  ajustes, erro-padrão da cobertura perto de 0,02).
- **Limites (critério 3, não bloqueiam):** θ = 0,1, ou sem verificação.
- **Critério 4:** média, por combinação, de |diferença pareada| das médias
  posteriores de ψ e θ entre c = logit(0,1) e cada corte maior, que deve ser
  ≤ 0,05. O percentil 95 também é relatado.
- As inclinações β_1 e α_1 são relatadas, mas não entram na decisão.
- Limitação: os dados vêm da mesma forma normal que o modelo assume, e não
  há Markov. Passar aqui não diz nada sobre o critério 6.

## Resultado da validação do v0 (05/11/2026)

340 conjuntos, 1.020 ajustes, nenhum erro; cerca de 54 horas de CPU. **O v0
não passa nos critérios como escritos:** reprova no 1 e, por pouco, no 2.
Nada aqui avalia os critérios 5, 6 e 7, que dependem do Curiango.

| # | Resultado nas células principais | Situação |
|---|---|---|
| 1 | células com ≥ 95% aprovados: 7 de 8 em c = logit(0,1); 2 de 8 em logit(0,3); 0 de 8 em logit(0,5) (melhor célula 0,77; pior 0,23) | reprova |
| 2 | viés absoluto máximo 0,023; cobertura ≥ 0,90 em 13 de 16 combinações, 0,878 nas outras 3 | viés passa, cobertura reprova |
| 4 | maior média de \|diferença pareada\|: ψ 0,047 e θ 0,041; o percentil 95 chega a 0,117 em ψ | passa |

**Critério 1.** Em logit(0,5), 61% dos ajustes com Δ = 3 e 26% com Δ = 5 têm
divergências (até 7,4% das transições), com R-hat até 1,14 e ESS mínimo 21.
Nos cortes mais baixos não há nenhuma divergência; as reprovações são de
R-hat, que não passa de 1,02. Os parâmetros com pior R-hat são sobretudo σ_0,
Δ e λ_0. A largura do intervalo de λ_0 sobe de cerca de 0,5 em logit(0,1) para
cerca de 5 em logit(0,5).

Interpretação, não testada: com λ_0 = −4 e σ_0 = 1,5, a fração de scores da
classe falsa acima do corte é 11,5%, 1,8% e 0,4% nos três cortes, então o
modelo vê apenas a cauda de f₀, e λ_0 e σ_0 ficam mal identificados. Nesse
regime o prior provisório deve pesar. ψ e θ não sofrem porque dependem da
cauda, não da posição de f₀.

**Critério 2.** As três combinações com 0,878 têm 5% de verificação: ψ com
θ = 0,3 e Δ = 3; ψ com θ = 0,6 e Δ = 5; θ com θ = 0,3 e Δ = 5. Correção ao
desenho: os três cortes usam os mesmos dados, então o erro-padrão da cobertura
é cerca de 0,05, calculado por conjunto, e não 0,02. As falhas vêm de 5 ou 6
dos 30 conjuntos de cada combinação. Esse desenho não separa 0,878 de 0,90 nem
de 0,95. A cobertura geral é 0,95 para ψ e 0,94 para θ, e quase não muda entre
ajustes aprovados e reprovados no critério 1.

**Critério 3 (limites, não bloqueia).** Sem verificação e com Δ = 3, θ fica
inflado: viés +0,25, +0,13 e +0,08 para θ = 0,1, 0,3 e 0,6, enquanto o viés de
ψ fica em até 0,012. Com 5% de verificação, o viés de θ não passa de 0,012 nas
células com θ = 0,1. Com θ = 0,1 e Δ = 3, ψ depende de c mesmo com 20% de
verificação (mudança média de 0,05 a 0,08), o que limita o uso em espécies
raras com classificador fraco.

**Inclinações (relatadas).** Nas células principais, viés de −0,07 e −0,04 em
β_1 e de +0,03 e +0,02 em α_1 (Δ = 3 e 5), com cobertura de 0,93 a 0,95. Nos
limites com Δ = 3, viés de −0,24 e +0,27.

## Diagnóstico do critério 1 (desenho fixado antes de rodar)

Pergunta: as reprovações nos cortes altos são de amostragem ou de
identificação? `run_diag_v0.R` reajusta ajustes reprovados com os mesmos dados
e a mesma semente, mudando só o amostrador: `adapt_delta = 0,95` e 1000+1000
iterações. Por combinação principal, entram os reprovados de menor id: 2 em
logit(0,3) e 3 em logit(0,5), até 40 ajustes. As duas mudanças vão juntas, então
o diagnóstico não separa o efeito de cada uma. A amostra só tem casos difíceis
e não estima a taxa de aprovação da grade.

Regra de leitura, com os critérios originais (R-hat < 1,01 e sem divergências):

- **Amostragem:** ≥ 95% dos reajustes aprovados em cada corte. Refazer a grade
  com esse amostrador.
- **Identificação:** menos de 80% aprovados em logit(0,5), ou divergências
  persistentes com Δ = 3. Decidir entre prior informativo para f₀ e limitar
  quanto c pode subir.
- **Intermediário:** entre os dois, olhar por corte e por Δ antes de decidir.

### Resultado do diagnóstico (06/11/2026)

38 reajustes, nenhum erro; `summarise_diag_v0.R` compara com os originais. Todos
tinham reprovado no original.

| Corte | Δ | Reajustes | Aprovados | Com divergências | R-hat máximo |
|---|---|---|---|---|---|
| logit(0,3) | 3 | 7 | 7 | 0 | 1,00 |
| logit(0,3) | 5 | 7 | 7 | 0 | 1,01 |
| logit(0,5) | 3 | 12 | 11 | 1 | 1,02 |
| logit(0,5) | 5 | 12 | 7 | 4 | 1,01 |

Pela regra fixada: **logit(0,3) é amostragem** (14 de 14) e **logit(0,5) é
identificação** (18 de 24, ou 75%, abaixo de 80%). Das 6 reprovações, 5 têm
divergências (1 a 14 em 4.000 transições) e 1 tem só R-hat de 1,011. As
divergências caíram de 19 para 5 dos 24 ajustes em logit(0,5).

- O amostrador mais rígido quase não muda ψ e θ: diferença média de 0,001 e
  máxima de 0,004. As reprovações do critério 1 não estavam deslocando essas
  estimativas. Por isso os reajustes não mudam a cobertura do critério 2.
- O intervalo de λ_0 e Δ continua com largura perto de 5,8 em logit(0,5), o que
  é coerente com identificação fraca, e não só com amostragem.
- **Limitação:** escolher pelos menores ids trouxe casos leves. Os ajustes
  selecionados tinham até 24 divergências e R-hat até 1,02, enquanto na grade
  chegaram a 148 e 1,14. Os piores casos de logit(0,5) não foram testados, então
  75% provavelmente é otimista para esse corte.
- O custo por ajuste sobe de 3 a 5 vezes (mediana perto de 430 s em logit(0,3) e
  1.500 s em logit(0,5), com a máquina dividida com outros jobs).

## Segunda validação do v0 (desenho fixado antes de rodar)

Decisão do Diogo em 06/11/2026, depois do diagnóstico: c fica limitado a no
máximo logit(0,3), e logit(0,5) passa a ser limite relatado, não critério.
Isso muda o escopo dos critérios 1 e 4; os limiares não mudam. No Curiango,
`min_confidence = 0.1` (`dev/benchmarks/curiango-export.R`), igual ao padrão de
`export_occupancy_data()`, então c = logit(0,1) é o valor de uso.

`run_val2_v0.R`, só células principais, c = logit(0,1) e logit(0,3),
`adapt_delta = 0,95` e 1000+1000 iterações. Os conjuntos 1 a 30 são os mesmos
dados da primeira validação (mesmos ids). As células com 5% de verificação
ganham 30 conjuntos novos, 60 no total, para decidir a cobertura. São 360
conjuntos e 720 ajustes.

- **Critério 1:** por célula e corte, ≥ 95% com R-hat < 1,01 e sem divergências.
- **Critério 2:** viés absoluto ≤ 0,05 e cobertura ≥ 0,90, agrupando os dois
  cortes de cada combinação θ × verificação × Δ. O erro-padrão é calculado por
  conjunto, porque os cortes usam os mesmos dados.
- **Critério 4:** média de |diferença pareada| entre logit(0,1) e logit(0,3)
  ≤ 0,05.

## Resultado da segunda validação

Rodada em 06/11/2026: 360 conjuntos, 720 ajustes, 0 erros, cerca de 35 h de CPU.
A rodada caiu uma vez em 175 conjuntos, por causa da compactação da conversa, e
foi retomada; o `seed` vem do id, então os ajustes não mudam.

- **Critério 1: passa.** As 16 combinações de célula e corte ficam em ≥ 95%
  (mínimo 0,967, n = 30). Só 2 dos 720 ajustes reprovam, ambos em logit(0,3) e
  com Δ = 3: um com 2 divergências, outro com R-hat ≥ 1,01 em σ₀. ESS mínimo 929.
- **Critério 2: reprova em 1 de 16.** O viés passa (máximo 0,020). A cobertura
  fica ≥ 0,90 em 15 de 16; a exceção é θ com θ = 0,6, 5% de verificação e Δ = 3:
  0,883 (EP por conjunto 0,03). Dos 3 casos de 0,878 da primeira validação, dois
  sumiram com os 30 conjuntos novos; este não, e os conjuntos novos pioraram:
  em logit(0,1), 0,90 nos conjuntos 1 a 30 e 0,80 nos 31 a 60 (0,85 nos 60).
  Em logit(0,3), 0,917.
- **Critério 4: passa.** Máximo de 0,032 (θ) e 0,021 (ψ); p95 até 0,075.

A falha da célula é assimétrica em logit(0,1): 7 intervalos acima de θ e 2
abaixo, com viés +0,019 e RMSE 0,042. Somando as células principais, a cobertura
de θ em logit(0,1) é 0,922 (EP 0,014), abaixo do nominal; a de ψ é 0,950. Em
logit(0,3) ficam em 0,942 e 0,956. A investigação está na seção seguinte.

Em logit(0,3), as emissões ficam bem menos informadas, com ψ e θ preservados:
largura do intervalo de λ₀ e Δ em torno de 2,5, contra 0,6 em logit(0,1), e viés
de −0,22 e +0,20. Mesma identificação fraca de f₀ do diagnóstico.

## Investigação da célula que reprovou (06/11/2026)

Sem Stan, com máxima verossimilhança em `loglik_v0`, em c = logit(0,1):
`probe_cell_v0.R` usa 1.000 conjuntos novos por célula, com as emissões livres e
fixas na verdade; `probe_same_sets_v0.R` usa os mesmos conjuntos da grade e
compara par a par com as médias posteriores. O intervalo é de Wald, no logit.

Modelo e simulador coincidem, e a largura dos intervalos não é o problema: na
célula, o desvio-padrão de θ̂ é 0,037 e a largura implica 0,035.

| θ = 0,6, 5%, Δ = 3 | viés | cobertura |
|---|---|---|
| Verossimilhança, 1.000 conjuntos novos | +0,001 (EP 0,001) | 0,938 |
| Verossimilhança, os 60 conjuntos da grade | +0,011 (EP 0,005) | 0,933 |
| Stan, os 60 conjuntos da grade | +0,019 | 0,850 |

Os +0,019 se dividem em duas partes:

- **+0,011 é da amostra.** A verossimilhança erra igual nesses 60 conjuntos, e
  esse viés some em 1.000 conjuntos. A verossimilhança não tem viés nessa célula.
- **+0,008 é do Stan em relação à verossimilhança**, e é sistemático: +0,008 também
  com θ = 0,3 e Δ = 3, contra +0,001 com Δ = 5. Não foi separado se vem dos priors
  das emissões, ainda provisórios, ou da assimetria da posterior (média contra
  moda).

Fixar as emissões na verdade não muda a cobertura de forma importante: ela fica
perto de 0,95 nos dois casos. Dentro da célula, o erro de θ̂ acompanha o de μ₁
(r = −0,78) e o de σ₁ (r = +0,60), como esperado, porque θ depende de quanto de
f₁ cai abaixo de c. Isso descreve a variação entre conjuntos, não o viés médio.

Leitura: o critério 2 segue reprovado como foi fixado, mas a cobertura de 0,85
parece em boa parte azar da amostra. Extrapolando da verossimilhança, um
deslocamento de 0,008 a 0,009 daria cobertura perto de 0,93 nessa célula; isso é
inferência, não foi medido com MCMC em muitos conjuntos. Para o passo 3: definir
os priors por prior predictive check e repetir essa célula, medindo o
deslocamento em relação à verossimilhança.

## Prior predictive check das emissões (07/11/2026)

`prior_check_v0.R`, sem dados: cada sorteio do prior dá as duas distribuições de
score, e lemos o que elas implicam sobre um classificador. A região plausível
foi escrita no script antes de ver a saída, sem usar os valores simulados nem
dados reais: falsos acima de 0,5 em até 30%; verdadeiros acima de 0,5 em ao menos
20%; AUC entre 0,6 e 0,999; verdadeiros saturados acima de 0,9999 em até 30%;
falsos no piso abaixo de 0,0001 em até 50%. Não fixei antes uma fração mínima
de sorteios dentro da região, então ela serve para comparar, não para aprovar.

| Prior | Dentro da região | AUC (5%, 50%, 95%) | Saturados (p95) | Piso (p95) | P(Δ < 1) |
|---|---|---|---|---|---|
| A: provisório, λ_0 N(−3, 3), Δ N⁺(0, 5), σ N⁺(0, 3) | 0,33 | 0,53; 0,83; 1 | 0,38 | 0,33 | 0,16 |
| B: λ_0 N(−3, 2), Δ N⁺(0, 4), σ N⁺(0, 1,5) | 0,31 | 0,55; 0,94; 1 | 0,02 | 0,05 | 0,20 |
| **C: λ_0 N(−3, 2), Δ LN(log 3, 0,6), σ LN(log 1,2, 0,5)** | 0,43 | 0,69; 0,95; 1 | 0,03 | 0,05 | 0,03 |
| D: λ_0 N(−3, 1,5), Δ LN(log 4, 0,5), σ LN(log 1,2, 0,4) | 0,52 | 0,80; 0,99; 1 | 0,04 | 0,01 | 0,003 |

**Escolha: C.** Tira a massa de A em scores saturados e no piso, e afasta Δ e σ
de zero, onde as componentes não se identificam. D fica mais dentro da região,
mas quase exclui classificadores fracos (AUC de 5% em 0,80), o que seria
pressupor o que queremos medir. A escolha é julgamento, não saída de uma regra.
O `prior_emissions` do Stan seleciona o prior: 0 é A, 1 é C. `simulate_v0()` usa
1 por padrão, então os scripts das validações anteriores precisam de
`prior_emissions = 0L` para reproduzir aqueles resultados.

## Repetição da célula (desenho fixado antes de rodar)

`run_cell_v0.R`: θ = 0,6, 5% de verificação, Δ = 3, c = logit(0,1), prior C,
`adapt_delta = 0,95` e 1000+1000 iterações. Conjuntos 1 a 60 são os dados da
grade, e 61 a 160 são novos (EP da cobertura perto de 0,02). Cada conjunto também
tem a máxima verossimilhança. Piloto de 5 conjuntos: cerca de 200 s por conjunto,
sem divergências, R-hat máximo 1,003, ESS mínimo 1.566.

- **Critério 2:** viés absoluto ≤ 0,05 e cobertura ≥ 0,90, em θ e ψ, nos 160
  conjuntos. A cobertura dos conjuntos 1 a 60 também é relatada, para comparar
  com os 0,85 do prior A.
- **Deslocamento:** média de θ posterior menos θ de máxima verossimilhança, com
  EP entre conjuntos, nos conjuntos 1 a 60 (prior A: +0,008) e nos 160. O mesmo
  com a mediana posterior: se média e mediana diferirem pouco e o deslocamento
  cair, o prior era a causa; se não cair, sobra a assimetria da posterior.
- **Limite:** mudar o prior invalida, em rigor, os resultados da segunda
  validação. Passar nesta célula não aprova as outras 15 combinações.

### Resultado (07/11/2026)

`summarise_cell_v0.R`, 160 conjuntos: sem divergências, R-hat máximo 1,006, ESS
mínimo 1.428, máxima verossimilhança convergiu em todos.

**O critério 2 passa nesta célula.** Viés e cobertura de θ e ψ com intervalos de 95%:

| Conjuntos | θ: viés (EP) | θ: cobertura | ψ: viés | ψ: cobertura |
|---|---|---|---|---|
| 1 a 160 | +0,011 (0,003) | 0,931 | +0,001 | 0,950 |
| 1 a 60 (os da grade) | +0,017 (0,005) | 0,867 | +0,001 | 0,950 |
| 61 a 160 (novos) | +0,007 (0,003) | 0,970 | +0,001 | 0,950 |

- A cobertura de 0,931 tem EP de 0,020 e fica no valor que a seção anterior
  extrapolou. Dos 11 intervalos que erram θ, 9 ficam acima e 2 abaixo: a assimetria
  continua.
- **A falha veio sobretudo da amostra.** Com os mesmos 60 conjuntos, a cobertura
  mal muda com o prior (0,85 no A, 0,867 no C; 2 ganhos, 1 perda). Os 100 conjuntos
  novos dão 0,970. Os conjuntos 1 a 60 entraram aqui porque reprovaram, então os
  160 ainda carregam essa seleção; o número sem seleção é o dos novos.
- **O prior explica só parte do deslocamento.** Nos 60 conjuntos, `plogis` da
  média de α menos a verossimilhança foi de +0,0078 (prior A) para +0,0060
  (prior C), diferença pareada de −0,0017 (EP 0,0001). Nos 160, +0,0059 (EP 0,0001).
- **A assimetria da posterior também explica só parte.** Na escala de θ, nos 160:
  média +0,0053 (EP 0,0001), mediana +0,0040 (EP 0,0001).
- A regra fixada antes de rodar previa uma causa ou a outra, e o resultado não
  cabe nela: o deslocamento caiu cerca de 22%, a diferença entre média e mediana é
  de 0,0013, e sobram +0,004 na mediana. Uma leitura possível, não testada, é que a
  posterior marginal integra as emissões e a verossimilhança as maximiza junto com
  θ. O deslocamento é pequeno diante do limite de 0,05 e do desvio-padrão de θ̂
  (0,037), então não bloqueia o protótipo.

Continua valendo o limite acima: as outras 15 combinações não foram refeitas com o
prior C. A verossimilhança teve viés de +0,005 e cobertura de 0,956 nestes 160.

## Terceira validação, com o prior C (desenho fixado antes de rodar)

Mesma grade e mesmos critérios da segunda validação (`run_val2_v0.R`: 360
conjuntos, 720 ajustes), agora com o prior C, em `results/val3_v0`. Os dados são
os mesmos, porque a semente é o id do conjunto e o prior não entra na simulação.
Roda na AWS com `aws/launch.sh`: uma instância c7a.16xlarge spot, 64 workers,
limite de 2 h por instância e preço máximo de US$ 1,30/h.

Como os 60 conjuntos da célula θ = 0,6, 5%, Δ = 3 são os mesmos, ela deve repetir
perto de 0,87 em logit(0,1). O número da grade será relatado, mas a decisão do
critério 2 nessa célula fica com os 160 conjuntos da seção anterior.

### Resultado da terceira validação (07/11/2026)

360 conjuntos, 720 ajustes, 0 erros, 37,4 h de CPU. A instância rodou 42 min, sem
interrupção, a cerca de US$ 0,97/h: perto de US$ 0,70, estimado pelo preço spot
do lançamento. Resultados em `results/val3_v0/task_all.rds`, lidos por
`summarise_val_v0.R`.

- **Critério 1: passa.** 100% em todas as células e cortes, sem divergências,
  R-hat máximo 1,008, ESS mínimo 1.042. Na segunda validação, 2 dos 720 reprovavam.
- **Critério 2: 15 de 16 na grade.** O viés passa (máximo 0,017). A exceção é a
  esperada: θ com θ = 0,6, 5%, Δ = 3 ficou em 0,892 (0,867 em logit(0,1) e 0,917 em
  logit(0,3)). Pela regra fixada antes de rodar, essa célula se decide nos 160
  conjuntos da repetição (0,931), que só cobrem logit(0,1). Três combinações
  passam por pouco, com n = 30 ou 60 conjuntos: ψ com θ = 0,6, 5%, Δ = 5 (0,900),
  θ com θ = 0,3, 20%, Δ = 3 (0,900) e ψ com θ = 0,3, 5%, Δ = 3 (0,908).
- **Critério 4: passa.** Máximo de 0,032 (θ) e 0,021 (ψ); p95 até 0,071.

Isso resolve o limite das seções anteriores: o prior C agora está validado na grade
inteira. A validação vale para dados simulados pelo próprio modelo v0, sem Markov.

## Plano do passo do Curiango (07/11/2026, a aprovar)

O que este passo responde: o modelo de score chega à mesma inferência sem ninguém
escolher um limiar, nos dados reais? Os dados são públicos (`crywolf::curiango`).

### O que os dados mostram antes de ajustar

97.806 minutos, 1.753 sítio-noites, 7 sítios, 98% dos intervalos de 15 min. São
1.199 minutos verificados (1,2%), 257 positivos. **Eles não são uma amostra
aleatória em relação ao score: ver a correção abaixo.** Na escala logit, sem pesos:

| Classificador | AUC | Falsos abaixo de 0,1 | Falsos acima: q10, q50, q90 | Verdadeiros abaixo de 0,1 | Verdadeiros acima: q10, q50, q90 |
|---|---|---|---|---|---|
| próprio | 0,965 | 46,6% | −2,16, −1,96, −1,45 | 0% | −1,67, 0,58, 2,90 |
| BirdNET | 0,947 | 95,5% | −2,06, −1,21, 0,21 | 7,8% | −1,80, −0,35, 3,33 |

Consequências:

- **A grade validada não cobre estes dados.** Ela usou σ₀ = σ₁ = 1,5, 150 sítios
  × 20 ocasiões e ao menos 5% verificado. No classificador próprio, a máxima
  verossimilhança dá σ₀ = 0,54 e σ₁ = 1,70. Há mais verificações em número (1.199
  contra 150), mas em fração bem menor.
- **O prior C fica apertado em σ₀.** 0,54 cai perto do percentil 5 de
  lognormal(log 1,2; 0,5). Com esse volume de dados deve pesar pouco, mas é preciso
  conferir (posterior contra prior).
- **f₀ do BirdNET é vista só pela cauda.** Só 42 dos 942 falsos passam de 0,1, e a
  normal ajustada fica em μ₀ = −7,4 e σ₀ = 3,05, longe do prior.

### Resultado da etapa 0 (07/11/2026): a normal censurada reprova

`emissions_curiango_v0.R` e `emissions_family_curiango.R`, sem Stan, só nos 1.199
minutos verificados, com 30% das noites retidas. **A etapa 1 não rodou**, porque a
condição para seguir era a normal descrever o classificador próprio.

| Ganho de log score retido, mistura de 2 normais menos normal (50 partições por noite) | Média | Intervalo de 95% das partições | Partições com ganho |
|---|---|---|---|
| próprio, falsos | +27,0 | 7,1 a 62,4 | 98% |
| próprio, verdadeiros | +6,7 | −1,7 a 14,0 | 92% |
| BirdNET, falsos | −0,2 | −4,3 a 0,0 | 66% |
| BirdNET, verdadeiros | +7,7 | 0,1 a 15,8 | 98% |

- **f₁ do classificador próprio tem dois grupos:** cerca de 25% perto de −1,5
  (σ 0,41) e o resto perto de 1,2 (σ 1,42). A normal prevê 1% a 12% de verdadeiros
  abaixo de 0,1, e nenhum dos 257 ficou lá. Chamadas distantes ou fracas explicariam
  o grupo baixo, mas isso é interpretação; não foi testado.
- **f₀ do classificador próprio tem cauda pesada:** mesma média (−2,17), com σ de
  0,33 em 87% e 1,22 em 13%. A cauda importa, porque são os falsos de score alto.
- **O grupo baixo de f₁ se sobrepõe a f₀.** Fora dos minutos verificados, um score
  perto de −1,5 pode ser qualquer um dos dois. Separar isso depende dos 1.199
  minutos, e é a questão de identificação da família nova.
- No BirdNET, os 42 falsos acima do corte não permitem preferir uma forma de f₀.

### Correção: a verificação depende do score (07/11/2026)

Os resultados da etapa 0 acima estão sob suspeita. A inclusão nos minutos verificados
é de 1,1% abaixo de 0,5 no classificador próprio e de 11,5% a partir daí: 162
minutos verificados contra 15 esperados. O efeito não vem do número de linhas por
minuto (abaixo de 0,4, a taxa fica em 1% com qualquer número de linhas) nem só do
BirdNET (`selection_curiango.R`). O mecanismo não está documentado no depósito; a
descrição de "cerca de 1% ao acaso", em `dev/benchmarks/curiango-export.R` e em
`data-raw/curiango.R` do crywolf, não bate com os dados.

Pesando pelo inverso da inclusão em dois estratos, o que é aproximado porque o
mecanismo é desconhecido:

| Quantidade | Sem pesos | Com pesos |
|---|---|---|
| Minutos com chamada | 0,214 | 0,107 |
| Precisão no limiar 0,4 | 0,977 | 0,949 |
| Recall no limiar 0,4 | 0,654 | 0,211 |
| Mediana dos verdadeiros (logit) | 0,58 | −1,20 |

- **Os dois grupos de f₁ parecem ser em boa parte efeito da seleção.** Com pesos,
  78% dos verdadeiros ficam entre −2 e 0, e a cauda direita é longa. A vantagem da
  mistura precisa ser refeita com pesos, então **a simulação de identificação da
  mistura fica suspensa**.
- **Continua valendo:** nenhum dos 439 minutos verificados abaixo de 0,1 tem chamada, e
  esse estrato é o de inclusão de 1%.
- **O modelo conjunto:** se a seleção depende só do score observado, a verossimilhança
  não precisa de pesos (inferência, falta simular). Os PPC por classe, sim, porque
  replicam sem a seleção.
- **Fora daqui:** o que tratou esses minutos como amostra aleatória pode estar
  afetado: `inclusion_prob` do export, recall e os verificados do crywolf. Precisão
  condicional ao score é bem menos sensível. Falta avaliar.

### O que o artigo diz e etapa 0 com pesos (07/11/2026)

O artigo do Curiango descreve o conjunto de teste como cerca de 1% dos arquivos, com
o número por sítio proporcional às gravações de cada sítio. Não menciona score nem
hora. Os dados não batem com isso em três pontos:

- **Score:** inclusão de 1,05% abaixo de 0,3, 2,85% entre 0,3 e 0,5 e 11,5% acima.
- **Hora, mesmo abaixo de 0,3:** cerca de 1,6% entre 18 h e 22 h, 0,9% de 0 h a 5 h,
  0,5% às 16 h, 17 h e 23 h, e 0,1% às 6 h (p ≈ 1e-36).
- **Sítio, abaixo de 0,3:** de 0,79% a 1,42% (p = 0,0006).

Vazamento do treino do classificador próprio não explica sozinho: ele foi treinado
com clipes do mesmo conjunto de gravações, mas o enriquecimento aparece também nos
scores do BirdNET, que não usa esse treino. Se a seleção dependeu do estado real (por
exemplo, de ouvir o minuto antes de incluir) e não só do score, a verossimilhança
conjunta também é afetada. **Quem sabe o procedimento é a Liliana; falta perguntar.**
As sessões do crywolf e do FrogNet não têm informação sobre o mecanismo. Pela
avaliação do crywolf, não testada: positivos verificados seguem válidos; negativos
verificados pesam demais e podem baixar ψ um pouco; p10 e p11 vêm sobretudo dos
dados automáticos; o `raw_fp` da vinheta do Curiango fica superestimado. Checagem
sugerida: refazer o ajuste só com os verificados de score abaixo de 0,3.

Com pesos em três estratos de score, sem corrigir a hora, e por isso provisório, a
normal ainda perde para a mistura nas 50 partições por noite:

| Classe | n efetivo | Ganho médio | Intervalo de 95% das partições | Partições com ganho |
|---|---|---|---|---|
| falsos | 936 | +7,4 | −2,9 a 15,0 | 94% |
| verdadeiros | 120 | +15,3 | 4,7 a 26,2 | 100% |

Muda a forma: em f₁, 78% ficam perto de −1,45 e 22% perto de 0,91, o inverso do que
parecia sem pesos. Em f₀, a mistura é só uma cauda moderada (σ 0,26 e 0,61). A
simulação de identificação continua suspensa até saber como o teste foi sorteado; os
valores de `em_curiango` em `mix.R` vêm do ajuste sem pesos e precisam ser trocados.

### Piloto base do v0 (07/11/2026)

Classificador próprio, c = logit(0,1), 4 cadeias, 17,6 min, sem divergências, R-hat
1,00, ESS mínimo 2.881. ψ no centro 0,43 (0,40 a 0,46), θ no centro 0,136 (0,13 a
0,14), λ₀ = −2,16, Δ = 1,29, σ₀ = 0,35, σ₁ = 1,49. Isso implica 0,069 de minutos com
chamada, contra 0,107 pela estimativa ponderada.

O PPC global reprova: P(y = 1 | minuto anterior com y = 1) é 0,39 contra 0,07 a 0,09
replicado; a variância de detecções por noite é 10,3 contra 4,5 a 5,7; as noites com
detecção são 25% contra 36% a 42%. É a dependência entre minutos esperada sem Markov.

Um teste de recuperação da mistura, com um único conjunto simulado, convergiu em 11
min e alargou o componente baixo de f₁ (σ 0,57 contra 0,41). Um conjunto não mede viés.

### Etapas

| # | Etapa | Onde | Duração estimada | Segue se |
|---|---|---|---|---|
| 0 | Preparar os dados (`curiango_v0.R`) e ajustar f₀ e f₁ só nos 1.199 minutos, sem Stan: critério 6 preliminar, com partição por noite | Mac | minutos | a normal censurada descreve o classificador próprio |
| 1 | Piloto do v0: um ajuste do classificador próprio em logit(0,1). Medir tempo, diagnósticos e PPC por classe e de autocorrelação entre minutos | Mac, 4 núcleos | ~15 a 40 min por cadeia (extrapolado de 113 s × 33) | R-hat e ESS adequados; falha esperada só na autocorrelação |
| 2 | v1 com Markov em w, dentro da noite, só quando o minuto anterior está a 15 min. Conferir log-verossimilhança R × Stan e redução ao v0; simulação com σ₀, σ₁, tamanho e verificação do Curiango | Mac e AWS | a medir | passa nos critérios 1 e 2 nessa simulação |
| 3 | Covariáveis: θ ~ bio + aci, ψ ~ temp_d + rh_d, e temperatura em f₀ e f₁ (**g**_ik), pelo achado de sheepdog#67 | Mac | a medir | o efeito de temperatura reaparece |
| 4 | Ajustes finais: dois classificadores × c = logit(0,1) e logit(0,3); os quatro caminhos com limiar na mesma especificação; k-fold | AWS | ~100 h de CPU, ~US$ 2 a 4 (a refazer depois do piloto) | critérios abaixo |

### Critérios nesta etapa

- **4:** ψ e θ mudam ≤ 0,05 entre logit(0,1) e logit(0,3).
- **5:** o v1 tem ψ estático por sítio-noite, então a comparação é com `ind_mk`
  (`fp_occu()` com Markov) numa varredura de limiares. γ e ε ficam de fora: exigem
  compor com a cadeia entre noites, que é outro modelo.
- **6:** PPC do score por classe nos minutos verificados. Se reprovar no classificador
  próprio, troca-se a família de f₀ e f₁ antes de qualquer outra etapa.
- **7:** a diferença entre classificadores nos coeficientes de ocupação fica menor que
  entre MaxF1 e MaxPrecision. É o critério que decide se a fase vale um artigo.
- **k-fold:** mesmos blocos de 7 noites de `dev/dyn-kfold`. O elpd do crywolf é de y
  binário e o do modelo de score é de s contínuo, logo não se comparam direto. A
  comparação usa a probabilidade que o modelo de score dá a y = 1 no limiar 0,40.

### Referências e limites

No crywolf, o Markov foi o maior ganho nesses dados (elpd +481,3, EP 120,1, de `dyn_mk`
sobre `dyn`; PPC sem Markov com p = 0), então a falha do v0 no PPC de autocorrelação
não seria defeito do modelo de score. `dyn` fica 191,5 acima de `ind`: as noites têm
dinâmica entre si, e o modelo estático deixa isso de fora; `ind_mk` fica 206,9 abaixo
de `dyn_mk`. Se o modelo de score valer, o passo seguinte é compor com o `fp_occu_dyn()`.
