//
//  ZLDownloadManger.m
//  ZLDownloadManager
//
//  Created by 周麟 on 2017/4/13.
//  Copyright © 2017年 周麟. All rights reserved.
//


#import "ZLDownloadManger.h"
#import "ZLDownloadTask.h"

@interface ZLDownloadManger()<NSURLSessionDownloadDelegate>
@property (nonatomic, strong) NSMutableDictionary *taskDic;//存放当前未完成的任务
@property (nonatomic, strong) NSMutableDictionary *taskTotalDic;//记录所有下载任务
@property (nonatomic, strong) NSMutableDictionary *sessionInfo;
@property (nonatomic, strong) NSMutableDictionary *tempFilePathDic;//记录任务中临时文件的地址对应关系
@property (nonatomic, strong) NSMutableDictionary *tempDonwloadTaskDic;//记录临时下载信息
@property (nonatomic, strong) NSMutableDictionary *resumeDataDic;//用户杀死进程临时需要保存resumeData
@property (nonatomic, strong) NSMutableArray *currentTaskQueue;//当前下载队列
@property (nonatomic, copy) NSString *unDownloadSystemPath;//未完成下载系统临时文件目录
@property (nonatomic, strong) NSOperationQueue *queue;
@end

@implementation ZLDownloadManger
+ (instancetype)sharedInstance{
    static ZLDownloadManger *manager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        manager = [[ZLDownloadManger alloc] init];
    });
    return manager;
}

- (instancetype)init{
    self = [super init];
    if (self) {
        self.taskDic = [NSMutableDictionary dictionary];
        self.sessionInfo = [NSMutableDictionary dictionary];
        self.tempFilePathDic = [NSMutableDictionary dictionary];
        self.tempDonwloadTaskDic = [NSMutableDictionary dictionary];
        self.resumeDataDic = [NSMutableDictionary dictionary];
        self.currentTaskQueue = [NSMutableArray array];
        if ([[NSUserDefaults standardUserDefaults] objectForKey:@"taskTotalDic"]) {
            self.taskTotalDic = [[[NSUserDefaults standardUserDefaults] objectForKey:@"taskTotalDic"] mutableCopy];
        }
        else{
            self.taskTotalDic = [NSMutableDictionary dictionary];
        }
        self.queue = [[NSOperationQueue alloc] init];
        self.queue.maxConcurrentOperationCount = 1;
    }
    return self;
}

/**
 *  创建缓存目录文件
 */
- (void)createCacheDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    if (![fileManager fileExistsAtPath:ZLCachesDirectory]) {
        [fileManager createDirectoryAtPath:ZLCachesDirectory withIntermediateDirectories:YES attributes:nil error:nil];
    }
    else{
        NSLog(@"%@",[fileManager contentsOfDirectoryAtPath:ZLCachesDirectory error:nil]);
    }
}

/**
 *  开始下载任务
 */
