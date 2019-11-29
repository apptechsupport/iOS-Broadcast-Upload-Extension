
#import "SampleHandler.h"

@interface SampleHandler()

@property(nonatomic,strong)RPScreenRecorder* screenRecorder;
@property(nonatomic,strong)AVAssetWriter* assetWriter;
@property(nonatomic,strong)AVAssetWriterInput* assetWriterInput;
@property(nonatomic,strong)NSString* videoOutPath;
@property(nonatomic,strong)AVAssetWriterInputPixelBufferAdaptor *pixelBufferAdaptor;
@property(nonatomic,strong)AVCaptureSession *captureSession;

@end

@implementation SampleHandler

- (void)broadcastStartedWithSetupInfo:(NSDictionary<NSString *,NSObject *> *)setupInfo {
    // User has requested to start the broadcast. Setup info from the UI extension can be supplied but optional.
    NSLog(@"开始录屏");
    [self startScreenRecording];
    
}

#pragma mark - 初始化录屏所需类
- (void)startScreenRecording {
    
    self.captureSession = [[AVCaptureSession alloc]init];
    self.screenRecorder = [RPScreenRecorder sharedRecorder];
    if (self.screenRecorder.isRecording) {
        return;
    }
    NSError *error = nil;
    NSArray *pathDocuments = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *outputURL = pathDocuments[0];
    self.videoOutPath = [[outputURL stringByAppendingPathComponent:@"demo"] stringByAppendingPathExtension:@"mp4"];
    NSLog(@"self.videoOutPath=%@",self.videoOutPath);
    
    self.assetWriter = [AVAssetWriter assetWriterWithURL:[NSURL fileURLWithPath:self.videoOutPath] fileType:AVFileTypeMPEG4 error:&error];
    
    NSDictionary *compressionProperties =
        @{AVVideoProfileLevelKey         : AVVideoProfileLevelH264HighAutoLevel,
          AVVideoH264EntropyModeKey      : AVVideoH264EntropyModeCABAC,
          AVVideoAverageBitRateKey       : @(1920 * 1080 * 11.4),
          AVVideoMaxKeyFrameIntervalKey  : @60,
          AVVideoAllowFrameReorderingKey : @NO};
    
    NSNumber* width= [NSNumber numberWithFloat:[[UIScreen mainScreen] bounds].size.width];
    NSNumber* height = [NSNumber numberWithFloat:[[UIScreen mainScreen] bounds].size.height];
    
    NSDictionary *videoSettings =
        @{
          AVVideoCompressionPropertiesKey : compressionProperties,
          AVVideoCodecKey                 : AVVideoCodecTypeH264,
          AVVideoWidthKey                 : width,
          AVVideoHeightKey                : height
          };
    
    self.assetWriterInput = [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo outputSettings:videoSettings];
    self.pixelBufferAdaptor =
    [[AVAssetWriterInputPixelBufferAdaptor alloc]initWithAssetWriterInput:self.assetWriterInput
                                              sourcePixelBufferAttributes:[NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithInt:kCVPixelFormatType_32BGRA],kCVPixelBufferPixelFormatTypeKey,nil]];
    [self.assetWriter addInput:self.assetWriterInput];
    [self.assetWriterInput setMediaTimeScale:60];
    [self.assetWriter setMovieTimeScale:60];
    [self.assetWriterInput setExpectsMediaDataInRealTime:YES];
    
    //写入视频
    [self.assetWriter startWriting];
    [self.assetWriter startSessionAtSourceTime:kCMTimeZero];
    
    [self.captureSession startRunning];
    
}

#pragma mark - 直播
- (void)processSampleBuffer:(CMSampleBufferRef)sampleBuffer withType:(RPSampleBufferType)sampleBufferType {
    NSLog(@"录屏中...");
    switch (sampleBufferType) {
            
        case RPSampleBufferTypeVideo:
            // Handle video sample buffer for app audio
        {
            CVImageBufferRef imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
            static int64_t frameNumber = 0;
            if(self.assetWriterInput.readyForMoreMediaData){
                NSLog(@"录屏中写入...");
                [self.pixelBufferAdaptor appendPixelBuffer:imageBuffer
                                      withPresentationTime:CMTimeMake(frameNumber, 25)];
            }
            
            frameNumber++;
            
            NSLog(@"已获取的长度%lu",[NSData dataWithContentsOfFile:self.videoOutPath].length);
        }
            break;
        case RPSampleBufferTypeAudioApp:
            // Handle audio sample buffer for app audio
            break;
        case RPSampleBufferTypeAudioMic:
            // Handle audio sample buffer for mic audio
            break;
        default:
            break;
    }
}

- (void)broadcastPaused {
    // User has requested to pause the broadcast. Samples will stop being delivered.
    NSLog(@"暂停录屏");
    
}

- (void)broadcastResumed {
    // User has requested to resume the broadcast. Samples delivery will resume.
    NSLog(@"继续录屏");
    
}

- (void)broadcastFinished {
    // User has requested to finish the broadcast.
    NSLog(@"结束录屏");
    [self.captureSession stopRunning];
    [self.assetWriter finishWriting];
    
    NSData* data = [NSData dataWithContentsOfFile:self.videoOutPath];
    NSLog(@"获取的总长度%lu",data.length);
    
    //存储数据到共享区:SuiteName和宿主必须一致
    NSUserDefaults *userDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"group.hyjk.TestForLuPing"];
    [userDefaults setValue:data forKey:@"key"];
    [userDefaults synchronize];
    
    //向宿主发送通知
    [self sendNotificationForMessageWithIdentifier:@"broadcastFinished" userInfo:nil];
    
}

- (void)sendNotificationForMessageWithIdentifier:(nullable NSString *)identifier userInfo:(NSDictionary *)info {
    CFNotificationCenterRef const center = CFNotificationCenterGetDarwinNotifyCenter();
    CFDictionaryRef userInfo = (__bridge CFDictionaryRef)info;
    BOOL const deliverImmediately = YES;
    CFStringRef identifierRef = (__bridge CFStringRef)identifier;
    CFNotificationCenterPostNotification(center, identifierRef, NULL, userInfo, deliverImmediately);
}

@end
