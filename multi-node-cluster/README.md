# Create a multi-node Kubernetes cluster on macOS.

- [multipass](https://canonical.com/multipass/install) - **PREREQUISITE**
- [kubeadm](https://kubernetes.io/docs/tasks/tools/#kubeadm) - included in script `k8s-cluster.sh`
- [calico](https://docs.tigera.io/calico/latest/about) - included in script `k8s-cluster.sh`
- [containerd](https://containerd.io/) - included in script `k8s-cluster.sh`
- [kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl) - included in script `k8s-cluster.sh`
- one control node, two worker nodes

**Note**: Tested and validated for Ubuntu24.04

## Create the automation script `k8s-cluster.sh`

What this script does automatically

### Cluster creation

- Creates cloud-init configuration files
- Launches all 3 VMs in parallel
- Waits for all VMs to complete initialization
- Retrieves the join command from master
- Joins both workers to the cluster
- Verifies the cluster is working
- Shows connection instructions
- Cleans up temporary files

### Cluster deletion

- Deletes and purges all VMs
- Cleans up any leftover files

### Key features:

- Sequential VM creation to avoid resource contention
- Automatic waiting for initialization to complete
- Error handling with colored output
- Status monitoring to track progress
- Complete automation - no manual intervention needed
- Clean deletion that removes everything

The entire cluster creation takes about 5-10 minutes depending on your internet speed and system resources. You now have true one-command cluster creation and deletion!

## Make the script executable and use it

```
# Make executable
chmod +x k8s-cluster.sh

# Create cluster (one command!)
./k8s-cluster.sh create

# Check status
./k8s-cluster.sh status

# Delete cluster (one command!)
./k8s-cluster.sh delete
```
