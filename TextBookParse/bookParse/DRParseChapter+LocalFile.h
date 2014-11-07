//
//  DRParseChapter+LocalFile.h
//  TextBookParse
//
//  Created by xxsy-ima001 on 14-9-23.
//  Copyright (c) 2014年 ___xiaoxiangwenxue___. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DRParseChapter.h"
@interface DRParseChapter (LocalFile)
+(void)writeDRParseChaptersArray:(NSArray*)parseChapterArr ToPlistFileWithPlistFilePath:(NSString*)plistFilePath;

+(void)writeDRParseChaptersArray:(NSArray*)parseChapterArr withCoverFilePath:(NSString*)coverPath withBookName:(NSString*)bookName withAuthor:(NSString*)author ToPlistFileWithPlistFilePath:(NSString*)plistFilePath;

+(NSArray*)parseChapterArrayFromPlistFilePath:(NSString*)plistFilePath;

+(NSDictionary*)parseChapterDicFromPlistFilePath:(NSString*)plistFilePath;
@end
