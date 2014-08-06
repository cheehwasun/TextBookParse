//
//  DDFileReader.m
//  TextBookParse
//
//  Created by xxsy-ima001 on 14-8-5.
//  Copyright (c) 2014年 ___xiaoxiangwenxue___. All rights reserved.
//

//
//  DDFileReader.m
//  PBX2OPML
//
//  Created by michael isbell on 11/6/11.
//  Copyright (c) 2011 BlueSwitch. All rights reserved.
//

//DDFileReader.m

#import "DDFileReader.h"
#import "NSData+encoding.h"
@interface NSData (DDAdditions)

- (NSRange) rangeOfData_dd:(NSData *)dataToFind;

@end

@implementation NSData (DDAdditions)

- (NSRange) rangeOfData_dd:(NSData *)dataToFind {
    
    const void * bytes = [self bytes];
    NSUInteger length = [self length];
    
    const void * searchBytes = [dataToFind bytes];
    NSUInteger searchLength = [dataToFind length];
    NSUInteger searchIndex = 0;
    
    NSRange foundRange = {NSNotFound, searchLength};
    for (NSUInteger index = 0; index < length; index++) {
        if (((char *)bytes)[index] == ((char *)searchBytes)[searchIndex]) {
            //the current character matches
            if (foundRange.location == NSNotFound) {
                foundRange.location = index;
            }
            searchIndex++;
            if (searchIndex >= searchLength) { return foundRange; }
        } else {
            searchIndex = 0;
            foundRange.location = NSNotFound;
        }
    }
    return foundRange;
}

@end

@implementation DDFileReader
@synthesize lineDelimiter, chunkSize;

- (id) initWithFilePath:(NSString *)aPath {
    if (self = [super init]) {
        self.fileHandle = [NSFileHandle fileHandleForReadingAtPath:aPath];
        if (self.fileHandle == nil) {
            return nil;
        }
        
        lineDelimiter = @"\n";
        self.currentOffset = 0ULL; // ???
        chunkSize = 10;
        [self.fileHandle seekToEndOfFile];
        self.totalFileLength = [self.fileHandle offsetInFile];
        self.stringEncoding = [self getcontentEncoding];
        //we don't need to seek back, since readLine will do that.
    }
    return self;
}


-(NSStringEncoding)getcontentEncoding{
    [self.fileHandle seekToFileOffset:0];
    NSData *data = [self.fileHandle readDataOfLength:(NSInteger)(10ULL < self.totalFileLength?10ULL:(self.totalFileLength -1ULL))];
    if (data) {
        return [data getCharEncoding];
    }
    return NSUTF8StringEncoding;
}

- (void) dealloc {
    [self.fileHandle closeFile];
    self.currentOffset = 0ULL;
    
}

- (NSString *) readLine {
    if (self.currentOffset >= self.totalFileLength) { return nil; }
    
    NSData * newLineData = [lineDelimiter dataUsingEncoding:self.stringEncoding];
    [self.fileHandle seekToFileOffset:self.currentOffset];
    NSMutableData * currentData = [[NSMutableData alloc] init];
    BOOL shouldReadMore = YES;
    
    @autoreleasepool {
        
        while (shouldReadMore) {
            if (self.currentOffset >= self.totalFileLength) { break; }
            NSData * chunk = [self.fileHandle readDataOfLength:chunkSize];
            NSRange newLineRange = [chunk rangeOfData_dd:newLineData];
            if (newLineRange.location != NSNotFound) {
                
                //include the length so we can include the delimiter in the string
                chunk = [chunk subdataWithRange:NSMakeRange(0, newLineRange.location+[newLineData length])];
                shouldReadMore = NO;
            }
            [currentData appendData:chunk];
            self.currentOffset += [chunk length];
        }
    }
    
    NSString * line = [[NSString alloc] initWithData:currentData encoding:self.stringEncoding];
    return line;
}

- (NSString *) readTrimmedLine {
    return [[self readLine] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

#if NS_BLOCKS_AVAILABLE
- (void) enumerateLinesUsingBlock:(void(^)(NSString*, BOOL*))block {
    NSString * line = nil;
    BOOL stop = NO;
    while (stop == NO && (line = [self readLine])) {
        block(line, &stop);
    }
}
#endif

@end