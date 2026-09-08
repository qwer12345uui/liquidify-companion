#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LYCMetalGlassView.h"

static const void *kLYCGlassKey = &kLYCGlassKey;
static NSString *const LYCPreferences = @"com.qwer12345uui.liquidifycompanion";

static BOOL LYCEnabled(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:LYCPreferences];
    return [prefs objectForKey:@"Enabled"] ? [prefs boolForKey:@"Enabled"] : YES;
}

static void LYCHideNativeDockMaterial(UIView *root) {
    for (UIView *view in root.subviews) {
        if ([view isKindOfClass:LYCMetalGlassView.class]) continue;
        NSString *name = NSStringFromClass(view.class);
        if ([name containsString:@"Material"] ||
            [name containsString:@"VisualEffect"] ||
            [name containsString:@"BackgroundView"]) {
            view.alpha = 0.0;
            continue;
        }
        LYCHideNativeDockMaterial(view);
    }
}

static void LYCInstallOrLayoutGlass(UIView *dock) {
    if (!LYCEnabled() || !dock.window || CGRectIsEmpty(dock.bounds)) return;
    LYCMetalGlassView *glass = objc_getAssociatedObject(dock, kLYCGlassKey);
    if (!glass) {
        glass = [[LYCMetalGlassView alloc] initWithFrame:dock.bounds];
        glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(dock, kLYCGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [dock insertSubview:glass atIndex:0];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [glass refreshBackdrop];
        });
    }
    glass.frame = dock.bounds;
    LYCHideNativeDockMaterial(dock);
    [dock sendSubviewToBack:glass];
}

%hook SBDockView
- (void)didMoveToWindow {
    %orig;
    LYCInstallOrLayoutGlass((UIView *)self);
}
- (void)layoutSubviews {
    %orig;
    LYCInstallOrLayoutGlass((UIView *)self);
}
%end

%ctor {
    @autoreleasepool {
        if (!NSClassFromString(@"SBDockView")) {
            NSLog(@"[LiquidifyCompanion] SBDockView unavailable; no hooks installed");
        }
    }
}
