FROM registry.redhat.io/ubi8/ubi

RUN yum install -y --nodocs wget git jq httpd-tools make golang python3-pip \
    && yum clean all
RUN pip3 install yamllint yq

ENV GIT_SSL_NO_VERIFY true
ENV WORKSPACE /mnt/sandbox
ENV METRICS /mnt/metrics
ENV ARTIFACTS /mnt/artifacts
ENV KUBECONFIG ${WORKSPACE}/kubeconfig
ENV PATH $PATH:$WORKSPACE/bin     

RUN mkdir -p ${ARTIFACTS}
RUN mkdir -p ${WORKSPACE}
RUN mkdir -p ${METRICS}
RUN mkdir -p /context

COPY * /context/

ENTRYPOINT [ "/context/run.sh" ]