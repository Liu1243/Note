## IO流
Java IO 流的 40 多个类都是从如下 4 个抽象类基类中派生出来的。
- `InputStream`/`Reader`: 所有的输入流的基类，前者是字节输入流，后者是字符输入流。
- `OutputStream`/`Writer`: 所有输出流的基类，前者是字节输出流，后者是字符输出流。

## 字节流
### InputStream 字节输入流
常用方法：
- read() read(byte b\[]) read(byte \[], int off, int len)
- skip(long n) 
- available() 
- close()
Java9，增加了多个实用方法：
- readAllBytes()：读取所有字节，返回字节数组
- readnBytes(byte\[] b, int off, in len)：阻塞读取len个字节
- transferTo(OutputStream out)：将所有字节从一个输入流传递到一个输出流

`FileInputStream` 是一个比较常用的字节输入流对象，可直接指定文件路径，可以直接读取单字节数据，也可以读取至字节数组中。
一般我们是不会直接单独使用 `FileInputStream` ，通常会配合 `BufferedInputStream`（字节缓冲输入流，后文会讲到）来使用。
通过readAllBytes()读取输入流所有字节并将其赋值给一个String对象：
```java
// 新建一个 BufferedInputStream 对象
BufferedInputStream bufferedInputStream = new BufferedInputStream(new FileInputStream("input.txt"));
// 读取文件的内容并复制到 String 对象中
String result = new String(bufferedInputStream.readAllBytes());
System.out.println(result);
```
`DataInputStream` 用于读取指定类型数据，不能单独使用，必须结合其它流，比如 `FileInputStream` 。
`ObjectInputStream` 用于从输入流中读取 Java 对象（反序列化），`ObjectOutputStream` 用于将对象写入到输出流(序列化)。用于序列化和反序列化的类必须实现Serializable接口，如果有属性不想被徐磊话，实用transient修饰。

### OutputStream 字节输出流
常用方法：
- write(int b) write(byte b\[]) write(byte \[], int off, int len)
- flush()
- close()
`FileOutputStream` 是最常用的字节输出流对象，可直接指定文件路径，可以直接输出单字节数据，也可以输出指定的字节数组。
`FileOutputStream` 通常也会配合 `BufferedOutputStream`（字节缓冲输出流，后文会讲到）来使用。
**`DataOutputStream`** 用于写入指定类型数据，不能单独使用，必须结合其它流，比如 `FileOutputStream` 。
`ObjectInputStream` 用于从输入流中读取 Java 对象（`ObjectInputStream`,反序列化），`ObjectOutputStream`将对象写入到输出流(`ObjectOutputStream`，序列化)。

## 字符流
**为什么 I/O 流操作要分为字节流操作和字符流操作呢？**
- 字符流是由 Java 虚拟机将字节转换得到的，这个过程还算是比较耗时。
- 如果我们不知道编码类型就很容易出现乱码问题。
字符流默认采用的是 `Unicode` 编码，我们可以通过构造方法自定义编码。
> Unicode 本身只是一种字符集，它为每个字符分配一个唯一的数字编号，并没有规定具体的存储方式。UTF-8、UTF-16、UTF-32 都是 Unicode 的编码方式，它们使用不同的字节数来表示 Unicode 字符。例如，UTF-8 :英文占 1 字节，中文占 3 字节。

### Reader 字符输入流
`Reader` 用于读取文本， `InputStream` 用于读取原始字节。
常用方法：
- read() read(char\[] cbuf) read(char\[] cbuf, int off, int len)
- skip(long n)
- close()
`InputStreamReader` 是字节流转换为字符流的桥梁，其子类 `FileReader` 是基于该基础上的封装，可以直接操作字符文件。
```java
// 字节流转换为字符流的桥梁
public class InputStreamReader extends Reader {
}
// 用于读取字符文件
public class FileReader extends InputStreamReader {
}
```

### Writer 字符输出流
`OutputStreamWriter` 是字符流转换为字节流的桥梁，其子类 `FileWriter` 是基于该基础上的封装，可以直接将字符写入到文件。

