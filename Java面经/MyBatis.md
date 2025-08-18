#{}和${}的区别是什么？
`${}` 是 **原样文本替换**，MyBatis 在拼接 SQL 前，会直接把内容替换进去。存在SQL注入风险；
`#{}` 会被 MyBatis 转换为 `?` 占位符，并通过 **PreparedStatement** 来设置参数，防止SQL注入。

xml映射文件中，除了常见的select、insert、update、delete标签之外，还有哪些标签？
- **结构性标签**：`<resultMap> <parameterMap> <sql> <include> <selectKey>`
- **动态 SQL 标签**：`<if> <choose>/<when>/<otherwise> <foreach> <where> <set> <trim> <bind>`

Dao接口的工作原理是什么？Dao接口里的方法，参数不同时，方法能重载吗？
最佳实践是一个xml映射文件对应一个Dao接口，也就是Mapper接口。接口的全限名，就是映射文件中的 namespace 的值，接口的方法名，就是映射文件中 `MappedStatement` 的 id 值，接口方法内的参数，就是传递给 sql 的参数。
Mapper接口没有实现类，接口全限名+方法名作为key，可唯一定位一个mappedStatement。
Dao 接口里的方法可以重载，但是 Mybatis 的 xml 里面的 ID 不允许重复。
```java
/**
 * Mapper接口里面方法重载
 */
public interface StuMapper {

 List<Student> getAllStu();

 List<Student> getAllStu(@Param("id") Integer id);
}
```
使用动态sql实现重载
```xml
<select id="getAllStu" resultType="com.pojo.Student">
  select * from student
  <where>
    <if test="id != null">
      id = #{id}
    </if>
  </where>
</select>
```
**Mybatis 的 Dao 接口可以有多个重载方法，但是多个接口对应的映射必须只有一个，否则启动会报错。**
Dao 接口的工作原理是 JDK 动态代理，MyBatis 运行时会使用 JDK 动态代理为 Dao 接口生成代理 proxy 对象，代理对象 proxy 会拦截接口方法，转而执行 `MappedStatement` 所代表的 sql，然后将 sql 执行结果返回。

Dao 接口方法可以重载，但是需要满足以下条件：
1. 仅有一个无参方法和一个有参方法
2. 多个有参方法时，参数数量必须一致。且使用相同的 `@Param` ，或者使用 `param1` 这种

MyBatis是如何进行分页的？分页插件的原理是什么？
**(1)** MyBatis 使用 RowBounds 对象进行分页，它是针对 ResultSet 结果集执行的内存分页，而非物理分页，不修改原先SQL；**(2)** 可以在 sql 内直接书写带有物理分页的参数来完成物理分页功能，**(3)** 也可以使用分页插件来完成物理分页。
分页插件的基本原理是使用 MyBatis 提供的插件接口，实现自定义插件，在插件的拦截方法内拦截待执行的 sql，然后重写 sql

简述MyBatis的插件运行原理，以及如何编写一个插件？
MyBatis 的插件机制是基于 **责任链模式 + 动态代理** 实现的。
MyBatis 允许我们对以下四个核心对象的方法进行拦截：
- `Executor`（执行 SQL）
- `StatementHandler`（处理 JDBC Statement）
- `ParameterHandler`（处理 SQL 参数）
- `ResultSetHandler`（处理结果集）
如果某个方法被插件配置为需要拦截，调用时会先进入代理的 `invoke()` → 然后调用插件的 `intercept()` → 再决定是否执行原方法。
如果有多个插件，MyBatis 会把它们组成一个 **责任链**，逐个执行。
编写一个插件的步骤：
1. 实现Interceptor接口
```java
@Intercepts({
    @Signature(
        type = StatementHandler.class, // 拦截的接口
        method = "prepare",            // 拦截的方法
        args = {Connection.class, Integer.class} // 方法参数
    )
})
public class ExamplePlugin implements Interceptor {

    @Override
    public Object intercept(Invocation invocation) throws Throwable {
        // 在这里写增强逻辑
        System.out.println("拦截到 SQL 预编译方法！");
        return invocation.proceed(); // 放行，执行原方法
    }

    @Override
    public Object plugin(Object target) {
        // 生成代理对象，只有目标类是 StatementHandler 才包装
        return Plugin.wrap(target, this);
    }

    @Override
    public void setProperties(Properties properties) {
        // 可接收外部配置 <plugin> 标签里的参数
        System.out.println("插件属性：" + properties);
    }
}
```
2. 在Mybatis配置文件中注册插件
```xml
<plugins>
    <plugin interceptor="com.example.mybatis.ExamplePlugin">
        <property name="someKey" value="someValue"/>
    </plugin>
</plugins>
```

