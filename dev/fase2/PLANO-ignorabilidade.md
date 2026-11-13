# Simulação de ignorabilidade da seleção dos clipes (plano, 12/11/2026)

Passo 4 de `dev/dag/NOTAS-fase2.md` e linha "Simulação da ignorabilidade" da
fase 2 em `dev/roadmap-integration.md`. **Este plano é escrito antes de rodar
qualquer simulação; os critérios abaixo ficam fixos depois da aprovação do
Diogo.** Não depende da resposta da Liliana sobre o sorteio do Curiango.

## Pergunta

Num modelo que condiciona em todos os scores observados, escolher as ocasiões
verificadas em função do score é uma seleção ignorável (Rubin 1976), desde que
f₀ e f₁ estejam bem especificadas. A simulação mede:

1. se o v0 recupera ψ e θ quando a verificação é dirigida pelo score (PPS com
   π conhecido, como o `directed_pps`, e "top"), com f bem especificada;
2. quanto isso se perde quando f₀ e f₁ estão mal especificadas, que é o caso
   real no Curiango (a mistura bate a normal censurada; ver "Correção" no
   `README.md`);
3. o tamanho do viés quando a seleção **não** é ignorável: por uma covariável
   que afeta θ mas fica fora do modelo (a hora, no Curiango), ou pelo próprio
   estado w (alguém ouviu o minuto antes de incluí-lo).

Rhinehart et al. anotam um subconjunto aleatório e sugerem dirigir a escuta
para os scores altos como extensão futura (p. 1787); os itens 1 e 2 respondem
a isso.

## Desenho

### Dados simulados

Base no `simulate_v0()`, com uma covariável nova de ocasião, `h`, binária
("início da noite", 25% das ocasiões), que entra em θ:
logit θ_ik = α₀ + α₁ d_ik + α_h h_ik, com α_h = 1.

- 150 sítios × 20 ocasiões; ψ = 0,5 no centro (β = (0; −0,8)); θ = 0,3 no
  centro (α₀ = logit 0,3; α₁ = 0,6).
- c = logit(0,1) (corte já validado; a insensibilidade a c não é refeita).
- **Verdade das emissões (2 níveis):**
  - *normal*: valores do piloto do v0 no Curiango, λ₀ = −2,16, Δ = 1,29,
    σ₀ = 0,35, σ₁ = 1,49. Classificador fraco, com metade de f₀ abaixo de c.
  - *mistura*: f₀ = 0,85 N(−2,2; 0,26) + 0,15 N(−2,2; 0,61);
    f₁ = 0,78 N(−1,45; 0,41) + 0,22 N(0,91; 1,42). Médias e σ de f₀ vêm da
    etapa 0 com pesos (provisória); os σ de f₁ vêm do ajuste sem pesos. É uma
    forma plausível de má especificação, não uma estimativa do Curiango.
- **Fração verificada (2 níveis):** 5% e 2% das ocasiões (150 e 60). Com 2% e
  θ = 0,3 esperam-se perto de 9 positivos verificados por conjunto.

Cada conjunto (verdade × réplica) é simulado uma vez, e todos os desenhos de
seleção são aplicados aos mesmos dados: a comparação entre desenhos é pareada.

### Desenhos de seleção (o número de ocasiões verificadas é o mesmo em todos)

| Código | Desenho | Ignorável para o modelo? |
|---|---|---|
| S1 | aleatório simples | sim |
| S2 | PPS sistemático por ocasião, tamanho = plogis(max(s, c)) + piso de 5% da média, π conhecido | sim, se f está certa |
| S3 | "top": as n ocasiões de maior score | sim, se f está certa |
| S4 | PPS pela hora: peso 3 se h = 1, 1 caso contrário (razão parecida com a do Curiango) | sim se h está em θ; não se h fica fora |
| S5 | pelo estado: peso 5 se w = 1, 1 caso contrário | não |

S2 simplifica o `directed_pps` (uma ocasião por unidade): aqui o sorteio é por
ocasião, porque o v0 não tem a unidade sítio × espécie × mês. O ajuste não usa
π em nenhum desenho; π só é guardado.

### Ajustes

Modelo v0 (`model_v0.stan`, prior C), com θ ~ d + h, salvo onde indicado.

| Braço | Desenhos | θ no modelo |
|---|---|---|
| principal | S1 a S5 | d + h |
| omissão de h | S1 e S4 | d |
| referência | sem verificação | d + h |

Por conjunto: 2 frações × 7 ajustes + 1 sem verificação = 15 ajustes.
**50 réplicas** por verdade: 2 × 50 × 15 = **1.500 ajustes**. Pela validação
do v0 (cerca de 3 min por ajuste em 150 × 20), perto de **75 h de CPU**: vai
para a AWS (`dev/fase2/aws/`), depois do piloto.

