# ☁ Cloud Cybersecurity Homelab
Deploy an attack/defend cybersecurity homelab on AWS with Terraform.



# Topology
![Topology](images/Cloud-hosted%20Cybersecurity%20Homelab.png)

| Box | OS | Instance type | Role | Connect with |
|---|---|---|---|---|
| Windows | Windows Server 2022 (latest Amazon AMI) | t3.micro | Target | RDP |
| Kali | Kali Linux (AWS Marketplace) | t3.micro | Attacker | SSH, RDP |
| Security Tools | Ubuntu 22.04 (latest Canonical AMI) | m7i-flex.large | Defender (Splunk etc.) | SSH, RDP |

All three sit in one public subnet (`10.0.1.0/24`). Inbound traffic is only allowed from **your IP** and from the lab itself (`10.0.0.0/16`).

On first boot, Kali and Security Tools install an Xfce desktop + xrdp automatically (Security Tools also gets Firefox). Kali's setup upgrades a 2023 image, so allow 30+ minutes before RDP works. Check progress over SSH with `cloud-init status`.

# Before you start (one time)
1. Install [Terraform](https://developer.hashicorp.com/terraform/downloads) and the [AWS CLI](https://aws.amazon.com/cli/), then run `aws configure` with an IAM user's access keys.
2. In **us-east-2 (Ohio)**, create an EC2 key pair (EC2 → Network & Security → Key Pairs, type **RSA**, format **.pem**). Keep the `.pem` file safe: it's needed for SSH and for decrypting the Windows password.
3. Subscribe (free) to **Kali Linux** in the AWS Marketplace, otherwise the launch fails with `OptInRequired`.

# Configure
```bash
cp .env.example .env     # then edit .env: your public IP + key pair name
source .env              # run in every new terminal before Terraform
```
`.env` is git-ignored, so your IP never ends up on GitHub.

# Deploy
```bash
terraform init      # download the AWS provider (first time only)
terraform plan      # preview what will be created
terraform apply     # build the lab, prints the 3 public IPs
terraform destroy   # delete everything when you're done
```

# After each deploy
Every `apply` builds brand-new servers, so set a password for RDP on the Linux boxes:
```bash
ssh -i <key>.pem kali@<KALI_IP>      then   sudo passwd kali
ssh -i <key>.pem ubuntu@<TOOLS_IP>   then   sudo passwd ubuntu
```
Windows: EC2 console → instance → Connect → RDP client → Get password (upload your `.pem`), then log in as `Administrator`.

If you suddenly can't connect, your home IP probably changed. Update `.env`, `source .env`, then `terraform apply`.

# Cost
Roughly **$0.17/hour** while running (all types are AWS Free Plan eligible, so this comes out of your credits). Destroy or stop the lab when you're not using it. Stopped instances still pay for their disks (~$6/month).
