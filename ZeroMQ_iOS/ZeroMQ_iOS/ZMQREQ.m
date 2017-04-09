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

@property (strong, nonatomic) ZMQContext *context;

@property (strong, nonatomic) NSMutableArray *sockets;

@property (strong, nonatomic) NSThread *thread;

@property (strong, nonatomic) NSMutableDictionary *successDict;

@property (strong, nonatomic) NSMutableDictionary *failureDict;

@end

@implementation ZMQREQ


#pragma mark - 懒加载
- (ZMQContext *)context {
    if (_context == nil) {
        _context = [[ZMQContext alloc] initWithIOThreads:1];
    }
    
    return _context;
}

- (NSMutableArray *)sockets {
    if (_sockets == nil) {
        _sockets = [NSMutableArray array];
    }
    
    return _sockets;
}

- (NSThread *)thread {
    if (_thread == nil) {
        _thread = [[NSThread alloc] initWithTarget:self selector:@selector(backgroundThread) object:nil];
        _thread.name = @"zmqREQ";
        [_thread start];
    }
    
    return _thread;
}

- (NSMutableDictionary *)successDict {
    if (_successDict == nil) {
        _successDict = [NSMutableDictionary dictionary];
    }
    
    return _successDict;
}

- (NSMutableDictionary *)failureDict {
    if (_failureDict == nil) {
        _failureDict = [NSMutableDictionary dictionary];
    }
    
    return _failureDict;
}

#pragma mark - runloop
/// 启动子线程，并激活RunLoop
- (void)backgroundThread {
    
    @autoreleasepool {
        NSThread *currentThread = [NSThread currentThread];
        BOOL isCancelled = [currentThread isCancelled];
        
        NSLog(@"start -- %@", currentThread);
        NSRunLoop *currentRunLoop = [NSRunLoop currentRunLoop];
        
        // 开启runloop
        [currentRunLoop addPort:[NSMachPort port] forMode:NSDefaultRunLoopMode];
        
        while (!isCancelled && [currentRunLoop runMode:NSDefaultRunLoopMode beforeDate:[NSDate distantFuture]]) {
            isCancelled = [currentThread isCancelled];
        }
        
        // 结束线程
        NSLog(@"end -- %@", currentThread);
    }
    
}

/// 让子线程执行发送的请求
- (void)requestInThread:(id)params {
    NSThread *currentThread = [NSThread currentThread];
    
    // 判断线程是否已经取消
    if (currentThread.isCancelled) { return; }
    
    // 获取缓存数组中的socket
    ZMQSocket *socket = self.sockets.lastObject;
    [self.sockets removeLastObject];
    
    // 获取block
    NSString *key = [params description];
    successType success = self.successDict[key];
    [self.successDict removeObjectForKey:key];
    failureType failure = self.failureDict[key];
    [self.failureDict removeObjectForKey:key];
    
    if (socket == nil) {
        socket = [self.context socketWithType:ZMQ_REQ];
        socket.loadingtime = 5000;
        
        NSString *endpoint = @"tcp://localhost:5555"; // 服务器IP地址
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
            if (failure) {
                failure(nil);
            }
        });
        
    }else{
        if (socket == nil) return ;
        
        NSData *reply = [socket receiveDataWithFlags:0]; // 阻塞当前线程，直到有数据返回
        // 判断线程是否已经取消
        if (currentThread.isCancelled) { return; }
        
        id data = nil;
        if (reply) {
            data = [NSJSONSerialization JSONObjectWithData:reply options:0 error:nil];
            [self.sockets addObject:socket];
        } else {
            [socket close];
            socket = nil;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if (success) {
                success(data);
            }
        });
    }
    
}

/// 空任务，唤醒线程
- (void)closeThread {}

#pragma mark - 外部接口方法
- (void)close {
    [_thread cancel];
    
    [self performSelector:@selector(closeThread) onThread:_thread withObject:nil waitUntilDone:NO];
    
    // 清空资源
    [self.sockets removeAllObjects];
    self.sockets = nil;
    
    [self.context closeSockets];
    [self.context terminate];
    
    [self.successDict removeAllObjects];
    self.successDict = nil;
    
    [self.failureDict removeAllObjects];
    self.failureDict = nil;
}

- (void)startRequest:(id)params success:(void (^)(id))success failure:(void (^)(NSError *))failure {
    if (params == nil) return;
    
    NSString *key = [params description];
    // 先保存block
    if (success != nil) {
        [self.successDict setObject:success forKey:key];
    }
    if (failure != nil) {
        [self.failureDict setObject:failure forKey:key];
    }
    
    // 异步请求
    [self performSelector:@selector(requestInThread:) onThread:self.thread withObject:params waitUntilDone:NO];
}

#pragma mark - 单例
+(instancetype)shareInstance {return [[self alloc]init];}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [super allocWithZone:zone];
    });
    return instance;
}

- (id)copyWithZone:(NSZone *)zone{return self;}

- (id)mutableCopyWithZone:(NSZone *)zone {return self;}

@end
