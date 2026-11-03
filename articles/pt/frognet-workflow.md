# O fluxo de trabalho do FrogNet

> **Tradução.** Este artigo é uma tradução da versão em inglês, que é a
> referência: [The FrogNet
> workflow](https://provetelab.org/sheepdog/articles/frognet-workflow.md).
> Traduzido da versão 3.2.1 do pacote; se as duas divergirem, vale a
> versão em inglês.

Este artigo percorre as três etapas do sheepdog tal como usadas no
projeto FrogNet (anuros do Pantanal e do Cerrado, Mato Grosso do Sul,
Brasil). Os caminhos, os nomes dos locais e as espécies-núcleo vêm dos
scripts do FrogNet da v1.2.0; as configurações marcadas como “example”
são ilustrativas. Os dados do FrogNet não são distribuídos com o pacote,
de modo que os chunks que os leem não são executados; a última seção
roda com os arquivos de exemplo incluídos no pacote.

``` r

library(sheepdog)
```

## Etapa 1a: clipes para validar

A pasta de cada local contém um `BirdNET_SelectionTable.txt` que
concatena as predições do classificador customizado em todas as
gravações do local. Ele é gravado pela GUI do BirdNET quando a opção
“Combine selection tables” está marcada nas configurações de saída. Por
padrão, a GUI grava uma tabela por arquivo de áudio; o sheepdog também
lê essas tabelas e empilha as de cada pasta de local. As gravações ficam
em um NAS mapeado como `N:/` no Windows; no Mac, os mesmos caminhos são
remapeados.

Verifique primeiro a seleção com `simulate = TRUE`: o manifesto é
gravado, mas nenhum áudio é cortado.

``` r

extract_validation_clips(
  data_dir   = "N:/Arara",
  output_dir = "N:/Arara/validation",
  n_top = 2,                     # top 2 per site x species x night x hour
  min_confidence = 0.1,
  hour_start = 17, hour_end = 2, # example: nights, small hours go to the
  alternate_days = TRUE,         #   night before; alternate nights
  target_total = 4000,           # clips per site, balanced among species
  balance_by_hour = TRUE,
  remap_from = "N:/", remap_to = "/Volumes/Arara/",
  simulate = TRUE
)
```

Em seguida, rode novamente com `simulate = FALSE` (o padrão). Os clipes
vão para `validation/clips/<species>/`, um zip por espécie para
`validation/packages/`, e o mapeamento de cada clipe para sua origem
para `validation/clip_manifest.csv`. Uma nova execução pula os clipes já
cortados.

As etapas também podem ser executadas uma a uma.
[`select_clips()`](https://provetelab.org/sheepdog/reference/select_clips.md)
é pura: retorna o manifesto sem tocar no áudio, o que ajuda a testar
desenhos.

``` r

pred <- read_selection_tables("N:/Arara")
man  <- select_clips(pred, n_top = 2, target_total = 4000,
                     remap_from = "N:/", remap_to = "/Volumes/Arara/")
man  <- cut_clips(man, "N:/Arara/validation")
pack_clips(man, "N:/Arara/validation")
```

### Estimativa das taxas de falso positivo

O desenho `"top"` serve ao retreino e à calibração, não à estimativa das
taxas de falso positivo para modelos de ocupação. Para isso, sorteie
ocasiões ao acaso entre as que têm uma detecção, com o mesmo limiar da
análise de ocupação (desenho de confirmação de observações):

``` r

extract_validation_clips(
  "N:/Arara", "N:/Arara/validation_random",
  sampling_mode = "random_detections", threshold = 0.5,  # example values
  occasion_unit = "file", n_top = 1, target_total = 300,
  remap_from = "N:/", remap_to = "/Volumes/Arara/"
)
```

Toda detecção \>= 0,5 de uma ocasião sorteada é cortada, e o manifesto
registra `inclusion_prob`. Veja
[`vignette("crywolf-integration")`](https://provetelab.org/sheepdog/articles/crywolf-integration.md)
para a passagem aos modelos de ocupação.

## Etapa 1b: após a revisão

Os revisores classificam os clipes na aba de revisão da GUI do BirdNET,
que move cada clipe para as subpastas `Positive/` ou `Negative/`.

``` r

# a FrogNet run cut by v1.2.0: the old manifest is read as well
post_validation(
  review_dir    = "E:/validacao_UEMS_meta4000/clipes",
  manifest_path = "E:/validacao_UEMS_meta4000/manifesto_clipes.csv",
  output_dir    = "E:/validacao_UEMS_meta4000/results",
  target_precision = 0.90, min_n = 15
)
```

Isso grava `validation_by_clip.csv` (o veredito de cada clipe), a
precisão por classe de confiança, o menor limiar que atinge a
precisão-alvo por espécie, a presença confirmada por noite e os clipes
positivos para retreino.

## Etapa 2: calibração

Os clipes revisados de todos os locais calibram o score de confiança em
uma probabilidade de detecção verdadeira. No FrogNet, o manifesto do
local BEP saiu como `BEP2` e UEMS é abreviado como UEM; por isso,
`site_map` corrige os nomes.

``` r

dir_proj <- "~/Library/CloudStorage/Box-Box/Meus Artigos/2026-codigo FrogNet"
sites <- c("UEMS", "MIM", "ARA", "BAI", "XAR", "REF", "BEP")
res <- calibrate(
  validation_files  = file.path(dir_proj,
                                paste0("validacao_por_clipe_", sites, ".csv")),
  prediction_tables = c(
    UEM = file.path(dir_proj, "BirdNET_SelectionTable_UEMS.txt"),
    MIM = file.path(dir_proj, "BirdNET_SelectionTable_MIM.txt"),
    ARA = file.path(dir_proj, "BirdNET_SelectionTable_ARA.txt"),
    BAI = file.path(dir_proj, "BirdNET_SelectionTable_BAI.txt"),
    XAR = file.path(dir_proj, "BirdNET_SelectionTable_XAR.txt"),
    REF = file.path(dir_proj, "BirdNET_SelectionTable_REF.txt"),
    BEP = file.path(dir_proj, "BirdNET_SelectionTable_BEP.txt")),
  output_dir = "~/FrogNet_calibration",
  site_map   = c(BEP2 = "BEP", UEMS = "UEM"),
  p_min = 0.95, min_detections_night = 1
)
res$comparison
```

Os modelos candidatos vão de uma regressão logística sobre
logit(confiança) a um GLMM binomial com inclinações aleatórias por
espécie e um intercepto por local x espécie. Eles são comparados por
validação cruzada em 5 partições estratificada por local x espécie, e o
melhor é reajustado a todos os clipes. Verifique a comparação e as
curvas de calibração (`calibration_curves.png`) antes de usar as
probabilidades. As detecções calibradas de sete locais ocupam cerca de
700 MB; portanto, mantenha `output_dir` fora de uma pasta sincronizada.

`nightly_detection_history.csv` fornece, para cada local x espécie x
noite, o número de detecções com P(TP) \>= `p_min` e se a noite tem uma
detecção sob as regras de repetição k = 1, 2 e 3.

No FrogNet (2026), 6.304 clipes revisados (16 espécies x 7 locais) deram
uma AUC de 0,93 para o modelo hierárquico, contra 0,82 para o score
isolado, e cerca de 3,15 milhões de detecções foram pontuadas.

## Etapa 3: matrizes de comunidade

Ordenações (PCoA, NMDS, RDA) não têm uma camada que absorva falsos
positivos, de modo que a regra de entrada é estrita: pelo menos duas
detecções confiáveis na noite, apenas as espécies-núcleo (calibração
confiável em todos os locais) e células local x mês com pelo menos cinco
noites gravadas.

``` r

build_community_matrices(
  "~/FrogNet_calibration/nightly_detection_history.csv",
  "~/FrogNet_community_matrices",
  core_species = c("boa_ran", "den_nan", "phy_alb", "rhi_dip", "sci_nas",
                   "lep_pod", "lep_fus", "pse_par", "pit_azu", "lys_lim"),
  k_min = 2, min_nights_month = 5
)
```

As seis espécies com calibração problemática no FrogNet (`tra_typ`,
`boa_pun`, `den_min`, `sci_fuv`, `ade_dip`, `lep_ele`) ficam de fora;
use-as, no máximo, em uma análise de sensibilidade.

## Um exemplo executável

A tabela de validação de exemplo incluída no pacote vem de dados
simulados:

``` r

library(sheepdog)
val <- readr::read_csv(
  system.file("extdata", "validation_by_clip.csv", package = "sheepdog"),
  show_col_types = FALSE)
precision_by_bin(val, min_n = 3)
#> # A tibble: 4 × 8
#>   site  species_folder bin    n_reviewed n_positive precision precision_weighted
#>   <chr> <chr>          <fct>       <int>      <int>     <dbl>              <dbl>
#> 1 ARA   boa_ran        [0.5,…          3          1     0.333              0.375
#> 2 ARA   boa_ran        [0.6,…          2          1     0.5                0.5  
#> 3 ARA   boa_ran        [0.7,…          3          3     1                  1    
#> 4 ARA   boa_ran        [0.9,…          3          3     1                  1    
#> # ℹ 1 more variable: low_support <lgl>
nightly_presence(val)
#> # A tibble: 3 × 8
#>   site  species_folder    night n_clips n_reviewed n_positive presence 
#>   <chr> <chr>             <dbl>   <int>      <int>      <int> <chr>    
#> 1 ARA   boa_ran        20220110       3          3          3 confirmed
#> 2 ARA   boa_ran        20220111       4          3          1 confirmed
#> 3 ARA   boa_ran        20220115       5          5          4 confirmed
#> # ℹ 1 more variable: max_confidence_positive <dbl>
```
