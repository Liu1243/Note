> 笔记内容为学习极客时间-MySQL实战45讲

**目录**

- [01 基础架构：一条SQL查询语句是如何执行的？](#01%20%E5%9F%BA%E7%A1%80%E6%9E%B6%E6%9E%84%EF%BC%9A%E4%B8%80%E6%9D%A1SQL%E6%9F%A5%E8%AF%A2%E8%AF%AD%E5%8F%A5%E6%98%AF%E5%A6%82%E4%BD%95%E6%89%A7%E8%A1%8C%E7%9A%84%EF%BC%9F)
- [02 日志系统：一条SQL更新语句是如何执行的？](#02%20%E6%97%A5%E5%BF%97%E7%B3%BB%E7%BB%9F%EF%BC%9A%E4%B8%80%E6%9D%A1SQL%E6%9B%B4%E6%96%B0%E8%AF%AD%E5%8F%A5%E6%98%AF%E5%A6%82%E4%BD%95%E6%89%A7%E8%A1%8C%E7%9A%84%EF%BC%9F)


## 01 基础架构：一条SQL查询语句是如何执行的？
MySQL的基本架构示意图如下图所示：
![](MySQL/attachments/34ac5e67995e7afd46d6dd53414567d9_MD5.jpeg)
大体上，可以分为Server层和存储层两部分。
**Server层**包括连接器、分析器、优化器、执行器以及查询缓存，包括MySQL大多数核心功能，以及所有的内置函数（日期、时间、数字等），所有跨存储引擎的功能都在这一层实现，比如存储过程、触发器以及视图等。
**存储引擎层**负责数据的存储以及提取。架构模式是插件式的，支持innoDB、MyISAM、Memory等多个存储引擎。目前最常用的是InnoDB，从5.5.5版本开始成为默认的存储引擎。
下面是各个组件的作用：
**连接器** 连接器负责跟客户端建立连接、获取权限、维持和管理连接。
连接默认使用长连接，这可能会导致MySQL长时间后内存占用过大，被系统强行Kill，现象来看就是MySQL异常重启。
解决方案：
>1. 定期断开长连接。使用一段时间，或者程序里面判断执行过一个占用内存大的查询后，断开连接，之后要查询再重连。
>2. 如果使用5.7或者更新的版本，可以在每次执行一个比较大的操作后，通过执行mysql_reset_connection来重新初始化连接资源。这个过程不需要重连和做权限验证，但会将连接恢复到刚刚创建完时的状态。

**查询缓存** 是一个保存在内存中，KV形式的缓存
但通常==不建议使用查询缓存==，因为查询缓存弊大于利。
对于更新压力大的数据库来说，查询缓存的命中率非常低；除非是对一个静态表，很长时间才会更新一次，才适合使用查询缓存。
MySQL可以将参数`query_cache_type`设置为DEMAND，这样对于默认的SQL语句都不使用查询缓存，对于确定要使用查询缓存的语句，可以使用SQL_CACHE显式指定
`select SQL_CACHE * from T where ID=10；`
MySQL8.0版本中将查询缓存的整个功能模块都删除了。

**分析器** 包括 *词法分析* 以及 *语法分析*

**优化器** 优化器式在表中有多个索引的情况下，决定使用哪个索引；或者是在一个语句有多表关联（join）的时候，决定表的连接顺序。

**执行器** 执行器用于执行最终优化好的SQL语句。
执行器的执行流程为：
1. 首先判断用户对该表的权限
2. 调用定义的存储引擎的接口获取该表的第一行，判断条件，如果不是则跳过，如果是将该行保存到结果集中
3. 调用引擎结果取“下一行”，重复判断逻辑，直到该表的最后一行
4. 执行器将上述遍历过程中所有满足条件的行组成记录集作为结果集返回给客户端
可以在数据库的慢查询日志中看到`rows_examined`字段，表示语句执行过程中扫描了多少行。在有些场景下，执行器调用一次，在存储引擎内部扫描多行，所以==引擎扫描行数和rows_examined并不是完全相同的==

问题：
> 我给你留一个问题吧，如果表T中没有字段k，而你执行了这个语句 select * from T where k=1, 那肯定是会报“不存在这个列”的错误： “Unknown column ‘k’ in ‘where clause’”。你觉得这个错误是在我们上面提到的哪个阶段报出来的呢？

答案： 语法分析

## 02 日志系统：一条SQL更新语句是如何执行的？
与查询流程不一样的是，更新流程还涉及两个重要的日志模块，`redo log`以及`binlog`。

**重要的日志模块：redo log**
redo log就是MySQL中常说的WAL技术，Write-Ahead Logging，先写日志，在写磁盘，降低了IO成本。
InnoDB中的redo log的大小是固定的，例如可配置为一组4个文件，每个文件大小是1GB，那么总共就可以记录4GB的操作，整个写入是循环写。
![](MySQL/attachments/4bd5f486a6991f6329c87980f03a9c09_MD5.jpeg)
*write pos*是当前记录的位置，*checkpoint*是当前要擦除的位置。
write pos到checkpoint中间的部分可以用来记录新的操作。如果write pos追上checkpoint，则不能执行新的更新，需要推进checkpoint。
有了redo log，InnoDB可以保证即使数据库异常重启，之前的提交不会丢失，这个能力称为*crash-safe*。

**重要的日志模块：binlog**
前面的redo log是InnoDB引擎特有的日志，也就是存储层特有的日志，而server层也有自己的日志binlog。
redo log与bin log的三点不同：
1. redo log是InnoDB引擎特有的；binlog是MySQL的Server层实现的，所有引擎都可以使用
2. redo log是物理日志；bin log是逻辑日志
3. redo log是循环写；bin log是追加写

有了两个日志的概念后，看看执行器和InnoDB引擎在执行update语句的内部流程：
![](MySQL/attachments/906972662855b6d0a857667c1e5e838b_MD5.jpeg)
redo log的写入拆分成为了：prepare和commit，这就是“两阶段提交”。

**两阶段提交**
两阶段提交是为了让两个日志之间的逻辑一致。

**总结**
redo log用于保证crash-safe能力。innodb_flush_log_at_trx_commit这个参数设置成1的时候，表示每次事务的redo log都直接持久化到磁盘。这个参数我建议你设置成1，这样可以保证MySQL异常重启之后数据不丢失。
sync_binlog这个参数设置成1的时候，表示每次事务的binlog都持久化到磁盘。这个参数我也建议你设置成1，这样可以保证MySQL异常重启之后binlog不丢失。

问题：
>前面我说到定期全量备份的周期“取决于系统重要性，有的是一天一备，有的是一周一备”。那么在什么场景下，一天一备会比一周一备更有优势呢？或者说，它影响了这个数据库系统的哪个指标？

答案：影响的是“最长恢复时间”这个指标

## 03 事务隔离：为什么你改了我还看不见？

## 16 “order by”是怎么工作的？
表定义：
```sql
CREATE TABLE `t` ( 
`id` int(11) NOT NULL, 
`city` varchar(16) NOT NULL, 
`name` varchar(16) NOT NULL, 
`age` int(11) NOT NULL, 
`addr` varchar(128) DEFAULT NULL, 
PRIMARY KEY (`id`), 
KEY `city` (`city`) ) 
ENGINE=InnoDB;
```
查询的SQL语句：
`select city,name,age from t where city='杭州' order by name limit 1000 ;`
**全字段排序**
为了避免全表扫描，在city字段上添加索引，使用explain查看语句执行情况
![](MySQL/attachments/80f979ef11c9be8a1a1662215c2bdaf2_MD5.jpeg)
“Using filesort”表示需要排序，MySQL会为每个线程分配一块内存用于排序，sort_buffer。
为了说明这个SQL查询语句的执行情况，首先查看city索引的示意图：
![](MySQL/attachments/1ef1a2a7bb37c318c9936c8a54288ce5_MD5.jpeg)
这个语句的执行过程为：
1. 初始化sort_buffer，确定放入city、name、age字段
2. 从索引city中找到第一个满足要求的的主键id，ID_X
3. 到主键id索引中取出整行，将name、city、age三个字段的值，存入sort_buffer中
4. 从索引city中取出下一个记录的主键id
5. 重复3、4步直到不满足查询条件为止，对应于ID_Y
6. 对sort_buffer中的数据按照name进行快速排序
7. 按照排序结果将前1000行返回给客户端
以上过程成为**全字段排序**，执行流程如下图：
![](MySQL/attachments/36aceb06347d3a669e83497161838525_MD5.jpeg)
“按照name排序”这个操作，可能在内存中完成，也有可能使用外部排序，取决于`sort_buffer_size`，就是MySQL为排序开辟的内存大小。如果要排序的数据量小于sort_buffer_size就在内存中完成。
在使用临时文件进行排序时，外部排序一般使用归并排序，其中需要使用到的临时文件个数为`number_of_tmp_files`。
**rowid排序**
全字段排序在要查询返回字段很多的话，sort_buffer里面要放的字段数太多，这样内存能够同时放下的行数很少，需要分成很多个临时文件，排序的性能会很差。也就是说==如果单行很大，全字段排序效率不好==。
修改`max_length_for_sort_data`参数，MySQL专门控制用于排序的行数据长度的一个参数，如果单行的长度超过这个值，MySQL就认为单行太大，换一种算法。
简短来说，就是在sort_buffer中只存入需要排序的name以及主键id，排序完成后再根据主键id查询其他需要返回的字段值。这样的好处就是sort_buffer中可以放入更多的行，使得尽可能在内存中操作，提高效率。
以下的执行过程，成为rowid排序。
![](MySQL/attachments/71f27ebf249f00c43ed4388a83698a15_MD5.jpeg)
**全字段排序 VS rowid排序**
如果MySQL担心排序内存太小，才会采用rowid排序算法，这样排序过程中一次可以排序更多的行，但是需要在返回到原表中取数据。
如果MySQL认为内存足够大，会优先使用全字段排序。
==如果内存够，就要多利用内存，尽量减少磁盘访问==

从以上分析的执行过程来看，MySQL之所以需要生成临时表，在临时表上做排序操作，**是因为原来的数据都是无序的。**
我们可以创建一个city与name的联合索引：
`alter table t add index city_user(city, name);`
![](MySQL/attachments/a22dc65f7c3dd17bd690fc8eb445a5b1_MD5.jpeg)
这样name就会天然有序，查询过程中不需要临时表，也不需要排序。
更进一步的优化就是**覆盖索引**，**索引上的信息足够满足查询请求，不需要再回到主键索引上去取数据。**
`alter table t add index city_user_age(city, name, age);`

问题：
> 假设你的表里面已经有了city_name(city, name)这个联合索引，然后你要查杭州和苏州两个城市中所有的市民的姓名，并且按名字排序，显示前100条记录。如果SQL查询语句是这么写的 ：
> `mysql> select * from t where city in ('杭州',"苏州") order by name limit 100;`
> 那么，这个语句执行的时候会有排序过程吗，为什么？
> 如果业务端代码由你来开发，需要实现一个在数据库端不需要排序的方案，你会怎么实现呢？
> 进一步地，如果有分页需求，要显示第101页，也就是说语句最后要改成 “limit 10000,100”， 你的实现方法又会是什么呢？

答案：
in这种方式name不是递增有序的，因此需要排序过程。
就是将两个city分开单独查询，充分利用索引的有序性，然后再进行归并排序的思想。
如果limit 10000,100直接使用
`select * from t where city="苏州" order by name limit 10100`
这种方式返回给客户端的数据量太大了，可以使用
`select id,name from t where city="苏州" order by name limit 10100`
这种方式，先查询到id值，然后根据id值取其他字段值。

## 17 如何正确地显示随机消息？
业务场景是
从一个单词表中随机选出三个单词。随着单词表变大，选单词这个逻辑变得越来越慢，甚至影响到了首页的打开速度。
**内存临时表**
首先想到的是用order by rand()实现
![](MySQL/attachments/b22999cfe886d7ca99aa01bc77af89c9_MD5.jpeg)
Using temporary，表示使用临时表，Using filesort表示需要执行排序操作。
对于临时内存表的排序来说，**InnoDB**优先会执行全字段排序减少磁盘访问。**内存表**回表过程只是简单的根据数据行的位置，直接访问到数据，不会访问磁盘，因此会使用rowid排序。
![](MySQL/attachments/731b9dd8b99c2c858ed47eff46e6b84a_MD5.jpeg)
图中内存临时表使用的是Memory引擎，pos是位置信息（MySQL用来定位一行数据），也就是rowid。
- 对于有主键的InnoDB表来说，这个rowid就是主键ID；
- 对于没有主键的InnoDB表来说，这个rowid就是由系统生成的，占用6字节；
小结：**order by rand()使用了内存临时表，内存临时表排序的时候使用了rowid排序方法。**
`tmp_table_size`限制了内存临时表的大小，默认是16M，如果临时表大于16M，则内存临时表就会转成磁盘临时表。
磁盘临时表使用的引擎默认是InnoDB，由参数`internal_tmp_disk_storage_engine`控制
当需要limit的数字较小时，堆大小没有超过sort_buffer_size，MySQL5.6引入了**优先队列排序算法**，不需要临时文件。但当维护的堆大小超过了时，之恶能使用归并排序算法。
**随机排序算法**
```sql
mysql> select count(*) into @C from t; 
set @Y1 = floor(@C * rand()); 
set @Y2 = floor(@C * rand()); 
set @Y3 = floor(@C * rand()); 
select * from t limit @Y1，1； //在应用代码里面取Y1、Y2、Y3值，拼出SQL后执行 
select * from t limit @Y2，1； 
select * from t limit @Y3，1；
```
扫描的总行数为C+(Y1+1)+(Y2+1)+(Y3+1)

**总结**
如果你直接使用order by rand()，这个语句需要Using temporary 和 Using filesort，查询的执行代价往往是比较大的。所以，在设计的时候你要量避开这种写法。
今天的例子里面，我们不是仅仅在数据库内部解决问题，还会让应用代码配合拼接SQL语句。在实际应用的过程中，比较规范的用法就是：尽量将业务逻辑写在业务代码中，让数据库只做“读写数据”的事情。

问题：
> 上面的随机算法3的总扫描行数是 C+(Y1+1)+(Y2+1)+(Y3+1)，实际上它还是可以继续优化，来进一步减少扫描行数的。
> 我的问题是，如果你是这个需求的开发人员，你会怎么做，来减少扫描行数呢？说说你的方案，并说明你的方案需要的扫描行数。

答案：
先取出id值，然后直接where进行查询

## 18 为什么这些SQL语句逻辑相同，性能却差异巨大？
案例一：条件字段函数操作
**对索引字段做函数操作，可能会破坏索引值的有序性，因此优化器就决定放弃走树搜索功能。**
例如：
`select count(*) from tradelog where month(t_modified)=7;`
下图方框上就是month函数计算的结果
![](MySQL/attachments/f633b6c346cf07a23df26c0b1557e0ba_MD5.jpeg)
即使t_modified上有索引，但还是会全表扫描。因为B+树提供的快速定位能力，来源于同一层兄弟节点的有序性，而month函数会破坏这一特性。
**优化：**
```sql
mysql> select count(*) from tradelog where -> (t_modified >= '2016-7-1' and t_modified<'2016-8-1') or -> (t_modified >= '2017-7-1' and t_modified<'2017-8-1') or -> (t_modified >= '2018-7-1' and t_modified<'2018-8-1');
```
显示的进行查询，这样可以利用到索引

案例二：隐式类型转换
`mysql> select * from tradelog where tradeid=110717;`
其中tradeid的类型为varchar(32)，输入的类型为整型，对比时需要类型转换。
==MySQL中的转换规则是将字符串转换成数组。==
对于优化器而言，上述语句等价于：
`mysql> select * from tradelog where CAST(tradid AS signed int) = 110717;`
出发了规则一：对索引字段做函数操作，优化器会放弃走树搜索功能。

案例三：隐式字符编码转换
tradelog字符集为utf8mb4，trade_detail字符集为utf8，且tradeid上都有索引。

但执行下述sql，会发现第二行进行了全表扫描，并没有用到trade_detail中tradeid的索引。
![](MySQL/attachments/98e85e71e0741b00f16500fd3adb536e_MD5.jpeg)
1. 第一行显示优化器会先在交易记录表tradelog上查到id=2的行，这个步骤用上了主键索引，rows=1表示只扫描一行；
2. 第二行key=NULL，表示没有用上交易详情表trade_detail上的tradeid索引，进行了全表扫描。
![](MySQL/attachments/0d58a33919c308ed8334d426e9377d8b_MD5.jpeg)
在这个执行计划里，是从tradelog表中取tradeid字段，再去trade_detail表里查询匹配字段。因此，我们把tradelog称为**驱动表**，把trade_detail称为**被驱动表**，把tradeid称为**关联字段**。

单独把第三步改成SQL来看，是：
`mysql> select * from trade_detail where tradeid=$L2.tradeid.value;`
$L2.tradeid.value的字符集是utf8mb4，并且utf8mb4是utf8的超集，MySQL会进行转换，等价于：
`select * from trade_detail where CONVERT(traideid USING utf8mb4)=$L2.tradeid.value;`
也是违反了对索引字段做函数操作，优化器放弃走树搜索功能。
**连接过程中要求在被驱动表的索引字段上加函数操作**，是直接导致对被驱动表做全表扫描的原因。
优化：
- 比较常见的优化方法是，把trade_detail表上的tradeid字段的字符集也改成utf8mb4，这样就没有字符集转换的问题了。
- 如果能够修改字段的字符集的话，是最好不过了。但如果数据量比较大， 或者业务上暂时不能做这个DDL的话，那就只能采用修改SQL语句的方法了。
  `select d.* from tradelog l , trade_detail d where d.tradeid=CONVERT(l.tradeid USING utf8) and l.id=2;`

==因此，每次你的业务代码升级时，把可能出现的、新的SQL语句explain一下，是一个很好的习惯。==











