// Phase 2, v1 with informative priors on f1: model_v1.stan with the f1
// mixture parametrised as u = (logit pi1, mu1a, log gap, log sigma1a,
// log sigma1b) and u ~ multi_normal(u_mu, u_Sigma), from the night bootstrap
// of the stage 1 emissions on the random draw (ct01 + ct02, option (a) of
// 19/11/2026). Meant to be run with v = -1 everywhere: the labels enter only
// through the prior, so they are not counted twice. f0 keeps the priors of
// model_v1.stan. Other parts as in model_v1.stan.
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
  vector[5] u_mu;
  cov_matrix[5] u_Sigma;
}
parameters {
  vector[P_psi] beta;
  vector[P_theta] alpha;
  real rho;
  real lambda0;
  real<lower=0> sigma0;
  real<lower=0> tail0;
  real<lower=0, upper=1> pi0;
  vector[5] u;
}
transformed parameters {
  real pi1 = inv_logit(u[1]);
  real mu1a = u[2];
  real mu1b = u[2] + exp(u[3]);
  real sigma1a = exp(u[4]);
  real sigma1b = exp(u[5]);
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
  u ~ multi_normal(u_mu, u_Sigma);
  for (i in 1:N_site) {
    target += site_lik_markov(first[i], last[i], eta_psi[i], eta_theta, rho, e0, e1, v, adj);
  }
}
generated quantities {
  // calling rate at the centre of the covariates: after a gap (theta0) and
  // stationary within a run of adjacent occasions (theta_bar)
  real psi_c = inv_logit(beta[1]);
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
