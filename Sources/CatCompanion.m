#import "CatCompanion.h"
#import <math.h>

static const NSUInteger CatColumns=4,CatRows=3,CatFrameCount=12;
static const unsigned char CatVisibleAlpha=8;

@interface CatAtlas : NSObject
@property(nonatomic, copy) NSArray<NSImage *> *frames;
@property(nonatomic, copy) NSDictionary *summary;
@end
@implementation CatAtlas
@end

// All frame selection, including preview/test paths, uses the same cycle.
static NSTimeInterval CatFrameInterval(BOOL moving,BOOL running) {
    return !moving?.45:(running?.085:.14);
}
static NSUInteger CatFrameIndex(BOOL moving,BOOL running,NSTimeInterval time) {
    NSTimeInterval interval=CatFrameInterval(moving,running);
    double phase=isfinite(time)?fmod(fabs(time),interval*CatColumns):0;
    NSUInteger column=MIN(CatColumns-1,(NSUInteger)floor(phase/interval));
    return (!moving?0:(running?8:4))+column;
}

// Drawing into a canonical premultiplied RGBA buffer makes alpha scanning
// independent of the PNG encoder's channel order or color-space representation.
static NSData *CatRGBA(CGImageRef image) {
    size_t width=CGImageGetWidth(image),height=CGImageGetHeight(image);
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,width,height,8,width*4,colorSpace,
                                              kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) return nil;
    CGContextDrawImage(context,CGRectMake(0,0,width,height),image);
    CGContextRelease(context);
    return pixels;
}
static NSImage *CatImageFromRGBA(NSData *pixels,NSUInteger width,NSUInteger height) {
    CGDataProviderRef provider=CGDataProviderCreateWithCFData((__bridge CFDataRef)pixels);
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CGImageRef image=CGImageCreate(width,height,8,32,width*4,colorSpace,
                                  kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big,
                                  provider,NULL,NO,kCGRenderingIntentDefault);
    NSImage *result=image?[[NSImage alloc] initWithCGImage:image size:NSMakeSize(width,height)]:nil;
    if (image) CGImageRelease(image);
    CGColorSpaceRelease(colorSpace);CGDataProviderRelease(provider);
    return result;
}
// Generated atlases retain a visual grid but may have unequal gutters. Choose
// cuts through a fully transparent gutter instead of assuming equal cell sizes.
static NSArray<NSNumber *> *CatAtlasCuts(NSData *pixels,NSUInteger width,NSUInteger height,
                                         BOOL horizontalAxis,NSUInteger divisions,NSUInteger *clearCuts) {
    NSUInteger length=horizontalAxis?width:height;
    NSMutableData *projection=[NSMutableData dataWithLength:length];
    unsigned char *occupied=projection.mutableBytes;const unsigned char *bytes=pixels.bytes;
    for(NSUInteger y=0;y<height;y++) for(NSUInteger x=0;x<width;x++) {
        if(bytes[(y*width+x)*4+3]>CatVisibleAlpha) occupied[horizontalAxis?x:y]=1;
    }
    NSMutableArray<NSNumber *> *cuts=[NSMutableArray arrayWithObject:@0];
    for(NSUInteger index=1;index<divisions;index++) {
        NSUInteger nominal=index*length/divisions,radius=(NSUInteger)ceil(length*.07);
        NSUInteger low=nominal>radius?nominal-radius:1,high=MIN(length-1,nominal+radius+1);
        NSUInteger best=nominal,bestLength=0;double bestDistance=HUGE_VAL;
        for(NSUInteger position=low;position<high;) {
            if(occupied[position]) { position++;continue; }
            NSUInteger beginning=position;
            while(position<high&&!occupied[position]) position++;
            NSUInteger span=position-beginning,midpoint=beginning+(span-1)/2;
            double distance=fabs((double)midpoint-nominal);
            if(span>bestLength||(span==bestLength&&distance<bestDistance)) {
                best=midpoint;bestLength=span;bestDistance=distance;
            }
        }
        if(bestLength>0&&!occupied[best]) (*clearCuts)++;
        [cuts addObject:@(best)];
    }
    [cuts addObject:@(length)];return cuts;
}
static CatAtlas *CatCompanionAtlas(void) {
    static CatAtlas *loaded;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        loaded=[CatAtlas new];loaded.frames=@[];
        loaded.summary=@{@"available":@NO,@"frameCount":@0,@"columns":@(CatColumns),@"rows":@(CatRows)};
        NSURL *url=[NSBundle.mainBundle URLForResource:@"calico-cat-atlas" withExtension:@"png"];
        NSData *data=url?[NSData dataWithContentsOfURL:url]:nil;
        NSBitmapImageRep *bitmap=data?[[NSBitmapImageRep alloc] initWithData:data]:nil;
        CGImageRef atlas=bitmap.CGImage;
        if(!atlas) return;
        NSUInteger atlasWidth=CGImageGetWidth(atlas),atlasHeight=CGImageGetHeight(atlas);
        if(atlasWidth<CatColumns||atlasHeight<CatRows) return;
        NSData *atlasPixels=CatRGBA(atlas);if(!atlasPixels) return;
        const unsigned char *source=atlasPixels.bytes;
        NSUInteger clearCuts=0;
        NSArray<NSNumber *> *columnCuts=CatAtlasCuts(atlasPixels,atlasWidth,atlasHeight,YES,CatColumns,&clearCuts);
        NSArray<NSNumber *> *rowCuts=CatAtlasCuts(atlasPixels,atlasWidth,atlasHeight,NO,CatRows,&clearCuts);
        NSMutableArray<NSValue *> *contentRects=[NSMutableArray new];
        NSMutableArray<NSDictionary *> *contentSummary=[NSMutableArray new];
        NSUInteger nonempty=0,sourceMargins=0,maxWidth=0,maxHeight=0;
        for(NSUInteger row=0;row<CatRows;row++) for(NSUInteger column=0;column<CatColumns;column++) {
            NSUInteger left=columnCuts[column].unsignedIntegerValue,right=columnCuts[column+1].unsignedIntegerValue;
            NSUInteger top=rowCuts[row].unsignedIntegerValue,bottom=rowCuts[row+1].unsignedIntegerValue;
            NSUInteger minX=right,minY=bottom,maxX=left,maxY=top,count=0;
            for(NSUInteger y=top;y<bottom;y++) for(NSUInteger x=left;x<right;x++) {
                if(source[(y*atlasWidth+x)*4+3]<=CatVisibleAlpha) continue;
                minX=MIN(minX,x);minY=MIN(minY,y);maxX=MAX(maxX,x);maxY=MAX(maxY,y);count++;
            }
            if(!count) { [contentRects addObject:[NSValue valueWithRect:NSZeroRect]];continue; }
            nonempty++;NSUInteger width=maxX-minX+1,height=maxY-minY+1;
            if(minX>left&&minY>top&&maxX+1<right&&maxY+1<bottom) sourceMargins++;
            maxWidth=MAX(maxWidth,width);maxHeight=MAX(maxHeight,height);
            [contentRects addObject:[NSValue valueWithRect:NSMakeRect(minX,minY,width,height)]];
            [contentSummary addObject:@{@"x":@(minX),@"y":@(minY),@"width":@(width),@"height":@(height)}];
        }
        if(nonempty!=CatFrameCount||maxWidth==0||maxHeight==0) {
            loaded.summary=@{@"available":@NO,@"frameCount":@0,@"nonemptyFrameCount":@(nonempty),
                             @"atlasWidth":@(atlasWidth),@"atlasHeight":@(atlasHeight),
                             @"columnCuts":columnCuts,@"rowCuts":rowCuts,@"transparentInternalCutCount":@(clearCuts)};
            return;
        }
        // Trim each region without scaling. All poses then share one pixel scale,
        // one canvas, horizontal center and a common bottom baseline.
        NSUInteger padding=MAX(2,(NSUInteger)ceil(MAX(maxWidth,maxHeight)*.025));
        NSUInteger canvasWidth=maxWidth+padding*2,canvasHeight=maxHeight+padding*2;
        NSMutableArray<NSImage *> *frames=[NSMutableArray arrayWithCapacity:CatFrameCount];
        NSUInteger normalizedMargins=0,alignedBaselines=0;
        for(NSValue *value in contentRects) {
            NSRect rect=value.rectValue;
            NSUInteger left=(NSUInteger)rect.origin.x,top=(NSUInteger)rect.origin.y;
            NSUInteger width=(NSUInteger)rect.size.width,height=(NSUInteger)rect.size.height;
            NSUInteger targetX=(canvasWidth-width)/2,targetY=canvasHeight-padding-height;
            NSMutableData *normalized=[NSMutableData dataWithLength:canvasWidth*canvasHeight*4];
            unsigned char *target=normalized.mutableBytes;
            for(NSUInteger y=0;y<height;y++) {
                memcpy(target+((targetY+y)*canvasWidth+targetX)*4,source+((top+y)*atlasWidth+left)*4,width*4);
            }
            // Verify the actual normalized alpha, not just the computed offsets.
            NSUInteger minX=canvasWidth,minY=canvasHeight,maxX=0,maxY=0,count=0;
            for(NSUInteger y=0;y<canvasHeight;y++) for(NSUInteger x=0;x<canvasWidth;x++) {
                if(target[(y*canvasWidth+x)*4+3]<=CatVisibleAlpha) continue;
                minX=MIN(minX,x);minY=MIN(minY,y);maxX=MAX(maxX,x);maxY=MAX(maxY,y);count++;
            }
            if(count&&minX>=padding&&minY>=padding&&maxX+padding<canvasWidth&&maxY+padding<canvasHeight) normalizedMargins++;
            if(count&&maxY==canvasHeight-padding-1) alignedBaselines++;
            NSImage *image=CatImageFromRGBA(normalized,canvasWidth,canvasHeight);if(!image) return;
            [frames addObject:image];
        }
        loaded.frames=frames;
        loaded.summary=@{@"available":@YES,@"frameCount":@(frames.count),@"columns":@(CatColumns),@"rows":@(CatRows),
                         @"atlasWidth":@(atlasWidth),@"atlasHeight":@(atlasHeight),
                         @"columnCuts":columnCuts,@"rowCuts":rowCuts,@"transparentInternalCutCount":@(clearCuts),
                         @"cropWidth":@(canvasWidth),@"cropHeight":@(canvasHeight),@"paddingPixels":@(padding),
                         @"nonemptyFrameCount":@(nonempty),@"sourceMarginFrameCount":@(sourceMargins),
                         @"alphaMarginFrameCount":@(normalizedMargins),@"baselineAlignedFrameCount":@(alignedBaselines),
                         @"sourceVisibleBounds":contentSummary,@"normalization":@"same-pixel-scale-center-and-baseline"};
    });
    return loaded;
}

