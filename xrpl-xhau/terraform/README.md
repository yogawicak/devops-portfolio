# XRPL/Xahau Validator Terraform

Multi-cloud Terraform configurations for deploying XRPL/Xahau validator infrastructure.

## Structure

```
terraform/
├── aws/                    # AWS-specific configuration
│   ├── main.tf             # Provider & backend
│   ├── variables.tf        # AWS variables
│   ├── vpc.tf              # VPC, subnets, NAT
│   ├── ec2.tf              # EC2 instances, EBS
│   ├── security-groups.tf  # Security groups
│   ├── outputs.tf          # Outputs
│   └── templates/
│       └── validator-userdata.sh.tpl
│
└── digitalocean/           # DigitalOcean-specific configuration
    ├── main.tf             # Provider & backend
    ├── variables.tf        # DO variables
    ├── vpc.tf              # VPC
    ├── droplets.tf         # Droplets, volumes
    ├── firewalls.tf        # Firewall rules
    ├── outputs.tf          # Outputs
    └── templates/
        └── validator-userdata.sh.tpl
```

## Deployment

### AWS

```bash
cd terraform/aws

# Configure
cp production.tfvars.example production.tfvars
# Edit production.tfvars with your values

# Deploy
terraform init
terraform plan -var-file="production.tfvars"
terraform apply -var-file="production.tfvars"
```

### DigitalOcean

```bash
cd terraform/digitalocean

# Configure
cp production.tfvars.example production.tfvars
# Edit production.tfvars with your values
export DIGITALOCEAN_TOKEN="your-api-token"

# Deploy
terraform init
terraform plan -var-file="production.tfvars" -var="do_token=$DIGITALOCEAN_TOKEN"
terraform apply -var-file="production.tfvars" -var="do_token=$DIGITALOCEAN_TOKEN"
```

## Resource Comparison

| Resource       | AWS               | DigitalOcean         |
| -------------- | ----------------- | -------------------- |
| Validator      | EC2 r5.large      | Droplet m-4vcpu-32gb |
| Monitoring     | EC2 t3.medium     | Droplet s-2vcpu-4gb  |
| Bastion        | EC2 t3.micro      | Droplet s-1vcpu-1gb  |
| Ledger Storage | EBS gp3 500GB     | Block Storage 500GB  |
| Firewall       | Security Groups   | Cloud Firewalls      |
| Network        | VPC + NAT Gateway | VPC                  |

## Outputs

After deployment, both configurations output:

- Bastion public IP
- Validator private IPs
- SSH connection commands
- Resource IDs
