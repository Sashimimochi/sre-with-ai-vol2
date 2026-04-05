.PHONY: help install install-kubectl install-kind install-helm check-os \
        setup teardown teardown-all \
        setup-monitoring port-forward-monitoring stop-port-forward-monitoring teardown-monitoring \
        get-grafana-password create-slack-secret \
        setup-dify port-forward-dify stop-port-forward-dify teardown-dify \
        setup-mcp port-forward-mcp stop-port-forward-mcp teardown-mcp \
        port-forward stop-port-forward apply delete operator del-operator

# OSの判定
UNAME_S := $(shell uname -s)

# ローカル共有クラスタ名 (monitoring と dify を同じクラスタに収容)
# クラウド等で別クラスタを使いたい場合は環境変数で上書き可能:
#   CLUSTER_NAME=my-cluster make setup-monitoring
CLUSTER_NAME ?= local
MONITOR_NAMESPACE=monitoring
PROM_OPER_REL=mon
ELASTIC_NAMESPACE="elastic-system"
ELASTICSEARC_ENDPOINT=http://elastic.local
ELASTIC_OPERATOR_VERSION=2.14.0

# ============================================================
# 共通処理定義
# ============================================================

# kindクラスタを作成してクラスタの状態を確認する
# 既にクラスタが存在する場合はスキップして再利用する (冪等)
# 使い方: $(call create-kind-cluster,<クラスタ名>)
define create-kind-cluster
	@if kind get clusters 2>/dev/null | grep -q "^$(1)$$"; then \
		echo "kindクラスタ '$(1)' は既に存在しています。既存クラスタを使用します。"; \
	else \
		echo "kindクラスタを作成しています ($(1))..."; \
		kind create cluster --name $(1); \
	fi
	@echo ""
	@echo "クラスタの状態を確認しています..."
	kubectl cluster-info --context kind-$(1)
	kubectl get nodes
	@echo ""
endef

# 指定したnamespaceのすべてのPodが起動するまで待つ
# 使い方: $(call wait-for-pods,<namespace>)
define wait-for-pods
	@echo "すべてのPodが起動するまで待っています (タイムアウト: 10分)..."
	kubectl wait --for=condition=Ready pod --all -n $(1) --timeout=600s
	@echo ""
endef

# デフォルトターゲット
help:
	@echo "SRE自動化ハンドブック Vol.2 セットアップ"
	@echo ""
	@echo "使用可能なコマンド:"
	@echo "  make install         - すべてのツールをインストール (kubectl, kind, helm)"
	@echo "  make install-kubectl - kubectlをインストール"
	@echo "  make install-kind    - kindをインストール"
	@echo "  make install-helm    - helmをインストール"
	@echo "  make check-os        - 現在のOSを確認"
	@echo ""
	@echo "汎用コマンド:"
	@echo "  make setup                 - kindクラスタを作成しPrometheus/Grafana/Alertmanager + Difyをインストール"
	@echo "  make port-forward          - すべてのサービス (Prometheus/Grafana/Alertmanager/Dify) へポートフォワード"
	@echo "  make stop-port-forward     - すべてのポートフォワードを停止"
	@echo "  make teardown              - すべてのコンポーネントとkindクラスタを削除 (teardown-allの別名)"
	@echo ""
	@echo "Prometheus 監視環境:"
	@echo "  make setup-monitoring      - kindクラスタを作成しPrometheus/Grafana/Alertmanagerをインストール"
	@echo "  make create-slack-secret   - .envのWebhook URLをKubernetes Secretに登録"
	@echo "  make port-forward-monitoring - Prometheus(9090)、Grafana(3000)、Alertmanager(9093)へポートフォワード"
	@echo "  make stop-port-forward-monitoring - 監視系ポートフォワードを停止"
	@echo "  make teardown-monitoring   - 監視コンポーネントを削除 (クラスタは維持)"
	@echo "  make get-grafana-password  - GrafanaのAdminパスワードを取得"
	@echo ""
	@echo "Dify 環境:"
	@echo "  make setup-dify            - kindクラスタを作成しDifyをインストール"
	@echo "  make port-forward-dify     - Dify Web UI(8080)へポートフォワード"
	@echo "  make stop-port-forward-dify - Difyのポートフォワードを停止"
	@echo "  make teardown-dify         - Difyコンポーネントを削除 (クラスタは維持)"
	@echo ""
	@echo "Prometheus MCP サーバー:"
	@echo "  make setup-mcp             - Prometheus MCPサーバーをデプロイ (monitoring namespace)"
	@echo "  make port-forward-mcp      - Prometheus MCPサーバー(9000)へポートフォワード"
	@echo "  make stop-port-forward-mcp - MCPサーバーのポートフォワードを停止"
	@echo "  make teardown-mcp          - MCPサーバーを削除 (クラスタは維持)"
	@echo ""
	@echo "クラスタ管理:"
	@echo "  make teardown-all          - すべてのポートフォワードを停止してkindクラスタを削除"
	@echo ""
	@echo "共有クラスタ名: $(CLUSTER_NAME)  (CLUSTER_NAME=<名前> で上書き可能)"
	@echo ""
	@echo "検出されたOS: $(UNAME_S)"

