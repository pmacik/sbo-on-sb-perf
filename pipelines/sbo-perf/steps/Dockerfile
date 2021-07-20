FROM registry.redhat.io/ubi8/ubi
ENV WORKSPACE /workspace
ENV ARTIFACTS /mnt/artifacts
ENV KUBECONFIG /mnt/kubeconfig/kubeconfig
ENV PATH $PATH:$WORKSPACE     
RUN mkdir -p ${ARTIFACTS}
RUN mkdir -p ${WORKSPACE}
RUN yum install -y --nodocs wget git jq httpd-tools make golang python3-pip \
    && yum clean all
RUN pip3 install yamllint yq
ENV GIT_SSL_NO_VERIFY true
RUN mkdir -p /context
COPY * /context/
ENTRYPOINT [ "/context/run.sh" ]