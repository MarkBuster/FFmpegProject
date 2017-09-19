//
//  MovieManager.m
//  FFmpegProject
//
//  Created by Dombo on 2017/9/8.
//  Copyright © 2017年 Dombo. All rights reserved.
//

#import "MovieManager.h"
#include "avcodec.h"
#include "avformat.h"
#include "swscale.h"
#include "swresample.h"

#include <SDL2/SDL.h>

#import "KxAudioManager.h"
@interface MovieManager() {
    AVFormatContext *_formatCtx;
    
    AVCodecContext *_videoCodecCtx;
    AVCodecContext *_audioCodecCtx;
    
    AVFrame *_videoFrame;
    AVFrame *_audioFrame;
    
    AVStream *_stream;
    AVPacket _packet;
    AVPicture _picture;

    NSInteger _videoStreamIndex;
    NSInteger _audioSteamIndex;
    
    NSArray *_videoStreams;
    NSArray *_audioStreams;
    
    SwrContext          *_swrContext;
    
    CGFloat             _videoTimeBase;
    CGFloat             _audioTimeBase;
    
    double _fps;
    BOOL _isReleaseResources;
}

@property (nonatomic, copy) NSString *cruutenPath;
@end

@implementation MovieManager

#pragma mark -
/* 视频路径。 */
- (instancetype)initWithVideo:(NSString *)moviePath {
    if (!(self=[super init])) return nil;
//    id<KxAudioManager> audioManager = [KxAudioManager audioManager];
//    [audioManager activateAudioSession];
    if ([self initializeResources:[moviePath UTF8String]]) {
        self.cruutenPath = [moviePath copy];
        return self;
    } else {
        return nil;
    }
}


- (BOOL)initializeResources:(const char *)filePath {
    _isReleaseResources = NO;
    AVCodec *pCodec;
    // 注册所有编码器
    avcodec_register_all();
    av_register_all();
    avformat_network_init();
    
    if (avformat_open_input(&_formatCtx, filePath, NULL, NULL) != 0) {
        NSLog(@"打开文件失败");
        goto initError;
    }
    
    if ((_videoStreamIndex =  av_find_best_stream(_formatCtx, AVMEDIA_TYPE_VIDEO, -1, -1, &pCodec, 0)) < 0) {
        NSLog(@"没有找到第一个视频流");
        goto initError;
    }

    if (avformat_find_stream_info(_formatCtx, NULL) <0) {
        NSLog(@"文件类型不支持");
        return -2;
    }
    
    for (NSInteger i = 0; i < _formatCtx->nb_streams; i ++) {
        if (_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_AUDIO)
        {
            _audioSteamIndex = i;
        }
        else if (_formatCtx->streams[i]->codec->codec_type == AVMEDIA_TYPE_VIDEO)
        {
            _videoStreamIndex = i;
        }
    }
    
    if (_audioSteamIndex == -1)
    {
        NSLog(@"not found aduio stream");
        return -3;
    }
    
    // 获取视频流的编解码上下文的指针
    _stream = _formatCtx->streams[_videoStreamIndex];
    _videoCodecCtx = _formatCtx->streams[_videoStreamIndex]->codec; //_stream->codec; //这个是被弃用的。。但是怎么用新得啊？？？
    _audioCodecCtx = _formatCtx->streams[_audioSteamIndex]->codec;
    
    if (_stream -> avg_frame_rate.den && _stream->avg_frame_rate.num)
    {
        _fps = av_q2d(_stream->avg_frame_rate);
    }
    else { _fps = 30;}
     
    pCodec = avcodec_find_decoder(_videoCodecCtx->codec_id);
    if (pCodec == NULL) {
        NSLog(@"没有找到解码器");
        goto initError;
    }
    if (avcodec_open2(_videoCodecCtx, pCodec, NULL))
    {
        NSLog(@"打开解码器失败");
        goto initError;
    }
    
    _videoFrame = av_frame_alloc();
    _outputWidth = _videoCodecCtx->width;
    _outputHeight = _videoCodecCtx->height;
    
//    AVStream *audioStream = _formatCtx->streams[_audioSteamIndex];
//    AVCodec *audioCodec = avcodec_find_decoder(_formatCtx->audio_codec_id);
//    avcodec_open2(audioStream->codec, audioCodec, NULL);
//    AVPacket packet, *pkt = &packet;
//    AVFrame *audioFrame = av_frame_alloc();
//    int gotFrame = 0;
//    
//    while (0 == av_read_frame(_formatCtx, pkt)) {
//        if (_audioSteamIndex == pkt->stream_index)
//        {
//            avcodec_decode_audio4(audioStream->codec, audioFrame, &gotFrame, pkt);
//            if (gotFrame) {
//                // 进行视频重采样
//            }
//            av_packet_unref(pkt);
//        }
//    }
    
    BOOL audio = [self openAudioStream];
    
    return YES;
initError:
    return NO;
}

- (BOOL)openAudioStream {
    _audioSteamIndex = -1;
    NSMutableArray *arr = @[].mutableCopy;
    for (NSInteger i = 0; i< _formatCtx->nb_streams; i++) {
        if (AVMEDIA_TYPE_AUDIO == _formatCtx->streams[i]->codec->codec_type)
        {
            [arr addObject:[NSNumber numberWithInteger:i]];
        }
    }
    _audioStreams = [arr copy];
    for (NSNumber *n  in _audioStreams) {
        BOOL open = [self openAudioStreamWithIndex:n.integerValue];
        NSLog(@"open == %d", open);
    }
    return YES;
}

