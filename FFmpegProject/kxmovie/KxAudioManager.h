//
//  KxAudioManager.h
//  kxmovie
//
//  Created by Kolyvan on 23.10.12.
//  Copyright (c) 2012 Konstantin Boukreev . All rights reserved.
//
//  https://github.com/kolyvan/kxmovie
//  this file is part of KxMovie
//  KxMovie is licenced under the LGPL v3, see lgpl-3.0.txt


#import <CoreFoundation/CoreFoundation.h>
/*
 float *data  :分配一个float大小的内存空间
 UInt32 numFrames : 帧的数量
 UInt32 numChannels: 通道中每一帧的数据
 */
typedef void (^KxAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@protocol KxAudioManager <NSObject>

@property (readonly) UInt32             numOutputChannels; //通道中每一帧的数据
@property (readonly) Float64            samplingRate; // 音频采样率
@property (readonly) UInt32             numBytesPerSample;
@property (readonly) Float32            outputVolume;// 输出音量
@property (readonly) BOOL               playing; // 是否在播放
@property (readonly, strong) NSString   *audioRoute; // 音频波段

@property (readwrite, copy) KxAudioManagerOutputBlock outputBlock;

- (BOOL) activateAudioSession; // 音频会话是否启动
- (void) deactivateAudioSession; // 终止音频会话
- (BOOL) play; // 播放
- (void) pause; // 暂停

@end

@interface KxAudioManager : NSObject
+ (id<KxAudioManager>) audioManager;
@end
