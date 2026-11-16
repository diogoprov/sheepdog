# Pedido 6c: o veredito de `warning_signs()` (15/11/2026)

Resumo da avaliação feita no compêndio do estudo de desenho da revisão
(`review-design-sim`, `dev/PEDIDOS-sheepdog.md`, seção "Avaliação do 6c";
script `dev/diag/ws_rules.R`, commit b491b95). É a base da mudança na
documentação de `warning_signs()`, que passou a apresentar o veredito como
diagnóstico de heterogeneidade dos dados, e não da confiabilidade do limiar.

## Desenho

- **Bases:**
  - 46.948 reamostragens de revisão do Curiango (dados reais);
  - 290.555 amostras da fase 1 simulada, no regime estruturado
    (sheepdog fc25c42).
- **Falha:** o limiar da contagem ponderada tem precisão realizada abaixo
  de alvo − 0,02.
- **Conferência:** a regra atual, recalculada a partir dos sinais salvos,
  reproduz o veredito do sheepdog em 100% das amostras.
- **Regras candidatas:**
  - **A:** exigir um número mínimo de sinais checados;
  - **B:** sinal 6 pelo desvio-padrão entre grupos com encolhimento
    (τ > 0,10 ou τ > 0,15);
  - **C:** sinal 7 com intervalo de Wilson;
  - **A+B+C:** as três juntas.

## Resultados

Falha por veredito. Entre parênteses, a fração das amostras em cada
veredito.

| regra | Curiango limpo | Curiango `not_trustworthy` | fase 1 limpo | fase 1 `not_trustworthy` |
|---|---|---|---|---|
| atual | 34% (5%) | 14% (31%) | 2,1% (9%) | 13% (32%) |
| A | igual à atual | | igual à atual | |
| B, τ > 0,10 | 34% (5%) | 15% (31%) | 1,2% (8%) | 14% (35%) |
| B, τ > 0,15 | 36% (6%) | 13% (11%) | 2,2% (9%) | 13% (31%) |
| C, Wilson | 30% (13%) | 18% (14%) | 5,6% (14%) | 12% (19%) |
| A+B+C, τ > 0,15 | 33% (16%) | 13% (4%) | 7,0% (15%) | 12% (19%) |

Falha pelo número de sinais levantados (0 a 4), com a regra atual:

- **Curiango:** 34, 27, 25, 14 e 7%;
- **fase 1:** 2, 11, 15, 13 e 11%.

## Leitura

- **Curiango:** o veredito fica invertido com todas as regras. Com tudo
  limpo, falha mais do que com `not_trustworthy`.
- **Simulação:** o veredito limpo informa (2% contra 13% a 14%), mas cobre
  só 9% das amostras. Entre `use_with_caveats` e `not_trustworthy` não há
  diferença.
- **Origem da inversão (interpretação, não teste):** a diferença entre as
  duas bases sugere que ela vem dos FP agrupados por sítio, que não
  existem no regime estruturado.
- **Regras B e C:** trocam especificidade por sensibilidade sem reordenar
  os vereditos.
- **Bootstrap por noite da precisão no limiar:** também não discrimina,
  como no 6b (`dev/oob-6b/`).

## Decisão

Não mudar a regra do veredito. A documentação passa a apresentá-lo como
diagnóstico da heterogeneidade dos dados (o que o modelo ecológico precisa
levar em conta), e a confiabilidade do limiar fica com o
`threshold_conservative` (PR #150).
