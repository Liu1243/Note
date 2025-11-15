## Lesson01 SkipList
[Lesson 01 SkipList - 飞书云文档](https://hardcore.feishu.cn/wiki/VfAbwCvmyiVD5IktOU3crBT8nsc)

## Lesson02 Bloom Filter
### 推导
给定位数组大小m、数据量n，得出Hash函数个数k：
k=0.69\*m/n
一般来说数据量n是固定的，给定假阳性概率p，选择最优位数组大小m：
m=-(n\*lnp)/(ln2)\^2
### 实现
- 使用murmurhash算法
- bit存储，更省空间

## Lesson03 Arena
### 为什么需要内存管理
在CoreKV的应用场景下，处理的是天量的KV键值对的插入和删除。在插入Kev和Value的时候，不可避免的要在系统中审请内存。操作系统分配内存需要借助系统调用，并且陷入到内核态，这需要带来额外的上下文切换耗时，尤其是在频繁的插入操作中，少量的内存申请需要大量的切换开销，这样的操作带来的性能影响很大。Go语言为了解决这个问题，使用了tcmalloc的思想来进行内存分配。理论上来说 Golang已经帮助我们解决了内存分配的问题，为什么CorekV还要自己实现一个内存管理器呢。
Golang的内存分配是不区分业务逻辑的，只要程序有需要申请内存，Golang都会满足，这也就造成了Memtable的内存可能和CorekKV代码中的其他变量使用连续的内存空间。在Memtable这种需要频繁甲请内存的地方，如果混杂看其他的审请请求，很可能导致内存碎片的产生，从而影响分配的效率和空间的利用率。
![](KV%E5%AD%98%E5%82%A8/attachments/89f2c12463811904fc02ed291e5f3d2c_MD5.jpeg)
总结两个原因：
频紧申请、释放需要时间成本
频繁申请、释放容易产生内存碎片
==解决思路==：
内存分配经常采用的一种方式，就是首先使用预分配一块比较大的内存，需要使用小块内存时，从这块天内存里面继续分配，这脏候分配可能只是移动指针或者更新变量，非常高效。
CoreKV内存管理就使用了这种思想，解决了小块内存频繁调用的开销和内存碎片的问题，但是却可能浪费一些内存。
==具体操作==：
我们的Arena只提供分配空间的操作，不提供释放空间的操作。这是因为在CoreK的应用场景中，所有的操作都被当做在Arena内存池中的追加操作，当Arena在内存中占用的空间超过一定值以后，CorekV会将整个memtable转变为immutable，随后会持久化成sst文件。此时、整个Arena内存空间可以被释放。所以，Arena内存空间的释放不需要自已完成，借助Golang语言的内存回收机制即可。
### 代码实现
func (s \*Arena) allocate(sz uint32) uint32
s.buf是Arena所持有的内存空间，sz是需要分配的大小，返回申请后的buf头地址。
细节是buf尾部需要留出MaxNodeSize的空间大小，绕过go checkptr检查。
如果申请sz后，buf可用大小小于MaxNodeSize，需要进行扩容，扩容大小为buf大小的2倍，最大为1G，最小为sz。扩容后将数据从旧buf copy到新buf。
### 接口封装
func (s \*Arena) putNode(height int) uint32
我们发现Sizeof整个节点，是按照这个node的最高Level都被使用来计算的，但是在实际结果中，这个 node不一定需要记录到整个SkipList最高的高度，所以我们来考虑计算一下当前节点实际高度下所占用的内存大小。

func (s \*Arena) putVal(v ValueStruct) uint32
在PutVal方法中要实现说明一下，因为value中的值不仅仅包含val值，如果用作缓存，可能还存在过期时间的概念。我们刚才说过内存优化，自的是尽量减少分配的次数，如果将va中的值每次都单独分配内存，并且记录offset和size也不是不行，但是这样就会浪费分配次数和SkipList节点的内存占用。找们门者虑能不能将va中的值整体编码，在读取的时候按照固定的编码格式进行还原即可。
因此我们改动一下之前SkipList的Val结构，不再是val \[]byte，而是使用一个新的struct
![](KV%E5%AD%98%E5%82%A8/attachments/466d02144d2393b5ffe1224cc9bb6539_MD5.jpeg)
现在经过我们的一顿操作，现在我们如果插入两个键值对，在内存中和跳表中的视图就会如上图所示。
能不能优化？如果我们要对Element做Val的==更新操作==，要将Element锁住，因为要更新ValOffset和ValSize两个变量，因为CoreKV不像LevelDB不支持内存中的原地更新操作。这样一来的话，如果天量的更新操作会导致锁冲突剧烈，一般情况下，我们会考虑无锁的实现。那么两人变量实现无锁不太简单能不能合并成一个变量呢？
ValOffet的数据类型是uint32，ValSize最天也就是uint32，那理论上用一个uint64就可以表示。我们将 valsize左移32位，然后做个拼接即可
==val size+val offset合并为一个64位val数组，各32位，实现无锁更新==

func (s \*Arena) putKey(key \[]byte) uint32

这样我们就把一个基本完善的CoreKV内存管理模块完成了，并且考虑了很多细节。但是，我们的SkipList就要大改动了，I因为开始的Element中保存的是实际的KV值，但是接下来Element中保存的是 Arena中的offset。
我们的SkipList当中也必须要持有一个Arena，类似这样
```go
type SkipList struct {
	maxLevel int
	lock sync.RWMutex
	currentHeight int32
	headOffset uint32
	arena *Arena
}
```
![](KV%E5%AD%98%E5%82%A8/attachments/68638c37c87f0212d34015275ae70753_MD5.jpeg)也就是说Element从上面的变成了下面的。

## Lesson04 Cache
### 缓存在CoreKV中的应用
- 一打开的sstable文件对象和对应元数据
- sstable中的dataBlock的内容
### LRU LFU
LRU是最近最少使用，没有办法按照访问频率来淘汰。
LFU则是根据访问频率来决定。
- LRU
优点：实现简单，可以很快的适应访问模式的改变
缺点：对于热点数据的命中率可能不如LFU
- LFU
优点：对于热点数据命中率更高
缺点：难以应对突发的稀疏流量，可能存在日数据长期不被淘汰，会影响某些场景下的命中率（如外卖），需要额外消耗来记录和更新访问频率
### TinyLFU算法简介
TinyLFU解决了上面所提到的几个问题：
a.LFU需要额外大量的空间存储统计信息 （Count-Min Sketch 位图解决）
b.LFU存在旧数据长期不被淘汰的问题（过一段时间访问频率减半）
但是仍然没有解决LFU难以应对突发的稀疏流量的问题，引入W-TinyLFU
**W-TinyLFU窗口设计**
主缓存（maincache）便用SLRu遂出策略和TinvLFU接纳策略，而窗口缓存（windowcache）采用 LRU逐出策略而没有任何接纳策略。
主缓存根据SLRU策略静态划分为A1和A2两个区域，80%的空间分配给热门项目（A2）：并从20% 的非热门项目（A1）中挑选victim。所有请求的key都会被充许进入窗口缓存，而窗口缓存的victim则有机会被允许进人主缓存。如果被接受，则W-TinyLFU的victim是主缓存的victim，否则是窗口缓存的 victim。
窗口缓存的大小初始为总缓存大小的1%，主缓存的大小为99%。
### 具体实现
整体架构
![](KV%E5%AD%98%E5%82%A8/attachments/2fdbefbf1825a807d735d1ace2d33351_MD5.jpeg)
#### Count-Min Sketch算法
刚才提到了LFU需要统计每个条数据的访问频率，这就需要一个或者O门9类型来存储次数，但是子细一想，一条缓存数据的访问次数真的需要类型这么大的表示范围来统计吗？我们认为一个缓存被访问15次已经算是很高的频率了，那么我们门只用4个Bit就可以保存这个数据。（24=16）
再来绍一个cmsketch算法，看过硬核课堂BoomEiter视频的都知道，BloomEiter利用位图的思想来标记一条数据是否存在，存在与否可以用某个Bit位的01来代替，那么我们能不能扩展一下，利用这种思想来计数呢?
我们给要计数的值计算一个Hash，然后在位图中给这个Hash值对应的位置累加1就可以了，但是 Boomier中的一典型问题是假阳性，可以说只要是用Hash计算就有存在冲案的可能，那么cmsketch计数法如果出现冲突会怎么样呢？会给同一个位置多计算访问次数。这里cmSketch选择了以最小的统计数据值作为结果。这是一个不那么精确地统计方法，但是可以大致的反应访问分布的规律。因为这个算法也就有了一个名字，叫做count-Min sketch。
#### BloomFilter
给BloomFilter新增Allow方法，当key存在BloomFilter，返回True；不存在插入到BloomFilter中。
#### TinyLFU缓存策略实现
![](KV%E5%AD%98%E5%82%A8/attachments/b94e042d2e857e715cf720da4045b31d_MD5.jpeg)
首先所有的数据都会先进人window-ru，这里面会缓存近期访同的数据，对于突发的稀疏流量，应对效果上比较好，但是window-lrU的准入第略是所有数据都可以放进来，但是这样LRU很快就会满，所以必须涉及到淘汰策略。淘汰策略很简单，每次被淘汰的数据必定是链表未尾的那个。但是淘汰到哪里去是个问题我们先不考虑这个问题，先来实现一个简单的LRU。

segment-lru是将缓存区分为两个部分，一个占据2o%叫做Probation（缓刑），一个占据80%(Protected）。当数据需要进入Segment-Lru的时候，都会先进入Probation区，当数据在Probation 区再次被访问时，会进入到Protected区。如果Protected区中的数据已满，将会淘汰最后一个数据。

我们已经解决了window-iru和siru的逻辑实现，那么如何把两个区域之间的逻辑结合起来呢？ Get的逻辑不会涉及window-Iru和segmented-Iru缓存之间的数据流动，我们只看Set逻辑。
当Set一个数据的时候，首先进入window-Iru，如果LRU没满，直接add就好。如果满了，需要淘汰注意淘汰之后的数据，是不会直接丢掉的，要加入到siru中。如果siru没满，就加入到stageone，如果满了，就从stageone淘汰（因为必须放到stageone）。
但是这个时候有个问题，如果从stageone淘汰的数据被访问的频次比较高，从window-lru中的数据访问频次比较低，怎么办？别忘了我们有cmSketch计数器，可以统计下过去的访问频率，做下比较，就能决定抛弃个了。

还有一人细节问题，如果大量的数据都只访问一次，那么每次从WLRU中淘汰的数据，会频紧的被淘汰出来，那么每一次都要跟sIru中的做对比，能不能不做这个操作呢？我们希望加个过滤，这些只出现一次的数据，进行拦截。
对一个数据是否出现过做统计，最合适的数据结构是布隆过滤器

经过上面的设计，我们可以发现解决了Iru和Ifu的问题。
但是我们注意一点，ifu是把频次高的放在前面，但是invfu的sru还是个ru，没有根据频次排序，这会带来什么问题呢？频次高的可能在Iru未尾，被淘汰。这不就违背了Ifu的原则了吗？我们思考一下，如果一个高频词数据在siru被淘汰出去，在跟window-Iru进行pk的时候，多半是会保留下来的。如果不幸被淘汰了，如果后面没有访问，那他的淘汰是应该的，如果后面又被访问到，由于他的计数信息还存在，所以极大概率会被重新添加到缓存中。

我们来总结一下，经过如上的逻辑，对于所有类型的数据，缓存会是什么样的表现形式。
1.针对只访问一次的数据，在LRU中很快就被淘汰了，不占用缓存空间。
2.针对突发性的稀疏流量，就是可能在短时间内频紧访问的数据，WindoWs-LRU可以很好的适应这种访问模型
3.针对真正的热点数据，很快就会从Window-IRU进入到Protected区中，并且会经过保鲜机制存活下来。