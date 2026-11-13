// Phase 2, two-stage v1: the emissions are fixed at stage 1 estimates
// (emissions_2stage_curiango.R), passed as per-occasion log densities e0 and
// e1; only occupancy, calling and the Markov term are estimated. With
// markov = 0 the Markov term is dropped (rho = 0) and theta0 = theta_bar.
// With night_re = 1, the calling rate gets a random effect of the calendar
// night (shared by the sites recorded that night), non-centred; theta0 and
// theta_bar are then at the median night (u = 0).
functions {
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
  array[N_occ] int<lower=-1, upper=1> v;    // -1 not verified
  array[N_occ] int<lower=0, upper=1> adj;   // previous occasion is one step back
  vector[N_occ] e0;                         // log f0(score), fixed
  vector[N_occ] e1;                         // log f1(score), fixed
  int<lower=0, upper=1> markov;
  int<lower=0, upper=1> night_re;
  int<lower=1> N_night;
  array[N_site] int<lower=1, upper=N_night> night;  // calendar night of each site
}
parameters {
  vector[P_psi] beta;
  vector[P_theta] alpha;
  array[markov] real rho;
  array[night_re] real<lower=0> sigma_night;
  vector[night_re == 1 ? N_night : 0] u_night;
}
transformed parameters {
  real r = markov == 1 ? rho[1] : 0;
}
model {
  vector[N_site] eta_psi = X * beta;
  vector[N_occ] eta_theta = D * alpha;
  if (night_re == 1) {
    for (i in 1:N_site) {
      eta_theta[first[i]:last[i]] += sigma_night[1] * u_night[night[i]];
    }
    u_night ~ std_normal();
    sigma_night ~ normal(0, 1);
  }
  beta[1] ~ normal(0, 1.5);
  alpha[1] ~ normal(0, 1.5);
  if (P_psi > 1) beta[2:P_psi] ~ normal(0, 2.5);
  if (P_theta > 1) alpha[2:P_theta] ~ normal(0, 2.5);
  rho ~ normal(0, 2.5);
  for (i in 1:N_site) {
    target += site_lik_markov(first[i], last[i], eta_psi[i], eta_theta, r, e0, e1, v, adj);
  }
}
generated quantities {
  real psi_c = inv_logit(beta[1]);
  real theta0 = inv_logit(alpha[1]);
  real theta_bar = theta0 / (1 - inv_logit(alpha[1] + r) + theta0);
}
