//
//  ZLDownloadTask.h
//  ZLDownloadManager
//
//  Created by 周麟 on 2017/5/3.
//  Copyright © 2017年 周麟. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "ZLDownloadManger.h"

@interface ZLDownloadTask : NSObject
@property (nonatomic, strong) NSURLSession *session;
@property (nonatomic, assign) id<NSURLSessionDelegate>delegate;
@property (nonatomic, strong) NSURLSessionDownloadTask *task;
@property (nonatomic, assign) NSInteger taskIdentifier;
/** 下载地址 */
@property (nonatomic, copy) NSString *downloadUrl;
/** 资源ID */
@property (nonatomic, copy) NSString *resID;
/** 资源类型*/
@property (nonatomic, copy) NSString *type;
/** 获得服务器这次请求 返回数据的总长度 */
@property (nonatomic, assign) NSInteger totalLength;
/** 当前数据长度 */
@property (nonatomic, assign) NSInteger currentLength;
@property (nonatomic, copy) ZLProgressBlock progressBlock;
@property (nonatomic, copy) ZLStateBlock stateBlock;
@property (nonatomic, assign) ZLDownloadState taskState;
@property (nonatomic, assign) BOOL isFirstRunning;
@property (nonatomic, assign) BOOL isRunning;

- (instancetype)initWithResId:(NSString *)resID resType:(NSString *)type downloadUrl:(NSString *)url delegate:(id<NSURLSessionDelegate>)delegate operationQueue:(NSOperationQueue *)queue;
- (NSURLSessionDownloadTask *)createDownloadTask;
- (NSURLSessionDownloadTask *)createDownloadTaskWithResumeData:(NSData *)data;
@end
