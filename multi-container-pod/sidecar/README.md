```
kubectl create configmap error-monitoring --from-file=error-monitoring.sh
kubectl apply -f pod.side-car.yaml
```

- A ConfigMap volume is always mounted as read-only (`defaultMode = 0644`). Because the ConfigMap `error-monitoring` has not a configuration file (should be immutable), but a bash script (should be executable), the ConfigMap volume has been defined with `defaultMode: 0655`

- Note that the sidecar container has been defined with a command that calls `sh` to install the `bash` and `curl` packages and then calls `bash` to execute the `error-monitoring.sh` script.

- The `alpine` image has been used instead of the `busybox` image in the `sidecar` container, because the script `error-monitoring` is a bash script and `busybox` image does not have bash.

- Simulate an error in the nginx logging:

  ```
  kubectl exec -it sidecar -c sidecar -- sh
  sh# curl http://localhost/hshsjsj
  ```

  You should receive a response with HTTP status error `404`
  The `error-monitoring.sh` bash script running in `sidecar` container of Pod `sidecar` monitors the NGINX error log and when there is a new error, the error line is written `standard output`, which is directed to the logging of the `sidecar` container:

  ```
  kubectl logs sidecar -c sidecar
  ```