//
//  ZLDownloadManger.h
//  ZLDownloadManager
//
//  Created by 周麟 on 2017/4/13.
//  Copyright © 2017年 周麟. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "AppDelegate.h"


// 缓存主目录
#define ZLCachesDirectory [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:@"CacheResource"]

// 保存文件名
#define ZLFileName(resID) resID

// 文件的存放路径（caches）
#define ZLFileFullpath(resID,type) [ZLCachesDirectory stringByAppendingPathComponent:[ZLFileName(resID) stringByAppendingString:type]]

// 文件的已下载长度
#define ZLDownloadLength(resID,type) [[[NSFileManager defaultManager] attributesOfItemAtPath:ZLFileFullpath(resID,type) error:nil][NSFileSize] integerValue]

// 存储文件总长度的文件路径（caches）
#define ZLTotalLengthFullpath [ZLCachesDirectory stringByAppendingPathComponent:@"totalLength.plist"]

@class ZLDownloadTask;
typedef NS_ENUM(NSInteger,DownloadType){
    DownloadTypeSingleTask,
    DownloadTypeMultiTask,
};

typedef NS_ENUM(NSInteger,ZLDownloadState) {
    ZLDownloadStateStart,         /** 下载中 */
    ZLDownloadStateSuspended,     /** 下载暂停 */
    ZLDownloadStateCompleted,     /** 下载完成 */
    ZLDownloadStateFailed,        /** 下载失败 */
    ZLDownloadStateWaited,        /** 等待下载 */
    ZLDownloadStateCanceled       /** 取消下载 */
};

typedef void(^ZLProgressBlock)(int64_t receivedSize, int64_t expectedSize, CGFloat progress);
typedef void(^ZLStateBlock)(ZLDownloadState state);
typedef void(^ZLErrorBlock) (NSString *error);

@interface ZLDownloadManger : NSObject

+ (instancetype)sharedInstance;

/**
 *  开启任务下载资源
 *
 *  @param url           下载地址
 *  @param resID       资源ID
 *  @param type        资源类型
 *  @param progressBlock 回调下载进度
 *  @param stateBlock    下载状态
 *  @param errorBlock 错误信息
 */
- (void)startDownLoadWithUrl:(NSString *)url resID:(NSString *)resID type:(NSString *)type progress:(ZLProgressBlock)progressBlock state:(ZLStateBlock)stateBlock error:(ZLErrorBlock)errorBlock;

/**
 * 取消所有下载任务
 */
- (void)cancelAllTasks;


/**
 * 获取当前任务
 *
 */
- (ZLDownloadTask *)getCurrentTask;

/**
 *  挂起任务
 *  @param resID       资源ID
 */

- (BOOL)suspendTaskWithResID:(NSString *)resID;

/**
 *  暂停任务
 *
 *  @param resID       资源ID
 */
- (BOOL)stopTaskWithResID:(NSString *)resID;

/**
 *  批量暂停任务
 *
 *  @param resIDArray       资源ID数组
 */
- (BOOL)batchStopTaskWithResIDArray:(NSArray *)resIDArray;

/**
 *  继续任务
 *
 *  @param resID       资源ID
 */
- (BOOL)continueTaskWithResID:(NSString *)resID;

/**
 *  删除资源,同时删除任务和临时文件
 *
 *  @param resID       资源ID
 *  @param type        资源类型
 */
- (BOOL)deleteResourceWithResID:(NSString *)resID resType:(NSString *)type;

/**
 *  批量删除资源,同时删除任务和临时文件
 *
 *  @param resArray       资源数组(内含@{@"resID":resID,@"type":type})
 */
- (BOOL)batchDeleteResourceWithResArray:(NSArray *)resArray;
@end
