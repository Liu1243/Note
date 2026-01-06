## Lesson01 SkipList
[Lesson 01 SkipList - 飞书云文档](https://hardcore.feishu.cn/wiki/VfAbwCvmyiVD5IktOU3crBT8nsc)
1.更高效的randLevel算法？
redis采用p=1/4的概率随机层高，平衡查询性能（跳跃步长）和内存开销（指针数量）。
预计算查询表、结合Arena紧凑存储
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

func (s \*Arena) putKey(key \[]byte) uint33

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

## Lesson05 SSTable
### 先导知识
LevelDB源码解读
策略模式、迭代器模式
### 介绍
SSt文件是LSM用来存储持久化kV的文件，其设计充分考虑了持久化I读写性能，存储空间三者的权衡，可以学习到当今主流NoSg数据库文件存储格式的设计思想与方法，并且理解一个计算机领域重要应用之一：kV数据结构是如何存储在磁盘上的？更加宽泛的说可以学习到：内存数据结构是如何序列化到磁盘的?
### 接口设计
![](KV%E5%AD%98%E5%82%A8/attachments/506ea1289b75ba24c9fa211d0a1dbd47_MD5.jpeg)
==创建==
当向kv引擎Put数据时，会检查当前内存表是否达到指定的國值，如果达到值即会触发Flush行为，该行为最终会将整个skipList的数据序列化到磁盘上的sst文件上。因此需要一个open函数，打开一人sst文件，并且需要把数据序列化，然后把序列化的数据写入sst文件中。 
func openTable(opt，tableName，skipList)->table
又因为，序列化的过程是相对复杂的，为了合理的组织代码，并且可预测未来SS的存储格式会经常变化，这里传入一个buidler对象来处理将跳表的数据序列化为sst格式逻辑（策略模式)，代替直接传递 skipList对象。
func openTable(opt，tableName，builder)->table
==初始化==
如果kv引擎不是第一次启动，他将在指定的工作目录下去加载所有后缀为.sst的文件，然后逐一初始化，恢复索引等结构用于检索。
其接口可以还是openTable，只要使得builder为空，在打开tableName存在的情况下就进行初始化 func openTable(opt，tableName，nil)->table
==检索==
sst文件需要识别key的版本大小，因为有可能存在指定版本的点查/范围查询。
func Serach(key,maxs）->kv
司时需要支持繁项的范围查询，指定版本，前缀，升序，降序等范围查询，并且涉及在内存，磁盘等多种数据结构上的统一查询，所以需要使用选代器模式封装。
==序列化==
在flush跳表到磁盘成为sst时，需要序列化数据为二进制格式，并适用于存储在磁盘上。
### 原理详解
![](KV%E5%AD%98%E5%82%A8/attachments/b724e8a6157c954ab0eaf26221bd1826_MD5.jpeg)
#### 编码思想
编码的本质是遵守约定的映射，并具总在编解码的性能与存储空间之间作出权衡。通常需要写入三种要素，==类型==，用于标示一段数据用什么解码器还原来解释二进制的数据，==长度==，用于标示当前数据段占用的大小，以便于在二进制序列上移动指针读取数据，以及==数据==本身。
进一步，为了提高查询性能，通常在编码协议中会写入数据的索引，将数据的索引也作为一种数据存储在编码的二进制序列中。
同时，为了更加复杂的描述一段数据的类型，例如这段数据是否被压缩，是由哪个事务被写入，以及时间戳，是否删除等标记等等，单一的类型数据无法完全描述，因此引入了元数据段代替之前类型这一个枚举值来描述数据段。
![](KV%E5%AD%98%E5%82%A8/attachments/d6b3f2ce7f3c675422fd4251055a8570_MD5.jpeg)
读取数据时，编解码器应该设计成递归的形式，每种数据段有自己的解码规则，根据元数据段掌到的类型确定当前读取数据的解码器类型，通过长度确定其指针偏移范围读取数据，对这段数据进行解码，而这一过程往往是递归进行的。
#### 内存映射
mmap是linux提供的一种高效的内存与磁盘之间的数据传输方式。能够实现，磁盘文件和进程虚拟内存空间之间的相互同步，因此也就基于磁盘文件实现了进程之间的内存共享，他通过减少磁盘到页续再到用户进程空间的两次拷贝提高了整体的卷旺性能。
mmap需要将进程虚拟地址空间的一段内存关联到某个磁盘文件上，在进程的地址空间中会维护内存地址与磁盘物理地址的映射。在进程访问这片内存地址时，如果没有查询到磁盘物理地址则会引发缺页中断，中断逻辑会去拷贝磁盘中相应的文件到用户空间。
一旦进程的内存地址空间被更新，在一段时间后，更新的数据会同步回磁盘文件上，完成异步的更新。
a.延迟拷贝数据到进程虚拟地址空间，比普通的IO减少了同步文件系统页缓存的步骤，效率高
b.异步落盘有增加数据失的风险？->sst文件是仅追加的，因此当一个sst文件生成后，就不会有更新操作，不会频繁更新，数据脏页的情况就不存在，那么mmap将是高效的（可在flush的时候手动调用司步函数，保证数据落盘
#### 基本格式
![](KV%E5%AD%98%E5%82%A8/attachments/d0a06fa7df02acc2a2fce1d03f90554b_MD5.jpeg)
#### ==创建/初始化==
时机：manifest中加载，落盘memtable
func openTable(opt, tableName, builder) -> table
![](KV%E5%AD%98%E5%82%A8/attachments/cbb999c17bddc4a24a91ec7cf313c49e_MD5.jpeg)
1.构建参数上下文，创建sstable对象（创建mmap文件，并关联一块内存区域）
2.判断builder对象是否存在，如果存在则将执行builder的flush动作序列化数据到sst 
3.初始化sst文件（初始化table对象，索引，元数据等）
	a.读取尾部4字节获得checksum长度 
	b.根据长度读取checksum值
	c.读取4字节读取index_len的长度 
	d.根据长度读取index_data
	e.然后计算校验和与checksum对比 
	f.pb反序列化data为tablelndex对象
#### ==序列化==
时机：L0层flush，合并压缩
##### add builder
![](KV%E5%AD%98%E5%82%A8/attachments/dbec8f8d74f33dcb2b85e68aecf9ce74_MD5.jpeg)
1.检查 添加这个entry对象是否超出了当前block的最大size
2.如果超出最大size则序列化当前block
	a，序列化entry_offsets(uint32的数组） 
	b.序列化entry_offsets的长度
	c.计算当前block的checksum值 
	d.序列化checksum(uint32值） 
	e.序列化checksum的长度
	f.将当前的block加入整体sst的blocklist 
	g.计算整个sst的keycount数量
3.计算当前block的hashkey列表，用来之后生成bloom过滤器 
4.计算当前block的最大版本号信息
5.计算diffkey，用来压缩存储空间，拿block的第一个key作为basekey 
6.计算header对象
	a.overlap =len(key)-len(diffKey)
	b.diff =len(diffKey)
7.记录当前block的endoffset.存储在一个list中，本质上就是当前entry写入后的startoffset 
8.写入builder的底层字节数组，先写header，再写diffkey
9.计算当前entry值占用的空间大小，向builder申请足够的空间
10.将序列化的entry写入，可变长编码的过期时间，value的字节数组

##### builder flush() -> bytes
![](KV%E5%AD%98%E5%82%A8/attachments/437e69f072f692826eca964f9a3784e5_MD5.jpeg)
1.将当前没有序列化的block序列化
2.构建bloomfilter->源码地址 
3.构建tableindex
	a.遍历biocklist生生blockoffset对象
		i.根据每个block的end计算startoffset +=cur，end 
		ii.获得block的长度
		iii.获得block的baseKey
	b.获得最大版本与keyCount值
	c获得传递下来的bloomfilter的bytes 
	d.使用pb序列化整个tablerindex对象
4.计算tableindex的checksum 
5.计算整体的sst文件大小
6，创建一个足够大小的buf字节数组
7遍历blocklist逐一copv数据到目标but
8.Copypb序列化后的索引，及长度 
9.Copychecksum和checksum长度

#### 检索
func Search(key, maxVs) -> kv
![](KV%E5%AD%98%E5%82%A8/attachments/c891746e0d4ca2a88689c97aa36d26b2_MD5.jpeg)
1.获取当前table的索引 
2.重新回溯bloomfilter
3．判断当前key是否在该table中，不在则直接返回 
4.创建当前table的迭代器
5.Seek当前key，看是否返回了对象iter，如果没有则返回
	a.根据blockoffset做二分查找，返回一个idx
		i．去除时间戳去比较
		ii.如果相等，则比较时间戳
	b.如果idx\==0说明key只能在第一个block中block\[0].MinKey<=key 
	c.否则block\[idx].MinKey>key
	d.因此block_offset\[idx-1]<=key
	e.如果在idx-1的block中未找到key那才可能在idx中 
	f.根据计算的idx去加载对应的block，并构建block的迭代器
		i.从blockcache中拿到block 
		ii．如果没有拿到则从文件中加载
			1.根据blockoffset中offset对象的offset和len从sst中读取字节数组
			2.按写入顺序相反的方向读取读取数据，反序列化为block对象 3．全部读取后检查block的checksum是否一致
	g.在block上seekkey
		i.二分法检索key返回一个idx
		ii.然后从block的offsets中找到start_offset 
		iii.读取当前block的第一个key的header对象
		iv.根据第一个key的header对象反序列化为baseKey 
		V.读取idx+1的entry_offsets作为end_offset值
		vi.通过start_offset与end_offset从block的data数组中获取entry的data部分 vi.解码data的header部分
		vii.计算baseKey和diffKey拼接出最终的key
		ix.去除header和key后读取data的后面部分，反序列化为value部分
			1.先解码过期时间，用变长编码反解析 
			2.在直接返回value部分(字节数组）
	h.返回block送代器最终持有的item
6.排除版本号的比较iter的key和当前key是否相等，不相等直接返回
7.解析出当前key的时间截，比较是否比maxVS大，大的话需要更新maxVs 
8.返回代器iter持有的entry

#### 总结
![](KV%E5%AD%98%E5%82%A8/attachments/c0c88eba3c43d84e7dff3fe55c69db15_MD5.jpeg)

### LAB 实现sst文件(lab_sst分支)
1.功能：初始化，序列化，查询
在一个生产上下文中完成LAB，从整体系统的角度理解SSt组件的应用场景。 
2. 提高
空间压缩，在sst序列化每个block时，对block使用高效的压缩算法，节省内存空间
为工作自录上支件锁，件锁可保证多个进程不会同时操作一个自录
manifest加载sst后就会加载所有sst的index部分，以便用于对大规模数据的存储

## Lesson06 MANIFEST
### 需求背景
Manifest文件是一个用于存储sst所属层级关系的元数据文件，当数据库重启时，需要读取该文件用于恢复层级关系的元信息。其次每次flush或者merge了sst文件后都需要变更Manifest文件。
> 1能够存储sst文件层级元信息 
> 2.支持高性能的update操作

如果没有manifest文件行不行？
> 把level信息写入sst文件本身，每次初始化的时候直接扫描工作目录下全部sst文件，来恢复层级元信息不行吗？

数据库的恢复速度也是一个重要的优化指标。
### 组件设计
#### 一般解
> 能够存储sst文件层级元信息
> sst文件属于哪个level以及用于快速检索key是否在这个sst文件中

##### 数据结构设计
```go
type manifest struct {
	levels [][]*sst
}
type sst struct {
	fileName string
}
```
##### 对外接口设计
read->Protobuf Data->writer 
#### 更优解
**支持高性能的update操作**
顺序写的性能远天于随机写，因此使用mmap+append的设计思想可以充分发挥ssD的性能。
> 顺序写保证不会有频繁更新导致的脏页问题,脏页会导致频繁的页交换
##### 问题
**append策略会导致读取逻辑复杂，需要重播所有变更，那么就会导致数据库重启速度变慢。**
引入对变更程度的度量来衡量判断检查点时机，对manifest文件cehckpoint，覆写文件。因此把manifest文件可以设计成只有创建和删除sst两种命令的状态机。
因为有删除操作，内存中使用list会导致多次移动元素，故内存用map来组织数据
**如果整个db只有一个manifest文件，那是否会存在单点问题？**
通过底层磁盘的亢余阵列来保证，并且保证数据库每次都在一个正确的状态下启动
##### 数据结构设计
```go
type Manifest struct {
	Levels []set[int64] // level->table set 每层有哪些set
	Tables map[uint64]TableManifest // 快速查询一个table在哪一层
	Creations int // 统计sst创建次数
	Delections int // 统计sst删除次数
}
// table元信息
type TableManifest struct {
	Level uint8
}
```
##### 对外接口设计
1.funcOpenManifestFile(opt \*Options)(\*ManifestFile,error)
	a.打开/创建manifest文件
2.AddTableMeta(levelNum int,t \*TableMeta) (err error)
	a.添加table元信息到manifest文件
	b.在这里会在一定阈值时，进行覆写以便于提高数据库恢复的速度 
3.RevertToManifest(idMapmap\[uint64]struct)error
	a.检查manifest文件正确性，保证db在一个正确的状态启动
	b.对比manifest文件和工作目录中的sst文件，删除非重合的部分

### 设计原理
#### 数据结构
![](KV%E5%AD%98%E5%82%A8/attachments/3e47fe20f5a206368d0191f587937cbd_MD5.jpeg)
#### 实现逻辑
![](KV%E5%AD%98%E5%82%A8/attachments/25dec16af6bca138fdc15da6ce82f4fe_MD5.jpeg)
**1.加载manifest文件**
	a.打开工作目录下的manifest文件 
	b.如果manifest不存在
		i.则创建一个内存中的manifest结构
		ii.并通过覆写的方式创建一个manifest文件
			1.创建一个remanifest文件
			2.将当前的状态全部抽象为changes对象，然后追加得到一个list
			3.将其整个序列化到刚刚打开的remanifest文件（magicllen,crc,manifestChangeSeti） 
			4.然后对remanifest重命名为manifest文件
		iii.并直接返回结果
	C.如果文件中存在新的数据，则会执行重放逻辅
		i.按文件格式循环解析manifestchangeSet结果 
		ii.遍历manifestChangeSet逐条应用change消息
			1.如果是创建则更新内存中manifest中的levels和tables，并统计创建命令的次数 
			2.如果是删除则删除manifest中的levels和tables，并统计删除命令的次数
**2.构建levelmanger**
	a.从manifest的元信息中解析出sst文件的fid
	b.对比工作目录中多余的fid，将其删除，保证集群从正确的状态启动
	c.然后逐一写入对应的level list中，并且按fid排序 
	d.根据fid逐一打开sst文件，并加载其索引块
3.添加一个sst文件到manifest中
	a.创建一个changeSet对象 
	b.应用到内存的manifest中
	c.判断是否达到覆写阐值，如果达到则覆写manifest文件
	d.序列化后追加写入到当前的manifest文件 
	e.手动调用sync接口同步manifest文件
> **如果写入manifest失败如何处理？**
> 保证可以从wal中恢复即可

### LAB-MANIFEST实现
https://github.com/hardcore-os/corekv/tree/lab_manifest
全局搜索LABManifest关键字可以找到coding的位置
### 源码导读
GitHub-hardcore-os/corekv
在无法独立完成LAB时的一个参考答案

## Lesson07 Recovery
### 需求背景
为解决数据库进程崩溃造成数据法失情况的发生，需要一种能够让数据库在重启时恢复上一次运行最后一个正确状态的机制。
### 测试用例
#### 正确初始化
```go
func TestFLushBase(t *testing.T)
	lsm=buildcase() 
	test := func() {
		//测试flush
		assert.Nil(t,lsm.levels.flush(lsm.memTable))
		//基准chess
		baseTest(t,lsm)
	}
	//运行N次测试多个sst的影响 
	runTest(test，2)
}
```
#### 异常初始化
```go
func TestRecoveryBase(t *testing.T) (
	buildCase()
	test := func() {
		//丢弃整个LSM结构模拟数据库崩渍恢复
		Lsm：=NewLSM(opt)
		//测试正确性
		baseTest(t,lsm)
	}
	runTest(test，1)
}
```
#### 调用场景
在LSM结构初始化的时候调用，如果没有WAL文件存在则创建空的memtable对象
```go
// 恢复接口
func (lsm *LSM) revocery() (*memTable, []*memTable)
// 写wal接口
func (wf *WalFile) write(entry *utils.Entry) error
```
### 架构设计
![](KV%E5%AD%98%E5%82%A8/attachments/8a06f136fbc38cc0fe5f895c88e1c74d_MD5.jpeg)
### 更进一步
1. 为保证数据一定写入了文件，每次WAL时都需要调用sync函数，同步文件系统？
2. 如果没有写满一个memtable时数据库就崩溃了，那么重启后创建一个新的memtable，这样会造成wal文件的磁盘空间浪费（因为mmap会事先分配文件大小）？

### 实验要求
基础实验
在lab_recovery分支上完成实验
提高实验
代码中有一处bug

### Lesson08 Parallel Compact
#### 需求背景
现在的corekv，所有的sst都仅会在Lo层（memtable的flush)，在whiskey论文精读讲过sst通过**归并排序**实现分层的意义在于可以在常量次数的查找内确定key在哪一个sst文件中进而提高性能。
那么选择LO层的哪几个文件合并到L1层？更一般地讲
> 应该选择Lx层的哪些sst合并到Ly层可以使得查询效率最大化？

LSM是非就地更新的，通过不断追加不同版本的kV来实现高性能的写入，但我们并不需要过于陈旧的key，这会造成存储空间的浪费，存储过多版本key的同时也会使得检索key的时候查询更多无效key而增加耗时,也就是说：
> 应该如何删除无效版本的key，提高空间利用率？因此我们的需求就是

1.实现一种Lx到Ly压缩(归并排序)sst的分层机制，提高查询效率。
2.正确的识别无效的key(不会再被访问的key)并将其删除，提高空间利用

那么为了实现这一过程，需要设计一个新的组件：Compacter，专门用来解决kv引擎中sst文件分层和无效key回收问题。
#### 问题约束
Compacter的过程一定是由一个后台协程完成的，因为他不需要与调用者交互，其技术挑战在于： 
a.Lx到Ly层的合并，那么x和y应该如何选择，才能提高查询效率？
b.如何识别无效的key并在何时删除key，使其空间利用率最天并对性能影响最小 
c.引擎在compact时发送崩溃应该如何处理才能保证数据的一致性？
d.对于corekv来说，在压缩过程中如何充分发挥ssD特性，提高compact的效率？

#### 接口定义
Compact如何与LSM的其他组件交互的？
	a.Compact在LSM初始化的时候创建后台执行的协程，并周期性的检查levelManger中levels管理的
各层状态，通过状态来决定真正compact的时机。
	b.当触发compact条件后，则将根据levels中的元信息生成压缩计划，指定从哪层压缩到哪层，以及涉及的两层sst的fileName。
对涉及的sst文件建立一个统一的送代器，逐个获取合并后的kv数据，写入table的构建器中，完成送代后flush到自标层上。
在压缩过程中涉及需要合并的sst是可以被检索的，只有压缩完毕后才会原子的更新manifest文件和内存索引完成合并。
![](KV%E5%AD%98%E5%82%A8/attachments/21fc89b0a81009bf8ebddcc32c1c0dff_MD5.jpeg)

#### 设计与实现
##### 暴力解
在磁盘中进行多路归并排序，是compact的算法基础，一个符合直觉的解：
1.针对LO层的sst全部是从内存表dump没有经过合并因此必然存在重叠区间的事实，每次LO层文件数量或者所有sst文件的总字节数送到一人國值的时候就会触发合并，将LO层中相互重叠的sst文件选中（口能有多个重叠组)，然后将LO的重叠组和L1中的所有文件进行比较，将L1中与重叠组有重合的SS加入重叠组，判断重叠只需要比较sst的最大key和最小key即可(sst文件本身是有序的)，而二者都已经在 table的索引元数据中被记录，因此是没有性能损失的。
2.对于L1到L6的其他合并，只需要在当前leve的size超过國值后选择其中fid最小的那个sst文件（最旧的)，和下一层的所有sst文件判断是否有重叠后选中有重叠的sst文件然后执行多路归并生成新的sst 文件。
3在合并的过程中需要不停的合并同一个kev的不同版本，所以必须要对至少两个sst文件施行归并排序，由于每个sst文件本身都是有序的，不同key按升序排序，相同的key按版本的降序排序，因此合并时仅写入第一个key，而忽略相同key的其他版本即可实现压缩。
![](KV%E5%AD%98%E5%82%A8/attachments/2f67375f110ee16e774c1707b43e5cc0_MD5.jpeg)
##### 更优解
1.LO层因为sst是无序的，合并时会涉及较多的sst，如何优化读写延迟？
> 1：合并时.对涉及的sst加读锁，保证依旧可以对外检索，而minor的过程只会向Lo添加新sst.因此可以保证是无阻塞的，同时当majorcompact结束后才会删除sst文件此步骤会造成阻塞(可通过mv的方式原子删除提高并发度）。
> 2.对LO层的查询最坏情况可能要遍历所有的sst文件，因此对LO层sst文件自身进行压缩，可以有效减少LO层SSt文件的数量，进而提高查询性能。

2.compact过程需要从Ln到Ln+1，一个有效key至少经历7次的移动，写放大严重如何解决？
> 如果Lmax层没有达到预期的容量，可以直接实现LO到Lmax的压缩，进行跨层级压缩，来减少写放大的可能性。

3.16层的数据会越来越多，是否会导致数据倾斜？过期的key在l6层如何被清理？
> 数据到达L6层后将无法被压缩到下一层，因此实现L6层自身的压缩，可以清理L6层的无效数据，提高空间利用率和性能。

4.为充分发挥ssd的并行度，如何实现并行compact压缩，来提高性能？
> level级别和table级别都加上读写互斥锁，然后维护一个全局的关于sst的状态表，记录每一个压缩任务的执行状态以及涉及的sst有哪些，在生成压缩计划的时候，检查其互斥性，如果当前压缩任务涉及的sst文件与正在执行的其他压缩任务没有冲突则可以执行否则失败。

5.对于Lx到LV的压缩，如果选择x与V才能使得整体压缩效益最大化，节省空间提高性能
> Lo层根据sst文件的数量来决定，其他层根据每个level的去除正在压缩状态的sst文件的总size与每层的期望size的比值作为优先级，而每个level的期望size之间相差一个数量级。

6.压缩过程执行到一半，数据库崩溃后数据的一致性如何保证？
> 只有在manifest文件状态变更成功后，才会向Lx中删除老旧日的sst，并在Ly中添加新的sst文件。

7．多个协程执行并行压缩，如果频繁出现并发冲突该如何解决？
> 在多个并发执行的压缩器初始化时，给予一个500ms左右的随机时间，使得每个压缩器执行的并发性被打散，降低冲突的可能性。

8.压缩时读取sSt文件到内存进行排序是否会造成OOM？
> 使用迭代器模式，从磁盘中逐条拉取数据到本地，减少内存的使用避免OOM，并且可以适当的使用并行预取机制，优化读取性能。

9.迭代器的range是否会破坏block的缓存？
> 选代过程中正确识别，送代器的使用场景，跳过setcache的过程

##### 详细设计
![](KV%E5%AD%98%E5%82%A8/attachments/fe2e7f8fa63d1e14cee234bc9894bfe2_MD5.jpeg)
![](KV%E5%AD%98%E5%82%A8/attachments/674a11e6e952ba8ebbc858f9c279593b_MD5.jpeg)
逻辑实现
![](KV%E5%AD%98%E5%82%A8/attachments/6219b1e0b585f17d75561c5881e49b76_MD5.jpeg)
###### 迭代器设计
![](KV%E5%AD%98%E5%82%A8/attachments/ff170bc844ce821f37fdc049bbcd1ba2_MD5.jpeg)
###### 详细逻辑
![](KV%E5%AD%98%E5%82%A8/attachments/a2947ce93446b1fa92fcedf5e250286a_MD5.jpeg)
#### LAB:Parallel Compact

### Lesson09 LSM Logic Robustness
![](KV%E5%AD%98%E5%82%A8/attachments/499944e43cfd784afd1518edfa87949d_MD5.jpeg)
![](KV%E5%AD%98%E5%82%A8/attachments/11d98cff10774c710acae8f2b431a6a8_MD5.jpeg)
![](KV%E5%AD%98%E5%82%A8/attachments/5cb028a89c7d332b019022647799f5a8_MD5.jpeg)
![](KV%E5%AD%98%E5%82%A8/attachments/bc12b61d38c89a0cb202100d892cdf3d_MD5.jpeg)![](KV%E5%AD%98%E5%82%A8/attachments/9da0804cc183801fcb4b97780a9899e4_MD5.jpeg)

### Lesson10 vlog file codec
#### 背景需求
在论文《目WiscKey：在SSD存储上的键值分离设计》介绍了kv分离这种思想，关于kv分离是什么/有什么用/怎么做的问题这里不再复述，可以看《目wiscKey论文精读》了解更多。本节内容直接关注，kv 分离在corekv的具体实现上。
#### 组件交互
KV分离是如何集成在LSM系统中的？
![](KV%E5%AD%98%E5%82%A8/attachments/140b070096bf39cbf0e731ffbda42ec2_MD5.jpeg)
根据上图得出以下7个命题：
1.SET kV时判断值的字节大小是否超过阈值是则将其写入vlog文件并将返回的值指针写入sst中。 
2.GETkey时从sst中查询值并判断其是否为值指针是则从vlog中查询真正的值，否则直接返回。
3.vlog文件是一组fid自增的文件写入的数据超过设定阐值大小就会通过滚动的方式写入到fid+1的文件 
4.存在一种GC触发方式，从vlog文件组中选择一个脏key数量最多的文件进行重写操作
5.重写操作就是删除无效key.保留有效key到一个新vlog文件中的过程。 
6.对于重新写回LSM的有效key,可以批量的写入以提高性能
7.kv先写vlog文件再写LSM，因此必须保证vlog文件与sst文件的一致性
#### 接口设计
1.根据命题1/2，在GET/SET时需要得知何时做kV分离以及判断从sst掌到的值是否为值指针。
> 需要引入一个参数，来判断value的天小是否超过值，就叫ValueThreshold。
> 需要一个函数用来判断值是否为值指针，在sst增加一个meta字段存储flag元数据

2.根据命题3，vlog应该以仅追加的方式写入并持有一个统计学段可以识别当前文件大小以便于分割
> 需要记录一个maxFID表示最后一个活跃的vlog文件，然后记录一个offset代表下一个可写位置 vlog文件底层还是依赖mmap，与wal文件很像也是仅追加的写入
> 通过记录当前vlog文件的学节大小以及已经写入的kv数量双重判断是否需要切分滚动vlog文件

==mmap与fd write性能对比==
`mmap` 通过**消除数据拷贝和系统调用**，在小数据和随机访问场景下是绝对的性能王者；而 `write` 在处理**大块数据流**时，凭借简单的逻辑和高效的 DMA，依然是非常稳健的选择。
也就是说，在value大于4KB的时候（KV分离阈值），直接使用fd的write顺序写性能更高。
3.根据命题4/5，协程应该持有一个vlog列表以及统计组件用来识别脏key并处理复写过程中的并发问题
> 这个问题在下一节详细讲解

4．根据命题6，需要设计一个批量写入LSM的新路径，以加速vlogGC的进程。
> 批量写入LSM，需要使用channel来传递，因此需要维护一个request结构体封装buf存储批量数据这个问题在下一节GC过程中详细讲解

5.对于命题7，写入vlog数据后如果DB崩溃，则可能丢失数据，因此需要重放vlog数据
> 需要一种重放机制，在DB初始化时从vlog文件上一个检查点位置重新读取kV并写入LSM保证数据一致

综合来看，我们需要:
一个ValueLog结构体作为整个kv分离机制的驱动组件统一所有逻辑。
> 具体来说，KV分离需要有初始化/读/写/关闭/GC(重写)/重放等功能模块。

一个LogFile结构体来处理vlog文件的磁盘存储以及编解码问题。
> 要基于mmap实现vlog文件的存储，实现具体的读/写/关闭操作

一个DiscardStats结构来封装kv分离过程中的统计数据。
> 在compact的时候进行统计每个fid写入kv的总字节数，用一个map组织以json序列化后作为一个内部 key存储在DB中，作为一个统计快照

==根据上述的分析，本节中我们可以得到这样的需求列表：==
1.实现一个vlog驱动组件，用来控制整个kv分离机制（读/写/统计/重放/复写）
2.open函数，当存在vlog文件时需要重放之前的vlog文件否则重启一个新的vlog文件
3.read函数，根据值指针查询到具体的entry对象并返回 
4.write函数，写入entry对象并返回值指针
5.close函数，优雅关闭时，释放持有的vlog文件句柄
```go
//valuelog
type valueLog struct {
	...
	// 全局的文件句柄映射表：维护fid与logfile映射关系
	filesMap map[uint32]*file.LogFile
	// vlog文件当前最大的fid值，代表当前唯一可写的vlog文件
	maxFid uint32
	// coreKV全局驱动对象
	db *DB
	// maxFid对应的vlog文件中下一个可写的offset位置
	writeableLogOffset uint32
	// 已经写入的vlog中kv数量
	numEntriesWritten uint32
	// 全局的配置对象
	opt Options
	// 统计每个vlog文件脏key数量，便于选择最需要被GC的vlog文件
	lfDiscardStats *lfDiscardStats
	...
}
func (db *DB) initVLog()
func (vlog *valueLog) close() error
func (vLog *valueLog) write(reqs []*request) error
func (vlog *valueLog) read(vp valuePointer) ([]byte, func(), error)
```
#### 实现原理
箭头起点表示调用者，终点表示被调用者
除3.a与3.e除外(二者表示了数据的流向从LSM返回给DB)
![](KV%E5%AD%98%E5%82%A8/attachments/9e21e42580f9bfc7b5f6973cdebde748_MD5.jpeg)
1.在db初始化的时候调用initvLog函数（对应绿色线条）
	a.启动discard数据收集协程，记录每个\[fid].vlog有多少被丢弃的value 
	b.丛工作自录中获取所有以.vlog结尾的文件从中获取tid列表
	c.如果fid列表为空就创建一个O.viog文件，否则排序fid后遍历打开每个vlog文件并更新maxFiD 
	d.对每个\[fid].log文件进行重放，逐一遍历kv数据批量打包为request,写入LSM
	e.通过maxFID获取最后一个活跃的vlog文件并seek到未尾获取其offset作为writableLogoffset 
	f.获取！corekv！discard内部key的值，是用来存储discard统计数据的快照，用来恢复DB状态
2.db写入一个kv,通过shouldwriteValueToLSM判断vlaue是否超过阐值（对应红色线条）
	a.超过阈值，写入vlog文件，将key,value数据封装一个request对象调用valueLog的write方法 
	b.加锁获取maxFID从中获取当前可写的logFile文件句柄，调用其write方法
	c.创建一个buf对象将kv数据编码为二进制数据写入buf，并构建值指针对象后写入LogFile
	d.判断当前的vlog文件是否达到了切割标准，是则newID=maxFid+1，创建一个新的LogFile文件
	e.最后db将entry的meta字段中添加BitValuePointeruePtr表示一个值指针，将valuePtr写入LSM 
3.db读取key(对应蓝色线条）
	a．先从LSM中读取到entry对象，判断entry的meta字段是否有BitValuePointeruePtr的标记
	b.是的话则将entry的value反序列化为valuePtr结构体，并调用vlog的read方法读取真正的value 
	c.先加锁，再根据valuePtr中的fid在map中找到logFile的句柄调用其read去mmap中查询bytes 
	d，对读取的数据进行crc32检查，检查对value的读取是否有效，最终返回value的数组
	e.然后通过拷贝替换db持有的entry的value字段，将entry返回给db调用者 
4.DB关闭vlog对象（未在途中表示
	a.等待关闭信号(所有协程任务运行完毕）
	b.遍历filesMap对象掌到所有的fid，对于maxFID进行截断操作 
	c．对于所有的fid逐个关闭底层的LogFile对象，释放内存和fd句柄

关键细节：
1值指针应该如何设计？ 
FID+Offset+Len
2.vlog的存储格式如何设计？ 
head+key+value+crc32
其中head包含klen+vlen+(meta)?
3.如何为sst的存储格式中扩展一个meta字段？
需要对kv的pb结构/表/builder/valueStruct等组件进行修改，相对复杂
#### LAB：实现vlog文件的编解码

### Lesson11 vlog gc
#### 需求分析
不断追加的value数据会使得vlog文件组filesize不断变大，而这些被存储的value有可能已经失效（过期，被删除，被更新)。存储无效的value就会导致空间利用率降低，并且也会影响QueryRange的效率。
**如何在不影响线上请求的情况下，删除无效的value呢？对这一问题的解决方案就是垃圾回收(gc)**。 GC需要在尽可能低成本的运行，因为它是一种代价，并不创造收益。
任意GC算法都需要回答三个同题：**何时触发？如何识别？如何删除？**
对于corekv来说，他是一个底层kv引擎，仅知道读写负载这一信息，很难在最佳时间触发Gc。若过于频繁触发会使性能抖动，过于缓慢触发会失去GC的作用。因此应该交由kV的使用者来进行GC这一决策，开发一个对外的接口，让使用者根据业务情况选择最佳的GC触发时机。
识别垃圾对象是困难的，因为corekv不能中断写操作并且支持TTL，如此说来，在任意时刻总存在新产生的垃圾对象，那么识别程序必须能够高效识别且知道何时终止识别过程。对于Vog文件来说，其逻辑上是一个仅追加的文件，物理上是多个分段支件组成的。对于一个这样的线性列表支件，可以从头开始遍历一遍，每次去LSM中查询当前的key是否无效，并将无效的key忽略，有效的key保留。同时完成识别与删除操作，这就是在线垃圾收集的基本思想。
那么问题是每次gc都需要从头开始遍历这在效率上是不可行的，因此可以想到使用采样统计的思想进行优化，如果每次我们随机采样其中儿个Vlog文件进行GC是否会做到完美的权衡得失？
比随机选择更好的方式是利用一些信息进行选择，比如记录每一个vlog文件中有哪些过期的脏key存在，每次选择脏key数量最多的vlog文件。那么在哪在什么时候做这个统计操作？compact的时候是最佳时机，因为本来就需要遍历整个sst文件，他知道哪些key需要被删除，在compact的时候将被删除的key 通过channe发送通知，交给一个专门统计脏kev的协程，来统计这份数据，然后基于这个数据每次选择脏key最多的vlog文件，对其Gc。
**如果这份统计数据由于kV引擎崩溃而丢失了怎么办**？这就需要kV定期将其同步到DB中，作为一个内部key存储到磁盘中。
上面提到过删除无效key的办法就是再次把有效的key写回DB一次，根据set的流程，set后的数据会再次被插入vlog文件的tail位置，完成GC。**如果当key1判断为有效key写回DB的同时，在线请求对key 进行了update操作并且先一步写入DB，那么这一重写操作是否会覆盖正常的set操作呢？**
在上面的流程中肯定是会的，因此解决办法就是在GC的时候禁止memtable滚动，只要保证LSM中写顺序的正确性即可，因为vlog文件对value的顺序不敏感，可以理解为LSM是vlog的一种索引，而所有的数据存储在仅追加的日志中(这一思想也是现代分布式系统的核心思维模型）。只要禁止memtable的滚动，跳表会按kev的时间排序，这样我们通过在一个跳表中利用时间截的有序性解决了重写时的并发冲突问题，这也是为什么要禁止内存表滚动的原因，因为滚动会导致keV1跨跳表写入，无法利用这一特性。
#### 系统设计
![](KV%E5%AD%98%E5%82%A8/attachments/386fb65d1b0da20a39fed6e47a55d340_MD5.jpeg)
**用户调用RunValueLogGc接口传递discardRatio参数（丢弃率）** 
1.选择discard统计值最大的那个vlog文件
2，对该文件进行采样，检查当前这个文件是否值得被重写
3.读取当前文件的所有kv，然后拿其中的key去lsm中查询，并将两个entry进行对比检查当前的这个entry是否有必要重写，如果有则封装为request对象并发送给writech
4.从writeCh中读取到req，写入到req的buf中，直到达到buf的预期大小，然后一次性写入vlog文件（需要kv分离的entry会被写入），而不需要写入vlog的entry会被直接写入lsm中。
#### 接口设计
`func (kv *KV)RunValueLogGC(int ratio) error`
#### 关键细节
1.异步写入如何防止背压？背压强调的是对于一个队列模型，输入数据的速度大于输出数据的速度，进而导致缓冲区溢出的现象，在corekv中，由于异步的批量写入很容易造成写入速度高于存储速度导致 OOM，因此需要一定的机制来限制异步写入的频次。
2.在上一节中我们专注于vlog文件的编解码并没有讲清楚vlog是如何与现有corekv整合到，我们从GET和SET两个函数看下其中要做事情。
```go
func (db *DB)Set(data *utils.Entry) error {
	// 必要检查
	// 如果value大于一个阈值，则创建指针，并写入vlog中
	var (
		vp *utils.ValuePtr
		err error
	)
	// 如果value不应该写入LSM，则先写入vlog，必须保证vlog具有重放功能 便于崩溃恢复
	if !db.shouldWriteValueToLSM(data) {
		if vp, err = db.vlog.newValuePtr(data); err!=nil {
			return err
		}
		data.Meta |= utils.BitValuePointer
		data.Value = vp.Encode()
	}
	return db.lsm.Set(data)
}
func (db *DB)Get(key []byte) (*utils.Entry, error) {
	var (
		entry *utils.Entry
		err error
	)
	// 从LSM中查询，判断entry是否是值指针
	if entry, err = db.lsm.Get(key); err!=nil {
		return entry, err
	}
	// 检查从lsm中拿到的value是否是ptr
	if entry != nil && utils.IsValuePtr(entry) {
		var vp utils.ValuePtr
		vp.Decode(entry.Value)
		result, cb, err := db.vlog.read(&vp)
		defer utils.RunCallBack(cb)
		if err != nil {
			return nil, err 
		}
		enrty.Value = utils.SafeCopy(nil, result)
	}
	return entry, nil
}
```
3.corekv作为一个高性能的引擎，必须保证被频繁使用的对象应该尽可能的复用，减少创建对象时分配内存与回收对象时释放肉存的资源消耗。而reguest的对象就是常见的频繁被创建使用的对象，因此我们需要使用对象池机制来提高性能。
4.**值指针是如何编解码的**？任何对象在内存中都是一段学节序列(学节数组），因此理论上任何一个对象都可以直接转化为学节数组，但由于复杂对象包含指针学段，其对象本身不能保护全部的信息，因此该对象的学节数组是不能作为序列化的等价产物的，但如果该对象仅包含基本数据类型，那么其自身的字节数组包含全部序列化信息，因此该对象的学节数组可以与序列化产物直接等价。
```go
type ValuePtr struct {
	Len uint32
	Offset uint32
	Fid uint32
}
// Encode Pointer into byte buffer
func (p ValuePtr) Encode() []byte {
	b := make([]byte, vptrSize)
	// copy over the content from p to b
	*(*ValuePtr)(unsafe.Pointer(&b[0])) = p
	return b
}
// Decode the value pointer into the provided byte buffer
func (p *ValuePtr) Decode(b []byte) {
	// cpoy over data from b into b. 
	copy(((*[vptrSize]byte)(unsafe.Pointer(p))[:]), b[:vptrSize])
}
```
5．GC可以同时运行多个嘛？
肯定是不行的，操作vlog每次只能有一个协程，因此需要一个并发控制限制。 
6.每次都要从头开始执行Vog嘛？这样效率是不是太低？
vlog文件在相对较大的时候不能立即删除，而应该先被逻辑删除，在一般情况下fid较小的vlog文件会GC 清除，因此当corekv重后启重放时，如果每次都从o.vlog开始，则会做过多的无用功，所以需要有一个head指针表示小于该位置的指针都是无效的kv数据，不需要关注(重放/GC）。 
7．如何选择一个vlog文件执行Gc可以使得效率最大化？
如果每次都选择脏key最多的vlog文件执行gc那么Gc的效果就是最大的，但当corekv是第一次启动，没有统计数据时该如何选择？这个时候最简单的方式就是使用随机选择的方法，随机选择一个Vvlog文件进行GC，利用随机选择作为一种降级策略。 
8.选择出来的vog文件就一定会执行嘛？
需要说明的是要有一个标准来判断执行此GC是合法的，我们定义一个丢弃采样率这样的一个指标在接口中传递进去，用来判断当前的vlog是不是值得被GC，这一判断是对选择策略的一个补充，因为有可能是随机选择出来的，那么如何判断其被GC的价值呢？可以通过排除法，首先一个刚刚被创建的vlog支件不值得被GC，maxFID的vlog一定不能被Gc（还在append中），在两个size和count的采样窗口内去检查被读取的key是不是一个被丢弃的key，是的话就对齐进行统计。
如果可丢弃的key不足count窗口的大小(通常是1ooo条)，或者其可丢弃的kv总大小不足size窗口，或实际去弃key的总size小于预期size（总size\*去弃率）那么我们门就跳过这个vlog文件的Gc任务。
```go
func DiscardEntry(e, vs *Entry) bool {
	if isDeletedOrExpired(vs.Meta, vs.ExpireAt) {
		return true
	}
	if (vs.Meta & BitValuePointer) == 0 {
		return true
	}
	return false
}
```
9.如何执行GC？
在kv分离所追求的在线GC本质上可以等价于重写操作，因此在vlog的gc实现中，直接对被选中的文件执行重写即可完成gc。
遍历vlog文件，拿到key去读DB，解析值指针，然后用值指针去vlog文件查询到kv数据组织为entry写入一个buf中，buf满时披露写入LSM中，为充分发挥SSD特性，可以异步的并发写磁盘，来提高写性能。
批量写入writeCh中，专门的写协程会处理批量写请求，要产严格控制写入磁盘的频率避免背压现象产生。
#### 逻辑流畅
![](KV%E5%AD%98%E5%82%A8/attachments/72e3427bb8ff99107b2d89a60372133d_MD5.jpeg)

### Lesson11 API
#### 背景需求
我们在前面的课程当中，实现了各个独立的模块，包括内存部分的Memtable、磁盘部分的SsT、Vlog 以及各种数据结构中的lterator。但到自前为正，我们还没有提供给用户使用的APl，在今关的课程当中，我们就来实现coreKv最外层的APl。
#### 组件交互
![](KV%E5%AD%98%E5%82%A8/attachments/1487393d321df91c16c7a499ac588c6e_MD5.jpeg)
CoreKV是经典的LSMTree架构，但与传统LSMtree不同的地方在于，引I入了Wisckey的特性。即在Value值比较大的时候，会使用KV分离的方式进行存储。这样减少了写放大。
==内存部分==
在Corekv的内存部分，称为MemTable，分为MemTable和ImmutableMemTable，具体的实现我们采用了SkipList，他对外提供了一些接口，这些接口我们后面需要用到，来实现一个完整的KV读写流程。
==磁盘部分==
磁盘部分分为三部分
ssTable通过LevelManager进行管理
![](KV%E5%AD%98%E5%82%A8/attachments/ac92abc2c1e1caa2a7463b75c89c490e_MD5.jpeg)
WAL文件，将数据写到MemTable之前，需要先写入WAL文件，保证原子性。 
VLog文件，KV分离后，存储Value的文件
我们来关注这个图中的Set和Get调用，接下来我们的工作就是将整个流程串起来。
#### 接口设计
我们需要提供那些API？
> 打开并初始化一个DB
> 关闭DB、并且清理占用资源
> 在DB中进行增删改查、遍历等操作

首先我们需要一个Open方法，来显式的打开数据库。
Open(opt \*Options)\*DB
这个方法需要传入一些配置参数，返回值是一个DB实例
在Options当中，我们需要提供以下可配置的参数
	1.在CoreKV中，我们实现了KV分离的特性，但是Value达到多大需要进行分离存诸，这个需要根据业务实际调优，因此这个值需要对外提供可配置选项。
	2.同理MemTable SSTable VLogSize都需要提供可配置选项。
```go
// Options 总配置文件
type Options struct {
	ValueThreshold int64 // kV分离阈值
	WorkDir string // 数据库文件保存目录
	MemTableSize int64 // 内存MemTable大小上限
	SSTableMaxSz int64 //SST文件大小上限
	MaxBatchCount int64 //最大批量写入数量
	MaxBatchSize int64 // max batch size in bytes
	ValueLogFileSize int // Vlog文件大小
	VerifyValueMaxEntries bool
	ValueLogMaxEntries uint32
	LogRotatesToFlush int32
	MaxTableSize int64
}
```
close()
关闭数据库，清理资源占用，包括打开的文件描述符、占用的内存资源。具体需要关闭哪些呢？ MemTable的内存占用，Vlog的文件描述符和Stat统计信息的内存占用。

API
> Set
> Get
> Del
> Update
> Range

Info
返回统计信息

DB数据结构
```go
// DB 对外暴露的接口对象 全局唯一，持有各种资源句柄
DB struct {
	sync.RWMutex
	opt *Options
	lsm *lsm.LSM
	vlog *valueLog
	stats *Stats
	flushChan chan flushTask // For flushing memtables
	writeCh chan *request
	blockWrites int32
	vhead *utils.ValuePtr
	logRotates int32
}
```
#### 实现原理
现有组件提供的接口情况
LSMTree中包含两部分MemTable和SSTable，具体的交互细节这节课不需要关注，我们只需要知道调用LSM的Set接口，可以将数据写入；调用Get接口，可以将数据读出。
同时LSM提供了NewLSM初始化方法，和Close清理资源的方法。

Vlog提供了open和close方法，write和read方法，这里我们也不用关注。
我们唯一需要感知到的接口就是newValuePtr，这个方法将单个的Value包装成Vlog可以识别的 Request，并返回一个Vlog中的指针值。

我们先梳理一下，这些组件提供的所有对外接口。
MemTable和SSTable共同组成LSMTree，通过LSMTree对外提供接口，提供的API有Set、Get
调用LSM的Set方法时，为了保证原子性，因为文件需要先写入WAL文件，WAL文件提供有Write方法，但是LSMTree的实现中，我们已经集成到了LSM的API中，因此这里不用关心。

总结：
LSM Tree：Set、Get
vlog：newValuePtr

##### Set接口
1.调用者将要存储的Key和Value组装成CoreKV的Entry结构体，Key和Value当前只支持\[byte]类型
```go
// NewEntry
func NewEntry(key, value []byte) *Entry {
	return &Entry {
		Key: key,
		Value: value
	}
}
```
2.调用者调用Set方法，传入Entry结构体。
3.判断是否超过KV分离值，如果超出國值，需要进行KV分离，则调用vlog提供的写入方法newValuePtr写入Value值。同时将Value的指针值替换给Entry的Value 
4.写入LSM树
![](KV%E5%AD%98%E5%82%A8/attachments/13a820d0050bb9e6014927c9a6fede0a_MD5.jpeg)
##### Get接口
1.调用者调用Get方法，传入要查找的Key值
2.直接调用Ism的Get方法，从LSM树中查找。如果查找不到，即返回NotFouna
3.如果查找到对应的Value，需要判断Value是否是指针类型，如果是指针类型，需要进行解码 4．如果非指针类型，直接组装成Entry。如果是指针类型，解码后，传入Vlog拿到存储的值 
5.判断Entry是否是已过期的值。
6.返回Entry或者ErrKeyNotFound
![](KV%E5%AD%98%E5%82%A8/attachments/5adc5742c0bd3aaa9991e47e5c59aa6c_MD5.jpeg)
##### 更新和删除操作
这两种操作都可以视为变种的Set操作。
由于LSMTree中的MemTable支持原地的更新操作，我们来考虑如下三种情况
![](KV%E5%AD%98%E5%82%A8/attachments/2f5d314b2585e9f98edb38196ed21644_MD5.jpeg)
1、如果原始值还在MemTable中，Set相同的Key，那么能够保证在MemTable中只会保留有最新的值。
2、如果原始值被刷新到了SSTable中，Set相同的Key，那么MemTable中会存在最新的Key，此时最先读取MemTable，也能保证读到最新的值。
3、如果原始值被刷新到了SSTable，后面新Set的值也被刷到了不同的SSTable中，由于LSMTree的读取策略，能够保证读取到最新的ssTable中的最新Key。
对于册删除操作，我们可以利用幕碑机制。即，将Vaue设置为Nil，这样在读取到值为Nil的情况时，给用户返回NotFouno
##### TTL
TTL（TimeToLive）是KV存储诸中非常常用的一个功能，尤其是缓存场景中，可以使用TTL功能对缓存进行过期操作。
具体的实现有两种方式，一种是静默时的数据检查，一种是在触发读写操作时进行检查。在SST文件进行Compaction时，会对所有的KV对进行有效期的检查，过期数据在Compaction的时候会被丢弃，减少没有必要的写入操作。
在Get方法取到数据后，返回前，会再次进行有效期的检查。
##### Range
Range接口实现的功能是遍历整个corekV，这需要我们调用各个模块的Iterator来组合实现这个功能。 
Range接口的输出结果是当前DB中存储的所有有效的Key-Value对，同时这些Key-Value对应该按照一定的顺序有序输出（具体顺序取决于我们在实现过程中使用的比较器），我们在这里采用的排序规则是，按照字典序由小到大排序。
接下来我们要思考的问题就是，如何把所有的Key-Value对遍历一遍？
我们先来看一下当前实现了哪些Iteratol
内存表MemTable的Memlterator，作用是遍历整个MemTable
ssT文件的contactlterator，作用是遍历所有的SsTTable，每个Table文件都具有自已的lterator实现，通过Contactiterator进行组合送代。其中Levelo层的SsT文件因为Key值范围有重合，不能使用 Contactlterator进行组合，只能单独对每个Iterator进行遍历。
因此，我们只需要把所有的Iterator全部遍历一遍，所有的Key-Value对就会输出。但是还有一个问题是，有一些被删除或者失效的Key-Value，此时还没有被Compact删除，会不会也被遍历出来？
答案是不会。DBiterator是CoreKV最外层的迭代器实现，最终的实现是依赖Mergelterator，Mergelterator当中持有所有的Iterator，采用多路归并的思想进行比较遍历。在遍历Mergelteratol 时，会比较所有Iterator的Key值大小，把当前所有Iterator中最小的Key值输出。
![](KV%E5%AD%98%E5%82%A8/attachments/f40e43b0979ba36c0269efd344d88a48_MD5.jpeg)![](KV%E5%AD%98%E5%82%A8/attachments/8b6321cebe4f5395c7f34acbac72d733_MD5.jpeg)
##### 未来改进
支持事务

### Lesson12 单机事务实现 Snapshot Isolation
#### SI && MVCC
快照隔离（sl,Snapshotlsolation）是讨论隔离性时常见的术语，可以做两种的解读，一是具体的隔离级别，SQLServer、CockroachDB都直接定义了这个隔离级别；二是一种隔离机制用于实现相应的隔离级别，在Oracle、MySQLInnoDB、PostgreSQL等主流数据库中普遍使用。多版本并发控制（MVcC
multiversionconcurrencycontrol）是通过记录数据项历史版本的方式提升系统应对多事务访问的并发处理能力，例如避免单值（Single-Valued）存储情况下写操作对读操作的锁排斥。MVcc和锁都是Si的重要实现手段，当然也存在无锁的SI实现。 
##### SI运作方式
事务（记为T1）开始的瞬间会获取一个时间截StartTimestamp（记为ST），而数据库内的所有数据项的每个历史版本都记录着对应的时间戳CommitTimestamp（记为cT）。T1读取的快照由所有数据项版本中那些C小于S工目最近的历史版本构成，由于这些数据项内容只是历史版本不会再次被写操作锁定所以不会发生读写冲突，快照内的读操作永远不会被阻塞。
其他事务在ST之后的修改，T1不可见。当T1commit的瞬间会获得一个cT，并保证大于此刻数据库中已存在的任意时间戳（ST或CT），持久化时会将这个CT将作为数据项的版本时间戳截。T1的写操作也体现在T1的快照中，可以被T1内的读操作再次读取。当T1commit后，修改会对那些持有ST大于T1CT的事务可见。
如果存在其他事务（T2），其CT在T1的运行间隔ST，CT】之间，与T1对同样的数据项进行写操作，则T1abort，T2commit成功，这个特性被称为First-committer-wins，可以保证不出现Lostupdate。事买上，部分数据库会将其调整为Eirst-write-wins，将冲突判断提前到write操作时，减少冲突的代价。类似cAS，从而阻止了更新异常(LostUpdate)的出现。
> 简单提一下冲突检查的方式
> 实现的时候通常利用锁和LastCommitMap，提交之前锁住相应的行，然后遍历自己的WriteSet，检查是否存在一行记录的LastCommit落在了自己的\[ST,cT]内。
> 如果不存在冲突，就把自己的CommitTS更新到LastCommit中，并提交事务释放锁。这个过程不是某个数据库的具体实现，事实上不同数据库对于S实现存在很大差别。
> 例如，PostgreSQL会将历史版本和当前版本一起保存通过时间戳区分，而MySQL和Oracle都在回滚段中保存历史版本。
> MySQL的RC与RR级别均使用了SI，如果当前事务（T1）读操作的数据被其他事务的写操作加锁，T1 转向回滚段读取快照数据，避免读操作被阻塞。

实际上，我们可以对于上述运行过程提同
提交时进行的冲突检查是为了解决LostUpdate异常，那么对于这个异常来说，写写冲突的检查是充分且必要的吗？

#### Snapshot Isolation Demo
如果说直接上手corekv，编写它的事务处理模块太复杂，那么我们先从一个简单的Demo开始
在这个Demo中，我们模拟一个银行中的多个账户，每个账户都有一定的余额列表，我们会随机开启事务，在多个账户之间互相转账，同时检测转账的结果是否符合事务的要求。首先，我们来编写一个银行类，提供一些基本方法。
```go
type Bank struct {
	orcale *txn.TranscationManager // 事务管理
	accountNum int // 银行内所有账户数量
	accounts []*Account // 所有账户
}
```
对于Bank而言，我们要提供的一个核心功能就是，在账户之间转账。
![](KV%E5%AD%98%E5%82%A8/attachments/f520810f9a43fc15d129cc9241adb7c2_MD5.jpeg)
还有一个额外的功能，就是累计全部账户的余额，便于检查转账结果是否正确。
![](KV%E5%AD%98%E5%82%A8/attachments/8b3af83d5bc21ca05c184cf7ed054e63_MD5.jpeg)
对于一个账户，需要记录如下字段
![](KV%E5%AD%98%E5%82%A8/attachments/e3c892bf848e089093ef6465cdd3ad58_MD5.jpeg)
##### 快照读
Snapshotsolation的核心概念，是对于读操作来说，都从快照中读取，从而避免了读写冲突。
```go
type Transaction struct {
	mutex sync.Mutex
	id int64
	max int64
	active map[iny64]struct{}
}
```
那么如何生成这个快照呢？上述的代码中，我们看到，每一个事务对一个Account的操作都被记录在这个Account的history字段中。由于事务ID是严格单调递增的（我们用这种方式实现逻辑上的时间戳），当我们开启一个事务的时候，在TransactionManager当中获取一个StartTimeStamp，也就是当前事务的D，那么在此之前的HistorV就可以算作快照数据。那么具体满足哪些条件，才可以视为合法的快照数据呢？
首先，在获取到事务ID后，由于读写不冲突，该Account内的余额还有可能被其他事务更新，也就是说History字段当中还会不断的增加数据。自前可以确定的是，在该事务ID之后更新的数据，一定不能被当前事务可见。
所以我们记录下来第一个条件：**当前事务可见的快照列表，事务ID一定不能天于当前事务。**
第二个条件，在该事务开启时，在事务的结构体的active字段中，会保存在那一时刻所有活跃中的事务快照（该列表中的事务Commit或者Abort后会被册删除掉）。**当前事务只能看到被Commit的事务列表，因此History学段中的数据，都不能出现在Active列表当中**。这是第二个条件。
第三个条件，在该事务开启时，会保存当前最大的Commit的事务ID，那么大于该ID的事务，在事务开启的时刻，可以被认为没有被提交，自然对当前事务也就不可见。
那么第三个条件就是：**当前事务可见的快照列表，事务ID只能小于等于最大的已提交事务ID**
当然满足这些条件的History肯定不止一条，因为这当前事务的整个执行过程中，可能会有多个事务被提交。这时，我们只需要选择最新的一个事务就可以了。
上述的操作就是快照读，指的是，在读取事务开始时，申请一个StartTimeStamp，所有可读取的快照，必定在此StartTimeStamp之前。
##### 并发写
聊完了快照读，我们再来看一下并发写。
我们提到，所有对于Account的余额更新操作，都会在Account的History列表中记录下来，具体的数值，和是哪一个事务进行的更新。在Snapshotlsolation的论文描述中，写入操作在进行Commit时，会获取一个CommitTimeStamp，在该事务开启时的StartTimeStamp和Commit时的
CommitTimeStamp之间，如果有其他事务Commit了自己History中的数据，自己的事务就要Abort掉，否则就会造成其他事务Commit的数据被修改，造成LostUpdate。那么具体的逻辑怎么实现呢
在论文中提到，可以获取一个很久的StartTimeStamp作为事务开始的标志。那么我们干脆以最开始的时间戳作为StartTimeStamp。而在Commit的时候，才去申请一个CommitTimeStamp，在遍历操作时，去判断从StartTimeStamp到这个CommitTimeStamp内有没有事务从未Commit状态，到 Commit状态。
如同判断这个事务从未Commit变成了Commit状态呢？
我们提到在事务开始之初，在Account对象的History字段内包含了所有被Commit的历史数据。在事务对象的Active字段内，包含了事务生成时所有活跃的事务列表（活跃的意思是，已开启，未提交）。所以如果一条数据的事务D，存在于活跃的事务列表中，说明这条数据在事务并始时，这条数据还未被提交。而在Commit时，发现这条数据已经被提交到了Account的History字段中。当前事务就要被 Abort。
![](KV%E5%AD%98%E5%82%A8/attachments/0c1768cd48d58fc82533651d4b9e125f_MD5.jpeg)

### Lesson13 快照读
在学习了之前的SnapshotlsolationDemo之后，我们已经知道了如何去实现快照隔离级别。现在我们要
和CoreKV的代码结合起来，真正实现一个支持事务的KV数据库。
#### 背景
回想一下，之前实现的SnapShotIsolation，我们做了哪些事情？
> 在银行中实现了很多账户
> 需要在每一个账户中记录历史版本数据
> 读取时需要获取一个时间戳，来判断哪些历史版本对当前事务可见，从而实现快照读
> 写操作时需要获取一个commit时间戳，来判断范围内的数据是否被其他事务提交需要进行写写冲突检测

#### 组件设计
##### 历史版本
> 对应到银行中的一个账户，CoreKV中的一条数据就是一个KV对
> 对应到一个账户中的余额，Corekv中的就是一个value值
> 对应到一个账户中的余额修改记录，corekv中就是一个value版本
> 账户余额修改记录中的对应事务，corekv中就是key的ts

在CoreKV中，已经天然支持了多版本的数据结构。每一个Key在写入的时候，都会携带一个时间戳。 CoreKV1.o的时间戳，是在Key后面追加真实的物理时间戳，但是Key在大量并发写入的时候，时间戳不能满足精确区分同一个KeV写入先后顺序。因此我们必须实现一个逻辑时间戳，逻辑时间戳的获取我们在事务管理模块中完成。
我们再来复习一下，多版本的Key在CoreKV中的存储格式
![](KV%E5%AD%98%E5%82%A8/attachments/59b6d8ba2722274c298973a9d5e3e52b_MD5.jpeg)
解释一下上面这个图，在跳表的每个节点当中，存储的Key都是原始Key+TimeStamp，在SSTFile存储的Key当中，组成结构也同样是Key+TimeStamp，并且都是按照一定的顺序排列的，这个顺序的规则是，按照Key的学典序进行排列，当遇到相同的Key时，则按照时间戳截天小（Key的后8位）排序。
这也就是说，所有的Key中都包含了版本信息，这个版本信息在Key的后8位当中。且由于这个时间截是事务提交时的时间截，所以也可以找到对应的事务。（commitTs相关的逻辑会在事务的写入操作中讲解，这里先记住即可）。
看到这里，我们已经实现了Demo当中所有账户余额历史版本的保存、读取功能。
##### 迭代器
在对历史版本进行送代时，账户余额是保存在内存中的，因此我们可以方便的进行遍历。但是CoreKV会将数据进行下盘，因此我要读取出来指定版本之前的最新一个历更数据，这需要我作比【银行 Demo】代码，稍微多一些逻辑。
所幸的是，我们在CoreKV1.O的版本中实现了针对整个DB的送代器，但我们还需要一个额外的送代器--pendingWritelterator，也就是当前事务写入数据的送代器。
为什么需要当前事务写入数据的代器呢？
![](KV%E5%AD%98%E5%82%A8/attachments/bf8b3565e33ecddef97d08870e5b8052_MD5.jpeg)
1：在该事务进行读取时，对当前事务已经写入的数据，应该充许被读取到。
2，在该事务进行读取时，对其他事务已经写入但还未提交的数据，不应该读取到。
为了实现上述的效果，我们将一个事务的写入数据暂存在txn结构体的pendingWrites当中，只有当事务执行了Commit操作后，才调用DB的Set接口，将数据真正写入Memtable中。（写入操作时会细讲）。所以对这部分数据进行读取时，需要提供iterator对其进行送代，
###### 数据结构
```go
type pedingWritesIterator struct {
	entries []*utils.Entry
	nextIdx int
	readTs uint64
}
```
到此为止，我们需要的送代器要负责送代三个部分的数据 
1.当前事务写入的
2.内存中的 
3.磁盘中的
而pendingWriteslterator的核心逻辑如下：
```go
func (pi *pendingWritesIterator) Seek(key []byte) {
	key = utils.ParseKey(key)
	pi.nextIdx = sort.Search(len(pi.entries), func(idx int) bool {
		cmp := bytes.Compare(pi.entries[idx].Key, key)
		return cmp <=0
	})
}
```
##### 事务管理
事务管理模块负责授时（生成逻辑时间戳）、事务状态记录、事务清理、冲突检测等。
###### 数据结构
```go
type TxnManager struct {
	sync.Mutex
	nextTxnTs uint64
}
```

```go
type Txn struct {
	readTs uint64
	commitTs uint64
	db *DB
	
	reads []uint64
	doneRead bool
	
	pendingWrites map[string]*utils.Entry
}
```
获取读取时间戳，就是实现一个单调递增的计数器
```go
func (m *TxnManager) ReadTs() uint64 {
	var ReadTs uint64
	m.Lock()
	readTs = m.nextTxnTs-1
	m.Unlock()
	return readTs
}
```
##### 冲突检测
在事务管理模块中，会记录所有已经提交的事务，如果当前事务管理模块中所有已提交的事务时间戳都小于当前事务的读取时间截，此刻认为没有冲突。
如果存在事务，提交的时间截比当前事务的读取时间截要天，则需要进行下一步检测
在每个已提交的事务中，会记录该事务修改的Key列表，如果Key列表中存在要读取的Key，则说明要读取的Key被其他事务修改，此时即认为存在冲突。
![](KV%E5%AD%98%E5%82%A8/attachments/5d557126eea7353908767928be423642_MD5.jpeg)
#### 代码实现
当我们有了以上的工具组件以后，我们就可以按照SnapshotlsolationDemo的思路来实现快照读
快照读操作
	a.初始化一个事务txn
		1.初始化pendingWrites字段，用来暂存该事务内的所有写入操作 
		2.完成事务starttimestamp授时
			a.调用txn_manager，将时间戳字段递增。
	b.读取数据
		i.调用txn的Get方法
			1.先从pendingWrites当中查找，如果找到直接返回，因为pendingWrite当中是最新的数据。
			2.如果pendingWrites当中没有找到，则调用db的Get方法。对于Get方法而言，需要传入带时间戳的Key，时间戳应为该事务的starttimestamp 
			3．提交事务
				a.如果该事务中没有写操作，则直接返回
				b.进行冲突检测，如果读取的Key中被其他事务修改，则返回ErrConflict

#### 场景分析
1：当前事务有写有读，前面写入的数据，会被后面的读取操作读到吗？
会的。因为当前事务写入操作都暂存在pendingWrites当中，在读取操作时会遍历pendingWrites，可以保证前面写入的数据被读到。
2．其他事务先进行写操作，当前事务进行读操作，如何保证当前事务不会读到其他事务未提交的数据？首先，只有事务提交后的数据，才能写入memtable和SsT文件中，未提交的数据都暂存在事务的pendingWrite当中，而pendingWrites只能被当前事务自己可见。 
3.当前先进行读操作，其他事务进行写操作，但未提交
首先，只有事务提交后的数据，才能写入memtable和SsT文件中，未提交的数据都暂存在事务的
pendingWrite当中，而pendingWrites只能被当前事务自己可见。 
4.其他事务先执行写，且已经提交
其他事务已经提交的数据，会写入Memtable中，当前事务一定可以读到。
### Lesson14 并发写
#### OverView
在上一节课的讲解中，我们已经实现了快照读，核心的思路是，在启动读取事务的时候，获取一个 Start时间戳，当前读取事务能读到的内容包括：所有已经提交的事务以及当前事务写入的内容。
CoreKV实现了SerializableSnapshot隔离级别（简称ssl）的乐观并发控制的事务，相比Snapshot隔离级别（简称Sl），SSI除了跟踪写操作进行冲突检测，也会对事务中的读操作进行跟踪，在Commit时进行冲突检查，当前事务读取过的数据，如果在事务执行的期间被其他事务修改过，则会提交失败：
![](KV%E5%AD%98%E5%82%A8/attachments/cafecd577cbd5149211a5963776c453b_MD5.jpeg)
#### 事务的生命周期
乐观并发控制事务的生命周期大致上分为四段，获取时间戳、跟踪读写、提交、请理：
- 事务启动：获取事务开始时刻的授时
- 事务过程：跟踪事务的读写操作涉及到的key，事务期间读操作按启动时刻的快照为准，事务中的写入内容在内存中暂存
- 事务提交：根据事务中跟踪的key进行冲突检测，获取事务提交时刻的授时，使写入生效
- 清理旧事务：当活跃的事务完成后，可以使已经不再需要的快照数据、冲突检测数据等事务相关数据得到释放
为了管理事务的生命周期，需要为每个事务和全局层面记录两部分元信息：
- 每个事务层面，需要记录自己读写的key列表，以及事务的开始时间戳和提交时间戳截，这部分信息维护在Txn结构体中
- 全局层面，需要管理全局时间截，以及最近提交的事务列表，用于在新的事务提交中对事务开始与提交时间戳中间提交过的事务范围进行冲突检查，乃至当前活跃的事务的最小时间戳，用于清理旧事务信息，这部分信息维护在oracle结构体中
这里授时得到的时间戳并非物理时间，而是逻辑上的：所有的数据变化均来自事务提交的时刻，因此仅当事务提交时使时间戳递增。
![](KV%E5%AD%98%E5%82%A8/attachments/4ba8ace21fe049078856f40f00dde27d_MD5.jpeg)
以上面的图为例，事务1在提交时需要与事务2和事务3进行冲突检测，因为事务2和事务3的提交时间位于事务1的开始与提交之间，事务2和事务3写入的key如果与事务1读写的key列表存在重叠，则认为存在冲突。

根据上面的描述，我们需要实现如下的功能
1.事务管理器需要管理活跃中的事务，并且需要负责清理过期的事务。 
2．事务管理器需要提供所有事务注册的接口，事务提交时的通知接口 
3：事务管理器需要检测事务之间的冲突

#### 事务开始
启动一个新事务的入口在db.newTransactionO函数。这个函数比较简单，除了初始化几个字段，唯一有行为语义的部分就是txn.readTs=db.orc.readTs（）这一行申请授时的地方了。
看一下readTs函数的实现
```go
func (o *oracle) readTs() uint64 {
	var readTs uint64
	o.Lock()
	readTs = o.nextTxnTs - 1
	o.readMark.Begin(readTs)
	o.Unlock()
	y.Check(o.txnMark.WaitForMark(context.Background(), readTs))
	return readTs
}
```
授时的逻辑很简单，直接复制来自oracle对象的nextTxnTs字段中记录的当前时间戳即可。这里的当前时间载，指的是当前系统中最新的已经分配的一个时间截。
这里有一个细节，前面提到时间截的递增发生于事务的提交，会存在一个时间截递增了但写入仍未落盘的时间窗口，导致事务在这时开始的话，会读到旧数据而非时间截载后的快照。解决办法就是后动事务前，先等待当前时间截的事务完成写入。
那么这里具体是怎么做的呢?
找们要把当前事务的时间载传递给事务管理器，由事务管理器判断，这个时间戴之前的事务是否已经全部被提交了。检测完成的结果，需要通知给当前事务，以便当前事务继续进行操作。这里的核心逻辑在WaitForMarker。
传递过去的事务D进行检测后有两种结果，一种是当前的事务D已经完成，一种是当前的事务D还没有完成落盘。没有完成落盘的，就不会通知给发出检测请求的事务，对应的事务也就会一直阻塞下去。
检测是如何进行的？通过上面的描述我们知道，可能同时存在多个事务等待某个事务完成，并且这些事务的channel都被放到了被等待事务的通知者列表中。同时，在Pending数组中，我们还需要记录事务ID有多少个。这是因为事务ID的递增只发生在Commit的时候，如果同一时刻多个事务开始但都未Commit，那么事务ID将会是同一个。
txnMark学段是WaterMark结构体类型，它内部会维护一个堆数据结构，可以用于跟踪事务的时间截区段的变化通知。
除了基于txnMark等待当前时间截相关的事务完成写入，readTs函数中还有一行o.readMark.Begin(readTs）。readMark与txnMark一样是一个WaterMark结构体，但它没有利用 WaterMark结构体等待点位的能力，只利用它的堆数据结构来跟踪当前活跃的事务的时间戳范围，用于找出哪些事务可以过期回收。
WaterMarker是如何跟踪当前活跃的事务的时间截范围的，首先WaterMarker需要知道全局活跃的事务列表，那就需要在任何一个事务开始时都WaterMarker注册，在事务结束时，需要回 WaterMarker通知，WaterMarker会移除已完成的事务。
由于事务的完成一定是按照时间戳顺序的，所以我们使用堆来进行事务的排序，在事务时间戳从小到大遍历的过程中，如果发现有某个事务未完成，后面的事务也就不需要看了。

#### 事务执行
事务执行期间，写入会暂存在内存的pendingWrites缓冲中。
事务期间的读取操作会首先读取pendingWrites缓冲，随后再读取LSMTree内的数据。CoreKV继承了leveldb中iterator组合的思想，把pendingWrites的读取链路封装为了Iterator，并与 MemTablelterator、Tablelterator等Iterator通过Mergelterator组合为最终的Iterator：
![](KV%E5%AD%98%E5%82%A8/attachments/ab95fe9183be7b2f9e291f586b9b1a3c_MD5.jpeg)
CoreKV会将commitTs作为key的后缀存储到LSMTree中，Iterator在送代中也会对时间截有感知，按readTs时刻的快照数据进行选代。这里与leveldb的sequence号与Snapshot的选代行为是致的。

#### 写偏序问题
![](KV%E5%AD%98%E5%82%A8/attachments/876a14704cd413e21cc9ac247e10243e_MD5.jpeg)
想象一下这个例子：你正在为医院写一个医生轮班管理程序。医院通常会同时要求几位医生待命，但底线是至少有一位医生在待命。医生可以放弃他们的班次（例如，如果他们自己生病了），只要至少有一个同事在这一班中继续工作。
现在想象一下，Alice和Bob是两位值班医生。两人都感到不适，所以他们都决定请假。不幸的是，他们恰好在同一时间点击按钮下班。
在两个事务中，应用首先检查是否有两个或以上的医生正在值班；如果是的话，它就假定一名医生口以安全地保班。由于数据库使用快照隔离，两次检查都返回2，所以两个事务都进入下一个阶段。
Aice更新直已的记录保班了，而Bob也做了一样的事情。两个事务都成功提交了，现在没有医生值现了。违反了至少有一名医生在值班的要求。
这种异常称为==写偏序==。它既不是==脏写==，也不是==丢失更新==，因为这两个事务正在更新两个不同的对象（Alice和Bob各自的待命记录）。在这里发生的冲突并不是那么明显，但是这显然是一个竞争条件：如果两个事务一个接一个地运行，那么第二个医生就不能歇班了。异常行为只有在事务并发进行时才有可能。
可以将写偏序视为丢失更新问题的一般化。如果两个事务读取相同的对象，然后更新其中一些对象（不同的事务可能更新不同的对象），则可能发生写偏序。在多个事务更新同一个对象的特殊情况下，就会发生脏写或丢失更新（取决于时机）。那么corekv解决了这个问题吗？
我们观察到问题原因出自这里：事务从数据库读取一些数据，检查查询的结果，并根据它看到的结果决定采取一些操作（写入数据库）。但是，在快照隔离的情况下，原始查询的结果在事务提交时可能不再是最新的，因为数据可能在同一时间被修改。
换句话说，事务基于一个**前提**（premise）采取行动（事务开始时候的事实，例如：自前有两名医生正在值班”）。之后当事务要提交时，原始数据可能已经改变一一前提可能不再成立。
当应用程序进行查询时（例如，“当前有多少医生正在值班？”），数据库不知道应用逻辑如何使用该查询结果。在这种情况下为了安全，数据库需要假设任何对该结果集的变更都可能会使该事务中的写入变得无效。换而言之，事务中的查询与写入可能存在因果依赖。为了提供可序列化的隔离级别，如果事务在过时的前提下执行操作，数据库必须能检测到这种情况，并中止事务。数据库如何知道查询结果是否可能已经改变？有两种情况需要考虑：
- 检测对日MVCC对象版本的读取（读之前存在末提交的写入
- 检测影响先前读取的写入（读之后发生写入）
那么我们只需要在CoreKV的事务提交逻辑中，增加检测当前事务写入的Kev有没有被其他事务修改过即可。这就需要我们追踪读取的Key和写入的Key，而上文中我们已经完成了这一逻辑。

#### 事务提交
事务的提交入口位于Commit(）函数，它调用的commitAndSend(函数是逻辑的主体。大致上的过程包括：
	1.通过orc.newCommitTs(txn）进行事务冲突检测，如果无冲突，获取授时commitTs
	2.循环为pendingWrites和duplicateWrites中的Entry的version绑定commitTs，并使存储的key定commitTs
	3.调用txn.db.sendToWritech(entries）使写入缓冲进入落盘写入
	4.等待落盘完成后，通知orc.doneCommit(commitTs)，移动txnMark的点位
newcommitTs内部会发起冲突检测和过期事务清理，并使事务跟踪到commitedTxns中：
![](KV%E5%AD%98%E5%82%A8/attachments/52195ddae0ccfeb42717308b8c099fb8_MD5.jpeg)
其中冲突检测的逻辑很简单，遍历committedTxns，找出当前事务开始之后提交的事务，判断自己读到的key中，是否存在于其他事务的写列表中：
![](KV%E5%AD%98%E5%82%A8/attachments/93ade572c35dcd1b1e24b9f8aec09791_MD5.jpeg)

#### 事务清理
前面提到事务在提交时会结合committedTxns数组中的信息，进行冲突检测。committedTxns数组记录近期的已提交事务的信息，显然是不能无限增长的。那么何时可以对committedTxns数组进行清理呢？标准就是最早的活跃的事务的开始时间戳，如果历史事务的提交时间戳早于当前活跃事务的开始时间戳，冲突检查时就不需要考虑它了，也就可以在committedTxns中回收它了。
![](KV%E5%AD%98%E5%82%A8/attachments/cc34f5f497c4562c496d636dca77e86c_MD5.jpeg)
![](KV%E5%AD%98%E5%82%A8/attachments/872e448a5a7cd9d80286e36e0356c788_MD5.jpeg)
oracle会记录lastcleanupTs记录上次清理的时间戳，避免不必要的清理操作。

#### 总结
- CorekV中与事务相关的结构体包括Txn和oracle两个，Txn内部的信息主要是开始时间载、提交时间截、读写的key列表，oracle相当于事务管理器，内部维护近期提交的事务列表、全局时间戳、当前活跃事务的最早时间戳截等。
- 事务时间戳截是逻辑时间截，每次事务提交时递增1。
- SSI事务中冲突探测的逻辑就是，找出在当前事务执行期间Commit的事务列表，检查当前事务读取的key列表是否与这些事务的写入的key列表有重叠。
- WaterMark结构体内部是个堆，用于管理、查找事务开始、结束的区段。oracle的txnMarker主要用子协调等待commit授时与落盘的时间窗口，readMarker管理当前活跌事务的最早时间载，用于清理过期的committedTxns。

### Lesson15 HotRing论文整体解读 & 无锁LinkedList实现
#### Backgroud
##### 零点峰值
2019年天猫双11再次刷新世界纪录，零点的订单峰值达到54.4万笔/秒。有订单就涉及到交易，有交易就需要数据库的事务保证，因此阿里巴巴数据库将在这时面临巨大的冲击。
现实往往更加严峻，在业务方面，一次订单随着业务逻辑在后端会放大为数十次的访问；在客户方面大量的客户只是疯狂的访，并没有生成订单。因此，在双11的零点峰值，业务实际的访问同量级是10亿次秒。
Tair作为高并发分布式的KVS系统，在这时发挥了重要作用。如下面的逻辑图所示，Tair作为数据库的分布式缓存系统，缓存了大量的热点数据（例如商品，库存，风控信息等），为数据库抵挡了巨大的访问量。2019年双11，Tair的峰值访同为9.92亿次秒
![](KV%E5%AD%98%E5%82%A8/attachments/54c6ca10ce50e9907b0b3b32855853f9_MD5.jpeg)
##### 热点问题
在业务层面，热点问题很好理解，最典型的就是双十一零点秒杀。这会导致数据访问呈现严重倾斜的幕律分布。
我们分析了多种业务的数据访问分布，如下图所示，大量的数据访问只集中在少部分的热点数据中，若用离散幕率分布(Zipfian)刻画，其e参数约为1.22。相似地，Facebook的一篇论文同样也展示了近似的数据访问分布。
![](KV%E5%AD%98%E5%82%A8/attachments/04132693dac35313f6141b120ed04075_MD5.jpeg)
直观上可以用下图来解释。以苹果新手机发售举例手机的库存等信息只存在KVS的一个节点中。当新手机发售后：大量的果粉疯狂进行抢购下单，业务的访问量基本都聚集在这一入节点上。节点可能无法承载大量的热点访问，进而引发系统崩溃，严重影响用户体验。
![](KV%E5%AD%98%E5%82%A8/attachments/a68c78fde266a81ad0862191d13a388f_MD5.jpeg)

#### HotRing
##### 现有技术
现有的内存KVS引擎通常采用链式哈希作为索引，结构如下图所示。首先，根据数据的键值（k)计算其哈希值h(k)，对应到哈希表（Hashtable)的某个头指针(Headi)。根据头指针遍历相应的冲突链(Collision Chain)的所有数据(item)，通过键值比较，找到自标数据。如果自标数据不在冲突链中(readmiss)，则可在冲突链头部插入该数据。
![](KV%E5%AD%98%E5%82%A8/attachments/b247a4d82a0d5355a74d340c44e5666a_MD5.jpeg)
在链式哈希索引结构中，访同位于冲突链尾部的数据，需要经过更多的索引跳挑数，即更多次的内存访问。很直观的想法是，如果可以将热点数据放置在冲突链头部，那么系统对于热点数据的访问将会有更快的响应速度。
但是，数据在冲突链中的位置由数据的插入顺序决定，这和数据的冷热程度是互相独立的。因此，如图所示，热点数据(Hotitem)在冲突链中的位置是完全均匀分布。
假设共有N个数据，哈希表Bucket数自是B，数据均匀分布，那么冲突链的长度是N/B，每次访问的平均访存次数是E=1+L/2=1+N/(2B)，1表示一次bucket查找。
##### 设计挑战
理想的设计也很直观，就是将所有热点数据移动到冲突链的头部。但有两方面因素便得这个问题非常难解。一方面，数据的热度是动态变化的，必须实现动态的热点感知保证热点时效性。另一方面，内存KVS的引擎性能是很敏感的(一次访问的时延通常是10OnS量级），必须实现无锁的热点感知维持引擎的高并发与高春吐特性。
##### HotRing设计
针对上面的2点设计挑战，HotRing采用有序环+动态识别与调整解决第一个挑战，采用无锁并发访问+适应热点数据量的无锁rehash解决第二个挑战。
###### 有序环
实现环式哈希索引后，第一个问题是要保证查询的正确性。若为无序环，当一个readmiss操作遍历冲突环时，它需要一个标志来判断遍历时终正，否则会形式死循环。但是在环上，所有数据都会动态变化（更新或删除)，头指针同样也会动态移动，没有标志可以作为遍历的终止判断。
利用key排序可以解决这个问题，若自标key介于连续两个item的key之间，说明为readmiss操作，即可终止返回。由于实际系统中，数据key的大小通常为10100B，比较会带来巨大的开销。哈希结构利用 tag来减少key的比较开销。
如下图所示，tag是哈希值的一部分，每个key计算的哈希值，前k位用来哈希表的定位，后n-k位作为冲突链中进一步区分key的标志。为了减小排序开销，我们构建字典序：order=(tag，key)。先根据tag进行排序，tag相同再根据key进行排序。
![](KV%E5%AD%98%E5%82%A8/attachments/49f0c919b7bde8a584d28ef8686c9026_MD5.jpeg)
下图比较了HotRing与传统链式哈希。以itemB举例，链式哈希需要遍历所有数据才能返回readmiss。而 HotRing在访问itemA与c后，即可确认Breadmiss。因此针对readmiss操作，链式哈希需要遍历整个冲突链；而HotRing利用字典序，不仅可以正确终止，且平均只需追历1/2冲突环。
![](KV%E5%AD%98%E5%82%A8/attachments/3c117f3742ca21e62ed83b64ab39bc3b_MD5.jpeg)
###### 动态识别与调整
这里说的是能够快速识别到热点变化，并且能够快速调整HeadPointer。HotRing实现了两种策略来实现周期性的热点识别与调整。每R次访同为一个周期R通常设置为5，第R次访问的线程将进行头指针的调整。两种策略如下：
- 随机移动策略
每R次访问，移动头指针指向第R次访问的item。若已经指向该item，则头指针不移动。该策略的优势是，不需要额外的元数据开销，且不需要采样过程，响应速度极快。当第R次访问的是hotaccess时， HeadPointer不需要移动；当第R次访问的是coldaccess时，HeadPointer将指向冷数据，会影响后续访问性能。该种策略在热点数据高度集中时非常有效，否则会带来热点识别非常不准确的问题，Head Pointer频繁摇摆。
- 采样分析策略
每R次访问，尝试启动对应冲突环的采样，统计item的访问频率。若第R次访问的item已经是头指针指向的item，则不启动采样。启动采样时要将Active位置1，采样次数设置成冲突链长度。
采样所需的元数据结构如下图所示，分别在头指针处设置TotalCounter，记录该环的访问总次数，每个 item设置counter记录该item的访问次数。因为内存指针需要分配64bits，但实际系统地址索引只使用其中的48bits。我们使用剩余16bits设置标志位（例如TotalCounter、Counter等），保证不会增加额外的元数据开销。该策略的优势是，通过采样分析，可以计算选出最优的头指针位置，稳态时性能表现更优。
![](KV%E5%AD%98%E5%82%A8/attachments/149fc89b5c8db6e061c3572d72a38c21_MD5.jpeg)
1. 采样分析策略如何选出最优位置？
采样结束后，最后访问的线程先将Active位清零，并负责频率计算以及热点调整。假设TotalCounter是 N，第k个数据的Counter是nk，则第k个数据的访问频率是nk/N。然后通过下面的公式计算将热点调整到每一个节点上得到的收益，再将HeadPointer移到得到最大收益的节点上。HeaderPointer的最佳位置可能并不是hotnode的位置，例如有多个热点。
![](KV%E5%AD%98%E5%82%A8/attachments/4b3b0886e7735709fff2f34d6b84887a_MD5.jpeg)
2. 如何针对更新操作的采样优化？
HotRing的更新分2种，1种是value小于=8B，直接在原节点原子更新；另一种是超过8B，采用RCU(Read-Copy-Update）更新。若让HeadPointer指向write-intensivehotitem，而HotRing采用的是单向循环链表，在采用RCU更新时，需要遍历整个冲突环才能找到该节点的前驱节点。所以，对于RCU 更新，采用的是自增其前驱节点的counter，而不是该节点的counter，让算法认为其前驱节点是热点。
> 现代CPU支持最多8字节的原子操作(CAS)，所以小于等于8B的数据直接可以CAS；大于8B的必须创建新节点RCU更新。
> **COW 是一种通用的资源优化策略（“懒”原则），而 RCU 是 Linux 内核中一种具体的同步机制（并发控制）。RCU 在实现“更新”逻辑时，正是利用了 COW 的思想。**
![](KV%E5%AD%98%E5%82%A8/attachments/2a680dcb75215354ef0a3191b4c82fb5_MD5.jpeg)
3. 热点继承防止冷启动
RCU更新的节点或者删除的节点正好是HeadPointer指向的节点，前者让HeaderPointer重新指向该节点的新版本，后者则让HeadPointer指向其下一个节点。而不是随机指向一个新节点，防止得到的新节点是cold node。
##### 无锁并发访问
- Read
没有任何需要加锁的地方，直接遍历即可。
- Insert
写节点需要让他的前驱节点指向新插入的节点，需要保证他的前驱节点是有效的，然后cas保证只会有一个插入成功，另一个需要重新插入。
- Update
考虑下图的情况，在链A->B->D上，线程1进行插入C的操作，同时线程2进行RCU更新B的操作，尝试更新为B。线程1修改B的指针指向C，完成插入。而线程2修改A的指针指向B完成更新。两个线程并发修改不同的内存，均可成功返回。但是这时遍历整条链(A->B‘->D)，将发现C无法被遍历到，导致正确性问题。
![](KV%E5%AD%98%E5%82%A8/attachments/d3806b4fc6fb31d94fb695d8b477b101_MD5.jpeg)
解决措施是利用上图(ItemFormat)中的Occupied标志位。当线程2更新B时，首先需要将B的Occupied 标志位置位。线程1插入C需要修改B的指针(NextItemAddress)，若发现Occupied标志位已置位，则需要重新遍历链表，尝试插入。通过使并发操作竞争修改同一内存地址，保证并发操作的止确性。
- Delete
考虑下图的情况，在链A->B->D->E上，线程1进行删除B的操作，同时线程2进行RCU更新D的操作，尝试更新为D'。线程1修改A的指针指向D，完成删除。而线程2修改B的指针指向D完成更新。两个线程并发修改不同的内存，均可成功返回。但是这时遍历整条链(A->D->E)，将发现D'无法被遍历到，导致正确性问题。
![](KV%E5%AD%98%E5%82%A8/attachments/70e30f75b7dda6db57f816a2918a315c_MD5.jpeg)
解决措施是让线程1在删除B之前将Occupied标志位置1，那么后续线程2在更新B的指针指向D'时将会失败。
- Head Pointer Movement
存在2个主要问题，1）如何处理由热点识别带来的HeadPointerMovement和NormalOperation的并发问题？2）如何处理Update/DeleteHeadItem引起的HeadPointerMovement并发问题？
问题1的解决办法是，在移动之前，先将自标节点的Occupied置1，来保证在此期间该节点不会被删除或者修改，结束后清0。
问题2的解决办法是，对于RCU更新后得到的新版本，先置新版本节点的Occupied标志位1，结束后清 O。若是删除headitem，则要同时锁定被删除的节点以及该节点的下一个节点。
 
#### 无锁LinkedList
使用golang unsafe包实现无锁链表
数据结构
```go
type node struct {
	Pointer unsafe.Pointer
	value interface{}
}
```
Golang的原子操作
```go
func LoadPointer(addr *unsafe.Pointer) (val unsafe.Pointer)
func StorePointer(addr *unsafe.Pointer, val unsafe.Pointer)
func CompareAndSwapPointer(addr *unsafe.POinter, old, new unsafe.Pointer) (swapped bool) 
```
接下来我们用这些基本操作实现一个无锁的LinkedList，我们给链表实现Pop和Push方法，并且采用头插法插入链表。
上述代码为在链表中通过头插法，在链表头部追加新节点的操作。三个参数分别代表要插入的数据、新的链表节点、在before节点前插入新节点。
在这里要特别提一句atomic.CompareAndSwapPointer（&self.Pointer，unsafe.Pointer（before），unsafe.Pointer（newElement），这里的self.Pointer是
unsafe.Pointer类型，语义是这个变量可以存储一个指针变量，他的具体的值就是before节点、或者新插入的节点的内存指针地址。CompareAndSwapPointer这个方法要求第一个参数必须为指针，因此对self.Pointer进行了取指运算。整个语句的语义解释为：在self.Pointer的内存地址上，将其内存地划存储的内容电原内容，修改为新节点的内存地址。

### Lesson16 实现Ring的数据结构
HotRing本身就是一个典型的HashMap结构，正如八股文中经常问到的Java中的HashMap一样，由一个 HashTable和链表组成。
我们先来看一个最简单的HashTable，我们应该如何用Go来实现。
#### HashMap
HashMap最简单的数据结构就是数组+链表
关键数据结构
```go
type Entry struct {
	key int,
	val string,
	next *Entry
}
```
Entry用来保存Key-Value对，,以及指向下一个Entry的指针，他描述HashMap中的每一个节点。
```go
type HashMap struct {
	size int,
	buckets []*Enrty
}
```
HashMap是整个hashmap的实现，他描述整个map的天小，用Entry类型的切片来实现
第一步，我们创建一个数组，存储的数据就是HashTable中的节点。
第二步，当我们需要插入数据的时候，现对数据进行一次Hash，然后对整个链表长度取余，定位到对应的数组位置。
第三步，处理Hash冲突。当产生Hash冲突时，我们将冲突数据按照链表的方式挂在后面
第四步，实现查找逻辑。查找逻辑是插入逻辑的简化和逆向。

#### 环状结构的实现
HashTable用来快速定位，链表用来处理Hash冲突。而在HotRing中有一点不同，它将链表处理成了环状结构使用环状结构的好处在于：可以方便的移动HeadPointer指向任意一个节点，避免查找时必须从链表的头部开始。
而便用环装数据结构必须要注意，环中所有的数据必须是有序的，这是因为，普通的单链表可以很方便的判断出结尾(Node.next\==nil)，而对于环中的每一个数据，每一个节点的Next指针都不为空，就没办法根据这个去判断链表的结束。
##### 判断环状链表结束的方法
当我们去查找一个值的时候，我们把这个值记为SearchKey，先用SearchKey进行Hash，然后定位到在Table中的位置，也就是它可能会在哪一个环形链表上。
当定位到环形链表上以后，我们需要掌到这个环形链表的头指针。并且从头结点开始遍历查找。
而环形链表中可能有N种情况 
	1、链表中没有任何一个节点 
	2、链表中只有一个节点
	3、链表中有N个节点(N>=2）
前两种情况我们很容易判断要查找的数据在不在链表中，而对手第三种情况，则又可以进行分类讨论。
如果我们按照环形链表是按照从小到大的节点顺序进行排序，那么一般情况下我们默认前驱节点是<后续节点的。但是在环中也会有特殊情况，就是在环形链表结尾的地方，前驱节点会>后续节点。而这一个特殊的地方，也就是我们代码要做文章的地方。
当Node.key<node.next.key时
如果要查找的值在头结点和Next节点之间，则说明该值不存在，可以不用继续查找了。
当Node.key>node.next.key时，说明此时已经找到了尾部。
如果要查找的值还不再Node和Node.next之间，说明该值不存在，可以直接返回。
![](KV%E5%AD%98%E5%82%A8/attachments/a682df999a47dddf08c2cf29b071697a_MD5.jpeg)

##### 头指针的数据结构与移动
头指针的设计，能够指向任意节点，同时要方便移动。
```go
// HeadPointer 头指针的构成
type HeadPointer struct {
	incBase uint32
	node *Node
}
```
如上述代码所见，买指针当中包含一个指回某一Node的指针，另外一个字段incBase是用来递增的倍数有了头指针的结构，那么将头指针指向某一个节点的方法SetHead就很好实现了。

##### 计数
计数的作用
在HotRing的论文中，我们知道在真实的业务中，热点是不停在变换的，为了保证HotRIng持续的高效查找，我们必须随时转移热点，也就是头指针的转向。如何保证的头节点新指向的头指针为热点数据，论文当中提到了两入方法随机法和采样法。
无论是随机法还是采样法，我们都需要统计一些数据来作为我们判断下一步标准的参考。因为计数的需求就出现了。需要几个计数？
我们至少需要两个数据，一个是宏观上的，整体对于整个HotRing环的访同数据统计；还有一个是针对每一个环中每一个单项数据的访问频次统计，用来标记环中每一个单项节点的访问频率。
因此我们对于HeadPoniter和HotRingEntry都各自实现一个incCounter方法。

### Lesson17 有锁HotRing的实现
#### 前言
在上一节课程中，我们实现了HotRing中Ring的数据结构，为后续的整体的模块实现了最基本的数据结构。在本节课中，我们尝试去实现HotRing的基本APl，包括增删改查。
在这节课中，我们先来实现一个有锁的基础版本，便于理解和编写代码的逻辑，在后面的课程中，我们会改造 HotRing为一个完全无锁的数据结构。

#### Search
HashMap的查找+HotRing的查找，构成了这一段代码的核心逻辑。但是关下武功，唯快不破，我们在这重要做的是：加快查找过程。
若环状链表数据没有任何顺序，确认item不存在的复杂度为O(n），从时间效率上看可以再优化。HotRing选择在写入
时略微增加开销，让环状链表保持顺序性，从而查找时就能更快定位或结束遍历。
对于自标元素item（k）结束查找的标志可以是：
item存在，则满足：
`item(k)=item(i)`
若不满足上式，且满足下列任一条件时，说明item不存在：
```
item(i-1) < item(k) < item(i) 
item(k) < item(i) < item(i-1)
item(i) < item(i-1) < item(k)
```
![](KV%E5%AD%98%E5%82%A8/attachments/6977881434b806da5993430f6c49582f_MD5.jpeg)
而为了减少对字符串的字典序比较，HotRing为每个item都增加了一个tag，即item（k）=（tag（k）， key(k))。
这个Tag到底怎么用呢，他怎么减少的字符串的比较？
举个例子，我们将学符串Key计算出来一个Hash值，其中前8位用来定位在HotRing中的位置，后8位用来比较Hash冲突后的Key。如果没有这种机制，那么我们假如要查找abcdefghijklmn这段Key，在Ring中存储的Key为abcdefghijklmq的话，按照字符串比较需要比较15次才可以。但如果我们直接用HashTag来比较，那么正常情况下，比较1、2次就有了结果。
通过这种设计，无需遍历链表中所有元素即可提前终止遍历，平均情况下查找item数可以达到（n/2）+1。实际上，因为头部指针位置的优化，天多数查找能够更早定位到hot item而结束。

#### Insert
插入数据的过程和查找基本一致，直先需要查找到新插入的数据应该存在的位置，然后执行链表的插入操作

#### Remove
删除操作有一丢丢不同，关键还是在于查找环中元素的条件判断
首先使用该Key在HotRing中查找节点，如果没有查找到，则直接返回，说明该节点已经被删除
如果查找到了该节点，则需要链表的删除操作。
![](KV%E5%AD%98%E5%82%A8/attachments/07e161dd5e1d0e591cc0b3c4a038529a_MD5.jpeg)
这样操作会不会有什么间题？
也许称会问如果节点为空，调用空指针的Next()方法岂不是会报错？但是这个问题已经在上述操作中被排除了，因为节点为空的话，查找节点的结果将会返回不存在，在上述逻辑中已经返回了。
也许环中只有一个节点，这样使用PrevNode.next指向ToBeDeletedNode.next会形成死循环，始终还是指向环中的唯一个节点。
对，这里我们需要特殊判断：当环中只有一个节点的时候，该冲突环在Map中的头结点应该置为空。

#### Update
这个操作比较简单，只需要查找到对应的数据，然后修改其Value即可。
但是有一点需要注意的是，新更新的值在近期很容易被天量访问（问就是经验），所以我们把这个节点设置为热节点。

### Lesson18 无锁HotRing实现（一）
#### 介绍
我们用两节课实现一个无锁的HotRing。第一节课，我们尝试实现一个基础的无锁HashMap数据结构，在这个过程中，我们会运用指针、CAS操作，通过第一节课，大家可以掌握无锁操作的开发要点。

#### 设计思路
![](KV%E5%AD%98%E5%82%A8/attachments/1bb134261b7e65bdbcb2ac14fe56f56a_MD5.jpeg)
传统的HashMap是使用HashTable+List来实现，当然我们的无锁HashMap也是运用相同的思路。大家都知道朴素的 HashMap是不支持并发操作的，这是因为补素的HashMap采用的是普通的LinkedList，在多线程的操作环境下，链表指针的修改会发生非预期的现象（至于是什么现象那就太太太基础了，不知道的麻烦去Google）。典型的线程安全的 HashMap实现思路是加一把大锁，或者实现为分段加锁，通过减少锁粒度的情况来降低锁冲突，从而尽可能的提高性能。
通过上述的简略分析，我们知道想实现一个无锁的HashMap，核心就是实现一个无锁的LinkedList，也就是我们最开始的几节课提到的，这里我们考虑如何结合无锁LinkedList，来实现一个整体的HashMap。
尝试使用无锁链表来实现HashMap，要模拟两个步骤：
1. 定位Bucket
依然是取余定位
2. 链表内的查找
无锁链表，需要实现一个有序的链表。
为什么需要实现为一个有序的链表，如果直接采用头插法或者尾插法插入链表头部或者尾部的话，会产生大量的冲突。CAS操作虽然是无锁操作，但仍然会自旋等待操作的完成，如果冲突太多，就会产生空耗。如果我们采用有序链表，每个数据都会有其应该插入的位置，可以减少冲突的可能性。

#### 实现
##### 定位操作
在这里我们需要先介绍一个前置知识，这是一个非常基础的前置知识，即数组的访问方法：数组元素可以通过下标访
问，也可以通过指针运算访问。指针访问是直接计算出来该数组的第N个元素对应的内存位置，也就是， ArrayPointer+N\*ElementSize。
查找元素的过程似乎很简单，不过这里我们直先要解决两个问题，首地址怎么确定？每个元素的天小怎么确定？
这里文涉及到Golang的知识点，取slice的地址：
> 首先，我们声明一个slice，slice的数据结构
> 我们使用一个Golang自带的SliceHeader，来指代一个slice，方便我们取用这个Slice
> SliceHeader如其名，Slice+Header，看上去很直观，实际上他是GoSlice（切片）的运行时表现。 sliceHeader的定义如下:
> type SliceHeader struct {
> 	Data uintptr
> 	Len int
> 	Cap int
> }
> - Data：指向具体的底层数组
> - Len：切片的长度
> - Cap：切片的容量

具体如何取Slice的首地址？
![](KV%E5%AD%98%E5%82%A8/attachments/b57c86bdf741a7f5e0b2530d6af0f037_MD5.jpeg)
再来看首地址的长度，既然我们知道了data是个指针类型的数组，而在golang中，指针的内存占用是8Bytes，那么
数组当中每个元素的占用都是8Bytes，我们只需要一个常量来表示就好了。 
intSizeBytes=strconv.IntSize>>3
##### 遍历链表
遍历链表的操作似乎也很简单：读取一个节点，进行比较，如果相等则直接返回，如果不等则比较下一个节点。接下来，我们来看在一个无锁有序的LinkedList当中如何进行操作。

##### 插入链表

### Lesson19 无锁HotRing实现（二）
#### 采样策略
我们都知道HoRing是一个解决内存热点同题的数据结构，那么直先要解决的同题就是谁是热点？从我们人类直观的角度来讲，最经常被访问的那一类数据我们称之为热点，那么在计算机中该如何表示呢？热点数据怎么识别呢？

##### 随机采样
首先我们来介绍一下随机采样。随机采样的策略就是：头指针周期性移动，指向一个新的热点项，这个决定不依赖任可历史元数据。而这个热点项也不一定是真正的热数据
具体实现：
- 使用一个变量，记录该Ring总共执行了多少次请求
- 每隔R个请求，线程决定是否要移动头指针
	- 若第R个请求是访问的就是当前头指针指向的数据（即热数据），头指针不移动。
	- 否则，**头指针移动到第R个请求所在的项上**。
随机采样灵活，容易实现，下面我们来看下代码的具体实现。

随机采样虽然灵活，容易实现。并且在热点比较集中（也就是经常访问某几个Key，且不常变动）的情况下，确实有看很好的效果。但如果热点经常漂移，则会造成热点频繁失效。在排序的HotRing中，可能会使得HashMap性能退化到比朴素的HashMap还要差。
为了解决这种随机漂移的问题，我们引入基于统计数据的统计采样。

##### 统计采样
如何统计访问频次？
###### 索引格式
除了在随机采样中提出的需要统计整个Ring的访问次数以外，还要知道每个节点的访问频次。
环上每一项的RingElement包括： 
- Key
- keyHash 
- Value 
- Tag
- Counter
- nextElement
###### 统计采样
统计采样需要性能开销的，为了降低开销，HotRing的论文中采取了一定的策略，并不是随时开启采样的，而是为了保证识别的准确性以及尽量降低性能消耗，和随机移动一样，周期性地调整：
- 维护一个变量，记录该Ring总共执行了多少次请求。
- 每隔R个请求，决定是否要移动头指针
	- 若第R个请求访问的是热点，则头指针不移动，直不并启采样。
	- 否则，则需要移动头指针，开启统计采样，采样个数也是R
			打开head.active
			后续的请求次数会被记录到head.count和对应的element.count(CAS)
###### 热点调整
基于上一步的统计采样，就可以决定哪一个是头节点，步骤如下：
- 关闭head.active(CAS)
- 遍历环，计算每一项的访问频次
- 计算每个节点的收益
- 使用CAS设置新的头指针
- 重置所有的计数器
上述的操作比较复杂，在我们的实现中，我们采取比较简单的做法：全量的频次统计，并且在移动头结点的时候，我们只选择访问频次最高的节点作为头结点。

#### 热点转移
由于统计采样的热点转移非常简单，即使用一个atomic.CAS操作交换一个热节点即可。所以这里我们只给出基于统计的热点转移算法。

#### Rehash
HotRing支持无锁的rehash操作。而和其它使用负载因子来触发rehash不同，HotRing使用访问开销（即操作平均内存访问次数）来触发rehash。 
HotRing rehash分为3步：
- 初始化
- 分割
- 删除
##### 初始化
首先创建线程，初始化一个2倍大小的散列表。易知，1个环会被拆成2个环，而散列值定位哪个环需要+1位，ta9需要-1位，根据这一位的值（即rehashbit），决定原有环中的项在哪一个新环上：
![](KV%E5%AD%98%E5%82%A8/attachments/e78ad21e8bc29873b46b7009ea42100f_MD5.jpeg)
同时，该线程创建一个rehashnode，里面包含2个rehashchilditem，作为2个新环的头（实际上是个dummy head）。它的格式和dataitem一样，但是tag值分别是o和T/2，代表不同的rehash bit。
![](KV%E5%AD%98%E5%82%A8/attachments/c51513125076940c6bc3e1b8afefeb70_MD5.jpeg)
##### 分割
接下来需要分割原有的环到2个新的环。
线程遍历原有的环，根据rehashbit，将项插入到不同的新环上，插入完毕后就可用了（可访问，可写且可读）。
![](KV%E5%AD%98%E5%82%A8/attachments/cd1641ee032be3c79477ceb99a3383ca_MD5.jpeg)
##### 删除
最后一步，线程将第一步中创建的rehashnode删除。
但在此之前，需要保证旧表上的访问要终止。所有旧表访问结束后，线程会删除旧表和rehashnode。
可知，只有rehash线程会阻塞，其它线程是不会阻塞的。
![](KV%E5%AD%98%E5%82%A8/attachments/7d401a3bdf42862e33d71ed88011de71_MD5.jpeg)





