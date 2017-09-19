//
//  ViewController.m
//  FFmpegProject
//
//  Created by Dombo on 2017/9/8.
//  Copyright © 2017年 Dombo. All rights reserved.
//

#import "ViewController.h"
#include "avformat.h"
#import <VideoToolbox/VideoToolbox.h>

#import "KxMovieViewController.h"
#import "FFmpegManager.h"
#define LERP(A,B,C) ((A)*(1.0-C)+(B)*C)


#import "MovieManager.h"
@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *PlayImageView;
@property (weak, nonatomic) IBOutlet UILabel *fpsLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@property (nonatomic, strong) MovieManager *manager;


@property (nonatomic, assign) float lastFrameTime;
@property (nonatomic, strong) NSTimer *timer;
@end

@implementation ViewController

-(void)viewDidAppear:(BOOL)animated {
//    NSString *path = @"http://live.hkstv.hk.lxdns.com/live/hks/playlist.m3u8";//@"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4";
//    
//    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
//    
//    if ([path.pathExtension isEqualToString:@"wmv"])
//        parameters[KxMovieParameterMinBufferedDuration] = @(5.0);
//    
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
//        parameters[KxMovieParameterDisableDeinterlacing] = @(YES);
//    
//    KxMovieViewController *vc = [KxMovieViewController movieViewControllerWithContentPath:path parameters:parameters];
//    [self presentViewController:vc animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.manager = [[MovieManager alloc] initWithVideo:@"http://live.hkstv.hk.lxdns.com/live/hks/playlist.m3u8"];
    
    int tns, thh, tmm, tss;
    tns = self.manager.duration;
    thh = tns / 3600;
    tmm = (tns % 3600) / 60;
    tss = tns % 60;

//    NSLog(@"%s", avcodec_configuration());
    
//    FFmpegManager *manager = [[FFmpegManager alloc] initWithVideo:@"http://wvideo.spriteapp.cn/video/2016/0328/56f8ec01d9bfe_wpd.mp4"];
    
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)playBtnAction:(UIButton *)sender {
    sender.selected = !sender.selected;
    
    if (sender.selected)
    {
        _lastFrameTime = -1;
        [self.manager seekTime:0.0];// seek to 0.0 seconds
        self.timer = [NSTimer scheduledTimerWithTimeInterval: 1 / self.manager.fps
                                                      target:self
                                                    selector:@selector(displayNextFrame:)
                                                    userInfo:nil
                                                     repeats:YES];
    }
    else
    {
        [self.timer invalidate];
        self.timer = nil;
    }
}


-(void)displayNextFrame:(NSTimer *)timer {
    NSTimeInterval startTime = [NSDate timeIntervalSinceReferenceDate];
    self.timeLabel.text = [self dealTime:self.manager.currentTime];
    if (![self.manager stepFrame]) {
        [timer invalidate];
        return;
    }
    self.PlayImageView.image = self.manager.currentImage;
    float frameTime = 1.0 / ([NSDate timeIntervalSinceReferenceDate] - startTime);
    if (_lastFrameTime < 0)
    {
        _lastFrameTime = frameTime;
    }
    else
    {
        _lastFrameTime = LERP(frameTime, _lastFrameTime, 0.8);
    }
    [self.fpsLabel setText:[NSString stringWithFormat:@"fps %.0f",_lastFrameTime]];
}


- (NSString *)dealTime:(double)time {
    int tns, thh, tmm, tss;
    tns = time;
    thh = tns / 3600;
    tmm = (tns % 3600) / 60;
    tss = tns % 60;
    //        [ImageView setTransform:CGAffineTransformMakeRotation(M_PI)];
    return [NSString stringWithFormat:@"%02d:%02d:%02d",thh,tmm,tss];
}
@end
