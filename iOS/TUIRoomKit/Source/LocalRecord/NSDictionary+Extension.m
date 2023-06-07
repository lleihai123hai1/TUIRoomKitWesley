//
//  NSDictionary+Extension.m
//  ToolkitBase
//
//  Created by gg on 2022/5/9.
//  Copyright © 2022 Tencent. All rights reserved.
//

#import "NSDictionary+Extension.h"

@implementation NSDictionary (Extension)

- (NSString *)jsonStr {
    NSError *err = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self options:0 error:&err];
    if (err) {
        NSAssert(NO, err.description);
        NSLog(@"【ToolkitBase】Dic to json str error:%@", err);
        return @"";
    }
    return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
}

@end
