[微信公众平台](https://mp.weixin.qq.com/s/sd6ePRJMxH0RO8AzXoV9yA)
## 线程池优势
降低资源消耗：池化技术降低线程创建销毁损耗
提高响应速度：无需等待线程创建
提高线程可管理性
提供更多强大的功能：例如延迟定时线程池ScheduledThreadPoolExecutor

## 线程池使用
### ThreadPoolExecutor（推荐）
核心参数：
- corePoolSize：核心线程数；线程池初始化默认没有线程，有任务了才开始创建线程
- maximumPoolSize：最大线程数；核心线程以及队列已满时，如果 corePoolSize \< maximumPoolSize 时，创建非核心线程
- keepAliveTime：非核心线程空闲时间超过则自动终止回收，不回收核心线程
- unit：时间单位
- workQueue：保存线程任务的队列；分为无界、有界、同步移交，工作线程大于 corePoolSize，会将新来的任务放入队列。
	- ArrayBlockingQueue：有界队列，队列满创建非核心线程执行任务，达到最大后执行拒绝策略
	- LinkedBlockingQueue：无界队列，任务处理速度跟不上任务创建速度，会导致 OOM
	- SynchronousQueue：同步队列，队列长度为 0
- threadFactory：创建线程的工厂接口
- handler：拒绝策略
	- AbortPolicy：默认；中断抛出异常
	- CallerRunsPolicy：提交任务的主线程执行任务
	- DiscardOldestPolicy：丢弃队列头任务，重复执行
	- DiscardPolicy：丢弃任务，不通知

### Executors（不推荐）
![](%E7%9F%A5%E8%AF%86%E7%82%B9/attachments/97d83b9b47a4066ed7caabdcbeb0a49a_MD5.jpeg)
Executors 弊端：
- FixedThreadPool 和 SingleThreadPool 请求队列长度为 Integer.MAX_VALUE，可能堆积大量请求，导致 OOM
- CacheThreadPool 和 ScheduledThreadPool：允许创建线程数量为Integer.MAX_VALUE，可能创建大量线程，OOM

### 提交任务
无返回值的任务使用 public void execute(Runnable command) 方法提交；
有返回值的任务使用：
- Future submit(Runnable task) ：  提交Runnable任务    
- Future submit(Runnable task, T result)： 提交Runnable任务并指定执行结果
- Future submit(Callable task) ： 提交Callable 任务

Runnable 和 Callable 的区别：

| 维度          | Runnable                                  | Callable                                     |
| ----------- | ----------------------------------------- | -------------------------------------------- |
| **所在包**     | java.lang（老牌，JDK1.0）                      | java.util.concurrent（JUC，JDK5）               |
| **方法签名**    | `void run()`                              | `V call() throws Exception`                  |
| **有无返回值**   | ❌ 无                                       | ✅ 有（泛型 V）                                    |
| **能否抛受检异常** | ❌ 只能内部 catch                              | ✅ 直接 `throws Exception`                      |
| **提交方式**    | `execute(Runnable)`<br>`submit(Runnable)` | 只能 `submit(Callable)` 或 `invokeAll/Any(...)` |
| **拿到结果**    | 无法直接拿（得自己塞变量、锁）                           | `Future<V>`、`get()` 阻塞拿结果                    |
| **使用场景**    | 日志、异步写文件、无返回的耗时任务                         | 并行计算、RPC、需要返回结果或抛异常                          |
Runnable 没有返回值、Callable 有返回值。

### 批量执行任务
invokeAll、invokeAny

### 执行定时、延时任务
schedule方法

### 执行周期、重复性任务
scheduleAtFixedRate、scheduleWithFixedDelay

### 关闭线程池
shutdown 和 shutdownNow 的区别：
shutdown 延迟关闭线程池，等待任务队列中任务结束，线程池状态为 SHUTDOWN；shutdownNow 立即关闭线程池，返回任务队列中任务，线程池状态为 STOP。

## 线程池参数设计分析
corePoolSize：
根据任务处理时间和每秒产生的任务数量，以及二八原则。
80% 时间每秒产生 100 个任务，一个线程处理需要 0.1 s，那么 1s 内处理完 100 个任务，需要 10 个线程。
workQueue：
corePoolSize / 单个任务执行时间 \*2
corePoolSize=10，单个任务执行时间 0.1s，队列长度为 200
maximumPoolSize：
参照 corePoolSize 以及系统每秒产生的最大任务数。
系统每秒产生最大任务是 1000 个，最大线程数=（最大任务数-任务队列长度）\* 单个任务执行时间=（1000-200）\*0.1 = 80 个
keepAliveTime：
参考运行环境和硬件压力。