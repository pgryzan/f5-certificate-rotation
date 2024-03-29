#!/bin/bash

set -e

#   Utils
sudo apt-get install unzip
sudo snap install jq

#   Move to Temp Directory
cd /tmp

#############################################################################################################################
#   Vault
#############################################################################################################################
#   Download
curl --silent --remote-name https://releases.hashicorp.com/vault/${VAULT_VERSION}/vault_${VAULT_VERSION}_linux_amd64.zip

#   Install
unzip vault_${VAULT_VERSION}_linux_amd64.zip
sudo chown root:root vault
sudo mv vault /usr/local/bin/
vault -autocomplete-install
complete -C /usr/local/bin/vault vault
sudo setcap cap_ipc_lock=+ep /usr/local/bin/vault

cat <<-EOF > vault.service
[Unit]
Description=Vault
Documentation=https://www.vaultproject.io/
Requires=network-online.target
After=network-online.target

[Service]
Restart=on-failure
Environment=GOMAXPROCS=nproc
ExecStart=/usr/local/bin/vault server -dev -dev-root-token-id="root" -dev-listen-address=0.0.0.0:8200
ExecReload=/bin/kill -HUP $MAINPID
KillSignal=SIGTERM

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 755 vault.service
sudo mv vault.service /etc/systemd/system/

#   Enable the Service
sudo systemctl enable vault
sudo service vault start

sleep 10

#   Tell Vault we're using http
echo -e "export VAULT_ADDR=http://127.0.0.1:8200" >> ~/.bash_profile
export VAULT_ADDR=http://127.0.0.1:8200

#   Export VAULT_TOKEN
echo -e "export VAULT_TOKEN=root" >> ~/.bash_profile
export VAULT_TOKEN=root

#   Enable the PKI Engine
vault secrets enable pki

#   Generate a Root CA
vault write pki/root/generate/internal common_name=demo.com  > root-ca

#   Configure a Role
vault write pki/roles/web-certs allowed_domains=demo.com ttl=60s max_ttl=30m allow_subdomains=true allow_localhost=true generate_lease=true

#############################################################################################################################
#   Consul-Template
#############################################################################################################################
#   Download
curl --silent --remote-name https://releases.hashicorp.com/consul-template/${CONSUL_TEMPLATE_VERSION}/consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip

#   Install
unzip consul-template_${CONSUL_TEMPLATE_VERSION}_linux_amd64.zip
sudo chown root:root consul-template
sudo mv consul-template /usr/local/bin/

cat <<-EOF > consul-template.hcl
vault {
    address = "http://127.0.0.1:8200"
    token = "root"
    unwrap_token = false
    renew_token = false
}

syslog {
    enabled = true
    facility = "LOCAL5"
}

template {
    source = "/tmp/https.tmpl"
    destination = "/tmp/https.json"
}

template {
    source = "/tmp/certs.tmpl"
    destination = "/tmp/certs.json"
    #command = ${UPDATE_VIP}"
}
EOF

sudo chmod 755 consul-template.hcl
sudo mkdir -p /etc/consul-template.d
sudo mv consul-template.hcl /etc/consul-template.d

cat <<-EOF > consul-template.service
[Unit]
Description=consul-template
Requires=network-online.target
After=network-online.target

[Service]
EnvironmentFile=-/etc/sysconfig/consul-template
Restart=on-failure
ExecStart=/usr/local/bin/consul-template -config=/etc/consul-template.d/consul-template.hcl
KillSignal=SIGINT

[Install]
WantedBy=multi-user.target
EOF

sudo chmod 755 consul-template.service
sudo mv consul-template.service /etc/systemd/system/

#   Enable the Service
sudo systemctl enable consul-template
sudo service consul-template start

#############################################################################################################################
#   Setup F5
#############################################################################################################################
sudo mv id_rsa ~/.ssh
sudo chown 600 ~/.ssh/id_rsa

wget https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.17.1/f5-appsvcs-3.17.1-1.noarch.rpm
sudo chmod +x install-rpm.sh

COMMANDS="modify auth user ${F5_USERNAME} { password ${F5_PASSWORD} };
modify auth user ${F5_USERNAME} shell bash;
modify sys global-settings gui-setup disabled;
save sys config;
quit;"

echo "Setting up BIG-IP"

index=1
maxConnectionAttempts=12

while (( $index <= $maxConnectionAttempts ))
do
  ssh -o stricthostkeychecking=no -i ~/.ssh/id_rsa ${F5_USERNAME}@${BIG_IP} -y $COMMANDS
  case $? in
    (0) echo "Success"; break ;;
    (*) echo "BIG-IP SSH server not ready yet..." ;;
  esac
  sleep 10
  ((index+=1))
done

echo "Checking for BIG-IP Configuration Utility"
while [[ $(curl --silent --insecure -u ${F5_USERNAME}:${F5_PASSWORD} https://${BIG_IP}:8443/mgmt/tm/ltm | jq .kind) != "\"tm:ltm:ltmcollectionstate\"" ]]
do
   sleep 30
   echo "Trying BIG-IP Configuration Utility again..."
done

echo "Installing RPM"
./install-rpm.sh ${BIG_IP}:8443 ${F5_USERNAME}:${F5_PASSWORD} f5-appsvcs-3.17.1-1.noarch.rpm

sleep 30

echo "Creating BIG-IP VIP"
curl -X POST --silent --insecure -u ${F5_USERNAME}:${F5_PASSWORD} -H 'Content-Type: application/json' -d @https.json https://35.224.91.158:8443/mgmt/shared/appsvcs/declare | jq

exit 0