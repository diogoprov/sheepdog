# Fluxo de limiares da Larissa × sheepdog: notas da sessão remota

Sessão remota de 13/11/2026. Ler antes de mexer em limiares, calibração,
`select_clips()` ou no leitor do crywolf. A seção **"O que fazer
localmente"** lista o que a sessão remota não conseguiu fazer.

## Origem

A Larissa escreveu o documento "Threshold Workflow Review", um artifact no
claude.ai. Peça o link ao Diogo; ele não está no repositório. O documento
propõe um fluxo de 9 passos (0 a 8) para chegar a um limiar de **precisão
cumulativa ≥ 0,95** e traz um benchmark com o ACAD.

A conclusão central do benchmark: a **contagem ponderada, sem modelo**
(pesos `1 / inclusion_prob`), deve ser o estimador de referência. A
logística erra onde a curva não tem a forma certa (YRWA, GCKI), e a
log-loss por validação cruzada não mostra esse erro.

O texto do documento foi extraído para
`scratchpad/plano/plano.txt` na sessão remota. Esse arquivo não existe
fora dela.

## Situação de cada passo

| Passo | O que pede | No sheepdog |
|---|---|---|
| 0–1 | unidade de análise; score fixo; mínimo de 0,1 | existe (`occasion_unit`, `min_confidence`, `extraction_info.csv`) |
| 2 | amostra probabilística estratificada por faixa de score | **feito**: `select_clips(sampling_mode = "score_bands")` (PR #129) |
| 2 | unidades abaixo de 0,1; rodadas em duas fases | existe (`random_recordings`, `combine_rounds()`, `select_directed()`) |
| 3 | revisão cega | **feito**: `run_app(blind = TRUE)` (PR #128) |
| 4 | precisão por faixa, ponderada | existe (`precision_by_bin()`) |
| 4 | **teto de recall** e recall no limiar | **pendente (médio)** |
| 5 | logística no logit do score | existe (`fit_calibration()`) |
| 6 | comparar com quadrática, GAM e GAM monótono | **feito**: `compare_calibration_curves()` (PR #131) |
| 6 | estrutura dos FN por sítio (permutação, descontada a atividade) | **pendente (maior)**: exige gravações anotadas por inteiro |
| 7 | limiar pela precisão cumulativa ponderada | existe (`suggest_thresholds()`) |
| 7 | incerteza do limiar por bootstrap de gravações ou noites | **feito**: `threshold_bootstrap()` (PR #128) |
| 7 | um limiar único em cada grupo | **feito**: `threshold_by_group()` (PR #128) |
| 8 | ficha do limiar | **feito**: `threshold_record()` (PR #128) |
| — | sinais de alerta 2, 6, 7 e 8 (os que saem da amostra) | **pendente (médio)** |

Os sinais 1, 3, 4 e 5 exigem anotação completa. Servem mais ao benchmark
do que ao usuário.

## PRs desta sessão

- sheepdog #128 (merged): `threshold_bootstrap()`, `threshold_by_group()`,
  `threshold_record()` e `run_app(blind = TRUE)`.
- sheepdog #129 (merged): `sampling_mode = "score_bands"`, com o argumento
  `score_breaks` e a seção "Which design for which use" na ajuda de
  `select_clips()`. `export_occupancy_data()` avisa que o crywolf descarta
  esses clipes.
- crywolf #35 (merged): `fp_read_sheepdog()` descarta os clipes
  `score_bands` com um aviso, qualquer que seja o `keep_top`. Para com erro
  quando só há clipes `score_bands` e o export não tem gravações anotadas.
- sheepdog #130 (aberto, CI verde): `score_bands` na aba Setup do app, com
  `parse_breaks()`, e uma seção na vinheta `sampling-designs`.
- sheepdog #131 (aberto): `compare_calibration_curves()` e
  `plot_calibration_curves()`, com `mgcv` e `scam` nos Suggests e uma seção
  na vinheta `calibration`.
- sheepdog #133 (aberto): `score_bands` nos fluxogramas e esquemas.
- Os PRs #130 e #131 mexem no `NEWS.md`. Ao fazer o merge do segundo,
  resolva o conflito mantendo as duas entradas.

## Decisões de desenho (não refazer sem motivo)

**`score_bands` é um modo separado, não um estrato.**
- O desenho de observation-confirmation (Chambert et al. 2015) exige
  clipes escolhidos independentemente do score. Por isso `select_clips()`
  continua recusando colunas de score em `strata`.
- Os clipes `score_bands` servem para limiares e calibração e têm
  `inclusion_prob` = sorteados / candidatos do estrato × faixa.
- Ainda não aceitam `previous` (rodadas seguintes), `target_total` nem
  `max_per_species`.

**No crywolf, `score_bands` é sempre descartado.**
- Esses clipes viesariam a taxa de falsos positivos nas duas direções.
- O erro só ocorre quando não sobra nada para estimar falsos positivos
  (nenhum clipe aleatório e nenhuma gravação anotada).

**`compare_calibration_curves()`:**
- As dobras da validação cruzada são de gravações inteiras
  (`cluster = "source_audio"`).
- O veredito usa `top_error_excess`: o erro da curva nas faixas altas
  menos o menor erro entre as curvas flexíveis, e não o `top_error`
  absoluto. Com cerca de 20 clipes por faixa de 0,05, o ruído amostral
  sozinho já leva uma logística correta a cerca de 0,031. O limite de
  0,03 do documento da Larissa só faz sentido em excesso.
- "Alcança o alvo" quer dizer que existe algum limiar de **precisão
  cumulativa** (de uma curva flexível ou da contagem ponderada) com pelo
  menos `min_n` clipes efetivos acima dele. Uma curva que passa de 0,95
  só no topo extremo não conta; é o caso de `lep_fus` nos dados de exemplo.
- A ordem dos vereditos é:
  1. `too_few_clips`;
  2. `sample_more_near_threshold` (com poucos dados no topo, não dá para
     concluir nada);
  3. `no_curve_reaches_target`;
  4. `keep_logistic` (excesso ≤ 0,03 e limiar a até 0,03 da contagem
     ponderada);
  5. `use_monotone_or_weighted`.
- `threshold_precision` é a precisão cumulativa prevista pela curva sobre
  os clipes revisados, ponderada por `1 / inclusion_prob`. Responde à
  mesma pergunta que `threshold_weighted` (`threshold_for(...,
  sustained = TRUE)`).

## O que fazer localmente (a sessão remota não conseguiu)

1. **Instalar o `scam` e rodar o GAM monótono.** O ambiente remoto barrou
   `install.packages()`.
   - `install.packages("scam")`, depois
     `devtools::test(filter = "calibration_curves")`. O teste "the
     monotone GAM is fitted and never decreases" foi pulado na sessão
     remota.
   - Confira nos dados de exemplo se o veredito muda com o GAM monótono:
     `compare_calibration_curves(read_validation_tables(arquivos))`, com
     as quatro curvas.
   - Se o `scam` emitir avisos ou erros com pesos não inteiros, ajuste
     `fit_curve()` em `R/calibration_curves.R`.
   - Decida se a vinheta `calibration` deve incluir `"monotone_gam"`.
     Hoje ela usa só logística, quadrática e GAM.
2. **Rodar `devtools::document()` nos dois repositórios.**
   - A sessão remota tinha o roxygen2 7.3.1; os repositórios usam o 8.1.1.
     Os Rd foram gerados numa cópia e copiados um a um, e o NAMESPACE foi
     editado à mão.
   - No crywolf, `man/fp_read_sheepdog.Rd` foi editado **à mão** porque o
     roxygen não carregava o pacote sem o `instantiate`.
   - Confirme que `document()` não gera diferenças. Se gerar, faça commit
     do resultado.
3. **Rodar o crywolf completo, com CmdStan e `instantiate`.**
   - Na sessão remota só os testes do leitor rodaram, carregando os
     arquivos de `R/` diretamente.
   - Rode `devtools::test()` com o sheepdog instalado, para que o teste
     "the export of sheepdog itself is read" não seja pulado.
   - Faça um teste de ponta a ponta: um export do sheepdog com clipes
     `score_bands` e `random_detections`, lido por `fp_read_sheepdog()`.
     Deve haver o aviso de descarte e só os clipes aleatórios devem ficar.
4. **Rodar o `R CMD check` completo, com testes e vinhetas, e o
   `pkgdown::build_site()`.**
   - A sessão remota só rodou `--no-tests --ignore-vignettes` e renderizou
     as vinhetas alteradas, uma a uma.
   - Confira se `compare_calibration_curves` e `plot_calibration_curves`
     aparecem na seção "Stage 2 - Calibration" da referência.
5. **Testar o app na mão.**
   - Rode `run_app()` e use a aba Setup com `score_bands`: as faixas
     digitadas, o campo Strata e a mensagem sobre a finalidade dos clipes.
   - Teste a revisão cega com `run_app(blind = TRUE)`: Clip, Score e
     Design devem ficar escondidos e a ordem deve ser embaralhada por
     revisor.
   - Tire novos screenshots para a vinheta do app, se ela os usar.
6. **Validar `compare_calibration_curves()` com dados reais.**
   - Use os dados do piloto da Larissa (ACAD) e, se possível, o Curiango
     (`dev/benchmarks`).
   - Confira se YRWA e GCKI recebem `use_monotone_or_weighted` ou
     `no_curve_reaches_target`, como o benchmark dela indica.
   - Com dados reais, reveja os valores padrão: `top_from = 0.7`,
     `bin_width = 0.05`, `min_n = 15`, `max_error` e `tolerance = 0.03`.
7. **Email para a Larissa.**
   - O rascunho ficou só no chat da sessão remota, porque o endereço dela
     não estava disponível.
   - Antes de enviar, atualize o rascunho: "faixas de score" já está
     implementado (PR #129), e a comparação com GAM também (PR #131).
   - Pergunte se ela imagina o fluxo alternativo como um artigo separado
     (com o benchmark do ACAD, MABI e SIMR) ou como uma vinheta do
     sheepdog.
8. **Re-renderizar o fluxograma do README com o DiagrammeR.**
   - O PR #133 pôs `score_bands` nas figuras: a da vinheta, o esquema do
     site, `extraction_flow`, a figura de abertura do app e o cheatsheet.
   - Sem o DiagrammeR, o `man/figures/extraction_flow.*` foi gerado com o
     Graphviz do sistema, e o estilo ficou um pouco diferente do anterior.
   - Rode `source("data-raw/diagram_extraction.R")` e faça commit dos
     arquivos gerados.
9. **Ambiente remoto.** O host `cloud.r-project.org` foi liberado no
   ambiente padrão do claude.ai, mas a instalação de pacotes continua
   barrada pela regra de permissões da sessão. Para a próxima sessão
   remota instalar pacotes do CRAN, autorize o comando ou rode a
   instalação localmente.

## Próximos itens (médios), em ordem sugerida

1. **Teto de recall e recall no limiar.**
   - Fonte: gravações de `random_recordings` com vereditos. O teto é a
     fração das unidades com a espécie que têm score ≥ `min_confidence`.
     O recall no limiar é o teto vezes a fração das unidades detectadas
     com score ≥ θ.
   - Use pesos `1 / inclusion_prob`, calcule por grupo e com bootstrap por
     gravação, como em `threshold_bootstrap()`.
   - Os dados já saem do export (`recordings_verified.csv`).
2. **Relatório dos sinais de alerta 2, 6, 7 e 8**, os que saem da
   amostra. Ver a tabela de sinais no documento da Larissa. Junte as
   saídas de `precision_by_bin()`, `threshold_by_group()`,
   `compare_calibration_curves()` e `threshold_bootstrap()` num veredito
   por espécie: confiável / com ressalvas / não confiável.
3. **(Maior)** Falsos negativos por sítio, descontada a atividade.
   Precisa de dias-sítio com atividade verdadeira, ou seja, gravações
   anotadas por inteiro.
