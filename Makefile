.PHONY: all setup cluster build import deploy check clean

#  Commande par défaut : lance tout le processus de A à Z
all: setup cluster build import deploy check

#  1. Installation des dépendances (Packer, Ansible, Libs)
setup:
	@echo "--- [1/6] Installation des prérequis ---"
	@# Correction préventive pour éviter l'erreur de dépôt yarn fréquente dans Codespaces
	sudo rm -f /etc/apt/sources.list.d/yarn.list
	@# Installation de Packer
	curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
	sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" -y
	sudo apt-get update
	sudo apt-get install packer -y
	@# Installation des outils Python pour Ansible et K8s
	pip install --upgrade pip
	pip install ansible kubernetes requests
	ansible-galaxy collection install kubernetes.core
	@echo "✅ Environnement prêt."

#  2. Création du cluster K3d (si inexistant)
cluster:
	@echo "--- [2/6] Vérification du cluster K3d ---"
	@# Installe K3d si la commande n'existe pas
	which k3d > /dev/null || curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
	@# Crée le cluster 'lab' seulement s'il n'existe pas déjà
	k3d cluster list | grep -q "lab" || k3d cluster create lab --servers 1 --agents 2
	@echo "✅ Cluster K3d opérationnel."

#  3. Construction de l'image Docker avec Packer
build:
	@echo "--- [3/6] Build de l'image Packer ---"
	packer init nginx.pkr.hcl
	packer build nginx.pkr.hcl
	@echo "✅ Image 'my-custom-nginx:v1' construite."

#  4. Import de l'image dans le cluster (Étape critique pour K3d)
import:
	@echo "--- [4/6] Import de l'image dans K3d ---"
	k3d image import my-custom-nginx:v1 -c lab
	@echo "✅ Image importée dans le cluster."

#  5. Déploiement via Ansible
deploy:
	@echo "--- [5/6] Déploiement Ansible ---"
	ansible-playbook playbook.yml
	@echo "✅ Playbook exécuté."

#  6. Vérification finale
check:
	@echo "--- [6/6] État du déploiement ---"
	@sleep 5 # Petite pause pour laisser le temps aux pods de démarrer
	kubectl get pods
	kubectl get svc
	@echo "🎉 Succès ! L'application est déployée."

#  Nettoyage (Optionnel)
clean:
	k3d cluster delete lab
	docker rmi my-custom-nginx:v1
