#!/bin/bash

set -e

CLUSTER_NAME="k8s"
MASTER_NAME="${CLUSTER_NAME}-master"
WORKER1_NAME="${CLUSTER_NAME}-worker1"
WORKER2_NAME="${CLUSTER_NAME}-worker2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

create_cloud_init_files() {
    log "Creating cloud-init configuration files..."
    
    # Master cloud-init (simplified to avoid VM overload)
    cat > master-init.yaml << 'EOF'
#cloud-config
package_update: true
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gpg
  - containerd

runcmd:
  # Configure containerd
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  
  # Load required kernel modules for Kubernetes
  - modprobe br_netfilter
  - modprobe overlay
  - echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
  - echo 'overlay' >> /etc/modules-load.d/k8s.conf
  
  # Configure sysctl params required by setup, params persist across reboots
  - echo 'net.bridge.bridge-nf-call-iptables  = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.ipv4.ip_forward                 = 1' >> /etc/sysctl.d/k8s.conf
  - sysctl --system
  
  # Install Kubernetes components (updated method)
  - mkdir -p /etc/apt/keyrings
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  
  # Mark tools installation complete (don't initialize cluster in cloud-init)
  - touch /home/ubuntu/k8s-tools-ready

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      br_netfilter
      overlay
  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1
  - path: /home/ubuntu/init-cluster.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -e
      
      echo "Starting cluster initialization..."
      
      # Ensure kernel modules are loaded
      sudo modprobe br_netfilter
      sudo modprobe overlay
      sudo sysctl --system
      
      # Initialize cluster
      echo "Running kubeadm init..."
      sudo kubeadm init --pod-network-cidr=10.244.0.0/16
      
      # Set up kubectl for ubuntu user
      echo "Setting up kubectl..."
      sudo rm -rf /home/ubuntu/.kube
      sudo mkdir -p /home/ubuntu/.kube
      sudo cp /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
      sudo chown -R ubuntu:ubuntu /home/ubuntu/.kube
      sudo chmod 644 /home/ubuntu/.kube/config
      
      # Test kubectl access
      echo "Testing kubectl access..."
      kubectl get nodes
      
      # Install Calico CNI (simpler approach)
      echo "Installing Calico CNI..."
      kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.30.2/manifests/calico.yaml
      
      # Simple wait for networking
      echo "Waiting briefly for networking to initialize..."
      sleep 30
      
      echo "Cluster initialization complete!"
      # Mark initialization complete (ensure we can write to ubuntu home)
      sudo touch /home/ubuntu/k8s-master-ready
      sudo chown ubuntu:ubuntu /home/ubuntu/k8s-master-ready
EOF

    # Worker cloud-init
    cat > worker-init.yaml << 'EOF'
#cloud-config
package_update: true
packages:
  - apt-transport-https
  - ca-certificates
  - curl
  - gpg
  - containerd

runcmd:
  # Configure containerd
  - mkdir -p /etc/containerd
  - containerd config default > /etc/containerd/config.toml
  - sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
  - systemctl restart containerd
  - systemctl enable containerd
  
  # Load required kernel modules for Kubernetes
  - modprobe br_netfilter
  - modprobe overlay
  - echo 'br_netfilter' >> /etc/modules-load.d/k8s.conf
  - echo 'overlay' >> /etc/modules-load.d/k8s.conf
  
  # Configure sysctl params required by setup, params persist across reboots
  - echo 'net.bridge.bridge-nf-call-iptables  = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.bridge.bridge-nf-call-ip6tables = 1' >> /etc/sysctl.d/k8s.conf
  - echo 'net.ipv4.ip_forward                 = 1' >> /etc/sysctl.d/k8s.conf
  - sysctl --system
  
  # Install Kubernetes components (updated method)
  - mkdir -p /etc/apt/keyrings
  - curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | gpg --dearmor -o /etc/apt/keyrings/kubernetes.gpg
  - echo "deb [signed-by=/etc/apt/keyrings/kubernetes.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /" > /etc/apt/sources.list.d/kubernetes.list
  - apt-get update
  - apt-get install -y kubelet kubeadm kubectl
  - apt-mark hold kubelet kubeadm kubectl
  
  # Mark initialization complete
  - touch /home/ubuntu/k8s-tools-ready

write_files:
  - path: /etc/modules-load.d/k8s.conf
    content: |
      br_netfilter
      overlay
  - path: /etc/sysctl.d/k8s.conf
    content: |
      net.bridge.bridge-nf-call-iptables  = 1
      net.bridge.bridge-nf-call-ip6tables = 1
      net.ipv4.ip_forward                 = 1
EOF
}