# OSの確認
check-os:
	@echo "検出されたOS: $(UNAME_S)"
ifeq ($(UNAME_S),Darwin)
	@echo "macOSを検出しました"
else ifeq ($(UNAME_S),Linux)
	@echo "Linuxを検出しました"
else
	@echo "警告: サポートされていないOSです。MacまたはLinux (WSL2含む) を使用してください。"
endif

# すべてのツールをインストール
install: install-kubectl install-kind install-helm
	@echo ""
	@echo "✓ すべてのツールのインストールが完了しました"
	@echo ""
	@echo "インストールされたバージョンを確認:"
	@kubectl version --client 2>/dev/null || echo "kubectl: インストール確認に失敗"
	@kind version 2>/dev/null || echo "kind: インストール確認に失敗"
	@helm version 2>/dev/null || echo "helm: インストール確認に失敗"

# kubectlのインストール
# Kubernetes公式ドキュメントの推奨インストール方法を使用
# https://kubernetes.io/docs/tasks/tools/
install-kubectl:
	@echo "kubectlをインストールしています..."
ifeq ($(UNAME_S),Darwin)
	@if command -v kubectl >/dev/null 2>&1; then \
		echo "kubectl は既にインストールされています"; \
	else \
		if command -v brew >/dev/null 2>&1; then \
			brew install kubectl; \
		else \
			echo "エラー: Homebrewがインストールされていません"; \
			echo "Homebrewをインストールするには: /bin/bash -c \"\$$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""; \
			exit 1; \
		fi \
	fi
else ifeq ($(UNAME_S),Linux)
	@if command -v kubectl >/dev/null 2>&1; then \
		echo "kubectl は既にインストールされています"; \
	else \
		curl -LO "https://dl.k8s.io/release/$$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"; \
		chmod +x kubectl; \
		sudo mv kubectl /usr/local/bin/; \
		echo "✓ kubectlのインストールが完了しました"; \
	fi
else
	@echo "エラー: サポートされていないOSです"
	@exit 1
endif

# kindのインストール
# kind公式ドキュメントの推奨インストール方法を使用
# https://kind.sigs.k8s.io/docs/user/quick-start/
install-kind:
	@echo "kindをインストールしています..."
ifeq ($(UNAME_S),Darwin)
	@if command -v kind >/dev/null 2>&1; then \
		echo "kind は既にインストールされています"; \
	else \
		if command -v brew >/dev/null 2>&1; then \
			brew install kind; \
		else \
			echo "エラー: Homebrewがインストールされていません"; \
			exit 1; \
		fi \
	fi
else ifeq ($(UNAME_S),Linux)
	@if command -v kind >/dev/null 2>&1; then \
		echo "kind は既にインストールされています"; \
	else \
		curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64; \
		chmod +x ./kind; \
		sudo mv ./kind /usr/local/bin/kind; \
		echo "✓ kindのインストールが完了しました"; \
	fi
else
	@echo "エラー: サポートされていないOSです"
	@exit 1
endif

# helmのインストール
# Helm公式ドキュメントの推奨インストール方法を使用
# https://helm.sh/docs/intro/install/
install-helm:
	@echo "helmをインストールしています..."
