.PHONY: help install install-kubectl install-kind install-helm check-os

# OSの判定
UNAME_S := $(shell uname -s)

# デフォルトターゲット
help:
	@echo "SRE自動化ハンドブック Vol.2 - Chapter 2 セットアップ"
	@echo ""
	@echo "使用可能なコマンド:"
	@echo "  make install         - すべてのツールをインストール (kubectl, kind, helm)"
	@echo "  make install-kubectl - kubectlをインストール"
	@echo "  make install-kind    - kindをインストール"
	@echo "  make install-helm    - helmをインストール"
	@echo "  make check-os        - 現在のOSを確認"
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
