// Touch construction follows the KIF approach (Apache-2.0); see THIRD_PARTY.md.
#import "NSNaturalSwipe.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <mach/mach_time.h>
#import <math.h>
typedef CFTypeRef NSHID;
@interface UITouch (NSPrivate)
- (void)setWindow:(UIWindow *)w;
- (void)setView:(UIView *)v;
- (void)setGestureView:(UIView *)v;
- (void)setTapCount:(NSUInteger)n;
- (void)setTimestamp:(NSTimeInterval)t;
- (void)setPhase:(UITouchPhase)p;
- (void)_setLocationInWindow:(CGPoint)p resetPrevious:(BOOL)reset;
- (void)_setIsFirstTouchForView:(BOOL)b;
- (void)_setIsTapToClick:(BOOL)b;
- (void)_setHidEvent:(NSHID)e;
@end
@interface UIEvent (NSPrivate)
- (void)_clearTouches;
- (void)_addTouch:(UITouch *)t forDelayedDelivery:(BOOL)d;
- (void)_setHIDEvent:(NSHID)e;
- (void)_setTimestamp:(double)t;
@end
@interface UIApplication (NSPrivate)
- (UIEvent *)_touchesEvent;
@end
static NSHID (*NSUHand)(CFAllocatorRef,AbsoluteTime,uint32_t,uint32_t,uint32_t,uint32_t,uint32_t,double,double,double,double,double,Boolean,Boolean,uint32_t);
static NSHID (*NSUFinger)(CFAllocatorRef,AbsoluteTime,uint32_t,uint32_t,uint32_t,double,double,double,double,double,double,double,double,double,double,Boolean,Boolean,uint32_t);
static void (*NSUAppend)(NSHID,NSHID);
static void (*NSUSetInt)(NSHID,uint32_t,int);
BOOL NSUSendingSynthetic = NO;
static BOOL NSUConstructorHID(void) {
    static BOOL tried = NO;
    if (!tried) {
        tried = YES;
        void *h = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_NOW);
        if (!h) h = RTLD_DEFAULT;
        NSUHand = dlsym(h,"IOHIDEventCreateDigitizerEvent");
        NSUFinger = dlsym(h,"IOHIDEventCreateDigitizerFingerEventWithQuality");
        NSUAppend = dlsym(h,"IOHIDEventAppendEvent");
        NSUSetInt = dlsym(h,"IOHIDEventSetIntegerValue");
    }
    return NSUHand && NSUFinger && NSUAppend && NSUSetInt;
}
static NSHID NSUCreateHID(CGPoint p, UITouchPhase phase) {
    BOOL down = phase != UITouchPhaseEnded && phase != UITouchPhaseCancelled;
    uint32_t mask = phase == UITouchPhaseMoved ? 4 : 3;
    if (phase == UITouchPhaseCancelled) mask |= 0x80;
    uint64_t absolute = mach_absolute_time();
    AbsoluteTime stamp = {(UInt32)(absolute >> 32), (UInt32)absolute};
    NSHID hand = NSUHand(kCFAllocatorDefault,stamp,3,0,0,mask,0,0,0,0,0,0,down,down,0);
    if (!hand) return NULL;
    NSHID finger = NSUFinger(kCFAllocatorDefault,stamp,1,2,mask,p.x,p.y,0,0,0,5,5,1,1,1,down,down,0);
    if (!finger) { CFRelease(hand); return NULL; }
    NSUSetInt(hand,0xB0019,1); NSUSetInt(finger,0xB0019,1);
    NSUAppend(hand,finger); CFRelease(finger);
    return hand;
}
@interface NSUNaturalSwipeEngine ()
@property(nonatomic) BOOL active;
@property(nonatomic,strong) UITouch *touch;
@property(nonatomic,strong) UIWindow *window;
@property(nonatomic,strong) CADisplayLink *link;
@property(nonatomic,copy) void(^completion)(NSDictionary *);
@property(nonatomic) CGPoint start,end,last;
@property(nonatomic) double started,duration,bend,shape;
@property(nonatomic) NSUInteger frames;
@property(nonatomic,strong) UIScrollView *scroll;
@property(nonatomic) CGPoint initialOffset;
@end
@implementation NSUNaturalSwipeEngine
- (BOOL)dispatchPoint:(CGPoint)p phase:(UITouchPhase)phase {
    NSHID hid = NSUCreateHID(p,phase);
    if (!hid) return NO;
    @try {
        [self.touch setTimestamp:NSProcessInfo.processInfo.systemUptime];
        [self.touch _setLocationInWindow:p resetPrevious:phase==UITouchPhaseBegan];
        [self.touch setPhase:phase];
        [self.touch _setHidEvent:hid];
        UIEvent *event = [UIApplication.sharedApplication _touchesEvent];
        [event _clearTouches]; [event _setHIDEvent:hid];
        if ([event respondsToSelector:@selector(_setTimestamp:)]) [event _setTimestamp:self.touch.timestamp];
        [event _addTouch:self.touch forDelayedDelivery:NO];
        NSUSendingSynthetic = YES;
        [UIApplication.sharedApplication sendEvent:event];
        NSUSendingSynthetic = NO;
        self.last=p; self.frames++;
        if (phase==UITouchPhaseBegan || phase==UITouchPhaseMoved) [self.touch setPhase:UITouchPhaseStationary];
    } @catch (NSException *e) {
        NSUSendingSynthetic=NO; CFRelease(hid); return NO;
    }
    CFRelease(hid); return YES;
}
- (BOOL)beginInWindow:(UIWindow *)w from:(CGPoint)a to:(CGPoint)b duration:(double)d completion:(void(^)(NSDictionary *))done {
    NSAssert(NSThread.isMainThread,@"Main thread required");
    if (self.active || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || !w || w.hidden || !NSUConstructorHID() || !isfinite(d) || d<0.06 || d>3.0 || !CGRectContainsPoint(w.bounds,a) || !CGRectContainsPoint(w.bounds,b) || hypot(a.x-b.x,a.y-b.y)<60) return NO;
    UITouch *t=[UITouch new]; UIApplication *app=UIApplication.sharedApplication;
    for (NSString *s in @[@"setWindow:",@"setView:",@"setPhase:",@"setTimestamp:",@"_setLocationInWindow:resetPrevious:",@"_setHidEvent:"]) if (![t respondsToSelector:NSSelectorFromString(s)]) return NO;
    if (![app respondsToSelector:@selector(_touchesEvent)]) return NO;
    UIEvent *ev=[app _touchesEvent];
    for (NSString *s in @[@"_clearTouches",@"_setHIDEvent:",@"_addTouch:forDelayedDelivery:"]) if (![ev respondsToSelector:NSSelectorFromString(s)]) return NO;
    UIView *hit=[w hitTest:a withEvent:nil]; if (!hit) return NO;
    UIScrollView *sv=nil;
    for (UIView *v=hit;v;v=v.superview) if ([v isKindOfClass:UIScrollView.class]) { sv=(UIScrollView *)v; break; }
    @try {
        [t setWindow:w]; [t setView:hit]; [t _setLocationInWindow:a resetPrevious:YES]; [t setPhase:UITouchPhaseBegan];
        [t setTapCount:0];
        if ([t respondsToSelector:@selector(_setIsFirstTouchForView:)]) [t _setIsFirstTouchForView:YES];
        else {
            if ([t respondsToSelector:@selector(_setIsTapToClick:)]) [t _setIsTapToClick:NO];
            Ivar flags=class_getInstanceVariable(UITouch.class,"_touchFlags");
            if (!flags) return NO;
            unsigned char *ptr=(unsigned char *)(__bridge void *)t+ivar_getOffset(flags); *ptr|=1;
        }
        if ([t respondsToSelector:@selector(setGestureView:)]) [t setGestureView:hit];
    } @catch(NSException *e) { return NO; }
    self.touch=t;self.window=w;self.start=a;self.end=b;self.last=a;self.duration=d;self.completion=done;
    self.scroll=sv;self.initialOffset=sv.contentOffset;self.frames=0;self.active=YES;
    self.bend=((double)arc4random_uniform(20001)/10000.-1.)*(self.motionProfile.count?1.5:7.);
    self.shape=0.65+(double)arc4random_uniform(3501)/10000.;
    self.started=CACurrentMediaTime();
    if (![self dispatchPoint:a phase:UITouchPhaseBegan]) { [self finish:@"dispatch-error"];return NO; }
    self.link=[CADisplayLink displayLinkWithTarget:self selector:@selector(tick:)];
    self.link.preferredFrameRateRange=CAFrameRateRangeMake(60,120,120);
    [self.link addToRunLoop:NSRunLoop.mainRunLoop forMode:NSRunLoopCommonModes];
    return YES;
}
- (void)tick:(CADisplayLink *)link {
    if (UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || self.window.hidden || (self.scroll && self.scroll.window!=self.window)) { [self cancel];return; }
    double u=fmin(1.,(CACurrentMediaTime()-self.started)/self.duration);
    // Blend linear and smoothstep so velocity varies continuously without reversals.
    double s=self.shape*(u*u*(3.-2.*u))+(1.-self.shape)*u;
    double xOffset=0;
    if(self.motionProfile.count>=2){
        NSArray *a=self.motionProfile.firstObject,*b=self.motionProfile.lastObject;
        for(NSUInteger i=1;i<self.motionProfile.count;i++){b=self.motionProfile[i];if([b[0] doubleValue]>=u){a=self.motionProfile[i-1];break;}}
        double at=[a[0] doubleValue],bt=[b[0] doubleValue];
        double f=fmax(0.,fmin(1.,(u-at)/fmax(.000001,bt-at)));
        s=[a[2] doubleValue]+([b[2] doubleValue]-[a[2] doubleValue])*f;
        xOffset=([a[1] doubleValue]+([b[1] doubleValue]-[a[1] doubleValue])*f)*self.window.bounds.size.width;
    }
    CGPoint p=CGPointMake(self.start.x+(self.end.x-self.start.x)*s+xOffset+self.bend*sin(M_PI*u),self.start.y+(self.end.y-self.start.y)*s);
    if (![self dispatchPoint:p phase:UITouchPhaseMoved]) { [self dispatchPoint:self.last phase:UITouchPhaseCancelled];[self finish:@"dispatch-error"];return; }
    if (u>=1.) { BOOL lifted=[self dispatchPoint:self.end phase:UITouchPhaseEnded]; [self finish:lifted?@"ended":@"dispatch-error"]; }
}
- (void)cancel { if(self.active){[self dispatchPoint:self.last phase:UITouchPhaseCancelled];[self finish:@"cancelled"];} }
- (void)finish:(NSString *)reason {
    [self.link invalidate];self.link=nil;self.active=NO;
    NSDictionary *r=@{@"result":reason,@"frames":@(self.frames),@"duration":@(self.duration),@"elapsed":@(CACurrentMediaTime()-self.started),@"startY":@(self.start.y),@"endY":@(self.end.y),@"offsetBefore":@(self.initialOffset.y),@"offsetAfter":@(self.scroll.contentOffset.y),@"scrollClass":self.scroll?NSStringFromClass(self.scroll.class):@"none"};
    void(^done)(NSDictionary *)=self.completion;self.completion=nil;self.touch=nil;self.window=nil;self.scroll=nil;
    if(done) done(r);
}
@end
