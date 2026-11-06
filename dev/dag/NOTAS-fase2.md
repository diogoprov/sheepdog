# Fase 2: o que foi lido e concluído (sessão de 02–04/11/2026)

Notas para as próximas sessões, que não têm acesso à conversa em que isto
foi feito. O plano em si está em `dev/roadmap-integration.md` (seção
"Fase 2: modelo conjunto score–ocupação"). Aqui ficam as fontes, o
raciocínio e o que ainda está em aberto. Comece por este arquivo e depois
leia o roadmap.

## Arquivos

| Arquivo | O que é |
|---|---|
| `dev/roadmap-integration.md`, fase 2 | o modelo proposto, de onde vem cada parte, "Distribuição do máximo", "Identificação" e os passos |
| `dev/dag/fase2_dag.dot` e `.png` | **DAG de referência**, no estilo e na notação da vinheta do crywolf (`crywolf/dev/dag/crywolf_dag.dot`). Para refazer: `Rscript dev/dag/make_fase2_dag.R`, que usa o `dot` do Graphviz; o DiagrammeR posiciona errado os subscritos |
| `dev/dag/comparacao_modelos.md` | tabela Rhinehart et al. (2022) × Ogawa et al. (2025) × fase 2, com páginas |
| `dev/dag/dag_diagrammer_v0.R` e `.png` | primeira DAG, feita com DiagrammeR antes da leitura completa dos artigos. Usa a notação antiga e está superada; foi mantida para registro |

## Fontes lidas no texto completo

- **Rhinehart, Turek & Kitzes (2022)**, *Methods Ecol Evol* 13:1778–1789,
  DOI 10.1111/2041-210X.13905: lido no PDF, junto com o material
  suplementar (.docx). O texto não está no Undermind nem no Wiley Scholar
  Gateway; buscas feitas em 02/11/2026. O código está no Dryad,
  10.5061/dryad.ns1rn8ptd (`models.R`, em NIMBLE).
- **Ogawa, Gosselin, Darras, Roilo & Cord (2025)**, *Ecology*, DOI
  10.1002/ecy.70086: lido pelo Undermind, workspace "Ecoacústica +
  modelos de ocupação (sheepdog/crywolf)". O código está no Zenodo,
  10.5281/zenodo.12802535 (em JAGS).

## Conclusões

1. **A estrutura z → w → s vem de Rhinehart et al.** No modelo deles,
   f_ik ~ Bernoulli(z_i θ) indica se a espécie está presente no arquivo;
   θ é a taxa de canto, e os scores seguem N(μ₀, σ₀) ou N(μ₁, σ₁), com
   σ₀ ≠ σ₁. As anotações são por arquivo: h = 0, 1 ou 2.
2. **O `w` de Ogawa et al. não é canto.** É o status de falso positivo de
   uma detecção, w ~ Bernoulli(q). O modelo deles usa só um score por
   ocasião (o maior da hora, condicional a haver detecção), σ comum entre
   as componentes e nenhum dado verificado. Da proposta da fase 2, só a
   ideia de um score por ocasião vem deles.
3. **O `max_score` não é estatística suficiente para Rhinehart et al.**
   Eles usam o score de cada arquivo. O máximo de n janelas tem
   distribuição própria: sem canto, P(s ≤ x) = Φ((x − μ₀)/σ₀)ⁿ, que sobe
   com n. Se isso for ignorado, ocasiões com mais janelas parecem ter mais
   canto. Isto é inferência minha e precisa de simulação; as opções estão
   no roadmap, em "Distribuição do máximo". `n_windows` **não** está em
   `scores.csv` (corrigido em 05/11/2026; o export grava `max_score` e
   `n_above_min`).
4. **O que é novo na fase 2** em relação aos dois artigos:
   - covariáveis nas distribuições dos scores (**g**_ik); nos dois
     artigos, μ e σ são constantes;
   - termo de Markov dentro da noite, sobre o canto latente w_i,k−1. Os
     dois artigos assumem arquivos independentes;
   - verificação com desenho conhecido, vinda do contrato de dados;
   - score por ocasião modelado como o máximo das janelas.
