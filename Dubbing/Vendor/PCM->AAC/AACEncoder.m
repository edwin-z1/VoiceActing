//
//  AACEncoder.m
//  IJKMedia
//
//  Created by wangqiangqiang on 2018/6/27.
//  Copyright © 2018年 MOMO. All rights reserved.
//

#import "AACEncoder.h"
#import <libkern/OSAtomic.h>
#import <AudioToolbox/AudioToolbox.h>

@interface AACEncoder()
@property (nonatomic) AudioConverterRef audioConverter;
@property (nonatomic) uint8_t *aacBuffer;
@property (nonatomic) NSUInteger aacBufferSize;
@property (nonatomic) char *pcmBuffer;
@property (nonatomic) size_t pcmBufferSize;
@property (nonatomic, strong) NSMutableArray* cacheArray;

@property (nonatomic) size_t total_len;

@end

@interface SampleCacheBuf()

@property (nonatomic) size_t bufLen;
@property (nonatomic) uint32_t offset;
@property (nonatomic) CMTime pts;
@property (nonatomic) uint8_t * data;

@end
@implementation SampleCacheBuf
@end

@implementation AACEncoder

- (void)dealloc {
    _encoderQueue = nil;
    AudioConverterDispose(_audioConverter);
    if (_pcmBuffer != nil) {
        free(_pcmBuffer);
        _pcmBuffer = nil;
    }
    if (_aacBuffer != nil) {
        free(_aacBuffer);
        _aacBuffer = nil;
    }
}

- (instancetype)initWithBitrate:(NSUInteger)bitrate sampleRate:(NSUInteger)sampleRate channels:(NSUInteger)channels
{
    if (self = [super init]) {
        self.encoderQueue = dispatch_queue_create("AAC.Encoder.Queue", DISPATCH_QUEUE_SERIAL);
        self.sampleRate = sampleRate;
        self.channels = channels;
        self.bitrate = bitrate;
        _audioConverter = NULL;
        
        self.cacheArray = [NSMutableArray array];
        _aacBufferSize = 1024;
        _addADTSHeader = YES;
        _aacBuffer = malloc(_aacBufferSize * sizeof(uint8_t));
        memset(_aacBuffer, 0, _aacBufferSize);
        _pcmBufferSize = self.channels * _aacBufferSize * sizeof(UInt16);
        _pcmBuffer = malloc(_pcmBufferSize);
        memset(_pcmBuffer, 0, _pcmBufferSize);
        return self;
        
    }
    return nil;
}

