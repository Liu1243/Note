## Spring基础
Spring 框架指的都是 Spring Framework，是很多模块的集合。

Spring包含的模块有哪些？
4.x：
![](Java%E9%9D%A2%E7%BB%8F/attachments/8285b0edcd3fd0a93479d08c1b1f5bc5_MD5.jpeg)
5.x：
![](Java%E9%9D%A2%E7%BB%8F/attachments/bfb5cbd8a81e42389fea62fb8c6ee9a0_MD5.jpeg)
Spring5.x 版本中 Web 模块的 Portlet 组件已经被废弃掉，同时增加了用于异步响应式处理的 WebFlux 组件。
模块的依赖关系如下：
![](Java%E9%9D%A2%E7%BB%8F/attachments/e4af6aff17b5f4912af7d503cf00572f_MD5.jpeg)

Core Container
核心模块，主要提供 IoC 依赖注入功能的支持。
- **spring-core**：Spring 框架基本的核心工具类。
- **spring-beans**：提供对 bean 的创建、配置和管理等功能的支持。
- **spring-context**：提供对国际化、事件传播、资源加载等功能的支持。
- **spring-expression**：提供对表达式语言（Spring Expression Language） SpEL 的支持，只依赖于 core 模块，不依赖于其他模块，可以单独使用。

AOP
- **spring-aspects**：该模块为与 AspectJ 的集成提供支持。
- **spring-aop**：提供了面向切面的编程实现。
- **spring-instrument**：提供了为 JVM 添加代理（agent）的功能。 具体来讲，它为 Tomcat 提供了一个织入代理，能够为 Tomcat 传递类文件，就像这些文件是被类加载器加载的一样。没有理解也没关系，这个模块的使用场景非常有限。

Data Access/Integration
- **spring-jdbc**：提供了对数据库访问的抽象 JDBC。不同的数据库都有自己独立的 API 用于操作数据库，而 Java 程序只需要和 JDBC API 交互，这样就屏蔽了数据库的影响。
- **spring-tx**：提供对事务的支持。
- **spring-orm**：提供对 Hibernate、JPA、iBatis 等 ORM 框架的支持。
- **spring-oxm**：提供一个抽象层支撑 OXM(Object-to-XML-Mapping)，例如：JAXB、Castor、XMLBeans、JiBX 和 XStream 等。
- **spring-jms** : 消息服务。自 Spring Framework 4.1 以后，它还提供了对 spring-messaging 模块的继承。

Spring Web
- **spring-web**：对 Web 功能的实现提供一些最基础的支持。
- **spring-webmvc**：提供对 Spring MVC 的实现。
- **spring-websocket**：提供了对 WebSocket 的支持，WebSocket 可以让客户端和服务端进行双向通信。
- **spring-webflux**：提供对 WebFlux 的支持。WebFlux 是 Spring Framework 5.0 中引入的新的响应式框架。与 Spring MVC 不同，它不需要 Servlet API，是完全异步。

Messaging
**spring-messaging** 是从 Spring4.0 开始新加入的一个模块，主要职责是为 Spring 框架集成一些基础的报文传送应用。

Spring Test
Spring 的测试模块对 JUnit（单元测试框架）、TestNG（类似 JUnit）、Mockito（主要用来 Mock 对象）、PowerMock（解决 Mockito 的问题比如无法模拟 final, static， private 方法）等等常用的测试框架支持的都比较好。

Spring，Spring MVC，Spring Boot之间的关系是什么？
Spring就是Spring Framework，包含多个功能模块，Spring MVC就是其中的模块之一。
Spring MVC主要赋予 Spring 快速构建 MVC 架构的 Web 程序的能力。MVC 是模型(Model)、视图(View)、控制器(Controller)的简写，其核心思想是通过将业务逻辑、数据、显示分离来组织代码。
使用Spring开发需要各种显式的配置，Spring Boot旨在简化Spring开发，减少配置文件。
Spring Boot 只是简化了配置，如果你需要构建 MVC 架构的 Web 程序，你还是需要使用 Spring MVC 作为 MVC 框架，只是说 Spring Boot 帮你简化了 Spring MVC 的很多配置，真正做到开箱即用！