ifeq ($(UNAME_S),Darwin)
	@if command -v helm >/dev/null 2>&1; then \
		echo "helm は既にインストールされています"; \
	else \
		if command -v brew >/dev/null 2>&1; then \
			brew install helm; \
		else \
			echo "エラー: Homebrewがインストールされていません"; \
			exit 1; \
		fi \
	fi
else ifeq ($(UNAME_S),Linux)
	@if command -v helm >/dev/null 2>&1; then \
		echo "helm は既にインストールされています"; \
	else \
		curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash; \
		echo "✓ helmのインストールが完了しました"; \
	fi
else
	@echo "エラー: サポートされていないOSです"
	@exit 1
endif

# Slack Webhook URLをKubernetes Secretに登録
create-slack-secret:
	@if [ ! -f .env ]; then \
		echo "エラー: .envファイルが見つかりません。.env.exampleを参考に作成してください"; \
		exit 1; \
	fi
	@echo "Slack Webhook URLをSecretに登録しています..."
	kubectl create secret generic alertmanager-slack-url \
		--from-env-file=.env \
		--namespace monitoring \
		--dry-run=client -o yaml | kubectl apply -f -
	@echo "✓ Secretの登録が完了しました"

# kindクラスタの作成とPrometheus/Grafana/Alertmanagerのインストール
setup-monitoring:
	$(call create-kind-cluster,$(CLUSTER_NAME))
	@echo "Helmリポジトリを登録・更新しています..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add stable https://charts.helm.sh/stable
	helm repo update
	@echo ""
	@echo "Prometheus / Grafana / Alertmanager をインストールしています..."
	helm upgrade --install mon prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		-f prom-values.yaml
	@echo ""
	@echo "✓ インストールが完了しました"
	@echo "Operator / Grafana / Alertmanager / Exporterの起動を待っています (タイムアウト: 15分)..."
	kubectl wait --for=condition=Ready pod \
		-l 'app.kubernetes.io/managed-by=Helm' \
		-n monitoring --timeout=900s
	@echo "PrometheusのStatefulSet Podの起動を待っています (タイムアウト: 15分)..."
	kubectl wait --for=condition=Ready pod \
		-l 'operator.prometheus.io/name=mon-kube-prometheus-stack-prometheus' \
		-n monitoring --timeout=900s
	@echo ""
	$(MAKE) create-slack-secret

# Prometheus / Grafana / Alertmanager へのポートフォワードを設定
port-forward-monitoring:
	@echo "Prometheusへのポートフォワードを設定しています (http://localhost:9090)..."
	kubectl port-forward svc/mon-kube-prometheus-stack-prometheus 9090:9090 -n monitoring &
	@echo "Grafanaへのポートフォワードを設定しています (http://localhost:3000)..."
	kubectl port-forward svc/mon-grafana 3000:80 -n monitoring &
	@echo "Alertmanagerへのポートフォワードを設定しています (http://localhost:9093)..."
	kubectl port-forward svc/mon-kube-prometheus-stack-alertmanager 9093:9093 -n monitoring &
	@echo ""
	@echo "✓ ポートフォワードの設定が完了しました"
	@echo "  Prometheus:    http://localhost:9090"
	@echo "  Grafana:       http://localhost:3000  (デフォルト: admin / prom-operator)"
	@echo "  Alertmanager:  http://localhost:9093"
	@echo ""
	@echo "ポートフォワードを停止するには: make stop-port-forward-monitoring"

# 監視系ポートフォワードを停止
stop-port-forward-monitoring:
	@echo "監視系ポートフォワードを停止しています..."
	@pkill -f "kubectl port-forward svc/mon-" 2>/dev/null && echo "✓ ポートフォワードを停止しました" || echo "停止対象のポートフォワードが見つかりませんでした"

# 監視用kindクラスタの削除
teardown-monitoring: stop-port-forward-monitoring
	@echo "監視コンポーネントを削除しています..."
	helm uninstall mon --namespace monitoring 2>/dev/null || echo "監視用Helmリリース (mon) が見つかりませんでした"
	kubectl delete namespace monitoring --ignore-not-found=true
	@echo "✓ 監視コンポーネントの削除が完了しました (クラスタは維持されています)"

