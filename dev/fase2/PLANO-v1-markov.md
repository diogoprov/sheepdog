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
