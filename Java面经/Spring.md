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
AOP(Aspect-Oriented Programming:面向切面编程)能够将那些与业务无关，却为业务模块所共同调用的逻辑或责任（例如事务处理、日志管理、权限控制等）封装起来，便于减少系统的重复代码，降低模块间的耦合度，并有利于未来的可拓展性和可维护性。
AOP基于动态代理，如果代理的对象实现了接口，就是用JDK Proxy创建代理对象；对于没有实现接口的对象，使用Cglib生成一个被代理对象的子类做代理。
![](Java%E9%9D%A2%E7%BB%8F/attachments/5765df9ce5d45eefd6bcf19c1933dd3f_MD5.jpeg)
可以使用AspectJ。

---
AspectJ使用实例：
**需求**：在调用业务方法前后打印日志，不修改业务代码。
```java title:Target类
import org.springframework.stereotype.Service;

@Service
public class UserService {
    public void addUser(String name) {
        System.out.println("正在添加用户：" + name);
    }
}

```

```java title:AOP切面类
import org.aspectj.lang.JoinPoint;
import org.aspectj.lang.annotation.*;
import org.springframework.stereotype.Component;

@Aspect
@Component
public class LogAspect {

    // 定义切入点：匹配 UserService 下所有方法
    @Pointcut("execution(* com.example.demo.UserService.*(..))")
    public void userServiceMethods() {}

    // 前置通知
    @Before("userServiceMethods()")
    public void before(JoinPoint jp) {
        System.out.println("【前置通知】调用方法：" + jp.getSignature().getName());
    }

    // 后置通知（无论是否异常都会执行）
    @After("userServiceMethods()")
    public void after(JoinPoint jp) {
        System.out.println("【后置通知】方法执行结束：" + jp.getSignature().getName());
    }

    // 返回通知（只有方法正常返回时执行）
    @AfterReturning(pointcut = "userServiceMethods()", returning = "result")
    public void afterReturning(Object result) {
        System.out.println("【返回通知】返回值：" + result);
    }

    // 异常通知
    @AfterThrowing(pointcut = "userServiceMethods()", throwing = "ex")
    public void afterThrowing(Exception ex) {
        System.out.println("【异常通知】异常信息：" + ex.getMessage());
    }
}

```

Spring AOP和AspectJ AOP有什么区别？
![](Java%E9%9D%A2%E7%BB%8F/attachments/bafb52a799c6dd7e1aa93f991c8c1232_MD5.jpeg)
如何进行选择？
- **功能考量**：AspectJ 支持更复杂的 AOP 场景，Spring AOP 更简单易用。如果你需要增强 `final` 方法、静态方法、字段访问、构造器调用等，或者需要在非 Spring 管理的对象上应用增强逻辑，AspectJ 是唯一的选择。
- **性能考量**：切面数量较少时两者性能差异不大，但切面较多时 AspectJ 性能更优。
**一句话总结**：简单场景优先使用 Spring AOP；复杂场景或高性能需求时，选择 AspectJ。

AOP常见的通知类型有哪些？
![](Java%E9%9D%A2%E7%BB%8F/attachments/1d6fec2a01bb6b92689d5932b119a1ad_MD5.jpeg)
- **Before**（前置通知）：目标对象的方法调用之前触发
- **After** （后置通知）：目标对象的方法调用之后触发
- **AfterReturning**（返回通知）：目标对象的方法调用完成，在返回结果值之后触发
- **AfterThrowing**（异常通知）：目标对象的方法运行中抛出 / 触发异常后触发。AfterReturning 和 AfterThrowing 两者互斥。如果方法调用成功无异常，则会有返回值；如果方法抛出了异常，则不会有返回值。
- **Around** （环绕通知）：编程式控制目标对象的方法调用。环绕通知是所有通知类型中可操作范围最大的一种，因为它可以直接拿到目标对象，以及要执行的方法，所以环绕通知可以任意的在目标对象的方法调用前后搞事，甚至不调用目标对象的方法

---
Around环绕通知的例子：
```java
// 切入点：匹配 UserService 中的所有方法
    @Around("execution(* com.example.demo.service.UserService.*(..))")
    public Object logAround(ProceedingJoinPoint pjp) throws Throwable {
        String methodName = pjp.getSignature().getName();
        
        System.out.println("【环绕-前】调用方法：" + methodName);

        // 调用目标方法，并获取返回值
        Object result = pjp.proceed();

        System.out.println("【环绕-后】方法执行完毕：" + methodName);
        System.out.println("【环绕-返回值】" + result);

        return result; // 记得返回，否则外部拿不到方法的返回值
    }
```

