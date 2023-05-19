//
//  SafeNSMutableArray.m
//  TUIRoomKit
//
//  Created by WesleyLei on 2023/5/19.
//

#import "LocalRecordHeader.h"
#import "SafeNSMutableArray.h"

@interface SafeNSMutableArray()
@property(nonatomic,strong) dispatch_queue_t queue;
@property(nonatomic,strong) NSMutableArray *datMuArray;
@property (strong, nonatomic, nonnull) dispatch_semaphore_t operationsLock;
@end

@implementation SafeNSMutableArray
- (instancetype)init{
    if (self = [super init]) {
        self.operationsLock = dispatch_semaphore_create(1);
        self.queue = dispatch_queue_create("SafeNSMutableArray", DISPATCH_QUEUE_CONCURRENT);
        self.datMuArray = [NSMutableArray arrayWithCapacity:50];
    }
    return self;
}

- (void)addObject:(id)anObject{
    if(anObject){
        YGLOCK(self.operationsLock)
        [self.datMuArray addObject:anObject];
        YGUNLOCK(self.operationsLock)
    }
}
- (void)insertObject:(id)anObject atIndex:(NSUInteger)index{
    YGLOCK(self.operationsLock)
    if(anObject && index < self.datMuArray.count){
        [self.datMuArray insertObject:anObject atIndex:index];
    }
    YGUNLOCK(self.operationsLock)
    
}
- (void)removeLastObject{
    YGLOCK(self.operationsLock)
    [self.datMuArray removeLastObject];
    YGUNLOCK(self.operationsLock)
}
- (void)removeObjectAtIndex:(NSUInteger)index{
    YGLOCK(self.operationsLock)
    if(index < self.datMuArray.count){
        [self.datMuArray removeObjectAtIndex:index];
    }
    YGUNLOCK(self.operationsLock)
}
- (void)replaceObjectAtIndex:(NSUInteger)index withObject:(id)anObject{
    YGLOCK(self.operationsLock)
    if(anObject && index < self.datMuArray.count){
        [self.datMuArray replaceObjectAtIndex:index withObject:anObject];
    }
    YGUNLOCK(self.operationsLock)
}

- (id)objectAtIndex:(NSUInteger)index{
    __block id temp;
    YGLOCK(self.operationsLock)
    if(index < self.datMuArray.count){
        temp = [self.datMuArray objectAtIndex:index];
    }
    YGUNLOCK(self.operationsLock)
    return temp;
}

-(NSUInteger)count{
    __block NSUInteger temp;
    YGLOCK(self.operationsLock)
    temp = self.datMuArray.count;
    YGUNLOCK(self.operationsLock)
    return temp;
}
@end
