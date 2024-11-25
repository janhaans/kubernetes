# ConfigMap

```
kubectl create configmap greeting --from-literal=HELLO="Hello is English" --from-literal=HALLO="Hallo is Nederlands"
kubectl create configmap greeting --from-env-file=greeting.env
kubectl create configmap greeting --from-file=HELLO=hello.txt --from-file=HALLO=hallo.txt
kubectl create configmap greeting --from-file=data
```
