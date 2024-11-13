# Depends on a local copy of the CPG's VEP image.
FROM vep:release_110.1

ENV REF_DIR=/reference
ENV DATA_DIR=/data

COPY scripts /scripts/


