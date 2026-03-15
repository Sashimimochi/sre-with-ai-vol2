# sre-with-ai-vol2

## ローカルKubernetes環境のセットアップ

## 対応環境

- macOS (Homebrew経由)
- Linux (Ubuntu/Debian等)
- Windows (WSL2上のLinux)

## 前提条件

### macOS
- Homebrewがインストールされていること
  - インストールされていない場合: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`

### Linux / WSL2
- curlがインストールされていること
- sudoコマンドが使用可能であること

## インストール方法

### すべてのツールを一括でインストール

```bash
make install
```

このコマンドで以下のツールがインストールされます：
- kubectl: Kubernetesクラスタを操作するCLIツール
- kind: Docker上でKubernetesクラスタを動かすツール
- helm: Kubernetesのパッケージマネージャ

### 個別にインストール

必要なツールのみをインストールすることも可能です：

```bash
# kubectlのみをインストール
make install-kubectl

# kindのみをインストール
make install-kind

# helmのみをインストール
make install-helm
```

## 使用可能なコマンド

すべての使用可能なコマンドを確認するには：

```bash
make help
```

または単に：

```bash
make
```

## クラスタ設計方針

### ローカル (kind) 環境

monitoring と Dify は **同一の kind クラスタ** (`kind-local`) に異なる Namespace (`monitoring` / `dify`) で共存させます。

| コンポーネント | Namespace |
|---|---|
| Prometheus / Grafana / Alertmanager | `monitoring` |
| Dify | `dify` |

**同一クラスタを採用した理由:**
- ローカルマシンのリソースを節約できる (kind クラスタはそれぞれ Docker コンテナを消費する)
- Prometheus が Dify の Pod メトリクスを同一クラスタ内で直接スクレイプできる
- 単一の kubectl コンテキストで全コンポーネントを操作できる

クラスタ名は `CLUSTER_NAME` 変数で上書きできます:

```bash
# 例: 別の名前でクラスタを作成したい場合
CLUSTER_NAME=my-cluster make setup
```

### クラウド環境での運用 (将来の対応)

クラウド (EKS / GKE / AKS 等) では用途やチームに応じて柔軟に選択できます:

| 構成 | 適用場面 |
|---|---|
| 同一クラスタ・別 Namespace | リソース共有を優先する小規模環境 |
| 別クラスタ | セキュリティ分離・独立スケールが必要な本番環境 |

Makefile の `CLUSTER_NAME` 変数と各 `setup-*` ターゲットはどちらの構成にも対応できる設計になっています。

## Prometheus 監視環境のセットアップ

### 全コンポーネントの一括構築

monitoring と Dify を一度に構築するには:

```bash
make setup
```

実行内容:
1. デフォルト名 `local` の kind クラスタを作成 (既に存在する場合はスキップ)
2. Prometheus / Grafana / Alertmanager をインストール (`monitoring` namespace)
3. Dify をインストール (`dify` namespace)

### 監視環境のみ構築

```bash
make setup-monitoring
```

実行内容:
1. デフォルト名 `local` の kind クラスタを作成 (既に存在する場合はスキップ)
2. クラスタの状態・ノードを確認
3. `prometheus-community` Helmリポジトリを登録・更新
4. `kube-prometheus-stack` (Prometheus / Grafana / Alertmanager) をインストール
5. Podの起動を待機

### ブラウザからのアクセス

すべてのサービス (Prometheus / Grafana / Alertmanager / Dify) のポートフォワードを一度に設定するには:

```bash
make port-forward
```

| サービス | URL | 備考 |
|---|---|---|
| Prometheus | http://localhost:9090 | |
| Grafana | http://localhost:3000 | デフォルト: admin / prom-operator |
| Alertmanager | http://localhost:9093 | |
| Dify Web UI | http://localhost:8080 | |

監視系のみポートフォワードしたい場合:

```bash
make port-forward-monitoring
```

> **ヒント**: パスワードを確認したい場合は `make get-grafana-password` で取得できます。

ポートフォワードをすべて停止するには:

```bash
make stop-port-forward
```

### Grafanaパスワードの確認

Kubernetesシークレットに保存されているパスワードを確認する場合は、以下のコマンドを使用します。

```bash
make get-grafana-password
```

### 監視コンポーネントの削除

監視コンポーネント (Prometheus/Grafana/Alertmanager) のみを削除してクラスタを維持する場合:

```bash
make teardown-monitoring
```

クラスタ全体を削除する場合 (Dify を含む全コンポーネントも削除されます):

```bash
make teardown
```

## Dify 環境のセットアップ

[Dify](https://dify.ai/) は LLM アプリケーション開発プラットフォームです。
Helm チャートは [BorisPolonsky/dify-helm](https://github.com/BorisPolonsky/dify-helm) を使用します。

### Dify のインストール

```bash
make setup-dify
```

実行内容:
1. デフォルト名 `local` の kind クラスタを作成 (既に存在する場合はスキップ)
2. `dify` Helm リポジトリを登録・更新
3. `dify/dify` Helm チャートを `dify` Namespace にインストール (`dify-values.yaml` の設定を適用)
4. Pod の起動を待機

### ブラウザからのアクセス

すべてのサービスのポートフォワードを一度に設定するには (`make port-forward` でも可):

```bash
make port-forward-dify
```

| サービス | URL |
|---|---|
| Dify Web UI | http://localhost:8080 |

Dify のみのポートフォワードを停止するには:

```bash
make stop-port-forward-dify
```

### Dify コンポーネントの削除

Dify のみを削除してクラスタを維持する場合:

```bash
make teardown-dify
```

### クラスタ全体の削除

monitoring と Dify をすべて含めてクラスタごと削除する場合:

```bash
make teardown
```

または:

```bash
make teardown-all
```

## 各ツールについて

### kubectl
Kubernetesクラスタを操作するCLIツールです。Kubernetesの様々なリソース（Pod、Service、Deploymentなど）を管理できます。

### kind
「Kubernetes in Docker」の略で、Dockerコンテナの中でKubernetesノードを起動するツールです。ローカル開発環境で簡単にKubernetesクラスタを構築できます。

**注意**: kindを使用するには、Dockerがインストールされている必要があります。

### helm
Kubernetesのパッケージマネージャです。PrometheusやGrafanaなどの複雑なアプリケーションを、helmチャートを使って簡単にインストールできます。

## セキュリティについて

このMakefileは、各ツールの公式ドキュメントで推奨されているインストール方法を使用しています：
- kubectl: Kubernetes公式リリースから直接ダウンロード
- kind: kind公式リポジトリから特定バージョン（v0.20.0）をダウンロード
- helm: Helm公式インストールスクリプトを使用

信頼できるネットワーク環境で実行することをお勧めします。

## トラブルシューティング

### Homebrewがインストールされていない（macOS）

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### sudoコマンドでパスワードが要求される（Linux）

Linuxでは、kubectl、kind、helmを`/usr/local/bin/`にインストールするため、sudoコマンドでパスワードの入力が必要になる場合があります。

### 既にインストールされているツールがある場合

既にインストールされているツールは自動的にスキップされます。再インストールは行われません。

## インストール後の確認

インストールが正常に完了したかを確認するには：

```bash
kubectl version --client
kind version
helm version
```

各コマンドでバージョン情報が表示されれば、インストールは成功です。