## 字节缓冲流
IO 操作是很消耗性能的，缓冲流将数据加载至缓冲区，一次性读取/写入多个字节，从而避免频繁的 IO 操作，提高流的传输效率。
采用了装饰器模式来增强 `InputStream` 和`OutputStream`子类对象的功能。
通过 `BufferedInputStream`（字节缓冲输入流）来增强 `FileInputStream` 的功能。
```java
// 新建一个 BufferedInputStream 对象
BufferedInputStream bufferedInputStream = new BufferedInputStream(new FileInputStream("input.txt"));
```

### BufferedInputStream 字节缓冲输入流
`BufferedInputStream` 内部维护了一个缓冲区，这个缓冲区实际就是一个字节数组
```java
public
class BufferedInputStream extends FilterInputStream {
    // 内部缓冲区数组
    protected volatile byte buf[];
    // 缓冲区的默认大小
    private static int DEFAULT_BUFFER_SIZE = 8192;
    // 使用默认的缓冲区大小
    public BufferedInputStream(InputStream in) {
        this(in, DEFAULT_BUFFER_SIZE);
    }
    // 自定义缓冲区大小
    public BufferedInputStream(InputStream in, int size) {
        super(in);
        if (size <= 0) {
            throw new IllegalArgumentException("Buffer size <= 0");
        }
        buf = new byte[size];
    }
}
```
缓冲区的大小默认为 **8192** 字节，当然了，你也可以通过 `BufferedInputStream(InputStream in, int size)` 这个构造方法来指定缓冲区的大小。

### BufferedOutputStream 字节缓冲输出流
`BufferedOutputStream` 内部也维护了一个缓冲区，并且，这个缓存区的大小也是 **8192** 字节。

## 字符缓冲流
BufferedReader和BufferedWriter类似于BufferedInputStream和BufferedOutputStream，内部都维护了一个字节数组作为缓冲区。

## 打印流
`System.out` 实际是用于获取一个 `PrintStream` 对象，`print`方法实际调用的是 `PrintStream` 对象的 `write` 方法。
`PrintStream` 属于字节打印流，与之对应的是 `PrintWriter` （字符打印流）。`PrintStream` 是 `OutputStream` 的子类，`PrintWriter` 是 `Writer` 的子类。
```java
public class PrintStream extends FilterOutputStream
    implements Appendable, Closeable {
}
public class PrintWriter extends Writer {
}
```

## 随机访问流
支持随意跳转到文件的任意位置进行读写的 `RandomAccessFile`
`RandomAccessFile` 的构造方法如下，我们可以指定 `mode`（读写模式）。
```java
// openAndDelete 参数默认为 false 表示打开文件并且这个文件不会被删除
public RandomAccessFile(File file, String mode)
    throws FileNotFoundException {
    this(file, mode, false);
}
// 私有方法
private RandomAccessFile(File file, String mode, boolean openAndDelete)  throws FileNotFoundException{
  // 省略大部分代码
}
```
读写模式主要有下面四种：
- `r` : 只读模式。
- `rw`: 读写模式
- `rws`: 相对于 `rw`，`rws` 同步更新对“文件的内容”或“元数据”的修改到外部存储设备。
- `rwd` : 相对于 `rw`，`rwd` 同步更新对“文件的内容”的修改到外部存储设备。
文件内容指的是文件中实际保存的数据，元数据则是用来描述文件属性比如文件的大小信息、创建和修改时间。
`RandomAccessFile` 比较常见的一个应用就是实现大文件的 ==**断点续传**== 。何谓断点续传？简单来说就是上传文件中途暂停或失败（比如遇到网络问题）之后，不需要重新上传，只需要上传那些未成功上传的文件分片即可。分片（先将文件切分成多个文件分片）上传是断点续传的基础。
`RandomAccessFile` 的实现依赖于 `FileDescriptor` (文件描述符) 和 `FileChannel` （内存映射文件）。

---
## IO设计模式总结
### 装饰器模式
在不改变原有对象的情况下拓展其功能。
装饰器模式通过组合替代继承来扩展原始类的功能，在一些继承关系比较复杂的场景（IO 这一场景各种类的继承关系就比较复杂）更加实用。
对于字节流来说，FilterInputStream用于增强InputStream子类的功能，FilterOutputStream同理。
BufferedInputStream、DataInputStream都是FilterInputStream的子类。
ZipInputStream增强BufferedInputStream的能力。
ZipInputStream继承自InflaterInputStream。

