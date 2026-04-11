よく使うElasticsearchクエリ

### ログレベルエラーのログを検索する

```
GET filebeat-*/_search
{
  "query": {
    "match": {
      "log.level": "ERROR"
    }
  }
}
```