多个切面的执行顺序如何控制？
1. 使用@Order注解定义切面顺序
2. 实现Ordered接口重写getOrder方法。

## Spring MVC
说说自己对于Spring MVC了解？
MVC 是模型(Model)、视图(View)、控制器(Controller)的简写，其核心思想是通过将业务逻辑、数据、显示分离来组织代码。
MVC是一种设计模式。
Model 1时代：
整个 Web 应用几乎全部用 JSP 页面组成，只用少量的 JavaBean 来处理数据库连接、访问等操作。
JSP既是控制层也是表示层，控制逻辑和表现逻辑混杂在一起，导致代码重用率极低；再比如前端和后端相互依赖，难以进行测试维护并且开发效率极低。
![](Java%E9%9D%A2%E7%BB%8F/attachments/5de152568401ef6fa111202934d8814b_MD5.jpeg)
Model 2时代：
Java Bean(Model)+ JSP（View）+Servlet（Controller）
- Model:系统涉及的数据，也就是 dao 和 bean。
- View：展示模型中的数据，只是用来展示。
- Controller：接受用户请求，并将请求发送至 Model，最后返回数据给 JSP 并展示给用户
![](Java%E9%9D%A2%E7%BB%8F/attachments/c6179ef8fa5557fb6c36b4b2f6992164_MD5.jpeg)
Model2 的抽象和封装程度还远远不够，使用 Model2 进行开发时不可避免地会重复造轮子，这就大大降低了程序的可维护性和复用性。Struct2应运而生。
Spring MVC时代：
相比于Struct2框架，Spring MVC使用更加简单方便。
Spring MVC 下我们一般把后端项目分为 Service 层（处理业务）、Dao 层（数据库操作）、Entity 层（实体类）、Controller 层(控制层，返回数据给前台页面)。

Spring MVC的核心组件有哪些？
- **`DispatcherServlet`**：**核心的中央处理器**，负责接收请求、分发，并给予客户端响应。
- **`HandlerMapping`**：**处理器映射器**，根据 URL 去匹配查找能处理的 `Handler` ，并会将请求涉及到的拦截器和 `Handler` 一起封装。
- **`HandlerAdapter`**：**处理器适配器**，根据 `HandlerMapping` 找到的 `Handler` ，适配执行对应的 `Handler`；
- **`Handler`**：**请求处理器**，处理实际请求的处理器。
- **`ViewResolver`**：**视图解析器**，根据 `Handler` 返回的逻辑视图 / 视图，解析并渲染真正的视图，并传递给 `DispatcherServlet` 响应客户端

Spring MVC工作原理了解吗？
![](Java%E9%9D%A2%E7%BB%8F/attachments/03a16829dd43807095f6e2b306649feb_MD5.jpeg)
流程说明：
1. 客户端（浏览器）发送请求， `DispatcherServlet`拦截请求。
2. `DispatcherServlet` 根据请求信息调用 `HandlerMapping` 。`HandlerMapping` 根据 URL 去匹配查找能处理的 `Handler`（也就是我们平常说的 `Controller` 控制器） ，并会将请求涉及到的拦截器和 `Handler` 一起封装。
3. `DispatcherServlet` 调用 `HandlerAdapter`适配器执行 `Handler` 。
4. `Handler` 完成对用户请求的处理后，会返回一个 `ModelAndView` 对象给`DispatcherServlet`，`ModelAndView` 顾名思义，包含了数据模型以及相应的视图的信息。`Model` 是返回的数据对象，`View` 是个逻辑上的 `View`。
5. `ViewResolver` 会根据逻辑 `View` 查找实际的 `View`。
6. `DispaterServlet` 把返回的 `Model` 传给 `View`（视图渲染）。
7. 把 `View` 返回给请求者（浏览器）
上面是传统开发模式（JSP，Thymeleaf等）工作原理。现在主流的开发方式是前后端分离，View由前端框架（Vue、React等）处理，后端不负责渲染页面，只负责提供数据。
- 前后端分离时，后端通常不再返回具体的视图，而是返回**纯数据**（通常是 JSON 格式），由前端负责渲染和展示。
- `View` 的部分在前后端分离的场景下往往不需要设置，Spring MVC 的控制器方法只需要返回数据，不再返回 `ModelAndView`，而是直接返回数据，Spring 会自动将其转换为 JSON 格式。相应的，`ViewResolver` 也将不再被使用。
如何做到只返回JSON呢？
- 使用 `@RestController` 注解代替传统的 `@Controller` 注解，这样所有方法默认会返回 JSON 格式的数据，而不是试图解析视图。
- 如果你使用的是 `@Controller`，可以结合 `@ResponseBody` 注解来返回 JSON。

