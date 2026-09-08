#import "LYCMetalGlassView.h"
#import <Metal/Metal.h>
#import <MetalKit/MetalKit.h>
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

typedef struct {
    vector_float2 resolution;
    float contentsScale;
    float cornerRadius;
    vector_float4 materialTint;
    float glassThickness;
    float refractiveIndex;
    float dispersionStrength;
    float fresnelIntensity;
    float glareIntensity;
    float blurRadius;
} LYCUniforms;

static const char *LYCShaderCString = R"METAL(
#include <metal_stdlib>
using namespace metal;
struct VOut { float4 position [[position]]; float2 uv; };
struct U { float2 resolution; float contentsScale; float cornerRadius; float4 tint; float thickness; float eta; float dispersion; float fresnel; float glare; float blur; };
vertex VOut lycVertex(uint id [[vertex_id]]) {
    float2 p[3] = {float2(-1,-1), float2(3,-1), float2(-1,3)};
    VOut o; o.position=float4(p[id],0,1); o.uv=float2((p[id].x+1)*.5, 1-(p[id].y+1)*.5); return o;
}
fragment half4 lycGlass(VOut in [[stage_in]], constant U &u [[buffer(0)]], texture2d<half> bg [[texture(0)]]) {
    constexpr sampler s(address::clamp_to_edge, filter::linear);
    float2 uv=clamp(in.uv,0.0,1.0), q=uv*2.0-1.0;
    float2 aspect=float2(u.resolution.x/max(u.resolution.y,1.0),1.0); q*=aspect;
    float2 aq=abs(q), n=normalize(float2(copysign(pow(aq.x,3.0),q.x),copysign(pow(aq.y,3.0),q.y))+1e-4);
    float edge=smoothstep(.30,.98,max(aq.x/max(aspect.x,1.0),aq.y));
    float bend=(u.eta-1.0)*u.thickness*.0022;
    float2 off=n*bend*(.18+.82*edge);
    float2 px=1.0/max(u.resolution,float2(1.0));
    float b=max(u.blur,0.0)*.55;
    half4 c=bg.sample(s,uv+off);
    c=(c*4.0+bg.sample(s,uv+off+float2(px.x*b,0))+bg.sample(s,uv+off-float2(px.x*b,0))+bg.sample(s,uv+off+float2(0,px.y*b))+bg.sample(s,uv+off-float2(0,px.y*b)))/8.0;
    float d=u.dispersion*.00075*(.25+.75*edge);
    c.r=bg.sample(s,uv+off-n*d).r; c.b=bg.sample(s,uv+off+n*d).b;
    half3 color=mix(c.rgb,half3(u.tint.rgb),half(u.tint.a));
    float fres=pow(edge,3.0)*u.fresnel;
    float glare=pow(max(dot(normalize(n+1e-4),normalize(float2(-.65,-.75))),0.0),10.0)*edge*u.glare;
    color+=half3(fres*.22+glare*.38);
    color*=half(1.0+.035*(1.0-edge));
    return half4(color,1.0h);
}
)METAL";

@interface LYCMetalGlassView () <MTKViewDelegate>
@property(nonatomic,strong) MTKView *metalView;
@property(nonatomic,strong) id<MTLCommandQueue> queue;
@property(nonatomic,strong) id<MTLRenderPipelineState> pipeline;
@property(nonatomic,strong) id<MTLTexture> backdrop;
@property(nonatomic,assign) LYCUniforms uniforms;
@property(nonatomic,assign) BOOL capturing;
@property(nonatomic,assign) BOOL captureScheduled;
@property(nonatomic,assign) CGSize lastCaptureSize;
@end

