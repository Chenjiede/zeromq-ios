//
//  ZMQSubscription.m
//  ZMQ通信
//
//  Created by BaoLuniOS-3 on 16/9/28.
//  Copyright © 2016年 ITC. All rights reserved.
//

#import "ZMQSubscription.h"

#import "ZMQObjC.h"

NSString* const Endpoint_status_msg = @"Endpoint_status_msg";

NSString* const Task_status_msg = @"Task_status_msg";

NSString* const Remote_music_status_msg = @"Remote_music_status_msg";

@interface ZMQSubscription ()

{
@private
    NSThread *_thread;
    
    ZMQContext *_context;
    
    ZMQSocket *_socket;
}

@property (strong, nonatomic) NSMutableDictionary *delegates;

@end

@implementation ZMQSubscription

- (NSMutableDictionary *)delegates {
    if (_delegates == nil) {
        _delegates = [[NSMutableDictionary alloc] init];
        _delegates[Task_status_msg] = [[NSMutableDictionary alloc] init];
    }
    
    return _delegates;
}

static BOOL closeSocket = NO;

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

#pragma mark - 修改后的方法
- (void)setCode:(NSString *)code withDelegate:(id<ZMQSubscriptionDelegate>)delegate {
    
    NSAssert(delegate == nil, @"代理为空");
    NSAssert(code == nil, @"订阅码为空");
    
    // 订阅码的类型
    if (code == Task_status_msg) { // 会话信息
        NSString *key = [NSString stringWithFormat:@"%ld", (unsigned long)[delegate hash]];
        NSMutableDictionary *tasks = self.delegates[Task_status_msg];
        tasks[key] = delegate;
        return;
    }
    
    self.delegates[code] = delegate;
}

- (void)removeDelegate:(NSString *)code withDelegate:(id<ZMQSubscriptionDelegate>)delegate {
    // 订阅码的类型
    if (code == Task_status_msg) { // 会话信息
        NSString *key = [NSString stringWithFormat:@"%ld", (unsigned long)[delegate hash]];
        NSMutableDictionary *tasks = self.delegates[Task_status_msg];
        [tasks removeObjectForKey:key];
        return;
    }
    
    [self.delegates removeObjectForKey:code];
}


- (void)removeAllDelegate {
    [self.delegates removeAllObjects];
}

- (void)start {
    if (closeSocket) {
        [self performSelector:@selector(startConnect) withObject:nil afterDelay:1.0];
        return;
    }
 
    [self startConnect];
}

- (void)startConnect {
    
    _thread = [[NSThread alloc] initWithTarget:self selector:@selector(subscriptonThread) object:nil];
    _thread.name = @"subscription";
    
    [_thread start];
}

/// 处理数据，并回调代理的方法
- (void)handleData:(NSString *)dataStr delegate:(id<ZMQSubscriptionDelegate>)delegate code:(NSString *)key {
    
    NSData *data = [dataStr dataUsingEncoding:NSUTF8StringEncoding];
    id msg = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    
    // 回到主线程
    dispatch_async(dispatch_get_main_queue(), ^{
        if ([delegate respondsToSelector:@selector(subscription:recieveData:keyCode:)]) {
            [delegate subscription:self recieveData:msg keyCode:key];
        }
    });
}

- (void)stop {
    // 判断是否需要重启socket
    id delegate = self.delegates[Endpoint_status_msg];
    if (delegate) {
        closeSocket = YES;
    }
}

#pragma mark - 使用可控线程来操作
- (void)subscriptonThread {
    
    NSLog(@"%@", [NSThread currentThread]);
    _context = [[ZMQContext alloc] initWithIOThreads:1];
    _socket = [_context socketWithType:ZMQ_SUB];
    _socket.loadingtime = 3000;

    
    NSString *endpoint = @"tcp://:41204"; // 服务器IP地址
    if (![_socket connectToEndpoint:endpoint]) {
        NSLog(@"订阅失败");
        return;
    }
    
    NSData *filterData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    [_socket setData:filterData forOption:ZMQ_SUBSCRIBE];
    
    (void)setvbuf(stdout, NULL, _IONBF, BUFSIZ);
    
    closeSocket = NO;
    
    while (!closeSocket) {
        
        @autoreleasepool {
            NSData *recieveData = [_socket receiveDataWithFlags:0];
            if (recieveData == nil)  continue;
            
            // 数据处理
            NSString *dataStr = [[NSString alloc] initWithData:recieveData encoding:NSUTF8StringEncoding];
            NSRange range = [dataStr rangeOfString:@"{" options:NSCaseInsensitiveSearch];
            NSString *subStr = [dataStr substringFromIndex:range.location];
            NSString *codeKey = [dataStr substringToIndex:range.location];
            
            /*** 数据分发 ***/
            // 订阅码的类型
            if (codeKey == Task_status_msg) { // 会话信息
                NSDictionary *tasks = self.delegates[codeKey];
                
                [tasks enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id<ZMQSubscriptionDelegate>  _Nonnull obj, BOOL * _Nonnull stop) {
                    
                    [self handleData:subStr delegate:obj code:Task_status_msg];
                }];
                
            } else {
                
                id<ZMQSubscriptionDelegate> delegate = self.delegates[codeKey];
                if (delegate) {
                    
                    [self handleData:subStr delegate:delegate code:codeKey];
                }
            }
            
        }
        
    }
    
    [self clean];
}

- (void)clean {
    NSLog(@"clean");
    // 关闭socket
    [_context closeSockets];
    [_socket close];
    _context = nil;
    _socket = nil;
    
    _thread = nil;
}
@end
