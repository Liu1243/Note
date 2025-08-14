MySQL对自增主键做了优化，申请到自增id以后，就释放自增锁。
但仅仅是”普通的insert语句“才有效。有些情况下insert需要给其他资源加锁，或者无法在申请到自增id后立马释放锁。

## insert...select语句
可重复读隔离级别下，binlog_format=statement执行：
`insert into t2(c,d) select c,d from t;`
考虑以下执行序列：
![](MySQL/attachments/c58e5a465b84a508730b5858b9d6d00a_MD5.jpeg)
如果sessionB先执行，就会对表t主键索引加(-∞,1]这个next-key lock，语句执行完后，才允许sessionA的insert执行。
如果没有锁，可能出现sessionB先执行，但是后写binlog的情况。

## insert循环写入
要往t2中插入一行数据，这一行的c值是表t中c值最大值加1.
`insert into t2(c,d) (select c+1, d from t force index(c) order by c desc limit 1);`
加锁范围是表t索引c上(3, 4]和(4, supermum)这两个next-key lock，以及主键索引id=4这一行。
它的执行流程也比较简单，从表t中按照索引c倒序，扫描第一行，拿到结果写入到表t2中。
![](MySQL/attachments/a313028f78ad132a17644a8db6dda163_MD5.jpeg)
Rows_examined=1，扫描行数为1.

但如果执行
`insert into t(c,d) (select c+1, d from t force index(c) order by c desc limit 1);`
Row_examined=5，explain结果是：
![](MySQL/attachments/95eb1f8239054cbef56af8495ae4ac57_MD5.jpeg)
Extra中有Using temporary字段，使用到了临时表。执行过程中，需要把表t的内容读出来，写入临时表。
1. 创建临时表，表里有两个字段c和d。
2. 按照索引c扫描表t，依次取c=4、3、2、1，然后回表，读到c和d的值写入临时表。这时，Rows_examined=4。
3. 由于语义里面有limit 1，所以只取了临时表的第一行，再插入到表t中。这时，Rows_examined的值加1，变成了5。
这个语句会导致在表t上做全表扫描，并且会给索引c上的所有间隙都加上共享的next-key lock。所以，这个语句执行期间，其他事务不能在这个表上插入数据。
因为MySQL防止写入影响读，所以使用临时表。
优化为创建单独的内存临时表，而不是源表与目标表一致：
`create temporary table temp_t(c int,d int) engine=memory;`

## insert唯一键冲突
![](MySQL/attachments/8f3a31f18a57d48f366b5f572d399e13_MD5.jpeg)
在可重复读隔离级别下执行的。
session A持有索引c上的(5,10]共享next-key lock（读锁）。可能是为了防止这一行被其他事务删除。

以下是一个景点的死锁场景：
![](MySQL/attachments/243681921f0db2eb80d90ab4eb0795f7_MD5.jpeg)
死锁逻辑为：
1. 在T1时刻，启动session A，并执行insert语句，此时在索引c的c=5上加了记录锁。注意，这个索引是唯一索引，因此退化为记录锁
2. 在T2时刻，session B要执行相同的insert语句，发现了唯一键冲突，加上读锁；同样地，session C也在索引c上，c=5这一个记录上，加了读锁。
3. T3时刻，session A回滚。这时候，session B和session C都试图继续执行插入操作，都要加上写锁。两个session都要等待对方的行锁，所以就出现了死锁。
![](MySQL/attachments/2e1aa1fbde51cba4fa92221f54aa4234_MD5.jpeg)

## insert into...on duplicate key update
如果是：
`insert into t values(11,10,10) on duplicate key update d=100;`
会给索引c上(5, 10]上加一个next-key lock。
**insert into … on duplicate key update 这个语义的逻辑是，插入一行数据，如果碰到唯一键约束，就执行后面的更新语句。**
如果多个列违反了唯一性约束，就会按照索引的顺序，修改跟第一个索引冲突的行。
假设已经有了(1,1,1)和(2,2,2)这两行，
![](MySQL/attachments/9126203b29566056a2b9c5d3044fb613_MD5.jpeg)
主键id先判断，和id=2这一行冲突，所以修改的是id=2的行。
需要注意的是，执行这条语句的affected rows返回的是2，很容易造成误解。实际上，真正更新的只有一行，只是在代码实现上，insert和update都认为自己成功了，update计数加了1， insert计数也加了1。

## 小结
insert … select 是很常见的在两个表之间拷贝数据的方法。你需要注意，在可重复读隔离级别下，这个语句会给select的表里扫描到的记录和间隙加读锁。
而如果insert和select的对象是同一个表，则有可能会造成循环写入。这种情况下，我们需要引入用户临时表来做优化。
insert 语句如果出现唯一键冲突，会在冲突的唯一值上加共享的next-key lock(S锁)。因此，碰到由于唯一键约束导致报错后，要尽快提交或回滚事务，避免加锁时间过长。