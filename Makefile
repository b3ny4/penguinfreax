
.PHONY: all terraform ansible

all:
	make terraform
	@echo
	@echo
	@echo Make sure ec2 instance is running
	@echo Make sure all domains resolve properly before continuing.
	@read -p "Press Any key to continue"
	make ansible

terraform: ${HOME}/.aws/credentials terraform.tfvars
	terraform init &&\
	terraform validate &&\
	terraform apply &&\
	terraform init &&\
	echo "Please update the nameserver at your registrar" &&\
	cat nameservers

${HOME}/.aws/credentials:
	aws configure

domains:
	@echo "Your domains:"
	@read INPUT;echo "$${INPUT}" >> $@;\
	read INPUT;\
	until [ -z "$${INPUT}" ]; do echo "$${INPUT}" >> $@; read INPUT; done
	echo "" >> $@

ssh/ssh_key:
	mkdir -p ssh
	ssh-keygen -f $@

ssh/ssh_key.pub: ssh/ssh_key

terraform.tfvars: ssh/ssh_key.pub domains
	echo "public_key = \"" >> ssh/tmp.tfvars
	cat $< >> ssh/tmp.tfvars
	echo "\"" >> ssh/tmp.tfvars
	cat ssh/tmp.tfvars | tr -d "\n" >> $@
	rm -rf ssh/tmp.tfvars
	echo "" >> $@
	@read -p "Region to provision in: " REGION;\
	echo "region = \"$${REGION}\"" >> $@
	@read INPUT < domains; echo "server_name = \"$${INPUT}\"" >> $@; echo -n "domains = [\"$${INPUT}\"" >> $@;\
	for line in $$(tail --lines=+2 domains); do echo -n ",\"$${line}\"" >> $@; done
	echo "]" >> $@

ansible: ansible_wordpress.bs ansible_wordpress/roles/wordpress/defaults/main.yml
	cd ansible_wordpress &&\
	ansible-playbook -i inventory/production site.yml

ansible_wordpress.bs: ansible_wordpress/roles/bootstrap/defaults/main.yml
	cd ansible_wordpress &&\
	ansible-galaxy collection install -r requirements.yml &&\
	ansible-playbook -i inventory/bootstrap bootstrap.yml
	touch $@

ansible_wordpress/roles/bootstrap/defaults/main.yml:
	mkdir -p ansible_wordpress/roles/bootstrap/defaults
	echo "---" > $@
	echo "# file: roles/bootstrap/defaults/main.yml" >> $@
	@echo
	@echo "Please give a new become_password"
	@echo "become_password: \"$$(openssl passwd -6 --salt `cat /dev/urandom | tr -dc "[:alnum:]" | fold -w "$${1:-30}" | head -n 1` | tee /dev/tty | tail -n 1)\"" >> $@

ansible_wordpress/roles/wordpress/defaults/main.yml: domains
	mkdir -p ansible_wordpress/roles/wordpress/defaults
	echo "---" > $@
	echo "# file: roles/wordpress/defaults/main.yml" >> $@
	echo "domains:" >> $@
	for line in $$(cat domains); do echo "  - $${line}" >> $@; done