5. **Ignorabilidade.** Rhinehart et al. anotam um subconjunto aleatório e
   sugerem, como extensão futura, dirigir a escuta para os arquivos de
   score alto (p. 1787). A simulação de ignorabilidade da fase 2 responde
   diretamente a essa sugestão, o que ajuda a vender o artigo.
6. **Identificação, segundo o material suplementar de Rhinehart et al.**
   - Cerca de 5% das simulações falharam com μ₀ ≈ μ₁; 94% dessas falhas
     tinham ψ̂ entre 0,9 e 1.
   - As falhas aumentam com θ baixo e poucas anotações positivas.
   - Com o melhor classificador, as falhas vieram do valor inicial
     μ₁ = 1, longe do verdadeiro (6).
   - A restrição μ₁ > μ₀ só é assumida; as priors são independentes.

   Consequências para o `fp_occu_score()`: parametrizar
   μ₁ = μ₀ + Δ_s com Δ_s > 0, como o gap do `fp_occu()`; tirar os valores
   iniciais da calibração do sheepdog; e simular o caso de espécie rara.
7. **Uma divergência no próprio artigo.** A prior de μ₁ de Rhinehart et al.
   é N(1, 10⁴) no texto principal (p. 1781) e N(0, 10000) no material
   suplementar. Isso importa ao reimplementar o modelo para a comparação.
8. **A calibração do sheepdog conta a prevalência local duas vezes** se
   for usada como entrada da ocupação. P(TP | score, sítio) mistura o erro
   do classificador com a taxa de canto do sítio. Há evidência empírica no
   Curiango (sheepdog#67). No modelo conjunto, a prevalência vem de ψ e θ,
   e o classificador entra só por f₀ e f₁.

## Correções de 05/11/2026

Conferidas no código; o detalhe está no roadmap e em `dev/fase2/README.md`:
`n_windows` não existe no export; no Curiango o score é do minuto, não um
máximo de janelas; o critério "σ → 0 reduz-se a Miller" foi trocado pela
dicotomização do score; o clipe negativo da DAG conta o score duas vezes
quando é a janela do máximo. O protótipo do modelo está em `dev/fase2/`.

## Decisões relacionadas, tomadas em 02–04/11/2026

- **Dois usos da revisão de clipes**, ponto levantado pela Larissa
  Sugai:
  - a amostra para os limiares pode ser escolhida pelo score, por
    exemplo estratificada por faixa de score como em Wood & Kahl (2024).
    Isso não enviesa P(TP | score), desde que a forma do modelo esteja
    certa;
  - o site-confirmation do crywolf precisa de clipes sorteados ao acaso.

  Uma amostra montada para os limiares não serve para estimar falsos
  positivos. Isso está documentado em `calibrated_thresholds()`.
- **`calibrated_thresholds()`** (sheepdog#80) tira o limiar da calibração
  do stage 2, nas regras `"probability"` e `"precision"`. Continuam em
  aberto:
  - o nome, ou se deveria virar uma opção da `suggest_thresholds()`;
  - se o `calibrate()` deve gravar os limiares;
  - o alvo padrão: 0,95 ou 0,90.

  O ramo `brms` não foi executado na sessão em nuvem, porque o rstan não
  compilava modelos. Para rodar:
  `Sys.setenv(SHEEPDOG_TEST_BRMS = "true"); devtools::test(filter = "calibrated_thresholds")`.

## Próximos passos da fase 2 (resumo; detalhes no roadmap)

1. `simulate_fp()` com scores por janela e o máximo por ocasião.
2. Escolher entre as opções da distribuição do máximo, por simulação.
3. Escrever a verossimilhança em Stan (z e w marginalizados, forward
   dentro da noite) e o `fp_occu_score()` no crywolf.
4. Simulação de ignorabilidade (validação aleatória × por score × "top").
5. Reproduzir ou reimplementar Rhinehart et al. e Ogawa et al. nos dados
   simulados, com o código do Dryad e do Zenodo.
