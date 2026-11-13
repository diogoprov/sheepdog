#!/bin/bash
# EC2 user data (Amazon Linux 2023). __BUCKET__, __RUN__, __WORKERS__ and
# __MAX_HOURS__, __SCRIPT__ and __EXTRA__ are filled in by launch.sh. Runs the validation, resuming from
# the task files in S3, checkpoints every 5 min and on a spot notice, writes a
# DONE or FAILED marker and terminates the instance.
set -uxo pipefail
BUCKET=__BUCKET__; RUN=__RUN__; WORKERS=__WORKERS__; MAX_HOURS=__MAX_HOURS__
SCRIPT=__SCRIPT__; EXTRA="__EXTRA__"
# watchdog: terminate after MAX_HOURS whatever happens (shutdown = terminate)
shutdown -h +$((MAX_HOURS * 60))
WORK=/opt/fase2; OUT=dev/fase2/results/${RUN}
S3=s3://${BUCKET}/fpcalib/runs/${RUN}
meta() {
  T=$(curl -s -X PUT http://169.254.169.254/latest/api/token \
    -H "X-aws-ec2-metadata-token-ttl-seconds: 300")
  curl -s "$@" -H "X-aws-ec2-metadata-token: ${T}" \
    http://169.254.169.254/latest/meta-data/${P}
}
P=instance-id; ID=$(meta)
LOG=${WORK}/run.log
dnf install -y docker
systemctl start docker
mkdir -p ${WORK}
aws s3 cp ${S3}/code.tar.gz /tmp/code.tar.gz
tar xzf /tmp/code.tar.gz -C ${WORK}
mkdir -p ${WORK}/${OUT}
aws s3 sync ${S3}/tasks ${WORK}/${OUT} --only-show-errors
checkpoint() {
  aws s3 sync ${WORK}/${OUT} ${S3}/tasks --exclude '*' --include 'task_*.rds' --only-show-errors
  aws s3 cp ${LOG} ${S3}/logs/run_${ID}.log --only-show-errors || true
}
( while true; do sleep 300; checkpoint; done ) &
(
  while true; do
    P=spot/instance-action
    if [ "$(meta -o /dev/null -w '%{http_code}')" = "200" ]; then
      echo "spot notice $(date)" >> ${LOG}; checkpoint; break
    fi
    sleep 5
  done
) &
cd ${WORK}
echo "instance ${ID} $(date); WORKERS=${WORKERS}; $(ls ${OUT} | wc -l) task files resumed" > ${LOG}
docker build -f dev/fase2/aws/Dockerfile -t fase2 dev/fase2/aws > build.log 2>&1 && \
docker run --rm -v ${WORK}:/project fase2 \
  bash -c "Rscript -e 'for (f in list.files(\"${OUT}\", \"rds\$\", full.names = TRUE)) if (inherits(try(readRDS(f), silent = TRUE), \"try-error\")) file.remove(f)' && \
           Rscript --max-connections=512 dev/fase2/${SCRIPT} ${OUT} ${WORKERS} ${EXTRA}" >> ${LOG} 2>&1
STATUS=$?
echo "exit status ${STATUS} at $(date)" >> ${LOG}
cat build.log >> ${LOG}
checkpoint
# an interruption is not a failure: no marker, so the run can be launched again
P=spot/instance-action
if [ "${STATUS}" != "0" ] && [ "$(meta -o /dev/null -w '%{http_code}')" = "200" ]; then shutdown -h now; exit 0; fi
if [ "${STATUS}" = "0" ]; then MARK=DONE; else MARK=FAILED; fi
echo "${ID} exit ${STATUS} $(date)" > /tmp/${MARK}
aws s3 cp /tmp/${MARK} ${S3}/${MARK} --only-show-errors
shutdown -h now