Semente: 2026 combinada com o id da tarefa; a seleção usa um fluxo próprio, de
modo que mudar um desenho não muda os dados.

## Critérios (fixados antes de rodar)

Intervalos de 95%; viés na escala de probabilidade; ψ e θ no centro das
covariáveis (h = 0). Com 50 réplicas, o erro-padrão de Monte Carlo da
cobertura é cerca de 0,03 perto de 0,95; isso é relatado junto.

| # | Critério | Limiar | Papel |
|---|---|---|---|
| I1 | Convergência, por célula | ≥ 95% dos ajustes com R-hat < 1,01 e sem divergências | bloqueia a leitura da célula |
| I2 | Controle: verdade normal, S1 a S4 com h no modelo | cobertura ≥ 0,90 e \|viés\| ≤ 0,05 em ψ e θ | se reprovar, há defeito no v0 ou no simulador; nada mais se interpreta |
| I3 | Seleção pelo score sob má especificação: verdade mistura, S2 e S3 | mesmo limiar de I2, e viés de S2/S3 menos o de S1 (pareado) ≤ 0,05 | decide a recomendação abaixo |
| I4 | Seleção não ignorável: S4 sem h e S5 | relatado (viés, cobertura, diferença pareada para S1); não bloqueia | mostra o que o `inclusion_prob` e o `sampling_mode` têm de proteger |
| I5 | Sem verificação | relatado; não bloqueia | mostra o quanto ψ e θ dependem da forma de f |

β₁, α₁, α_h e as emissões são relatados, sem entrar na decisão.

**Decisão sobre a recomendação (vai para a vinheta do `fp_occu_score()`):**

- I2 e I3 passam: verificar por score é seguro com este modelo, mesmo com f
  mal especificada nesta forma; o `directed_pps` pode ser o desenho padrão.
- I2 passa e I3 reprova só em S3: PPS sim, "top" não.
- I2 passa e I3 reprova em S2 e S3: a seleção pelo score só vale com f bem
  especificada; recomenda-se a camada aleatória (fase 3, validação em duas
  camadas) e o PPC por classe (critério 6) antes de confiar em θ.

## Etapas

| # | Etapa | Onde | Duração | Segue se |
|---|---|---|---|---|
| 0 | `sim_ignorab.R`: simulador com h e mistura, e as cinco seleções. Testes: tamanho da amostra igual entre desenhos, frequências do PPS batem com π em 4.000 sorteios, mesma semente dá os mesmos dados | Mac | minutos | testes passam |
| 1 | Piloto: 1 réplica de cada braço nas duas verdades (30 ajustes), 10 workers | Mac | ~10 a 15 min | sem erros; tempo por ajuste medido; estimativa de custo refeita |
| 2 | Rodada completa (1.500 ajustes), retomável por tarefa como `run_val2_v0.R` | AWS spot | ~75 h de CPU (refazer após o piloto) | aprovação do Diogo com o custo do piloto |
| 3 | `summarise_ignorab.R`: tabela por célula e critério; figura de viés pareado por desenho | Mac | minutos | |

## Limites conhecidos

- Sem Markov dentro da noite (o v0 não tem; o v1 vem depois). Ocasiões são
  independentes dado w.
- Uma só forma de má especificação. Passar em I3 não garante nada para outras
  formas; reprovar já basta para recomendar a camada aleatória.
- O modelo com mistura (`model_mix.stan`) não entra: a simulação de
  identificação dele está suspensa até saber como o teste do Curiango foi
  sorteado.
- 150 × 20 é bem menor que o Curiango (97.806 minutos); a fração verificada é
  maior para compensar o número de positivos.
- Os mesmos conjuntos simulados servem depois ao passo 5 (reimplementar
  Rhinehart et al. e Ogawa et al.).

## Etapas 0 e 1 feitas (12/11/2026)

- `sim_ignorab.R` (simulador, seleções, dados do Stan, grade e sementes) e
  `check_ignorab.R`: todas as conferências passam. Tamanho igual nos cinco
  desenhos; frequências do PPS a ≤ 0,016 de π em 4.000 sorteios; 19,4% de
  ocasiões com chamada, 41% censuradas, cerca de 12 positivos verificados
  com 2% ao acaso (não 9, como estimado acima).
- `run_ignorab.R` e `summarise_ignorab.R`; o lançador da AWS agora recebe o
  script e os argumentos extras (`launch.sh ... [script] [extra]`).
- **Piloto:** 30 ajustes (1 réplica de cada braço), nenhum erro, todos
  convergidos (R-hat < 1,01, sem divergências). Mediana de 178 s por ajuste
  (máximo 225 s), 1,53 h de CPU. A rodada completa fica em cerca de 75 h de
  CPU, como estimado. **Uma réplica não mede viés nem cobertura; os números
  do piloto não são interpretados.**
