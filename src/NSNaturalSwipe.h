#import <UIKit/UIKit.h>
@interface NSUNaturalSwipeEngine : NSObject
@property(nonatomic,readonly) BOOL active;
// Optional [time, horizontal deviation, vertical progress] points, all normalized.
@property(nonatomic,copy) NSArray<NSArray<NSNumber *> *> *motionProfile;
- (BOOL)beginInWindow:(UIWindow *)window from:(CGPoint)from to:(CGPoint)to duration:(double)duration completion:(void(^)(NSDictionary *result))completion;
- (void)cancel;
@end
void NSUInstall(void);
