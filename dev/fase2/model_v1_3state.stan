// Phase 2, two-stage v1 with persistent emission components: three hidden
// states per minute, no call (0), call in the low component of f1 (L) and
// call in the high component (H). Emission densities are fixed at stage 1
// (emissions_2stage_curiango.R): e0 for f0 and e1a, e1b for the two
// components of f1. Calling follows the v1 Markov term (rho); given a call,
// the component is H with probability inv_logit(xi) after no call or a gap,
// inv_logit(xi + tau_h) after a call in H, inv_logit(xi + tau_l) after a call
// in L. With tau_h = tau_l = 0 it reduces to model_v1_2stage.stan with the
// component weight of f1 estimated instead of fixed.
functions {
  real site_lik_3state(int first, int last, real eta_psi, vector eta_theta,
                       real rho, real xi, real tau_h, real tau_l,
                       vector e0, vector e1a, vector e1b, array[] int v,
                       array[] int adj) {
    real ah = 0;  // log P(scores 1..k, state_k = H | z = 1)
    real al = 0;  // L
    real a0 = 0;  // no call
    real lp0 = log1m_inv_logit(eta_psi);
    real lh = log_inv_logit(xi);
    real ll = log1m_inv_logit(xi);
    real lhh = log_inv_logit(xi + tau_h);
    real llh = log1m_inv_logit(xi + tau_h);
    real lhl = log_inv_logit(xi + tau_l);
    real lll = log1m_inv_logit(xi + tau_l);
    for (n in first:last) {
      real nh;
      real nl;
      real n0;
      real c = log_inv_logit(eta_theta[n]);
      real nc = log1m_inv_logit(eta_theta[n]);
      if (n == first || adj[n] == 0) {
        real prev = n == first ? 0 : log_sum_exp([ah, al, a0]');
        nh = prev + c + lh;
        nl = prev + c + ll;
        n0 = prev + nc;
      } else {
        real cr = log_inv_logit(eta_theta[n] + rho);
        real ncr = log1m_inv_logit(eta_theta[n] + rho);
        nh = log_sum_exp([ah + cr + lhh, al + cr + lhl, a0 + c + lh]');
        nl = log_sum_exp([ah + cr + llh, al + cr + lll, a0 + c + ll]');
        n0 = log_sum_exp([ah + ncr, al + ncr, a0 + nc]');
      }
      ah = v[n] == 0 ? negative_infinity() : nh + e1b[n];
      al = v[n] == 0 ? negative_infinity() : nl + e1a[n];
      a0 = v[n] == 1 ? negative_infinity() : n0 + e0[n];
      lp0 = v[n] == 1 ? negative_infinity() : lp0 + e0[n];
    }
    return log_sum_exp(log_inv_logit(eta_psi) + log_sum_exp([ah, al, a0]'), lp0);
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
  vector[N_occ] e1a;                        // log of the low component of f1
  vector[N_occ] e1b;                        // log of the high component of f1
}
parameters {
  vector[P_psi] beta;
  vector[P_theta] alpha;
  real rho;
  real xi;
  real tau_h;
  real tau_l;
}
model {
  vector[N_site] eta_psi = X * beta;
  vector[N_occ] eta_theta = D * alpha;
  beta[1] ~ normal(0, 1.5);
  alpha[1] ~ normal(0, 1.5);
  if (P_psi > 1) beta[2:P_psi] ~ normal(0, 2.5);
  if (P_theta > 1) alpha[2:P_theta] ~ normal(0, 2.5);
  rho ~ normal(0, 2.5);
  xi ~ normal(0, 1.5);
  tau_h ~ normal(0, 2.5);
  tau_l ~ normal(0, 2.5);
  for (i in 1:N_site) {
    target += site_lik_3state(first[i], last[i], eta_psi[i], eta_theta, rho,
                              xi, tau_h, tau_l, e0, e1a, e1b, v, adj);
  }
}
generated quantities {
  real psi_c = inv_logit(beta[1]);
  real theta0 = inv_logit(alpha[1]);
  real theta_bar = theta0 / (1 - inv_logit(alpha[1] + rho) + theta0);
  real p_h = inv_logit(xi);                 // H after no call or a gap
  real p_hh = inv_logit(xi + tau_h);        // H after H
  real p_hl = inv_logit(xi + tau_l);        // H after L
}
