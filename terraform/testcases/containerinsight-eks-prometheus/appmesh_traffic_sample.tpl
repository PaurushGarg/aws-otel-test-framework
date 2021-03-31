apiVersion: appmesh.k8s.aws/v1beta2
kind: Mesh
metadata:
  name: ${MESH_NAME}
spec:
  namespaceSelector:
    matchLabels:
      mesh: ${MESH_NAME}
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: front
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  podSelector:
    matchLabels:
      app: front
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  backends:
    - virtualService:
        virtualServiceRef:
          name: color
  serviceDiscovery:
    dns:
      hostname: front.${APP_NAMESPACE}.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: white
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  podSelector:
    matchLabels:
      app: color
      version: white
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  serviceDiscovery:
    dns:
      hostname: color-white.${APP_NAMESPACE}.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: blue
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  podSelector:
    matchLabels:
      app: color
      version: blue
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  serviceDiscovery:
    dns:
      hostname: color-blue.${APP_NAMESPACE}.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: red
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  podSelector:
    matchLabels:
      app: color
      version: red
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  serviceDiscovery:
    dns:
      hostname: color-red.${APP_NAMESPACE}.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: yellow
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  podSelector:
    matchLabels:
      app: color
      version: yellow
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  serviceDiscovery:
    dns:
      hostname: color-yellow.${APP_NAMESPACE}.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualNode
metadata:
  name: green
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  podSelector:
    matchLabels:
      app: color
      version: green
  listeners:
    - portMapping:
        port: 8080
        protocol: http
      healthCheck:
        protocol: http
        path: '/ping'
        healthyThreshold: 2
        unhealthyThreshold: 2
        timeoutMillis: 2000
        intervalMillis: 5000
  serviceDiscovery:
    dns:
      hostname: color-green.${APP_NAMESPACE}.svc.cluster.local
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualService
metadata:
  name: color
  namespace: ${APP_NAMESPACE}
spec:
  meshName: ${MESH_NAME}
  provider:
    virtualRouter:
      virtualRouterRef:
        name: color
---
apiVersion: appmesh.k8s.aws/v1beta2
kind: VirtualRouter
metadata:
  namespace: ${APP_NAMESPACE}
  name: color
spec:
  meshName: ${MESH_NAME}
  listeners:
    - portMapping:
        port: 8080
        protocol: http
  routes:
    - name: color-route-blue
      priority: 10
      httpRoute:
        match:
          prefix: /
          headers:
            - name: color_header
              match:
                exact: blue
        action:
          weightedTargets:
            - virtualNodeRef:
                name: blue
              weight: 1
    - name: color-route-green
      priority: 20
      httpRoute:
        match:
          prefix: /
          headers:
            - name: color_header
              match:
                regex: ".*green.*"
        action:
          weightedTargets:
            - virtualNodeRef:
                name: green
              weight: 1
    - name: color-route-red
      priority: 30
      httpRoute:
        match:
          prefix: /
          headers:
            - name: color_header
              match:
                prefix: red
        action:
          weightedTargets:
            - virtualNodeRef:
                name: red
              weight: 1
    - name: color-route-yellow
      priority: 40
      httpRoute:
        match:
          prefix: /
          headers:
            - name: color_header
              #no match means if header present
        action:
          weightedTargets:
            - virtualNodeRef:
                name: yellow
              weight: 1
    - name: color-route-white
      httpRoute:
        match:
          #default match with no priority
          prefix: /
        action:
          weightedTargets:
            - virtualNodeRef:
                name: white
              weight: 1
---
apiVersion: v1
kind: Service
metadata:
  name: front
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http
  selector:
    app: front
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: front
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: front
  template:
    metadata:
      labels:
        app: front
    spec:
      containers:
        - name: app
          image: ${FRONT_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR_HOST"
              value: "color.${APP_NAMESPACE}.svc.cluster.local:8080"
---
apiVersion: v1
kind: Service
metadata:
  name: color-green
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http
  selector:
    app: color
    version: green
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: green
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: green
  template:
    metadata:
      labels:
        app: color
        version: green
    spec:
      containers:
        - name: app
          image: ${COLOR_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "green"
---
apiVersion: v1
kind: Service
metadata:
  name: color-blue
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http
  selector:
    app: color
    version: blue
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: blue
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: blue
  template:
    metadata:
      labels:
        app: color
        version: blue
    spec:
      containers:
        - name: app
          image: ${COLOR_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "blue"
---
apiVersion: v1
kind: Service
metadata:
  name: color-red
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http
  selector:
    app: color
    version: red
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: red
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: red
  template:
    metadata:
      labels:
        app: color
        version: red
    spec:
      containers:
        - name: app
          image: ${COLOR_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "red"
---
apiVersion: v1
kind: Service
metadata:
  name: color-yellow
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http
  selector:
    app: color
    version: yellow
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: yellow
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: yellow
  template:
    metadata:
      labels:
        app: color
        version: yellow
    spec:
      containers:
        - name: app
          image: ${COLOR_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "yellow"
---
apiVersion: v1
kind: Service
metadata:
  name: color-white
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http
  selector:
    app: color
    version: white
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: white
  namespace: ${APP_NAMESPACE}
spec:
  replicas: 1
  selector:
    matchLabels:
      app: color
      version: white
  template:
    metadata:
      labels:
        app: color
        version: white
    spec:
      containers:
        - name: app
          image: ${COLOR_APP_IMAGE}
          ports:
            - containerPort: 8080
          env:
            - name: "COLOR"
              value: "white"
---
apiVersion: v1
kind: Service
metadata:
  name: color
  namespace: ${APP_NAMESPACE}
spec:
  ports:
    - port: 8080
      name: http