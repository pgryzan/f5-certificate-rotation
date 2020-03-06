# F5 Certificate Rotation Using Vault and Consul Template
This is an example of how rotate certificates on an F5 LTM using Vault and Consul Template

* To get started, clone the repo to your local drive and create a copy of the terraform.tfvars.example file named terraform.tfvars. 
* Fill in your GCP and SSH credentials.
* Run
  ```bash
  terraform init
  ```
  to initialize Terraform
* Run
  ```bash
  terraform apply -auto-approve
  ```
  to spin up F5 BIP-IP and Hashistack virtual machines. When complete, you should see the output commands

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/Terraform%20Outputs.png "Terraform Output Commands")
  The Big-IP vm takes about 3 to 5 minutes to complete initialization. If you need to reference the Terraform outputs commands, you can always see them again by running
  ```bash
  terraform output
  ```
* We need to install some F5 services need to make this example work. Download the f5-appsvcs RPM from [here](https://github.com/F5Networks/f5-appsvcs-extension/releases/download/v3.17.1/f5-appsvcs-3.17.1-1.noarch.rpm). We are using the f5-appsvcs-3.17.1-1.noarch.rpm located on the [https://github.com/F5Networks/f5-appsvcs-extension/releases](https://github.com/F5Networks/f5-appsvcs-extension/releases) page.
* Open the F5 UI by running the big_ip_address commmand and login using the credentails that are located in the variables.tf file
* Navigate to IApps > Package Management LX > Import and upload the RPM

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/F5%20RPM.png "F5 RPM Import Upload")
  When it's complete you should see the available plugin services.

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/F5%20Plugins.png "F5 Plugin Services")
* Test out the REST endpoint by running the outputs test_as3 command. It should return a json list

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/AS3%20Service%20Test.png "F5 Services Test")
* Upload the VIP declaration, https.json, by running the outputs create_vip command. You should see something like this when refreshing the UI

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/F5%20VIP.png "F5 VIP")
* Now your ready to SSH into the Hashistack vm. Run the outputs ssh_hashistack command to login into the vm and change the directory to /tmp. This is where all of the certificate rotation action is happening.
* Take a look at the certs.tmpl file. This is the temaplate that Consul Template uses to create the certs.json file. The certs.json file is uploaded to the F5 VM to rotate the certificate.
* Take a look at the certs.json file. Notice the we've already setup the Vault PKI Engine to rotate the certificates every 30 seconds. You can watch the remarks timestamp update by running:
  ```bash
  cat certs.json
  ```

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/Generated%20Certs.png "Vault Generated Certificates")
* Finnaly, run the update_vip command on the Hashistack vm. You should see a completion output

  ![alt text](https://github.com/pgryzan/f5-certificate-rotation/blob/master/images/Cert%20Rotation%20Success.png "Certificate Success")
* If you wanted to have Consul Template automatically upload the certificate to the F5 VIP, then uncomment the command variable in the /etc/consul-template.d/consul-template.hcl file and restart the server using
  ```bash
  sudo service consul-template restart
  ```