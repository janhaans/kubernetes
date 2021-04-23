# Secret

Reference example to insert secrets in a container in a Pod with Secret:

1. insert secret as an environment variable in container
2. insert secret as file in container

Deploy Secret's and Pod:
`$> kubectl apply -f busybox-secret-1.yaml`\
`$> kubectl apply -f busybox-secret-2.yaml`\
`$> kubectl apply -f busybox-pod.yaml`

You can use following commands to check if everything is working:\
`$> kubectl exec -it busybox --sh`\
`#> cat /etc/credentials/username2`\
`#> cat /etc/credentials/password2`\
`#> env | grep username1`\
`#> env | grep password1` 