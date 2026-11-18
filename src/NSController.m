#import "NSNaturalSwipe.h"
#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <math.h>
extern BOOL NSUSendingSynthetic;
static NSUInteger NSUPhysicalDispatchDepth=0;
static double NSURand(double a,double b){return a+(b-a)*(double)arc4random()/UINT32_MAX;}
static NSString *NSUDataDirectory(void){return [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/NaturalSwipe"];}
static void NSURecord(NSDictionary *d){
    @try {
        NSString *p=[NSUDataDirectory() stringByAppendingPathComponent:@"events.jsonl"];
        NSData *data=[NSJSONSerialization dataWithJSONObject:d options:NSJSONWritingFragmentsAllowed error:nil];
        if(!data)return;
        NSFileManager *fm=NSFileManager.defaultManager;
        if([[fm attributesOfItemAtPath:p error:nil] fileSize]>512000)[fm removeItemAtPath:p error:nil];
        if(![fm fileExistsAtPath:p])[fm createFileAtPath:p contents:nil attributes:nil];
        NSFileHandle *f=[NSFileHandle fileHandleForWritingAtPath:p];[f seekToEndOfFile];[f writeData:data];[f writeData:[@"\n" dataUsingEncoding:NSUTF8StringEncoding]];[f closeFile];
    }@catch(NSException *e){}
}
@interface NSUFloatingButton : UIButton
@property(nonatomic,copy) dispatch_block_t onTap;
@property(nonatomic,copy) dispatch_block_t onPressBegan;
@property(nonatomic,copy) dispatch_block_t onLongPress;
@property(nonatomic,copy) dispatch_block_t onInteraction;
@property(nonatomic,copy) void(^onDrag)(CGPoint delta, BOOL ended);
@property(nonatomic) BOOL isCollapsed;
@property(nonatomic) BOOL dockRight;
@property(nonatomic) BOOL gestureTracking;
@property(nonatomic) BOOL didDrag;
@property(nonatomic) BOOL didLongPress;
@property(nonatomic) NSUInteger touchSerial;
@property(nonatomic) CGPoint touchStart;
@property(nonatomic) CGPoint lastTouch;
@end
@implementation NSUFloatingButton
- (void)setIsCollapsed:(BOOL)value { _isCollapsed=value;[self setNeedsDisplay]; }
- (void)setDockRight:(BOOL)value { _dockRight=value;[self setNeedsDisplay]; }
- (void)drawRect:(CGRect)rect {
    [super drawRect:rect];if(!self.isCollapsed)return;
    [[UIColor colorWithWhite:1 alpha:.85] setFill];
    CGFloat x=self.dockRight?5:self.bounds.size.width-8;
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(x,(self.bounds.size.height-20)/2.,3,20) cornerRadius:1.5] fill];
}
- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [super touchesBegan:touches withEvent:event];
    UITouch *t=touches.anyObject;self.touchStart=[t locationInView:self.superview];self.lastTouch=self.touchStart;
    self.gestureTracking=YES;self.didDrag=NO;self.didLongPress=NO;
    NSUInteger serial=++self.touchSerial;if(self.onPressBegan)self.onPressBegan();if(self.onInteraction)self.onInteraction();
    __weak typeof(self) weakSelf=self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,(int64_t)(.55*NSEC_PER_SEC)),dispatch_get_main_queue(),^{
        __strong typeof(weakSelf) self=weakSelf;
        if(!self || !self.window || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || !self.gestureTracking || self.didDrag || self.touchSerial!=serial)return;
        self.didLongPress=YES;self.highlighted=NO;if(self.onLongPress)self.onLongPress();
    });
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    if(!self.gestureTracking || self.didLongPress)return;
    CGPoint p=[touches.anyObject locationInView:self.superview];
    if(!self.didDrag && hypot(p.x-self.touchStart.x,p.y-self.touchStart.y)>8){self.didDrag=YES;[super touchesCancelled:touches withEvent:event];}
    if(self.didDrag){
        CGPoint delta=CGPointMake(p.x-self.lastTouch.x,p.y-self.lastTouch.y);
        self.center=CGPointMake(self.center.x+delta.x,self.center.y+delta.y);self.lastTouch=p;
        if(self.onInteraction)self.onInteraction();if(self.onDrag)self.onDrag(delta,NO);return;
    }
    [super touchesMoved:touches withEvent:event];
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    BOOL tracked=self.gestureTracking,dragged=self.didDrag,longPressed=self.didLongPress;
    CGPoint p=[touches.anyObject locationInView:self];BOOL inside=CGRectContainsPoint(CGRectInset(self.bounds,-4,-4),p);
    self.gestureTracking=NO;self.touchSerial++;
    if(!dragged&&!longPressed)[super touchesEnded:touches withEvent:event];else [super touchesCancelled:touches withEvent:event];
    self.didDrag=NO;self.didLongPress=NO;
    if(!tracked)return;
    if(self.onInteraction)self.onInteraction();
    if(dragged){if(self.onDrag)self.onDrag(CGPointZero,YES);}
    else if(!longPressed && inside && self.onTap)self.onTap();
}
- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    BOOL dragged=self.didDrag;self.gestureTracking=NO;self.touchSerial++;self.didDrag=NO;self.didLongPress=NO;
    [super touchesCancelled:touches withEvent:event];if(dragged && self.onDrag)self.onDrag(CGPointZero,YES);
}
- (void)resetGesture {self.gestureTracking=NO;self.touchSerial++;self.didDrag=NO;self.didLongPress=NO;self.highlighted=NO;}
- (BOOL)accessibilityActivate { if(self.onPressBegan)self.onPressBegan();if(self.onTap)self.onTap();return YES; }
@end
@interface NSUNaturalController : NSObject
@property(nonatomic,strong) NSUFloatingButton *button;
@property(nonatomic,strong) NSTimer *idleTimer;
@property(nonatomic) BOOL collapsed;
@property(nonatomic) BOOL docking;
@property(nonatomic) double lastInteraction;
@property(nonatomic,weak) UIAlertController *presentedPanel;
@property(nonatomic) NSUInteger runSerial;
@property(nonatomic) BOOL stopOnTap,cancelPending;
@property(nonatomic) NSUInteger pressedSerial,cancelToken;
@property(nonatomic,strong) NSMutableSet *physicalTouches;
@property(nonatomic) CGSize lastWindowSize;
@property(nonatomic,strong) NSUNaturalSwipeEngine *engine;
- (void)performSwipe;
- (void)noteInteraction;
- (void)setCollapsed:(BOOL)value animated:(BOOL)animated;
- (void)dockButton;
- (void)armIdleTimer;
@property(nonatomic,strong) NSTimer *timer;
@property(nonatomic,strong) NSMutableDictionary *config;
@property(nonatomic,weak) UIWindow *window;
@property(nonatomic,weak) UIViewController *screen;
@property(nonatomic) BOOL running;
@property(nonatomic) NSInteger completed,requested;
@property(nonatomic) double nextAt;
@property(nonatomic,copy) NSString *commandID;
@property(nonatomic) BOOL learning;
@property(nonatomic) double learnUntil;
@property(nonatomic,strong) NSMutableArray *samples;
@property(nonatomic,strong) NSMutableArray *points;
@property(nonatomic,strong) UITouch *observedTouch;
@property(nonatomic,weak) UIWindow *observedWindow;
@property(nonatomic) double observedAt,lastSampleEnded;
- (void)stop:(NSString *)why;
- (void)observeEvent:(UIEvent *)event;
@end
static NSUNaturalController *NSUController;
static UIWindow *NSUActiveWindow(void);
static UIViewController *NSTop(UIViewController *v);
static void (*NSUOriginalSend)(id,SEL,UIEvent *);
static void NSUHookSend(id app,SEL sel,UIEvent *event){
    BOOL physical=!NSUSendingSynthetic;
    BOOL shouldStop=NO;NSUInteger owner=NSUController.runSerial;
    if(physical && event.type==UIEventTypeTouches){
        for(UITouch *t in event.allTouches){
            NSValue *key=[NSValue valueWithPointer:(__bridge const void *)t];
            if(t.phase==UITouchPhaseBegan){
                [NSUController.physicalTouches addObject:key];
                if(NSUController.running && ![t.view isDescendantOfView:NSUController.button])shouldStop=YES;
            }else if(t.phase==UITouchPhaseEnded || t.phase==UITouchPhaseCancelled)[NSUController.physicalTouches removeObject:key];
        }
        if(NSUController.learning)[NSUController observeEvent:event];
    }
    if(physical)NSUPhysicalDispatchDepth++;
    @try {
        NSUOriginalSend(app,sel,event);
        if(physical){
            if(shouldStop && NSUController.runSerial==owner)[NSUController stop:@"manual-touch"];
            if(NSUController.button && event.type==UIEventTypeTouches)[NSUController noteInteraction];
        }
    } @finally {if(physical)NSUPhysicalDispatchDepth--;}
}
static UIWindow *NSUActiveWindow(void){
    for(UIScene *scene in UIApplication.sharedApplication.connectedScenes){
        if(scene.activationState!=UISceneActivationStateForegroundActive || ![scene isKindOfClass:UIWindowScene.class])continue;
        UIWindow *fallback=nil;
        for(UIWindow *w in ((UIWindowScene *)scene).windows){
            if(w.hidden || w.alpha<0.5 || w.windowLevel!=UIWindowLevelNormal || !w.rootViewController)continue;
            if(w.isKeyWindow)return w;fallback=w;
        }
        if(fallback)return fallback;
    }
    for(UIWindow *w in UIApplication.sharedApplication.windows)if(!w.hidden && w.windowLevel==UIWindowLevelNormal && w.rootViewController && w.isKeyWindow)return w;
    return nil;
}
static UIViewController *NSTop(UIViewController *v){
    if(v.presentedViewController)return NSTop(v.presentedViewController);
    if([v isKindOfClass:UINavigationController.class])return NSTop(((UINavigationController *)v).visibleViewController);
    if([v isKindOfClass:UITabBarController.class])return NSTop(((UITabBarController *)v).selectedViewController);
    return v;
}
@implementation NSUNaturalController
- (instancetype)init{
    if((self=[super init])){
        [NSFileManager.defaultManager createDirectoryAtPath:NSUDataDirectory() withIntermediateDirectories:YES attributes:nil error:nil];
        self.engine=[NSUNaturalSwipeEngine new];self.physicalTouches=[NSMutableSet new];
        self.samples=[[NSArray arrayWithContentsOfFile:[NSUDataDirectory() stringByAppendingPathComponent:@"gestures.plist"]] mutableCopy]?:[NSMutableArray new];
        self.config=[@{@"minDuration":@0.35,@"maxDuration":@0.85,@"minGap":@1.8,@"maxGap":@4.0,@"count":@20,@"up":@YES,@"useLearned":@YES,@"dockRight":@YES,@"dockY":@0.44} mutableCopy];
        NSDictionary *d=[NSDictionary dictionaryWithContentsOfFile:[NSUDataDirectory() stringByAppendingPathComponent:@"settings.plist"]];
        if(d)[self.config addEntriesFromDictionary:d];[self validate];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(inactive:) name:UIApplicationWillResignActiveNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(inactive:) name:UIApplicationDidEnterBackgroundNotification object:nil];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(noteInteraction) name:UIApplicationDidBecomeActiveNotification object:nil];
        self.timer=[NSTimer timerWithTimeInterval:0.5 target:self selector:@selector(poll:) userInfo:nil repeats:YES];
        [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];
        NSURecord(@{@"type":@"loaded",@"version":@"1.0.0",@"bundle":NSBundle.mainBundle.bundleIdentifier?:@"",@"pid":@(NSProcessInfo.processInfo.processIdentifier),@"time":@(NSDate.date.timeIntervalSince1970)});
    }return self;
}
- (void)validate{
    double a=[self.config[@"minDuration"] doubleValue],b=[self.config[@"maxDuration"] doubleValue];
    if(!isfinite(a))a=.35;if(!isfinite(b))b=.85;a=fmax(.06,fmin(3.,a));b=fmax(a,fmin(3.,b));
    double c=[self.config[@"minGap"] doubleValue],d=[self.config[@"maxGap"] doubleValue];
    if(!isfinite(c))c=1.8;if(!isfinite(d))d=4.;c=fmax(.5,fmin(60.,c));d=fmax(c,fmin(120.,d));
    self.config[@"minDuration"]=@(a);self.config[@"maxDuration"]=@(b);self.config[@"minGap"]=@(c);self.config[@"maxGap"]=@(d);
    self.config[@"count"]=@(MAX(0,[self.config[@"count"] integerValue]));
    self.config[@"up"]=@([self.config[@"up"] boolValue]);
    double y=[self.config[@"dockY"] doubleValue];self.config[@"dockY"]=@(isfinite(y)?fmax(.05,fmin(.95,y)):.44);
}
- (void)save{[self validate];[self.config writeToFile:[NSUDataDirectory() stringByAppendingPathComponent:@"settings.plist"] atomically:YES];}
- (void)inactive:(NSNotification *)n{[self stop:@"app-inactive"];self.learning=NO;self.points=nil;self.observedTouch=nil;[self.idleTimer invalidate];self.idleTimer=nil;self.docking=NO;[self.button resetGesture];[self.physicalTouches removeAllObjects];}
- (void)updateButton{
    NSString *text=self.running?@"停止":(self.learning?[NSString stringWithFormat:@"学习%lu",(unsigned long)self.samples.count]:@"滑动");
    [self.button setTitle:self.collapsed?@"":text forState:UIControlStateNormal];
    self.button.backgroundColor=self.running?[UIColor colorWithRed:.82 green:.12 blue:.16 alpha:.96]:[UIColor colorWithRed:.12 green:.32 blue:.46 alpha:.92];
    self.button.accessibilityLabel=self.running?@"点击停止自动滑动":@"点击按配置开始滑动";
    self.button.accessibilityHint=@"长按打开设置，拖动后贴边";
}
- (void)mountButton:(UIWindow *)w{
    if(!self.button){
        self.button=[[NSUFloatingButton alloc]initWithFrame:CGRectMake(0,0,56,46)];
        self.button.titleLabel.font=[UIFont boldSystemFontOfSize:14];self.button.titleLabel.adjustsFontSizeToFitWidth=YES;
        self.button.exclusiveTouch=YES;self.button.clipsToBounds=YES;self.button.contentMode=UIViewContentModeRedraw;[self.button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
        __weak typeof(self) weakSelf=self;
        self.button.onPressBegan=^{__strong typeof(weakSelf) self=weakSelf;if(!self)return;self.stopOnTap=self.running||self.engine.active;self.pressedSerial=self.runSerial;};
        self.button.onTap=^{
            __strong typeof(weakSelf) self=weakSelf;if(!self)return;
            [self noteInteraction];[self setCollapsed:NO animated:YES];
            if(self.stopOnTap){if(self.runSerial==self.pressedSerial)[self stop:@"button-tap"];return;}
            if(self.running)return;
            [self startCount:[self.config[@"count"] integerValue]];
        };
        self.button.onLongPress=^{__strong typeof(weakSelf) self=weakSelf;if(!self)return;[self noteInteraction];[self setCollapsed:NO animated:YES];[self menu];};
        self.button.onInteraction=^{[weakSelf noteInteraction];};
        self.button.onDrag=^(CGPoint delta,BOOL ended){
            __strong typeof(weakSelf) self=weakSelf;if(!self)return;
            if(!self.docking){self.docking=YES;[self stop:@"drag-button"];}
            if(ended)[self dockButton];
        };
    }
    BOOL reparent=self.button.superview!=w;
    if(reparent || !CGSizeEqualToSize(self.lastWindowSize,w.bounds.size)){self.docking=NO;[self.button resetGesture];}
    if(reparent){[self.button removeFromSuperview];[w addSubview:self.button];}
    if(reparent || !CGSizeEqualToSize(self.lastWindowSize,w.bounds.size)){
        self.lastWindowSize=w.bounds.size;
        self.button.center=CGPointMake(28,[self.config[@"dockY"] doubleValue]*w.bounds.size.height);
        [self applyButtonFrameAnimated:NO];
        [self noteInteraction];
    }
    [w bringSubviewToFront:self.button];[self updateButton];
}
- (void)applyButtonFrameAnimated:(BOOL)animated{
    UIWindow *w=self.button.window;if(!w || self.docking)return;
    CGFloat h=46,width=self.collapsed?26:56;
    BOOL right=[self.config[@"dockRight"] boolValue];
    CGFloat x=right?(self.collapsed?w.bounds.size.width-14:w.bounds.size.width-width-6):(self.collapsed?-12:6);
    CGFloat y=fmax(w.safeAreaInsets.top+h*.5+8,fmin(w.bounds.size.height-w.safeAreaInsets.bottom-h*.5-8,self.button.center.y));
    CGRect frame=CGRectMake(x,y-h*.5,width,h);
    void(^change)(void)=^{self.button.frame=frame;self.button.alpha=self.collapsed?.76:1.;self.button.layer.cornerRadius=self.collapsed?13:23;self.button.isCollapsed=self.collapsed;self.button.dockRight=right;[self updateButton];};
    if(animated)[UIView animateWithDuration:.22 delay:0 options:UIViewAnimationOptionBeginFromCurrentState|UIViewAnimationOptionAllowUserInteraction|UIViewAnimationOptionCurveEaseOut animations:change completion:nil];else change();
}
- (void)noteInteraction{
    self.lastInteraction=CACurrentMediaTime();[self armIdleTimer];
}
- (void)armIdleTimer{
    [self.idleTimer invalidate];self.idleTimer=nil;
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive || self.collapsed)return;
    NSTimeInterval delay=fmax(.1,5.-(CACurrentMediaTime()-self.lastInteraction));
    self.idleTimer=[NSTimer timerWithTimeInterval:delay target:self selector:@selector(idleTimeout:) userInfo:nil repeats:NO];
    [NSRunLoop.mainRunLoop addTimer:self.idleTimer forMode:NSRunLoopCommonModes];
}
- (void)idleTimeout:(NSTimer *)timer{
    self.idleTimer=nil;
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    BOOL panelVisible=self.presentedPanel.presentingViewController && self.presentedPanel.isViewLoaded && self.presentedPanel.view.window;
    if(self.button.gestureTracking || self.physicalTouches.count || self.docking || panelVisible){[self noteInteraction];return;}
    if(CACurrentMediaTime()-self.lastInteraction>=4.95)[self setCollapsed:YES animated:YES];else [self armIdleTimer];
}
- (void)setCollapsed:(BOOL)value animated:(BOOL)animated{
    self.collapsed=value;
    if(value){[self.idleTimer invalidate];self.idleTimer=nil;}else [self armIdleTimer];
    [self applyButtonFrameAnimated:animated];
}
- (void)dockButton{
    self.docking=NO;
    UIWindow *w=self.button.window;if(!w)return;
    BOOL right=self.button.center.x>=w.bounds.size.width*.5;
    CGFloat y=fmax(w.safeAreaInsets.top+31,fmin(w.bounds.size.height-w.safeAreaInsets.bottom-31,self.button.center.y));
    self.config[@"dockRight"]=@(right);self.config[@"dockY"]=@(y/w.bounds.size.height);self.docking=NO;
    [self save];self.button.center=CGPointMake(right?w.bounds.size.width-28:28,y);
    self.collapsed=NO;[self applyButtonFrameAnimated:YES];[self noteInteraction];
}
- (void)menu{
    [self stop:@"menu-stop"];[self noteInteraction];
    UIWindow *w=NSUActiveWindow();UIViewController *vc=NSTop(w.rootViewController);if(!vc || [vc isKindOfClass:UIAlertController.class])return;
    NSString *direction=[self.config[@"up"] boolValue]?@"手指向上 · 浏览下方内容":@"手指向下 · 浏览上方内容";
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"自然滑动" message:[NSString stringWithFormat:@"%@\n每次 %.2f–%.2f 秒，间隔 %.1f–%.1f 秒\n轻触页面、切到后台会停止",direction,[self.config[@"minDuration"] doubleValue],[self.config[@"maxDuration"] doubleValue],[self.config[@"minGap"] doubleValue],[self.config[@"maxGap"] doubleValue]] preferredStyle:UIAlertControllerStyleActionSheet];
    NSString *startTitle=[self.config[@"count"] integerValue]==0?@"开始无限循环":[NSString stringWithFormat:@"开始 %ld 次",(long)[self.config[@"count"] integerValue]];
    [a addAction:[UIAlertAction actionWithTitle:startTitle style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[self startCount:[self.config[@"count"] integerValue]];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"无限循环（直到手动停止）" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){self.config[@"count"]=@0;[self save];[self startCount:0];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"试滑一次" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[self startCount:1];}]];
    [a addAction:[UIAlertAction actionWithTitle:self.learning?@"结束学习":@"学习我的滑动（60秒）" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){[self stop:@"learning"];self.learning=!self.learning;self.learnUntil=CACurrentMediaTime()+60;self.lastSampleEnded=0;[self updateButton];}]];
    [a addAction:[UIAlertAction actionWithTitle:[NSString stringWithFormat:@"个人节奏：%@（%lu条）",[self.config[@"useLearned"] boolValue]?@"开":@"关",(unsigned long)self.samples.count] style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){self.config[@"useLearned"]=@(![self.config[@"useLearned"] boolValue]);[self save];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"设置速度与间隔" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){
        UIViewController *presenter=NSUActiveWindow().rootViewController;
        [presenter dismissViewControllerAnimated:YES completion:^{[self settings];}];
    }]];
    [a addAction:[UIAlertAction actionWithTitle:@"切换滑动方向" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){self.config[@"up"]=@(![self.config[@"up"] boolValue]);[self save];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    a.popoverPresentationController.sourceView=self.button;a.popoverPresentationController.sourceRect=self.button.bounds;self.presentedPanel=a;[vc presentViewController:a animated:YES completion:nil];
}
- (void)settings{
    UIViewController *vc=NSTop(NSUActiveWindow().rootViewController);if(!vc || [vc isKindOfClass:UIAlertController.class])return;
    UIAlertController *a=[UIAlertController alertControllerWithTitle:@"随机滑动设置" message:@"单次时间越短越快（秒）\n每次在上下限间随机；间隔从抬指后开始" preferredStyle:UIAlertControllerStyleAlert];
    NSArray *keys=@[@"minDuration",@"maxDuration",@"minGap",@"maxGap",@"count"];
    NSArray *names=@[@"最快用时（0.06–3秒）",@"最慢用时（≤3秒）",@"最短间隔（≥0.5秒）",@"最长间隔（≤120秒）",@"滑动次数（0=无限）"];
    for(NSInteger i=0;i<keys.count;i++)[a addTextFieldWithConfigurationHandler:^(UITextField *f){f.placeholder=names[i];f.text=[self.config[keys[i]] description];f.keyboardType=i==4?UIKeyboardTypeNumberPad:UIKeyboardTypeDecimalPad;UILabel *label=[[UILabel alloc]initWithFrame:CGRectMake(0,0,154,30)];label.text=names[i];label.font=[UIFont systemFontOfSize:11];f.leftView=label;f.leftViewMode=UITextFieldViewModeAlways;f.accessibilityLabel=names[i];}];
    [a addAction:[UIAlertAction actionWithTitle:@"保存" style:UIAlertActionStyleDefault handler:^(UIAlertAction *x){for(NSInteger i=0;i<keys.count;i++) self.config[keys[i]]=@([a.textFields[i].text doubleValue]);[self save];}]];
    [a addAction:[UIAlertAction actionWithTitle:@"取消" style:UIAlertActionStyleCancel handler:nil]];
    self.presentedPanel=a;[vc presentViewController:a animated:YES completion:nil];
}
- (void)observeEvent:(UIEvent *)event{
    if(!self.learning || CACurrentMediaTime()>self.learnUntil)return;
    if(event.allTouches.count!=1){self.points=nil;self.observedTouch=nil;return;}
    UITouch *t=event.allTouches.anyObject;
    if(t.phase==UITouchPhaseBegan){
        UIView *v=t.view;BOOL scroll=NO;
        for(UIView *p=v;p;p=p.superview){if([p isKindOfClass:UITextView.class]||[p isKindOfClass:UITextField.class])return;if([p isKindOfClass:UIScrollView.class]){scroll=YES;break;}}
        if(!scroll || [v isDescendantOfView:self.button])return;
        self.observedTouch=t;self.observedWindow=t.window;self.observedAt=t.timestamp;self.points=[NSMutableArray new];
    }
    if(t!=self.observedTouch || !self.points || !self.observedWindow)return;
    UIWindow *w=self.observedWindow;CGPoint p=[t locationInView:w];double dt=t.timestamp-self.observedAt;
    if(dt<0 || dt>3. || self.points.count>=500){self.points=nil;self.observedTouch=nil;return;}
    if(self.points.count==0 || dt>[self.points.lastObject[0] doubleValue]) [self.points addObject:@[@(dt),@(p.x/w.bounds.size.width),@(p.y/w.bounds.size.height)]];
    if(t.phase==UITouchPhaseCancelled){self.points=nil;self.observedTouch=nil;return;}
    if(t.phase!=UITouchPhaseEnded)return;
    NSArray *first=self.points.firstObject,*last=self.points.lastObject;
    double dy=[last[2] doubleValue]-[first[2] doubleValue],dx=[last[1] doubleValue]-[first[1] doubleValue];
    if(dt>=.08 && dt<=2.5 && fabs(dy)>.12 && fabs(dx)<.30 && self.points.count>=4){
        NSMutableArray *profile=[NSMutableArray new];
        for(NSArray *q in self.points){double progress=([q[2] doubleValue]-[first[2] doubleValue])/dy;double residual=[q[1] doubleValue]-[first[1] doubleValue]-dx*progress;[profile addObject:@[@([q[0] doubleValue]/dt),@(residual),@(progress)]];}
        double gap=self.lastSampleEnded>0?self.observedAt-self.lastSampleEnded:0;
        NSDictionary *sample=@{@"duration":@(dt),@"from":@[[first objectAtIndex:1],[first objectAtIndex:2]],@"to":@[[last objectAtIndex:1],[last objectAtIndex:2]],@"profile":profile,@"up":@(dy<0),@"gap":@(gap),@"time":@(NSDate.date.timeIntervalSince1970)};
        [self.samples addObject:sample];while(self.samples.count>20)[self.samples removeObjectAtIndex:0];
        [self.samples writeToFile:[NSUDataDirectory() stringByAppendingPathComponent:@"gestures.plist"] atomically:YES];
        self.lastSampleEnded=t.timestamp;
        NSMutableArray *durations=[NSMutableArray new],*gaps=[NSMutableArray new];
        for(NSDictionary *s in self.samples){[durations addObject:s[@"duration"]];double g=[s[@"gap"] doubleValue];if(g>=.5&&g<=60)[gaps addObject:@(g)];}
        [durations sortUsingSelector:@selector(compare:)];double median=[durations[durations.count/2] doubleValue];
        self.config[@"minDuration"]=@(fmax(.06,median*.72));self.config[@"maxDuration"]=@(fmax(.08,median*1.45));self.config[@"useLearned"]=@YES;
        if(gaps.count){[gaps sortUsingSelector:@selector(compare:)];double mg=[gaps[gaps.count/2] doubleValue];self.config[@"minGap"]=@(fmax(.5,mg*.8));self.config[@"maxGap"]=@(mg*1.2);}
        [self save];[self updateButton];
        NSURecord(@{@"type":@"learned",@"duration":@(dt),@"distanceFraction":@(fabs(dy)),@"points":@(profile.count),@"samples":@(self.samples.count),@"up":@(dy<0)});
    }
    self.points=nil;self.observedTouch=nil;
}
- (void)startCount:(NSInteger)n{
    [self stop:@"new-session"];self.learning=NO;self.points=nil;self.observedTouch=nil;[self validate];
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    self.running=YES;self.completed=0;self.requested=MAX(0,n);self.window=NSUActiveWindow();self.screen=nil;self.nextAt=CACurrentMediaTime();
    [self updateButton];
    NSURecord(@{@"type":@"start",@"count":@(self.requested),@"config":self.config.copy,@"time":@(NSDate.date.timeIntervalSince1970)});
    NSUInteger serial=self.runSerial;
    dispatch_async(dispatch_get_main_queue(),^{if(self.runSerial==serial && self.running && !self.engine.active)[self performSwipe];});
}
- (void)stop:(NSString *)why{
    BOOL was=self.running||self.engine.active;self.runSerial++;self.running=NO;
    NSUInteger token=++self.cancelToken;
    if(self.engine.active && NSUPhysicalDispatchDepth>0){
        self.cancelPending=YES;
        dispatch_async(dispatch_get_main_queue(),^{
            if(self.cancelToken!=token || !self.cancelPending)return;
            self.cancelPending=NO;[self.engine cancel];
            if(self.running)[self performSwipe];
        });
    }else {self.cancelPending=NO;[self.engine cancel];}
    [self updateButton];
    if(was)NSURecord(@{@"type":@"stop",@"reason":why,@"completed":@(self.completed),@"time":@(NSDate.date.timeIntervalSince1970)});
}
- (void)poll:(NSTimer *)timer{
    if(UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    if(self.learning && CACurrentMediaTime()>self.learnUntil){self.learning=NO;self.points=nil;self.observedTouch=nil;}
    UIWindow *w=NSUActiveWindow();if(!w)return;[self mountButton:w];
    NSString *cp=[NSUDataDirectory() stringByAppendingPathComponent:@"command.plist"];
    NSDictionary *cmd=[NSDictionary dictionaryWithContentsOfFile:cp];
    NSString *cid=[cmd[@"id"] isKindOfClass:NSString.class]?cmd[@"id"]:nil;
    // Consume commands once per process; discard old commands rather than replaying after an app launch.
    if(cid && ![cid isEqualToString:self.commandID]){
        self.commandID=cid;[NSFileManager.defaultManager removeItemAtPath:cp error:nil];
        double age=NSDate.date.timeIntervalSince1970-[cmd[@"time"] doubleValue];
        if(age>=0 && age<15){
            NSString *op=cmd[@"op"];
            if([op isEqual:@"stop"])[self stop:@"command"];
            else if([op isEqual:@"once"])[self startCount:1];
            else if([op isEqual:@"loop"])[self startCount:0];
            else if([op isEqual:@"menu"])[self menu];
            else if([op isEqual:@"status"]){
                NSDictionary *state=@{@"version":@"1.0.0",@"running":@(self.running),@"collapsed":@(self.collapsed),@"frame":NSStringFromCGRect(self.button.frame),@"window":NSStringFromCGRect(w.bounds),@"count":self.config[@"count"],@"completed":@(self.completed),@"dockRight":self.config[@"dockRight"],@"samples":@(self.samples.count),@"idleSeconds":@(CACurrentMediaTime()-self.lastInteraction),@"menuVisible":@(self.presentedPanel.viewIfLoaded.window!=nil),@"time":@(NSDate.date.timeIntervalSince1970)};
                [[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingPrettyPrinted error:nil] writeToFile:[NSUDataDirectory() stringByAppendingPathComponent:@"ui-state.json"] atomically:YES];
            }
            else if([op isEqual:@"learn"]){[self stop:@"learning"];self.learning=YES;self.learnUntil=CACurrentMediaTime()+60;self.lastSampleEnded=0;[self updateButton];}
        }
    }
    if(self.running && !self.engine.active && CACurrentMediaTime()>=self.nextAt)[self performSwipe];
}
- (void)performSwipe{
    if(!self.running || self.cancelPending || self.engine.active || NSUPhysicalDispatchDepth>0 || CACurrentMediaTime()<self.nextAt || UIApplication.sharedApplication.applicationState!=UIApplicationStateActive)return;
    UIWindow *w=NSUActiveWindow();if(!w){[self stop:@"no-active-window"];return;}
    UIViewController *top=NSTop(w.rootViewController);
    if([top isKindOfClass:UIAlertController.class] && top==self.presentedPanel){
        if(top.isBeingDismissed){NSUInteger serial=self.runSerial;[top.transitionCoordinator animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> c){if(self.runSerial==serial && self.running)[self performSwipe];}];}
        return;
    }
    if(w!=self.window || !top || [top isKindOfClass:UIAlertController.class] || (self.screen && self.screen!=top)){[self stop:@"screen-changed"];return;}
    self.screen=top;
    double width=w.bounds.size.width,height=w.bounds.size.height;
    if(width>=height){[self stop:@"portrait-required"];return;}
    double low=fmin(height-w.safeAreaInsets.bottom-82,height*NSURand(.68,.76));
    double high=fmax(w.safeAreaInsets.top+90,height*NSURand(.30,.38));
    CGPoint a=CGPointMake(width*NSURand(.43,.57),low),b=CGPointMake(a.x+NSURand(-10,10),high);
    if(![self.config[@"up"] boolValue]){double y=a.y;a.y=b.y;b.y=y;}
    self.engine.motionProfile=nil;
    double learnedDuration=0;
    if([self.config[@"useLearned"] boolValue] && self.samples.count){
        NSMutableArray *matching=[NSMutableArray new];for(NSDictionary *s in self.samples)if([s[@"up"] boolValue]==[self.config[@"up"] boolValue])[matching addObject:s];
        if(matching.count){NSDictionary *s=matching[arc4random_uniform((uint32_t)matching.count)];
            NSArray *from=s[@"from"],*to=s[@"to"];
            double jitter=NSURand(-.012,.012)*width;
            a=CGPointMake([from[0] doubleValue]*width+jitter,[from[1] doubleValue]*height);
            b=CGPointMake([to[0] doubleValue]*width+jitter,[to[1] doubleValue]*height);
            a.x=fmax(width*.07,fmin(width*.95,a.x));b.x=fmax(width*.07,fmin(width*.95,b.x));
            double topEdge=w.safeAreaInsets.top+45,bottomEdge=height-w.safeAreaInsets.bottom-50;
            a.y=fmax(topEdge,fmin(bottomEdge,a.y));b.y=fmax(topEdge,fmin(bottomEdge,b.y));
            self.engine.motionProfile=s[@"profile"];learnedDuration=[s[@"duration"] doubleValue];
        }
    }
    UIView *hit=[w hitTest:a withEvent:nil];BOOL found=NO;
    for(UIView *v=hit;v;v=v.superview){
        if([v isKindOfClass:UITextField.class]||[v isKindOfClass:UITextView.class]){[self stop:@"text-input"];return;}
        if([v isKindOfClass:UIScrollView.class] && ((UIScrollView *)v).scrollEnabled){found=YES;break;}
    }
    if(!found || [hit isDescendantOfView:self.button]){[self stop:@"no-scroll-target"];return;}
    double duration=NSURand([self.config[@"minDuration"] doubleValue],[self.config[@"maxDuration"] doubleValue]);
    if(learnedDuration>0)duration=fmax([self.config[@"minDuration"] doubleValue],fmin([self.config[@"maxDuration"] doubleValue],learnedDuration*NSURand(.90,1.10)));
    NSUInteger owner=self.runSerial;
    BOOL started=[self.engine beginInWindow:w from:a to:b duration:duration completion:^(NSDictionary *r){
        NSMutableDictionary *m=r.mutableCopy;m[@"type"]=@"swipe";m[@"time"]=@(NSDate.date.timeIntervalSince1970);NSURecord(m);
        if(self.runSerial!=owner)return;
        if(![r[@"result"] isEqual:@"ended"]){self.running=NO;[self updateButton];return;}
        if(self.completed<NSIntegerMax)self.completed++;if(self.requested>0 && self.completed>=self.requested){[self stop:@"completed"];return;}
        self.nextAt=CACurrentMediaTime()+NSURand([self.config[@"minGap"] doubleValue],[self.config[@"maxGap"] doubleValue]);
    }];
    if(!started)[self stop:@"touch-unavailable"];
}
@end
void NSUInstall(void){
    static BOOL loaded=NO;if(loaded)return;
    NSBundle *bundle=NSBundle.mainBundle;
    NSString *bundleID=bundle.bundleIdentifier;
    NSString *process=NSProcessInfo.processInfo.processName;
    if(bundleID.length==0 || ![bundle.bundlePath.pathExtension.lowercaseString isEqualToString:@"app"] || bundle.infoDictionary[@"NSExtension"])return;
    if([bundleID.lowercaseString isEqualToString:@"com.apple.springboard"] || [process isEqualToString:@"SpringBoard"] || [process isEqualToString:@"backboardd"])return;
    // The original jailbreak edition must not run alongside this edition.
    if(NSClassFromString(@"NSNaturalController"))return;
    UIApplication *app=UIApplication.sharedApplication;if(!app)return;
    const void *marker=(const void *)sel_registerName("luobo_naturalSwipeUniversal_installed_v1");
    if(objc_getAssociatedObject(app,marker))return;
    // object_getClass(instance) is the instance's concrete class, not its metaclass.
    Class appClass=object_getClass(app);SEL selector=@selector(sendEvent:);
    Method method=class_getInstanceMethod(appClass,selector);
    if(!appClass || !method)return;
    IMP prior=method_getImplementation(method);
    if(!prior || prior==(IMP)NSUHookSend)return;
    void(*hook)(Class,SEL,IMP,IMP *)=dlsym(RTLD_DEFAULT,"MSHookMessageEx");
    if(hook){
        IMP original=NULL;
        hook(appClass,selector,(IMP)NSUHookSend,&original);
        NSUOriginalSend=(void(*)(id,SEL,UIEvent *))original;
    }else{
        const char *types=method_getTypeEncoding(method);
        NSUOriginalSend=(void(*)(id,SEL,UIEvent *))prior;
        if(!class_addMethod(appClass,selector,(IMP)NSUHookSend,types))
            NSUOriginalSend=(void(*)(id,SEL,UIEvent *))method_setImplementation(class_getInstanceMethod(appClass,selector),(IMP)NSUHookSend);
    }
    if(!NSUOriginalSend || NSUOriginalSend==NSUHookSend)return;
    objc_setAssociatedObject(app,marker,@YES,OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    loaded=YES;NSUController=[NSUNaturalController new];
    NSURecord(@{@"type":@"generic-loaded",@"bundle":bundleID,@"version":@"1.0.0",@"hook":hook?@"existing-hook-engine":@"objc-runtime"});
}
__attribute__((constructor)) static void NSUConstructor(void){
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,2*NSEC_PER_SEC),dispatch_get_main_queue(),^{NSUInstall();});
}