MyBatis执行批量插入，能返回数据库主键列表吗？
能，JDBC可以，MyBatis也可以

MyBatis动态sql是做什么的？都有哪些动态sql？简述一下动态sql的执行原理？
MyBatis 动态 sql 可以让我们在 xml 映射文件内，以标签的形式编写动态 sql，完成逻辑判断和动态拼接 sql 的功能。其执行原理为，使用 OGNL 从 sql 参数对象中计算表达式的值，根据表达式的值动态拼接 sql，以此来完成动态 sql 的功能。
- `<if></if>`
- `<where></where>(trim,set)`
- `<choose></choose>（when, otherwise）`
- `<foreach></foreach>`
- `<bind/>`
动态sql的执行原理步骤：
1. **XML 解析阶段**
    - Mapper XML → `MappedStatement`
    - 动态 SQL 标签解析成 `SqlNode` 树，交给 `DynamicSqlSource`
2. **运行阶段**
    - Mapper 方法调用 → Executor 执行
    - `DynamicSqlSource` 遍历 `SqlNode` 树，根据参数决定拼接哪些 SQL 片段
    - 生成完整 SQL → 封装成 `BoundSql`
3. **执行阶段**
    - `BoundSql` 中的 SQL 和参数映射交给 JDBC PreparedStatement
    - 最终执行 SQL 并返回结果集

MyBatis是如何将sql执行结果封装为目标对象并返回的？都有哪些映射形式？
1. \<resultMap>标签
2. sql列的别名t_name AS name
有了列名和属性名的映射关系，MyBatis通过反射创建对象，使用反射给对象的属性赋值。

MyBatis能执行一对一、一对多的关联查询吗？都有哪些实现方式，以及他们之间的区别
不仅支持 **一对一**、**一对多**，还支持 **多对一**、**多对多**。
1. **分步查询（嵌套 Select，N+1 查询方式）**
先查主对象，再根据主对象的外键，调用另一个 `select` 查询关联对象。
```java
<resultMap id="teacherResultMap" type="Teacher">
  <id property="id" column="id"/>
  <result property="name" column="name"/>
  <collection property="students" column="id"
              ofType="Student" select="selectStudentsByTeacherId"/>
</resultMap>

<select id="selectTeacher" resultMap="teacherResultMap">
  SELECT id, name FROM teacher WHERE id = #{id}
</select>

<select id="selectStudentsByTeacherId" resultType="Student">
  SELECT id, name, teacher_id FROM student WHERE teacher_id = #{teacherId}
</select>

```
2. 联表查询（嵌套 ResultMap，一次 Join 查询）
通过 **join SQL** 把主对象和关联对象一起查出来，MyBatis 用 `<resultMap>` 来完成对象组装。
```java
<resultMap id="teacherResultMap" type="Teacher">
  <id property="id" column="t_id"/>
  <result property="name" column="t_name"/>
  <collection property="students" ofType="Student">
    <id property="id" column="s_id"/>
    <result property="name" column="s_name"/>
  </collection>
</resultMap>

<select id="selectTeacherWithStudents" resultMap="teacherResultMap">
  SELECT t.id AS t_id, t.name AS t_name,
         s.id AS s_id, s.name AS s_name
  FROM teacher t
  LEFT JOIN student s ON t.id = s.teacher_id
  WHERE t.id = #{id}
</select>
```
去重机制：靠 `<resultMap>` 中的 `<id>` 标签（可以是联合主键）。

