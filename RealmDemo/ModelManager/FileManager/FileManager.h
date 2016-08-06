//
//  FileManager.h
//  RealmDemo
//
//  Created by Mac on 16/8/5.
//  Copyright © 2016年 com.luohaifang. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "HttpService.h"
//文件管理器 文件名用时间戳 防止重名 文件按照不同用户放在不同的文件夹下面
@interface FileManager : NSObject

+ (instancetype)shareManager;
//下载文件
- (NSURLSessionDownloadTask*)downFile:(NSString*)fileUrl handler:(completionHandler)handler;

//文件是否存在
- (BOOL)fileIsExit:(NSString*)fileName;
//文件名对应的本地路径
- (NSURL*)fileUrl:(NSString*)fileName;

@end