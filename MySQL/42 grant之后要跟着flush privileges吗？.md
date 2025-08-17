创建用户：
`create user 'ua'@'%' identified by 'pa';`
这条语句的逻辑是创建一个用户’ua’@’%’，密码是pa。注意，在MySQL里面，用户名(user)+地址(host)才表示一个用户，因此 ua@ip1 和 ua@ip2代表的是两个不同的用户。
这个命令的含义是：
1. 磁盘上，向mysql.user表里插入一行，由于没有指定权限，所以这行数据上所有表示权限的字段的值都是N；
2. 内存里，往数组acl_users里插入一个acl_user对象，这个对象的access字段值为0。
接下来，按照用户权限方位从大到小的顺序依次说明。

## 全局权限
全局权限，作用于整个MySQL实例。给用户ua赋予最高权限：
`grant all privileges on *.* to 'ua'@'%' with grant option;`
这个grant命令做了两个动作：
1. 磁盘上，将mysql.user表里，用户’ua’@’%'这一行的所有表示权限的字段的值都修改为‘Y’；
2. 内存里，从数组acl_users中找到这个用户对应的对象，将access值（权限位）修改为二进制的“全1”。
执行完成后，有新的客户端使用用户ua登录成功，MySQL会为新连接维护一个线程对象，然后从acl_users数组里查到这个用户的权限，并将权限值拷贝到这个线程对象中。之后在这个连接中执行的语句，所有关于全局权限的判断，都直接使用线程对象内部保存的权限位。
基于上面的分析我们可以知道：
3. grant 命令对于全局权限，同时更新了磁盘和内存。命令完成后即时生效，接下来新创建的连接会使用新的权限。
4. 对于一个已经存在的连接，它的全局权限不受grant命令的影响。
==生产环境需要合理控制用户权限范围==
回收grant权限语句：
`revoke all privileges on *.* from 'ua'@'%';`
这条revoke命令的用法与grant类似，做了如下两个动作：
5. 磁盘上，将mysql.user表里，用户’ua’@’%'这一行的所有表示权限的字段的值都修改为“N”；
6. 内存里，从数组acl_users中找到这个用户对应的对象，将access的值修改为0。

## db权限
MySQL支持库级别的权限定义。用户ua拥有db1的所有权限，执行：
`grant all privileges on db1.* to 'ua'@'%' with grant option;`
基于库的权限记录保存在mysql.db表中，在内存里则保存在数组acl_dbs中。这条grant命令做了如下两个动作：
1. 磁盘上，往mysql.db表中插入了一行记录，所有权限位字段设置为“Y”；
2. 内存里，增加一个对象到数组acl_dbs中，这个对象的权限位为“全1”。
每次判断一个用户对一个数据库的读写权限时，需要遍历acl_dbs数组，根据user、host和db找到匹配的对象，根据对象的权限位判断。
==grant修改db权限的时候，是同时对磁盘和内存生效的。==
grant操作对于已经存在的连接的影响，在全局权限和基于db的权限效果是不同的。
![](MySQL/attachments/a88e1aca9c45af7090ef4cd84184545d_MD5.jpeg)
super是全局权限，在线程对象中存储，revoke操作影响不到这个线程对象。
T5时刻revoke库权限，是因为acl_dbs是一个全局数组，所有线程判断db权限都用这个数组，revoke操作会马上影响到session B。
session C中是因为使用了use db1，拿到了这个库的权限，在切换出db1库之前，session C对这个库一直有权限。

## 表权限和列权限
MySQL支持更细粒度的表权限和列权限。其中，表权限定义存放在表mysql.tables_priv中，列权限定义存放在表mysql.columns_priv中。这两类权限，组合起来存放在内存的hash结构column_priv_hash中。
赋权语句为:
```sql
create table db1.t1(id int, a int); 

grant all privileges on db1.t1 to 'ua'@'%' with grant option; 
GRANT SELECT(id), INSERT (id,a) ON mydb.mytbl TO 'ua'@'%' with grant option;
```
grant会修改数据表，也会同步修改内存中的hash结构。这两类操作，会马上影响到已经存在的连接。

flush privileges命令会清空acl_users数组，然后从mysql.user表中读取数据重新加载，重新构造一个acl_users数组。也就是说，以数据表中的数据为准，会将全局权限内存数组重新加载一遍。
同样地，对于db权限、表权限和列权限，MySQL也做了这样的处理。
也就是说，如果内存的权限数据和磁盘数据表相同的话，不需要执行flush privileges。而如果我们都是用grant/revoke语句来执行的话，内存和数据表本来就是保持同步更新的。

**正常情况下，grant命令之后，没有必要跟着执行flush privileges命令。**

## flush privileges使用场景
当数据表中的权限数据跟内存中的权限数据不一致的时候，flush privileges语句可以用来重建内存数据，达到一致状态。
不一致是由不规范的操作导致的，例如使用DML语句操作系统权限表。