统一异常处理怎么做？
使用注解的方式统一异常处理，具体会使用到 `@ControllerAdvice` + `@ExceptionHandler` 这两个注解 。
```java
@ControllerAdvice
@ResponseBody
public class GlobalExceptionHandler {

    @ExceptionHandler(BaseException.class)
    public ResponseEntity<?> handleAppException(BaseException ex, HttpServletRequest request) {
      //......
    }

    @ExceptionHandler(value = ResourceNotFoundException.class)
    public ResponseEntity<ErrorReponse> handleResourceNotFoundException(ResourceNotFoundException ex, HttpServletRequest request) {
      //......
    }
}
```
给所有或者指定的 `Controller` 织入异常处理的逻辑（AOP），当 `Controller` 中的方法抛出异常的时候，由被`@ExceptionHandler` 注解修饰的方法进行处理。
`ExceptionHandlerMethodResolver` 中 `getMappedMethod` 方法决定了异常具体被哪个被 `@ExceptionHandler` 注解修饰的方法处理异常。
从源代码看出：**`getMappedMethod()`会首先找到可以匹配处理异常的所有方法信息，然后对其进行从小到大的排序，最后取最小的那一个匹配的方法(即匹配度最高的那个)。**

## Spring框架中用到了哪些设计模式？
- **工厂设计模式** : Spring 使用工厂模式通过 `BeanFactory`、`ApplicationContext` 创建 bean 对象。
- **代理设计模式** : Spring AOP 功能的实现。
- **单例设计模式** : Spring 中的 Bean 默认都是单例的。
- **模板方法模式** : Spring 中 `jdbcTemplate`、`hibernateTemplate` 等以 Template 结尾的对数据库操作的类，它们就使用到了模板模式。
- **包装器设计模式** : 我们的项目需要连接多个数据库，而且不同的客户在每次访问中根据需要会去访问不同的数据库。这种模式让我们可以根据客户的需求能够动态切换不同的数据源。
- **观察者模式:** Spring 事件驱动模型就是观察者模式很经典的一个应用。
- **适配器模式** : Spring AOP 的增强或通知(Advice)使用到了适配器模式、spring MVC 中也是用到了适配器模式适配`Controller`。

