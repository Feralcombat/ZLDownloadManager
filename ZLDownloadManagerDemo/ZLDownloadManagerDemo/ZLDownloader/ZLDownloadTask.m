//
//  ZLDownloadTask.m
//  ZLDownloadManager
//
//  Created by 周麟 on 2017/5/3.
//  Copyright © 2017年 周麟. All rights reserved.
//

#import "ZLDownloadTask.h"

@interface ZLDownloadTask ()
@property (nonatomic, strong ,readonly) NSOperationQueue *queue;
@end

@implementation ZLDownloadTask
- (instancetype)initWithResId:(NSString *)resID resType:(NSString *)type downloadUrl:(NSString *)url delegate:(id<NSURLSessionDelegate>)delegate operationQueue:(NSOperationQueue *)queue{
    self = [super init];
    if (self) {
        self.resID = resID;
        self.downloadUrl = url;
        self.type = type;
        self.isRunning = NO;
        self.isFirstRunning = YES;
        self.taskState = ZLDownloadStateWaited;
//        self.taskIdentifier = arc4random() % ((arc4random() % 10000 + arc4random() % 10000));
        self.delegate = delegate;
        _queue = queue;
    }
    return self;
}

- (NSURLSessionDownloadTask *)createDownloadTask{
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.resID];
    config.discretionary = NO;

    self.session = [NSURLSession sessionWithConfiguration:config delegate:self.delegate delegateQueue:_queue];
    if ([[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(self.resID, @".tmp")]) {
        //                if ([[[UIDevice currentDevice] systemVersion] floatValue]<9.0) {
        self.task = [self.session downloadTaskWithResumeData:[NSData dataWithContentsOfFile:ZLFileFullpath(self.resID, @".tmp")]];
        //                }
        //                else{
        //                    task = [session downloadTaskWithResumeData:[self getCorrectResumeData:[NSData dataWithContentsOfFile:ZLFileFullpath(resID, @".tmp")]]];
        //                }
    }
    else{
        self.task = [self.session downloadTaskWithURL:[NSURL URLWithString:self.downloadUrl]];
    }
    
//    [self.task setValue:@(self.taskIdentifier) forKeyPath:@"taskIdentifier"];
    return self.task;
}

- (NSURLSessionDownloadTask *)createDownloadTaskWithResumeData:(NSData *)data{
//    self.taskIdentifier = arc4random() % ((arc4random() % 10000 + arc4random() % 10000));
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:self.resID];
    config.discretionary = YES;
//    NSOperationQueue *queue = [[NSOperationQueue alloc] init];
//    queue.maxConcurrentOperationCount = 1;
    self.session = [NSURLSession sessionWithConfiguration:config delegate:self.delegate delegateQueue:_queue];
    self.task = [self.session downloadTaskWithResumeData:data];
//    [self.task setValue:@(self.taskIdentifier) forKeyPath:@"taskIdentifier"];
    return self.task;
}
@end
