//  KFEpubParser.m
//  KFEpubKit
//
// Copyright (c) 2013 Rico Becker | KF INTERACTIVE
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "KFEpubParser.h"
#import "HTMLDocument.h"
#import "HTMLSelector.h"
@interface KFEpubParser ()


@property (strong) NSXMLParser *parser;
@property (strong) NSString *rootPath;
@property (strong) NSMutableDictionary *items;
@property (strong) NSMutableArray *spinearray;


@end


#define kMimeTypeEpub @"application/epub+zip"
#define kMimeTypeiBooks @"application/x-ibooks+zip"


@implementation KFEpubParser


- (KFEpubKitBookType)bookTypeForBaseURL:(NSURL *)baseURL
{
    NSError *error = nil;
    KFEpubKitBookType bookType = KFEpubKitBookTypeUnknown;
    
    NSURL *mimetypeURL = [baseURL URLByAppendingPathComponent:@"mimetype"];
    NSString *mimetype = [[NSString alloc] initWithContentsOfURL:mimetypeURL encoding:NSASCIIStringEncoding error:&error];
    
    if (error)
    {
        return bookType;
    }
    
    NSRange mimeRange = [mimetype rangeOfString:kMimeTypeEpub];
    
    if (mimeRange.location == 0 && mimeRange.length == 20)
    {
        bookType = KFEpubKitBookTypeEpub2;
    }
    else if ([mimetype isEqualToString:kMimeTypeiBooks])
    {
        bookType = KFEpubKitBookTypeiBook;
    }
    
    return bookType;
}


- (KFEpubKitBookEncryption)contentEncryptionForBaseURL:(NSURL *)baseURL
{
    NSURL *containerURL = [[baseURL URLByAppendingPathComponent:@"META-INF"] URLByAppendingPathComponent:@"sinf.xml"];
    NSError *error = nil;
    NSString *content = [NSString stringWithContentsOfURL:containerURL encoding:NSUTF8StringEncoding error:&error];
    DDXMLDocument *document = [[DDXMLDocument alloc] initWithXMLString:content options:kNilOptions error:&error];
    
    if (error)
    {
        return KFEpubKitBookEnryptionNone;
    }
    NSArray *sinfNodes = [document.rootElement nodesForXPath:@"//fairplay:sinf" error:&error];
    if (sinfNodes == nil || sinfNodes.count == 0)
    {
        return KFEpubKitBookEnryptionNone;
    }
    else
    {
        return KFEpubKitBookEnryptionFairplay;
    }
}


- (NSURL *)rootFileForBaseURL:(NSURL *)baseURL
{
    NSError *error = nil;
    NSURL *containerURL = [[baseURL URLByAppendingPathComponent:@"META-INF"] URLByAppendingPathComponent:@"container.xml"];
    
    NSString *content = [NSString stringWithContentsOfURL:containerURL encoding:NSUTF8StringEncoding error:&error];
    DDXMLDocument *document = [[DDXMLDocument alloc] initWithXMLString:content options:kNilOptions error:&error];
    DDXMLElement *root  = [document rootElement];
    
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray* objectElements = [root nodesForXPath:@"//default:container/default:rootfiles/default:rootfile" error:&error];
    
    NSUInteger count = 0;
    NSString *value = nil;
    for (DDXMLElement* xmlElement in objectElements)
    {
        value = [[xmlElement attributeForName:@"full-path"] stringValue];
        count++;
    }
    
    if (count == 1 && value)
    {
        return [baseURL URLByAppendingPathComponent:value];
    }
    else if (count == 0)
    {
        NSLog(@"no root file found.");
    }
    else
    {
        NSLog(@"there are more than one root files. this is odd.");
    }
    return nil;
}


- (NSString *)coverPathComponentFromDocument:(DDXMLDocument *)document
{
    NSString *coverPath;
    DDXMLElement *root  = [document rootElement];
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray *metaNodes = [root nodesForXPath:@"//default:item[@properties='cover-image']" error:nil];
    
    if (metaNodes)
    {
        coverPath = [[metaNodes.lastObject attributeForName:@"href"] stringValue];
    }
    
    if (!coverPath)
    {
        NSString *coverItemId;
        
        DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
        defaultNamespace.name = @"default";
        metaNodes = [root nodesForXPath:@"//default:meta" error:nil];
        for (DDXMLElement *xmlElement in metaNodes)
        {
            if ([[xmlElement attributeForName:@"name"].stringValue compare:@"cover" options:NSCaseInsensitiveSearch] == NSOrderedSame)
            {
                coverItemId = [xmlElement attributeForName:@"content"].stringValue;
            }
        }
        
        if (!coverItemId)
        {
            return nil;
        }
        else
        {
            DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
            defaultNamespace.name = @"default";
            NSArray *itemNodes = [root nodesForXPath:@"//default:item" error:nil];
            
            for (DDXMLElement *itemElement in itemNodes)
            {
                if ([[itemElement attributeForName:@"id"].stringValue compare:coverItemId options:NSCaseInsensitiveSearch] == NSOrderedSame)
                {
                    coverPath = [itemElement attributeForName:@"href"].stringValue;
                }
            }
            
        }
    }
    return coverPath;
}



