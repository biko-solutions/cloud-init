#!/bin/bash
sudo adduser --system --quiet --shell=/bin/bash --home=/home/bikoadmin --gecos 'BIKO sysadmin' --group bikoadmin
sudo mkdir /home/bikoadmin/.ssh
sudo chown -R bikoadmin:bikoadmin /home/bikoadmin/.ssh/
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQD2W9EXH66GBjLHDyv9ztWn3J1YcOoqlGqZDHAbeEYlxLz2ju06dPrSTjxiuabeDhF3Nu7BDykhOBikn+Hsj4KTzEEEX8mqC+94Z39DgFn2trgEV205vgl7FnBEVKQAMFvXsW7NH5Tl8eyIvyALNFbwPT5FtV9CVgkmLIWuJHDQQiztDRFihbXU2JXKvd4PnLAwoBvohtPJ/HO9b6tO18OAGopAHWmhDwAYaz1CsDE8k8A1hCOOrvah9CBjdU5wicmcVGacCcUNav1ij6Km/k9XJfji5Png88tSWx0PYE1Hu4i+jWT8yLbDDEJDRqXP2fLMvDc2jXsQ1rZuZpkAC+VMU9/zWsZMKv3lpTfN2S3TG/wXalyJx9AxqrTDBG/myFiGzA9Z7uOA2P/lHh/VmIh5dDX+ZjF7djH7o5z73eKVHuc/ryyU/2FEc5pWiSRJHAQ4vVx+EuVYmRXtL7K4ZjYSOia+RokevhBgxrlxuLyF+sMsz1r9zeZybGKS/ju4/p0= external sysadmin" | sudo tee /home/bikoadmin/.ssh/authorized_keys > /dev/null
sudo sed -i "/AllowUsers/s/$/ bikoadmin/" /etc/ssh/sshd_config;\
echo "bikoadmin ALL=(ALL) NOPASSWD:ALL" | sudo tee /etc/sudoers.d/90-bikoadmin > /dev/null
sudo systemctl restart ssh sshd
