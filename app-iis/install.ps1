[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Invoke-WebRequest https://chocolatey.org/install.ps1 -UseBasicParsing | Invoke-Expression
& choco feature enable -n allowGlobalConfirmation

# There's no VC14 runtime on Server 2016 by default :o
& choco install vcredist2015

& choco install openssh --params "/SSHAgentFeature /SSHServerFeature"
& ssh-keygen -A
Start-Service ssh-agent
# Use PSExec (psexec.exe -i -s cmd.exe) to run the following:
#ssh-add ssh_host_dsa_key
#ssh-add ssh_host_rsa_key
#ssh-add ssh_host_ecdsa_key
#ssh-add ssh_host_ed25519_key
New-NetFirewallRule -Protocol TCP -LocalPort 22 -Direction Inbound -Action Allow -DisplayName SSH

& choco install git

# Install IIS with FastCGI features

& git clone https://github.com/LukeCarrier/windows-php.git C:\PHP

Copy-Item C:\PHP\bin\config.dist.bat C:\PHP\bin\config.bat
# Patch SET PHP= line in C:\PHP\bin\config.bat

# Create a Moodle user

# Add an IIS FastCGI application for PHP
# Add a MODULE handler mapping (e.g. executable path C:\PHP\embedded\php\php-7.0.13-nts-Win32-VC14-x64\php-cgi.exe|-c C:\Users\moodle\php.ini)
# Add
