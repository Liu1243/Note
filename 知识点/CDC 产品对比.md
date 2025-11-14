![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/f9d73f9562453d36ff4d8591701b4f8f_MD5.jpeg)
canal 已经废弃，并且不支持全量同步，建议使用 Flink CDC

基于查询的 CDC 常用于离线全量同步；
基于日志的 CDC 则常用于在线实时的增量同步。

Flink CDC 集成了 Debezium 作为捕获数据更改的引擎，与 Debezium 不同的是，Flink CDC 不强依赖 Kafka。