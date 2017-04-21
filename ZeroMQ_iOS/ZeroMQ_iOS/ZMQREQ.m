//
//  ZMQREQ.m
//  IP广播
//
//  Created by BaoLuniOS-3 on 2017/3/29.
//  Copyright © 2017年 ITC. All rights reserved.
//


#import "ZMQREQ.h"

#import "ZMQObjC.h"

typedef void(^successType)(id data);
typedef void (^failureType)(NSError *error);

@interface ZMQREQ ()
{
@private
    BOOL _isCancle;
}
@property (copy, nonatomic) successType successBlock;

@property (copy, nonatomic) failureType failureBlock;
@end

@implementation ZMQREQ

#pragma mark - 类方法
static ZMQContext *_context;
static NSMutableArray *_sockets;
static NSString *_ipCla;

+ (ZMQContext *)context {
    if (_context == nil) {
        _context = [[ZMQContext alloc] initWithIOThreads:1];
    }
    
    return _context;
}

+ (NSMutableArray *)sockets {
    if (_sockets == nil) {
        _sockets = [NSMutableArray array];
    }
    
    return _sockets;
}

+ (NSThread *)thread {
    
    static NSThread *thread = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        thread = [[NSThread alloc] initWithTarget:self selector:@selector(zmqREQThreadMain) object:nil];
        
        thread.name = @"zmqREQ";
        [thread start];
    });
    return thread;
}

+ (void)zmqREQThreadMain {
    @autoreleasepool {
        NSThread *currentThread = [NSThread currentThread];
        BOOL isCancelled = [currentThread isCancelled];
        NSLog(@"start - %@", currentThread);
        NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
        
        // 开启runloop
        [currentRunLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        
        while (!isCancelled && [currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
            isCancelled = [currentThread isCancelled];
        }
        
        NSLog(@"end - %@", currentThread);
    }
    
}

+ (void)setupDomainIP:(NSString *)ip {
    _ipCla = ip;
}

#pragma mark - runloop
- (void)requestInThread:(NSDictionary *)params {
    NSThread *currentThread = [NSThread currentThread];
    
    // 判断线程是否已经取消
    if (currentThread.isCancelled || _isCancle) { return; }
    
    // 获取缓存数组中的socket
    ZMQSocket *socket = [ZMQREQ sockets].lastObject;
    [[ZMQREQ sockets] removeLastObject];
    
    if (socket == nil) {
        socket = [[ZMQREQ context] socketWithType:ZMQ_REQ];
        socket.loadingtime = 8000;
        
        NSAssert(_ipCla.length != 0 || _ip.length != 0 , @"没有设置服务器的IP地址");
        NSString *endpoint = _ip.length > 0 ? _ip : _ipCla;
        if (![socket connectToEndpoint:endpoint]) {
            NSLog(@"监听失败");
            
            [socket close];
            socket = nil;
            
        }
        NSLog(@"创建socket");
    }
    
    NSData *json = [NSJSONSerialization dataWithJSONObject:params options:0 error:nil];
    
    if (![socket sendData:json withFlags:1]) {
        NSLog(@"发送失败");
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_failureBlock) {
                _failureBlock(nil);
            }
            
            _failureBlock = nil;
        });
        
    }else{
        if (socket == nil) return ;
        
        NSData *reply = [socket receiveDataWithFlags:0]; // 阻塞当前线程，直到有数据返回
        // 判断线程是否已经取消
        if (currentThread.isCancelled || _isCancle) { return; }
        
        id data = nil;
        if (reply) {
            data = [NSJSONSerialization JSONObjectWithData:reply options:0 error:nil];
            [[ZMQREQ sockets] addObject:socket];
        } else {
            [socket close];
            socket = nil;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (_successBlock) {
                _successBlock(data);
            }
            
            _successBlock = nil;
        });
    }
    
}

/// 空任务，唤醒线程
- (void)closeThread {}

#pragma mark - 外部接口方法
+ (void)close {
    [[ZMQREQ thread] cancel];
    
    [self performSelector:@selector(closeThread) onThread:[ZMQREQ thread] withObject:nil waitUntilDone:NO];
    
    // 清空资源
    [[ZMQREQ sockets] removeAllObjects];
    
    [[ZMQREQ context] closeSockets];
    [[ZMQREQ context] terminate];
}

- (void)startRequest:(NSDictionary *)params success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    // 判断线程是否已经关闭
    if ([ZMQREQ thread].isCancelled) return;
    
    // 先保存block
    _successBlock = success;
    _failureBlock = failure;
    
    // 异步请求
    [self performSelector:@selector(requestInThread:) onThread:[ZMQREQ thread] withObject:params waitUntilDone:NO];
}

+ (instancetype)startRequest:(NSDictionary *)params success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    ZMQREQ *zmq = [[ZMQREQ alloc] init];
    
    [zmq startRequest:params success:success failure:failure];
    
    return zmq;
}

- (void)cancle {
    _isCancle = YES;
}
@end
