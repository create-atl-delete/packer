<powershell>

write-output "Running User Data Script"
write-host "(host) Running User Data Script"

Set-ExecutionPolicy Unrestricted -Scope LocalMachine -Force -ErrorAction Ignore

# Don't set this before Set-ExecutionPolicy as it throws an error
$ErrorActionPreference = "stop"

# Install SSM Agent if not present
if (-not (Get-Service AmazonSSMAgent -ErrorAction SilentlyContinue)) {
    Write-Output "SSM Agent not found, installing..."
    Invoke-WebRequest -Uri "https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/windows_amd64/AmazonSSMAgentSetup.exe" -OutFile "$env:TEMP\AmazonSSMAgentSetup.exe"
    Start-Process -FilePath "$env:TEMP\AmazonSSMAgentSetup.exe" -ArgumentList "/install", "/quiet" -Wait
    Remove-Item -Path "$env:TEMP\AmazonSSMAgentSetup.exe" -Force
    Start-Service AmazonSSMAgent
}

# Install sshd
Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0

# Save the private key from intance metadata to administrators_authorized_keys
New-Item C:\ProgramData\ssh\administrators_authorized_keys -ItemType File -ErrorAction SilentlyContinue
Set-Content C:\ProgramData\ssh\administrators_authorized_keys -Value ((New-Object System.Net.WebClient).DownloadString('http://169.254.169.254/latest/meta-data/public-keys/0/openssh-key'))

# Set appropriate permissions on administrators_authorized_keys by copying them from an arbitrary existing key 
Get-ACL C:\ProgramData\ssh\ssh_host_dsa_key | Set-ACL C:\ProgramData\ssh\administrators_authorized_keys

# Set sshd to automatic and re/start
Set-Service sshd -StartupType "Automatic"
Restart-Service sshd

</powershell>