static NSData *CatRenderForTest(NSInteger facing,NSRect rect,NSUInteger width,NSUInteger height) {
    NSMutableData *pixels=[NSMutableData dataWithLength:width*height*4];
    CGColorSpaceRef colorSpace=CGColorSpaceCreateDeviceRGB();
    CGContextRef context=CGBitmapContextCreate(pixels.mutableBytes,width,height,8,width*4,colorSpace,
                                              kCGImageAlphaPremultipliedLast|kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(colorSpace);
    if (!context) return nil;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext=[NSGraphicsContext graphicsContextWithCGContext:context flipped:NO];
    [CatCompanion drawInRect:rect facing:facing moving:YES running:YES time:.1];
    [NSGraphicsContext restoreGraphicsState];
    CGContextRelease(context);
    return pixels;
}

@implementation CatCompanion
+ (BOOL)isAvailable { return CatCompanionAtlas().frames.count==CatFrameCount; }
+ (NSDictionary *)assetSummary { return CatCompanionAtlas().summary; }
+ (void)drawInRect:(NSRect)rect facing:(NSInteger)facing moving:(BOOL)moving running:(BOOL)running time:(NSTimeInterval)time {
    NSArray<NSImage *> *frames=CatCompanionAtlas().frames;
    if (frames.count!=CatFrameCount||!isfinite(NSMinX(rect))||!isfinite(NSMinY(rect))||
        !isfinite(NSWidth(rect))||!isfinite(NSHeight(rect))||NSWidth(rect)<=0||NSHeight(rect)<=0) return;
    NSImage *image=frames[CatFrameIndex(moving,running,time)];
    CGFloat fit=MIN(NSWidth(rect)/image.size.width,NSHeight(rect)/image.size.height);
    CGFloat width=image.size.width*fit,height=image.size.height*fit;
    [NSGraphicsContext saveGraphicsState];
    NSGraphicsContext.currentContext.imageInterpolation=NSImageInterpolationHigh;
    NSGraphicsContext.currentContext.shouldAntialias=YES;
    NSAffineTransform *transform=[NSAffineTransform transform];
    [transform translateXBy:NSMidX(rect) yBy:NSMidY(rect)];
    if (facing<0) [transform scaleXBy:-1 yBy:1];
    [transform concat];
    [image drawInRect:NSMakeRect(-width*.5,-height*.5,width,height) fromRect:NSZeroRect
             operation:NSCompositingOperationSourceOver fraction:1 respectFlipped:YES
                 hints:@{NSImageHintInterpolation:@(NSImageInterpolationHigh)}];
    [NSGraphicsContext restoreGraphicsState];
}
+ (NSDictionary *)runAssetTests {
    NSMutableArray *passed=[NSMutableArray new],*failed=[NSMutableArray new];
    void (^check)(BOOL,NSString *)=^(BOOL ok,NSString *name){[(ok?passed:failed) addObject:name];};
    CatAtlas *atlas=CatCompanionAtlas();NSDictionary *summary=atlas.summary;
    check(atlas.frames.count==CatFrameCount&&[summary[@"nonemptyFrameCount"] unsignedIntegerValue]==CatFrameCount,@"all-twelve-calico-frames-load-and-contain-visible-pixels");
    check([summary[@"transparentInternalCutCount"] unsignedIntegerValue]==CatColumns+CatRows-2,@"all-internal-atlas-cuts-pass-through-fully-transparent-gutters");
    check([summary[@"alphaMarginFrameCount"] unsignedIntegerValue]==CatFrameCount,@"all-normalized-frames-have-transparent-outer-margins");
    check([summary[@"baselineAlignedFrameCount"] unsignedIntegerValue]==CatFrameCount,@"all-twelve-poses-share-one-bottom-baseline-without-rescaling");
    BOOL sameSize=atlas.frames.count==CatFrameCount;
    for(NSImage *frame in atlas.frames) sameSize &= NSEqualSizes(frame.size,atlas.frames.firstObject.size);
    check(sameSize,@"one-common-canvas-keeps-every-pose-at-identical-pixel-scale");
    BOOL cycles=YES;
    for(NSUInteger mode=0;mode<3;mode++) {
        BOOL moving=mode>0,running=mode==2;double interval=CatFrameInterval(moving,running);
        for(NSUInteger column=0;column<4;column++) {
            double t=(column+.25)*interval;
            cycles &= CatFrameIndex(moving,running,t)==mode*4+column&&CatFrameIndex(moving,running,t+interval*4)==mode*4+column;
        }
    }
    check(cycles,@"idle-walk-and-run-each-cycle-through-four-own-row-frames");
    check(CatFrameIndex(NO,YES,NAN)==0&&CatFrameIndex(YES,YES,INFINITY)==8&&CatFrameIndex(YES,NO,-.01)<8,@"invalid-and-negative-time-always-select-a-valid-frame");
    NSData *right=CatRenderForTest(1,NSMakeRect(0,0,152,104),152,104),*left=CatRenderForTest(-1,NSMakeRect(0,0,152,104),152,104);
    BOOL mirrors=right.length>0&&left.length==right.length;double difference=0,alpha=0;
    const unsigned char *r=right.bytes,*l=left.bytes;
    if (mirrors) for(NSUInteger y=0;y<104;y++) for(NSUInteger x=0;x<152;x++) {
        NSUInteger a=(y*152+x)*4,b=(y*152+151-x)*4;
        for(NSUInteger channel=0;channel<4;channel++) difference+=abs((int)r[a+channel]-(int)l[b+channel]);
        alpha+=r[a+3];
    }
    mirrors &= alpha>0&&difference/(152*104*4)<2;
    check(mirrors,@"left-facing-render-is-a-horizontal-mirror-of-right-facing-render");
    NSData *bounded=CatRenderForTest(1,NSMakeRect(12,12,38,26),64,50);BOOL inside=bounded.length>0;NSUInteger visible=0;
    const unsigned char *b=bounded.bytes;
    if (inside) for(NSUInteger y=0;y<50;y++) for(NSUInteger x=0;x<64;x++) {
        if (b[(y*64+x)*4+3]<=CatVisibleAlpha) continue;
        visible++;
        inside &= x>=12&&x<50&&y>=12&&y<38;
    }
    check(inside&&visible>0,@"smooth-aspect-fit-drawing-stays-inside-thirty-eight-by-twenty-six-stage");
    return @{@"passed":@(failed.count==0),@"checks":passed,@"failures":failed,@"asset":summary};
}
@end
