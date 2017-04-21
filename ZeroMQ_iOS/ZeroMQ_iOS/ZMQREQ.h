//
//  ZMQREQ.h
//  IP广播
//
//  Created by BaoLuniOS-3 on 2017/3/29.
//  Copyright © 2017年 ITC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface ZMQREQ : NSObject

/**
 * 发送异步的应答请求
 @param params  请求参数
 @param success 请求成功的回调Block
 @param failure 请求失败的回调Block
 @return 返回请求的对象，对请求任务进行控制
 */
+ (instancetype)startRequest:(NSDictionary *)params success:(void (^)(id data))success failure:(void (^)(NSError *error))failure;

/**
 *  设置要服务器的IP地址(所有请求共同使用)
 */
+ (void)setupDomainIP:(NSString *)ip;

/**
 *  结束消息的发送并关闭常驻线程
 */
+ (void)close;

/**
 *  设置要服务器的IP地址(当前对象使用)
 */
@property (copy, nonatomic) NSString *ip;

/**
 *  取消请求任务
 */
- (void)cancle;
@end
