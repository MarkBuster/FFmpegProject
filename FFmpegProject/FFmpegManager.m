//
//  FFmpegManager.m
//  FFmpegProject
//
//  Created by Dombo on 2017/9/15.
//  Copyright © 2017年 Dombo. All rights reserved.
//

#import "FFmpegManager.h"
#include "avcodec.h"
#include "avformat.h"
#include "swscale.h"
#include "swresample.h"

@interface FFmpegManager()
{
    AVFormatContext *_pFormatCtx;
    int  _i,_videoIndex;
    AVCodecContext *_pCodecCtx;
    AVCodec *_pCodec;
    AVFrame *_pFrame,*_pFrameYUV;
    uint8_t *_out_buffer;
    AVPacket *_packet;
    
    
}
@end

@implementation FFmpegManager

- (instancetype)initWithVideo:(NSString *)moviePath {
    if (self = [super init]) {
        
        [self initializeResources:[moviePath UTF8String]];
    }
    return self;
}

- (BOOL)initializeResources:(const char *)filePath {
    
    av_register_all();
    avformat_network_init();
    _pFormatCtx = avformat_alloc_context();
    
    if (avformat_open_input(&_pFormatCtx, filePath, NULL, NULL) != 0)
    {
        NSLog(@"couldn't open input stream \n");
        return NO;
    }

    if (avformat_find_stream_info(_pFormatCtx, NULL) <0) {
        NSLog(@"couldn't find stream information. \n");
        return NO;
    }
    
//    ==================================================
    _videoIndex = -1;
//    总个数是 nb_streams
    for (int i = 0; i<_pFormatCtx->nb_streams; i++) {
        if (_pFormatCtx->streams[i]->codec->codec_type==AVMEDIA_TYPE_VIDEO) {
            _videoIndex = i;
            break;
        }
    }
    
    if (_videoIndex == -1) {
        NSLog(@"Didnt fing a video stream \n");
        return NO;
    }
    
    _pCodecCtx = _pFormatCtx->streams[0]->codec;
    AVCodec * pCodec = avcodec_find_decoder(_pCodecCtx->codec_id);
    if (pCodec == NULL)
    {
        NSLog(@"codec not found . \n");
        return NO;
    }
    
//     ======================打开解码器============================
    if (avcodec_open2(_pCodecCtx, pCodec, NULL) < 0)
    {
        NSLog(@"Could not open codec . \n");
        return NO;
    }
    
//    _pFormatCtx->duration  单位为微妙     / 10^6   转换成秒
    NSLog(@"时长：%lld",_pFormatCtx->duration);
    NSLog(@"封装格式 %s",_pFormatCtx->iformat->long_name);
//
    NSLog(@"宽度 ： %d",_pFormatCtx->streams[0]->codec->width);
    NSLog(@"高度 ： %d",_pFormatCtx->streams[0]->codec->height);
    
    FILE *fp= fopen("info.txt", "wb+");//文件打开； wb 可读可写的权限
    fclose(fp);
    return YES;
}
@end
