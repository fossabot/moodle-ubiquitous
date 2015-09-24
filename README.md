# The Perfect Cluster: Moodle

A work in progress sample Moodle configuration comprised of:

* Configuration management with [Salt](https://docs.saltstack.com/en/getstarted/)
* Static file serving with [nginx](http://nginx.org/)
* [PHP 5.6](http://php.net/), with OPcache

* * *

## Network configuration

For the purposes of this guide, we're assuming the following configuration. To
simplify your configuration, just do a find/replace on this document with your
details.

### IP addresses

| IP address    | Hostname       | Server role |
| ------------- | -------------- | ----------- |
| 192.168.120.5 | ```salt.flo``` | Salt master |

### Configuration values

| Configuration item                 | Value                                                 |
| ---------------------------------- | ----------------------------------------------------- |
| Administrative user                | ```admin```                                           |
| Salt master public key fingerprint | ```3e:91:ad:e7:be:1f:63:16:c2:be:60:2b:7d:d5:f8:42``` |

## Future tasks

* Configure the Salt master to run in a [non-root configuration](https://docs.saltstack.com/en/latest/ref/configuration/nonroot.html).

## New server configuration

All servers in the cluster will be configured as Salt minions. Salt will handle
configuring our servers based on roles which we'll define later. This section
assumes a stock, minimal installation of CentOS 7 with networking correctly
configured.

Start SSHd and instruct systemd to launch the service at boot time:

    $ sudo systemctl start sshd
    $ sudo systemctl enable sshd

Allow inbound SSH traffic through the firewall:

    $ sudo firewall-cmd --permanent --zone=public --add-service=ssh
    $ sudo firewall-cmd --reload

Add the SaltStack RPM repository:

    $ sudo rpm --import https://repo.saltstack.com/yum/rhel7/SALTSTACK-GPG-KEY.pub
    $ echo '[saltstack-repo]
    name=SaltStack repo for RHEL/CentOS $releasever
    baseurl=https://repo.saltstack.com/yum/rhel$releasever
    enabled=1
    gpgcheck=1
    gpgkey=https://repo.saltstack.com/yum/rhel$releasever/SALTSTACK-GPG-KEY.pub' | sudo tee /etc/yum.repos.d/saltstack.repo

Configure the server as a Salt minion:

    $ sudo yum install -y salt-minion
    $ sudo sed -i "s/#master:.*/master: 192.168.120.5/" /etc/salt/minion

The minion and master now need to exchange public keys to verify their
respective identities. Substitute the key below for the one you obtained from
your master during configuration. If you're currently configuring your master,
skip to the Salt master section of this document and return when you're done.

    $ sudo sed -i "s/#master_finger:.*/master_finger: '3e:91:ad:e7:be:1f:63:16:c2:be:60:2b:7d:d5:f8:42'/" /etc/salt/minion

Start and enable the Salt minion daemon on boot:

    $ sudo systemctl start salt-minion
    $ sudo systemctl enable salt-minion

Now query its public key -- we need to verify this in the next step:

    $ sudo salt-call --local key.finger

To complete the key exchange, log in to the Salt master and execute the
following command to list all keys:

    $ sudo salt-key -l all

In the "Unaccepted Keys" section, you should see the hostname of the server
you've been working on (in our case, ```salt.flo```). To verify its public key:

    $ sudo salt-key -f salt.flo

Assuming these two fingerprints are identical, we'll want to approve the key,
and hit ```[Return]``` when prompted to confirm:

    $ sudo salt-key -a salt.flo

To confirm everything's working correctly, we'll finish by sending the server
a ```test.ping``` operation:

    $ sudo salt salt.flo test.ping

### Salt master

Install the Salt master and some tools for managing our configuration:

    $ sudo yum install git salt-master vim-enhanced

Configure the Salt master:

    $ sudo sed -i "s/#interface:.*/interface: 192.168.120.5/" /etc/salt/master

Start the Salt master and launch it at boot time:

    $ sudo systemctl start salt-master
    $ sudo systemctl enable salt-master

Export the master's public key fingerprint, and store it for later. We'll need
this when adding Salt minions to facilitate secure key exchange.

    $ sudo salt-key -F master | grep master.pub | cut -d' ' -f3-

Create the state tree based upon the contents of this repository and tighten its
permissions to prevent writes from unauthorised users:

    $ sudo git clone https://github.com/LukeCarrier/moodle-cluster /srv/salt
    $ sudo chown -R admin:admin /srv/salt
    $ find /srv/salt -type d -exec chmod 750 {} \;
    $ find /srv/salt -type f -exec chmod 640 {} \;