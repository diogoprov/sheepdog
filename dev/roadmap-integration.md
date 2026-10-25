# Roadmap: integração sheepdog + crywolf

Escrito em 24/10/2026, com a `main` do sheepdog em `7e9c785` (3.2.1,
candidata ao CRAN) e o crywolf em `c9e2287` (1.7.0.9000, a caminho do 2.0.0).
É um plano, não uma decisão: os itens **[decidir]** dependem do Diogo. Vale
para os dois repositórios; uma cópia (ou um link) deve ir para
`crywolf/dev/`.

## Objetivo

Hoje o fluxo tem três etapas em sequência: score do BirdNET → limiar ou
calibração (sheepdog) → histórico binário → modelo de ocupação (crywolf ou
spOccupancy). A incerteza se perde em cada etapa, e o resultado depende de
escolhas que o modelo não enxerga. O objetivo é **um caminho único, do
score à ocupação, com a incerteza propagada**, em que:

- o sheepdog é a camada de **medição**: desenho da validação com
  probabilidades de inclusão conhecidas, revisão, calibração e proveniência;
- o crywolf é a camada de **processo**: ocupação (depois dinâmica e
  multiespécies) com um modelo de observação que usa os scores e as
  verificações;
- os dois continuam independentes (nenhum importa o outro); a ligação é um
  **contrato de dados** documentado nos dois pacotes.

## Por que agora: o que o artigo do Curiango mostrou