@implementation LYCMetalGlassView
- (instancetype)initWithFrame:(CGRect)frame {
    if ((self=[super initWithFrame:frame])) {
        self.userInteractionEnabled=NO;
        self.backgroundColor=UIColor.clearColor;
        self.layer.cornerCurve=kCACornerCurveContinuous;
        self.layer.cornerRadius=28.0;
        self.layer.masksToBounds=YES;
        id<MTLDevice> device=MTLCreateSystemDefaultDevice();
        if (!device) { self.hidden=YES; return self; }
        _queue=[device newCommandQueue];
        _metalView=[[MTKView alloc] initWithFrame:self.bounds device:device];
        _metalView.autoresizingMask=UIViewAutoresizingFlexibleWidth|UIViewAutoresizingFlexibleHeight;
        _metalView.delegate=self; _metalView.paused=YES; _metalView.enableSetNeedsDisplay=YES;
        _metalView.framebufferOnly=YES; _metalView.opaque=YES;
        _metalView.colorPixelFormat=MTLPixelFormatBGRA8Unorm;
        [self addSubview:_metalView];
        NSError *error=nil;
        NSString *source=[NSString stringWithUTF8String:LYCShaderCString];
        id<MTLLibrary> lib=[device newLibraryWithSource:source options:nil error:&error];
        MTLRenderPipelineDescriptor *d=[MTLRenderPipelineDescriptor new];
        d.vertexFunction=[lib newFunctionWithName:@"lycVertex"];
        d.fragmentFunction=[lib newFunctionWithName:@"lycGlass"];
        d.colorAttachments[0].pixelFormat=_metalView.colorPixelFormat;
        _pipeline=[device newRenderPipelineStateWithDescriptor:d error:&error];
        if (!_pipeline) { NSLog(@"[LiquidifyCompanion] Metal pipeline error: %@",error); self.hidden=YES; }
        [self reloadParameters];
    } return self;
}
- (void)reloadParameters {
    NSUserDefaults *p=[[NSUserDefaults alloc] initWithSuiteName:@"com.qwer12345uui.liquidifycompanion"];
    float strength=[p objectForKey:@"RefractionStrength"]?[p floatForKey:@"RefractionStrength"]:24.0f;
    _uniforms.materialTint=(vector_float4){0.90,0.96,1.0,0.08};
    _uniforms.glassThickness=MAX(8.0f,MIN(40.0f,strength));
    _uniforms.refractiveIndex=1.22f;
    _uniforms.dispersionStrength=MAX(0.0f,MIN(24.0f,[p objectForKey:@"Dispersion"]?[p floatForKey:@"Dispersion"]:9.0f));
    _uniforms.fresnelIntensity=MAX(0.0f,MIN(2.0f,[p objectForKey:@"Fresnel"]?[p floatForKey:@"Fresnel"]:0.85f));
    _uniforms.glareIntensity=MAX(0.0f,MIN(2.0f,[p objectForKey:@"Glare"]?[p floatForKey:@"Glare"]:0.75f));
    _uniforms.blurRadius=MAX(0.0f,MIN(10.0f,[p objectForKey:@"BlurRadius"]?[p floatForKey:@"BlurRadius"]:2.0f));
    [_metalView setNeedsDisplay];
}
- (BOOL)isRendererAvailable { return _pipeline != nil && _queue != nil && _metalView.device != nil; }
- (void)layoutSubviews {
    [super layoutSubviews];
    self.layer.cornerRadius=MIN(32.0,CGRectGetHeight(self.bounds)*.28);
    CGFloat scale=MIN(UIScreen.mainScreen.scale,2.0);
    _metalView.contentScaleFactor=scale;
    _metalView.drawableSize=CGSizeMake(MAX(1.0,CGRectGetWidth(self.bounds)*scale),MAX(1.0,CGRectGetHeight(self.bounds)*scale));
    if (!CGSizeEqualToSize(_lastCaptureSize,self.bounds.size)) {
        _lastCaptureSize=self.bounds.size;
        [self refreshBackdrop];
    }
}
- (void)refreshBackdrop {
    NSAssert(NSThread.isMainThread,@"Backdrop capture must run on the main thread");
    if (_captureScheduled || _capturing || !self.rendererAvailable || CGRectIsEmpty(self.bounds) || !self.window) return;
    _captureScheduled=YES;
    __weak typeof(self) weakSelf=self;
    dispatch_async(dispatch_get_main_queue(), ^{
        typeof(self) self=weakSelf;
        if (!self) return;
        self.captureScheduled=NO;
        if (self.capturing || !self.rendererAvailable || !self.window || CGRectIsEmpty(self.bounds)) return;
        self.capturing=YES;
        BOOL wasHidden=self.hidden;
        BOOL contextOpen=NO;
        @try {
            self.hidden=YES;
            UIGraphicsBeginImageContextWithOptions(self.bounds.size,YES,MIN(UIScreen.mainScreen.scale,2.0));
            contextOpen=YES;
            CGContextRef c=UIGraphicsGetCurrentContext();
            CGPoint o=[self convertPoint:CGPointZero toView:self.window];
            CGContextTranslateCTM(c,-o.x,-o.y);
            [self.window.layer renderInContext:c];
            UIImage *image=UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            contextOpen=NO;
            if (image.CGImage) {
                NSError *error=nil;
                MTKTextureLoader *loader=[[MTKTextureLoader alloc] initWithDevice:self.metalView.device];
                self.backdrop=[loader newTextureWithCGImage:image.CGImage options:@{MTKTextureLoaderOptionSRGB:@NO,MTKTextureLoaderOptionOrigin:MTKTextureLoaderOriginTopLeft} error:&error];
                if (error) NSLog(@"[LiquidifyCompanion] backdrop error: %@",error);
            }
        } @finally {
            if (contextOpen) UIGraphicsEndImageContext();
            self.hidden=wasHidden;
            self.capturing=NO;
        }
        [self.metalView setNeedsDisplay];
    });
}
- (void)drawInMTKView:(MTKView *)view {
    if (!_backdrop || !_pipeline || !view.currentDrawable || !view.currentRenderPassDescriptor) return;
    _uniforms.resolution=(vector_float2){(float)view.drawableSize.width,(float)view.drawableSize.height};
    _uniforms.contentsScale=UIScreen.mainScreen.scale; _uniforms.cornerRadius=self.layer.cornerRadius;
    id<MTLCommandBuffer> cb=[_queue commandBuffer]; id<MTLRenderCommandEncoder> e=[cb renderCommandEncoderWithDescriptor:view.currentRenderPassDescriptor];
    [e setRenderPipelineState:_pipeline]; [e setFragmentBytes:&_uniforms length:sizeof(_uniforms) atIndex:0];
    [e setFragmentTexture:_backdrop atIndex:0]; [e drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3]; [e endEncoding];
    [cb presentDrawable:view.currentDrawable]; [cb commit];
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size { (void)view; (void)size; }
@end
