# Ingress CRL Auto-update
This is a simple script that updates the CRL of the ingress-nginx controller. It is meant to be used in a cron job.

## Service Account
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: ingress-crl-updater
```

## Cluster Role and Cluster Role Binding
### Cluster Role
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: secret-updater-role
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["get", "list", "update"]
```

## Cluster Role Binding
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: secret-updater-binding
subjects:
- kind: ServiceAccount
  name: ingress-crl-updater
  namespace: default
roleRef:
  kind: ClusterRole
  name: secret-updater-role
  apiGroup: rbac.authorization.k8s.io
```

## Cron Jobs
```yaml
...
    spec:
      template:
        spec:
          serviceAccountName: ingress-crl-updater
          containers:
          template:
            spec:
              containers:
                - name: crl-updater
                  image: upnic/ingress-crl-updater:latest
                  env:
                    - name: NAMESPACE
                      value: "your namespace"
                    - name: CRL_URLS
                      value: "your urls comma separated"
```

## Docker Build and Push
```
docker buildx build --platform=linux/amd64 . -t upnic/ingress-crl-updater:latest --push
```
