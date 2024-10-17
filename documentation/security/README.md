# Security

Access to `kube-apiserver` is controlled:

- Authentication
- Authorization

There are 2 types of entities accessing or sending requests to `kube-apiserver`:

- Users
- Applications (service accounts)

## User authentication

There are several methods to authenticate a user:

**Password authentication file**  
This is a csv file with fields: `password,username,user_uid,groupname`  
`kube-apiserver` is started with the option `--basic-auth-path=<password file>

**Token authentication file**
This is a csv file with fields: `token,username,user_uid,groupname`  
`kube-apiserver` is started with the option `--token-auth-path=<password file>

**Clien Certificates**

**External Identity Provider**

Note:  
When kubernetes cluster has been created with `kubeadm`, then you can see `kube-apiserver` configuraton in file `etc/kubernetes/manifests/kube-apiserver.yaml`  
When kubernetes cluster has been created form scratch, then you can see `kube-apiserver` configuration with

- `sudo systemctl status kube-apiserver.service`  
  or
- `sudo ps -ef | grep "kube-apiserver"`

## TLS Basics

- symmetric keys
- asymmetric keys (private key, public key)

**Create private key**

`openssl genrsa -out server.key 1024`

**Create public key**

`openssl rsa -pubout -in server.key -out server.crt` (public keys can also have extension `pem`)

**Create Certificate Signing Request (CSR)**

`openssl req -new -key server.key -out server.csr -subj "/CN=www.server.com"`

**Create Self-Signed Certificate**

`openssl x509 -req -in server.csr -key server.key -out server.crt`

**Create CA signed Certificate**

`openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -out server.crt`

**View Certificate**

`openssl x509 -in server.crt -text -noout`

The CSR contains the public key and it is created from the provided private key. Therefore you do not have to explicitly create a public key before you create a CSR. The Common Name (CN) in the CSR identifies the entity for which the certificate will be created. The CSR is sent to a Certificate Authority (CA) and verifies your identity, signs the public key in the CSR and creates the certificate. The certificate contains the signed public key and attributes like Common Name that identifies the owner of the private key.

In a TLS handshake a shared symmetric key is negotiated between the client and server by using the server private key and certificate (and client private key and certificate in case of mutually authentication). The shared symmetric key is used to encrypt the data that is transferred between the client and server, because symmetric key encryption is much faster than asymmetric key encryption.

## TLS in Kubernetes

All connections within a Kubernetes cluster must be encrypted and mutually authenticated. A connection is mutual authenticated when the client has a Client Certificate and the server has a Server Certificate to identify themselves. A Kubernetes cluster requires at least one Certificate Authority (CA).

The server components in a kubernetes cluster that must have a Server Certificate are:

- `Kube API Server`
- `ETCD Server`
- `Kubelet Server`

The clients of the Kubernetes API Server are:

- Kubernetes Administrators
- `Kube Scheduler`
- `Kube Controller Manager`
- `Kube Proxy`
- `Kubelet Server` (to authenticate the Kubelet in the Kube API Server)

The client of the ETCD Server is:

- `Kube API Server` (the server key and certificate can be re-used or you create new client key and certificate)

The client of the Kubelet Server is

- `Kube API Server` (to monitor the cluster)(the server key and certificate can be re-used or you create new client key and certificate)

A Kubernetes cluster can have multiple CA's. When for example ETCD Server has its own CA, then Kubernetes API Server must have client certificate signed by the ETCD CA and have server certificate signed by the other CA that is used by all other Kubernetes components. Each CA has its own key and certificate.

All Kubernetes components must have the Kubernetes CA root certificate(s) (ca.crt).

