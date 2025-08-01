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
![](MySQL/attachments/7096a908257b225cfb7ecccec70b7d03_MD5.jpeg)
for update使用的是当前读
其中，Q3读到id=1这一行的现象，被称为“幻读”。也就是说，幻读指的是一个事务在前后两次查询同一个范围的时候，后一次查询看到了前一次查询没有看到的行。

“幻读”的说明：
1. 在可重复读隔离级别下，普通的查询是快照读，是不会看到别的事务插入的数据的。因此，幻读在“当前读”下才会出现。
2. 上面session B的修改结果，被session A之后的select语句用“当前读”看到，不能称为幻读。幻读仅专指“新插入的行”。
从事物的可见性规则来分析，上述结果没有问题。
**幻读有什么问题？**
**首先是语义上的**，sessionA中T1时刻“把d=5的行锁住”，这个语义被破坏了。sessionB、sessionC按理来说应该是要被阻塞的，虽然在顺序上加锁的时刻还没有看到sessionB与sessionC的操作。

**其次是数据一致性的问题**
![](MySQL/attachments/e8a0c15ef4dc37ce4762abdf9e6c2fa0_MD5.jpeg)
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
![](MySQL/attachments/365fa7a8234432f9e9a3fab8bb06ac11_MD5.jpeg)
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
![](MySQL/attachments/4422ee2bc77ff409cbf0a0f753832294_MD5.jpeg)
这样加了6个行锁，7个间隙锁，确保了无法再插入新的记录。
间隙锁和行锁合称next-key lock，前开后闭区间， (-∞,0]、(0,5]、(5,10]、(10,15]、(15,20]、(20, 25]、(25, +supremum]
supremum是一个不存在的最大值，是为了符合前开后闭区间这一规则
==间隙锁和next-key lock的引入解决了幻读的问题，但也会存在一些问题（死锁）==
![](MySQL/attachments/54430050289c71a3ef44f130824f7ef9_MD5.jpeg)
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
![](MySQL/attachments/3c1bafb7478c8d7b5d809f043d7b69a9_MD5.jpeg)
1. 原则1，加锁单位为next-key lock，sessionA加锁范围为(5, 10]
2. 优化2，next-key lock退化为间隙锁，(5, 10)
所以最终id=8插入会被阻塞，id=10的更新ok

**案例二：非唯一索引等值锁**
![](MySQL/attachments/3071bd13b6424f35e49112cef7074ee0_MD5.jpeg)
1. 原则1，(0, 5]加next-key lock
2. 但是c是普通索引，需要向右遍历，直到查询到c=10；根据原则2，访问到的对象都要加锁，(5, 10]
3. 优化2，第二个next-key lock退化为间隙锁，(5, 10)
4. 原则2，该查询使用覆盖索引，并不需要访问主键索引，所以主键索引上没有加任何锁，因此sessionB的update语句可以执行
sessionC会被sessionA的(5, 10)间隙锁锁住；需要注意，lock in share mode只会锁覆盖索引，如果是for update，系统会认为接下来需要更新数据，会顺便在主键索引上满足条件的行加行锁。
==锁是加在索引上的==，如果要用lock in share mode给行加锁避免数据被更新，必须绕过覆盖索引的优化，在查询字段中加入索引中不存在的字段

==案例三：主键索引范围锁==
![](MySQL/attachments/029f4df569a620163feb3d1d9ade1785_MD5.jpeg)
1. 找到第一个id=10的行，next-key lock(5, 10]，根据优化1，退化为行锁id=10
2. 范围查询继续往后找，找到id=15停下，原则2，next-key lock(10, 15]
for update，sessionA锁的范围在主键索引上，行锁id=10，next-key lock(10, 15]
注意，首次id=10是等值查询来判断的，向右扫描到id=15的时候，使用的是范围查询判断

**案例四：非唯一索引范围锁**
![](MySQL/attachments/692b50a1955dda3038cb5793a2c557e4_MD5.jpeg)
c=10定位记录，索引c加next-key lock(5, 10]，c是非唯一索引，没有优化1，不会蜕变为行锁；第二个c=15是范围查询，加next-key lock(10, 15]；

