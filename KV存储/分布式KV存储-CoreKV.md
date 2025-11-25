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

### LAB 实现sst文件
1.功能：初始化，序列化，查询
在一个生产上下文中完成LAB，从整体系统的角度理解SSt组件的应用场景。 
2. 提高
空间压缩，在sst序列化每个block时，对block使用高效的压缩算法，节省内存空间
为工作自录上支件锁，件锁可保证多个进程不会同时操作一个自录
manifest加载sst后就会加载所有sst的index部分，以便用于对大规模数据的存储