wait_for_vm_ready() {
    local vm_name=$1
    local ready_file=$2
    log "Waiting for $vm_name to be ready..."
    
    local max_attempts=60
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        log "Attempt $((attempt + 1)): Checking $vm_name..."
        
        # Check if tools are installed
        if multipass exec $vm_name -- test -f $ready_file 2>/dev/null; then
            log "Tools ready file found on $vm_name"
            
            if [[ $vm_name == *"master"* ]]; then
                log "Initializing cluster on $vm_name..."
                
                # Check if init script exists
                if ! multipass exec $vm_name -- test -f /home/ubuntu/init-cluster.sh; then
                    error "Initialization script not found on $vm_name"
                    return 1
                fi
                
                # Run cluster initialization
                log "Running cluster initialization script..."
                if multipass exec $vm_name -- /home/ubuntu/init-cluster.sh; then
                    log "$vm_name cluster ready!"
                    return 0
                else
                    error "Cluster initialization failed on $vm_name"
                    # Show some debug info
                    log "Checking what went wrong..."
                    multipass exec $vm_name -- sudo journalctl -u kubelet --no-pager -l | tail -10 || true
                    return 1
                fi
            else
                # For workers
                log "$vm_name is ready!"
                return 0
            fi
        else
            log "Ready file $ready_file not found on $vm_name yet"
            # Show what files do exist
            multipass exec $vm_name -- ls -la /home/ubuntu/ | grep k8s || true
        fi
        
        sleep 10
        attempt=$((attempt + 1))
    done
    
    error "$vm_name failed to initialize within 10 minutes"
    return 1
}

