.PHONY: help install install-kubectl install-kind install-helm check-os \
        setup-monitoring port-forward stop-port-forward teardown-monitoring

# OSの判定
UNAME_S := $(shell uname -s)

# デフォルトターゲット
help:
	@echo "SRE自動化ハンドブック Vol.2 セットアップ"
	@echo ""
	@echo "使用可能なコマンド:"
	@echo "  make install         - すべてのツールをインストール (kubectl, kind, helm)"
	@echo "  make install-kubectl - kubectlをインストール"
	@echo "  make install-kind    - kindをインストール"
	@echo "  make install-helm    - helmをインストール"
	@echo "  make check-os           - 現在のOSを確認"
	@echo ""
	@echo "Prometheus 監視環境:"
	@echo "  make setup-monitoring    - kindクラスタを作成しPrometheus/Grafana/Alertmanagerをインストール"
	@echo "  make port-forward        - Prometheus(9090)、Grafana(3000)、Alertmanager(9093)へポートフォワード"
	@echo "  make stop-port-forward   - ポートフォワードを停止"
	@echo "  make teardown-monitoring - 監視用kindクラスタを削除"
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

# kindクラスタの作成とPrometheus/Grafana/Alertmanagerのインストール
setup-monitoring:
	@echo "監視用kindクラスタを作成しています..."
	kind create cluster --name monitoring
	@echo ""
	@echo "クラスタの状態を確認しています..."
	kubectl cluster-info --context kind-monitoring
	kubectl get nodes
	@echo ""
	@echo "Helmリポジトリを登録・更新しています..."
	helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
	helm repo add stable https://charts.helm.sh/stable
	helm repo update
	@echo ""
	@echo "Prometheus / Grafana / Alertmanager をインストールしています..."
	helm upgrade --install mon prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		--set kubeStateMetrics.enabled=true \
		--set nodeExporter.enabled=true
	@echo ""
	@echo "✓ インストールが完了しました"
	@echo "すべてのPodが起動するまで待っています (タイムアウト: 5分)..."
	kubectl wait --for=condition=Ready pod --all -n monitoring --timeout=300s

# Prometheus / Grafana / Alertmanager へのポートフォワードを設定
port-forward:
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
	@echo "ポートフォワードを停止するには: make stop-port-forward"

# ポートフォワードを停止
stop-port-forward:
	@echo "ポートフォワードを停止しています..."
	@pkill -f "kubectl port-forward svc/mon-" 2>/dev/null && echo "✓ ポートフォワードを停止しました" || echo "停止対象のポートフォワードが見つかりませんでした"

# 監視用kindクラスタの削除
teardown-monitoring: stop-port-forward
	@echo "監視用kindクラスタを削除しています..."
	kind delete cluster --name monitoring
	@echo "✓ クラスタの削除が完了しました"