**案例五：唯一索引范围锁bug**
![](MySQL/attachments/ca1333b4953cd2ad0833d99f43ed4ff7_MD5.jpeg)
首先是索引id加上next-key lock(10, 15]，因为id是唯一索引，所以循环判断到id=15应该停止。
但是事实上，InnoDB会往前扫描第一个不满足条件的行为止，也就是id=20。由于是范围扫描，会加next-key lock(15, 20]
所以这是一个bug

**案例六：非唯一索引上存在“等值”的情况**
![](MySQL/attachments/286f4fed8bf3a97b948de1fe4667f324_MD5.jpeg)
![](MySQL/attachments/72522034276cbd41e77d6e781941d8a7_MD5.jpeg)
首先访问第一个c=10的记录，按照原则1，加next-key lock（c=5，id=5）到（c=10，id=10）
c不是唯一索引，向右查找，直到碰到（c=15，id=15）这一行循环结束。根据优化2，等值查询向右查询到不满足条件的行，会退化为（c=10，id=10）到（c=15，id=15）的间隙锁
加锁范围是如下蓝色区域覆盖的部分，虚线表示开区间
![](MySQL/attachments/7b5c4db403adb54e0462244078980472_MD5.jpeg)

**案例七：limit语句加锁**
![](MySQL/attachments/11cc70347275ac0342ac10cd46d2c672_MD5.jpeg)
sessionA的delete语句加了limit 2。而表t里c=10记录就两条，加不加limit 2，删除的效果都是一样的，但是加锁的效果却不同。
这是因为，因为limit 2，在遍历到（c=10，id=30）这一行之后，满足条件的语句已经有两条，循环就结束了
所以索引c加锁范围就从（c=5，id=5）到（c=10，id=30）前开后闭区间
![](MySQL/attachments/227805395e8f4dde5d385846a638c840_MD5.jpeg)
==指导意义就会死删除数据的时候尽量加limit==，不仅可以控制删除数据的条目，让操作更安全，还可以减少加锁的范围

**案例八：一个死锁的例子**
next-key lock实际上是间隙锁和行锁加起来的结果
![](MySQL/attachments/d709ebbce5216f9ea4bc5c3f812c45a7_MD5.jpeg)
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
![](MySQL/attachments/4277873ed3468980a82889de445e9c34_MD5.jpeg)
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
![](MySQL/attachments/eca3b7d2dd8f55792c99aecc57497bd7_MD5.jpeg)
如果断开sessionA连接，因为还未提交，只能回滚；而断开sessionB没有影响。
如何判断事务外空闲呢？
![](MySQL/attachments/aa95a5b92a5e9dd8eb25416c1f070b7b_MD5.jpeg)
id=4与id=5都是sleep状态，查看事务具体状态，查看information_schema库的innodb_trx表
![](MySQL/attachments/75f1837b421dd7128c135bb2023c040b_MD5.jpeg)
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
![](MySQL/attachments/523ea72af2012ef83102b758b72d326a_MD5.jpeg)
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
![](MySQL/attachments/b5faa30455fde8ba63fe44e3b17a1538_MD5.jpeg)
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

![](MySQL/attachments/3478c3caa0f7551d76415b36fb38e9e6_MD5.jpeg)
1. trx1第一个到达，被选为这组的leader；
2. 等trx1写盘的时候，组里面已经有三个事务，LSN变为160；
3. trx1写盘的时候，带LSN=160，等trx1返回时，所有LSN小于等于160的redo log都已经被持久化到磁盘中
4. trx2、trx3直接返回
一次group commit中，组员越多，节约磁盘IOPS越好。并发场景下，第一个事务写完redo log buffer，接下来fsync越晚调用，组员会更多，节约的IOPS效果越好。
==MySQL优化是拖时间==，将redo log的fsync拖到binlog write之后。
![](MySQL/attachments/ee38e761241445d9e84b61656a266bce_MD5.jpeg)
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

