#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import "LYCMetalGlassView.h"

static const void *kLYCGlassKey = &kLYCGlassKey;
static const void *kLYCOriginalAlphaKey = &kLYCOriginalAlphaKey;
static NSString *const LYCPreferences = @"com.qwer12345uui.liquidifycompanion";

static BOOL LYCEnabled(void) {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:LYCPreferences];
    return [prefs objectForKey:@"Enabled"] ? [prefs boolForKey:@"Enabled"] : YES;
}

static void LYCSetNativeDockMaterialHidden(UIView *root, BOOL hidden) {
    for (UIView *view in root.subviews) {
        if ([view isKindOfClass:LYCMetalGlassView.class]) continue;
        NSString *name = NSStringFromClass(view.class);
        BOOL isMaterial = [name containsString:@"Material"] || [name containsString:@"VisualEffect"];
        BOOL isDockBackground = [name containsString:@"Dock"] && [name containsString:@"Background"];
        if (isMaterial || isDockBackground) {
            if (hidden) {
                if (!objc_getAssociatedObject(view, kLYCOriginalAlphaKey)) {
                    objc_setAssociatedObject(view, kLYCOriginalAlphaKey, @(view.alpha), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                view.alpha = 0.0;
            } else {
                NSNumber *original = objc_getAssociatedObject(view, kLYCOriginalAlphaKey);
                if (original) {
                    view.alpha = original.doubleValue;
                    objc_setAssociatedObject(view, kLYCOriginalAlphaKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
            continue;
        }
        LYCSetNativeDockMaterialHidden(view, hidden);
    }
}

static void LYCInstallOrLayoutGlass(UIView *dock) {
    LYCMetalGlassView *glass = objc_getAssociatedObject(dock, kLYCGlassKey);
    if (!LYCEnabled() || !dock.window || CGRectIsEmpty(dock.bounds)) {
        LYCSetNativeDockMaterialHidden(dock, NO);
        [glass removeFromSuperview];
        objc_setAssociatedObject(dock, kLYCGlassKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    if (!glass) {
        glass = [[LYCMetalGlassView alloc] initWithFrame:dock.bounds];
        if (!glass.rendererAvailable) {
            LYCSetNativeDockMaterialHidden(dock, NO);
            return;
        }
        glass.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(dock, kLYCGlassKey, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [dock insertSubview:glass atIndex:0];
        __weak LYCMetalGlassView *weakGlass = glass;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.18 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakGlass refreshBackdrop];
        });
    }
    glass.frame = dock.bounds;
    LYCSetNativeDockMaterialHidden(dock, YES);
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
