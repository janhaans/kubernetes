# SecurityContext

Reference example to use securityContext in order to:

1. Run processes in container not as root with
2. Create files in container not owned by root

Deploy pod:\
`$> kubectl apply -f security-context.yaml`

Check UID = 1000 and GID = 3000:\
`$> kubectl exec -it security-context-demo -- sh`\
`#> uid`\
When **runAsGroup** was not specified in security-context.yaml file then GID would have been 0 (=root)

Check that "sleep" process is running as user with UID = 1000:\
`$> kubectl exec -it security-context-demo -- sh`\
`#> ps aux`

Check that new created files have owner UID = 1000 and GID = 3000:\
`$> kubectl exec -it security-context-demo -- sh`\
`#> cd /data/demo`\
`#> echo "Hello World" > greeting.txt`\
`#> ls -l`\
If **fsGroup** was defined with for example 2000, then the created files would have GID = 2000

In this example **securityContext** is defined at Pod level. You can also define **securityContext** at container level. If **securityContext** is defined at both Pod level and container level, then the definition at container level precedes the definition at Pod level. 