|方式|好处|缺点|适用场景|
|---|---|---|---|
|**分步查询（N+1 查询）**|SQL 简单，可复用，逻辑清晰|会产生 N+1 次查询，性能差|小数据量，或需要延迟加载的场景|
|**联表查询（Join + 嵌套 ResultMap）**|一次 SQL 搞定，性能高|SQL 复杂，结果集有重复行，需要去重|数据量大，需要一次性查出完整对象图|

MyBatis是否支持延迟加载？如果支持，实现原理是什么？
只支持association一对一以及collection一对多的延迟加载。配置lazyLoadingEnabled=true|false。
MyBatis延迟加载机制，是动态代理+按需触发SQL查询。
- **代理对象生成**  
    当你查询到一个主对象时（比如 `Teacher`），MyBatis 不会立刻加载关联对象（比如 `Student` 列表）。  
    它会用 **CGLIB 或 JDK 动态代理** 为 `Teacher` 的 `students` 属性生成一个代理对象（空壳子）。
- **拦截方法调用**  
    当你调用 `teacher.getStudents()` 时，MyBatis 的代理拦截器会捕捉到这个调用。
    - 如果 `students` 尚未加载，拦截器会执行 **延迟加载 SQL**（即之前保存好的 `select * from student where teacher_id = ?`）。
    - 如果已经加载过，就直接返回已有数据。
- **填充结果 & 返回**  
    查询结果被填充到 `teacher.students` 中，下次调用时就不会再触发 SQL 了。
本质是==延迟到真正需要的时候，再去数据库查询==

MyBatis的xml映射文件中，不同的xml映射文件，id是否可以重复？
不同的 xml 映射文件，如果配置了 namespace，那么 id 可以重复；如果没有配置 namespace，那么 id 不能重复；毕竟 namespace 不是必须的，只是最佳实践而已。
原因就是 namespace+id 是作为 `Map<String, MappedStatement>` 的 key 使用的

MyBatis中如何执行批处理？
使用BatchExecutor完成批处理

MyBatis都有哪些Executor执行器？他们之间的区别是什么？
- **`SimpleExecutor`：** 每执行一次 update 或 select，就开启一个 Statement 对象，用完立刻关闭 Statement 对象。
- **`ReuseExecutor`：** 执行 update 或 select，以 sql 作为 key 查找 Statement 对象，存在就使用，不存在就创建，用完后，不关闭 Statement 对象，而是放置于 Map<String, Statement>内，供下一次使用。简言之，就是重复使用 Statement 对象。
- **`BatchExecutor`**：执行 update（没有 select，JDBC 批处理不支持 select），将所有 sql 都添加到批处理中（addBatch()），等待统一执行（executeBatch()），它缓存了多个 Statement 对象，每个 Statement 对象都是 addBatch()完毕后，等待逐一执行 executeBatch()批处理。与 JDBC 批处理相同。

MyBatis中如何指定使用哪一个Executor执行器？
在 MyBatis 配置文件中，可以指定默认的 `ExecutorType` 执行器类型，也可以手动给 `DefaultSqlSessionFactory` 的创建 SqlSession 的方法传递 `ExecutorType` 类型参数。

MyBatis是否可以映射Enum枚举类？
MyBatis 可以映射枚举类，不单可以映射枚举类，MyBatis 可以映射任何对象到表的一列上。映射方式为自定义一个 `TypeHandler` ，实现 `TypeHandler` 的 `setParameter()` 和 `getResult()` 接口方法。`TypeHandler` 有两个作用：
- 一是完成从 javaType 至 jdbcType 的转换；
- 二是完成 jdbcType 至 javaType 的转换，体现为 `setParameter()` 和 `getResult()` 两个方法，分别代表设置 sql 问号占位符参数和获取列查询结果。

