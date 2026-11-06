# Decomposes the failures of criterion 1 and the coverage of criterion 2.
#   Rscript dev/fase2/diagnose_val_v0.R OUT_DIR
suppressPackageStartupMessages(library(dplyr))
out <- commandArgs(TRUE)[1]
d <- bind_rows(lapply(list.files(out,"^task_.*rds$",full.names=TRUE),readRDS)) |>
  mutate(main = theta>0.1 & frac>0)
f <- d |> group_by(main,theta,frac,delta,cut,id) |>
  summarise(maxr=max(rhat), miness=min(ess_bulk), dv=first(divergent),
            worst=variable[which.max(rhat)], .groups="drop") |>
  mutate(r_bad=maxr>=1.01, d_bad=dv>0)
m <- filter(f,main)
cat("== main: causa da reprovacao por delta x cut ==\n")
m |> group_by(delta,cut) |> summarise(n=n(), pass=mean(!r_bad&!d_bad), r_bad=mean(r_bad), d_bad=mean(d_bad),
   med_dv_when_bad=median(dv[d_bad]), max_dv=max(dv), maxr=max(maxr), p95r=quantile(maxr,.95), min_ess=min(miness), .groups="drop") |> as.data.frame() |> print(digits=3)
cat("\n== parametro de pior rhat nos ajustes com r_bad ==\n"); print(table(m$worst[m$r_bad], m$cut[m$r_bad]))
cat("\n== divergencias: fracao de transicoes (de 2000) ==\n")
print(quantile(m$dv[m$d_bad]/2000, c(.5,.9,1)))
cat("\n== rhat por parametro, main, 95o pct ==\n")
d |> filter(main) |> rename(D=delta) |> group_by(variable,D,cut) |> summarise(p95=quantile(rhat,.95), .groups="drop") |>
  tidyr::pivot_wider(names_from=variable, values_from=p95) |> as.data.frame() |> print(digits=3)
cat("\n== posteriores das emissoes, main ==\n")
tr <- function(v,dl) case_when(v=="lambda0"~-4, v=="delta"~dl, TRUE~1.5)
d |> filter(main, variable %in% c("lambda0","delta","sigma0","sigma1")) |> mutate(t=tr(variable,delta)) |>
  group_by(variable,delta,cut) |> summarise(bias=mean(mean-t), width=mean(hi-lo), cov=mean(lo<=t&t<=hi), .groups="drop") |> as.data.frame() |> print(digits=3)
p <- d |> filter(main, variable %in% c("beta[1]","alpha[1]")) |>
  mutate(par=ifelse(variable=="beta[1]","psi","theta"), tr=ifelse(par=="psi",.5,theta),
         cov=plogis(lo)<=tr & tr<=plogis(hi), w=plogis(hi)-plogis(lo)) |>
  left_join(select(f,id,cut,r_bad,d_bad),by=c("id","cut")) |> mutate(ok=!r_bad&!d_bad)
cat("\n== cobertura: aprovados x reprovados no crit. 1 ==\n")
p |> group_by(par,ok) |> summarise(n=n(),cov=mean(cov),w=mean(w),.groups="drop") |> as.data.frame() |> print(digits=3)
cat("\n== celulas de cobertura<0.90, por corte, e EP por conjunto (cluster) ==\n")
cc <- p |> group_by(par,theta,frac,delta) |> summarise(cov=mean(cov), .groups="drop") |> filter(cov<.9)
print(as.data.frame(cc),digits=3)
for(i in seq_len(nrow(cc))){ x <- semi_join(p,cc[i,],by=c("par","theta","frac","delta"))
 print(as.data.frame(x |> group_by(cut) |> summarise(n=n(),cov=mean(cov),.groups="drop")),digits=3)
 s <- x |> group_by(id) |> summarise(c=mean(cov)); cat("EP cluster:",round(sd(s$c)/sqrt(nrow(s)),3)," sets com alguma falha:",sum(s$c<1),"de",nrow(s),"\n")}
cat("\n== cobertura geral main por par, so c=0.1 por celula ==\n")
p |> filter(cut==.1) |> group_by(par,theta,frac,delta) |> summarise(cov=mean(cov),.groups="drop") |> as.data.frame() |> print(digits=3)
