#!/bin/bash -e

NS=${NS:-2}
S=${S:-2}
SD=${SD:-2}
SDN=${SDN:-1}
C=${C:-2}
CD=${CD:-2}
CDN=${CDN:-1}
B=${B:-1}

USER_NS_PREFIX=${USER_NS_PREFIX:-scale}

OUTPUT_DIR=${OUTPUT_DIR:-$NS"n-"$S"s-"$SD"sd-"$C"c-"$CD"cd-"$B"b"}
rm -rvf $OUTPUT_DIR
mkdir -p $OUTPUT_DIR

function debug() {
    if [ -n "$DEBUG" ]; then
        echo [DEBUG] $1;
    fi
}

if [ -z "$OUTPUT" ]; then
  NS_OUT=$OUTPUT_DIR/scale-ns.yaml
  S_OUT=$OUTPUT_DIR/scale-secret.yaml
  C_OUT=$OUTPUT_DIR/scale-cm.yaml
  D_OUT=$OUTPUT_DIR/scale-app.yaml
  SVC_OUT=$OUTPUT_DIR/scale-bsvc.yaml
  B_OUT=$OUTPUT_DIR/scale-sbr.yaml
else
  SINGLE_OUTPUT=$OUTPUT_DIR/$OUTPUT
  NS_OUT=$SINGLE_OUTPUT
  S_OUT=$SINGLE_OUTPUT
  C_OUT=$SINGLE_OUTPUT
  D_OUT=$SINGLE_OUTPUT
  SVC_OUT=$SINGLE_OUTPUT
  B_OUT=$SINGLE_OUTPUT
fi

for n in $(seq -f "%04.0f" 1 $NS); do
    ns=$USER_NS_PREFIX-$n
    cat >> $NS_OUT <<EOD
---
apiVersion: v1
kind: Namespace
metadata:
  name: $ns
EOD
    # SECRET
    {
    for s in $(seq -f "%04.0f" 1 $S); do
        debug "secret: $ns/ns-$n-sec-$s"
        data="data:"
        for sd in $(seq -f "%04.0f" 1 $SD); do
            value="VALUE:"
            for x in $(seq 1 $SDN); do
                value="$value$(date +%N)";
            done
            data="$data
  SECRET_"$n"_"$s"_"$sd": $(echo $value| base64 -w0)" 
        done
    cat >> $S_OUT <<EOD
---
apiVersion: v1
kind: Secret
metadata:
  name: ns-$n-sec-$s
  namespace: $ns
$data
EOD
    done

    # CM
    for c in $(seq -f "%04.0f" 1 $C); do
        debug "configmap: $ns/ns-$n-cm-$c"
        data="data:"
        for cd in $(seq -f "%04.0f" 1 $CD); do
            value="VALUE:"
            for x in $(seq 1 $CDN); do
                value="$value$(date +%N)";
            done
            data="$data
  DATA_"$n"_"$c"_"$cd": $value" 
        done
    cat >> $C_OUT <<EOD
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: ns-$n-cm-$c
  namespace: $ns
$data
EOD
    done

    # App
    for b in $(seq -f "%04.0f" 1 $B); do
        debug "deployment: $ns/app-$n-$b"
        cat >> $D_OUT <<EOD
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-$n-$b
  namespace: $ns
  labels:
    app: sbo-perf-app-$n-$b
spec:
  replicas: 1
  strategy: 
    type: RollingUpdate
  selector:
    matchLabels:
      app: sbo-perf-app-$n-$b
  template:
    metadata:
      labels:
        app: sbo-perf-app-$n-$b
    spec:
      containers:
      - name: sbo-generic-test-app
        image: quay.io/redhat-developer/sbo-generic-test-app:20200923
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: sbo-perf-app-$n-$b
  name: app-$n-$b
  namespace: $ns
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: sbo-perf-app-$n-$b
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app: sbo-perf-app-$n-$b
  name: app-$n-$b
  namespace: $ns
  annotations: 
    service.binding/host: path={.spec.host}
spec:
  port:
    targetPort: 8080
  to:
    kind: "Service"
    name: app-$n-$b
EOD
        debug "svc: $ns/svc-$n-$b"
        cat >> $SVC_OUT <<EOD
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backing-svc-$n-$b
  namespace: $ns
  labels:
    app: sbo-perf-svc-$n-$b
spec:
  replicas: 1
  strategy: 
    type: RollingUpdate
  selector:
    matchLabels:
      app: sbo-perf-svc-$n-$b
  template:
    metadata:
      labels:
        app: sbo-perf-svc-$n-$b
    spec:
      containers:
      - name: busybox
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ['sh', '-c', 'echo Container 1 is Running ; sleep 3600']
        ports:
        - containerPort: 8080
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: sbo-perf-svc-$n-$b
  name: backing-svc-$n-$b
  namespace: $ns
spec:
  ports:
  - port: 8080
    protocol: TCP
    targetPort: 8080
  selector:
    app: sbo-perf-svc-$n-$b
---
apiVersion: route.openshift.io/v1
kind: Route
metadata:
  labels:
    app: sbo-perf-svc-$n-$b
  name: backing-svc-$n-$b
  namespace: $ns
  annotations: 
    service.binding/host: path={.spec.host}
spec:
  port:
    targetPort: 8080
  to:
    kind: "Service"
    name: backing-svc-$n-$b
EOD
        debug "sbr: $ns/service-binding-$n-$b"
        cat >> $B_OUT <<EOD
---
apiVersion: binding.operators.coreos.com/v1alpha1
kind: ServiceBinding
metadata:
  name: service-binding-$n-$b
  namespace: $ns
spec:
  services:
  - group: route.openshift.io
    version: v1
    kind: Route
    name: backing-svc-$n-$b
  application:
    name: app-$n-$b
    group: apps
    version: v1
    resource: deployments
---
apiVersion: binding.operators.coreos.com/v1alpha1
kind: ServiceBinding
metadata:
  name: service-binding-secret-$n-$b
  namespace: $ns
spec:
  bindAsFiles: false
  services:
  - group: ""
    version: v1
    kind: Secret
    name: ns-$n-sec-$b
  application:
    name: app-$n-$b
    group: apps
    version: v1
    resource: deployments
EOD
    done
    } &
#    }
done

wait
