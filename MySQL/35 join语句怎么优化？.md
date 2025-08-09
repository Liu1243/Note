上一节介绍了join的两种算法，分别是Index Nested-Loop join（NLJ）和Block Nested-Loop Join（BNL）。
NLJ算法效果不错；BNL算法在大表join的性能差，比较次数等于两个表参与join的行数的乘积，消耗cpu资源。
这两个算法还有优化空间。

## Multi-Range Read优化
MRR优化的目的是尽量使用顺序读盘。
InnoDB在普通索引a上查到主键id的值后，再根据一个个主键id的值到主键索引上去查整行数据的过程，称为回表。
回表过程是一行行查数据，还是批量的查数据？
主键索引是一棵B+树，在这棵树上，每次只能根据一个主键id查到一行数据。因此，回表肯定是一行行搜索主键索引的。
![](MySQL/attachments/a63366db5b1ce425aecb5eb05dcea00a_MD5.jpeg)
如果a的值递增顺序查询，id的值为随机，那么就会出现随机访问，性能差。
**因为大多数的数据都是按照主键递增顺序插入得到的，所以我们可以认为，如果按照主键的递增顺序查询的话，对磁盘的读比较接近顺序读，能够提升读性能。**
MRR优化思路：
1. 根据索引a，定位到满足条件的记录，将id值放入read_rnd_buffer中;
2. 将read_rnd_buffer中的id进行递增排序；
3. 排序后的id数组，依次到主键id索引中查记录，并作为结果返回。
read_rnd_buffer的大小是由read_rnd_buffer_size参数控制的。如果你想要稳定地使用MRR优化的话，需要设置`set optimizer_switch="mrr_cost_based=off"`。（官方文档的说法，是现在的优化器策略，判断消耗的时候，会更倾向于不使用MRR，把mrr_cost_based设置为off，就是固定使用MRR了。）
![](MySQL/attachments/9bc1bea61070096b5912a01fa347e8f2_MD5.jpeg)
![](MySQL/attachments/e660b6c64490ce327523698aa5f7ba6a_MD5.jpeg)
Extra字段多了Using MRR，表示用了MRR优化。
**MRR能够提升性能的核心**在于，这条查询语句在索引a上做的是一个范围查询（也就是说，这是一个多值查询），可以得到足够多的主键id。这样通过排序以后，再去主键索引查数据，才能体现出“顺序性”的优势。

## Batched Key Access
理解了MRR性能提升的原理，我们就能理解MySQL在5.6版本后开始引入的Batched Key Acess(BKA)算法了。这个BKA算法，其实就是对NLJ算法的优化。
NLJ算法流程图：
![](MySQL/attachments/a3b48b3e47951e48f0c79706b05e10bb_MD5.jpeg)
NLJ算法执行的逻辑是：从驱动表t1，一行行地取出a的值，再到被驱动表t2去做join。也就是说，对于表t2来说，每次都是匹配一个值。这时，MRR的优势就用不上了。
把表t1数据取出来，放在临时缓存join_buffer中。
![](MySQL/attachments/db754c07642ac698021b1d7950dfd823_MD5.jpeg)
如果要使用BKA优化算法的话，你需要在执行SQL语句之前，先设置
`set optimizer_switch='mrr=on,mrr_cost_based=off,batched_key_access=on';`
前两个启用MRR，原因是BKA算法的优化依赖于MRR。

## BNL算法的性能问题
BNL算法可能会对被驱动表做多次扫描，如果被驱动表是一个很大的冷数据表，那么会造成IO压力大。
InnoDB对Buffer Pool的LRU算法做了优化：第一次从磁盘读入内存的数据页，会放在old区域；如果1s后这个数据也不再被访问了，就不会被移动到LRU链表头部，对Buffer Pool的命中率影响不大。
但是如果一个使用BNL算法的join语句，多次扫描一个冷表，并且语句执行时间超过1s，就会在再次扫描冷表的时候把冷表的数据页放在LRU链表头部。
这种情况对应的，是冷表的数据量小于整个Buffer Pool的3/8，能够完全放入old区域的情况。
如果这个冷表很大，就会出现另外一种情况：业务正常访问的数据页，没有机会进入young区域。
**大表join操作虽然对IO有影响，但是在语句执行结束后，对IO的影响也就结束了。但是，对Buffer Pool的影响就是持续性的，需要依靠后续的查询请求慢慢恢复内存命中率。**

也就是说，BNL算法对系统的影响主要包括三个方面：
1. 可能会多次扫描被驱动表，占用磁盘IO资源；
2. 判断join条件需要执行M\*N次对比（M、N分别是两张表的行数），如果是大表就会占用非常多的CPU资源；
3. 可能会导致Buffer Pool的热数据被淘汰，影响内存命中率。

