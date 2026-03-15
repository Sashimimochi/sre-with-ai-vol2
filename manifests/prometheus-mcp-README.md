# Prometheus MCP Server マニフェスト

このディレクトリには、Kubernetes上でPrometheus用のMCPサーバーを構築するためのマニフェストファイルが含まれています。

## 概要

[prometheus-mcp-server](https://github.com/pab1it0/prometheus-mcp-server)は、PrometheusをMCP (Model Context Protocol)サーバーとして公開するためのサーバーです。これにより、AIエージェントがPrometheusからメトリクスを取得できるようになります。

## ファイル構成

- `prometheus-mcp-namespace.yaml`: mcp-servers namespaceの定義
- `prometheus-mcp-deployment.yaml`: prometheus-mcpサーバーのDeploymentリソース定義
- `prometheus-mcp-service.yaml`: prometheus-mcpサーバーのServiceリソース定義

## デプロイ方法

### 前提条件

- Kubernetesクラスターが利用可能であること
- `kubectl`コマンドが設定済みであること
- Prometheusが`monitoring` namespaceの`prometheus-server`という名前でデプロイされていること

### デプロイ手順

すべてのPrometheus MCPマニフェストを適用する場合:

```bash
kubectl apply -f manifests/prometheus-mcp-namespace.yaml
kubectl apply -f manifests/prometheus-mcp-deployment.yaml
kubectl apply -f manifests/prometheus-mcp-service.yaml
```

または、まとめて適用:

```bash
kubectl apply -f manifests/prometheus-mcp-*.yaml
```

### デプロイの確認

```bash
# Podの状態を確認
kubectl get pods -n mcp-servers

# Serviceの状態を確認
kubectl get svc -n mcp-servers

# Deploymentの状態を確認
kubectl get deployment -n mcp-servers
```

## 設定のカスタマイズ

### Prometheus URLの変更

Prometheus URLを変更する場合は、`prometheus-mcp-deployment.yaml`の以下の部分を編集してください:

```yaml
env:
- name: PROMETHEUS_URL
  value: "http://prometheus-server.monitoring.svc.cluster.local:9090"
```

### 認証情報の追加

Prometheusに認証が必要な場合は、以下の環境変数を追加してください:

```yaml
env:
- name: PROMETHEUS_USERNAME
  value: "your-username"
- name: PROMETHEUS_PASSWORD
  valueFrom:
    secretKeyRef:
      name: prometheus-credentials
      key: password
```

または、トークン認証の場合:

```yaml
env:
- name: PROMETHEUS_TOKEN
  valueFrom:
    secretKeyRef:
      name: prometheus-credentials
      key: token
```

### リソース制限の調整

環境に応じて、`prometheus-mcp-deployment.yaml`のresourcesセクションを調整してください:

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

## トラブルシューティング

### Podが起動しない場合

```bash
# Podのログを確認
kubectl logs -n mcp-servers -l app=prometheus-mcp

# Podの詳細情報を確認
kubectl describe pod -n mcp-servers -l app=prometheus-mcp
```

### Prometheusへの接続に失敗する場合

1. Prometheus URLが正しいことを確認
2. Prometheusが実際に稼働していることを確認
3. ネットワークポリシーが適切に設定されていることを確認

## 環境変数リファレンス

| 環境変数 | 説明 | デフォルト値 | 必須 |
|---------|------|------------|------|
| `PROMETHEUS_URL` | PrometheusサーバーのURL | なし | Yes |
| `PROMETHEUS_MCP_SERVER_TRANSPORT` | トランスポートモード (stdio/http/sse) | http | No |
| `PROMETHEUS_MCP_BIND_HOST` | HTTPトランスポート時のバインドホスト | 0.0.0.0 | No |
| `PROMETHEUS_MCP_BIND_PORT` | HTTPトランスポート時のポート | 8080 | No |
| `PROMETHEUS_USERNAME` | Basic認証のユーザー名 | なし | No |
| `PROMETHEUS_PASSWORD` | Basic認証のパスワード | なし | No |
| `PROMETHEUS_TOKEN` | Bearer認証のトークン | なし | No |
| `PROMETHEUS_URL_SSL_VERIFY` | SSL検証の有効/無効 | True | No |

## 参考資料

- [prometheus-mcp-server GitHub Repository](https://github.com/pab1it0/prometheus-mcp-server)
- [Model Context Protocol](https://modelcontextprotocol.io/)