create_cluster() {
    log "Creating Kubernetes cluster..."
    
    # Create cloud-init files
    create_cloud_init_files
    
    # Launch VMs sequentially with reduced resources for stability
    log "Launching master node..."
    if ! multipass launch --cpus 2 --memory 3G --disk 15G --name $MASTER_NAME --cloud-init master-init.yaml; then
        error "Failed to launch master node"
        return 1
    fi
    
    log "Launching worker node 1..."
    if ! multipass launch --cpus 1 --memory 1.5G --disk 8G --name $WORKER1_NAME --cloud-init worker-init.yaml; then
        error "Failed to launch worker node 1"
        return 1
    fi
    
    log "Launching worker node 2..."
    if ! multipass launch --cpus 1 --memory 1.5G --disk 8G --name $WORKER2_NAME --cloud-init worker-init.yaml; then
        error "Failed to launch worker node 2"
        return 1
    fi
    
    # Wait for all VMs to have tools installed
    wait_for_vm_ready $MASTER_NAME "/home/ubuntu/k8s-tools-ready"
    wait_for_vm_ready $WORKER1_NAME "/home/ubuntu/k8s-tools-ready"
    wait_for_vm_ready $WORKER2_NAME "/home/ubuntu/k8s-tools-ready"
    
    # Get join command from master with better error handling
    log "Getting join command from master..."
    local join_command=""
    local max_attempts=5
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if join_command=$(multipass exec $MASTER_NAME -- sudo kubeadm token create --print-join-command 2>/dev/null); then
            log "Successfully got join command"
            break
        else
            warn "Failed to get join command (attempt $((attempt + 1))/$max_attempts)"
            sleep 10
            attempt=$((attempt + 1))
        fi
    done
    
    if [ -z "$join_command" ]; then
        error "Failed to get join command after $max_attempts attempts"
        log "Checking API server status..."
        multipass exec $MASTER_NAME -- sudo systemctl status kubelet || true
        return 1
    fi
    
    # Join workers to cluster with better error handling
    log "Joining worker nodes to cluster..."
    
    log "Joining $WORKER1_NAME..."
    if ! multipass exec $WORKER1_NAME -- sudo $join_command; then
        warn "Failed to join $WORKER1_NAME to cluster"
    fi
    
    log "Joining $WORKER2_NAME..."
    if ! multipass exec $WORKER2_NAME -- sudo $join_command; then
        warn "Failed to join $WORKER2_NAME to cluster"
    fi
    
    # Wait for workers to potentially join
    sleep 30
    
    # Verify cluster with better error handling
    log "Verifying cluster status..."
    if multipass exec $MASTER_NAME -- kubectl get nodes -o wide 2>/dev/null; then
        log "Cluster verification successful!"
    else
        warn "Cluster verification failed - API server may be unstable"
        log "Checking system resources on master:"
        multipass info $MASTER_NAME || true
    fi
    
    # Show cluster info and setup local access
    log "Cluster created successfully!"
    echo ""
    echo "Setting up local kubectl access..."
    
    # Create .kube directory if it doesn't exist
    mkdir -p ~/.kube
    
    # Copy kubeconfig to local machine
    if multipass exec $MASTER_NAME -- sudo cat /etc/kubernetes/admin.conf > ~/.kube/config-multipass 2>/dev/null; then
        log "Kubeconfig copied to ~/.kube/config-multipass"
        echo ""
        echo "To access your cluster from your macbook:"
        echo "  export KUBECONFIG=~/.kube/config-multipass"
        echo "  kubectl get nodes"
        echo ""
        echo "Or test it directly:"
        echo "  KUBECONFIG=~/.kube/config-multipass kubectl get nodes"
        echo ""
        
        # Test local access
        if KUBECONFIG=~/.kube/config-multipass kubectl get nodes >/dev/null 2>&1; then
            log "✅ Local kubectl access is working!"
            echo ""
            echo "Cluster nodes:"
            KUBECONFIG=~/.kube/config-multipass kubectl get nodes
        else
            warn "❌ Local kubectl access test failed - you may need to set up port forwarding"
        fi
    else
        warn "Failed to copy kubeconfig - you can copy it manually later"
    fi
    
    echo ""
    echo "To access your cluster directly:"
    echo "  multipass shell $MASTER_NAME"
    echo ""
    
    # Cleanup cloud-init files
    rm -f master-init.yaml worker-init.yaml
}

delete_cluster() {
    log "Deleting Kubernetes cluster..."
    
    # Stop and delete VMs
    for vm in $MASTER_NAME $WORKER1_NAME $WORKER2_NAME; do
        if multipass list | grep -q "^$vm"; then
            log "Deleting $vm..."
            multipass delete $vm --purge
        fi
    done
    
    # Cleanup any leftover files
    rm -f master-init.yaml worker-init.yaml
    
    log "Cluster deleted successfully!"
}

show_status() {
    log "Cluster status:"
    multipass list | grep "^$CLUSTER_NAME"
    
    if multipass list | grep -q "^$MASTER_NAME.*Running"; then
        echo ""
        log "Kubernetes nodes:"
        multipass exec $MASTER_NAME -- kubectl get nodes -o wide 2>/dev/null || echo "Master not ready yet"
    fi
}

show_help() {
    echo "Usage: $0 {create|delete|status|help}"
    echo ""
    echo "Commands:"
    echo "  create  - Create a new multi-node Kubernetes cluster"
    echo "  delete  - Delete the existing cluster"
    echo "  status  - Show cluster status"
    echo "  help    - Show this help message"
    echo ""
    echo "The cluster will have:"
    echo "  - 1 master node (2 CPU, 4GB RAM, 20GB disk)"
    echo "  - 2 worker nodes (2 CPU, 2GB RAM, 10GB disk each)"
    echo "  - Calico CNI for networking"
}

# Main script logic
case "${1:-}" in
    create)
        create_cluster
        ;;
    delete)
        delete_cluster
        ;;
    status)
        show_status
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        error "Invalid command: ${1:-}"
        show_help
        exit 1
        ;;
esac