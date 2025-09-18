**JDBC (Java Database Connectivity)**定义和Java客户端如何访问数据库，并提供了方法查询和更新数据库中的数据，JDBC的组件包括：
- **DriverManager**: 用于管理一组 JDBC 驱动程序。
- **Connection**: 代表与特定数据库的连接。
- **Statement**: 用于执行 SQL 语句。
- **ResultSet**: 用于保存从数据库查询返回的数据。

**JNDI (Java Naming and Directory Interface**)是 Java 的一个 API，它为应用程序提供了命名和目录功能。应用可以实用JNDI以统一的方式访问各种命名和目录服务，包括EJB、JMS消息队列、JDBC数据源。

JNDI 可以用来管理和提供对 JDBC 资源的访问，特别是数据源（DataSource）。

**总而言之，JDBC 是进行数据库操作的基础，而 JNDI 则提供了一种更高级、更具可管理性的方式来获取和使用 JDBC 资源，尤其是在企业级应用中，这种组合使用被认为是最佳实践。**

