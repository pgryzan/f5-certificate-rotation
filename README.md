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
  The Big-IP vm takes about 3 to 5 minutes to complete initialization.