O artigo do Curiango, aceito no JAV (ms JAV-03737) [CITAR: referência
completa quando sair; dados em https://doi.org/10.5281/zenodo.21795898],
analisou os mesmos 97.906 minutos de áudio por quatro caminhos (dois
classificadores × dois limiares) e três estruturas de modelo. Cinco
resultados dele motivam este roadmap diretamente:

1. **O limiar e o classificador pesaram mais que o modelo.** A ocupação
   predita em temperaturas baixas diferiu em mais de 65 pontos percentuais
   entre os caminhos PreBuilt–MaxF1 e Custom–MaxPrecision. É o argumento
   mais forte para tirar o limiar do caminho (fases 1 e 2).
2. **O trade-off precisão × recall não tem solução dentro do paradigma do
   limiar.** MaxPrecision quase zera o p10 mas descarta dados e alarga os
   intervalos; MaxF1 retém dados mas exige o modelo com falsos positivos. A
   recomendação do artigo ("priorizar a precisão em modelos hierárquicos")
   é a melhor possível com limiar; um modelo que usa todos os scores pode
   torná-la desnecessária. Esta é a hipótese central a testar (fase 2).
3. **Detecções de score alto podem ser um subconjunto não aleatório**, cuja
   detectabilidade varia com o ambiente (seção de resultados do artigo). No
   modelo conjunto, isso vira um parâmetro: a distribuição dos scores
   condicionada às covariáveis.
4. **As janelas de uma noite não são independentes**, e todos os PPC de
   sítio falharam por isso; o modelo dinâmico foi descartado como
   "computacionalmente proibitivo" para mais de 1.700 noites. O termo de
   Markov do crywolf já trata a dependência dentro da noite, e o forward de
   dois estados planejado para o `fp_occu_dyn()` custa linear no número de
   noites; o Curiango é o caso de teste natural dos dois.
5. **O efeito da lua deve agir na intensidade do canto, não no "cantou ou
   não"** (discussão do artigo). Pede uma resposta de atividade vocal
   (densidade de chamadas), não binária (fase 4).

Além disso, o Curiango tem o conjunto de validação ideal para a fase 2: 1.199
arquivos (~1 % do total) anotados por completo, sorteados com estratificação
proporcional por sítio. É o equivalente ao `sampling_mode =
"random_recordings"` do sheepdog e identifica as distribuições de scores dos
verdadeiros e dos falsos positivos sem depender do classificador.

## Estado (25/10/2026)

- Fase 0 feita: `export_occupancy_data()` (sheepdog#36) e `fp_read_sheepdog()`
  (crywolf 1.9.0, doi:10.5281/zenodo.23624712).
- Fase 1 em andamento: `fp_draws_data()` e `fp_occu_mc()` no crywolf; o
  Curiango exportado (sheepdog#38 e #39) é o caso de teste. A primeira rodada
  foi descartada por dois artefatos do export, corrigidos no #39.
- Sensores com inferência embarcada: a recomendação de guardar uma amostra
  probabilística do áudio bruto está na vinheta `sampling-designs`.

## Prioridades

| Prioridade | Fase | Pacote | Esforço | Depende de |
|---|---|---|---|---|
| 1 | 0. Contrato de dados | os dois | P–M | — |
| 2 | 1. Propagação Monte Carlo da calibração | os dois | P | fase 0 |
| 3 | 2. Modelo conjunto score–ocupação | crywolf | G | fase 0; crywolf 2.0.0 **[decidir]** |
| 4 | 3. Validação em duas camadas | sheepdog (+ crywolf) | M | fase 2 |
| 5 | 4. Atividade vocal (densidade de chamadas) | crywolf | M–G | fase 2 |
| 6 | 5. Comunidade | crywolf | G | roadmap do crywolf (MSO, Fase A) |

Em paralelo a tudo: o benchmark (seção própria), que decide se cada fase
vale a pena.

O roadmap do crywolf congela a API no 1.9/2.0 e põe depois o dinâmico e,
em seguida, o multiespécies. Nada aqui muda a API congelada: o que é novo
entra em funções novas. **[decidir]** Onde a fase 2 entra na fila do
crywolf: antes do dinâmico (é o que o Curiango pede primeiro), depois dele
ou dentro dele (`fp_occu_dyn()` já com scores).

No sheepdog, a 3.2.1 vai para o CRAN como está; as fases 0, 1 e 3 entram
como funções novas numa 3.3.0 (sem quebra).

## Fase 0: contrato de dados

**Problema.** Hoje o crywolf lê o `validation_by_clip.csv`
(`fp_read_validation()`) e as tabelas do BirdNET (`fp_read_birdnet()`) e
reconstrói as ocasiões com `fp_aggregate()`. Ficam de fora: as
probabilidades de inclusão e o modo de amostragem de cada clipe, a ocasião
dos clipes `random_recordings`, o consenso entre revisores, a calibração e a
proveniência. O crywolf também precisa avisar que só aceita clipes
sorteados independentemente do score; com o contrato, isso pode ser checado
nos dados em vez de documentado.

**Proposta.** Um conjunto de tabelas longas em CSV (legíveis fora do R),
num diretório com um `schema.json` que traz o nome e a versão do esquema
(`sheepdog-occupancy`, versão 1). O sheepdog escreve; o crywolf lê. Nenhum
pacote importa o outro.

| Tabela | Uma linha por | Colunas principais |
|---|---|---|
| `occasions.csv` | ocasião (arquivo ou minuto) | `site`, `occasion_id`, `night`, `start`, `duration`, `recorder`, covariáveis de ocasião |
| `scores.csv` | ocasião × espécie | `occasion_id`, `species_code`, `max_score`, `n_windows`, `n_above_min` (número de janelas com score ≥ `min_confidence`); scores abaixo de `min_confidence` são censurados e o valor de corte vai no `schema.json` |
| `detections.csv` (opcional) | janela com score ≥ `min_confidence` | `occasion_id`, `species_code`, `window_start`, `score` |
| `validation.csv` | clipe revisado | `occasion_id`, `species_code`, `window_start`, `verdict` (`TRUE`/`FALSE`/`NA`), `sampling_mode`, `inclusion_prob`, `stratum`, `reviewer`, `consensus` |
| `recordings_verified.csv` | ocasião anotada por completo | `occasion_id`, `species_code`, `present` (o caso `random_recordings`: o estado da ocasião, não de um clipe) |
| `sites.csv` | sítio (ou sítio-noite) | `site`, covariáveis |
| `calibration_draws.csv` (opcional) | draw × sítio × espécie × ponto da grade | saída de `grid_draws()` com `engine = "brms"`, para a fase 1 |
| `schema.json` | — | versão do esquema, versões do sheepdog e do classificador, `min_confidence`, `extraction_info` |

Decisões embutidas, a conferir:

- **`max_score` por ocasião** é a estatística suficiente mínima para os
  modelos de Rhinehart et al. (2022) e de Ogawa et al. (2025) no nível da
  ocasião. Guardar as janelas (`detections.csv`) deixa aberta a fase 4.
- **Veredito de clipe ≠ estado da ocasião.** Um positivo prova que houve
  canto na ocasião; um negativo no clipe de maior score não prova ausência
  (pode haver canto com score menor). O contrato separa `validation.csv`
  (clipes) de `recordings_verified.csv` (ocasiões anotadas por completo),
  e os modelos tratam os dois de forma diferente.
- **`inclusion_prob` e `sampling_mode` sempre presentes.** São o que permite
  ao crywolf recusar ou ponderar uma amostra que dependa do score (fase 2,
  "ignorabilidade").

| Passo | Pacote | Pronto quando |
|---|---|---|
| Especificação do esquema em `inst/schema/sheepdog-occupancy-v1.md`, a mesma nos dois pacotes | os dois | revisada pelo Diogo |
| `export_occupancy_data()`: monta e escreve as tabelas a partir das tabelas do BirdNET, do manifesto e das validações | sheepdog | ida e volta sem perda no exemplo do pacote; `occasion_id` igual ao de `select_clips()` |
| `fp_read_sheepdog()`: lê o diretório, confere a versão do esquema e devolve `occasions`/`detections`/`validation` no formato de `fp_aggregate()` e `fp_data()` | crywolf | com limiar fixo, o `fp_data` sai idêntico ao do caminho atual (`fp_read_birdnet()` + `fp_read_validation()` + `fp_aggregate()`) |
| Recusar ou avisar quando `validation` vem de `sampling_mode = "top"` | crywolf | teste com os três modos |
| Fixture compartilhada: um diretório pequeno gerado pelo sheepdog, copiado para `crywolf/tests/testthat/` | os dois | os testes dos dois pacotes leem o mesmo arquivo; um script em `data-raw/` refaz a cópia |
| Exportar o Curiango no esquema | dev | o benchmark das fases 1 e 2 lê só o diretório |
| `fp_to_unmarked()` (acrescentado em 25/10/2026): converte o objeto do `fp_read_sheepdog()` num `unmarked::unmarkedFrameOccuFP`, com as gravações anotadas de ouvido como método certo e as ocasiões automáticas (score >= limiar) como método incerto, para quem quer o `occuFP()` frequentista em vez do Stan | crywolf | o `occuFP()` ajusta o exemplo; com os mesmos dados, as estimativas ficam próximas das do `fp_occu()` com a priori fraca |

## Fase 1: propagação Monte Carlo da calibração

O caminho mais barato para tirar o limiar fixo, usando o que já existe.
`history_draws()` (sheepdog, `engine = "brms"`) dá um histórico por draw
da posterior da calibração. O crywolf ajusta o modelo em *M* históricos e
junta as posteriores, como na propagação por Monte Carlo de Monchy et al.
(2026, preprint). Não é inferência conjunta (a calibração não aprende com a
ocupação), mas mede quanto a incerteza da calibração pesa no resultado
ecológico, o que por si só responde a uma pergunta do artigo do Curiango.

| Passo | Pacote | Pronto quando |
|---|---|---|
| `calibration_draws.csv` no contrato | sheepdog | escrito por `export_occupancy_data(fit = )` |
| `fp_occu_mc(data_list, ...)`: ajusta em paralelo e empilha os draws (mistura igual das posteriores) | crywolf | com *M* = 1 e calibração degenerada, igual ao `fp_occu()`; `summary()` separa a variância entre e dentro dos ajustes |
| Escolha de *M*: medir a estabilidade dos coeficientes de ocupação com *M* = 10, 20, 50 | dev | regra prática documentada |
| Curiango: comparar com os quatro caminhos do artigo | dev | figura no estilo da Fig. 4 do artigo, com o caminho MC |

Risco: custo *M* vezes o de um ajuste. O caminho rápido (GLM por sítio) do
crywolf ajuda; medir antes de documentar.

## Fase 2: modelo conjunto score–ocupação

É o núcleo do plano e a contribuição metodológica.

### O modelo (proposta, a validar)

Sítio (ou sítio-noite) *i*, ocasião *j*:

- **Estado:** z_i ~ Bernoulli(ψ_i), logit(ψ_i) = X_i β (como no
  `fp_occu()`).
- **Canto na ocasião:** w_ij | z_i ~ Bernoulli(z_i · θ_ij), logit(θ_ij) =
  V_ij α, com o termo de Markov e o efeito de gravador do crywolf. θ faz o
  papel de p11.
- **Score:** s_ij = logit(`max_score`), com censura em `min_confidence`.
  - s_ij | w_ij = 1 ~ f₁(μ₁ + U_ij γ₁, σ₁);
  - s_ij | w_ij = 0 ~ f₀(μ₀ + U_ij γ₀, σ₀), com uma massa de censura (sem
    detecção);
  - restrição de identificação μ₁ > μ₀ (o "gap", como no `fp_gap_prior()`).
- **Verificações:** uma ocasião de `recordings_verified` observa w_ij;
  um clipe positivo em `validation` implica w_ij = 1; um clipe negativo
  informa só a componente f₀ daquele score, não w_ij.

Este modelo junta o modelo de mistura contínua de Rhinehart et al. (2022) e
o de classificação–ocupação de Ogawa et al. (2025) com o desenho de
verificação de Miller et al. (2011) e de Chambert et al. (2015). O que muda
em relação a eles, e é o que o Curiango pede:

1. **Covariáveis nas distribuições dos scores** (U_ij: BIO, ACI, gravador,
   sítio). O erro do classificador varia no espaço (Metcalf et al. 2022), e
   o artigo do Curiango sugere que os scores altos variam com o ambiente.
2. **Dependência dentro da noite** pelo termo de Markov do crywolf, que
   nenhum dos dois modelos citados tem.
3. **Verificação com desenho conhecido** vinda do contrato.

**f₁ e f₀.** Normais no logit, como em Rhinehart et al. (2022), são o ponto
de partida. **[decidir]** Testar uma alternativa mais flexível (t de
Student ou skew-normal) se o PPC dos scores falhar no Curiango.

### Relação com a calibração do sheepdog

A calibração do sheepdog modela P(TP | score, sítio, espécie), uma regressão
discriminativa. Pelo teorema de Bayes, ela é a razão f₁/f₀ combinada com a
prevalência local de canto. Um intercepto de sítio na calibração absorve,
então, duas coisas: o erro do classificador naquele sítio e a taxa de canto
do sítio, que é justamente o que a ocupação quer estimar. Usar o p_tp
calibrado com efeito de sítio como entrada do modelo de ocupação conta a
prevalência local duas vezes. Isto é inferência minha, não está testado.
No modelo conjunto, a prevalência vem de ψ e θ, e o classificador entra só
por f₁ e f₀.

Consequências práticas:

- a fase 2 não substitui a calibração do sheepdog, que continua servindo
  aos limiares, ao retreino e às matrizes de comunidade;
- o sheepdog deve documentar essa diferença;
- comparar com a calibração hierárquica por sítio de Freeland-Haynes et al.
  (2026, preprint), que estende o Platt scaling com prior de processo
  gaussiano nas covariáveis. **Ler o texto completo** antes de afirmar
  como eles tratam a prevalência: só li o abstract.

### Ignorabilidade da seleção dos clipes

Num modelo que condiciona em todos os scores observados, escolher clipes
para revisar em função do score é uma seleção ignorável no sentido de
Rubin (1976), desde que f₁ e f₀ estejam bem especificadas. Isso relaxa a
exigência atual do crywolf de usar só clipes sorteados ao acaso. Com f₁ e
f₀ mal especificadas, a camada aleatória é o que protege; daí a fase 3.
Também é inferência minha; precisa de simulação (abaixo).

### Passos

| Passo | Pronto quando |
|---|---|
| `simulate_fp()` com scores: gerar s_ij de f₁/f₀ com covariáveis | os scores simulados reproduzem as curvas de precisão e recall da Fig. 3 do Curiango com parâmetros escolhidos à mão |
| Stan: verossimilhança por sítio marginalizando z e w (dois níveis de soma; com Markov, forward de dois estados dentro da noite) | log-densidade em R = Stan; com σ → 0 e limiar fixo, reduz-se ao modelo de Miller (conferir numericamente) |
| `fp_occu_score()`: função nova; fórmulas `occ`, `det`, `score1`, `score0`; métodos `summary`, `predict`, `loo`, `fp_ppc` (incluindo o PPC dos scores) | testes de recuperação e SBC uniforme, como no `fp_occu()` |
| Simulação da ignorabilidade: validação aleatória × por score × "top", com f bem e mal especificada | tabela de viés e cobertura; vira uma vinheta |
| Curiango, os dois classificadores, sem limiar | comparado por LOO e pela Fig. 4 do artigo; a hipótese é que os dois classificadores convirjam mais entre si do que nos caminhos com limiar |
| Comparação com Rhinehart et al. (2022) e Ogawa et al. (2025) nos dados simulados | código deles reproduzido ou reimplementado; diferença documentada |

**Critério de sucesso** (decide se a fase vale um artigo): no Curiango, a
diferença entre os dois classificadores nos coeficientes de ocupação fica
menor que a diferença entre MaxF1 e MaxPrecision com limiar, sem perder
cobertura em simulação.

## Fase 3: validação em camadas

O ACORN (Haucke et al. 2026, preprint) escolhe os clipes a revisar pelo
quanto informam a ocupação, não pela acurácia do classificador. McEwen et
al. (2026, preprint) lembram que rótulos escolhidos assim não servem para
calibrar nem para validar o classificador. A proposta separa as camadas pelo
papel de cada uma:

- **camada probabilística** (sheepdog, já existe): `random_detections` ou
  `random_recordings`, com `inclusion_prob`; garante a calibração, as
  métricas do classificador e a proteção contra f₁/f₀ mal especificadas;
- **camada dirigida** (nova): clipes escolhidos pela redução esperada da
  variância posterior dos coeficientes de ocupação, a partir de um ajuste
  do `fp_occu_score()`;
- **camada de treino** (nova, acrescentada em 25/10/2026): clipes de score
  ambíguo (perto de 0,5, ou de maior entropia binária) para o retreino do
  classificador. É o "aprendizado ativo por incerteza" das propostas de
  MLOps. Serve só ao treino: como o `"top"`, depende do score e não pode
  entrar na calibração nem na taxa de falsos positivos.

| Passo | Pacote | Pronto quando |
|---|---|---|
| `select_clips(sampling_mode = "targeted", priority = )`: aceita uma tabela de prioridade por ocasião (gerada fora do sheepdog) e registra `sampling_mode` e a ordem de escolha | sheepdog | o manifesto marca a camada de cada clipe; `inclusion_prob` = `NA` na camada dirigida |
| `fp_review_priority(fit)`: prioridade por ocasião (variância de w_ij ponderada pela influência em β) | crywolf | em simulação, recupera β com menos revisões que a amostra aleatória, com a mesma cobertura |
| `select_clips(sampling_mode = "uncertain")`: clipes de score perto de 0,5 por local × espécie, com `inclusion_prob` = `NA` e o mesmo aviso do `"top"`; o `build_training_set()` os aceita | sheepdog | teste de que o modo não entra em `read_validations()` sem aviso; exemplo na vinheta `retraining` |
| Divisão do orçamento: fração aleatória mínima | dev | simulação com orçamentos de 100 a 1.000 clipes; recomendação documentada |
| Comparar com o ACORN | dev | mesmos dados simulados; diferença documentada |

O `fp_verification_curve()` do crywolf já responde "quanto verificar";
a fase 3 acrescenta "o quê".

## Fase 4: atividade vocal

Passar de "cantou na ocasião" para a proporção de janelas com canto
(densidade de chamadas; Navine et al. 2024, preprint; Freeland-Haynes et
al. 2026, preprint). Com uma janela de 3 s e um minuto por ocasião, cada
ocasião tem cerca de 20 janelas, e a fase 2 já define as distribuições dos
scores por janela. A densidade vira um submodelo: λ_ij, a taxa de janelas
com canto dada a ocupação, com covariáveis (lua, temperatura). Precisa de
`detections.csv` no contrato.

É aqui que se testa a hipótese da lua do Curiango (efeito na intensidade,
não na ocupação). Também é o caso natural dos anuros em coro do FrogNet.

**[decidir]** Se a fase 4 vem antes ou depois da comunidade.

## Fase 5: comunidade

Segue a Fase A do roadmap do crywolf (`fp_occu_ms()`, falso positivo por
espécie, independente entre espécies), agora com scores por espécie. As
`community_matrices_draws()` do sheepdog passam a ser a linha de base para
comparar: matrizes de comunidade com e sem modelo de observação, numa
análise de metacomunidade.

A confusão entre espécies (A marcada quando quem canta é B) continua **fora
do plano**, como decidido no roadmap do crywolf. A literatura sobre ela
existe (Wright et al. 2019; Stratton et al. 2022; Clement et al. 2022), mas
exige uma matriz de classificação e um desenho de verificação próprio.
**[decidir]** Se ela vira um projeto de pesquisa separado (por exemplo, com
os anuros do FrogNet, que têm cantos parecidos entre espécies).

## Benchmark e dados

| Conjunto | Para quê | Situação |
|---|---|---|
| Simulações (`simulate_fp()` estendido) | recuperação, SBC, ignorabilidade, orçamento de validação | a fazer na fase 2 |
| Curiango (Zenodo 10.5281/zenodo.21795898, CC BY 4.0) | um classificador local e um global, 1.199 arquivos anotados por completo, PPC com falhas conhecidas | já usado nos dois pacotes; falta exportar no esquema |
| FrogNet (anuros, Pantanal e Cerrado) | multiespécies, coros, atividade vocal | **[decidir]** quais dados e quando |
| Conjuntos públicos totalmente anotados (Havaí, Pacific Northwest, usados por Navine et al. e Freeland-Haynes et al.) | validação externa | **[decidir]** conferir licença e acesso |

Contraponto obrigatório no benchmark: Katsis et al. (2025) acharam que,
com um classificador bom e uma espécie fácil de detectar, ouvir as
detecções indicadas pelo classificador e usar o modelo de ocupação comum
foi tão bom quanto os modelos com falsos positivos, que eram sensíveis ao
limiar e caros. O benchmark precisa mostrar **quando** o modelo conjunto
compensa, e não só que ele funciona. O artigo do Curiango aponta na mesma
direção (o classificador local deixou os caminhos mais parecidos).

## Riscos

- **Identificação.** Com poucas verificações, f₁/f₀, θ e ψ competem pelas
  mesmas detecções. O gap ajuda; medir em simulação quanta verificação é
  necessária antes de documentar, como foi feito com o `random_fp`.
- **Custo.** Marginalizar w dentro da noite com Markov, em 1.700 noites
  × 56 ocasiões, é caro. Medir no Curiango cedo; o `reduce_sum` e as
  tuplas do crywolf 1.7 ajudam.
- **Má especificação de f₁/f₀.** Os scores do BirdNET se acumulam perto de
  0 e de 1. Testar o PPC dos scores antes de confiar nos coeficientes.
- **Duas fontes da verdade.** A calibração do sheepdog e o `fp_occu_score()`
  vão dar probabilidades diferentes para a mesma detecção. A documentação
  dos dois pacotes precisa dizer qual usar para quê.
- **Sobreposição com trabalhos recentes.** ACORN, Freeland-Haynes et al. e
  McEwen et al. saíram em setembro de 2026. Ler os textos completos antes
  de fixar o desenho da fase 2 e da fase 3, e citar de forma explícita o que
  for igual.

## Artigos

**[decidir]** Uma divisão possível:

1. **Software** (sheepdog + crywolf juntos, fases 0 e 1): o fluxo da medição
   ao processo, com a incerteza propagada de ponta a ponta. O contrato de
   dados e o Curiango são o caso de uso.
2. **Métodos** (fases 2 e 3): modelo conjunto score–ocupação com validação
   em duas camadas; o Curiango como estudo de caso, mostrando o que muda em
   relação aos quatro caminhos do artigo do JAV.

## Referências verificadas

Conferidas no Crossref, no Undermind ou no Scholar Gateway em 24/10/2026.
Os preprints foram lidos só pelo abstract.

- Chambert, T., Miller, D. A. W., & Nichols, J. D. (2015). Modeling false
  positive detections in species occurrence data under different study
  designs. *Ecology*. https://doi.org/10.1890/14-1507.1
- Clement, M., Royle, J. A., & Mixan, R. J. (2022). Estimating occupancy
  from autonomous recording unit data in the presence of misclassifications
  and detection heterogeneity. *Methods in Ecology and Evolution*.
  https://doi.org/10.1111/2041-210X.13895
- Freeland-Haynes, L., Weldy, M. J., Navine, A. K., Hart, P. J., Denton,
  T., & Kitzes, J. (2026). Calibrating classifiers across covariates:
  hierarchical vocal density estimation for acoustic monitoring at scale.
  *bioRxiv* (preprint). https://doi.org/10.64898/2026.09.08.747031
- Haucke, T., Harrell, L., Kay, J., Clapp, M. K., & Beery, S. (2026).
  Targeted review for AI-assisted biodiversity surveys: active
  continuous-score occupancy modeling. *arXiv* (preprint).
  https://arxiv.org/abs/2609.25657
- Katsis, L., et al. (2025). A comparison of statistical methods for
  deriving occupancy estimates from machine learning outputs. *Scientific
  Reports*. https://doi.org/10.1038/s41598-025-95207-3
- McEwen, B., Zhang, S.-Q., & Stowell, D. (2026). Active learning for
  biodiversity monitoring: from label efficiency to reliable ecological
  inference. *arXiv* (preprint). https://arxiv.org/abs/2609.27409
- Metcalf, O., et al. (2022). Detecting and reducing heterogeneity of error
  in acoustic classification. *Methods in Ecology and Evolution*.
  https://doi.org/10.1111/2041-210X.13967
- Miller, D. A., et al. (2011). Improving occupancy estimation when two
  types of observational error occur: non-detection and species
  misidentification. *Ecology*. https://doi.org/10.1890/10-1396.1
- Monchy, C., Gimenez, O., Le Bohec, C., Bardon, G., & Étienne, M.-P.
  (2026). Monte Carlo simulations to propagate the uncertainty of automated
  classification into ecological models. *bioRxiv* (preprint).
  https://doi.org/10.64898/2026.01.14.699344
- Navine, A. K., Denton, T., Weldy, M. J., & Hart, P. J. (2024). All
  thresholds barred: direct estimation of call density in bioacoustic data.
  *arXiv* (preprint). https://doi.org/10.48550/arXiv.2402.15360
- Ogawa, R., Gosselin, F., Darras, K. F. A., Roilo, S., & Cord, A. F.
  (2025). A classification-occupancy model based on automatically
  identified species data. *Ecology*. https://doi.org/10.1002/ecy.70086
- Rhinehart, T., Turek, D., & Kitzes, J. (2022). A continuous-score
  occupancy model that incorporates uncertain machine learning output from
  autonomous biodiversity surveys. *Methods in Ecology and Evolution*.
  https://doi.org/10.1111/2041-210X.13905
- Rubin, D. B. (1976). Inference and missing data. *Biometrika*.
  https://doi.org/10.1093/biomet/63.3.581
- Stratton, C., et al. (2022). Coupling validation effort with in situ
  bioacoustic data improves estimating relative activity and occupancy for
  multiple species with cross-species misclassifications. *Methods in
  Ecology and Evolution*. https://doi.org/10.1111/2041-210X.13831
- Wright, W. J., Irvine, K. M., Almberg, E. S., & Litt, A. R. (2019).
  Modelling misclassification in multi-species acoustic data when
  estimating occupancy and relative activity. *Methods in Ecology and
  Evolution*. https://doi.org/10.1111/2041-210X.13315
- Artigo do Curiango, JAV (aceito). [CITAR: referência completa]
