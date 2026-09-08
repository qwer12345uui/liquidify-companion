#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface LYCMetalGlassView : UIView
@property(nonatomic,readonly,getter=isRendererAvailable) BOOL rendererAvailable;
- (void)refreshBackdrop;
- (void)reloadParameters;
@end

NS_ASSUME_NONNULL_END
