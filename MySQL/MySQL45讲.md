> 笔记内容为学习极客时间-MySQL实战45讲

**目录**

- [01 基础架构：一条SQL查询语句是如何执行的？](#01%20%E5%9F%BA%E7%A1%80%E6%9E%B6%E6%9E%84%EF%BC%9A%E4%B8%80%E6%9D%A1SQL%E6%9F%A5%E8%AF%A2%E8%AF%AD%E5%8F%A5%E6%98%AF%E5%A6%82%E4%BD%95%E6%89%A7%E8%A1%8C%E7%9A%84%EF%BC%9F)
- [02 日志系统：一条SQL更新语句是如何执行的？](#02%20%E6%97%A5%E5%BF%97%E7%B3%BB%E7%BB%9F%EF%BC%9A%E4%B8%80%E6%9D%A1SQL%E6%9B%B4%E6%96%B0%E8%AF%AD%E5%8F%A5%E6%98%AF%E5%A6%82%E4%BD%95%E6%89%A7%E8%A1%8C%E7%9A%84%EF%BC%9F)
- [03 事务隔离：为什么你改了我还看不见？](#03%20%E4%BA%8B%E5%8A%A1%E9%9A%94%E7%A6%BB%EF%BC%9A%E4%B8%BA%E4%BB%80%E4%B9%88%E4%BD%A0%E6%94%B9%E4%BA%86%E6%88%91%E8%BF%98%E7%9C%8B%E4%B8%8D%E8%A7%81%EF%BC%9F)
- [16 “order by”是怎么工作的？](#16%20%E2%80%9Corder%20by%E2%80%9D%E6%98%AF%E6%80%8E%E4%B9%88%E5%B7%A5%E4%BD%9C%E7%9A%84%EF%BC%9F)
- [17 如何正确地显示随机消息？](#17%20%E5%A6%82%E4%BD%95%E6%AD%A3%E7%A1%AE%E5%9C%B0%E6%98%BE%E7%A4%BA%E9%9A%8F%E6%9C%BA%E6%B6%88%E6%81%AF%EF%BC%9F)
- [18 为什么这些SQL语句逻辑相同，性能却差异巨大？](#18%20%E4%B8%BA%E4%BB%80%E4%B9%88%E8%BF%99%E4%BA%9BSQL%E8%AF%AD%E5%8F%A5%E9%80%BB%E8%BE%91%E7%9B%B8%E5%90%8C%EF%BC%8C%E6%80%A7%E8%83%BD%E5%8D%B4%E5%B7%AE%E5%BC%82%E5%B7%A8%E5%A4%A7%EF%BC%9F)
- [19 为什么我只查一行的语句，也执行这么慢？](#19%20%E4%B8%BA%E4%BB%80%E4%B9%88%E6%88%91%E5%8F%AA%E6%9F%A5%E4%B8%80%E8%A1%8C%E7%9A%84%E8%AF%AD%E5%8F%A5%EF%BC%8C%E4%B9%9F%E6%89%A7%E8%A1%8C%E8%BF%99%E4%B9%88%E6%85%A2%EF%BC%9F)

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

## 19 为什么我只查一行的语句，也执行这么慢？

**第一类：查询长时间不返回**
```sql
mysql> select * from t where id=1;
```
一般这种情况，大概率是表t被锁住了。执行`show processlist`命令，查看当前语句的执行情况。

**等MDL锁**
![](MySQL/attachments/a1372942382dd37834ccc1af73c8e4c4_MD5.jpeg)
Waiting for table metadata lock，出现**这个状态表示的是，现在有一个线程正在表t上请求或者持有MDL写锁，把select语句堵住了。**
解决的办法就是找到谁持有MDL锁，将他kill
有了performance_schema和sys系统库以后，就方便多了。（MySQL启动时需要设置performance_schema=on)
通过查询sys.schema_table_lock_waits这张表，我们就可以直接找出造成阻塞的process id，把这个连接用kill 命令断开即可。
`select blocking_pid from sys.schema_table_lock_waits;`

**等flush**
![](MySQL/attachments/af94f1e9fb75065ac27431f1da06f11e_MD5.jpeg)
Waiting for table flush，现在有一个线程正要对表t做flush操作。
一般有两种flush操作：
```sql
flush tables t with read lock;
flush tables with read lock;
```
这两个flush语句，如果指定表t的话，代表的是只关闭表t；如果没有指定具体的表名，则表示关闭MySQL里所有打开的表。
但是正常这两个语句执行起来都很快，除非它们也被别的线程堵住了。

复现步骤：
![](MySQL/attachments/249c7ff717d7f1654ea4e52c9a88fac0_MD5.jpeg)
processlist结果
![](MySQL/attachments/6983b6822ef72589aec70a1636555124_MD5.jpeg)

**等行锁**
以上表级锁都是MySQL Server层的机制，而行级锁是InnoDB存储引擎的机制。
```sql
mysql> select * from t where id=1 lock in share mode;
```
访问id=1记录需要加读锁，如果这时候有一个事务持有一个写锁，并且一直不提交，那该select就会被阻塞。
![](MySQL/attachments/354a53f519e6be518ed2f6d1eeb5a738_MD5.jpeg)
![](MySQL/attachments/6a3b2db4a8fe75a8595b65277e3614c8_MD5.jpeg)
分析方式就是，查出谁占有写锁，如果MySQL5.7版本，可以通过sys.innodb_lock_waits查看。
```sql
select * from t sys.innodb_lock_waits where locked_table=`'test'.'t'`\G
```
![](MySQL/attachments/243223872973643da60441e8d4f2c7e6_MD5.jpeg)
这里KILL QUERY 4是没有用的，因为当前语句是执行完成的，只是没有commit，所以必须KILL 4 断开连接。

**第二类：查询慢**
`select * from t where c=50000 limit 1;`
以上语句执行慢是因为c上没有索引，需要扫描50000行。

接下来再看一个只扫描一行，但是执行很慢的语句。
`select * from t where id=1；`
扫描行数为1，但是执行时间800ms
![](MySQL/attachments/cd9d8307ded02cf808f39bbdb0ee8c5a_MD5.jpeg)
`select * from t where id=1 lock in share mode`
扫描行数同样为1行，但是执行时间为0.2ms
![](MySQL/attachments/49827a5a8f02bd9e7d98236b71cc6be1_MD5.jpeg)

按道理说lock in share mode还需要加锁，执行时间应该更长才对。
复现：
![](MySQL/attachments/86952d0c7d5ae7a24d96e3227959803d_MD5.jpeg)
执行的情况：
![](MySQL/attachments/9542265f0d859b10aabd1c6e4cb42c8b_MD5.jpeg)
session B更新完100万次，生成了100万个回滚日志(undo log)。

带lock in share mode的SQL语句，是**当前读**，因此会直接读到1000001这个结果，所以速度很快；而select * from t where id=1这个语句，是**一致性读**，因此需要从1000001开始，依次执行undo log，执行了100万次以后，才将1这个结果返回。

问题：
> 我们在举例加锁读的时候，用的是这个语句，select * from t where id=1 lock in share mode。由于id上有索引，所以可以直接定位到id=1这一行，因此读锁也是只加在了这一行上。
> 但如果是下面的SQL语句，
> `begin; select * from t where c=5 for update; commit;`
> 这个语句序列是怎么加锁的呢？加的锁又是什么时候释放呢？

答案：
在可重复读的隔离级别下，因为c没有索引，会全表扫描，并对扫描到的每一个记录加**临键锁（next-key lock）**，**临键锁=间隙锁+记录锁**，锁住满足条件的行，并且锁住索引该行前后的间隙，防止其他事务插入，导致幻读。所有被扫描的索引记录都会添加临键锁，判断不满足后释放锁，而c=5的记录锁以及间隙锁会在commit后释放。
在读提交的隔离级别下，语句执行完成后，只有行锁，没有间隙锁，也是在commit后才释放行锁。

## 20 幻读是什么，幻读有什么问题？
以下语句属于当前读：
加锁的select `select...for update`
`select...lock in share mode`
update
delete
insert
以上语句都会读取数据的最新版本，而不是快照版本，并会加上行锁或间隙锁，防止并发事物的干扰

==假设只在id=5这一行加锁==，查看以下场景：
![](MySQL/attachments/5a729948bda236fdc947073e9fc508f5_MD5.jpeg)
for update使用的是当前读
其中，Q3读到id=1这一行的现象，被称为“幻读”。也就是说，幻读指的是一个事务在前后两次查询同一个范围的时候，后一次查询看到了前一次查询没有看到的行。

“幻读”的说明：
1. 在可重复读隔离级别下，普通的查询是快照读，是不会看到别的事务插入的数据的。因此，幻读在“当前读”下才会出现。
2. 上面session B的修改结果，被session A之后的select语句用“当前读”看到，不能称为幻读。幻读仅专指“新插入的行”。
从事物的可见性规则来分析，上述结果没有问题。
**幻读有什么问题？**
**首先是语义上的**，sessionA中T1时刻“把d=5的行锁住”，这个语义被破坏了。sessionB、sessionC按理来说应该是要被阻塞的，虽然在顺序上加锁的时刻还没有看到sessionB与sessionC的操作。

**其次是数据一致性的问题**
![](MySQL/attachments/cf24f9e2def438030ef8e791b092f841_MD5.jpeg)
上图的执行顺序在binlog中是
```sql
update t set d=5 where id=0; /*(0,0,5)*/ 
update t set c=5 where id=0; /*(0,5,5)*/ 
insert into t values(1,1,5); /*(1,1,5)*/ 
update t set c=5 where id=1; /*(1,5,5)*/ 
update t set d=100 where d=5;/*所有d=5的行，d改成100*/
```
这个语句序列，不论是拿到备库去执行，还是以后用binlog来克隆一个库，这三行的结果，都变成了 (0,5,100)、(1,5,100)和(5,5,100)。
也就是说，id=0和id=1这两行，发生了数据不一致。
==也就是说只给d=5这一行加锁是不行的==
那么给所有扫描到的行加写锁：
![](MySQL/attachments/fab7d1bad2c8006a45fd3dc81282cab9_MD5.jpeg)
binlog中
```sql
insert into t values(1,1,5); /*(1,1,5)*/ 
update t set c=5 where id=1; /*(1,5,5)*/ 
update t set d=100 where d=5;/*所有d=5的行，d改成100*/ update t set d=5 where id=0; /*(0,0,5)*/ 
update t set c=5 where id=0; /*(0,5,5)*/
```
id=0这一行的问题解决了，但是id=1这一行，也就是幻读的问题还没有解决。
为什么把所有的记录都加了锁，还是阻止不了id=1这一行的插入和更新呢？是因为加锁的时候id=1这一行还不存在，所有加不上锁。
==即使把所有的记录都加上锁，还是阻止不了新插入的记录==
**如何解决幻读？**
InnoDB引入间隙锁（Gap Lock）
![](MySQL/attachments/a43a48ab6ff3cd65e53f07dea8124fbd_MD5.jpeg)
这样加了6个行锁，7个间隙锁，确保了无法再插入新的记录。
间隙锁和行锁合称next-key lock，前开后闭区间， (-∞,0]、(0,5]、(5,10]、(10,15]、(15,20]、(20, 25]、(25, +supremum]
supremum是一个不存在的最大值，是为了符合前开后闭区间这一规则
==间隙锁和next-key lock的引入解决了幻读的问题，但也会存在一些问题（死锁）==
![](MySQL/attachments/30cb0a2478ffa9644f01f355548ce920_MD5.jpeg)
间隙锁之间不会冲突，sessionA与sessionB的间隙锁发生了死锁。
**间隙锁的引入，可能会导致同样的语句锁住更大的范围，这其实是影响了并发度的**
==间隙锁在可重复读RP隔离级别才会生效==
读提交RC隔离级别没有间隙锁，但需要解决数据和日志不一致问题，需要把binlog格式设置为row

**RC+row binlog与RP的比较**
RC锁力度小，仅锁定特定行，加上row格式的binlog可以实现数据与日志的一致性；RP有间隙锁，但可以解决幻读问题。
实际场景：
**现代互联网业务**（如电商、社交）推荐：**`READ COMMITTED + binlog_format=ROW`**
这是大厂（如阿里、字节）主流实践，兼顾性能与一致性
**强一致性场景**（如银行核心账务）建议：**`REPEATABLE READ`**，牺牲部分性能换取数据一致性。
> row格式的binlog：不会记录sql语句，而是记录数据实际变更情况
> statement格式的binlog：记录的是sql语句本身

**为什么说RC+row格式binlog可以解决数据与日志的一致性？**
RC保证事务提交后才写binlog，并且记录的是数据本身的变化，而不是sql语句，避免了因sql语句顺序而导致的不一致性。

## 21 为什么只改了一行的语句，锁这么多？
间隙锁在可重复读RP隔离级别下才有效

加锁规则包含两个“原则”、两个“优化”和一个“bug”
1. 原则1：加锁的基本单位是next-key lock，前开后闭区间
2. 原则2：查找过程中访问到的对象才会加锁
3. 优化1：索引上的等值查询，给唯一索引加锁的时候，next-key lock退化为行锁
4. 优化2：索引上的等值查询，向右遍历时且最后一个值不满足等值条件的时候，next-key lock退化为间隙锁
5. 1个bug：唯一索引上的范围查询会访问到不满足条件的第一个值为止

**案例一：等值查询间隙锁**
![](MySQL/attachments/525c9b48a22f9ed3d521fea381604616_MD5.jpeg)
1. 原则1，加锁单位为next-key lock，sessionA加锁范围为(5, 10]
2. 优化2，next-key lock退化为间隙锁，(5, 10)
所以最终id=8插入会被阻塞，id=10的更新ok

**案例二：非唯一索引等值锁**
![](MySQL/attachments/445537dfe9a487a471422fb250b08b28_MD5.jpeg)
1. 原则1，(0, 5]加next-key lock
2. 但是c是普通索引，需要向右遍历，直到查询到c=10；根据原则2，访问到的对象都要加锁，(5, 10]
3. 优化2，第二个next-key lock退化为间隙锁，(5, 10)
4. 原则2，该查询使用覆盖索引，并不需要访问主键索引，所以主键索引上没有加任何锁，因此sessionB的update语句可以执行
sessionC会被sessionA的(5, 10)间隙锁锁住；需要注意，lock in share mode只会锁覆盖索引，如果是for update，系统会认为接下来需要更新数据，会顺便在主键索引上满足条件的行加行锁。
==锁是加在索引上的==，如果要用lock in share mode给行加锁避免数据被更新，必须绕过覆盖索引的优化，在查询字段中加入索引中不存在的字段

==案例三：主键索引范围锁==
![](MySQL/attachments/8874ddb7047b41727f97811a3ec62f63_MD5.jpeg)
1. 找到第一个id=10的行，next-key lock(5, 10]，根据优化1，退化为行锁id=10
2. 范围查询继续往后找，找到id=15停下，原则2，next-key lock(10, 15]
for update，sessionA锁的范围在主键索引上，行锁id=10，next-key lock(10, 15]
注意，首次id=10是等值查询来判断的，向右扫描到id=15的时候，使用的是范围查询判断

**案例四：非唯一索引范围锁**
![](MySQL/attachments/5799a6b79a9b19c1826067832d4d383f_MD5.jpeg)
c=10定位记录，索引c加next-key lock(5, 10]，c是非唯一索引，没有优化1，不会蜕变为行锁；第二个c=15是范围查询，加next-key lock(10, 15]；

**案例五：唯一索引范围锁bug**
![](MySQL/attachments/04ccf9ead994b2f3095d0c6025deb842_MD5.jpeg)
首先是索引id加上next-key lock(10, 15]，因为id是唯一索引，所以循环判断到id=15应该停止。
但是事实上，InnoDB会往前扫描第一个不满足条件的行为止，也就是id=20。由于是范围扫描，会加next-key lock(15, 20]
所以这是一个bug

**案例六：非唯一索引上存在“等值”的情况**
![](MySQL/attachments/88d41a13ab46917964bcb2562cc21fa7_MD5.jpeg)
![](MySQL/attachments/ee6e78084bb8e7ef4da35ca278f0acbc_MD5.jpeg)
首先访问第一个c=10的记录，按照原则1，加next-key lock（c=5，id=5）到（c=10，id=10）
c不是唯一索引，向右查找，直到碰到（c=15，id=15）这一行循环结束。根据优化2，等值查询向右查询到不满足条件的行，会退化为（c=10，id=10）到（c=15，id=15）的间隙锁
加锁范围是如下蓝色区域覆盖的部分，虚线表示开区间
![](MySQL/attachments/1c60e7ea4643cb11e8b0c7521faaf382_MD5.jpeg)

**案例七：limit语句加锁**
![](MySQL/attachments/f7788aa4b6bc1e3c94f5462ac168b00f_MD5.jpeg)
sessionA的delete语句加了limit 2。而表t里c=10记录就两条，加不加limit 2，删除的效果都是一样的，但是加锁的效果却不同。
这是因为，因为limit 2，在遍历到（c=10，id=30）这一行之后，满足条件的语句已经有两条，循环就结束了
所以索引c加锁范围就从（c=5，id=5）到（c=10，id=30）前开后闭区间
![](MySQL/attachments/46741edf835ff3b34ec192448db3ec9d_MD5.jpeg)
==指导意义就会死删除数据的时候尽量加limit==，不仅可以控制删除数据的条目，让操作更安全，还可以减少加锁的范围

**案例八：一个死锁的例子**
next-key lock实际上是间隙锁和行锁加起来的结果
![](MySQL/attachments/7d5b424d4d28669e318ee95c02cdedd5_MD5.jpeg)
1. sessionA加lock in share mode，索引c上加next-key lock(5, 10] (10, 15]，优化2，第二个锁退化为间隙锁(10, 15)
2. sessionB，在索引c上添加next-key lock(5,10]，进入锁等待
3. sessionA插入（8，8，8），被sessionB的next-key lock锁住，出纤死锁，sessionB回滚
sessionB的next-key lock不是还没申请成功吗？
其实next-key lock加锁的操作分为两步：先加（5，10）间隙锁，加锁成功；然后加c=10行锁，这样才被锁住。

==分析加锁规则的时候用next-key lock分析，但是具体的执行过程，会分为间隙锁和行锁两阶段来执行的==

### 小结
上述案例在可重复读隔离级别下验证的，遵循两阶段锁协议，所有加锁的资源，都是在事务提交或者回滚的时候释放

读提交隔离级别下，锁的范围更小，锁的时间更短；在语句执行过程中加上的行锁，会在语句执行完成后，把“不满足条件的行”上的行锁直接释放，不需要等到事务提交

问题：
![](MySQL/attachments/bcebee5a8564710e1939a090a2836c77_MD5.jpeg)
答案：
1. 由于是order by c desc，第一个要定位的是索引c“最右边”c=20的行，加上间隙锁（20，25）和next-key lock(15, 20]
2. 在索引c上向左遍历，直到c=10停下来，所以next-key lock会加到(5, 10]
3. c=20、c=15、c=10三行存在，并且是select \*，所以会在主键id上加三个行锁
所以锁范围就是：索引c上（5，25）、id=15、20两个行锁

## 22 MySQL有哪些“饮鸠止渴”提高性能的方法？
**短连接风暴**
正常的短连接模式就是连接到数据库后，执行很少的SQL语句就断开，下次需要时再重连。
但是MySQL建立连接的过程成本很高，需要登陆权限判断和获得数据读写权限。
风险就是当数据库处理的慢，连接数会暴涨。max_connections参数控制MySQL实例同时存在的连接数的上限，超过后会拒绝连接请求，提示“Too many connections”。
自然的想法就是提高max_connections值。但这样风险：改的太大，让更多的连接进来，系统负载会进一步加大，大量的资源耗费在权限认证等逻辑，结果适得其反，已经连接的线程拿不到CPU资源去执行业务SQL。
==第一种方法：先处理掉占着连接但是不工作的线程==
对于不需要保持的连接，通过kill connection主动踢掉；同样的可以设置wait_timeout，一个线程空闲wait_timeout之后，会被MySQL主动断开连接。
但是在show processlist结果里踢掉sleep线程，可能是有损的。
![](MySQL/attachments/cf7ae5b7cbfb94601972b24544296423_MD5.jpeg)
如果断开sessionA连接，因为还未提交，只能回滚；而断开sessionB没有影响。
如何判断事务外空闲呢？
![](MySQL/attachments/a66bdf6946e54b38061af5cbba779411_MD5.jpeg)
id=4与id=5都是sleep状态，查看事务具体状态，查看information_schema库的innodb_trx表
![](MySQL/attachments/0457c26256e73efc6d694d4ba8c3d706_MD5.jpeg)
trx_mysql_thread_id=4表示id=4的线程处在事务中
如果连接数太多，优先断开事务外空闲太久的连接；如果还不够，考虑断开事务内空闲太久的连接。
从服务端断开的命令是kill connection+id命令。断开后，客户端并不会直接指导，在下一个请求会报错“ERROR 2013 (HY000): Lost connection to MySQL server during query”
从数据库端主动断开连接可能是有损的，尤其是应用端收到错误，不重新连接，导致从应用端看上去“MySQL一直没有恢复”
==第二种方法：减少连接过程的消耗==
让数据库跳过权限验证阶段，但会存在安全问题
方法：重启数据库，使用-skip-grant-tables参数启动，MySQL会跳过所有权限验证阶段，包括连接过程以及语句执行过程；但在MySQL8.0，使用该参数会把--skip-networking打开，表示数据库只能被本地的客户端连接

**慢查询性能问题**
三种可能：
1. 索引没有设计好
紧急创建索引，MySQL5.6版本之后，创建索引支持Online DDL。最高效的做法是直接alter table。
理想的做法是现在备库执行，流程是：
	1. 备库B执行set sql_log_bin=off，不写binlog，然后执行alter table加索引
	2. 主备切换
	3. 这时主库为B，备库是B。在A上执行set sql_log_bin=off，然后执行alter table加索引
平时也可以考虑gh-ost方案
2. SQL语句没写好
SQL语句不好，导致语句没有使用上索引。
MySQL5.7提供了query_rewrite，可以把一个语句改写成另外一种模式。
3. MySQL选错了索引
应急方案即使在语句上添加force index

---
以上三种可能，出现最多的是前两种，而前两种可以避免：
1. 上线前，在测试环境把慢记录日志打开，并且把long_query_time设置为0，确保每个语句都会记录在慢记录日志
2. 测试表里插入模拟线上数据，做回归测试
3. 观察row_examined是否与预期一致
全量回归测试使用开源工具pt-query-digest

**QPS突增问题**
由于业务高峰或者程序bug导致某个语句的QPS暴增，导致MySQL压力过大，影响服务
新功能bug导致，最理想情况是业务把功能下掉
而从数据库端处理，对于不同的背景，有不同的方法：
1. 全新业务bug。假设DB运维规范，也就是白名单是一个一个加的，如果确定业务方会下掉功能，可以从数据库端直接把白名单去掉
2. 如果新功能使用的是单独的数据库用户，直接用管理员账号把用户删掉，断开现有连接
3. 如果新增功能跟主体功能是部署在一起的，只能通过处理语句来限制。可以使用查询重写，把压力最大的SQL语句重写为“select 1”
重写sql风险很高，会有副作用：如果其他功能也用到了相同的sql模板，会误伤；业务不只是靠一个语句完成，这会导致后面的业务逻辑失败
==虚拟化、白名单机制、业务账号分离，建立规范的运维体系==

## 23 MySQL如何保证数据不丢？
该篇与数据的可靠性有关，在前面提到WAL机制，只要redo log和binlog保证持久化到磁盘，就能保证MySQL异常重启后，数据就可以恢复。
那么，如何保证redo log真实写入磁盘，以及binlog、redo log写入流程。

**binlog写入机制**
事务执行过程中，先把日志写入到binlog cache，事务提交的时候，再把binlog cache写入到binlog文件中。
binlog cache在内存中，每个线程一个，binlog_cache_size控制单个线程内binlog cache所占内存的大小。
![](MySQL/attachments/5464fac84ae1bd52148003098c2421c2_MD5.jpeg)
每个线程都有自己的binlog cache，但是共用一份binlog文件。
- write，将日志写入文件系统的page cache（也是在内存中）
- fsync，将数据持久化到磁盘中，占磁盘的IOPS
write和fsync的机制，由==sync_binlog==控制：
- sync_binlog=0，每次提交事务只write，不fsync
- sync_binlog=1，每次提交事务都fsync
- sync_binlog=N，每次提交事务都write，积累N个事务后fsync
出现IO瓶颈的时候，将sync_binlog设置为一个较大的值，可以提高性能。一般设置为100-1000，风险就是主机异常重启，会丢失最近N个事务的binlog日志

**redo log的写入机制**
事务执行的过程中，生成的redo log会先写到redo log buffer，那什么时候会持久化到磁盘呢？
redo log可能存在三种状态：
![](MySQL/attachments/df6f5d11e0149eb037f61a9f46ab5a16_MD5.jpeg)
- 存在redo log buffer中，物理上是在MySQL的进程内存中
- write写到磁盘，但是没有fsync持久化，物理上是在文件系统的page cache中
- 持久化到磁盘，对应的是hard disk
为了控制redo log的写入策略，InnoDB提供了==innodb_flush_log_at_trx_commit==参数：
- 0，每次事务提交只是把redo log留在redo log buffer
- 1，每次提交都把redo log直接持久化到磁盘
- 2，每次只是把redo log写到page cache
InnoDB后台线程每次1s，将redo log buffer中的日志，调用write写到文件系统的page cache中，然后调用fsync持久化到磁盘。
也就是说，一个没有提交的事务的redo log也可能已经被持久化到磁盘了。
除了轮询外，还有两种场景也会把一个没有提交的事务的redo log持久化到磁盘中：
- redo log buffer占用空间达到innodb_log_buffer_size的一半，后台线程会主动写盘。只是write，没有fsync
- 并行的事务提交的时候，顺带将这个事务的redo log buffer持久化到磁盘
两阶段提交中，时序上redo log先prepare，再写binlog，最后redo log commit。
崩溃恢复逻辑是依赖于prepare的redo log，再加上binlog来恢复的；每秒一次的轮询刷盘，InnoDB认为redo log在commit的时候不需要fsync，只会write到文件系统的page cache中就够了
通常的“双1”配置，就是sync_binlog与innodn_flush_log_at_trx_commit都是1。也就是说一个事务完整提交前，需要等待两次刷盘，一次是redo log（prepare），一次是binlog

为了进一步提高TPS，使用==组提交策略==
先介绍日志逻辑序列号（log sequence number，LSN），是单调递增的，对应redo log的一个个写入点
如图是三个并发的事务（trx1，trx2，trx3）在prepare阶段，都写完redo log buffer，持久化到磁盘的过程，对应的LSN为50、120、160

![](MySQL/attachments/cc93112e8289b7d7cd285084c3388447_MD5.jpeg)
1. trx1第一个到达，被选为这组的leader；
2. 等trx1写盘的时候，组里面已经有三个事务，LSN变为160；
3. trx1写盘的时候，带LSN=160，等trx1返回时，所有LSN小于等于160的redo log都已经被持久化到磁盘中
4. trx2、trx3直接返回
一次group commit中，组员越多，节约磁盘IOPS越好。并发场景下，第一个事务写完redo log buffer，接下来fsync越晚调用，组员会更多，节约的IOPS效果越好。
==MySQL优化是拖时间==，将redo log的fsync拖到binlog write之后。
![](MySQL/attachments/03409c88013ab4df53f8335db6117058_MD5.jpeg)
通常情况下，步骤3执行的很快，所以binlog的write和fsync间隔时间短，导致能一起持久化的binlog比较少，组提交的效果不好。
提升binlog组提交的效果，设置binlog_group_commit_sync_delay和binlog_group_commit_sync_no_delay_count来实现。
- delay表示延迟多少微妙后调用fsync
- count表示积累多少次后调用fsync
两个条件是或的关系，只要有一个满足就会调用fsync
> WAL机制得益于两个方面：顺序写、组提交

==如果MySQL出现IO性能瓶颈==，可以考虑以下三种方法：
1. 设置delay、count参数，通过组提交，减少binlog写盘次数；但会增加语句的响应时间
2. sync_binlog设置为100-1000；风险是主机掉电会丢失binlog日志
3. innodb_flush_log_at_trx_commit设置为2；风险是掉电丢失数据

**小结**
数据库的crash-safe保证的是：
1. 客户端收到事务成功的消息，事务一定是持久化
2. 客户端收到事务失败，事务一定失败
3. 客户端收到“执行异常”的消息，应用需要重练后查询当前状态；数据库只需要保证内部的一致性（数据和日志、主库和备库）

**问题**：
什么时候会把线上生产库设置为“非双1”？

**答案**：
> 1. 业务高峰期
> 2. 备库延迟，为了让备库尽快赶上主库
> 3. 用备库恢复主库的副本
> 4. 批量导入数据
> 一般情况下，“双非1”是innodb_flush_logs_at_trx_commit=2、sync_binlog=1000

## 24 MySQL如何保证主备一致
binlog可以实现归档，也可以用来主备同步
**MySQL主备的基本原理**
下图是基本的主备切换流程
![](MySQL/attachments/3ce59e3787e4d52fd98944febd13708b_MD5.jpeg)
备库一般设置为只读（readonly）模式
备库只读了，如何和主库保持同步更新呢？
readonly设置对超级（super）权限用户无效，而同步更新的线程拥有超级权限。
下图是update语句在节点A执行，然后同步到节点B的完整流程图。
![](MySQL/attachments/b9e0a72eb99ed25606010304c2594ff0_MD5.jpeg)
备库B与主库A之间维持了一个长连接，事务日志用不完整过程：
1. 备库B通过change master命令，设置主库A的IP、端口、用户名、密码，以及binlog的请求位置（文件名、日志偏移量）
2. 备库B执行start slave，备库会启动两个线程：io_thread、sql_thread，io_thread负责与主库建立连接
3. 主库A校验完用户名、密码后，开始按照备库B传过来的位置，从本地读取binlog，发给B
4. 备库B拿到binlog，写到本地文件relay log
5. sql_thread读取relay log，解析日志中命令并执行

**binlog三种格式对比**
statement、row以及mixed
statement格式binlog如下，存储的是SQL语句原文
![](MySQL/attachments/9b7f4b41475ff8a357c5482847182935_MD5.jpeg)
statement格式的缺陷是：在主库执行SQL语句用的是索引a，备库执行使用索引t_modified，这样可能会导致主备不一致，所以需要用到row格式。
row格式如下
![](MySQL/attachments/e5e0cdecdaa7c45b245de30a1bcaaaf3_MD5.jpeg)
借助mysqlbinlog工具解析结果
![](MySQL/attachments/4471f931a50eedbc9f0c5bad5f5e3233_MD5.jpeg)
可以看出，row格式记录了真实删除行的主键id，这样就不会有主备删除不同行的情况。
**为什么会有mixed格式的binlog？**
- statement格式的binlog会导致主备不一致，所以要用到row格式
- row格式缺点是很占空间；例如一个delete删除10w数据，statement只需记录一个SQL语句，但row需要将10w条数据都写到binlog中
- MySQL取了折中方案，mixed格式的binlog。MySQL会自己判断SQL语句是否可能引起主备不一致，如果有可能，就用row格式，否则使用statement格式
==因此，线上至少把binlog设置为mixed格式==

row格式的binlog还有一个好处就是可以：**恢复数据**；不管是在insert、update还是delete语句，row格式都记录了完整的数据，可以使用row格式的binlog进行操作回滚；MariaDB的Flashback工具就是基于以上原理实现回滚数据的。

用mysqlbinlog解析出来日志的statement语句直接拷贝出来执行是有风险的，有些语句依赖上下文命令，直接执行的结果可能是错误的，经典的例子就是`insert into t values(10,10, now());`
![](MySQL/attachments/63c3dd95c7230a50f95882df9a1533f6_MD5.jpeg)
![](MySQL/attachments/f8fd1ab08f4ed994a3279fca2aa8efe0_MD5.jpeg)
binlog恢复数据的标准做法就是用musqlbinlog工具解析出来，把整个解析结果发给MySQL执行：
`mysqlbinlog master.000001 --start-position=2738 --stop-position=2973 | mysql -h127.0.0.1 -P13000 -u$user -p$pwd;`

**循环复制问题**
实际生产上使用比较多的是双M结构，也就是下图的主备切换流程，节点A和节点B互为主备关系。
![](MySQL/attachments/a7b1d62a604ecc7bb8a96d0592e4541a_MD5.jpeg)
节点A更新一条语句，生成binlog发给节点B，节点B执行完语句也会生成binlog（建议log_slave_updates设置为on，表示备库执行relay log后生成binlog），那么节点A和B之间会不断循环执行这个更新语句，也就是循环复制了，怎么解决呢？
可以使用实例的server id解决：
1. 规定两个库的server id必须不同，如果相同不能是主备关系
2. 备库接收到binlog重放过程中，生成与原binlog的server id相同的新的binlog
3. 每个库在收到自己从库发过来的日志后，先判断server id，如果与自己的相同，表示日志是自己生成的，直接丢弃该日志

问题：
循环复制问题，通过判断server id的方式还不够完备，还是有可能出现死循环，构造出场景，如何解决？
答案：
> 一个场景是，主库更新事务，用命令set global server_id=x修改了server_id。
> 另外一个场景是，有三个节点的时候，B的binlog传给A，然后A与A‘搭建了双M结构，A与A’之间会出现循环复制![](MySQL/attachments/e92be17f83144125bb58a4a56529bc6b_MD5.jpeg)
>这种场景在做数据库迁移的时候会出现，可以在A或者A‘上执行：
>`stop slave； 
>`CHANGE MASTER TO IGNORE_SERVER_IDS=(server_id_of_B);`
>` start slave;`
>这样这个节点收到日志后不会再执行，过一段时间后，再执行下面命令将这个值改回来。
>`CHANGE MASTER TO IGNORE_SERVER_IDS=();`

## 25 MySQL是怎么保证高可用的？
正常情况下，只要主库执行更新生成所有的binlog，都可以传到备库并正确执行，备库就能达到和主库一致的状态，这就是最终一致性。
MySQL要提供高可用能力，最终一致性是不够的。
**主备延迟**
主备切换可能是主动运维动作，也有可能是被动操作。
主动切换：存在“同步延迟”
1. 主库A执行完成一个事务，写入binlog，时刻记为T1；
2. 传给备库B，B接受完这个binlog时刻记为T2；
3. 备库执行完这个事务，时刻记为T3
主备延迟，就是同一个事务，备库执行完成的时间和主库执行完成的时间之间的差值，T3-T1
备库上执行`show slave status`会显示`seconds_behind_master`，表示当前备库延迟了多少秒
seconds_behind_master的计算方式是：
- 每个事务的binlog里有一个时间字段，记录主库上写入的时间
- 备库取出当前执行的事务时间字段值，计算与当前时间的差值
主备机器时间不一致，会导致主备延迟值不准吗？
不会，当备库连接主库的时候，会执行`SELECT UNIX_TIMESTAMP()`获取当前主库的系统时间，如果不一致，在后续计算的时候会自动校准。
在网络正常的情况下，日志从主库传递给备库的时间是很短的，T2-T1非常小，主备延迟主要来源备库接受完binlog和执行完binlog之间的时间差。
==主备延迟最直接的表现是：备库消费中转日志（relay log）的速度，比主库生产binlog的速度要慢==

**主备延迟的来源**
1. **在有些部署条件下，备库所在的机器性能要比主库所在的机器性能差。**
这是因为，想着反正备库没有请求，所以可以用差一点的机器。
但现在这种部署比较少，因为主备可能发生切换，备库随时可能变成主库，所以主备库选用相同规格的机器，做对称部署。

2. **备库的压力大**
一般的想法是，主库既然提供了写能力，那么备库可以提供一些读能力，或者一些运营后台需要的分析语句，不能影响正常业务，所以只能在备库上跑。
结果就是，备库上的查询耗费了大量的CPU资源，影响了同步速度，导致主备延迟。

---
处理：
1. 一主多从。多几个从库，让从库分担读的压力
2. 通过binlog输出到外部系统，例如Hadoop，让外部系统提供统计类查询的能力
==一主多从的方式大都会采用==，作为数据库系统，必须保证有定期全量备份的能力
---
3. **大事务**
大事务在主库上执行时间长，那么会导致从库延迟时间长。
==经典的就是一次性delete太多数据==，删除数据的时候，要控制每个事务的删除量，分成多次删除。
==另外一个大事务场景，就是大表DDL==，计划内的DDL，建议使用gh-ost方案。

4. **备库的并行复制能力**

由于主备延迟的存在，主备切换的时候，对应不同的策略：
**可靠性优先策略**
双M结构下，从状态1切换到状态2过程：
> 1. 判断备库B的seconds_behind_master，如果小于某个值（5s）继续下一步，否则重试
> 2. 主库A改为只读，readonly设置为true
> 3. 判断备库B的seconds_behind_master，直到0
> 4. 备库B改为可读写，readonly设置false
> 5. 业务请求切换到备库B
![](MySQL/attachments/9cbabb74088fee0bc2bf6f70516910a9_MD5.jpeg)
图中SBM是seconds_behind_master的简写

这个切换流程存在不可用时间，所以要在步骤1判断SBM值要足够小。

**可用性优先策略**
把步骤4、5调整到最开始执行，不等待主备数据同步，直接把连接切换到备库B，并且让备库B可以读写，那么系统就没有不可用时间了。
==代价是可能出现数据不一致的情况==
> 1. 使用row格式的binlog，数据不一致的情况很容易不发现，使用mixed或者statement格式的binlog时，数据可能发生不一致
> 2. 主备切换的可用性策略会导致不一致。一般建议使用可靠性优先策略，对于数据服务数据的可靠性优于可用性

**有哪些情况数据的可用性优先级更高呢？**
记录操作日志的库，数据不一致可以通过binlog修补，而且短暂的不一致不会引发业务问题；同时业务系统依赖于日志的写入日志，如果库不可写，会导致线上的业务无法操作。
改进措施：让业务逻辑不依赖于日志的写入，可以写到本地文件，然后使用可靠性优先策略

**可靠性优先，异常切换效果？**
如果主备间延迟时间长，主库A掉电，HA切换B作为主库，使用可靠性优先策略的话，需要等待SBM=0，这时系统会出现完全不可用的情况。
![](MySQL/attachments/5cdfaf4cf413cebd8b684e3f8d268740_MD5.jpeg)

**问题：**
一般现在的数据库运维系统都有备库延迟监控，其实就是在备库上执行 show slave status，采集seconds_behind_master的值。
假设，现在你看到你维护的一个备库，它的延迟监控的图像类似图6，是一个45°斜向上的线段，你觉得可能是什么原因导致呢？你又会怎么去确认这个原因呢？
![](MySQL/attachments/1159cc95693fcdc4866de68b63ff77f7_MD5.jpeg)
答案：
> 主库被完全堵住：
> 1. 大事务（大表DDL、一个事务操作很多行）
> 2. 备库起了一个长事务 ，例如
> `begin; select * from t limit 1;`
> 这时主库对表t做了一个加字段的操作，DDL在备库应用的时候会被堵住

## 26 备库为什么会延迟好几个小时？
不论是偶发性的查询压力，还是备份，对备库延迟的影响都是分钟级的，备库在恢复正常以后都能追上来。
但是如果备库执行日志的速度持续低于主库生成日志的速度，那么延迟可能成为小时级别。对于压力大的主库，备库可能永远都追不上。
主备的并行复制能力关注图中黑色的两个箭头。一个代表客户端写入主库，另一个代表备库上sql_thread执行中转日志（relay log）。按照并行度来看，第一个比第二个高。
![](MySQL/attachments/e8983f649ef42c95c2dba975d67e76a5_MD5.jpeg)
主库上影响并行度的原因就是各种锁，备库则是sql_thread更新数据的逻辑。
MySQL5.6之前，只支持单线程复制，在主库并发高，TPS高时会出现严重的主备延迟问题。
所有的多线程复制机制，都是将一个线程的sql_thread拆成多个线程：
![](MySQL/attachments/c9710175a800a605b98fd53ae27cdd95_MD5.jpeg)
图中coordinator负责读取中转日志和分发事务，worker线程更新日志，由参数slave_parallel_workers决定的。32核物理机的情况下，设置为8-16之间最好，因为备库可能还要提供读查询。
coordinator在分发的时候，需要满足以下两个基本要求：
1. 不能造成更新覆盖。更新同一行的两个事务，必须被分发到同一个worker中
2. 同一个事务不能被拆开，必须放到同一个事务中

---
常见的策略：
**按表分发策略**
如果两个事务更新不同的表，他们是可以并行的
![](MySQL/attachments/46c5ecfb7dffeb924d671b9e61c5872f_MD5.jpeg)
每个worker对应一个hash表，保存当前worker的“执行队列”里事务所涉及的表。key是“库名.表名”，value是当前队列中有多少个事务修改这个表
新事物T的分配流程，该事务修改的行涉及到表t1和t3：
1. 事务T中涉及修改t1，而worker1队列中有事务在修改表t1，事务T和队列中的某个事物要修改同一个表的数据，事务T和worker1是冲突的
2. 顺序判断事务T和每个worker队列的冲突关系，发现事务T跟worker2也冲突
3. 事务T跟多于一个worker冲突，coordinator线程进入等待
4. worker继续执行，同时修改hash_table，假设修改t3的事务先完成
5. coordinator发现跟事务T冲突的worker只有worker1，因此把它分配给worker1
6. coordinator继续读取下一个日志，继续分配事务
每个事务在分发的时候，跟所有worker冲突关系有：
- 如果跟所有worker都不冲突，分配给最空闲的
- 如果跟多于一个worker冲突，进入等待状态
- 如果只跟一个worker冲突，分配给存在冲突的worker
==这个按表分发的方案，在多个表负载均匀的场景里效果好==，如果碰到热点表，所有的更新事务都会涉及到一个表的时候，所有事务都会被分配到同一个worker中，就会变成单线程复制。

**按行分发策略**
解决热点表的并行复制问题，就需要一个按行并行复制的方案。核心思路：如果两个事务没有更新相同的行，那么在备库上可以并行执行，要求row格式的binlog。
基于行的策略需要同时考虑主键id以及唯一键，key应该是“库名+表名+索引a的名字+a的值”，例如`update t1 set a=1 where id=2`，解析的hash表：
- key=hash_func(db1+t1+“PRIMARY”+2), value=2; 这里value=2是因为修改前后的行id值不变，出现了两次。
- key=hash_func(db1+t1+“a”+2), value=1，表示会影响到这个表a=2的行
- key=hash_func(db1+t1+“a”+1), value=1，表示会影响到这个表a=1的行
==相比于表的并行分发策略，按行并行策略在决定线程分发的时候，需要消耗更多的计算资源==
以上两种方案约束条件：
1. 要能够从binlog解析出来表名、主键值和唯一索引的值，必须是row格式的binlog
2. 表必须有主键
3. 不能有外键。如果有外键，级联更新的行不会记录在binlog中，冲突检测不准确
对于3的解释参考：[Site Unreachable](https://zhuanlan.zhihu.com/p/489942393)，**被级联的操作不会被记录在binlog中**

按行分发策略的问题：
1. 耗费内存。例如一个语句要删除100w行数据，hash表就要记录100w个项
2. 耗费cpu。解析binlog，计算hash
所以，在实现按行分发的策略时，会设置一个阈值，单个事务如果超过设置的行数阈值，就暂时退化到单线程模式，退化逻辑：
- coordinator暂时hold住事务
- 等待所有worker都执行完成，变成空队列
- coordinator直接执行这个事务
- 恢复并行模式
---
**MySQL5.5版本的并行复制策略**
5.5版本不支持 并行复制

**MySQL5.6**
支持的粒度是按库并行，hash表里key就是数据库名。
这个策略的并行效果取决于各个DB的压力均衡。
相较于按表以及按行分发，有两个优势：
1. 构造hash值很快，只需要库名；并且一个实例上的DB数不多，不会出现要构造100w个项的情况
2. 不要求binlog的格式，statement格式的binlog也可以拿到库名

**MariaDB的并行复制策略**
MariaDB利用redo log组提交优化这个特性：
1. 能够在同一个组里提交的事务，一定不会修改同一行；如果修改同一行，就只能串行执行，而不能并行提交
2. 主库上可以并行执行的事务，备库上一定可以并行执行

---
实现上：
1. 一组里面一起提交的事务，有相同的commit_id，下一组就是commit_id+1
2. commit_id直接写到binlog中
3. 传到备库应用的时候，相同的commit_id事务分发到多个worker执行
4. 这一组全部执行完成后欧，coordinator再去取下一批
MariaDB策略目标就是“模拟主库的并行模式”，问题是没有实现“真正的模拟主库并发度”这个目标。
下图是主库并行事务，第一组事务提交完成的时候，下一组事务很快进入commit状态
![](MySQL/attachments/c7b4005111414c8db52a88ad733a5de2_MD5.jpeg)
按照MariaDB的并行复制策略，备库上的执行效果如下图：
![](MySQL/attachments/13ccdabb8e5a60692f7a084dd5646e0c_MD5.jpeg)
系统的吞吐量不够；并且很容易被大事务拖后腿，假设trx2是一个超大事务，备库应用的时候，trx1和trx3执行完成后，只能等待trx2完全执行完成，下一组才能执行，这段时间只有一个worker线程在工作。

**MySQL5.7**
参数slave-parallel-type参数控制并行复制策略：
1. DATABASE，使用MySQL5.6按库并行
2. LOGICAL_CLOCK，使用类似于MariaDB的策略

MariaDB策略的核心，是“所有处于commit”的事务可以并行，事务处于commit，表示已经通过了锁冲突的检测。
![](MySQL/attachments/03409c88013ab4df53f8335db6117058_MD5.jpeg)
其实只要能够达到redo log prepare阶段，就表示事务已经通过锁冲突的检测。
MySQL5.7并行复制策略的思想是：
1. 同时处于prepare的事务，备库使可以并行的
2. 处于prepare，与处于commit的事务之间，在备库执行也是可以并行的
binlog_group_commit_sync_delay、binlog_group_commit_sync_no_delay_count在binlog组提交的时候是故意拉长binlog从write到fsync的时间，减少binlog的写盘次数 ；在5.7并行复制策略中，可以用来制造更多的“同时处于prepare阶段的事务”，增加了备库复制的并行度。
==这两个参数，接可以故意让主库提交的慢些，也可以让备库执行的快些==

**MySQL5.7.22**
新增了基于WRITESET的并行复制。
参数binlog-transaction-dependency-tracking可选值：
- COMMIT_ORDER，根据同时进入prepare和commit判断是否可以并行的策略
- WRITESET，表示对于事务涉及的每一行，计算这一行的hash值，组成集合writeset。如果两个事务没有操作相同的行，writeset没有交集，就可以并行
- WRITESET_SESSION，比WRITESET多了一个约束，在主库上同一个线程先后执行的两个事务，备库执行时保证相同的先后顺序
hash值是通过“库名+表名+索引名+值”计算出来的。对于唯一索引，也要计算hash。
与前面介绍的按行分发的策略是差不多的，优势是：
1. writeset是在主库生成后直接写入到binlog中，备库执行的时候，不需要解析binlog的内容，节省了计算量
2. 不需要把整个事务的binlog扫描决定分发，更省内存
3. 由于备库的分发策略不依赖于binlog的内容，binlog是statement格式也是可以的
==对于没主键和外键约束的场景，WRITEWSET也是无法并行的，暂时退化到单线程模型==

**小结**
MySQL5.7版本的并行策略，修改了binlog的内容，协议不向上兼容。

**问题**：
假设一个MySQL 5.7.22版本的主库，单线程插入了很多数据，过了3个小时后，我们要给这个主库搭建一个相同版本的备库。
这时候，你为了更快地让备库追上主库，要开并行复制。在binlog-transaction-dependency-tracking参数的COMMIT_ORDER、WRITESET和WRITE_SESSION这三个取值中，你会选择哪一个呢？
你选择的原因是什么？如果设置另外两个参数，你认为会出现什么现象呢？
答案：
> 应该设置为WRITESET。主库是单线程，所以每个事务的commit_id不同，设置为COMMIT_ORDER模式，从库也只能单线程执行；WRITESET_SESSION要求备库应用日志的时候，同一个线程的日志必须与主库上执行的先后顺序相同，也会导致单线程执行。

## 27 主库出问题了，从库怎么办？
为了解决数据库层读性能问题，接下来讨论的架构师：一主多从。先谈论一主多从的切换正确性，下图是一个基本的一主多从结构。
![](MySQL/attachments/5c08cd7353d79873df09048f09e1928c_MD5.jpeg)
虚线箭头表示的是主备关系，A与A‘互为主备，从库B、C、D指向的是主库A。一主多从用于读写分离，主库复制所有的写入和一部分读，其他读请求由从库分担。
下图是主库发生故障，主备切换后的结果。
![](MySQL/attachments/3cfcbad5cd3789363b97dd14ec8b3b48_MD5.jpeg)
相比于一主一备，一主多从结构切换后A‘会成为新的主库，从库B、C、D要改接到A’。

**基于点位的主备切换**
节点B设置为节点A‘从库时，需要执行change master命令：
```sql
CHANGE MASTER TO MASTER_HOST=$host_name MASTER_PORT=$port MASTER_USER=$user_name MASTER_PASSWORD=$password MASTER_LOG_FILE=$master_log_name MASTER_LOG_POS=$master_log_pos
```
最后两个参数MASTER_LOG_FILE和MASTER_LOG_POS表示，要从主库的master_log_name文件的master_log_pos这个位置的日志继续同步。而这个位置就是我们所说的同步位点，也就是主库对应的文件名和日志偏移量。
相同的日志，点位是不同的，因此“找同步位点”这个操作是很难精确获取到。
一般取同步点位的方法是：
1. 等待新主库A'把relay log全部同步完成；
2. A‘上执行show master status，得到A’上最新的FIle和Position；
3. 取原主库故障的时刻T；
4. 用mysqlbiblog工具解析A‘的File，得到T时刻的位点
假设获取位点为123
但这个位点并不精确，因为在时刻T有可能A已经执行insert并将binlog传给A‘以及B，然后传完掉电。
这时系统状态：
- B上同步了binlog
- A’也同步了binlog，是在123之后
- B执行change master，指向A‘的123，会把insert又同步到B执行
B会报告Duplicate entry ‘id_of_R’ for key ‘PRIMARY’ 错误，提示出现了主键冲突，然后停止同步。

**通常情况下，切换任务的时候，要主动跳过错误**
两种做法：
一种是主动跳过一个事务，sql_slave_skip_counter
另一种是跳过指定的错误，slave_skip_errors，通常跳过：
- 1062错误是插入数据时唯一键冲突；
- 1032错误是删除数据时找不到行。
等到主备同步关系建立完成，并稳定执行一段时间后，需要将slave_skip_errors设置为空，以免出现主从不一致。

**GTID**
通过跳过事务和忽略错误的方法，虽然最终都可以建立从库B和新主库A‘的主备关系，但操作都很复杂，容易出错。MySQL5.6引入GTID。
GTID全程Global Transaction Identifier，全局事务ID，是一个事务在提交的时候生成的，是这个事务的唯一表示。格式为：
`GTID=server_uuid:gno`
其中server_uuid是一个实例第一次启动自动生成的，是一个全局唯一的值；gno是一个整数，初始值是1，每次提交事务的时候分配给这个事务并加1；
官方文档里定义为：`GTID=source_id:transcation_id`与上面表示是一样的，只是这种方式会造成误解。
GTID模式的启动需要启动MySQL实例的时候加上参数gtid_mode=on, enforce_gtid_consistency=on。
GTID的是两种生成方式：
1. gtid_next=automatic，代表使用默认值。MySQL会把server_uuid:gno分配给这个事务。
2. gtid是一个指定的值，例如gtid_next='current_gtid'，那么有两种可能：
	1. 如果current值已经存在实例的GTID集合中，接下来执行的事务会被忽略
	2. 如果不存在，就将这个current分配给接下来的事务
每个MySQL实例都维护了一个GTID集合，对应“这个实例执行过的所有的事务”。

**基于GTID的主备切换**
GTID模式下，备库B设置为新主库A‘的从库的语法为：
```sql
CHANGE MASTER TO MASTER_HOST=$host_name MASTER_PORT=$port MASTER_USER=$user_name MASTER_PASSWORD=$password master_auto_position=1
```
master_auto_position=1表示主备关系使用的GTID协议，不需要执行位点。
主备切换逻辑，实例A‘的GTID集合记为set_a，实例B的GTID集合记为set_b：
1. 实例B指定主库A‘，基于主备协议建立连接
2. 实例B把set_b发给主库A‘
3. 实例A’计算两个集合的差集，存在于set_a，不存在set_b的集合，判断A‘本地是否已经包含了这个差集需要的所有binlog日志。
	1. 如果不包含，说明A’已经把实例B需要的binlog删除了，直接返回错误
	2. 如果包含，A‘从自己的binlog文件中，找到第一个不在set_b的事务，发给B
设计思想：基于GTID的主备关系，只要建立主备关系，就必须保证主库发给备库的日志是完整的。

基于位点的协议，由备库指定位点，不做日志完整性判断。

**GTID和在线DDL**
之前探讨业务高峰期慢查询，分析到如果是由于索引缺失引起的性能问题，可以通过在线加索引解决。考虑到避免新索引对主库性能造成的影响，可以现在备库加索引，然后再切换。
双M结构下，备库执行的DDL语句会回传给主库，为了避免传回后对主库造成影响，通过set sql_log_bin=off关掉binlog。
提出了一个问题：这样操作的话，数据库里面是加了索引，但是binlog并没有记录下这一个更新，是不是会导致数据和日志不一致？
GTID可以解决这个问题；假设，这两个互为主备关系的库还是实例X和实例Y，且当前主库是X，并且都打开了GTID模式。这时的主备切换流程可以变成下面这样：
- 在实例X上执行stop slave。
- 在实例Y上执行DDL语句。注意，这里并不需要关闭binlog。
- 执行完成后，查出这个DDL语句对应的GTID，并记为 server_uuid_of_Y:gno。
- 到实例X上执行以下语句序列：
	> set GTID_NEXT="server_uuid_of_Y:gno"; begin; 
	> commit; 
	> set gtid_next=automatic; 
	> start slave;
	
这样既可以让实例Y更新有binlog日志，同时确保不会再实例X上执行这条更新。
- 接下来，执行主备切换，按照以上流程再执行一边

**问题：**
你在GTID模式下设置主从关系的时候，从库执行start slave命令后，主库发现需要的binlog已经被删除掉了，导致主备创建不成功。这种情况下，你觉得可以怎么处理呢？
答案：
> 1. 如果业务允许主从不一致的情况，那么可以在主库上先执行show global variables like ‘gtid_purged’，得到主库已经删除的GTID集合，假设是gtid_purged1；然后先在从库上执行reset master，再执行set global gtid_purged =‘gtid_purged1’；最后执行start slave，就会从主库现存的binlog开始同步。binlog缺失的那一部分，数据在从库上就可能会有丢失，造成主从不一致
> 2. 如果需要主从数据一致的话，最好还是通过重新搭建从库来做。
> 3. 如果有其他的从库保留有全量的binlog的话，可以把新的从库先接到这个保留了全量binlog的从库，追上日志以后，如果有需要，再接回主库。
> 4. 如果binlog有备份的情况，可以先在从库上应用缺失的binlog，然后再执行start slave。

## 28 读写分离有哪些坑？
一主多从架构的经典应用场景：读写分离，如何处理主备延迟导致的读写分离问题。
读写分离的基本结构如下：
![](MySQL/attachments/8d7df217cdedc4576d47a5d195228ec0_MD5.jpeg)
读写分离的目的是分摊主库的压力。上面是client主动做负载均衡，将数据库的连接信息放在client的连接层。
下面是MySQL和client中间有一个proxy，client连接proxy，由代理根据请求类型以及上下文决定请求的分发路由。
![](MySQL/attachments/809319e4f22ffd2f6906591cda0361a0_MD5.jpeg)
各自的特点：
1. 客户端直连方案，因为少了一层proxy转发，所以查询性能稍微好一点儿，并且整体架构简单，排查问题更方便。但是这种方案，由于要了解后端部署细节，所以在出现主备切换、库迁移等操作的时候，客户端都会感知到，并且需要调整数据库连接信息。你可能会觉得这样客户端也太麻烦了，信息大量冗余，架构很丑。其实也未必，一般采用这样的架构，一定会伴随一个负责管理后端的组件，比如Zookeeper，尽量让业务端只专注于业务逻开发。
2. 带proxy的架构，对客户端比较友好。客户端不需要关注后端细节，连接维护、后端信息维护等工作，都是由proxy完成的。但这样的话，对后端维护团队的要求会更高。而且，proxy也需要有高可用架构。因此，带proxy架构的整体就相对比较复杂。

目前趋势是proxy架构方向。
**这种“在从库上会读到系统的一个过期状态”的现象，在这篇文章里，我们暂且称之为“过期读”。**
解决的方案有：
- 强制走主库方案；
- sleep方案；
- 判断主备无延迟方案；
- 配合semi-sync方案；
- 等主库位点方案；
- 等GTID方案。

**强制走主库方案**
将请求做分类：
1. 必须拿到最新结果的请求，强制将其发到主库上。
2. 对于可以读到旧数据的请求，才将其发到从库上
但是，在一些“所有查询都不能是过期读”的场景下，就必须放弃读写分离，所有读写压力都在主库上，放弃了拓展性。

接下来的方案是可以支持读写分离的场景下，有哪些解决过期读的方案。

**Sleep方案**
主库更新后，从库先sleep以下。类似于执行select sleep(1)。
这个方案的假设是：大多数情况下主备延迟在1s之内，做一个sleep可以有很大概率拿到最新的数据。
但从严格意义上讲，这个方案存在的问题就是不精确：
1. 如果这个请求本来0.5s可以拿到最新结果，也会等1s
2. 如果延迟超过1s，还是会出现过期读

**判断主备无延迟方案**
确保备库无延迟，有三种做法。
==第一种做法是，每次从库执行查询请求前判断seconds_behind_master是否已经等于0==。如果还不等于0，等到参数变成0才能执行查询请求。
SBM单位是秒，精度不够还可以使用对比位点和GTID的方法确保主备无延迟。
以下是show slave status的结果截图：
![](MySQL/attachments/4e20f185eeee0f4a4594678950778e9a_MD5.jpeg)
==第二种方法，对比位点确保主备无延迟==
- Master_Log_File和Read_Master_Log_Pos，表示的是读到的主库的最新位点；
- Relay_Master_Log_File和Exec_Master_Log_Pos，表示的是备库执行的最新位点。
如果Master_Log_File和Relay_Master_Log_File、Read_Master_Log_Pos和Exec_Master_Log_Pos这两组值完全相同，就表示接收到的日志已经同步完成。
==第三种方法，对比GTID集合确保主备无延迟==
- Auto_Position=1 ，表示这对主备关系使用了GTID协议。
- Retrieved_Gtid_Set，是备库收到的所有日志的GTID集合；
- Executed_Gtid_Set，是备库所有已经执行完成的GTID集合。
如果这两个集合相同，也表示备库接收到的日志都已经同步完成。

第二、三种方法都比判断SBM是否为0准确。
相比于sleep方案，这三种方法准确度确实提高了，但是还没有达到精确的程度。
一个事务的binlog在主备库之间的状态：
1. 主库执行完成，写入binlog，并反馈给客户端；
2. binlog被从主库发送给备库，备库收到；
3. 在备库执行binlog完成。
上面判断主备无延迟的逻辑，是“备库收到的日志都执行完了”。但是还有一部分日志是客户端已经收到提交确认，备库还未收到日志的状态。
![](MySQL/attachments/d717231ae9cc79e91890c5e2c4e589bc_MD5.jpeg)
这时，主库上执行完成了三个事务trx1、trx2和trx3，其中
- trx1和trx2已经传到从库，并且已经执行完成了；
-  trx3在主库执行完成，并且已经回复给客户端，但是还没有传到从库中。
从库认为没有同步延迟，但还是查不到trx3，出现了过期读。

**配合semi-sync**
引入半同步复制，semi-sync replication。
semi-sync设计是：
1. 事务提交的时候，主库把binlog发给从库；
2. 从库收到binlog以后，发回给主库一个ack，表示收到了；
3. 主库收到这个ack以后，才能给客户端返回“事务完成”的确认。
也就是说，如果启用了semi-sync，就表示所有给客户端发送过确认的事务，都确保了备库已经收到了这个日志。

但semi-sync+位点判断的方案，只对一主一从的场景是成立的。一主多从的场景中，主库只需要等到一个从库的ack，就对客户端返回确认。这时，在从库上执行查询，就有可能产生过期读的问题。
其次，如果在业务更新的高峰期，主库的位点或者GTID集合更新很快，那么上面的两个位点等值判断就会一直不成立，很可能出现从库上迟迟无法响应查询请求的情况。

实际上，回到我们最初的业务逻辑里，当发起一个查询请求以后，我们要得到准确的结果，其实**并不需要等到“主备完全同步”**。
![](MySQL/attachments/ec3e523496340bc86ca8fa2b58b9be29_MD5.jpeg)
上图就是一个等待位点方案的bad case。从状态1到状态4一直处于延迟一个事务的状态。
但是，其实客户端是在发完trx1更新后发起的select语句，我们只需要确保trx1已经执行完成就可以执行select语句了。也就是说，如果在状态3执行查询请求，得到的就是预期结果了。

到这里，我们小结一下，semi-sync配合判断主备无延迟的方案，存在两个问题：
1. 一主多从的时候，在某些从库执行查询请求会存在过期读的现象；
2. 在持续延迟的情况下，可能出现过度等待的问题。

**等主库位点方案**
`select master_pos_wait(file, pos[, timeout]);`
这条命令的逻辑如下：
1. 它是在从库执行的；
2. 参数file和pos指的是主库上的文件名和位置；
3. timeout可选，设置为正整数N表示这个函数最多等待N秒。
这个命令正常返回的结果是一个正整数M，表示从命令开始执行，到应用完file和pos表示的binlog位置，执行了多少事务。
当然，除了正常返回一个正整数M外，这条命令还会返回一些其他结果，包括：
4. 如果执行期间，备库同步线程发生异常，则返回NULL；
5. 如果等待超过N秒，就返回-1；
6. 如果刚开始执行的时候，就发现已经执行过这个位置了，则返回0。

对于先执行trx1，在执行一个查询请求的逻辑，要保证能够查到正确的数据，可以使用这个逻辑：
1. trx1事务更新完成后，马上执行show master status得到当前主库执行到的File和Position；
2. 选定一个从库执行查询语句；
3. 在从库上执行select master_pos_wait(File, Position, 1)；
4. 如果返回值是>=0的正整数，则在这个从库执行查询语句；
5. 否则，到主库执行查询语句。
![](MySQL/attachments/56e004c919f86279d58c2fa2b5861903_MD5.jpeg)

**GTID方案**
`select wait_for_executed_gtid_set(gtid_set, 1);`
这条命令的逻辑是：
1. 等待，直到这个库执行的事务中包含传入的gtid_set，返回0；
2. 超时返回1。
在前面等位点的方案中，我们执行完事务后，还要主动去主库执行show master status。而MySQL 5.7.6版本开始，允许在执行完更新类事务后，把这个事务的GTID返回给客户端，这样等GTID的方案就可以减少一次查询。
这时，等GTID的执行流程就变成了：
3. trx1事务更新完成后，从返回包直接获取这个事务的GTID，记为gtid1；
4. 选定一个从库执行查询语句；
5. 在从库上执行 select wait_for_executed_gtid_set(gtid1, 1)；
6. 如果返回值是0，则在这个从库执行查询语句；
7. 否则，到主库执行查询语句。

等待超时后是否直接到主库查询，需要业务开发考虑限流。
怎么能够让MySQL在执行事务后，返回包中带上GTID呢？
将参数session_track_gtids设置为OWN_GTID，然后通过API接口mysql_session_track_get_first从返回包解析出GTID的值即可。

**小结**
一主多从做读写分离，可能会碰到过期读的场景。
虽然最后等待位点和等待GTID这两个方案比较准确，但是如果从库读延迟，那么请求就会全部落在主库上，这是可能会由于压力增大，把主库打挂。
在实际应用中，这几种方案是可以混合使用的：现在客户端对请求做分类，区分哪些请求可以接收过期读，哪些请求完全不能接收过期读；对不能接收过期读的语句，在使用等GTID或等位点的方案。

**问题**
假设你的系统采用了我们文中介绍的最后一个方案，也就是等GTID的方案，现在你要对主库的一张大表做DDL，可能会出现什么情况呢？为了避免这种情况，你会怎么做呢？
答案：
> 假设，这条语句在主库上要执行10分钟，提交后传到备库就要10分钟（典型的大事务）。那么，在主库DDL之后再提交的事务的GTID，去备库查的时候，就会等10分钟才出现。
> 这样，这个读写分离机制在这10分钟之内都会超时，然后走主库。
> 这种预期内的操作，应该在业务低峰期的时候，确保主库能够支持所有业务查询，然后把读请求都切到主库，再在主库上做DDL。等备库延迟追上以后，再把读请求切回备库。
> 当然了，使用gh-ost方案来解决这个问题也是不错的选择。