## Spring的循环依赖
Spring循环依赖了解吗，怎么解决？
循环依赖是指 Bean 对象循环引用，是两个或多个 Bean 之间相互持有对方的引用，例如 CircularDependencyA → CircularDependencyB → CircularDependencyA。
```java
@Component
public class CircularDependencyA {
    @Autowired
    private CircularDependencyB circB;
}

@Component
public class CircularDependencyB {
    @Autowired
    private CircularDependencyA circA;
}
```
单个对象的自我依赖也会出现循环依赖。
```java
@Component
public class CircularDependencyA {
    @Autowired
    private CircularDependencyA circA;
}
```
Spring 框架通过使用三级缓存来解决这个问题，确保即使在循环依赖的情况下也能正确创建 Bean。
Spring 中的三级缓存其实就是三个 Map，如下：
```java
// 一级缓存
/** Cache of singleton objects: bean name to bean instance. */
private final Map<String, Object> singletonObjects = new ConcurrentHashMap<>(256);

// 二级缓存
/** Cache of early singleton objects: bean name to bean instance. */
private final Map<String, Object> earlySingletonObjects = new HashMap<>(16);

// 三级缓存
/** Cache of singleton factories: bean name to ObjectFactory. */
private final Map<String, ObjectFactory<?>> singletonFactories = new HashMap<>(16);
```
1. **一级缓存（singletonObjects）**：存放最终形态的 Bean（已经实例化、属性填充、初始化），单例池，为“Spring 的单例属性”⽽⽣。一般情况我们获取 Bean 都是从这里获取的，但是并不是所有的 Bean 都在单例池里面，例如原型 Bean 就不在里面。
2. **二级缓存（earlySingletonObjects）**：存放过渡 Bean（半成品，尚未属性填充），也就是三级缓存中`ObjectFactory`产生的对象，与三级缓存配合使用的，可以防止 AOP 的情况下，每次调用`ObjectFactory#getObject()`都是会产生新的代理对象的。
3. **三级缓存（singletonFactories）**：存放`ObjectFactory`，`ObjectFactory`的`getObject()`方法（最终调用的是`getEarlyBeanReference()`方法）可以生成原始 Bean 对象或者代理对象（如果 Bean 被 AOP 切面代理）。三级缓存只会对单例 Bean 生效。
Spring创建Bean的流程：
4. 先去 **一级缓存 `singletonObjects`** 中获取，存在就返回；
5. 如果不存在或者对象正在创建中，于是去 **二级缓存 `earlySingletonObjects`** 中获取；
6. 如果还没有获取到，就去 **三级缓存 `singletonFactories`** 中获取，通过执行 `ObjectFacotry` 的 `getObject()` 就可以获取该对象，获取成功之后，从三级缓存移除，并将该对象加入到二级缓存中。
Spring在创建Bean的时候，如果允许循环依赖，就会将刚刚实例化完成，但是属性还没有初始化的Bean对象提前暴露，通过`addSingletonFactory`向三级缓存中添加一个ObjectFactory对象。
```java
class A {
    // 使用了 B
    private B b;
}
class B {
    // 使用了 A
    private A a;
}
```
以上面的循环依赖代码为例，解决循环依赖的流程如下：
1. Spring创建A之后，发现A依赖B，又去创建B，B依赖A，又去创建A
2. 当B创建A时，A发生了循环依赖，由于A还没有初始化完成，一二级缓存中没有A
3. 就去三级缓存中调用getObject方法获取A的前期暴露对象
4. 将ObjectFactory从三级缓存中删除，将前期暴露对象放入二级缓存中，那么 B 就将这个前期暴露对象注入到依赖，来支持循环依赖。

在没有AOP的情况下，一二级缓存就可以解决循环依赖的问题。但是AOP需要三级缓存，确保了Bean的创建过程有多次对早期引用的请求，始终返回同一个代理对象，避免了一个Bean有多个代理对象的问题。
**最后总结一下 Spring 如何解决三级缓存**：
在三级缓存这一块，主要记一下 Spring 是如何支持循环依赖的即可，也就是如果发生循环依赖的话，就去 **三级缓存 `singletonFactories`** 中拿到三级缓存中存储的 `ObjectFactory` 并调用它的 `getObject()` 方法来获取这个循环依赖对象的前期暴露对象（虽然还没初始化完成，但是可以拿到该对象在堆中的存储地址了），并且将这个前期暴露对象放到二级缓存中，这样在循环依赖时，就不会重复初始化了！
不过，这种机制也有一些缺点，比如增加了内存开销（需要维护三级缓存，也就是三个 Map），降低了性能（需要进行多次检查和转换）。并且，还有少部分情况是不支持循环依赖的，比如非单例的 bean 和`@Async`注解的 bean 无法支持循环依赖

@Lazy能解决循环依赖吗？
`@Lazy` 用来标识类是否需要懒加载/延迟加载，可以作用在类上、方法上、构造器上、方法参数上、成员变量中。
Spring Boot2.2新增了全局懒加载属性，开启后全局bean被设置为懒加载，需要时再去创建。
`spring.main.lazy-initialization=true`
如非必要，尽量不要用全局懒加载。全局懒加载会让 Bean 第一次使用的时候加载会变慢，并且它会延迟应用程序问题的发现（当 Bean 被初始化时，问题才会出现）。
如果一个 Bean 没有被标记为懒加载，那么它会在 Spring IoC 容器启动的过程中被创建和初始化。如果一个 Bean 被标记为懒加载，那么它不会在 Spring IoC 容器启动时立即实例化，而是在第一次被请求时才创建。这可以帮助减少应用启动时的初始化时间，也可以用来解决循环依赖问题。
`@Lazy` 能够在一定程度上打破循环依赖链，允许 Spring 容器顺利地完成 Bean 的创建和注入。但这并不是一个根本性的解决方案，尤其是在构造函数注入、复杂的多级依赖等场景中，`@Lazy` 无法有效地解决问题。因此，==最佳实践仍然是尽量避免设计上的循环依赖==。

