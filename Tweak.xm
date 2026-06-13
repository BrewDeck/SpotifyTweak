#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import <MediaPlayer/MediaPlayer.h>
#import <AVFoundation/AVFoundation.h>

static NSString *const kAssetMessageHandlerName = @"assetSelected";
static NSString *const kChooserURLString = @"https://musichoarders.xyz?remote.port=browser";

@interface AssetChooserViewController : UIViewController <WKScriptMessageHandler, WKNavigationDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@end

@implementation AssetChooserViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.96];

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    WKUserContentController *contentController = [WKUserContentController new];
    [contentController addScriptMessageHandler:self name:kAssetMessageHandlerName];
    configuration.userContentController = contentController;

    NSString *injection = @"window.addEventListener('click', function(event) {"
    "  var target = event.target;"
    "  while (target && !target.href && !target.src) target = target.parentElement;"
    "  if (!target) return;"
    "  var url = target.href || target.src;"
    "  if (!url) return;"
    "  var allowed = /\\.(mp4|webm|png|jpe?g|webp|avif)(\\?|$)/i.test(url);"
    "  if (!allowed) return;"
    "  var type = /\\.(mp4|webm)(\\?|$)/i.test(url) ? 'video' : 'image';"
    "  window.webkit.messageHandlers.assetSelected.postMessage({ type: type, url: url });"
    "}, true);";

    WKUserScript *script = [[WKUserScript alloc] initWithSource:injection injectionTime:WKUserScriptInjectionTimeAtDocumentStart forMainFrameOnly:NO];
    [contentController addUserScript:script];

    self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:configuration];
    self.webView.navigationDelegate = self;
    self.webView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.webView];

    self.spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    self.spinner.translatesAutoresizingMaskIntoConstraints = NO;
    self.spinner.color = [UIColor whiteColor];
    [self.view addSubview:self.spinner];
    [self.spinner startAnimating];

    UIButton *closeButton = [UIButton buttonWithType:UIButtonTypeSystem];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    [closeButton setTitle:@"Close" forState:UIControlStateNormal];
    closeButton.tintColor = [UIColor whiteColor];
    closeButton.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.5];
    closeButton.layer.cornerRadius = 12.0;
    [closeButton addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:closeButton];

    [NSLayoutConstraint activateConstraints:@[
        [self.webView.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:24],
        [self.webView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.webView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        [self.webView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor constant:-24],
        [self.spinner.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.spinner.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [closeButton.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [closeButton.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:16],
        [closeButton.widthAnchor constraintEqualToConstant:80],
        [closeButton.heightAnchor constraintEqualToConstant:38],
    ]];

    NSURL *url = [NSURL URLWithString:kChooserURLString];
    NSURLRequest *request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30.0];
    [self.webView loadRequest:request];
}

- (void)closeTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self.spinner stopAnimating];
}

- (void)userContentController:(WKUserContentController *)userContentController didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:kAssetMessageHandlerName]) { return; }
    NSDictionary *body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) { return; }
    NSString *type = body[@"type"];
    NSString *urlString = body[@"url"];
    if (urlString.length == 0 || type.length == 0) { return; }
    NSURL *assetURL = [NSURL URLWithString:urlString];
    if (!assetURL) { return; }

    [self handleSelectedAssetWithType:type url:assetURL];
}

- (void)handleSelectedAssetWithType:(NSString *)type url:(NSURL *)url {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if ([type isEqualToString:@"video"]) {
            [self updateNowPlayingForVideoURL:url];
        } else {
            [self updateNowPlayingForImageURL:url];
        }
    });
}

- (UIImage *)resizeImage:(UIImage *)image toFit:(CGSize)size {
    if (CGSizeEqualToSize(image.size, size)) { return image; }
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    [image drawInRect:CGRectMake(0, 0, size.width, size.height)];
    UIImage *resized = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return resized;
}

- (void)updateNowPlayingForImageURL:(NSURL *)url {
    NSError *error = nil;
    NSData *data = [NSData dataWithContentsOfURL:url options:NSDataReadingUncached error:&error];
    if (!data || error) { return; }
    UIImage *image = [UIImage imageWithData:data scale:[UIScreen mainScreen].scale];
    if (!image) { return; }
    [self updateNowPlayingWithImage:image assetURL:url];
}

