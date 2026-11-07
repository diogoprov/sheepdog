# Environment for dev/fase2/run_val2_v0.R on EC2 (recipe of crywolf dev/dyn-sim/aws).
# The checkout is mounted at /project when the container runs.
FROM rocker/r-ver:4.6.1

RUN apt-get update && apt-get install -y --no-install-recommends \
      ca-certificates curl libcurl4-openssl-dev libssl-dev libxml2-dev \
    && rm -rf /var/lib/apt/lists/*

# one Stan fit per core: BLAS threads would only compete with the other workers
ENV OPENBLAS_NUM_THREADS=1 \
    OMP_NUM_THREADS=1 \
    CMDSTAN=/opt/cmdstan/cmdstan-2.40.0 \
    MAKEFLAGS="-j16"

RUN R -q -e 'install.packages(c("posterior", "remotes"))' \
 && R -q -e 'install.packages("cmdstanr", repos = c("https://stan-dev.r-universe.dev", getOption("repos")))'
RUN mkdir -p /opt/cmdstan \
 && R -q -e 'cmdstanr::install_cmdstan(dir = "/opt/cmdstan", version = "2.40.0", cores = 32, quiet = TRUE)'

WORKDIR /project
