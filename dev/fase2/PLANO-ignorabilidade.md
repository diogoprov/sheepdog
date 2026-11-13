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