# GrafanaのAdminパスワードを取得
get-grafana-password:
	@echo "GrafanaのAdminパスワードを取得しています..."
	@kubectl get secret mon-grafana -n monitoring -o json | jq -r '.data."admin-password"' | base64 --decode ; echo

# kindクラスタの作成とDifyのインストール
setup-dify:
	$(call create-kind-cluster,$(CLUSTER_NAME))
	@echo "Helmリポジトリを登録・更新しています..."
	helm repo add dify https://borispolonsky.github.io/dify-helm
	helm repo update
	@echo ""
	@echo "Dify をインストールしています..."
	helm upgrade --install dify dify/dify \
		--namespace dify \
		--create-namespace \
		-f dify-values.yaml
	@echo ""
	@echo "✓ インストールが完了しました"
	$(call wait-for-pods,dify)

# Dify へのポートフォワードを設定
port-forward-dify:
	@echo "Dify Web UIへのポートフォワードを設定しています (http://localhost:8080)..."
	kubectl port-forward -n dify svc/dify 8080:80 &
	@echo ""
	@echo "✓ ポートフォワードの設定が完了しました"
	@echo "  Dify Web UI: http://localhost:8080"
	@echo ""
	@echo "ポートフォワードを停止するには: make stop-port-forward-dify"

# Dify のポートフォワードを停止
stop-port-forward-dify:
	@echo "Dify のポートフォワードを停止しています..."
	@pkill -f "kubectl port-forward.*svc/dify" 2>/dev/null && echo "✓ ポートフォワードを停止しました" || echo "停止対象のポートフォワードが見つかりませんでした"

# Dify用kindクラスタの削除
teardown-dify: stop-port-forward-dify
	@echo "Difyコンポーネントを削除しています..."
	helm uninstall dify --namespace dify 2>/dev/null || echo "Dify用Helmリリース (dify) が見つかりませんでした"
	kubectl delete namespace dify --ignore-not-found=true
	@echo "✓ Difyコンポーネントの削除が完了しました (クラスタは維持されています)"

# Prometheus MCPサーバーのデプロイ (monitoring namespace に統合)
setup-mcp:
	@echo "Prometheus MCP サーバーをデプロイしています..."
	kubectl apply -f manifests/prometheus-mcp-deployment.yaml
	kubectl apply -f manifests/prometheus-mcp-service.yaml
	@echo ""
	@echo "✓ デプロイが完了しました"
	@echo "Prometheus MCP Podの起動を待っています (タイムアウト: 5分)..."
	kubectl wait --for=condition=Ready pod \
		-l app=prometheus-mcp \
		-n monitoring --timeout=300s
	@echo ""
	@echo "Grafana MCP サーバーをデプロイしています..."
	kubectl apply -f manifests/grafana-mcp-deployment.yaml
	kubectl apply -f manifests/grafana-mcp-service.yaml
	@echo ""
	@echo "✓ デプロイが完了しました"
	@echo "Grafana MCP Podの起動を待っています (タイムアウト: 5分)..."
	kubectl wait --for=condition=Ready pod \
		-l app=grafana-mcp \
		-n monitoring --timeout=300s
	@echo ""

# Prometheus MCPサーバーへのポートフォワードを設定
port-forward-mcp:
	@echo "Prometheus MCPサーバーへのポートフォワードを設定しています (http://localhost:9000)..."
	kubectl port-forward svc/prometheus-mcp 9000:9000 -n monitoring &
	@echo "Prometheus MCPサーバーへのポートフォワードを設定しています (http://localhost:8081)..."
	kubectl port-forward svc/grafana-mcp 8081:8081 -n monitoring &
	@echo ""
	@echo "✓ ポートフォワードの設定が完了しました"
	@echo "  Prometheus MCP: http://localhost:9000/mcp"
	@echo "  Grafana MCP:    http://localhost:8081/mcp"
	@echo ""
	@echo "ポートフォワードを停止するには: make stop-port-forward-mcp"

# Prometheus MCPサーバーのポートフォワードを停止
stop-port-forward-mcp:
	@echo "Prometheus MCPサーバーのポートフォワードを停止しています..."
	@pkill -f "kubectl port-forward svc/prometheus-mcp" 2>/dev/null && echo "✓ ポートフォワードを停止しました" || echo "停止対象のポートフォワードが見つかりませんでした"
	@pkill -f "kubectl port-forward svc/grafana-mcp" 2>/dev/null && echo "✓ ポートフォワードを停止しました" || echo "停止対象のポートフォワードが見つかりませんでした"