- (void)setupAACEncoder
{
    AudioStreamBasicDescription inAudioStreamBasicDescription= {0};
    inAudioStreamBasicDescription.mSampleRate = self.sampleRate;
    inAudioStreamBasicDescription.mFormatID = kAudioFormatLinearPCM;
    inAudioStreamBasicDescription.mFormatFlags = kLinearPCMFormatFlagIsPacked | kLinearPCMFormatFlagIsSignedInteger;//12;
    inAudioStreamBasicDescription.mChannelsPerFrame = (UInt32)self.channels;
    inAudioStreamBasicDescription.mBitsPerChannel = 16;
    inAudioStreamBasicDescription.mBytesPerFrame = (inAudioStreamBasicDescription.mBitsPerChannel / 8) *  inAudioStreamBasicDescription.mChannelsPerFrame;
    inAudioStreamBasicDescription.mFramesPerPacket = 1;
    inAudioStreamBasicDescription.mBytesPerPacket = inAudioStreamBasicDescription.mBytesPerFrame * inAudioStreamBasicDescription.mFramesPerPacket;
    
//    NSLog(@"inAudioStreamBasicDescription.mSampleRate:%f", inAudioStreamBasicDescription.mSampleRate);
//    NSLog(@"inAudioStreamBasicDescription.mFormatID:%u", inAudioStreamBasicDescription.mFormatID);
//    NSLog(@"inAudioStreamBasicDescription.mFormatFlags:%u", inAudioStreamBasicDescription.mFormatFlags);
//    NSLog(@"inAudioStreamBasicDescription.mBytesPerPacket:%u", inAudioStreamBasicDescription.mBytesPerPacket);
//    NSLog(@"inAudioStreamBasicDescription.mFramesPerPacket:%u", inAudioStreamBasicDescription.mFramesPerPacket);
//    NSLog(@"inAudioStreamBasicDescription.mBytesPerFrame:%u", inAudioStreamBasicDescription.mBytesPerFrame);
//    NSLog(@"inAudioStreamBasicDescription.mChannelsPerFrame:%u", inAudioStreamBasicDescription.mChannelsPerFrame);
//    NSLog(@"inAudioStreamBasicDescription.mBitsPerChannel:%u", inAudioStreamBasicDescription.mBitsPerChannel);
//    NSLog(@"inAudioStreamBasicDescription.mReserved:%u", inAudioStreamBasicDescription.mReserved);
    AudioStreamBasicDescription outAudioStreamBasicDescription = {0}; // Always initialize the fields of a new audio stream basic description structure to zero, as shown here: ...
    
    // The number of frames per second of the data in the stream, when the stream is played at normal speed. For compressed formats, this field indicates the number of frames per second of equivalent decompressed data. The mSampleRate field must be nonzero, except when this structure is used in a listing of supported formats (see “kAudioStreamAnyRate”).
    if (self.sampleRate != 0) {
        outAudioStreamBasicDescription.mSampleRate = self.sampleRate;
    } else {
        outAudioStreamBasicDescription.mSampleRate = inAudioStreamBasicDescription.mSampleRate;
        
    }
    outAudioStreamBasicDescription.mFormatID = kAudioFormatMPEG4AAC; // kAudioFormatMPEG4AAC_HE does not work. Can't find `AudioClassDescription`. `mFormatFlags` is set to 0.
    outAudioStreamBasicDescription.mFormatFlags = kMPEG4Object_AAC_LC; // Format-specific flags to specify details of the format. Set to 0 to indicate no format flags. See “Audio Data Format Identifiers” for the flags that apply to each format.
    outAudioStreamBasicDescription.mBytesPerPacket = 0; // The number of bytes in a packet of audio data. To indicate variable packet size, set this field to 0. For a format that uses variable packet size, specify the size of each packet using an AudioStreamPacketDescription structure.
    outAudioStreamBasicDescription.mFramesPerPacket = 1024; // The number of frames in a packet of audio data. For uncompressed audio, the value is 1. For variable bit-rate formats, the value is a larger fixed number, such as 1024 for AAC. For formats with a variable number of frames per packet, such as Ogg Vorbis, set this field to 0.
    outAudioStreamBasicDescription.mBytesPerFrame = 0; // The number of bytes from the start of one frame to the start of the next frame in an audio buffer. Set this field to 0 for compressed formats. ...
    
    // The number of channels in each frame of audio data. This value must be nonzero.
    if (self.channels == 0) {
        outAudioStreamBasicDescription.mChannelsPerFrame = inAudioStreamBasicDescription.mChannelsPerFrame;
    } else {
        outAudioStreamBasicDescription.mChannelsPerFrame = (uint32_t)self.channels;
    }
    
    outAudioStreamBasicDescription.mBitsPerChannel = 0; // ... Set this field to 0 for compressed formats.
    outAudioStreamBasicDescription.mReserved = 0; // Pads the structure out to force an even 8-byte alignment. Must be set to 0.
    AudioClassDescription *description = [self
                                          getAudioClassDescriptionWithType:kAudioFormatMPEG4AAC
                                          fromManufacturer:kAppleSoftwareAudioCodecManufacturer];
    
    OSStatus status = AudioConverterNewSpecific(&inAudioStreamBasicDescription, &outAudioStreamBasicDescription, 1, description, &_audioConverter);
    if (status != 0) {
        NSLog(@"setup converter: %d", (int)status);
    }
    
    if (self.bitrate != 0) {
        UInt32 ulBitRate = (UInt32)self.bitrate;
        UInt32 ulSize = sizeof(ulBitRate);
        AudioConverterSetProperty(_audioConverter, kAudioConverterEncodeBitRate, ulSize, & ulBitRate);
    }
}

- (AudioClassDescription *)getAudioClassDescriptionWithType:(UInt32)type
                                           fromManufacturer:(UInt32)manufacturer
{
    static AudioClassDescription desc;
    
    UInt32 encoderSpecifier = type;
    OSStatus st;
    
    UInt32 size;
    st = AudioFormatGetPropertyInfo(kAudioFormatProperty_Encoders,
                                    sizeof(encoderSpecifier),
                                    &encoderSpecifier,
                                    &size);
    if (st) {
        NSLog(@"error getting audio format propery info: %d", (int)(st));
        return nil;
    }
    
    unsigned int count = size / sizeof(AudioClassDescription);
    AudioClassDescription descriptions[count];
    st = AudioFormatGetProperty(kAudioFormatProperty_Encoders,
                                sizeof(encoderSpecifier),
                                &encoderSpecifier,
                                &size,
                                descriptions);
    if (st) {
        NSLog(@"error getting audio format propery: %d", (int)(st));
        return nil;
    }
    
    for (unsigned int i = 0; i < count; i++) {
        if ((type == descriptions[i].mSubType) &&
            (manufacturer == descriptions[i].mManufacturer)) {
            memcpy(&desc, &(descriptions[i]), sizeof(desc));
            return &desc;
        }
    }
    
    return nil;
}