- (NSDictionary *)metaDataFromDocument:(DDXMLDocument *)document
{
    NSMutableDictionary *metaData = [NSMutableDictionary new];
    DDXMLElement *root  = [document rootElement];
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray *metaNodes = [root nodesForXPath:@"//default:package/default:metadata" error:nil];
    
    if (metaNodes.count == 1)
    {
        DDXMLElement *metaNode = metaNodes[0];
        NSArray *metaElements = metaNode.children;
        
        for (DDXMLElement* xmlElement in metaElements)
        {            
            if ([self isValidNode:xmlElement])
            {
                if (![metaData objectForKey:xmlElement.localName]) {
                    metaData[xmlElement.localName] = xmlElement.stringValue;
                }else{
                    NSString * attributeString = [[[xmlElement attributes] firstObject] stringValue];
                    NSString * metaDataKeyString = [NSString stringWithFormat:@"%@-%@", xmlElement.localName, attributeString];
                    metaData[metaDataKeyString] = xmlElement.stringValue;
                }
            }
        }
    }
    else
    {
        NSLog(@"meta data invalid");
        return nil;
    }
    return metaData;
}


- (NSArray *)spineFromDocument:(DDXMLDocument *)document
{
    NSMutableArray *spine = [NSMutableArray new];
    DDXMLElement *root  = [document rootElement];
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray *spineNodes = [root nodesForXPath:@"//default:package/default:spine" error:nil];
    
    if (spineNodes.count == 1)
    {
        DDXMLElement *spineElement = spineNodes[0];
        
        NSString *toc = [[spineElement attributeForName:@"toc"] stringValue];
        if (toc)
        {
            [spine addObject:toc];
        }
        else
        {
            [spine addObject:@""];
        }
        NSArray *spineElements = spineElement.children;
        for (DDXMLElement* xmlElement in spineElements)
        {
            if ([self isValidNode:xmlElement])
            {
                [spine addObject:[[xmlElement attributeForName:@"idref"] stringValue]];
            }
        }
    }
    else
    {
        NSLog(@"spine data invalid");
        return nil;
    }
    return spine;
}


- (NSDictionary *)manifestFromDocument:(DDXMLDocument *)document
{
    NSMutableDictionary *manifest = [NSMutableDictionary new];
    DDXMLElement *root  = [document rootElement];
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray *manifestNodes = [root nodesForXPath:@"//default:package/default:manifest" error:nil];
    
    if (manifestNodes.count == 1)
    {
        NSArray *itemElements = ((DDXMLElement *)manifestNodes[0]).children;
        for (DDXMLElement* xmlElement in itemElements)
        {
            if ([self isValidNode:xmlElement] && xmlElement.attributes)
            {
                NSString *href = [[xmlElement attributeForName:@"href"] stringValue];
                NSString *itemId = [[xmlElement attributeForName:@"id"] stringValue];
                NSString *mediaType = [[xmlElement attributeForName:@"media-type"] stringValue];
                
                if (itemId)
                {
                    NSMutableDictionary *items = [NSMutableDictionary new];
                    if (href)
                    {
                        items[@"href"] = href;
                    }
                    if (mediaType)
                    {
                        items[@"media"] = mediaType;
                    }
                    manifest[itemId] = items;
                }
            }
        }
    }
    else
    {
        NSLog(@"manifest data invalid");
        return nil;
    }
    return manifest;
}


