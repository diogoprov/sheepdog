// Phase 2 prototype: v0 with a two-component normal mixture in each class,
// after stage 0 of the Curiango step. f0: same mean, a core and a wider tail.
// f1: a low and a high component, ordered above mu0. Priors are provisional.
functions {
#include score_emissions_mix.stanfunctions
}
data {
  int<lower=1> N_site;
  int<lower=1> N_occ;                       // sorted by site
  array[N_site] int<lower=1> first;
  array[N_site] int<lower=1> last;
  int<lower=1> P_psi;
  matrix[N_site, P_psi] X;
  int<lower=1> P_theta;
  matrix[N_occ, P_theta] D;
  vector[N_occ] s;                          // logit score; ignored if censored
  array[N_occ] int<lower=0, upper=2> cens;
  array[N_occ] int<lower=-1, upper=1> v;    // -1 not verified
  real c_lo;
  real c_hi;
}
parameters {
  vector[P_psi] beta;
  vector[P_theta] alpha;
  real lambda0;                             // mean of f0
  real<lower=0> sigma0;                     // core of f0
  real<lower=0> tail0;                      // sd of the tail = sigma0 + tail0
  real<lower=0, upper=1> pi0;               // share of the core
  real<lower=0> d1;                         // low component = lambda0 + d1
  real<lower=0> gap;                        // high component = low + gap
  real<lower=0> sigma1a;
  real<lower=0> sigma1b;
  real<lower=0, upper=1> pi1;               // share of the low component
}
transformed parameters {
  real mu1a = lambda0 + d1;
  real mu1b = mu1a + gap;
  real sigma0b = sigma0 + tail0;
}
model {
  vector[N_site] eta_psi = X * beta;
  vector[N_occ] eta_theta = D * alpha;
  vector[N_occ] e0 = emission_mix(s, cens, pi0, lambda0, sigma0, lambda0, sigma0b, c_lo, c_hi);
  vector[N_occ] e1 = emission_mix(s, cens, pi1, mu1a, sigma1a, mu1b, sigma1b, c_lo, c_hi);
  beta[1] ~ normal(0, 1.5);
  alpha[1] ~ normal(0, 1.5);
  if (P_psi > 1) beta[2:P_psi] ~ normal(0, 2.5);
  if (P_theta > 1) alpha[2:P_theta] ~ normal(0, 2.5);
  lambda0 ~ normal(-3, 2);
  sigma0 ~ lognormal(0, 0.75);
  tail0 ~ lognormal(0, 0.75);
  pi0 ~ beta(4, 1);
  d1 ~ lognormal(0, 0.75);
  gap ~ lognormal(log(2), 0.75);
  sigma1a ~ lognormal(0, 0.75);
  sigma1b ~ lognormal(0, 0.75);
  pi1 ~ beta(2, 2);
  for (i in 1:N_site) {
    target += site_lik_e(first[i], last[i], eta_psi[i], eta_theta, e0, e1, v);
  }
}
generated quantities {
  vector[N_site] log_lik;
  {
    vector[N_site] eta_psi = X * beta;
    vector[N_occ] eta_theta = D * alpha;
    vector[N_occ] e0 = emission_mix(s, cens, pi0, lambda0, sigma0, lambda0, sigma0b, c_lo, c_hi);
    vector[N_occ] e1 = emission_mix(s, cens, pi1, mu1a, sigma1a, mu1b, sigma1b, c_lo, c_hi);
    for (i in 1:N_site) {
      log_lik[i] = site_lik_e(first[i], last[i], eta_psi[i], eta_theta, e0, e1, v);
    }
  }
}
