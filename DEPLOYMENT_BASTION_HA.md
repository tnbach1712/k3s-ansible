# HA K3s Cluster Deployment - 3 Nodes with Bastion

## Cluster Configuration

### Nodes
- **Master 1**: 192.168.0.100
- **Master 2**: 192.168.0.101
- **Master 3**: 192.168.0.102

### Virtual IP (VIP)
- **API Server Endpoint**: 192.168.0.50 (managed by kube-vip)

### MetalLB IP Range
- **Service LoadBalancer Range**: 192.168.0.110 - 192.168.0.120

### Network Architecture
- **Bastion Host**: 51.159.77.46 (username: bachtn)
- **Private Network**: 192.168.0.0/24 (internal)
- **Network Interface**: eth0

### Cluster Settings
- **K3s Version**: v1.30.2+k3s2
- **CNI**: Flannel (default)
- **Timezone**: Asia/Ho_Chi_Minh
- **Ansible User**: root
- **K3s Token**: K3S-HA-CLUSTER-SECRET-TOKEN-12345

## Pre-Deployment Checklist

### 1. SSH Key Setup
Add your SSH key to Bastion host:
```bash
# Copy your public key to bastion
ssh-copy-id -i ~/.ssh/id_rsa bachtn@51.159.77.46

# Test connection
ssh bachtn@51.159.77.46 'echo "Bastion OK"'
```

### 2. SSH Config (Already Created)
SSH config has been created at `~/.ssh/config` with Bastion proxy configuration. This allows:
- Direct SSH to private nodes through Bastion
- Ansible to automatically route through Bastion

**Manual SSH Test**:
```bash
ssh root@192.168.0.100 'echo "Node 1 reachable"'
ssh root@192.168.0.101 'echo "Node 2 reachable"'
ssh root@192.168.0.102 'echo "Node 3 reachable"'
```

### 3. Install Ansible Dependencies
```bash
# Verify Ansible 2.11+
ansible --version

# Install required collections
ansible-galaxy collection install -r ./collections/requirements.yml

# Install netaddr package
pip install netaddr
```

### 4. Verify Node Access via Ansible
```bash
# Ping all nodes through Bastion
ansible all -i inventory/ha-3nodes/hosts.ini -m ping

# Gather facts to verify connectivity
ansible all -i inventory/ha-3nodes/hosts.ini -m gather_facts
```

### 5. Node Requirements
Ensure all nodes have:
- Ubuntu 22.04 / Debian 11 / Rocky 9 (or compatible)
- Minimum 2 CPU cores per node
- Minimum 2GB RAM per node
- Passwordless SSH access from Bastion (or use your configured key)

## Deployment Steps

### Step 1: Verify All Connectivity
```bash
cd /Users/bachtn3/code/k3s-ansible

# Test Bastion
ssh bachtn@51.159.77.46 'echo "Bastion OK"'

# Test Ansible connectivity
ansible all -i inventory/ha-3nodes/hosts.ini -m ping
```

### Step 2: Gather Facts
```bash
ansible all -i inventory/ha-3nodes/hosts.ini -m gather_facts
```

### Step 3: Deploy Cluster (Main Deployment)
```bash
ansible-playbook site.yml -i inventory/ha-3nodes/hosts.ini
```

**This will:**
- Install k3s on all three master nodes
- Configure kube-vip for virtual IP (192.168.0.50)
- Setup etcd in HA mode
- Configure MetalLB for LoadBalancer services
- Configure Flannel as CNI

**Expected duration**: 5-10 minutes per node

### Step 4: Monitor Deployment
You can watch the deployment progress:
```bash
# On any master node (through Bastion)
ssh root@192.168.0.100
systemctl status k3s
journalctl -u k3s -f
```

### Step 5: Access Cluster

Once deployed, copy the kubeconfig from any master node:

```bash
mkdir -p ~/.kube

# Copy kubeconfig through Bastion
scp -o ProxyCommand="ssh -W %h:%p -q bachtn@51.159.77.46" \
    root@192.168.0.100:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Edit the config to use VIP instead of localhost
sed -i '' 's/127.0.0.1/192.168.0.50/g' ~/.kube/config

# Verify cluster access
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

## Ansible Configuration

The following Ansible configurations are set for Bastion access:

**File**: `inventory/ha-3nodes/group_vars/all.yml`
```yaml
ansible_user: root
ansible_ssh_common_args: '-o ProxyCommand="ssh -W %h:%p -q bachtn@51.159.77.46"'
```

This automatically routes all Ansible connections through the Bastion host.

## Reset/Cleanup

To remove the cluster and reset all nodes:

```bash
ansible-playbook reset.yml -i inventory/ha-3nodes/hosts.ini
```

**Note**: After reset, it's recommended to reboot all nodes:

```bash
ansible all -i inventory/ha-3nodes/hosts.ini -m reboot
```

## Important Notes

### VIP Configuration
kube-vip will automatically assign the virtual IP (192.168.0.50) to one of the master nodes using ARP broadcasts within the private network.

### etcd HA
All three nodes act as both control plane and etcd members - this is the embedded etcd HA setup in k3s.

### Bastion Host Usage
- Ansible automatically proxies through Bastion
- SSH connections in `~/.ssh/config` also support Bastion proxy
- All traffic between control machine and nodes routes through: `your-machine → bastion → private-nodes`

### Network Isolation
The nodes are isolated on a private network and must communicate through Bastion. The Bastion host must:
- Have SSH access to all three k3s nodes
- Allow port forwarding
- Have connectivity to the private network (192.168.0.0/24)

### Scaling
To add worker nodes in the future:
- Add them to the `[node]` group in `hosts.ini`
- Ensure they're accessible through Bastion (update SSH config)
- Rerun `ansible-playbook site.yml -i inventory/ha-3nodes/hosts.ini`

## Troubleshooting

### SSH Connection Issues

**Bastion connection fails**:
```bash
# Test direct Bastion access
ssh -vv bachtn@51.159.77.46

# Check SSH key
ls -la ~/.ssh/id_rsa
```

**Node not reachable through Bastion**:
```bash
# Test through Bastion manually
ssh -J bachtn@51.159.77.46 root@192.168.0.100

# Check SSH config
cat ~/.ssh/config
```

### Ansible Issues

**Ping fails through Bastion**:
```bash
# Test with verbose output
ansible all -i inventory/ha-3nodes/hosts.ini -m ping -vvv

# Verify ProxyCommand is set
grep -A 2 "ansible_ssh_common_args" inventory/ha-3nodes/group_vars/all.yml
```

### K3s Status

**Check K3s on a node**:
```bash
ssh root@192.168.0.100
systemctl status k3s
journalctl -u k3s -n 50 -f
```

**Check kube-vip**:
```bash
kubectl get pods -n kube-system | grep kube-vip
kubectl logs -n kube-system -l app=kube-vip -f
```

**Check MetalLB**:
```bash
kubectl get pods -n metallb-system
kubectl logs -n metallb-system deployment/controller -f
```

**Verify VIP is Active**:
```bash
ssh root@192.168.0.100 'ip addr show | grep 192.168.0.50'
```

## Configuration Files

- **Inventory**: `inventory/ha-3nodes/hosts.ini`
- **Variables**: `inventory/ha-3nodes/group_vars/all.yml`
- **Ansible Config**: `ansible.cfg`
- **SSH Config**: `~/.ssh/config` (Bastion proxy)
- **Playbook**: `site.yml`