SpringBoot允许循环依赖发生吗？
SpringBoot2.6之前是允许循环依赖的，不会报错。SpringBoot 2.6.x 以后官方不再推荐编写存在循环依赖的代码，建议开发者自己写代码的时候去减少不必要的互相依赖。
SpringBoot 2.6.x 以后，如果你不想重构循环依赖的代码的话，也可以采用下面这些方法：
- 在全局配置文件中设置允许循环依赖存在：`spring.main.allow-circular-references=true`。最简单粗暴的方式，不太推荐。
- 在导致循环依赖的 Bean 上添加 `@Lazy` 注解，这是一种比较推荐的方式。`@Lazy` 用来标识类是否需要懒加载/延迟加载，可以作用在类上、方法上、构造器上、方法参数上、成员变量中。

## Spring事务
Spring管理事务的方式有几种？
- **编程式事务**：在代码中硬编码(在分布式系统中推荐使用) : 通过 `TransactionTemplate`或者 `TransactionManager` 手动管理事务，事务范围过大会出现事务未提交导致超时，因此事务要比锁的粒度更小。
- **声明式事务**：在 XML 配置文件中配置或者直接基于注解（单体应用或者简单业务系统推荐使用） : 实际是通过 AOP 实现（基于`@Transactional` 的全注解方式使用最多）
```java title:使用TransactionTemplate
@Service
public class UserService {

    private final TransactionTemplate transactionTemplate;

    @Autowired
    public UserService(PlatformTransactionManager transactionManager) {
        this.transactionTemplate = new TransactionTemplate(transactionManager);
    }

    public void addUser(String username) {
        transactionTemplate.execute(new TransactionCallbackWithoutResult() {
            @Override
            protected void doInTransactionWithoutResult(TransactionStatus status) {
                try {
                    System.out.println("插入用户：" + username);
                    // userRepository.save(new User(username));

                    // 模拟异常
                    if ("error".equals(username)) {
                        throw new RuntimeException("模拟异常");
                    }
                } catch (Exception e) {
                    status.setRollbackOnly(); // 手动回滚
                }
            }
        });
    }
}
```

```java title:使用@Transactional
@Transactional  // 自动开启事务，异常时回滚
    public void createOrder(String orderNo) {
        System.out.println("创建订单：" + orderNo);
        // orderRepository.save(new Order(orderNo));

        // 模拟异常
        if ("error".equals(orderNo)) {
            throw new RuntimeException("订单创建失败");
        }
    }
```

Spring事务中有哪几种事务传播行为？
事务传播行为是为了解决业务层方法之间相互调用的事务问题。
当事务方法被另一个事务方法调用时，必须指定事务应该如何传播。例如：方法可能继续在现有事务中运行，也可能开启一个新事务，并在自己的事务中运行。
**1.`TransactionDefinition.PROPAGATION_REQUIRED`**
使用的最多的一个事务传播行为，我们平时经常使用的`@Transactional`注解默认使用就是这个事务传播行为。如果当前存在事务，则加入该事务；如果当前没有事务，则创建一个新的事务。
**`2.TransactionDefinition.PROPAGATION_REQUIRES_NEW`**
创建一个新的事务，如果当前存在事务，则把当前事务挂起。也就是说不管外部方法是否开启事务，`Propagation.REQUIRES_NEW`修饰的内部方法会新开启自己的事务，且开启的事务相互独立，互不干扰。
**3.`TransactionDefinition.PROPAGATION_NESTED`**
如果当前存在事务，则创建一个事务作为当前事务的嵌套事务来运行；如果当前没有事务，则该取值等价于`TransactionDefinition.PROPAGATION_REQUIRED`。
**4.`TransactionDefinition.PROPAGATION_MANDATORY`**
如果当前存在事务，则加入该事务；如果当前没有事务，则抛出异常。（mandatory：强制性）这个使用的很少。
若是错误的配置以下 3 种事务传播行为，事务将不会发生回滚：
- **`TransactionDefinition.PROPAGATION_SUPPORTS`**: 如果当前存在事务，则加入该事务；如果当前没有事务，则以非事务的方式继续运行。
- **`TransactionDefinition.PROPAGATION_NOT_SUPPORTED`**: 以非事务方式运行，如果当前存在事务，则把当前事务挂起。
- **`TransactionDefinition.PROPAGATION_NEVER`**: 以非事务方式运行，如果当前存在事务，则抛出异常。