- (BOOL)openAudioStreamWithIndex:(NSInteger)index {
    AVCodecContext *codecCtx = _formatCtx->streams[index]->codec;
    SwrContext *swrContext = NULL;
    AVCodec *codec =avcodec_find_decoder(codecCtx->codec_id);
    if (!codec) {
        return NO;
    }
    if (avcodec_open2(codecCtx, codec, NULL) <0) {
        return NO;
    }
    if (!audioCodecIsSupported(codecCtx)) {
        id <KxAudioManager>audioManager = [KxAudioManager audioManager];
        swrContext = swr_alloc_set_opts(NULL,
                                        av_get_default_channel_layout(audioManager.numOutputChannels),
                                        AV_SAMPLE_FMT_S16,
                                        audioManager.samplingRate,
                                        av_get_default_channel_layout(codecCtx->channels),
                                        codecCtx->sample_fmt,
                                        codecCtx->sample_rate,
                                        0,
                                        NULL);
        
        if (!swrContext ||
            swr_init(swrContext))
        {
            if (swrContext) {
                swr_free(&swrContext);
                avcodec_close(codecCtx);
                return NO;
            }
        }
    }
    
    _audioFrame = av_frame_alloc();
    if (!_audioFrame)
    {
        if (swrContext) {
            swr_free(&swrContext);
            avcodec_close(codecCtx);
            return NO;
        }
    }
    
    _audioSteamIndex = index;
    _audioCodecCtx = codecCtx;
    _swrContext = swrContext;
    
    AVStream *st = _formatCtx->streams[_audioSteamIndex];
    avStreamFPSTimeBase(st, 0.025, 0, &_audioTimeBase);
    // ???????????????????写不下去了
    return YES;
}

static BOOL audioCodecIsSupported(AVCodecContext *audio)
{
    if (audio->sample_fmt == AV_SAMPLE_FMT_S16)
    {
        id<KxAudioManager> audioManager = [KxAudioManager audioManager];
        return  (int)audioManager.samplingRate == audio->sample_rate &&
        audioManager.numOutputChannels == audio->channels;
    }
    return NO;
}

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1) {
        LoggerStream(0, @"WARNING: st.codec.ticks_per_frame=%d", st->codec->ticks_per_frame);
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}

- (void)seekTime:(double)seconds {
    AVRational timeBase = _formatCtx->streams[_videoStreamIndex]->time_base;
    int64_t targetFrame = (int64_t)((double)timeBase.den / timeBase.num * seconds);
    avformat_seek_file(_formatCtx,
                       _videoStreamIndex,
                       0,
                       targetFrame,
                       targetFrame,
                       AVSEEK_FLAG_FRAME);
    avcodec_flush_buffers(_videoCodecCtx);
}

- (BOOL)stepFrame {
    int frameFinished = 0;
    while (!frameFinished && av_read_frame(_formatCtx, &_packet) >= 0) {
        if (_packet.stream_index == _videoStreamIndex) {
            avcodec_decode_video2(_videoCodecCtx,
                                  _videoFrame,
                                  &frameFinished,
                                  &_packet);
        }
    }
    if (frameFinished == 0 && _isReleaseResources == NO) {
        [self releaseResources];
    }
    return frameFinished != 0;
}

- (void)redialPaly {
    [self initializeResources:[self.cruutenPath UTF8String]];
}

- (void)replaceTheResources:(NSString *)moviePath {
    if (!_isReleaseResources) {
        [self releaseResources];
    }
    self.cruutenPath = [moviePath copy];
    [self initializeResources:[moviePath UTF8String]];
}

#pragma mark - 重写属性访问方法
-(double)duration {
    return (double)_formatCtx->duration / AV_TIME_BASE;
}

- (UIImage *)currentImage {
    if (!_videoFrame->data[0]) return nil;
    return [self imageFromAVPicture];
}

- (double)fps {
    return _fps;
}
- (double)currentTime {
    AVRational timeBase = _formatCtx->streams[_videoStreamIndex]->time_base;
    return _packet.pts * (double)timeBase.num / timeBase.den;
}

#pragma mark - 内部方法
// 获取当前播放 图片帧
- (UIImage *)imageFromAVPicture {
    avpicture_free(&_picture);
    avpicture_alloc(&_picture, AV_PIX_FMT_RGB24, _outputWidth, _outputHeight);
    struct SwsContext *imgConvertCtx = sws_getContext(_videoFrame->width,
                                                      _videoFrame->height,
                                                      AV_PIX_FMT_YUV420P,
                                                      _outputWidth,
                                                      _outputHeight,
                                                      AV_PIX_FMT_RGB24,
                                                      SWS_FAST_BILINEAR,
                                                      NULL,
                                                      NULL,
                                                      NULL);
    if(imgConvertCtx == nil) return nil;
    sws_scale(imgConvertCtx,
              _videoFrame->data,
              _videoFrame->linesize,
              0,
              _videoFrame->height,
              _picture.data,
              _picture.linesize);
    sws_freeContext(imgConvertCtx);
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    CFDataRef data = CFDataCreate(kCFAllocatorDefault,
                                  _picture.data[0],
                                  _picture.linesize[0] * _outputHeight);
    
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef cgImage = CGImageCreate(_outputWidth,
                                       _outputHeight,
                                       8,
                                       24,
                                       _picture.linesize[0],
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    CFRelease(data);
    return image;
}


#pragma mark - 释放资源
- (void)releaseResources {
    NSLog(@"释放资源");
    //    SJLogFunc
    _isReleaseResources = YES;
    // 释放RGB
    avpicture_free(&_picture);
    // 释放frame
    av_packet_unref(&_packet);
    // 释放YUV frame
    av_free(_videoFrame);
    // 关闭解码器
    if (_videoCodecCtx) avcodec_close(_videoCodecCtx);
    // 关闭文件
    if (_videoCodecCtx) avformat_close_input(&_formatCtx);
    avformat_network_deinit();
}
@end
