【OceanBase基于LSM Tree架构的存储引擎揭秘以及数据落盘方式详解】https://www.bilibili.com/video/BV1x14y1i7D5?vd_source=787ab3be9e386c9035561f425751b01d

## 架构
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/c7e5161e612b7337542d47c391d7a1b3_MD5.jpeg)
ZONE：集群
OBServer：物理机
## 存储引擎（内存结构）
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/05de7353555f7486dfe869e26e52fab2_MD5.jpeg)
MemStore类似于LSM-Tree中的MemTable；
KVCache缓存SSTable热数据；
内存索引有：BTree、Hashtable；支持高效范围查询以及点查询

## 传统LSM-Tree
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/0a340e7d24b5187ef9c85e771149a323_MD5.jpeg)
OB对LSM的多level SSTable进行优化，只使用C0-C2，减少读放大问题。

## 存储引擎比较
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/986b5ba888fefaca73ab298cba321c3a_MD5.jpeg)

## 查询优化
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/ce23732e5f4a8978fe28918ac310340e_MD5.jpeg)
优化LSM-tree层级结构（只有三层，包括内存、C0+C1增量数据、C2基线数据），引入row cache（缓存数据行）、Bloom Filter Cache；

## OB存储引擎（转储与合并）
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/3efc7657f0389087e456574adfc071df_MD5.jpeg)
为了解决2层LSM Tree merge引发的问题，引入转储。
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/382531812eebb44a1e22f77402e4a84e_MD5.jpeg)