### Spring Ioc
谈谈自己对于Ioc的了解？
**IoC（Inversion of Control:控制反转）** 是一种设计思想，而不是一个具体的技术实现。IoC 的思想就是将原本在程序中手动创建对象的控制权，交由 Spring 框架来管理。不过， IoC 并非 Spring 特有，在其他语言中也有应用。
什么叫控制反转？
- **控制**：指的是对象创建（实例化、管理）的权力
- **反转**：控制权交给外部环境（Spring 框架、IoC 容器）
将对象之间的相互依赖关系交给 IoC 容器来管理，并由 IoC 容器完成对象的注入。
  
在 Spring 中， IoC 容器是 Spring 用来实现 IoC 的载体， IoC 容器实际上就是个 Map（key，value），Map 中存放的是各种对象。

什么是Spring Bean？
Bean就是被Ioc容器管理的对象。
我们需要告诉 IoC 容器帮助我们管理哪些对象，这个是通过配置元数据来定义的。配置元数据可以是 XML 文件、注解或者 Java 配置类。
```xml
<!-- Constructor-arg with 'value' attribute -->
<bean id="..." class="...">
   <constructor-arg value="..."/>
</bean>
```
`org.springframework.beans`和 `org.springframework.context` 这两个包是 IoC 实现的基础

将一个类声明为Bean的注解有哪些？
@Component：通用的注解，可标注任意类为 `Spring` 组件。
@Repository：Dao层
@Service：Service层
@Controller：Controller层

@Component和@Bean的区别是什么？
- @Component注解作用于类，@Bean作用于方法
- `@Component`通常是通过类路径扫描来自动侦测以及自动装配到 Spring 容器中（我们可以使用 `@ComponentScan` 注解定义要扫描的路径从中找出标识了需要装配的类自动装配到 Spring 的 bean 容器中）。`@Bean` 注解通常是我们在标有该注解的方法中定义产生这个 bean,`@Bean`告诉了 Spring 这是某个类的实例，当我需要用它的时候还给我。
- `@Bean` 注解比 `@Component` 注解的自定义性更强，而且很多地方我们只能通过 `@Bean` 注解来注册 bean。比如当我们引用第三方库中的类需要装配到 `Spring`容器时，则只能通过 `@Bean`来实现。

注入Bean的注解有哪些？
@Autowired、@Resource和@Inject，其中@Autowired和@Resource用的较多一点。

@Autowired和@Resource的区别是什么？
@Autowired属于Spring内置的注解，默认注入方式是byType，优先根据接口类型去匹配并注入Bean。
**这会有什么问题呢？** 当一个接口存在多个实现类的话，`byType`这种方式就无法正确注入对象了，因为这个时候 Spring 会同时找到多个满足条件的选择，默认情况下它自己不知道选择哪一个。
注入方式变成byName，名称通常为类型首字母小写。
```java
// 报错，byName 和 byType 都无法匹配到 bean
@Autowired
private SmsService smsService;
// 正确注入 SmsServiceImpl1 对象对应的 bean
@Autowired
private SmsService smsServiceImpl1;
// 正确注入  SmsServiceImpl1 对象对应的 bean
// smsServiceImpl1 就是我们上面所说的名称
@Autowired
@Qualifier(value = "smsServiceImpl1")
private SmsService smsService;
```
> 我们还是建议通过 `@Qualifier` 注解来显式指定名称而不是依赖变量的名称。

@Resource属于JDK提供的注解，默认注入方式为byName。如果无法通过名称匹配则变为byType.
`@Resource` 有两个比较重要且日常开发常用的属性：`name`（名称）、`type`（类型）。
如果仅指定 `name` 属性则注入方式为`byName`，如果仅指定`type`属性则注入方式为`byType`，如果同时指定`name` 和`type`属性（不建议这么做）则注入方式为`byType`+`byName`。