For the creation of a `Kubernets Administrator` certificate you can use the `openssl` commands as described in [TLS Basics](#TLS Basics). However, the Common Name (CN) in the CSR must identify the user and the user must be member of the Kubernets admin group by specifying Organisation as `system:masters` in the CSR. The CSR becomes:

`openssl req -new -key admin.key -out admin.csr -subj "/O=system:masters/CN=kube-admin"`

The `Kube Scheduler`, `Kube Controller Manager` are system components, so the Common Name in the CSR must be prefixed with `system`

The `ETCD Server` is a distributed key/value store. When the control plane consists of multiple nodes, then each `ETCD Server` instance must have a separate certificate to secure the communication between the `ETCD Server` instances.

When the control plane consists of multipe nodes, then also each `Kube API Server` instance must have a separate certificate. Also each of these certificates needs to have Subject Alternative Names (SAN) to identify it as the certificate of `Kube API Server`:

- kubernetes
- kubernetes.default
- kubernetes.default.svc
- kubernetes.default.svc.cluster.local

Therefore you need to create a openssl configuration file `openssl.cnf` to specify the alternative names (use chatGPT for an example `openssl.cnf`) and create the CSR:

`openssl req -new -key apiserver.key -out apiserver.csr --subj "/CN=kube-apiserver" -config=openssl.cnf`

Note: you can also use SAN to have one shared certificate for all `Kube API Server` instances (or for all `ETCD Server` instances) but than you must define alternative names for each `ETCD Server` instance DNS name and IP address.

The `Kube API Server` connects to the `Kubelet Server` on each node to monitor the cluster. Therefore each node must have a certificate that is named after the node name. This certificate is used in the kubelet configuration. You must do this for each node in the cluster.

The `Kubelet Server` on each node are authenticated in the `Kube API Server`. The `Kubelet Server` client certificate must have the right Common Name in the CSR: `system:node:<nodename>`. The `Kubelet Server` must have the right permissions and therefore the Organisation in the CSR must be `system:nodes`. The CSR becomes for example `node01`:

`openssl req -new -key node1.key -out node1.csr -subj "/O=system:nodes/CN=system:node:node01"`

When you create a cluster with `kubeadm` then:

- all the certificates are created for you.
- the configuration of each Kubernetes component is in directory `/etc/kubernets/manifests`
- in the configuration the location of keys, certificates and root certificates are specified.
- the certificates van be view with the command

`openssl x509 -in <location certificate>.crt -text -noout`

When you create a cluster in the hard way without a tool like `kubeadm` then:

- you have to create all the certificates yourself
- the kubernetes components will run as native service (`/etc/systemd/system/<kubernetes component>.service`)
- the location of keys, certificates and root certificates are passed as parameters to the start command
- the certificates van be view with the command

`openssl x509 -in <location certificate>.crt -text -noout`

For more information have a look at the Kubernetes documentation that explains what certificates a cluster requires: [PKI certificates and requirements](https://kubernetes.io/docs/setup/best-practices/certificates/)

## Certificates API

To make the manual process of signing the CSR of a user by a kubernetes administrator easier, Kubernetes exposes the Certificate API. Now, when the kubernetes administrator receives a CSR of a user, he does not log into a control plane node and manually signs the CSR using the CA key and certificate, but he creates a `CertificateSigningRequest` and sends it to the Kubernets API. Then all kubernetes adminsitrators can see the created `CertificateSigningRequest` object. The request can be reviewed and approved using `kubectl` commands. Then the certificate can be extracted and shared with the user.

1. User Jane creates a key:

`openssl genrsa -out jane.key 2048`

2. User Jane creates CSR:

`openssl req -new -key jane.key -out jane.csr -subj "/CN=jane"`

3. User Jane sends CSR to a Kubernetes administrator
4. The Kubernetes administrator Base64 Encode Jane's CSR:

`cat jane.csr | base64 | tr -d '\n'`

5. The Kubernets administrator creates a `CertificateSigningRequest` in file `jane-csr.yaml`:

```
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: jane
spec:
  request: <BASE64_ENCODED_CSR>
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: 86400  # (Optional) Time the certificate should be valid (in seconds)
  usages:
  - digital signature
  - key encipherment
  - client auth
```

6. The Kubernetes administrator applies the YAML file:

`kubectl apply -f jan-csr,yaml`

7. A Kubernets administrator can review the CSR:

`kubectl get csr jane -o yaml`

8. A Kubernets administrator can approve the CSR:

`kubectl certificate approve jane`

9. A Kubernets administrator can extract the certificate and share it with Jane:

`kubectl get csr jane -o jsonpath='{.status.certificate}' | base64 --decode > jane.crt`

In the `Kube Controller Manager` configuration (`/etc/kubernets/manifests/kube-controller-manager.yaml`) are the locations of the CA key and CA certificate specified, which are required to sign a CSR.

- `--cluster-signing-cert-file=/etc/kubernetes/pki/ca.crt`
- `--cluster-signing-key-file=/etc/kubernetes/pki/key.crt`

## KubeConfig

You can send requests to kubernetes (`Kube API Server`) with:

- `curl`

```
curl https://kube-apiserver:6443/api/v1/pods
    --key admin.key
    --cert admin.crt
    --cacert ca.crt
```

- `kubectl`

```kubectl get pods
    --server kube-apiserver:6443
    --client-key admin.key
    --client-certificate admin.crt
    --certificate-authority ca.cert
```

It is tedious to provide for each `kubectl` command these parameters. You can move these parameters to a `config` file:

```
kubectl get pods
    --kubeconfig config
```

By default `kubectl` looks for a config file in `$HOME/.kube/config`. TheKubeConfig file has 3 sections:

- **Clusters**: array of Kubernetes clusters where each cluster has a name, endpoint and CA cerificate
- **Contexts**: array of contexts where for each context a user is associated with a cluster and optionally namespace
- **Users**: array of Kubernetes users where each user has a name, key and certificate.

```
apiVersion: v1
kind: Config
clusters:
- name: my-cluster
  cluster:
    server: https://kubernetes:6443
    certificate-authority: /path/to/ca.crt   # Path to the cluster's CA certificate
contexts:
- name: my-context
  context:
    cluster: my-cluster
    user: my-user
    namespace: my-namespace                 # Optionally
users:
- name: my-user
  user:
    client-certificate: /path/to/client.crt  # Path to the user's client certificate
    client-key: /path/to/client.key          # Path to the user's client key
current-context: my-context

```

In the KubeConfig file the default context is specified. Always use a full path to specifiy where the keys and certificates are located.

**View KubeConfig file**

```
kubectl config view  (will show $HOME/.kube/config)
kubectl config view --kubeconfig=my-custom-config
```

**List all contexts**

`kubectl config get-contexts`

**Use another context**

` kubectl config use {context name}`

## API Groups

All Kubernetes resources are grouped in different API groups. Each resource has a set of actions or verbs, such as:

- list
- get
- create
- delete
- update
- watch

These verbs are used to specify authorization.
At the top level the API groups can be seen with:

```
curl http://{hostname kube api server}:6443 -k
    --key /path/to/server.key
    --cert /path/to/server.crt
    --cacert /path/to/ca.crt
```

or, if you do want to use the certificates in KubeConfig:

```
kubectl proxy  #expose a port(8001) on localhost
curl http://localhost:8001 -k
```

## Authorization

Kubernetes supports multiple authorization modes

- **Node Authorization**
  While joining the `kubelet` of each node to the cluster, it is node authorised, by providing a certificate that has Common Name prefix `system:node` and group or Organization `system:nodes`
- **ABAC** (Attribute Based Access Control)
  A user is directly associated with a set of resource permissions
- **RBAC** (Role Based Access Control)
  A user is associated with a Role. A role contains a set of resource permissions
- **Webhook**
  Delegate authorization to a third party tool, like for exampleOpen Policy Agent
- **AlwaysAllow**
  Allows all access requests
- **AllwaysDeny**
  Denies all access requests

The authorization is mode is set on the `Kube API server` with parameter `--authorization-mode`. If you do not set this option then by default the authorization mode is `AlwaysAllow`. You can set multiple authorization modes, such as for example `--authorization-mode=Node,RBAC,Webhook`. The order of authorization is the order specified in `authorization-mode`.

## RBAC

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  namespace: default                # Specify the namespace this Role applies to
  name: pod-reader                  # Name of the Role
rules:
- apiGroups: [""]                   # Empty for core group for any other group specify group name
  resources: ["pods", "secrets"]
  verbs: ["get", "list", "watch"]
```

This role only defines the permissions. To assign it to a user or service account, you would need to create a **RoleBinding**.

```
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: read-pods-binding
  namespace: default
subjects:
- kind: User                            # or 'ServiceAccount' if binding to a service account
  name: jane                            # Name of the user or service account
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: Role
  name: pod-reader                      # The Role created above
  apiGroup: rbac.authorization.k8s.io
```

You as a Kubernetes user can check access:

```
kubectl auth can-i create deployments
kubectl auth can-i delete nodes
....
```

As a Kubernetes administrator you can check access of users:

```
kubectl auth can-i create deployments --as dev-user
kubectl auth can-i delete nodes --as dev-user
kubectl auth can-i create pods --as dev-user --namespace test
....
```

You can create a role that grants permissions to specific resources:

```
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: developer                   # Name of the Role
rules:
- apiGroups: [""]                   # Empty for core group for any other group specify group name
  resources: ["pods"]
  verbs: ["get", "create", "update"]
  resourceNames: ["blue", "orange"]
```
