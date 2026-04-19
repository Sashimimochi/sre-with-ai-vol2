# sre-with-ai-vol2

> **本リポジトリは技術書のサンプルコードです**
>
> 📖 [SRE自動化ハンドブック Vol.2 ～ログ検索からメトリクス、そして自律分析へ～](https://techbookfest.org/product/wYiKyttZ2bKykUqDCSNPXX?productVariantID=eUhXWnBiNbyi5CYq2taQSz)
>
> Prometheus・Grafana・Elasticsearch・Dify を組み合わせ、MCP (Model Context Protocol) を介した AI エージェントによるログ検索・メトリクス分析・自律的なアラートルール管理を実現するローカル Kubernetes 環境を構築します。

---

## 対応環境

- macOS (Homebrew 経由)
- Linux (Ubuntu/Debian 等)
- Windows (WSL2 上の Linux)

---

## 前提条件

### macOS
- Homebrew がインストールされていること
  - 未インストールの場合: `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
- Docker Desktop が起動していること

### Linux / WSL2
- `curl` と `sudo` が使用可能であること
- Docker が起動していること

---

## インストール

### すべてのツールを一括インストール

```bash
make install
```

インストールされるツール:

| ツール | 用途 |
|---|---|
| kubectl | Kubernetes クラスタを操作する CLI |
| kind | Docker 上で Kubernetes クラスタを動かすツール |
| helm | Kubernetes のパッケージマネージャ |

### 個別インストール

```bash
make install-kubectl   # kubectl のみ
make install-kind      # kind のみ
make install-helm      # helm のみ
```

---

## クラスタ設計方針

### ローカル (kind) 環境

すべてのコンポーネントを **単一の kind クラスタ** (`kind-local`) に異なる Namespace で共存させます。

| Namespace | コンポーネント |
|---|---|
| `monitoring` | Prometheus / Grafana / Alertmanager / chaos-exporter |
| `monitoring` | Prometheus MCP サーバー / Grafana MCP サーバー |
| `dify` | Dify |
| `elastic-system` | ECK Operator / Elasticsearch / Kibana / Fluentd / Elasticsearch Exporter / Elasticsearch MCP サーバー |
| `ingress-nginx` | ingress-nginx (MCP Ingress / ngrok 公開用) |

**単一クラスタを採用した理由:**
- ローカルマシンのリソースを節約できる (kind クラスタはそれぞれ Docker コンテナを消費する)
- Prometheus が全 Namespace の Pod メトリクスを同一クラスタ内で直接スクレイプできる
- 単一の kubectl コンテキストで全コンポーネントを操作できる

クラスタ名は `CLUSTER_NAME` 変数で上書き可能です:

```bash
CLUSTER_NAME=my-cluster make setup
```

### クラウド環境での運用 (将来の対応)

| 構成 | 適用場面 |
|---|---|
| 同一クラスタ・別 Namespace | リソース共有を優先する小規模環境 |
| 別クラスタ | セキュリティ分離・独立スケールが必要な本番環境 |

---

## 全コンポーネントの一括構築

monitoring / Dify / MCP サーバー / Elasticsearch をすべて一度に構築します:

```bash
make setup
```

すべてのサービスへのポートフォワードを一度に設定:

```bash
make port-forward
```

| サービス | URL | 備考 |
|---|---|---|
| Prometheus | http://localhost:9090 | |
| Grafana | http://localhost:3000 | デフォルト: admin / prom-operator |
| Alertmanager | http://localhost:9093 | |
| Dify Web UI | http://localhost:8080 | |
| Prometheus MCP | http://localhost:9000/mcp | |
| Grafana MCP | http://localhost:8081/mcp | |
| Elasticsearch | https://localhost:9200 | |
| Kibana | https://localhost:5601 | |
| Elasticsearch MCP | http://localhost:8085/mcp | |

ポートフォワードをすべて停止:

```bash
make stop-port-forward
```

クラスタごとすべて削除:

```bash
make teardown
```

---

## Prometheus 監視環境

### セットアップ

```bash
make setup-monitoring
```

実行内容:
1. kind クラスタを作成 (既存の場合はスキップ)
2. `kube-prometheus-stack` (Prometheus / Grafana / Alertmanager) をインストール
3. `chaos-exporter` をデプロイ (サンプルメトリクス生成用)
4. Slack Webhook Secret を登録 (`.env` ファイルが必要)

### ブラウザからのアクセス

```bash
make port-forward-monitoring
```

| サービス | URL | 備考 |
|---|---|---|
| Prometheus | http://localhost:9090 | |
| Grafana | http://localhost:3000 | デフォルト: admin / prom-operator |
| Alertmanager | http://localhost:9093 | |

```bash
make stop-port-forward-monitoring   # ポートフォワード停止
make get-grafana-password           # Grafana Admin パスワードを確認
```

### Slack 通知の設定

```bash
cp .env.example .env
# .env に SLACK_WEBHOOK_URL を記入してから:
make create-slack-secret
```

### 削除

```bash
make teardown-monitoring   # 監視コンポーネントのみ削除 (クラスタは維持)
```

---

## Dify 環境

[Dify](https://dify.ai/) は LLM アプリケーション開発プラットフォームです。  
Helm チャートは [BorisPolonsky/dify-helm](https://github.com/BorisPolonsky/dify-helm) を使用します。

### セットアップ

```bash
make setup-dify
```

### ブラウザからのアクセス

```bash
make port-forward-dify
```

| サービス | URL |
|---|---|
| Dify Web UI | http://localhost:8080 |

```bash
make stop-port-forward-dify
```

### 削除

```bash
make teardown-dify   # Dify のみ削除 (クラスタは維持)
```

---

## MCP サーバー

Prometheus / Grafana の MCP サーバーをデプロイします。Dify から SSE トランスポート経由で接続し、AI エージェントがメトリクス参照・アラートルール管理を行います。

### セットアップ

事前に `setup-monitoring` と `port-forward-monitoring` が完了している必要があります。

```bash
make setup-mcp
```

実行内容:
1. Grafana Service Account を作成してトークンを発行し、Secret に登録
2. Prometheus MCP サーバーをデプロイ (`monitoring` namespace)
3. Grafana MCP サーバーをデプロイ (`monitoring` namespace)

### ブラウザからのアクセス

```bash
make port-forward-mcp
```

| サービス | URL |
|---|---|
| Prometheus MCP | http://localhost:9000/mcp |
| Grafana MCP | http://localhost:8081/mcp |

```bash
make stop-port-forward-mcp
```

### 削除

```bash
make teardown-mcp   # MCP サーバーのみ削除 (クラスタは維持)
```

---

## Elasticsearch 環境

ECK (Elastic Cloud on Kubernetes) Operator を使って Elasticsearch クラスタを構築します。Fluentd がコンテナログを収集して Elasticsearch へ転送し、Kibana で可視化します。

### セットアップ

```bash
make setup-elasticsearch
```

実行内容:
1. kind クラスタを作成 (既存の場合はスキップ)
2. `ingress-nginx` をインストール (MCP Ingress / ngrok 公開用)
3. ECK Operator をインストール
4. Fluentd をインストール
5. Elasticsearch / Kibana / Elasticsearch MCP サーバーをデプロイ
6. Elasticsearch Exporter をインストール (Prometheus 連携用)

### ブラウザからのアクセス

```bash
make port-forward-elasticsearch
```

| サービス | URL | 備考 |
|---|---|---|
| Elasticsearch | https://localhost:9200 | |
| Kibana | https://localhost:5601 | |

```bash
make port-forward-elasticsearch-mcp   # Elasticsearch MCP (http://localhost:8085/mcp)
make stop-port-forward-elasticsearch
make stop-port-forward-elasticsearch-mcp
```

### パスワード管理

```bash
make get-elasticsearch-password    # Admin パスワードを確認
make healthcheck-elasticsearch     # クラスタヘルスを確認
make setpassword-elasticsearch     # canary 用 Secret にパスワードを登録
```

### 削除

```bash
make teardown-elasticsearch   # Elasticsearch 関連リソースをすべて削除 (クラスタは維持)
```

---

## MCP Ingress / ngrok 公開

ローカルクラスタの MCP サーバーを ngrok 経由で外部公開し、クラウド上の Dify 等から接続できるようにします。nginx Ingress のパスベースルーティングで 3 つの MCP サーバーを単一エンドポイントに集約します。

| パス | 転送先 |
|---|---|
| `/mcp/prometheus` | Prometheus MCP (port 9000) |
| `/mcp/grafana` | Grafana MCP (port 8081) |
| `/mcp/elastic` | Elasticsearch MCP (port 8085) |

### セットアップ

```bash
make setup-ingress
```

### ngrok の起動

```bash
make ngrok
```

起動後に表示される URL を各 MCP クライアントの接続先として設定してください:

```
https://<ngrok-url>/mcp/prometheus/mcp
https://<ngrok-url>/mcp/grafana/mcp
https://<ngrok-url>/mcp/elastic/mcp
```

### 削除

```bash
make teardown-ingress
```

---

## コマンドリファレンス

すべてのコマンドを確認するには:

```bash
make help
# または
make
```

### 主要ターゲット一覧

| カテゴリ | ターゲット | 内容 |
|---|---|---|
| 汎用 | `make setup` | 全コンポーネントを一括構築 |
| 汎用 | `make port-forward` | 全サービスへポートフォワード |
| 汎用 | `make stop-port-forward` | 全ポートフォワードを停止 |
| 汎用 | `make teardown` | 全ポートフォワード停止 + クラスタ削除 |
| 監視 | `make setup-monitoring` | Prometheus / Grafana / Alertmanager をインストール |
| 監視 | `make teardown-monitoring` | 監視コンポーネントを削除 |
| Dify | `make setup-dify` | Dify をインストール |
| Dify | `make teardown-dify` | Dify を削除 |
| MCP | `make setup-mcp` | Prometheus / Grafana MCP サーバーをデプロイ |
| MCP | `make teardown-mcp` | MCP サーバーを削除 |
| ES | `make setup-elasticsearch` | Elasticsearch 環境を構築 |
| ES | `make teardown-elasticsearch` | Elasticsearch 環境を削除 |
| Ingress | `make setup-ingress` | MCP Ingress をデプロイ |
| Ingress | `make ngrok` | ngrok でポート 80 を公開 |

---

## トラブルシューティング

### Homebrew がインストールされていない (macOS)

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

### sudo でパスワードが要求される (Linux)

kubectl / kind / helm を `/usr/local/bin/` にインストールするため、パスワード入力が必要になる場合があります。

### 既にインストールされているツールがある場合

各インストールターゲットは冪等に動作します。既にインストール済みのツールは自動的にスキップされます。

### クラスタ作成に失敗する

Docker が起動していることを確認してください。

```bash
docker info
```

### Elasticsearch の起動に時間がかかる

`setup-elasticsearch` は Elasticsearch Pod の起動を最大 40 分待機します。ローカルマシンのスペックによっては時間がかかります。起動状況は別ターミナルで確認できます:

```bash
kubectl get pods -n elastic-system -w
```

---

## インストール後の確認

```bash
kubectl version --client
kind version
helm version
```

各コマンドでバージョン情報が表示されれば、インストールは成功です。

---

## セキュリティについて

本リポジトリは **ローカル開発・学習用途** を想定しています。各ツールは公式ドキュメントで推奨されているインストール方法を使用しています。信頼できるネットワーク環境で実行してください。