static OSStatus inInputDataProc(AudioConverterRef inAudioConverter, UInt32 *ioNumberDataPackets, AudioBufferList *ioData, AudioStreamPacketDescription **outDataPacketDescription, void *inUserData)
{
    AACEncoder *encoder = (__bridge AACEncoder *)(inUserData);
    UInt32 requestedPackets = *ioNumberDataPackets;
//    NSLog(@"Number of packets requested: %d", (unsigned int)requestedPackets);
    size_t copiedSamples = [encoder copyPCMSamplesIntoBuffer:ioData];
    if (copiedSamples < requestedPackets) {
        NSLog(@"PCM buffer isn't full enough!");
//        *ioNumberDataPackets = 0;
//        return -1;
    }
    *ioNumberDataPackets = 1;
//    NSLog(@"Copied %zu samples into ioData", copiedSamples);
    return noErr;
}

- (size_t)copyPCMSamplesIntoBuffer:(AudioBufferList*)ioData {
    size_t originalBufferSize = _pcmBufferSize;
    if (!originalBufferSize) {
        return 0;
    }
    
    ioData->mBuffers[0].mData = _pcmBuffer;
    ioData->mBuffers[0].mDataByteSize = (uint32_t)_pcmBufferSize;
    
    //    _pcmBuffer = NULL;
    //    _pcmBufferSize = 0;
    return originalBufferSize;
}

- (void)processSampleBuffer:(NSData*)sampleBuffer atTime:(CMTime)pts
{
    if (!_audioConverter) {
        [self setupAACEncoder];
    }
    
    if ([sampleBuffer length] == 0) {
        return ;
    }

    char * sampleData = (char*)[sampleBuffer bytes];
    size_t sampleSize = sampleBuffer.length;

    SampleCacheBuf * cacheBuf = [[SampleCacheBuf alloc] init];
    cacheBuf.bufLen = sampleSize;
    cacheBuf.data = malloc(cacheBuf.bufLen);
    memset(cacheBuf.data, 0, cacheBuf.bufLen);
    memcpy(cacheBuf.data, sampleData, cacheBuf.bufLen);
    cacheBuf.offset = 0;
    cacheBuf.pts = pts;
    [self.cacheArray addObject:cacheBuf];
}

- (BOOL)checkCacheAvaliable
{
    if (self.cacheArray.count <= 0) {
        return NO;
    }
    int totalLen = 0;
    int count = (int)self.cacheArray.count;
    for (int i = 0; i < count; i++) {
        SampleCacheBuf * buf = [self.cacheArray objectAtIndex:i];
        totalLen += (buf.bufLen - buf.offset);
        if (totalLen >= _pcmBufferSize) {
            return YES;
        }
    }
    return NO;
}

- (CMTime)generatePCMData:(BOOL)isLast
{
    int copyOffset = 0;
    SampleCacheBuf *buf = self.cacheArray.firstObject;
    CMTime pts = buf.pts;
    memset(_pcmBuffer, 0, _pcmBufferSize);
    while(self.cacheArray.count > 0){
        
        buf = self.cacheArray.firstObject;
        if (copyOffset + (buf.bufLen - buf.offset) <= _pcmBufferSize) {
            memcpy(_pcmBuffer + copyOffset, buf.data + buf.offset, buf.bufLen - buf.offset);
            [self.cacheArray removeObjectAtIndex:0];
            copyOffset += (buf.bufLen - buf.offset);
            self.total_len += (buf.bufLen - buf.offset);
            free(buf.data);
            if (copyOffset == _pcmBufferSize) {
                break;
            }
//            if (isLast && self.cacheArray.count == 0) {
//                NSLog(@"last pcm size %d", copyOffset);
//            }
        } else {
            memcpy(_pcmBuffer + copyOffset, buf.data + buf.offset, _pcmBufferSize - copyOffset);
            buf.offset += ((int)_pcmBufferSize - copyOffset);
            self.total_len += ((int)_pcmBufferSize - copyOffset);
            copyOffset += (int)_pcmBufferSize;
            break;
        }
    }

    return pts;
}