- (void)updateNowPlayingForVideoURL:(NSURL *)url {
    AVURLAsset *asset = [AVURLAsset URLAssetWithURL:url options:nil];
    AVAssetImageGenerator *generator = [AVAssetImageGenerator assetImageGeneratorWithAsset:asset];
    generator.appliesPreferredTrackTransform = YES;
    generator.maximumSize = CGSizeMake(1920, 1080);
    NSError *error = nil;
    CMTime time = CMTimeMakeWithSeconds(0.5, 600);
    CGImageRef imageRef = [generator copyCGImageAtTime:time actualTime:NULL error:&error];
    if (!imageRef || error) { return; }
    UIImage *image = [UIImage imageWithCGImage:imageRef scale:[UIScreen mainScreen].scale orientation:UIImageOrientationUp];
    CGImageRelease(imageRef);
    if (!image) { return; }
    [self updateNowPlayingWithImage:image assetURL:url];
}

- (void)updateNowPlayingWithImage:(UIImage *)image assetURL:(NSURL *)url {
    CGSize artworkSize = CGSizeMake(1200, 1200);
    UIImage *finalImage = [self resizeImage:image toFit:artworkSize];
    MPMediaItemArtwork *artwork = [[MPMediaItemArtwork alloc] initWithBoundsSize:finalImage.size requestHandler:^UIImage * _Nonnull(CGSize size) {
        return [self resizeImage:finalImage toFit:size];
    }];

    NSMutableDictionary *info = [NSMutableDictionary dictionary];
    info[MPMediaItemPropertyTitle] = @"Spotify Asset";
    info[MPMediaItemPropertyArtist] = @"Musichoarders";
    info[MPNowPlayingInfoPropertyMediaType] = @(MPNowPlayingInfoMediaTypeAudio);
    info[MPNowPlayingInfoPropertyPlaybackRate] = @(1.0);
    info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = @(0);
    info[MPNowPlayingInfoPropertyPlaybackQueueIndex] = @(0);
    info[MPMediaItemPropertyArtwork] = artwork;
    info[MPNowPlayingInfoPropertyAssetURL] = url;

    dispatch_async(dispatch_get_main_queue(), ^{
        [MPNowPlayingInfoCenter defaultCenter].nowPlayingInfo = info;
    });
}

@end

@interface AssetChooserManager : NSObject
@property (nonatomic, strong) UIButton *launcherButton;
@property (nonatomic, assign) BOOL installed;
@property (nonatomic, assign) BOOL presented;
+ (instancetype)sharedManager;
- (void)installLauncher;
@end

@implementation AssetChooserManager

+ (instancetype)sharedManager {
    static AssetChooserManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [AssetChooserManager new];
    });
    return shared;
}

- (UIWindow *)activeWindow {
    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
        if (![scene isKindOfClass:[UIWindowScene class]]) { continue; }
        if (scene.activationState != UISceneActivationStateForegroundActive) { continue; }
        UIWindowScene *windowScene = (UIWindowScene *)scene;
        for (UIWindow *window in windowScene.windows.reverseObjectEnumerator) {
            if (window.isKeyWindow && window.windowLevel == UIWindowLevelNormal) {
                return window;
            }
        }
    }
    return [UIApplication sharedApplication].keyWindow;
}

- (void)installLauncher {
    if (self.installed) { return; }
    self.installed = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self activeWindow];
        if (!window) { return; }

        UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
        button.translatesAutoresizingMaskIntoConstraints = NO;
        button.layer.cornerRadius = 24.0;
        button.layer.masksToBounds = YES;
        button.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.65];
        [button setTitle:@"Assets" forState:UIControlStateNormal];
        [button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [button addTarget:self action:@selector(launchChooser:) forControlEvents:UIControlEventTouchUpInside];

        [window addSubview:button];
        [NSLayoutConstraint activateConstraints:@[
            [button.widthAnchor constraintEqualToConstant:92],
            [button.heightAnchor constraintEqualToConstant:48],
            [button.trailingAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.trailingAnchor constant:-16],
            [button.bottomAnchor constraintEqualToAnchor:window.safeAreaLayoutGuide.bottomAnchor constant:-92],
        ]];

        self.launcherButton = button;
    });
}

- (void)launchChooser:(id)sender {
    if (self.presented) { return; }
    self.presented = YES;
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *window = [self activeWindow];
        UIViewController *top = window.rootViewController;
        while (top.presentedViewController) {
            top = top.presentedViewController;
        }

        AssetChooserViewController *chooser = [AssetChooserViewController new];
        chooser.modalPresentationStyle = UIModalPresentationFullScreen;
        chooser.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        [top presentViewController:chooser animated:YES completion:nil];
    });
}

@end

%ctor {
    NSString *bundleID = [[NSBundle mainBundle] bundleIdentifier] ?: @"";
    if ([bundleID.lowercaseString containsString:@"spotify"]) {
        [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification * _Nonnull note) {
            [[AssetChooserManager sharedManager] installLauncher];
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [[AssetChooserManager sharedManager] installLauncher];
        });
    }
}
