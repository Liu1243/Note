事件驱动 的 网络编程并发模型
> 把“**等待 I/O 就绪**”和“**处理 I/O 业务**”分离，用**少量线程**通过**多路复用 + 回调**的方式同时服务**大量连接**，从而解决 BIO 的“一连接一线程”瓶颈。

传统 BIO，每个并发连接都需要独占一个线程
- 上下文切换 和 内存开销 随连接线性增长
- 连接空闲时线程阻塞在 recv/send，cpu 空转
Reactor 借助**操作系统多路复用 API**（select/poll/epoll/kqueue）**在一个线程里监听海量 fd**，**事件就绪后再回调用户代码**完成真正的 I/O 操作，线程不会被阻塞。

## 核心角色与流程
1. Reactor 分发器
运行事件循环，阻塞在多路复用器上；将就绪事件分发给对应处理器。
2. Acceptor 连接接收器
只处理 **accept** 事件，创建新连接并把它注册到 Reactor。
3. handler 业务处理器
执行 **read → 业务计算 → send** 的剩余逻辑；往往由线程池或当前 Reactor 线程执行。

客户端连接/读写 → 内核通知 epoll → Reactor 被唤醒 → 派发 → Handler 处理 → 注册新事件 → 回到循环。

| 模型                  | 线程职责                                            | 适用场景              | 代表框架                  |
| ------------------- | ----------------------------------------------- | ----------------- | --------------------- |
| **单 Reactor 单线程**   | 监听+读写+业务都在一个线程                                  | 连接极少、逻辑极快；教学 demo | Redis 6 之前            |
| **单 Reactor 多线程**   | Reactor 只做监听+读写；业务扔线程池                          | 并发中等，业务耗时         | ——                    |
| **主从 Reactor**（最常用） | Main-Reactor 只 accept；Sub-Reactor 池负责已连接 fd 的读写 | 高并发、充分利用多核        | Netty、Nginx、Memcached |
主从 Reactor 流程：
BossGroup (main-reactor) → accept → 把 channel 注册到 WorkerGroup (sub-reactor 池) → 读写+可选业务线程池。

与 Proactor 的区别：
- **Reactor** 是**同步**的：内核只告诉你“fd 可读/可写”，真正的 `read/write` 还是**用户代码**完成。
    
- **Proactor** 是**异步**的：内核帮你把数据读到用户缓冲区后再通知，**用户回调里直接拿到结果**；需要操作系统真异步 I/O（Windows IOCP、Linux io_uring）。
    

优势：
- 单线程管理十万连接 epoll
- 无阻塞、无上下文切换，CPU 利用率高
劣势
- 单 Reactor 模型下，**业务不能耗时**，否则监听线程被占满
- 纯 CPU 密集任务仍需额外线程池

工业实现：
- **Netty**：主从 Reactor + 无锁队列 + 零拷贝，Java 网络框架事实标准。
- **Nginx**：多进程主从 Reactor，每个 Worker 内再 epoll。
- **Redis**：单 Reactor 单线程处理命令，I/O 多路复用 + 事件分派。
- **Node.js**：V8 + libuv 的单线程事件循环，本质也是 Reactor。
