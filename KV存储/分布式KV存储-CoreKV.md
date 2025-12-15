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

#### LAB：实现vlog文件的编解码
