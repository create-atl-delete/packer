# Packer: Windows SSH over SSM

This repository provides a working template for building Windows AMIs using HashiCorp Packer with **SSH over AWS Systems Manager (SSM)**. 

## The Backstory
Using SSH over SSM is straightforward for Linux builds and well-documented by Packer. You just need the right IAM permissions and it largely works out of the box. However, Windows requires some additional work that HashiCorp has never documented. Specifically, getting OpenSSH to work with the key pair that Packer generates during launch.

On Linux, this key pair is available for use with SSH by default. On Windows, where we are using OpenSSH instead of a native client, this key pair is not available for use by default. To fix this, we must pass a user data file which enables the OpenSSH server capability, downloads the public key from the instance metadata, sets the appropriate permissions, and starts the service.

This repository demonstrates exactly how to do that.

### Why Not WinRM?
While WinRM is the traditional method for connecting to Windows machines, **SSH is strictly better**. SSH over SSM is more secure, requires no inbound security group rules, and doesn't suffer from the complex authentication and certificate nightmares often associated with WinRM.

## The Solution

The solution involves two parts: the Packer template and the User Data script.

### 1. User Data Script (`windows/ssh/ssh_config.ps1`)
We pass a PowerShell script as `user_data_file` to the instance. This script:
1. Checks if the Amazon SSM Agent is installed, and installs it from AWS if it is missing.
2. Installs the `OpenSSH.Server` Windows capability.
3. Downloads the public key Packer injected into the instance metadata (`http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key`).
4. Saves it to `C:\ProgramData\ssh\administrators_authorized_keys`.
5. Copies the correct ACL permissions from an existing host key so the SSH daemon accepts it.
6. Starts the `sshd` service.

### 2. Packer Template (`windows/ssh/windows_ssh.pkr.hcl`)
In your Packer template, you simply define the communicator as `ssh` and provide the user data script:
```hcl
  # Apply IAM Instance Profile to enable SSM
  iam_instance_profile = "RoleWithAmazonSSMManagedInstanceCore"

  # Pass AWS user_data_file to enable SSH
  user_data_file = "./ssh_config.ps1"

  # Tell Packer to use SSH over SSM
  communicator  = "ssh"
  ssh_interface = "session_manager"
  ssh_username  = "Administrator"
```

## Prerequisites

To use SSH over SSM, your environment must be properly configured.

### Local Host
* **AWS CLI:** Installed and configured. ([Instructions](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html#getting-started-install-instructions))
* **Session Manager Plugin:** Required to tunnel the SSH connection. ([Instructions](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html))

### Remote Host
* **SSM Agent:** The SSM agent is must be installed. The user data script installs it if not present.

### IAM Policies
* **EC2 Instance Profile:** The instance must have an IAM Role attached with the `AmazonSSMManagedInstanceCore` managed policy. ([Instructions](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-instance-permissions.html#instance-profile-add-permissions))
* **User/Role:** The AWS user or role running the Packer build needs `ssm:StartSession` and `ssm:TerminateSession` permissions. ([Instructions](https://docs.aws.amazon.com/systems-manager/latest/userguide/getting-started-restrict-access-quickstart.html#restrict-access-quickstart-end-user))

### Networking
* **Security Groups:** One of the main benefits of AWS SSM is that it requires **no inbound access**. The instance's Security Group does not need any inbound rules (no port 22 or 5986 required) for this to work.
* **VPC Endpoints (Optional):** For added security in private subnets, use VPC Endpoints for AWS SSM. ([Instructions](https://docs.aws.amazon.com/systems-manager/latest/userguide/setup-create-vpc.html))