- (NSArray *)guideFromDocument:(DDXMLDocument *)document
{
    NSMutableArray *guide = [NSMutableArray new];
    DDXMLElement *root  = [document rootElement];
    
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray *guideNodes = [root nodesForXPath:@"//default:package/default:guide" error:nil];
    
    if (guideNodes.count == 1)
    {
        DDXMLElement *guideElement = guideNodes[0];
        NSArray *referenceElements = guideElement.children;
        
        for (DDXMLElement* xmlElement in referenceElements)
        {
            if ([self isValidNode:xmlElement])
            {
                NSString *type = [[xmlElement attributeForName:@"type"] stringValue];
                NSString *href = [[xmlElement attributeForName:@"href"] stringValue];
                NSString *title = [[xmlElement attributeForName:@"title"] stringValue];
                
                NSMutableDictionary *reference = [NSMutableDictionary new];
                if (type)
                {
                    reference[type] = type;
                }
                if (href)
                {
                    reference[@"href"] = href;
                }
                if (title)
                {
                    reference[@"title"] = title;
                }
                [guide addObject:reference];
            }
        }
    }
    else
    {
        NSLog(@"guide data invalid");
        return nil;
    }
    
    return guide;
}


- (BOOL)isValidNode:(DDXMLElement *)node
{
    return node.kind != DDXMLCommentKind;
}

///获取目录列表，章节数量比spine获取到章节少
- (NSArray *)ncxFromDocument:(DDXMLDocument *)document{
    NSMutableArray *ncxArray = [NSMutableArray new];
    DDXMLElement *root  = [document rootElement];
    DDXMLNode *defaultNamespace = [root namespaceForPrefix:@""];
    defaultNamespace.name = @"default";
    NSArray *navPointNodes = [root nodesForXPath:@"//default:navMap/default:navPoint" error:nil];
    
    for (DDXMLElement *node in navPointNodes) {
        //index
        NSString *index = [[node  attributeForName:@"playOrder"] stringValue];
        //title
        NSArray *titleNodes = [node nodesForXPath:@"default:navLabel/default:text" error:nil];
        //content
        NSArray *contentNodes = [node nodesForXPath:@"default:content" error:nil];
        if (titleNodes.count != 1 && contentNodes.count !=1) {
            continue;
        }
        NSString *chapterTitle = [(DDXMLDocument*)[titleNodes firstObject] stringValue];
        NSString *chapterSrc = [[[contentNodes firstObject] attributeForName:@"src"] stringValue];
        if (!chapterTitle || !chapterSrc) {
            continue;
        }
        [ncxArray addObject:@{@"text":chapterTitle,@"src":chapterSrc,@"playOrder":index?:@""}];
    }
    [ncxArray sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSInteger before = [obj1[@"playOrder"] integerValue];
        NSInteger after = [obj2[@"playOrder"] integerValue];
        return before < after?NSOrderedAscending:NSOrderedDescending;
    }];
    return ncxArray;
}

///获取目录列表，章节数量比spine获取到章节少
- (NSArray *)catalogFromDocumentForCatalogFilePath:(NSString*)catalogFilePath{
    
    HTMLDocument *document = [HTMLDocument documentWithString:[[NSString alloc] initWithContentsOfFile:catalogFilePath encoding:NSUTF8StringEncoding error:nil]];
    if (!document) {
        return nil;
    }
    NSArray *links = [document nodesMatchingSelector:@"body * :link"];
    NSMutableArray *chapterArray = [NSMutableArray array];
    for (HTMLElement *element in links) {
        NSString *chapterName = [element textContent];
        NSDictionary *properties = [element attributes];
        if (!chapterName || properties.count <= 0 || !properties[@"href"]) {
            continue;
        }
        NSString *src = properties[@"href"];
        [chapterArray addObject:@{@"text":chapterName,@"src":src}];
    }
    return chapterArray;
}

///返回html解析内容，image 对应图片path，content对应纯文本
+(NSArray*)contentFromHTMLDocumentForHtmlFilePath:(NSString*)filePath{
    NSString *data = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:nil];
    if (!data) {
        return nil;
    }
    HTMLDocument *doc = [HTMLDocument documentWithString:data];
    HTMLElement *body = [doc firstNodeMatchingSelector:@"body"];
    if (!body) {
        return nil;
    }
    NSMutableArray *contents = [NSMutableArray array];
    NSArray *childenNodes = [body nodesMatchingSelector:@"*"];
    for (HTMLElement *node in childenNodes) {
        if ([[node.tagName lowercaseString] isEqualToString:@"p"]) {
            if (node.textContent) {
                [contents addObject:@{@"content":[NSString stringWithFormat:@"%@\n",node.textContent]}];
            }
        }
        if ([[node.tagName lowercaseString] isEqualToString:@"p"] && node.attributes[@"src"]) {
            if (node.attributes[@"src"]) {
                [contents addObject:@{@"url":node.attributes[@"src"]}];
            }
        }
    }
    return contents;
}
@end