- Nota para o resumo: nos braços sem h, α₀ estima θ médio sobre h, não θ em
  h = 0, então o viés contra 0,3 é esperado também em S1 sem h. Para I4 vale
  a diferença pareada para S1 sem h, que o `summarise_ignorab.R` já calcula.

## Etapas 2 e 3: resultados (13/11/2026)

Rodada completa na AWS (spot; c6i.16xlarge interrompida duas vezes,
concluída numa c6a.8xlarge, retomando das tarefas salvas): 1.500 ajustes,
nenhum erro, mediana de 143 s por ajuste, 62,9 h de CPU. Resultados em
`results/ignorab_v0/` (`task_all.rds` e `summary.txt`, saída de
`summarise_ignorab.R`). Com 50 réplicas, o erro-padrão de Monte Carlo da
cobertura é cerca de 0,03 perto de 0,95 e cerca de 0,05 perto de 0,80.

| # | Resultado | Situação |
|---|---|---|
| I1 | 30 de 30 células com ≥ 95% dos ajustes convergidos | passa |
| I2 | 16 de 16 células (verdade normal, S1 a S4 com h): \|viés\| ≤ 0,007 e cobertura ≥ 0,94 em ψ e θ | passa |
| I3 | 4 de 8 células: ψ passa nas quatro (S2 e S3, 5% e 2%); θ reprova nas quatro, pela cobertura | **reprova em S2 e S3** |
| I4 | S5 enviesa θ (diferença pareada para S1 de 0,071 com 5% e 0,038 com 2%, verdade normal; cobertura 0,14 e 0,74). S4 sem h: diferença pareada para S1 sem h ≤ 0,014. ψ quase não muda | relatado |
| I5 | Sem verificação, θ é recuperado na verdade normal (viés 0,005; cobertura 0,98); na mistura, viés −0,019 e cobertura 0,78 | relatado |

**θ na verdade mistura (I3):**

| Fração | Desenho | Viés | Cobertura | Diferença pareada para S1 |
|---|---|---|---|---|
| 5% | S1 | −0,020 | 0,78 | — |
| 5% | S2 | −0,012 | 0,86 | 0,008 |
| 5% | S3 | −0,048 | 0,56 | −0,029 |
| 2% | S1 | −0,019 | 0,80 | — |
| 2% | S2 | −0,015 | 0,84 | 0,004 |
| 2% | S3 | −0,019 | 0,80 | 0,000 |
| — | sem verificação | −0,019 | 0,78 | — |

**Pela regra fixada antes de rodar**, o caso é "I2 passa e I3 reprova em S2
e S3": a seleção pelo score só vale com f bem especificada; recomenda-se a
camada aleatória (fase 3) e o PPC por classe (critério 6) antes de confiar
em θ.

**O que a regra não previa (interpretação, para o Diogo decidir):**

- A subcobertura de θ sob a mistura não vem da seleção. S1 (aleatório) e o
  ajuste sem verificação têm a mesma cobertura (0,78 a 0,80) e o mesmo viés
  (cerca de −0,02). As diferenças pareadas de S2 para S1 ficam em 0,008 ou
  menos, e a cobertura de S2 é até maior que a de S1. Quem reprova é a
  normal censurada mal especificada, com qualquer desenho.
- Logo, a camada aleatória, sozinha, não resolveria: S1 é justamente a
  verificação aleatória e reprova igual. O que protege θ é o PPC por classe
  (detectar a má especificação) e um modelo de emissões mais flexível
  (`model_mix.stan`), não o desenho da verificação.
- Com 5% a 2% verificados, a verificação quase não informa θ além da forma
  de f: o ajuste sem verificação dá o mesmo resultado que S1. Isso vale para
  este cenário (150 × 20, classificador fraco); com mais positivos
  verificados pode mudar.
- "Top" (S3) é pior que PPS (S2) com 5%: viés −0,048, no limite, e
  cobertura 0,56. Com 2% os dois são parecidos. PPS sim, "top" não.
- Seleção pelo estado (S5) enviesa θ para cima mesmo com f certa, como
  esperado; ψ quase não muda.
- 0,86 e 0,84 (S2) estão a cerca de um erro-padrão de Monte Carlo de 0,90;
  com 50 réplicas, a reprovação de S2 por cobertura é frágil. A de S3 com
  5% não é.

Proposta, a confirmar: manter a recomendação de PPS (`directed_pps`) e não
"top"; condicionar a confiança em θ ao PPC por classe; e retomar a
simulação de identificação do `model_mix.stan` como o próximo passo
para θ, antes da camada aleatória.
