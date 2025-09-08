大数据的核心理念：
1. 能够伸缩到一千台服务器以上的分布式数据处理集群的技术
2. 上千个结点的集群，采用廉价的PC架构搭建起来的
3. 把数据中心当作是一台计算机 Datacenter as a Computer

![图片](BigData/%E5%A4%A7%E6%95%B0%E6%8D%AE%E7%BB%8F%E5%85%B8%E8%AE%BA%E6%96%87%E8%A7%A3%E8%AF%BB/attachments/b9a12ce80f10576e185ce1c0c1793db5_MD5.webp)
两个基础设施：
1. 保障数据一致性的分布式锁。实现了Paxos算法的Chubby锁服务。
2. 数据怎么序列化以及分布式系统之间的通信。Facebook在2007年发表的Thrift。

OLAT和OLTP数据库
![](BigData/%E5%A4%A7%E6%95%B0%E6%8D%AE%E7%BB%8F%E5%85%B8%E8%AE%BA%E6%96%87%E8%A7%A3%E8%AF%BB/attachments/400167eab7033e0ff7aa2d220b86c0e4_MD5.webp)
MapReduce的迭代进行，是不断优化OLAP类型的数据处理性能；Bigtable对应的进化，是在保障伸缩性的前提下，获得了更多的关系型数据库的能力。

实时数据处理的抽象进化：
![图片](BigData/%E5%A4%A7%E6%95%B0%E6%8D%AE%E7%BB%8F%E5%85%B8%E8%AE%BA%E6%96%87%E8%A7%A3%E8%AF%BB/attachments/b504f50d18c8e7b6e2a14297e875108e_MD5.webp)
![](BigData/%E5%A4%A7%E6%95%B0%E6%8D%AE%E7%BB%8F%E5%85%B8%E8%AE%BA%E6%96%87%E8%A7%A3%E8%AF%BB/attachments/460c6501ee7e224bf34229ba54f84791_MD5.webp)

将所有服务器放在一起的资源调度：
解决一致性，有基于Paxos协议的分布式锁，因为性能差，有了进一步的Multi-Paxos协议。
Paxos不易理解，有了Raft，K8S依赖的etcd就是Raft协议实现的。
物理机-》虚拟机——》容器



