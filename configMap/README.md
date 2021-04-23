# ConfigMap

Reference example to configure a container in a Pod with ConfigMap:

1. configure container command and arguments
2. configure container environment variables
3. mount configMap items as files in container 

Deploy ConfigMap's and Pod:\
`$> kubectl apply -f busybox-configmap-1.yaml`\
`$> kubectl apply -f busybox-configmap-2.yaml`\
`$> kubectl apply -f busybox-pod.yaml`

You can use the following command to check if everything is working:\
`$> kubectl exec -it busybox -- sh`\
`#> env | grep env`\
`#> cat /config/config.properties`\
`#> cat /config/user.properties`\
`#> ps | grep sleep`