- (void)startDownLoadWithUrl:(NSString *)url resID:(NSString *)resID type:(NSString *)type progress:(ZLProgressBlock)progressBlock state:(ZLStateBlock)stateBlock error:(ZLErrorBlock)errorBlock;
{
    [self createCacheDirectory];
    
    if (![self checkUrlIsValidate:url]) {
        errorBlock(@"非法的URL");
        return;
    }
    if ([[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(resID, type)]) {
        stateBlock(ZLDownloadStateCompleted);
        return;
    }
    if ([self judegeIfTaskIsExistWithResID:resID]) {
        errorBlock(@"该资源已经在缓存列表中了");
        return;
    }
    ZLDownloadTask *downloadTask = [[ZLDownloadTask alloc] initWithResId:resID resType:type downloadUrl:url delegate:self operationQueue:self.queue];
    downloadTask.progressBlock = progressBlock;
    downloadTask.stateBlock = stateBlock;
    [self.tempDonwloadTaskDic setObject:downloadTask forKey:@"temp"];
//    [self.sessionInfo setValue:downloadTask forKey:@(downloadTask.taskIdentifier).stringValue];
    [self.sessionInfo setValue:downloadTask forKey:downloadTask.resID];
    stateBlock(ZLDownloadStateWaited);
    [self addDownloadTask:downloadTask];
}


- (BOOL)judegeIfTaskIsExistWithResID:(NSString *)resID{
    BOOL isExist = NO;
    for (ZLDownloadTask *task in self.sessionInfo.allValues) {
        if ([task.resID isEqualToString:resID]) {
            isExist = YES;
            break;
        }
    }
    return isExist;
}

/**
 *  在下载队列中添加任务
 */
- (void)addDownloadTask:(ZLDownloadTask *)task{
    [self.currentTaskQueue addObject:task];
    [self runDownloadTask];
}

- (void)addDownloadTask:(ZLDownloadTask *)task  ResumeData:(NSData *)resumeData{
    NSURLSessionDownloadTask *newDownload = [task createDownloadTaskWithResumeData:resumeData];
    [newDownload resume];
    task.isRunning = YES;
    [self.taskTotalDic setObject:@(0) forKey:task.resID];
    [self.taskDic setObject:newDownload forKey:task.resID];
//    [self.sessionInfo setValue:task forKey:@(task.taskIdentifier).stringValue];
    [self.sessionInfo setValue:task forKey:task.resID];
}

- (void)runDownloadTask{
    BOOL hasTask = NO;
    for (ZLDownloadTask *downloadTask in self.currentTaskQueue) {
        if (downloadTask.isRunning == YES) {
            hasTask = YES;
            break;
        }
    }
    if (!hasTask) {
        for (ZLDownloadTask *downloadTask in self.currentTaskQueue) {
            if (downloadTask.isRunning == NO) {
                NSURLSessionDownloadTask *task = [downloadTask createDownloadTask];
                [self.taskTotalDic setObject:@(0) forKey:downloadTask.resID];
                [self.taskDic setObject:task forKey:downloadTask.resID];
                [task resume];
                downloadTask.isRunning = YES;
                break;
            }
        }
    }
}

- (void)cancelAllTasks{
    for (ZLDownloadTask *task in self.sessionInfo.allValues) {
        [self stopTaskWithResID:task.resID];
    }
}

- (ZLDownloadTask *)getCurrentTask{
    for (ZLDownloadTask *task in self.sessionInfo.allValues) {
        if (task.isRunning == YES) {
            return task;
        }
    }
    return nil;
}

/**
 *  挂起下载任务
 */
- (BOOL)suspendTaskWithResID:(NSString *)resID{
    BOOL isSucceess = NO;
    if ([self.taskDic objectForKey:resID]) {
        NSURLSessionDownloadTask *task = [self.taskDic objectForKey:resID];
        if (task.state == NSURLSessionTaskStateRunning) {
            [task suspend];
            isSucceess = YES;
        }
    }
    return isSucceess;
}

/**
 *  暂停下载任务
 */
- (BOOL)stopTaskWithResID:(NSString *)resID{
    __block BOOL isSuccess = NO;
    if ([self.taskDic objectForKey:resID]) {
        NSURLSessionDownloadTask *task = [self.taskDic objectForKey:resID];
        if (task.state == NSURLSessionTaskStateRunning || task.state == NSURLSessionTaskStateSuspended) {
            isSuccess = YES;
            [task cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
                
            }];
        }
    }
    else{
        __weak typeof(self)weakSelf = self;
        [self.sessionInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            ZLDownloadTask *downloadTask = obj;
            if ([downloadTask.resID isEqualToString:resID]) {
                downloadTask.stateBlock(ZLDownloadStateSuspended);
                [weakSelf.sessionInfo removeObjectForKey:key];
                [weakSelf.currentTaskQueue removeObject:downloadTask];
                isSuccess = YES;
               *stop = YES;
            }
        }];
    }
    return isSuccess;
}

/**
 *  强制暂停下载任务
 */
- (BOOL)forceStopTaskWithResID:(NSString *)resID{
    __weak typeof(self)weakSelf = self;
    __block BOOL isSuccess = NO;
    if ([self.taskDic objectForKey:resID]) {
        NSURLSessionDownloadTask *task = [self.taskDic objectForKey:resID];
        if (task.state == NSURLSessionTaskStateRunning || task.state == NSURLSessionTaskStateSuspended) {
            isSuccess = YES;
            [task cancel];
            [self runDownloadTask];
        }
    }
    else{
        [self.sessionInfo enumerateKeysAndObjectsUsingBlock:^(id  _Nonnull key, id  _Nonnull obj, BOOL * _Nonnull stop) {
            ZLDownloadTask *downloadTask = obj;
            if ([downloadTask.resID isEqualToString:resID]) {
                downloadTask.stateBlock(ZLDownloadStateCanceled);
                [weakSelf.sessionInfo removeObjectForKey:key];
                [weakSelf.currentTaskQueue removeObject:downloadTask];
                isSuccess = YES;
                *stop = YES;
            }
        }];
        
    }
    return isSuccess;
}
/**
 *  批量暂停下载任务
 */
