- Create new namespace `resourcequotas` and set the context to this namespace

```
kubectl create namespace resourcequotas
kubectl config set-context --current --cluster=kind-kind --user=kind-kind --namespace=resourcequotas
```

- Define ResoureQuota for namespace `resourcequotas`, see manifest `resourcequota.quota.yaml`

- Create ResourceQuota object

```
kubectl apply -f resourcequota.quota.yaml
```

- Create nginx Pod without resource requests and limits

```
kubectl apply -f pod.nginx.yaml
```

Then you get the error:

```
Error from server (Forbidden): error when creating "pod.nginx.yaml": pods "nginx" is forbidden: failed quota: quota: must specify limits.cpu for: nginx; limits.memory for: nginx; requests.cpu for: nginx; requests.memory for: nginx
```

- Create nginx Pod with resource requests and limits

```
kubectl apply -f pod.quota-resource-1.yaml
kubectl describe resourcequota
kubectl apply -f pod.quota-resource-2.yaml
kubectl describe resourcequota
kubectl apply -f pod.quota-resource-3.yaml
```

The last Pod deployment will fail because of exceeded resource quota

- Create nginx Pod without resource requests and limits but there is a LimitRange object for Pods in namespace

```
kubectl apply -f limitrange.pods.yaml
kubectl apply -f pod.nginx.yaml
```
