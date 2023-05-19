//
//  SafeNSMutableArray.h
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface SafeNSMutableArray : NSMutableArray
@property (nonatomic,assign,readonly) NSUInteger count;
- (void)addObject:(id)anObject;
- (void)insertObject:(id)anObject atIndex:(NSUInteger)index;
- (void)removeLastObject;
- (void)removeObjectAtIndex:(NSUInteger)index;
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject;
- (id)objectAtIndex:(NSUInteger)index;
@end

NS_ASSUME_NONNULL_END
