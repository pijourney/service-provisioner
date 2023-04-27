FROM alpine

ENV PSQL_VERSON="42.5.0"
ENV INIT_DIR="/pijourney-provisioner-init.d"
ENV LIB_DIR="/pijourney-provisioner-init.d/lib"

RUN mkdir -p ${INIT_DIR} && mkdir -p ${LIB_DIR}
RUN apk update && \
    apk upgrade && \
    apk add --no-cache curl jq postgresql-client openssl 
RUN curl https://jdbc.postgresql.org/download/postgresql-${PSQL_VERSON}.jar -o ${LIB_DIR}/postgresql-${PSQL_VERSON}.jar

COPY scripts/entry.sh ${INIT_DIR}/entry.sh
COPY scripts/lib/* ${LIB_DIR}/

ENTRYPOINT sh ${INIT_DIR}/entry.sh