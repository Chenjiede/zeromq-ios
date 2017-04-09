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
 *  单例对象
 */
+(instancetype)shareInstance;

/**
 *  结束消息的发送，并关闭常驻线程
 */
- (void)close;

/**
 * 发送异步的应答请求
 @param params  请求参数
 @param success 请求成功的回调Block
 @param failure 请求失败的回调Block
 */
- (void)startRequest:(id)params success:(void (^)(id data))success failure:(void (^)(NSError *error))failure;
@end
