
#import "ViewController.h"
#import <ReplayKit/ReplayKit.h>
#import <AVKit/AVKit.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController ()
@property(nonatomic,strong)AVPlayerViewController* moviePlayer;
@property(nonatomic,strong)NSString* videoPath;
@end

static NSString * const ScreenHoleNotificationName = @"ScreenHoleNotificationName";

void MyHoleNotificationCallback(CFNotificationCenterRef center,
                                   void * observer,
                                   CFStringRef name,
                                   void const * object,
                                   CFDictionaryRef userInfo) {
    NSString *identifier = (__bridge NSString *)name;
    NSObject *sender = (__bridge NSObject *)observer;
    //NSDictionary *info = (__bridge NSDictionary *)userInfo;
    NSDictionary *info = CFBridgingRelease(userInfo);
    
    NSLog(@"userInfo %@  %@",userInfo,info);

    NSDictionary *notiUserInfo = @{@"identifier":identifier};
    [[NSNotificationCenter defaultCenter] postNotificationName:ScreenHoleNotificationName
                                                        object:sender
                                                      userInfo:notiUserInfo];
}

@implementation ViewController

#pragma mark - Life Cycle
- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //注册Observer
    [self addUploaderEventMonitor];
    
    [self.view addSubview:self.moviePlayer.view];
    
    if (@available(iOS 12.0, *)) {
        
        RPSystemBroadcastPickerView *picker = [[RPSystemBroadcastPickerView alloc] initWithFrame:CGRectMake(0, 0, 100, 50)];
        picker.showsMicrophoneButton = YES;
        //extension的bundle id，必须要填写对
        picker.preferredExtension = @"hyjk.TestForLuPing.upload";
        [self.view addSubview:picker];
        picker.center = self.view.center;
        
        UILabel* label = [[UILabel alloc]initWithFrame:CGRectMake(0, CGRectGetMaxY(picker.frame), self.view.frame.size.width, 30)];
        label.text = @"点击上方按钮开始录屏";
        label.textAlignment = NSTextAlignmentCenter;
        [self.view addSubview:label];
            
    } else {
        // Fallback on earlier versions
    }
    
}

-(void)dealloc{
    
    [self removeUploaderEventMonitor];
    
}

#pragma mark - 接收来自extension的消息
- (void)addUploaderEventMonitor {
    
    [self registerForNotificationsWithIdentifier:@"broadcastFinished"];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(broadcastInfo:) name:ScreenHoleNotificationName object:nil];
}

- (void)broadcastInfo:(NSNotification *)noti {
    
    NSDictionary *userInfo = noti.userInfo;
    NSString *identifier = userInfo[@"identifier"];
    
    if ([identifier isEqualToString:@"broadcastFinished"]) {
        
        //reload数据
        NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.hyjk.TestForLuPing"];
        NSData* videoData = [userDefaults valueForKey:@"key"];
        
        if(videoData.length != 0){
            [self writeFile:videoData];
            AVPlayerItem *item = [[AVPlayerItem alloc]initWithURL:[NSURL fileURLWithPath:self.videoPath]];
            [self.moviePlayer.player replaceCurrentItemWithPlayerItem:item];
        }
    }
    
}

#pragma mark - 移除Observer
- (void)removeUploaderEventMonitor {
    
    [self unregisterForNotificationsWithIdentifier:@"broadcastFinished"];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ScreenHoleNotificationName object:nil];

}

#pragma mark - 宿主与extension之间的通知
- (void)registerForNotificationsWithIdentifier:(nullable NSString *)identifier {
    [self unregisterForNotificationsWithIdentifier:identifier];
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)identifier;
    CFNotificationCenterAddObserver(center,
                                    (__bridge const void *)(self),
                                    MyHoleNotificationCallback,
                                    str,
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
}

- (void)unregisterForNotificationsWithIdentifier:(nullable NSString *)identifier {
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFStringRef str = (__bridge CFStringRef)identifier;
    CFNotificationCenterRemoveObserver(center,
                                       (__bridge const void *)(self),
                                       str,
                                       NULL);
}

#pragma mark - SEL
-(void)writeFile:(NSData* )d{
    
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsPath =[paths objectAtIndex:0];
    NSString *iOSPath = [documentsPath stringByAppendingPathComponent:@"recored.mp4"];
    BOOL isSuccess = [d writeToFile:iOSPath atomically:YES];
    if (isSuccess) {
        NSLog(@"write success");
    } else {
        NSLog(@"write fail,please record first");
    }
}

#pragma mark - Lazy load
-(NSString* )videoPath{
    if (!_videoPath) {
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
        NSString *documentsPath =[paths objectAtIndex:0];
        _videoPath = [documentsPath stringByAppendingPathComponent:@"recored.mp4"];
    }
    return _videoPath;
}

-(AVPlayerViewController *)moviePlayer{

   if (!_moviePlayer) {
       _moviePlayer=[[AVPlayerViewController alloc]init];
       AVPlayerItem *item = [[AVPlayerItem alloc]initWithURL:[NSURL fileURLWithPath:self.videoPath]];
       _moviePlayer.player = [[AVPlayer alloc]initWithPlayerItem:item];
       _moviePlayer.view.frame=CGRectMake(0, 0, self.view.frame.size.width, 200);
       _moviePlayer.view.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
       _moviePlayer.showsPlaybackControls = YES;
   }
    return _moviePlayer;
    
}

@end
