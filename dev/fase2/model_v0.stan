// Phase 2 prototype, model v0: joint score-occupancy model with one score
// per occasion (the structure of Rhinehart et al. 2022 at the occasion
// level). z and w are marginalized. No Markov term, no covariates on the
// score distributions. See dev/fase2/README.md.
functions {
#include score_emissions.stanfunctions
}
data {
  int<lower=1> N_site;
  int<lower=1> N_occ;                       // sorted by site
  array[N_site] int<lower=1> first;
  array[N_site] int<lower=1> last;
  int<lower=1> P_psi;                       // first column is the intercept
  matrix[N_site, P_psi] X;
  int<lower=1> P_theta;                     // first column is the intercept
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
  real lambda0;                             // mu0
  real<lower=0> delta;                      // mu1 = mu0 + delta
  real<lower=0> sigma0;
  real<lower=0> sigma1;
}
transformed parameters {
  real mu1 = lambda0 + delta;
  vector[2] lcens0 = [normal_lcdf(c_lo | lambda0, sigma0),
                      normal_lccdf(c_hi | lambda0, sigma0)]';
  vector[2] lcens1 = [normal_lcdf(c_lo | mu1, sigma1),
                      normal_lccdf(c_hi | mu1, sigma1)]';
}
model {
  vector[N_site] eta_psi = X * beta;
  vector[N_occ] eta_theta = D * alpha;
  beta[1] ~ normal(0, 1.5);
  alpha[1] ~ normal(0, 1.5);
  if (P_psi > 1) beta[2:P_psi] ~ normal(0, 2.5);
  if (P_theta > 1) alpha[2:P_theta] ~ normal(0, 2.5);
  // provisional: logit scale, to be set by a prior predictive check
  lambda0 ~ normal(-3, 3);
  delta ~ normal(0, 5);
  sigma0 ~ normal(0, 3);
  sigma1 ~ normal(0, 3);
  for (i in 1:N_site) {
    target += site_lik(first[i], last[i], eta_psi[i], eta_theta, s, cens, v,
                       lambda0, mu1, sigma0, sigma1, lcens0, lcens1);
  }
}
generated quantities {
  vector[N_site] log_lik;
  {
    vector[N_site] eta_psi = X * beta;
    vector[N_occ] eta_theta = D * alpha;
    for (i in 1:N_site) {
      log_lik[i] = site_lik(first[i], last[i], eta_psi[i], eta_theta, s, cens,
                            v, lambda0, mu1, sigma0, sigma1, lcens0, lcens1);
    }
  }
}