MyBatis映射文件中，如果A标签通过include引用了B标签的内容，那么B标签能否定义在A标签的后面，还是说必须定义在A标签的前面？
虽然 MyBatis 解析 xml 映射文件是按照顺序解析的，但是，被引用的 B 标签依然可以定义在任何地方，MyBatis 都可以正确识别。
MyBatis 解析 A 标签，发现 A 标签引用了 B 标签，但是 B 标签尚未解析到，尚不存在，此时，MyBatis 会将 A 标签标记为未解析状态，然后继续解析余下的标签，包含 B 标签，待所有标签解析完毕，MyBatis 会重新解析那些被标记为未解析的标签，此时再解析 A 标签时，B 标签已经存在，A 标签也就可以正常解析完成了。

简述MyBatis的xml映射文件和Mybatis内部数据结构之间的映射关系？
MyBatis 将所有 xml 配置信息都封装到 All-In-One 重量级对象 Configuration 内部。在 xml 映射文件中， `<parameterMap>` 标签会被解析为 `ParameterMap` 对象，其每个子元素会被解析为 ParameterMapping 对象。 `<resultMap>` 标签会被解析为 `ResultMap` 对象，其每个子元素会被解析为 `ResultMapping` 对象。每一个 `<select>、<insert>、<update>、<delete>` 标签均会被解析为 `MappedStatement` 对象，标签内的 sql 会被解析为 BoundSql 对象。

| XML 标签                                            | MyBatis 内部对象             | 说明                                                     |
| ------------------------------------------------- | ------------------------ | ------------------------------------------------------ |
| `<parameterMap>`                                  | `ParameterMap`           | 描述 SQL 入参的映射关系（现在不常用，多用 `@Param` 或直接传对象）               |
| `<parameter>`                                     | `ParameterMapping`       | `parameterMap` 的子元素，描述单个参数的类型、jdbcType 等               |
| `<resultMap>`                                     | `ResultMap`              | 用于描述结果集如何映射到 Java 对象                                   |
| `<result>` / `<id>`                               | `ResultMapping`          | `resultMap` 的子元素，映射数据库列到 Java 属性                       |
| `<association>` / `<collection>`                  | `ResultMapping`（内部带嵌套）   | 支持一对一 / 一对多的结果映射                                       |
| `<select>` / `<insert>` / `<update>` / `<delete>` | `MappedStatement`        | 代表一条 SQL 语句及相关信息                                       |
| SQL 语句文本                                          | `SqlSource` / `BoundSql` | `<select>` 内的动态 SQL 最终解析成 `SqlSource`，运行时生成 `BoundSql` |
| `<sql>`                                           | `SqlFragment`            | SQL 片段（可复用），存放在 `Configuration.sqlFragments`           |
- **所有 XML 配置** → `Configuration`
- **SQL 语句级别** → `MappedStatement`（内含 `SqlSource`/`BoundSql`）
- **参数映射** → `ParameterMap` / `ParameterMapping`
- **结果映射** → `ResultMap` / `ResultMapping`

为什么说MyBatis是半自动ORM映射工具？他与全自动的区别在哪里？
Hibernate 属于全自动 ORM 映射工具，使用 Hibernate 查询关联对象或者关联集合对象时，可以根据对象关系模型直接获取，所以它是全自动的。而 MyBatis 在查询关联对象或关联集合对象时，需要手动编写 sql 来完成，所以，称之为半自动 ORM 映射工具。

|特性|MyBatis（半自动）|Hibernate（全自动）|
|---|---|---|
|SQL 编写|**手动编写**（灵活、可控）|**自动生成**（开发快，但灵活性差）|
|复杂查询|需要写原生 SQL / 动态 SQL|使用 HQL/Criteria 自动生成|
|映射关系|通过 XML / 注解配置 ResultMap|通过注解/XML 定义实体关系|
|性能调优|SQL 可控，易于优化|SQL 自动生成，调优难度较高|
|学习成本|低（SQL 基础即可）|高（需理解 ORM、缓存、事务等）|
|使用场景|复杂查询业务系统、对 SQL 性能要求高的项目|数据关系清晰、CRUD 为主的系统|
