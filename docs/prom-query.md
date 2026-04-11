## よく使うPromQL集

### 【CPU使用率(Pod別)】
```promql
sum(max by (cluster, namespace, pod, container)(node_namespace_pod_container:container_cpu_usage_seconds_total:sum_rate5m{namespace="monitoring"})) by (pod)
```

### 【メモリ使用率(%)】
```promql
sum(max by (cluster, namespace, pod, container)(container_memory_working_set_bytes{job="kubelet", metrics_path="/metrics/cadvisor", namespace="monitoring", container!="", image!=""})) by (pod)
```

chaos-exporter特有のメトリクス

- 'simulated_cpu_usage_percent', 'Simulated CPU usage percentage'
- 'simulated_memory_usage_bytes', 'Simulated Memory usage in bytes'
- 'simulated_disk_io_ops', 'Simulated Disk I/O operations per second'
- 'http_requests_total', 'Total HTTP requests'
- 'simulated_network_transmit_bytes_total', 'Simulated network transmit bytes'
- 'simulated_network_receive_bytes_total', 'Simulated network receive bytes'