Spring事务中隔离级别有哪几种？
枚举类：`Isolation`
- **`TransactionDefinition.ISOLATION_DEFAULT`** :使用后端数据库默认的隔离级别，MySQL 默认采用的 `REPEATABLE_READ` 隔离级别 Oracle 默认采用的 `READ_COMMITTED` 隔离级别.
- **`TransactionDefinition.ISOLATION_READ_UNCOMMITTED`** :最低的隔离级别，使用这个隔离级别很少，因为它允许读取尚未提交的数据变更，**可能会导致脏读、幻读或不可重复读**
- **`TransactionDefinition.ISOLATION_READ_COMMITTED`** : 允许读取并发事务已经提交的数据，**可以阻止脏读，但是幻读或不可重复读仍有可能发生**
- **`TransactionDefinition.ISOLATION_REPEATABLE_READ`** : 对同一字段的多次读取结果都是一致的，除非数据是被本身事务自己所修改，**可以阻止脏读和不可重复读，但幻读仍有可能发生。**
- **`TransactionDefinition.ISOLATION_SERIALIZABLE`** : 最高的隔离级别，完全服从 ACID 的隔离级别。所有的事务依次逐个执行，这样事务之间就完全不可能产生干扰，也就是说，**该级别可以防止脏读、不可重复读以及幻读**。但是这将严重影响程序的性能。通常情况下也不会用到该级别。

@Transactional(roolbackFor=Exception.class)注解了解吗？
`@Transactional` 注解默认回滚策略是只有在遇到`RuntimeException`(运行时异常) 或者 `Error` 时才会回滚事务，而不会回滚 `Checked Exception`（受检查异常）。这是因为 Spring 认为`RuntimeException`和 Error 是不可预期的错误，而受检异常是可预期的错误，可以通过业务逻辑来处理。
如果想要修改默认的回滚策略，可以使用 `@Transactional` 注解的 `rollbackFor` 和 `noRollbackFor` 属性来指定哪些异常需要回滚，哪些异常不需要回滚。

## Spring Data JPA
如何使用JPA在数据库中非持久化一个字段。
```java
static String transient1; // not persistent because of static
final String transient2 = "Satish"; // not persistent because of final
transient String transient3; // not persistent because of transient
@Transient
String transient4; // not persistent because of @Transient
```
一般后两种使用的比较多。

JPA的审计功能是做什么的？有什么用？
审计功能主要是帮助我们记录数据库操作的具体行为比如某条记录是谁创建的、什么时间创建的、最后修改人是谁、最后修改时间是什么时候。
```java
@Data
@AllArgsConstructor
@NoArgsConstructor
@MappedSuperclass
@EntityListeners(value = AuditingEntityListener.class)
public abstract class AbstractAuditBase {

    @CreatedDate
    @Column(updatable = false)
    @JsonIgnore
    private Instant createdAt;

    @LastModifiedDate
    @JsonIgnore
    private Instant updatedAt;

    @CreatedBy
    @Column(updatable = false)
    @JsonIgnore
    private String createdBy;

    @LastModifiedBy
    @JsonIgnore
    private String updatedBy;
}
```
- `@CreatedDate`: 表示该字段为创建时间字段，在这个实体被 insert 的时候，会设置值
    
- `@CreatedBy` :表示该字段为创建人，在这个实体被 insert 的时候，会设置值
    
    `@LastModifiedDate`、`@LastModifiedBy`同理。

实体之间的关联关系注解有哪些？
- `@OneToOne` : 一对一。
- `@ManyToMany`：多对多。
- `@OneToMany` : 一对多。
- `@ManyToOne`：多对一。
使用@ManyToOne和@OneToMany可以表达多对多的关联关系。

## Spring Security
有哪些控制请求访问权限的方法？
- `permitAll()`：无条件允许任何形式访问，不管你登录还是没有登录。
- `anonymous()`：允许匿名访问，也就是没有登录才可以访问。
- `denyAll()`：无条件决绝任何形式的访问。
- `authenticated()`：只允许已认证的用户访问。
- `fullyAuthenticated()`：只允许已经登录或者通过 remember-me 登录的用户访问。
- `hasRole(String)` : 只允许指定的角色访问。
- `hasAnyRole(String)` : 指定一个或者多个角色，满足其一的用户即可访问。
- `hasAuthority(String)`：只允许具有指定权限的用户访问
- `hasAnyAuthority(String)`：指定一个或者多个权限，满足其一的用户即可访问。
- `hasIpAddress(String)` : 只允许指定 ip 的用户访问。

