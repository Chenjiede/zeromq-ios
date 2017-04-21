//
//  ViewController.m
//  ZeroMQ_iOS
//
//  Created by chen on 2017/4/9.
//  Copyright © 2017年 chen. All rights reserved.
//

#import "ViewController.h"

#import "ZMQREQ.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    ZMQREQ *task = [ZMQREQ startRequest:@{@"name" : @"chen"} success:^(id data) {
        NSLog(@"%@", data);
    } failure:^(NSError *error) {
        NSLog(@"失败");
    }];
    
    // 取消任务
    [task cancle];
}

@end