### 适配器模式
适配器模式主要用于接口不兼容的类的协调工作。
适配器模式中存在被适配的对象或者类称为 **适配者(Adaptee)** ，作用于适配者的对象或者类称为**适配器(Adapter)** 。适配器分为对象适配器和类适配器。类适配器使用继承关系来实现，对象适配器使用组合关系来实现。
将字节流对象转换为字符流对象，就需要适配器。
`InputStreamReader` 和 `OutputStreamWriter` 就是两个适配器(Adapter)， 同时，它们两个也是字节流和字符流之间的桥梁。`InputStreamReader` 使用 `StreamDecoder` （流解码器）对字节进行解码，**实现字节流到字符流的转换，** `OutputStreamWriter` 使用`StreamEncoder`（流编码器）对字符进行编码，实现字符流到字节流的转换。
`InputStream` 和 `OutputStream` 的子类是被适配者， `InputStreamReader` 和 `OutputStreamWriter`是适配器。

适配器模式和装饰器模式的区别？
**装饰器模式** 更侧重于动态地增强原始类的功能，装饰器类需要跟原始类继承相同的抽象类或者实现相同的接口。并且，装饰器模式支持对原始类嵌套使用多个装饰器。
**适配器模式** 更侧重于让接口不兼容而不能交互的类可以一起工作，当我们调用适配器对应的方法时，适配器内部会调用适配者类或者和适配类相关的类的方法，这个过程透明的。就比如说 `StreamDecoder` （流解码器）和`StreamEncoder`（流编码器）就是分别基于 `InputStream` 和 `OutputStream` 来获取 `FileChannel`对象并调用对应的 `read` 方法和 `write` 方法进行字节数据的读取和写入。
适配器和适配者两者不需要继承相同的抽象类或者实现相同的接口。  
另外，`FutureTask` 类使用了适配器模式，`Executors` 的内部类 `RunnableAdapter` 实现属于适配器，用于将 `Runnable` 适配成 `Callable`。

### 工厂模式
工厂模式用于创建对象，NIO 中大量用到了工厂模式，比如 `Files` 类的 `newInputStream` 方法用于创建 `InputStream` 对象（静态工厂）、 `Paths` 类的 `get` 方法创建 `Path` 对象（静态工厂）、`ZipFileSystem` 类（`sun.nio`包下的类，属于 `java.nio` 相关的一些内部实现）的 `getPath` 的方法创建 `Path` 对象（简单工厂）。

### 观察者模式
NIO中的文件目录监听服务使用了观察者模式。
NIO 中的文件目录监听服务基于 `WatchService` 接口和 `Watchable` 接口。`WatchService` 属于观察者，`Watchable` 属于被观察者。
`Watchable` 接口定义了一个用于将对象注册到 `WatchService`（监控服务） 并绑定监听事件的方法 `register` 。

## Java IO模型详解
用户执行IO操作，必须通过**系统调用**来间接访问内核空间
当应用程序发起 I/O 调用后，会经历两个步骤：
1. 内核等待 I/O 设备准备好数据
2. 内核将数据从内核空间拷贝到用户空间。
UNIX系统下，IO模型有5种：**同步阻塞 I/O**、**同步非阻塞 I/O**、**I/O 多路复用**、**信号驱动 I/O** 和**异步 I/O**。

### Java中3种常见IO模型
BIO， Blocking IO 同步阻塞IO
程序read调用后会一直阻塞，直到内核把数据拷贝到用户空间
连接数大时，BIO无法处理更高的并发量

NIO Non-Blocking IO IO多路复用模型
1.4引入NIO，提供了 `Channel` , `Selector`，`Buffer` 等抽象。NIO 中的 N 可以理解为 Non-blocking，不单纯是 New。它是支持面向缓冲的，基于通道的 I/O 操作方法。 对于高负载、高并发的（网络）应用，应使用 NIO 。
> 同步非阻塞IO，程序轮询read，等待数据从内核空间拷贝到用户空间的时间内，线程依然是阻塞的
> ![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/0d07f43c1cf0e1b067459b7892e51dcc_MD5.jpeg)
> **应用程序不断进行 I/O 系统调用轮询数据是否已经准备好的过程是十分消耗 CPU 资源的。**