- (NSData *)encodeSampleBuffer:(NSData*)sampleBuffer atTime:(CMTime)sampleTime isLast:(BOOL)isLast {
    [self processSampleBuffer:sampleBuffer atTime:sampleTime];
    NSMutableData *fullEncodedData = [NSMutableData data];
    while ([self checkCacheAvaliable] ||
           isLast) {
        [self generatePCMData:isLast];
        NSError *error = nil;
        memset(_aacBuffer, 0, _aacBufferSize);
        AudioBufferList outAudioBufferList = {0};
        outAudioBufferList.mNumberBuffers = 1;
        outAudioBufferList.mBuffers[0].mNumberChannels = (int)_channels;
        outAudioBufferList.mBuffers[0].mDataByteSize = (int)_aacBufferSize;
        outAudioBufferList.mBuffers[0].mData = _aacBuffer;
        AudioStreamPacketDescription *outPacketDescription = NULL;
        UInt32 ioOutputDataPacketSize = 1;
        OSStatus status = AudioConverterFillComplexBuffer(_audioConverter, inInputDataProc, (__bridge void *)(self), &ioOutputDataPacketSize, &outAudioBufferList, outPacketDescription);
        
        NSData *data = nil;
        if (status == 0) {
            NSData *rawAAC = [NSData dataWithBytes:outAudioBufferList.mBuffers[0].mData length:outAudioBufferList.mBuffers[0].mDataByteSize];
            if (_addADTSHeader) {
                NSData *adtsHeader = [self adtsDataForPacketLength:rawAAC.length];
                NSMutableData *fullData = [NSMutableData dataWithData:adtsHeader];
                [fullData appendData:rawAAC];
                data = fullData;
            } else {
                data = rawAAC;
            }
        } else {
            error = [NSError errorWithDomain:NSOSStatusErrorDomain code:status userInfo:nil];
        }
        [fullEncodedData appendData:data];
        if (isLast)
            break;
    }
    return fullEncodedData;
}


/**
 *  Add ADTS header at the beginning of each and every AAC packet.
 *  This is needed as MediaCodec encoder generates a packet of raw
 *  AAC data.
 *6tt
 *  Note the packetLen must count in the ADTS header itself.
 *  See: http://wiki.multimedia.cx/index.php?title=ADTS
 *  Also: http://wiki.multimedia.cx/index.php?title=MPEG-4_Audiso#Channel_Configurations
 **/
- (NSData*)adtsDataForPacketLength:(NSUInteger)packetLength
{
    int adtsLength = 7;
    char *packet = malloc(sizeof(char) * adtsLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = 1;//(int)self.channels;  //MPEG-4 Audio Channel Configuration. 1 Channel front-center
    NSUInteger fullLength = adtsLength + packetLength;
    // fill in ADTS data
    packet[0] = (char)0xFF;    // 11111111      = syncword
    packet[1] = (char)0xF1;    // 1111 1 00 1  = syncword MPEG-2 Layer CRC
    packet[2] = (char)(((profile-1)<<6) + (freqIdx<<2) +(chanCfg>>2));
    packet[3] = (char)(((chanCfg&3)<<6) + (fullLength>>11));
    packet[4] = (char)((fullLength&0x7FF) >> 3);
    packet[5] = (char)(((fullLength&7)<<5) + 0x1F);
    packet[6] = (char)0xFC;
    NSData *data = [NSData dataWithBytesNoCopy:packet length:adtsLength freeWhenDone:YES];
    return data;
}

- (NSData*)latmDataForStream
{
    int latmLength = 2;
    char *packet = malloc(sizeof(char) * latmLength);
    // Variables Recycled by addADTStoPacket
    int profile = 2;  //AAC LC
    //39=MediaCodecInfo.CodecProfileLevel.AACObjectELD;
    int freqIdx = 4;  //44.1KHz
    int chanCfg = (int)self.channels ;
    // fill in ADTS data
    packet[0] = (char)((profile << 3)+((freqIdx & 0xF)>>1));
    packet[1] = (char)(((freqIdx<<7)& 0xF0) + (chanCfg <<3 ));
    NSData *data = [NSData dataWithBytesNoCopy:packet length:latmLength freeWhenDone:YES];
    return data;
}

- (void)stopProcess:(NSError**)error
{
    if (_encoderQueue) {
        _encoderQueue = nil;
    }
}

@end
