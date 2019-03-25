//
//  AACEncoder.h
//  IJKMedia
//
//  Created by wangqiangqiang on 2018/6/27.
//  Copyright © 2018年 MOMO. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

@class AACEncoder;

@interface AACEncoder : NSObject

@property (nonatomic) BOOL addADTSHeader;
@property (nonatomic) dispatch_queue_t encoderQueue;
@property (nonatomic) NSUInteger sampleRate;
@property (nonatomic) NSUInteger channels;
@property (nonatomic) NSUInteger bitrate;

- (instancetype)initWithBitrate:(NSUInteger)bitrate sampleRate:(NSUInteger)sampleRate channels:(NSUInteger)channels;
- (NSData *)encodeSampleBuffer:(NSData*)sampleBuffer atTime:(CMTime)sampleTime isLast:(BOOL)isLast;
- (void)stopProcess:(NSError **)error;

@end

@interface SampleCacheBuf : NSObject

@end
