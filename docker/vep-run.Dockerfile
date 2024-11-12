# Depends on a local copy of the CPG's VEP image.
FROM vep:release_110.1

ENV REF_DIR=/talos-deploy/reference
ENV DATA_DIR=/talos-deploy/data

COPY scripts /scripts/