IO多路复用模型：
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/d67727470dc1703615c5908ad92ed122_MD5.jpeg)
线程首先select，询问内核数据是否准备就绪，等数据准备就绪后再read，read调用的过程还是阻塞的。
> - **select 调用**：内核提供的系统调用，它支持一次查询多个系统调用的可用状态。几乎所有的操作系统都支持。
> - **epoll 调用**：linux 2.6 内核，属于 select 调用的增强版本，优化了 IO 的执行效率。

**IO 多路复用模型，通过减少无效的系统调用，减少了对 CPU 资源的消耗。**
Java的NIO，有选择器（Selector），成为多路复用器。一个线程可以管理多个客户端连接，当客户端的数据到了，才为其服务。
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/3ddf923f0d057f7a88af06012bb56592_MD5.jpeg)

AIO，Asynchronous IO 异步IO
7引入了NIO的改进版NIO2，也就是AIO，是异步IO模型。
异步IO是基于事件和回调机制实现的。
目前来说 AIO 的应用还不是很广泛。Netty 之前也尝试使用过 AIO，不过又放弃了。这是因为，Netty 使用了 AIO 之后，在 Linux 系统上的性能并没有多少提升。
总结Java中的BIO、NIO、AIO
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/81ffd664774ec7051952cd5576bbc9ee_MD5.jpeg)

## Java NIO核心知识总结
> 使用 NIO 并不一定意味着高性能，它的性能优势主要体现在高并发和高延迟的网络环境下。当连接数较少、并发程度较低或者网络传输速度较快时，NIO 的性能并不一定优于传统的 BIO 。

NIO核心组件：
- **Buffer（缓冲区）**：NIO 读写数据都是通过缓冲区进行操作的。读操作的时候将 Channel 中的数据填充到 Buffer 中，而写操作时将 Buffer 中的数据写入到 Channel 中。
- **Channel（通道）**：Channel 是一个双向的、可读可写的数据传输通道，NIO 通过 Channel 来实现数据的输入输出。通道是一个抽象的概念，它可以代表文件、套接字或者其他数据源之间的连接。
- **Selector（选择器）**：允许一个线程处理多个 Channel，基于事件驱动的 I/O 多路复用模型。所有的 Channel 都可以注册到 Selector 上，由 Selector 来分配线程来处理事件。

Buffer
传统BIO分为字节流和字符流。
1.4的NIO中，所有数据都是缓冲区处理的。
Buffer子类如下图，最常用的是ByteBuffer，用来存储和操作字节数组
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/772bbe6c34d57fca968874fd680d2dfa_MD5.jpeg)
可以将 Buffer 理解为一个数组，`IntBuffer`、`FloatBuffer`、`CharBuffer` 等分别对应 `int[]`、`float[]`、`char[]` 等。

Buffer类中定义的四个成员变量：
1. 容量（`capacity`）：`Buffer`可以存储的最大数据量，`Buffer`创建时设置且不可改变；
2. 界限（`limit`）：`Buffer` 中可以读/写数据的边界。写模式下，`limit` 代表最多能写入的数据，一般等于 `capacity`（可以通过`limit(int newLimit)`方法设置）；读模式下，`limit` 等于 Buffer 中实际写入的数据大小。
3. 位置（`position`）：下一个可以被读写的数据的位置（索引）。从写操作模式到读操作模式切换的时候（flip），`position` 都会归零，这样就可以从头开始读写了。
4. 标记（`mark`）：`Buffer`允许将位置直接定位到该标记处，这是一个可选属性；
**0 <= mark <= position <= limit <= capacity**

Buffer有读模式和写模式，被创建后默认是写模式，通过flip()切换到读模式，clear()或者compact()切换到写模式。
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/d5f5f7185ea5feda548894ee782711aa_MD5.jpeg)
`Buffer` 对象不能通过 `new` 调用构造方法创建对象 ，只能通过静态方法实例化 `Buffer`。
ByteBuffer创建对象方法：
```java
// 分配堆内存
public static ByteBuffer allocate(int capacity);
// 分配直接内存
public static ByteBuffer allocateDirect(int capacity);
```