## BNL转BKA
一些情况下，我们可以直接在被驱动表上建索引，这时就可以直接转成BKA算法了。
但是，有时候你确实会碰到一些不适合在被驱动表上建索引的情况。比如：
`select * from t1 join t2 on (t1.b=t2.b) where t2.b>=1 and t2.b<=2000;`
如果这条语句同时是一个低频的SQL语句，那么再为这个语句在表t2的字段b上创建一个索引就很浪费了。
这时候可以考虑使用临时表：
1. 把表t2中满足条件的数据放在临时表tmp_t中；
2. 为了让join使用BKA算法，给临时表tmp_t的字段b加上索引；
3. 让表t1和tmp_t做join操作。
```sql
create temporary table temp_t(id int primary key, a int, b int, index(b))engine=innodb; 
insert into temp_t select * from t2 where b>=1 and b<=2000; 
select * from t1 join temp_t on (t1.b=temp_t.b);
```
总体来看，不论是在原表上加索引，还是用有索引的临时表，我们的思路都是让join语句能够用上被驱动表上的索引，来触发BKA算法，提升查询性能。

## 拓展-hash join
MySQL的优化器和执行器一直被诟病的一个原因：不支持哈希join。
实际上，这个优化思路，我们可以自己实现在业务端。实现流程大致如下：
1. `select * from t1;`取得表t1的全部1000行数据，在业务端存入一个hash结构，比如C++里的set、PHP的dict这样的数据结构。
2. `select * from t2 where b>=1 and b<=2000;` 获取表t2中满足条件的2000行数据。
3. 把这2000行数据，一行一行地取到业务端，到hash结构的数据表中寻找匹配的数据。满足匹配的条件的这行数据，就作为结果集的一行。

## 小结
1. BKA优化是MySQL已经内置支持的，建议你默认使用；
2. BNL算法效率低，建议你都尽量转成BKA算法。优化的方向就是给被驱动表的关联字段加上索引；
3. 基于临时表的改进方案，对于能够提前过滤出小数据的join语句来说，效果还是很好的；
4. MySQL目前的版本还不支持hash join，但你可以配合应用端自己模拟出来，理论上效果要好于临时表的方案。

## 问题
我们在讲join语句的这两篇文章中，都只涉及到了两个表的join。那么，现在有一个三个表join的需求，假设这三个表的表结构如下：
```sql
CREATE TABLE `t1` ( 
	`id` int(11) NOT NULL, 
	`a` int(11) DEFAULT NULL, 
	`b` int(11) DEFAULT NULL, 
	`c` int(11) DEFAULT NULL, 
	PRIMARY KEY (`id`) 
) ENGINE=InnoDB; 
create table t2 like t1; 
create table t3 like t2; 
insert into ... //初始化三张表的数据
```
join逻辑
`select * from t1 join t2 on(t1.a=t2.a) join t3 on (t2.b=t3.b) where t1.c>=X and t2.c>=Y and t3.c>=Z;`
现在为了得到最快的执行速度，如果让你来设计表t1、t2、t3上的索引，来支持这个join语句，你会加哪些索引呢？
同时，如果我希望你用straight_join来重写这个语句，配合你创建的索引，你就需要安排连接顺序，你主要考虑的因素是什么呢？
答案：
> 第一原则是要尽量使用BKA算法。需要注意的是，使用BKA算法的时候，并不是“先计算两个表join的结果，再跟第三个表join”，而是直接嵌套查询的。
> 具体实现是：在t1.c>=X、t2.c>=Y、t3.c>=Z这三个条件里，选择一个经过过滤以后，数据最少的那个表，作为第一个驱动表。此时，可能会出现如下两种情况。
> 第一种情况，如果选出来是表t1或者t3，那剩下的部分就固定了。
> 1. 如果驱动表是t1，则连接顺序是t1->t2->t3，要在被驱动表字段创建上索引，也就是t2.a 和 t3.b上创建索引；
> 2. 如果驱动表是t3，则连接顺序是t3->t2->t1，需要在t2.b 和 t1.a上创建索引。
> 同时，我们还需要在第一个驱动表的字段c上创建索引。
> 以下是联合索引，减少回表：
> ALTER TABLE t1 ADD INDEX idx_c_a (c, a);
  ALTER TABLE t2 ADD INDEX idx_a_c_b (a, c, b);
  ALTER TABLE t3 ADD INDEX idx_b_c (b, c);
> 第二种情况是，如果选出来的第一个驱动表是表t2的话，则需要评估另外两个条件的过滤效果。
> 总之，整体的思路就是，尽量让每一次参与join的驱动表的数据集，越小越好，因为这样我们的驱动表就会越小。
> CREATE INDEX idx_c_a_b ON t2(c, a, b);
> CREATE INDEX idx_a_c ON t1(a, c);
> CREATE INDEX idx_b_c ON t3(b, c);