# Prometheus MCPサーバーを削除
teardown-mcp: stop-port-forward-mcp
	@echo "Prometheus MCP サーバーを削除しています..."
	kubectl delete -f manifests/prometheus-mcp-service.yaml --ignore-not-found=true
	kubectl delete -f manifests/prometheus-mcp-deployment.yaml --ignore-not-found=true
	@echo "✓ Prometheus MCP サーバーの削除が完了しました"
	@echo "Grafana MCP サーバーを削除しています..."
	kubectl delete -f manifests/grafana-mcp-service.yaml --ignore-not-found=true
	kubectl delete -f manifests/grafana-mcp-deployment.yaml --ignore-not-found=true
	@echo "✓ Grafana MCP サーバーの削除が完了しました"

# 汎用コマンド: monitoring と Dify を一度に構築する
setup: setup-monitoring setup-dify setup-mcp

# すべてのサービスへのポートフォワードを一度に設定する
port-forward: port-forward-monitoring port-forward-dify port-forward-mcp
	@echo ""
	@echo "✓ すべてのポートフォワードの設定が完了しました"
	@echo "  Prometheus:     http://localhost:9090"
	@echo "  Grafana:        http://localhost:3000  (デフォルト: admin / prom-operator)"
	@echo "  Alertmanager:   http://localhost:9093"
	@echo "  Dify Web UI:    http://localhost:8080"
	@echo "  Prometheus MCP: http://localhost:9000/mcp"
	@echo ""
	@echo "ポートフォワードを停止するには: make stop-port-forward"

# すべてのポートフォワードを停止する
stop-port-forward: stop-port-forward-monitoring stop-port-forward-dify stop-port-forward-mcp

# クラスタ全体を削除する (すべてのコンポーネントのポートフォワードを停止してからクラスタを削除)
teardown-all: stop-port-forward
	@echo "ローカルkindクラスタを削除しています ($(CLUSTER_NAME))..."
	kind delete cluster --name $(CLUSTER_NAME)
	@echo "✓ クラスタの削除が完了しました"

teardown: teardown-all


operator:
	kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/main/deploy/static/provider/kind/deploy.yaml
	kubectl wait --namespace ingress-nginx \
  --for=condition=available \
	deployment.apps/ingress-nginx-controller \
  --timeout=90s
	sleep 10
	kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=90s
	helm install elastic-operator elastic/eck-operator -n $(ELASTIC_NAMESPACE) --create-namespace --version $(ELASTIC_OPERATOR_VERSION)
	kubectl wait --namespace $(ELASTIC_NAMESPACE) \
  --for=condition=ready \
	pod/elastic-operator-0 \
  --timeout=90s

del-operator:
	helm delete elastic-operator -n $(ELASTIC_NAMESPACE)

delete:
	kubectl delete -f manifest/
	helm uninstall elastic-exporter

apply:
	helm install fluentd fluent/fluentd -f fluent-values.yaml
	kubectl apply -f manifests/elasticsearch/
	sleep 60
	kubectl wait --namespace $(ELASTIC_NAMESPACE) \
  --for=condition=ready \
	pod/quickstart-es-default-0 \
  --timeout=2400s
	helm install elastic-exporter prometheus-community/prometheus-elasticsearch-exporter -f elastic-exporter-values.yaml -n $(ELASTIC_NAMESPACE)

password:
	$(eval PASSWORD=`kubectl get secret quickstart-es-elastic-user -n $(ELASTIC_NAMESPACE) -o go-template='{{.data.elastic | base64decode}}'`)
	echo $(PASSWORD)

healthcheck:
	curl -u "elastic:$(PASSWORD)" -k "$(ELASTICSEARC_ENDPOINT)/_cluster/health?pretty"

setpassword:
	kubectl create secret generic quickstart-canary-es-elastic-user -n $(ELASTIC_NAMESPACE) --from-literal=elastic=$(PASSWORD) --dry-run=client -o yaml | kubectl apply -f -
