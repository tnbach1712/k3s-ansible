# HA K3s Cluster Deployment - 3 Nodes

## Cluster Configuration

### Nodes
- **Master 1**: 192.168.0.100
- **Master 2**: 192.168.0.101
- **Master 3**: 192.168.0.102

### Virtual IP (VIP)
- **API Server Endpoint**: 192.168.0.50 (managed by kube-vip)

### MetalLB IP Range
- **Service LoadBalancer Range**: 192.168.0.110 - 192.168.0.120

### Cluster Settings
- **K3s Version**: v1.30.2+k3s2
- **CNI**: Flannel (default)
- **Network Interface**: eth0
- **Timezone**: Asia/Ho_Chi_Minh
- **Ansible User**: root
- **K3s Token**: K3S-HA-CLUSTER-SECRET-TOKEN-12345
- **Bastion Host**: 51.159.77.46 (username: bachtn)

## Pre-Deployment Checklist

Before running the deployment, ensure:

1. **SSH Access**: All three nodes are accessible via SSH from your control machine
   ```bash
   ssh root@10.10.10.101
   ssh root@10.10.10.102
   ssh root@10.10.10.103
   ```

2. **Ansible Installed**: Verify Ansible 2.11+ is installed
   ```bash
   ansible --version
   ```

3. **Collections Installed**: Install required Ansible collections
   ```bash
   ansible-galaxy collection install -r ./collections/requirements.yml
   ```

4. **netaddr Package**: Install netaddr for Ansible
   ```bash
   pip install netaddr
   ```

5. **Node Requirements**:
   - Ubuntu 22.04 / Debian 11 / Rocky 9 (or compatible)
   - Minimum 2 CPU cores per node
   - Minimum 2GB RAM per node
   - Network connectivity between all nodes

## Deployment Steps

### 1. Verify Connectivity
```bash
ansible all -i inventory/ha-3nodes/hosts.ini -m ping
```

### 2. Verify Gather Facts
```bash
ansible all -i inventory/ha-3nodes/hosts.ini -m gather_facts
```

### 3. Deploy Cluster
```bash
ansible-playbook site.yml -i inventory/ha-3nodes/hosts.ini
```

### 4. Monitor Deployment
The playbook will:
- Install k3s on all three master nodes
- Configure kube-vip for virtual IP (192.168.0.50)
- Setup etcd in HA mode
- Configure MetalLB for LoadBalancer services
- Configure Flannel as CNI

### 5. Access Cluster
Once deployed, copy the kubeconfig from any master node:

```bash
mkdir -p ~/.kube
scp root@192.168.0.100:/etc/rancher/k3s/k3s.yaml ~/.kube/config

# Edit the config to replace localhost with VIP
sed -i '' 's/127.0.0.1/192.168.0.50/g' ~/.kube/config

# Verify cluster access
kubectl cluster-info
kubectl get nodes
```

## Reset/Cleanup

To remove the cluster and reset all nodes:

```bash
ansible-playbook reset.yml -i inventory/ha-3nodes/hosts.ini
```

**Note**: After reset, it's recommended to reboot all nodes since the VIP won't be fully removed:

```bash
ansible all -i inventory/ha-3nodes/hosts.ini -m reboot
```

## Important Notes

1. **VIP Configuration**: kube-vip will automatically assign the virtual IP (10.10.10.50) to one of the master nodes using ARP broadcasts.

2. **etcd HA**: All three nodes act as both control plane and etcd members - this is the embedded etcd HA setup in k3s.

3. **Scaling**: This is a 3-master, 0-worker configuration. To add worker nodes:
   - Add them to the `[node]` group in `hosts.ini`
   - Rerun `ansible-playbook site.yml -i inventory/ha-3nodes/hosts.ini`

4. **Network Isolation**: Ensure all nodes are on the same network subnet for kube-vip ARP to work properly.

5. **Flannel Interface**: Verify the `flannel_iface: eth0` matches your actual network interface. Check with `ip addr show` on the nodes.

## Troubleshooting

### Check K3s Status
```bash
ssh root@10.10.10.101
systemctl status k3s
journalctl -u k3s -f
```

### Check kube-vip
```bash
kubectl get pods -n kube-system | grep kube-vip
kubectl logs -n kube-system -l app=kube-vip -f
```

### Check MetalLB
```bash
kubectl get pods -n metallb-system
kubectl logs -n metallb-system deployment/controller -f
```

### Verify VIP is Active
```bash
ip addr show
# Should show 10.10.10.50 on one of the master nodes
```

## Configuration Files

- **Inventory**: `inventory/ha-3nodes/hosts.ini`
- **Variables**: `inventory/ha-3nodes/group_vars/all.yml`
- **Ansible Config**: `ansible.cfg`
- **Playbook**: `site.yml`