简单总结一下：
- `@Autowired` 是 Spring 提供的注解，`@Resource` 是 JDK 提供的注解。
- `Autowired` 默认的注入方式为`byType`（根据类型进行匹配），`@Resource`默认注入方式为 `byName`（根据名称进行匹配）。
- 当一个接口存在多个实现类的情况下，`@Autowired` 和`@Resource`都需要通过名称才能正确匹配到对应的 Bean。`Autowired` 可以通过 `@Qualifier` 注解来显式指定名称，`@Resource`可以通过 `name` 属性来显式指定名称。
- `@Autowired` 支持在构造函数、方法、字段和参数上使用。`@Resource` 主要用于字段和方法上的注入，不支持在构造函数或参数上使用。

注入Bean的方式有哪些?
依赖注入DI的常见方式:
1. 构造函数注入：通过类的构造函数来注入依赖项。
2. Setter 注入：通过类的 Setter 方法来注入依赖项。
3. Field（字段） 注入：直接在类的字段上使用注解（如 `@Autowired` 或 `@Resource`）来注入依赖项。

构造函数注入还是Setter注入?
**Spring 官方推荐构造函数注入**，这种注入方式的优势如下：
1. 依赖完整性：确保所有必需依赖在对象创建时就被注入，避免了空指针异常的风险。
2. 不可变性：有助于创建不可变对象，提高了线程安全性。
3. 初始化保证：组件在使用前已完全初始化，减少了潜在的错误。
4. 测试便利性：在单元测试中，可以直接通过构造函数传入模拟的依赖项，而不必依赖 Spring 容器进行注入。
构造函数注入适合处理**必需的依赖项**，而 **Setter 注入** 则更适合**可选的依赖项**，这些依赖项可以有默认值或在对象生命周期中动态设置。虽然 `@Autowired` 可以用于 Setter 方法来处理必需的依赖项，但构造函数注入仍然是更好的选择。
在某些情况下（例如第三方类不提供 Setter 方法），构造函数注入可能是**唯一的选择**。

Bean的作用域有哪些?
- **singleton** : IoC 容器中只有唯一的 bean 实例。Spring 中的 bean 默认都是单例的，是对单例设计模式的应用。
- **prototype** : 每次获取都会创建一个新的 bean 实例。也就是说，连续 `getBean()` 两次，得到的是不同的 Bean 实例。
- **request** （仅 Web 应用可用）: 每一次 HTTP 请求都会产生一个新的 bean（请求 bean），该 bean 仅在当前 HTTP request 内有效。
- **session** （仅 Web 应用可用） : 每一次来自新 session 的 HTTP 请求都会产生一个新的 bean（会话 bean），该 bean 仅在当前 HTTP session 内有效。
- **application/global-session** （仅 Web 应用可用）：每个 Web 应用在启动时创建一个 Bean（应用 Bean），该 bean 仅在当前应用启动时间内有效。
- **websocket** （仅 Web 应用可用）：每一次 WebSocket 会话产生一个新的 bean。

Bean是线程安全的吗?
取决于作用域和状态.几乎所有场景的Bean作用域都是默认的singleton.
prototype 作用域下，每次获取都会创建一个新的 bean 实例，不存在资源竞争问题，所以不存在线程安全问题。singleton 作用域下，IoC 容器中只有唯一的 bean 实例，可能会存在资源竞争问题（取决于 Bean 是否有状态）。如果这个 bean 是有状态的话，那就存在线程安全问题（有状态 Bean 是指包含可变的成员变量的对象）。
大部分 Bean 实际都是无状态（没有定义可变的成员变量）的（比如 Dao、Service），这种情况下， Bean 是线程安全的。

