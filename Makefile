.PHONY: package

# vars
PROJECT="genesis"
GENESIS_NAMESPACE ?= argocd

package:
	@rm -rf .orion-helper-scripts orion-install-helper
	@mkdir -p .orion-helper-scripts
	@git worktree add -f .orion-helper-scripts/bootstrap HEAD
	@chmod -R 775 .orion-helper-scripts
	@shar -T -D -Q .orion-helper-scripts/ | head -n -1 > orion-install-helper && echo ".orion-helper-scripts/bootstrap/helper/install.sh" >> orion-install-helper
	@echo The installer was packaged into: orion-install-helper

lint:
	find -name "*.sh" -not -path "./.devbox/*" | xargs shellcheck -x


# workflow
cluster:
	@kind create cluster --name $(PROJECT) --config .kind.yaml || echo "Cluster already exists..."

argocd:
	@kubectl create namespace $(GENESIS_NAMESPACE) || echo "Argo namespace already exists..."
	@kubectl create -n $(GENESIS_NAMESPACE)  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
	@sleep 15
	@kubectl wait --namespace $(GENESIS_NAMESPACE)  \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/name=argocd-server \
		--timeout=90s

ingress:
	@kubectl create -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	@sleep 10
	@kubectl wait --namespace ingress-nginx \
		--for=condition=ready pod \
		--selector=app.kubernetes.io/component=controller \
		--timeout=90s || sleep 10 && kubectl wait --namespace ingress-nginx \
										--for=condition=ready pod \
										--selector=app.kubernetes.io/component=controller \
										--timeout=90s

bootstrap: cluster argocd ingress
	@echo "Running Bootstrap..."
	@helm upgrade -n $(GENESIS_NAMESPACE)  -i -f test.values.yaml $(PROJECT) ./chart/
	@sleep 5
	@kubectl get deployments -n $(GENESIS_NAMESPACE)  -o name | xargs -n1 kubectl rollout restart -n $(GENESIS_NAMESPACE) 
	@sleep 5
	@watch kubectl get applications -n $(GENESIS_NAMESPACE) 

down:
	@kind delete cluster --name $(PROJECT)