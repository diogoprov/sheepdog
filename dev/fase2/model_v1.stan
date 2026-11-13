// Phase 2, v1: model_mix.stan with a first-order Markov term on the latent
// call w within the night. In an occupied site, logit P(w_k = 1) =
// eta_k + rho * w_{k-1} when occasion k - 1 is the previous step of the same
// site (adj[k] = 1), and eta_k on the first occasion and after a gap. With
// rho = 0 it reduces to model_mix.stan. Emission priors as in model_mix.stan
// (provisional); rho ~ normal(0, 2.5).
functions {
#include score_emissions_mix.stanfunctions
  real site_lik_markov(int first, int last, real eta_psi, vector eta_theta,
                       real rho, vector e0, vector e1, array[] int v,
                       array[] int adj) {
    real a1 = 0;  // log P(scores 1..k, w_k = 1 | z = 1)
    real a0 = 0;  // log P(scores 1..k, w_k = 0 | z = 1)
    real lp0 = log1m_inv_logit(eta_psi);
    for (n in first:last) {
      real n1;
      real n0;
      if (n == first || adj[n] == 0) {
        real prev = n == first ? 0 : log_sum_exp(a1, a0);
        n1 = prev + log_inv_logit(eta_theta[n]);
        n0 = prev + log1m_inv_logit(eta_theta[n]);
      } else {
        n1 = log_sum_exp(a1 + log_inv_logit(eta_theta[n] + rho),
                         a0 + log_inv_logit(eta_theta[n]));
        n0 = log_sum_exp(a1 + log1m_inv_logit(eta_theta[n] + rho),
                         a0 + log1m_inv_logit(eta_theta[n]));
      }
      a1 = v[n] == 0 ? negative_infinity() : n1 + e1[n];
      a0 = v[n] == 1 ? negative_infinity() : n0 + e0[n];
      lp0 = v[n] == 1 ? negative_infinity() : lp0 + e0[n];
    }
    return log_sum_exp(log_inv_logit(eta_psi) + log_sum_exp(a1, a0), lp0);
  }
}
data {
  int<lower=1> N_site;
  int<lower=1> N_occ;                       // sorted by site, then time
  array[N_site] int<lower=1> first;
  array[N_site] int<lower=1> last;
  int<lower=1> P_psi;
  matrix[N_site, P_psi] X;
  int<lower=1> P_theta;
  matrix[N_occ, P_theta] D;
  vector[N_occ] s;                          // logit score; ignored if censored
  array[N_occ] int<lower=0, upper=2> cens;
  array[N_occ] int<lower=-1, upper=1> v;    // -1 not verified
  array[N_occ] int<lower=0, upper=1> adj;   // previous occasion is one step back
  real c_lo;
  real c_hi;
}
parameters {
  vector[P_psi] beta;
  vector[P_theta] alpha;
  real rho;
  real lambda0;
  real<lower=0> sigma0;
  real<lower=0> tail0;
  real<lower=0, upper=1> pi0;
  real<lower=0> d1;
  real<lower=0> gap;
  real<lower=0> sigma1a;
  real<lower=0> sigma1b;
  real<lower=0, upper=1> pi1;
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
  rho ~ normal(0, 2.5);
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
    target += site_lik_markov(first[i], last[i], eta_psi[i], eta_theta, rho, e0, e1, v, adj);
  }
}
generated quantities {
  // calling rate at the centre of the covariates: after a gap (theta0) and
  // stationary within a run of adjacent occasions (theta_bar)
  real theta0 = inv_logit(alpha[1]);
  real theta_bar = theta0 / (1 - inv_logit(alpha[1] + rho) + theta0);
  vector[N_site] log_lik;
  {
    vector[N_site] eta_psi = X * beta;
    vector[N_occ] eta_theta = D * alpha;
    vector[N_occ] e0 = emission_mix(s, cens, pi0, lambda0, sigma0, lambda0, sigma0b, c_lo, c_hi);
    vector[N_occ] e1 = emission_mix(s, cens, pi1, mu1a, sigma1a, mu1b, sigma1b, c_lo, c_hi);
    for (i in 1:N_site) {
      log_lik[i] = site_lik_markov(first[i], last[i], eta_psi[i], eta_theta, rho, e0, e1, v, adj);
    }
  }
}
