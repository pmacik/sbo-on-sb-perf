FROM registry.redhat.io/ubi8/ubi

ENV WORKSPACE /tmp/workspace
ENV PATH $PATH:$WORKSPACE
ENV KUBECONFIG /tmp/kubeconfig/kubeconfig

RUN mkdir -p /tmp/workspace
RUN mkdir -p /tmp/artifacts

RUN yum install -y --nodocs wget git jq httpd-tools make golang python3-pip \
    && yum clean all

RUN pip3 install yamllint yq

ENV GIT_SSL_NO_VERIFY true

RUN mkdir -p /tmp/context

COPY * /tmp/context/

ENTRYPOINT [ "/tmp/context/run.sh" ]