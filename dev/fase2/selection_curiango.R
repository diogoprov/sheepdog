# Inclusion of the verified minutes by score, and estimates weighted by the
# inverse of the inclusion rate in two strata of the custom score (cut at 0.5).
m<-crywolf::curiango$minutes; v<-crywolf::curiango$verified
k<-paste(m$site_night,m$time); i<-match(k,paste(v$site_night,v$time)); m$ver<-!is.na(i); m$y<-v$y[i]
g<-glm(ver~I(conf_custom>=.5)+I(conf_birdnet>=.5),binomial,m); print(round(summary(g)$coefficients,2))
print(with(m,round(tapply(ver,list(custom=conf_custom>=.5,birdnet=conf_birdnet>=.5),mean),3)))
print(with(m,table(custom=conf_custom>=.5,birdnet=conf_birdnet>=.5)))
fine<-cut(m$conf_custom,c(.3,.4,.45,.48,.5,.52,.55,.6,.8,1)); print(round(tapply(m$ver,fine,mean),3))
# weights: inverse inclusion in two strata of the custom score
hi<-m$conf_custom>=.5; r0<-mean(m$ver[!hi]); r1<-mean(m$ver[hi]); cat("rates",r0,r1,"expected at r0 among high",sum(hi)*r0,"seen",sum(m$ver[hi]),"\n")
w<-ifelse(hi,1/r1,1/r0)[m$ver]; y<-m$y[m$ver]; cf<-m$conf_custom[m$ver]
cat("weighted P(w=1)",sum(w*y)/sum(w)," unweighted",mean(y),"\n")
for(t in c(.1,.2,.3,.4,.5,.7,.9)) cat("t",t,"precision w",round(sum((w*y)[cf>=t])/sum(w[cf>=t]),3),"raw",round(mean(y[cf>=t]),3),"| recall w",round(sum((w*y)[cf>=t])/sum(w*y),3),"raw",round(mean(cf[y==1]>=t),3),"\n")
lg<-qlogis(pmax(cf,1e-9)); wq<-function(x,w,p){o<-order(x);x[o][which(cumsum(w[o])/sum(w)>=p)[1]]}
u<-y==1; cat("true class weighted q10/50/90",round(sapply(c(.1,.5,.9),\(p)wq(lg[u],w[u],p)),2),"\n")
print(round(tapply(w[u],cut(lg[u],seq(-3,6,1)),sum)/sum(w[u]),3))
f<-y==0&cf>0; cat("false weighted uncens q",round(sapply(c(.1,.5,.9),\(p)wq(lg[f],w[f],p)),2),"\n")