- (BOOL)batchStopTaskWithResIDArray:(NSArray *)resIDArray{
    for (NSString *resID in resIDArray) {
        [self stopTaskWithResID:resID];
    }
    return YES;
}

/**
 *  继续下载任务
 */
- (BOOL)continueTaskWithResID:(NSString *)resID{
    BOOL isSuccess = NO;
    if ([self.taskDic objectForKey:resID]) {
        NSURLSessionDownloadTask *task = [self.taskDic objectForKey:resID];
        if (task.state == NSURLSessionTaskStateSuspended) {
            isSuccess = YES;
            [task resume];
        }
    }
    return isSuccess;
}

/**
 *  删除下载任务
 */
- (BOOL)deleteResourceWithResID:(NSString *)resID resType:(NSString *)type{
    BOOL isSuccess = NO;
    [self forceStopTaskWithResID:resID];
    if ([self.taskTotalDic objectForKey:resID]) {
        [self.taskTotalDic removeObjectForKey:resID];
        if ([[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(resID, @".tmp")]) {
            [[NSFileManager defaultManager] removeItemAtPath:ZLFileFullpath(resID, @".tmp") error:nil];
        }
        if ([[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(resID, type)]) {
            [[NSFileManager defaultManager] removeItemAtPath:ZLFileFullpath(resID, type) error:nil];
        }
        isSuccess = YES;
    }
    else{
        isSuccess = YES;
    }
    return isSuccess;
}

/**
 *  批量删除下载任务
 */
- (BOOL)batchDeleteResourceWithResArray:(NSArray *)resArray{
    for (NSDictionary *resDic in resArray) {
        [self deleteResourceWithResID:resDic[@"resID"] resType:resDic[@"type"]];
    }
    return YES;
}

/**
 *  验证URL是否合法
 */
- (BOOL)checkUrlIsValidate:(NSString *)url{
    if ([url hasPrefix:@"http:"] || [url hasPrefix:@"https:"]) {
        return YES;
    }
    else{
        return NO;
    }
}

#pragma mark - NSURLSessionTaskDelegate
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(NSError *)error{
    if (!error) {
        if (self.resumeDataDic.allValues.count > 0) {
            NSString *resID = self.resumeDataDic.allKeys[0];
            NSData *resumeData = self.resumeDataDic.allValues[0];
            ZLDownloadTask *sessionTask = [self.tempDonwloadTaskDic objectForKey:resID];
            [self addDownloadTask:sessionTask ResumeData:resumeData];
            [self.resumeDataDic removeAllObjects];
            [self.tempDonwloadTaskDic removeObjectForKey:resID];
        }
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(nullable NSError *)error{
    if (error) {
        if ([error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData]) {
//            ZLDownloadTask *downloadTask = [self.sessionInfo objectForKey:[NSString stringWithFormat:@"%lu",task.taskIdentifier]];
            ZLDownloadTask *downloadTask = [self.sessionInfo objectForKey:session.configuration.identifier];
            downloadTask.isRunning = NO;
            NSData *resumeData = [error.userInfo objectForKey:NSURLSessionDownloadTaskResumeData];
            NSData *correctResumeData;
            if ([[[UIDevice currentDevice] systemVersion] floatValue]<9.0) {
                correctResumeData = resumeData;
            }
            else{
                correctResumeData = [self getCorrectResumeData:resumeData];
            }
            if (![[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(downloadTask.resID, @".tmp")]) {
                downloadTask.isFirstRunning = NO;
                downloadTask.taskIdentifier = task.taskIdentifier;
                [self parseResumeData:resumeData WithResID:downloadTask.resID];
                [correctResumeData writeToFile:ZLFileFullpath(downloadTask.resID, @".tmp") atomically:NO];
                NSInteger identifier = task.taskIdentifier;
                task = [session downloadTaskWithResumeData:[NSData dataWithContentsOfFile:ZLFileFullpath(downloadTask.resID, @".tmp")]];
                [task setValue:@(identifier) forKeyPath:@"taskIdentifier"];
                downloadTask.isRunning = YES;
                [task resume];
                [self.taskDic setObject:task forKey:downloadTask.resID];
            }
            else{
                //用户手动暂停
                if ([self.taskDic objectForKey:downloadTask.resID]) {
                    [correctResumeData writeToFile:ZLFileFullpath(downloadTask.resID, @".tmp") atomically:NO];
                    downloadTask.stateBlock(ZLDownloadStateSuspended);
                    [self.taskDic removeObjectForKey:downloadTask.resID];
//                    [self.sessionInfo removeObjectForKey:[NSString stringWithFormat:@"%lu",task.taskIdentifier]];
                    [self.sessionInfo removeObjectForKey:session.configuration.identifier];
//                    for (NSURLSessionDownloadTask *currentTask in self.currentTaskQueue) {
//                        if (currentTask.taskIdentifier == task.taskIdentifier) {
//                            [self.currentTaskQueue removeObject:currentTask];
//                            break;
//                        }
//                    }
                    [self.currentTaskQueue removeObject:downloadTask];
                    [self runDownloadTask];
                    [session finishTasksAndInvalidate];
                }
                else{
                    //由于用户结束进程而重新开始的
                    NSInteger identifier = task.taskIdentifier;
                    NSData *correctResumeData;
                    if ([[[UIDevice currentDevice] systemVersion] floatValue]<9.0) {
                        correctResumeData = resumeData;
                    }
                    else{
                        correctResumeData = [self getCorrectResumeData:resumeData];
                    }
                    [session invalidateAndCancel];
//                    task = [session downloadTaskWithResumeData:correctResumeData];
//                    [task setValue:@(identifier) forKeyPath:@"taskIdentifier"];
                    ZLDownloadTask *sessionTask = [self.tempDonwloadTaskDic objectForKey:@"temp"];
                    [self.tempDonwloadTaskDic setObject:sessionTask forKey:sessionTask.resID];
                    [self.resumeDataDic setObject:correctResumeData forKey:sessionTask.resID];
                    
                }
               
            }
        }
        else{
//            ZLDownloadTask *donwloadTask = [self.sessionInfo objectForKey:[NSString stringWithFormat:@"%lu",task.taskIdentifier]];
            ZLDownloadTask *donwloadTask = [self.sessionInfo objectForKey:session.configuration.identifier];
            donwloadTask.isRunning = NO;
            if ([self.taskDic objectForKey:donwloadTask.resID]) {
                donwloadTask.stateBlock(ZLDownloadStateCanceled);
                [self.taskDic removeObjectForKey:donwloadTask.resID];
//                [self.sessionInfo removeObjectForKey:[NSString stringWithFormat:@"%lu",task.taskIdentifier]];
                [self.sessionInfo removeObjectForKey:session.configuration.identifier];
//                for (NSURLSessionDownloadTask *currentTask in self.currentTaskQueue) {
//                    if (currentTask.taskIdentifier == task.taskIdentifier) {
//                        [self.currentTaskQueue removeObject:currentTask];
//                        break;
//                    }
//                }
                [self.currentTaskQueue removeObject:donwloadTask];
                [session finishTasksAndInvalidate];
            }

        }
    }
    [[NSUserDefaults standardUserDefaults] setObject:self.taskTotalDic forKey:@"taskTotalDic"];
}

#pragma mark - NSURLSessionDownloadDelegate
- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
didFinishDownloadingToURL:(NSURL *)location{
//    NSLog(@"current thread:%@",[NSThread currentThread]);
//    ZLDownloadTask *sessionTask = [self.sessionInfo objectForKey:[NSString stringWithFormat:@"%lu",downloadTask.taskIdentifier]];
    ZLDownloadTask *sessionTask = [self.sessionInfo objectForKey:session.configuration.identifier];
    sessionTask.isRunning = NO;
    NSURL *fileUrl = [NSURL fileURLWithPath:ZLFileFullpath(sessionTask.resID, sessionTask.type) isDirectory:NO];
    [[NSFileManager defaultManager] moveItemAtURL:location toURL:fileUrl error:nil];
    [self.taskDic removeObjectForKey:sessionTask.resID];
//    [self.sessionInfo removeObjectForKey:[NSString stringWithFormat:@"%lu",downloadTask.taskIdentifier]];
    [self.sessionInfo removeObjectForKey:session.configuration.identifier];
    //    for (NSURLSessionDownloadTask *currentTask in self.currentTaskQueue) {
    //        if (currentTask.taskIdentifier == downloadTask.taskIdentifier) {
    //            [self.currentTaskQueue removeObject:currentTask];
    //            break;
    //        }
    //    }
    [self.currentTaskQueue removeObject:sessionTask];
    [self.taskTotalDic setObject:@(1) forKey:sessionTask.resID];
    [[NSFileManager defaultManager] removeItemAtPath:ZLFileFullpath(sessionTask.resID, @".tmp") error:nil];
    sessionTask.stateBlock(ZLDownloadStateCompleted);
    [self runDownloadTask];
    [[NSUserDefaults standardUserDefaults] setObject:self.taskTotalDic forKey:@"taskTotalDic"];
    
}

- (void)URLSession:(NSURLSession *)session downloadTask:(NSURLSessionDownloadTask *)downloadTask
      didWriteData:(int64_t)bytesWritten
 totalBytesWritten:(int64_t)totalBytesWritten
totalBytesExpectedToWrite:(int64_t)totalBytesExpectedToWrite{
//    ZLDownloadTask *sessionTask = [self.sessionInfo objectForKey:[NSString stringWithFormat:@"%lu",downloadTask.taskIdentifier]];
    ZLDownloadTask *sessionTask = [self.sessionInfo objectForKey:session.configuration.identifier];
    if (sessionTask == nil) {
        sessionTask = [self.tempDonwloadTaskDic objectForKey:@"temp"];
    }
    sessionTask.isRunning = YES;
    sessionTask.totalLength = totalBytesExpectedToWrite;
    if (![[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(sessionTask.resID, @".tmp")] && sessionTask.isFirstRunning == YES) {
        sessionTask.stateBlock(ZLDownloadStateStart);
        [downloadTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
            
        }];
    }
    else if (sessionTask.isFirstRunning){
        sessionTask.stateBlock(ZLDownloadStateStart);
        sessionTask.isFirstRunning = NO;
    }
    CGFloat addSize = (totalBytesWritten - sessionTask.currentLength) / 1024.0 / 1024.0;
    if (addSize >= 1.0) {
        //每下载1M记录下已下载数据
//        NSError *error = nil;
//        if ([[NSFileManager defaultManager] fileExistsAtPath:ZLFileFullpath(model.resID, @".tmp")]) {
//            //存在则删除
//            [[NSFileManager defaultManager] removeItemAtPath:ZLFileFullpath(model.resID, @".tmp") error:nil];
//        }
//        NSString *resumeDataTempName = [self.tempFilePathDic objectForKey:model.resID];
//        if (resumeDataTempName) {
//            [[NSFileManager defaultManager] copyItemAtPath:[self.unDownloadSystemPath stringByAppendingPathComponent:resumeDataTempName] toPath:ZLFileFullpath(model.resID, @".tmp") error:&error];
//        }
        sessionTask.currentLength = totalBytesWritten;
    }
    sessionTask.progressBlock(totalBytesWritten,totalBytesExpectedToWrite,totalBytesWritten/(totalBytesExpectedToWrite/1.0));
    [[NSUserDefaults standardUserDefaults] setObject:self.taskTotalDic forKey:@"taskTotalDic"];
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session{
    if (session.configuration.identifier) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"backgroundDownloadCompleteNotification" object:self userInfo:@{@"identifier":session.configuration.identifier}];
//        AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
//        app.completion();
    }
}

#pragma mark - 分析继续下载数据
- (void)parseResumeData:(NSData *)resumeData WithResID:(NSString *)resID{
    NSString *XMLStr = [[NSString alloc] initWithData:resumeData encoding:NSUTF8StringEncoding];
    NSString *tempFileName;
    //判断系统，iOS8以前和以后
    if ([[[UIDevice currentDevice] systemVersion] floatValue] < 9.0) {
        //iOS8包含iOS8以前
        NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoLocalPath"];
        NSString *tmpStr = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
        NSRange oneStringRange = [tmpStr rangeOfString:@"CFNetworkDownload_"];
        NSRange twoStringRange = [tmpStr rangeOfString:@".tmp"];
        tempFileName = [tmpStr substringWithRange:NSMakeRange(oneStringRange.location, twoStringRange.location + twoStringRange.length - oneStringRange.location)];
        
    } else {
        //iOS8以后
        NSRange tmpRange = [XMLStr rangeOfString:@"NSURLSessionResumeInfoTempFileName"];
        NSString *tmpStr = [XMLStr substringFromIndex:tmpRange.location + tmpRange.length];
        NSRange oneStringRange = [tmpStr rangeOfString:@"<string>"];
        NSRange twoStringRange = [tmpStr rangeOfString:@"</string>"];
        //记录tmp文件名
        tempFileName = [tmpStr substringWithRange:NSMakeRange(oneStringRange.location + oneStringRange.length, twoStringRange.location - oneStringRange.location - oneStringRange.length)];
    }
    [self.tempFilePathDic setObject:tempFileName forKey:resID];
    
}

#pragma mark - 获取正确的resumeData
- (NSData *)getCorrectResumeData:(NSData *)resumeData {
    NSData *newData = nil;
    NSString *kResumeCurrentRequest = @"NSURLSessionResumeCurrentRequest";
    NSString *kResumeOriginalRequest = @"NSURLSessionResumeOriginalRequest";
    //获取继续数据的字典
    NSMutableDictionary* resumeDictionary = [NSPropertyListSerialization propertyListWithData:resumeData options:NSPropertyListMutableContainers format:NULL error:nil];
    //重新编码原始请求和当前请求
    resumeDictionary[kResumeCurrentRequest] = [self correctRequestData:resumeDictionary[kResumeCurrentRequest]];
    resumeDictionary[kResumeOriginalRequest] = [self correctRequestData:resumeDictionary[kResumeOriginalRequest]];
    newData = [NSPropertyListSerialization dataWithPropertyList:resumeDictionary format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListMutableContainers error:nil];
    
    return newData;
}

#pragma mark - 编码继续请求字典中的当前请求数据和原始请求数据
- (NSData *)correctRequestData:(NSData *)data {
    NSData *resultData = nil;
    NSData *arData = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    if (arData != nil) {
        return data;
    }
    
    NSMutableDictionary *archiveDict = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListMutableContainersAndLeaves format:nil error:nil];
    
    int k = 0;
    NSMutableDictionary *oneDict = [NSMutableDictionary dictionaryWithDictionary:archiveDict[@"$objects"][1]];
    while (oneDict[[NSString stringWithFormat:@"$%d", k]] != nil) {
        k += 1;
    }
    
    int i = 0;
    while (oneDict[[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]] != nil) {
        NSString *obj = oneDict[[NSString stringWithFormat:@"__nsurlrequest_proto_prop_obj_%d", i]];
        if (obj != nil) {
            [oneDict setObject:obj forKey:[NSString stringWithFormat:@"$%d", i + k]];
            [oneDict removeObjectForKey:obj];
            archiveDict[@"$objects"][1] = oneDict;
        }
        i += 1;
    }
    
    if (oneDict[@"__nsurlrequest_proto_props"] != nil) {
        NSString *obj = oneDict[@"__nsurlrequest_proto_props"];
        [oneDict setObject:obj forKey:[NSString stringWithFormat:@"$%d", i + k]];
        [oneDict removeObjectForKey:@"__nsurlrequest_proto_props"];
        archiveDict[@"$objects"][1] = oneDict;
    }
    
    NSMutableDictionary *twoDict = [NSMutableDictionary dictionaryWithDictionary:archiveDict[@"$top"]];
    if (twoDict[@"NSKeyedArchiveRootObjectKey"] != nil) {
        [twoDict setObject:twoDict[@"NSKeyedArchiveRootObjectKey"] forKey:[NSString stringWithFormat:@"%@", NSKeyedArchiveRootObjectKey]];
        [twoDict removeObjectForKey:@"NSKeyedArchiveRootObjectKey"];
        archiveDict[@"$top"] = twoDict;
    }
    
    resultData = [NSPropertyListSerialization dataWithPropertyList:archiveDict format:NSPropertyListBinaryFormat_v1_0 options:NSPropertyListMutableContainers error:nil];
    
    return resultData;
}

- (NSString *)unDownloadSystemPath {
    if (_unDownloadSystemPath == nil) {
        _unDownloadSystemPath = [[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:@"com.apple.nsurlsessiond/Downloads"] stringByAppendingPathComponent:[[NSBundle mainBundle] bundleIdentifier]];
    }
    return _unDownloadSystemPath;
}
@end