对于有状态单例 Bean 的线程安全问题，常见的三种解决办法是：
1. **避免可变成员变量**: 尽量设计 Bean 为无状态。
2. **使用`ThreadLocal`**: 将可变成员变量保存在 `ThreadLocal` 中，确保线程独立。
3. **使用同步机制**: 利用 `synchronized` 或 `ReentrantLock` 来进行同步控制，确保线程安全。

Bean的声明周期了解吗?
1. 创建Bena实例:配置文件找到Bean定义,使用反射创建Bean实例
2. Bean属性赋值:@Autowired @Value setter方法或构造函数注入
3. Bean初始化:
	- 如果 Bean 实现了 `BeanNameAware` 接口，调用 `setBeanName()`方法，传入 Bean 的名字。
	- 如果 Bean 实现了 `BeanClassLoaderAware` 接口，调用 `setBeanClassLoader()`方法，传入 `ClassLoader`对象的实例。
	- 如果 Bean 实现了 `BeanFactoryAware` 接口，调用 `setBeanFactory()`方法，传入 `BeanFactory`对象的实例。
	- 与上面的类似，如果实现了其他 `*.Aware`接口，就调用相应的方法。
	- 如果有和加载这个 Bean 的 Spring 容器相关的 `BeanPostProcessor` 对象，执行`postProcessBeforeInitialization()` 方法
	- 如果 Bean 实现了`InitializingBean`接口，执行`afterPropertiesSet()`方法。
	- 如果 Bean 在配置文件中的定义包含 `init-method` 属性，执行指定的方法。
	- 如果有和加载这个 Bean 的 Spring 容器相关的 `BeanPostProcessor` 对象，执行`postProcessAfterInitialization()` 方法。
4. 销毁Bean:记录Bean的销毁方法,将来销毁的时候调用这些方法,注册回调方法
	- 如果 Bean 实现了 `DisposableBean` 接口，执行 `destroy()` 方法。
	- 如果 Bean 在配置文件中的定义包含 `destroy-method` 属性，执行指定的 Bean 销毁方法。或者，也可以直接通过`@PreDestroy` 注解标记 Bean 销毁之前执行的方法。

Aware接口能让Bean拿到Spring容器资源.
1. `BeanNameAware`：注入当前 bean 对应 beanName；
2. `BeanClassLoaderAware`：注入加载当前 bean 的 ClassLoader；
3. `BeanFactoryAware`：注入当前 `BeanFactory` 容器的引用。

BeanPostProcessor接口时修改Bean强大拓展点.
```java
public interface BeanPostProcessor {

	// 初始化前置处理
	default Object postProcessBeforeInitialization(Object bean, String beanName) throws BeansException {
		return bean;
	}
	// 初始化后置处理
	default Object postProcessAfterInitialization(Object bean, String beanName) throws BeansException {
		return bean;
	}
}
```
- `postProcessBeforeInitialization`：Bean 实例化、属性注入完成后，`InitializingBean#afterPropertiesSet`方法以及自定义的 `init-method` 方法之前执行；
- `postProcessAfterInitialization`：类似于上面，不过是在 `InitializingBean#afterPropertiesSet`方法以及自定义的 `init-method` 方法之后执行。

`InitializingBean` 和 `init-method` 是 Spring 为 Bean 初始化提供的扩展点。

1. 整体上可以简单分为四步：实例化 —> 属性赋值 —> 初始化 —> 销毁。
2. 初始化这一步涉及到的步骤比较多，包含 `Aware` 接口的依赖注入、`BeanPostProcessor` 在初始化前后的处理以及 `InitializingBean` 和 `init-method` 的初始化操作。
3. 销毁这一步会注册相关销毁回调接口，最后通过`DisposableBean` 和 `destory-method` 进行销毁。
![](Java%E9%9D%A2%E7%BB%8F/attachments/f28bce733eb581db678a43de2b7a4df2_MD5.jpeg)
### Spring AOP
谈谈自己对AOP的了解?