hasRole和hasAuthority有区别吗？
**使用 `hasAuthority` 更具有一致性，你不用考虑要不要加 `ROLE_` 前缀，数据库什么样这里就是什么样！而 `hasRole` 则不同，代码里如果写的是 `admin`，框架会自动加上 `ROLE_` 前缀，所以数据库就必须是 `ROLE_admin`。**
> 设计理念：
> authority 描述的的是一个具体的权限，例如针对某一项数据的查询或者删除权限，它是一个 permission，例如 read_employee、delete_employee、update_employee 之类的，这些都是具体的权限，相信大家都能理解。
> role 则是一个 permission 的集合，它的命名约定就是以 `ROLE_` 开始，例如我们定义的 ROLE 是 `ROLE_ADMIN`、`ROLE_USER` 等等。我们在 Spring Security 中的很多地方都能看到对 Role 的特殊处理，例如上篇文章我们所讲的[投票器和决策器中](https://mp.weixin.qq.com/s?__biz=MzI1NDY0MTkzNQ==&mid=2247490093&idx=1&sn=0fc060f0dc3e00035517edce5fb4113f&scene=21#wechat_redirect)，RoleVoter 在处理 Role 时会自动添加 `ROLE_` 前缀。
> 一个 Role 就是某些 authority 的集合
> 在 Spring Security4 之后，才有了前缀 `ROLE_` 的区别。


如何对密码进行加密？
这些加密算法实现类的接口是 `PasswordEncoder` ，如果你想要自己实现一个加密算法的话，也需要实现 `PasswordEncoder` 接口。
`PasswordEncoder` 接口一共也就 3 个必须实现的方法。
```java
public interface PasswordEncoder {
    // 加密也就是对原始密码进行编码
    String encode(CharSequence var1);
    // 比对原始密码和数据库中保存的密码
    boolean matches(CharSequence var1, String var2);
    // 判断加密密码是否需要再次进行加密，默认返回 false
    default boolean upgradeEncoding(String encodedPassword) {
        return false;
    }
}
```
官方推荐使用基于 bcrypt 强哈希函数的加密算法实现类。

如何优雅更换系统使用的加密算法？
通过 `DelegatingPasswordEncoder` 兼容多种不同的密码加密方案，以适应不同的业务需求。`DelegatingPasswordEncoder` 其实就是一个代理类，并非是一种全新的加密算法，它做的事情就是代理上面提到的加密算法实现类。在 Spring Security 5.0 之后，默认就是基于 `DelegatingPasswordEncoder` 进行密码加密的。

---
例子：
假设系统原来使用 **BCrypt** 加密密码，但现在要支持 **PBKDF2** 或其他新算法。
```java
public static PasswordEncoder passwordEncoder() {
        // 定义不同的加密算法
        String defaultEncodingId = "bcrypt"; // 默认新用户使用 bcrypt
        Map<String, PasswordEncoder> encoders = new HashMap<>();
        encoders.put("bcrypt", new BCryptPasswordEncoder());
        encoders.put("pbkdf2", new Pbkdf2PasswordEncoder());

        // DelegatingPasswordEncoder 会根据密码前缀 {id} 来选择对应的加密器
        return new DelegatingPasswordEncoder(defaultEncodingId, encoders);
    }

    public static void main(String[] args) {
        PasswordEncoder encoder = passwordEncoder();

        // 新用户密码加密
        String rawPassword = "123456";
        String encodedPassword = encoder.encode(rawPassword);
        System.out.println("加密后密码: " + encodedPassword);

        // 登录校验
        boolean matches = encoder.matches(rawPassword, encodedPassword);
        System.out.println("密码匹配结果: " + matches);

        // 模拟老用户使用 PBKDF2 的密码
        String oldPassword = "{pbkdf2}" + new Pbkdf2PasswordEncoder().encode("123456");
        System.out.println("老用户加密: " + oldPassword);
        System.out.println("老用户密码匹配: " + encoder.matches("123456", oldPassword));
    }
```
只要在密码前加 `{id}` 前缀，就能区分不同加密算法。

