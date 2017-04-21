//
//  ZMQSubscription.h
//  ZMQ通信
//
//  Created by BaoLuniOS-3 on 16/9/28.
//  Copyright © 2016年 ITC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ZMQSubscription;

@protocol ZMQSubscriptionDelegate <NSObject>

@optional
- (void)subscription:(ZMQSubscription * _Nonnull)subscription recieveData:(_Nullable id)data keyCode:(NSString * _Nonnull)code;

@end

@interface ZMQSubscription : NSObject
 
/**
 *  设置订阅码的代理
 */
- (void)setCode:( NSString * _Nonnull )code withDelegate:(_Nonnull id<ZMQSubscriptionDelegate>)delegate;

/**
 *  如果不需要接收订阅信息，把订阅码对应的delegate移除
 */
- (void)removeDelegate:( NSString * _Nullable)code withDelegate:(_Nullable id<ZMQSubscriptionDelegate>)delegate;

/**
 *  移除所有的订阅delegate对象
 */
- (void)removeAllDelegate;

/**
 *  开始接收订阅消息
 */
- (void)start;

/**
 *  结束接收订阅消息，并关闭socket
 */
- (void)stop;

+(_Nonnull instancetype)shareInstance;
@end
