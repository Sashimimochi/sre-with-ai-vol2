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