Channel 通道
BIO 中的流是单向的，分为各种 `InputStream`（输入流）和 `OutputStream`（输出流），数据只是在一个方向上传输。通道与流的不同之处在于通道是双向的，它可以用于读、写或者同时用于读写。
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/4a894bd0b7cb2dc66ff8b010a76b96fa_MD5.jpeg)
因为 Channel 是全双工的，所以它可以比流更好地映射底层操作系统的 API。特别是在 UNIX 网络编程模型中，底层操作系统的通道都是全双工的，同时支持读写操作。
最常用的是以下几种类型的通道：
- `FileChannel`：文件访问通道；
- `SocketChannel`、`ServerSocketChannel`：TCP 通信通道；
- `DatagramChannel`：UDP 通信通道；
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/1b9e27f38c411d3e6da626e79cb76652_MD5.jpeg)

Selector 选择器
Selector（选择器） 是 NIO 中的一个关键组件，它允许一个线程处理多个 Channel。
Selector 是基于事件驱动的 I/O 多路复用模型，主要运作原理是：通过 Selector 注册通道的事件，Selector 会不断地轮询注册在其上的 Channel。当事件发生时，比如：某个 Channel 上面有新的 TCP 连接接入、读和写事件，这个 Channel 就处于就绪状态，会被 Selector 轮询出来。Selector 会将相关的 Channel 加入到就绪集合中。通过 SelectionKey 可以获取就绪 Channel 的集合，然后对这些就绪的 Channel 进行相应的 I/O 操作。
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/b7482d166aee18af9a6fe47593a5915b_MD5.jpeg)
由于 JDK 使用了 `epoll()` 代替传统的 `select` 实现，所以它并没有最大连接句柄 `1024/2048` 的限制。这也就意味着只需要一个线程负责 Selector 的轮询，就可以接入成千上万的客户端。
Selector 可以监听以下四种事件类型：
1. `SelectionKey.OP_ACCEPT`：表示通道接受连接的事件，这通常用于 `ServerSocketChannel`。
2. `SelectionKey.OP_CONNECT`：表示通道完成连接的事件，这通常用于 `SocketChannel`。
3. `SelectionKey.OP_READ`：表示通道准备好进行读取的事件，即有数据可读。
4. `SelectionKey.OP_WRITE`：表示通道准备好进行写入的事件，即可以写入数据。
Selector是抽象类，通过open静态方法创建Selector实例。可以同时监控多个SelectableChannel的IO状况，是非阻塞IO的核心。

一个Selector实例有三种SelectionKey集合：
- 所有的SelectionKey集合，通过keys()方法返回
- 被选择的SelectionKey集合：通过selectedKey()返回
- 被取消的SelectionKey集合：下次执行select方法，这些Channel对应的SelectionKey会被删除

NIO零拷贝
提高IO性能，像 ActiveMQ、Kafka 、RocketMQ、QMQ、Netty 等顶级开源项目都用到了零拷贝。
零拷贝时，CPU 不需要将数据从一个存储区域复制到另一个存储区域，从而可以减少上下文切换以及 CPU 的拷贝时间。也就是说，零拷贝主要解决操作系统在处理 I/O 操作时频繁复制数据的问题。零拷贝的常见实现技术有： `mmap+write`、`sendfile`和 `sendfile + DMA gather copy` 。
![](Java%E9%9D%A2%E7%BB%8F/javaguide/attachments/89d5c04f468afdec64d67281554a871e_MD5.jpeg)
2次DMA拷贝无法避免，是依赖硬件完成的。零拷贝只要是减少了CPU拷贝以及上下文切换。
Java对零拷贝的支持：
- `MappedByteBuffer` 是 NIO 基于内存映射（`mmap`）这种零拷⻉⽅式的提供的⼀种实现，底层实际是调用了 Linux 内核的 `mmap` 系统调用。它可以将一个文件或者文件的一部分映射到内存中，形成一个虚拟内存文件，这样就可以直接操作内存中的数据，而不需要通过系统调用来读写文件。
- `FileChannel` 的`transferTo()/transferFrom()`是 NIO 基于发送文件（`sendfile`）这种零拷贝方式的提供的一种实现，底层实际是调用了 Linux 内核的 `sendfile`系统调用。它可以直接将文件数据从磁盘发送到网络，而不需要经过用户空间的缓冲区。

使用NIO构建网络程序，建议使用Netty。Netty在NIO基础上进行了优化和拓展，支持SSL、TSL等。













