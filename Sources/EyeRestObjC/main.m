#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <fcntl.h>
#import <sys/file.h>
#import <unistd.h>

typedef NS_ENUM(NSInteger, ERReminderKind) {
    ERReminderKindEye = 0,
    ERReminderKindStand = 1
};

typedef NS_ENUM(NSInteger, EREyeMode) {
    EREyeMode202020 = 0,
    EREyeModePomodoro = 1,
    EREyeModeCustom = 2
};

typedef NS_ENUM(NSInteger, ERRestStyle) {
    ERRestStyleBreath = 0,
    ERRestStyleForest = 1,
    ERRestStylePixel = 2,
    ERRestStyleToy = 3,
    ERRestStyleNight = 4
};

typedef NS_ENUM(NSInteger, ERMenuBarMode) {
    ERMenuBarModeBoth = 0,
    ERMenuBarModeEye = 1,
    ERMenuBarModeStand = 2,
    ERMenuBarModeCompact = 3,
    ERMenuBarModeSmart = 4
};

static NSString *const ERSettingsEyeEnabledKey = @"eyeEnabled";
static NSString *const ERSettingsEyeModeKey = @"eyeMode";
static NSString *const ERSettingsEyeFocusSecondsKey = @"eyeFocusSeconds";
static NSString *const ERSettingsEyeRestSecondsKey = @"eyeRestSeconds";
static NSString *const ERSettingsStandEnabledKey = @"standEnabled";
static NSString *const ERSettingsStandIntervalSecondsKey = @"standIntervalSeconds";
static NSString *const ERSettingsStandDurationSecondsKey = @"standDurationSeconds";
static NSString *const ERSettingsShowRestWindowKey = @"showRestWindow";
static NSString *const ERSettingsNotificationsKey = @"notificationsEnabled";
static NSString *const ERSettingsRestStyleKey = @"restStyle";
static NSString *const ERSettingsMenuBarModeKey = @"menuBarMode";
static NSString *const ERSettingsLaunchAtLoginKey = @"launchAtLogin";
static NSString *const ERStatsDateKey = @"statsDate";
static NSString *const ERStatsEyeDoneKey = @"statsEyeDone";
static NSString *const ERStatsStandDoneKey = @"statsStandDone";
static NSString *const ERStatsStandSecondsKey = @"statsStandSeconds";
static NSString *const ERStatsSnoozedKey = @"statsSnoozed";
static NSString *const ERStatsSkippedKey = @"statsSkipped";
static NSString *const ERStatsHistoryKey = @"statsHistory";
static NSString *const ERBrandName = @"松一下";
static NSString *const ERRestOverlayWindowIdentifier = @"local.codex.eyerest.rest-overlay";
static int ERSingleInstanceLockFD = -1;

static BOOL ERAcquireSingleInstanceLock(void) {
    const char *path = "/tmp/local.codex.eyerest.lock";
    ERSingleInstanceLockFD = open(path, O_CREAT | O_RDWR, 0644);
    if (ERSingleInstanceLockFD < 0) return NO;
    if (flock(ERSingleInstanceLockFD, LOCK_EX | LOCK_NB) != 0) {
        close(ERSingleInstanceLockFD);
        ERSingleInstanceLockFD = -1;
        return NO;
    }
    return YES;
}

static NSString *ERFormatDuration(NSTimeInterval interval) {
    NSInteger seconds = MAX(0, (NSInteger)ceil(interval));
    NSInteger hours = seconds / 3600;
    NSInteger minutes = (seconds % 3600) / 60;
    NSInteger remainingSeconds = seconds % 60;
    if (hours > 0) {
        return [NSString stringWithFormat:@"%ld:%02ld:%02ld", (long)hours, (long)minutes, (long)remainingSeconds];
    }
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)minutes, (long)remainingSeconds];
}

static NSString *ERFormatMenuBarShortDuration(NSTimeInterval interval) {
    NSInteger seconds = MAX(0, (NSInteger)ceil(interval));
    if (seconds < 60) {
        return [NSString stringWithFormat:@"%lds", (long)seconds];
    }
    NSInteger minutes = (NSInteger)ceil((double)seconds / 60.0);
    if (minutes < 60) {
        return [NSString stringWithFormat:@"%ldm", (long)minutes];
    }
    NSInteger hours = minutes / 60;
    NSInteger remainingMinutes = minutes % 60;
    return remainingMinutes > 0
        ? [NSString stringWithFormat:@"%ldh%02ldm", (long)hours, (long)remainingMinutes]
        : [NSString stringWithFormat:@"%ldh", (long)hours];
}

static NSString *EREyeModeTitle(EREyeMode mode) {
    switch (mode) {
        case EREyeMode202020: return @"20-20-20";
        case EREyeModePomodoro: return @"番茄钟";
        case EREyeModeCustom: return @"自定义";
    }
}

static NSString *ERRestStyleTitle(ERRestStyle style) {
    switch (style) {
        case ERRestStyleBreath: return @"极简呼吸";
        case ERRestStyleForest: return @"松弛森林";
        case ERRestStylePixel: return @"像素窗边";
        case ERRestStyleToy: return @"软糖玩具";
        case ERRestStyleNight: return @"夜间护眼";
    }
}

static NSString *ERMenuBarModeTitle(ERMenuBarMode mode) {
    switch (mode) {
        case ERMenuBarModeBoth: return @"眼睛 + 站立";
        case ERMenuBarModeEye: return @"只显示眼睛";
        case ERMenuBarModeStand: return @"只显示站立";
        case ERMenuBarModeCompact: return @"极简图标";
        case ERMenuBarModeSmart: return @"智能轮换";
    }
}

static NSString *ERRestStyleHint(ERRestStyle style) {
    switch (style) {
        case ERRestStyleBreath: return @"慢一点，屏幕会等你回来。";
        case ERRestStyleForest: return @"像走到树荫里一样，把肩膀放下来。";
        case ERRestStylePixel: return @"窗外有一格天空，眼睛也要存档。";
        case ERRestStyleToy: return @"把身体晃一晃，像按下柔软的重启键。";
        case ERRestStyleNight: return @"降低亮度，也降低一点紧绷。";
    }
}

typedef struct {
    __unsafe_unretained NSColor *settingsBackground;
    __unsafe_unretained NSColor *settingsHeader;
    __unsafe_unretained NSColor *card;
    __unsafe_unretained NSColor *cardBorder;
    __unsafe_unretained NSColor *backgroundA;
    __unsafe_unretained NSColor *backgroundB;
    __unsafe_unretained NSColor *foreground;
    __unsafe_unretained NSColor *secondary;
    __unsafe_unretained NSColor *accent;
    CGFloat cornerRadius;
    BOOL pixel;
} ERTheme;

static NSInteger ERClampInteger(NSInteger value, NSInteger minimum, NSInteger maximum) {
    return MIN(maximum, MAX(minimum, value));
}

static NSColor *ERColor(CGFloat red, CGFloat green, CGFloat blue, CGFloat alpha) {
    return [NSColor colorWithCalibratedRed:red green:green blue:blue alpha:alpha];
}

static NSString *ERTodayKey(void) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    return [formatter stringFromDate:NSDate.date];
}

static NSArray<NSString *> *ERRecentDateKeys(NSInteger days) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"yyyy-MM-dd";
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSMutableArray<NSString *> *dates = [NSMutableArray arrayWithCapacity:days];
    for (NSInteger offset = days - 1; offset >= 0; offset--) {
        NSDate *date = [calendar dateByAddingUnit:NSCalendarUnitDay value:-offset toDate:NSDate.date options:0];
        [dates addObject:[formatter stringFromDate:date]];
    }
    return dates;
}

static NSString *ERShortDateTitle(NSString *dateKey) {
    if (dateKey.length >= 10) {
        return [dateKey substringFromIndex:5];
    }
    return dateKey;
}

static NSString *ERFormatShortMinutes(NSInteger seconds) {
    NSInteger minutes = MAX(0, (NSInteger)llround((double)seconds / 60.0));
    if (minutes < 60) {
        return [NSString stringWithFormat:@"%ld 分钟", (long)minutes];
    }
    NSInteger hours = minutes / 60;
    NSInteger remaining = minutes % 60;
    return remaining > 0
        ? [NSString stringWithFormat:@"%ld 小时 %ld 分", (long)hours, (long)remaining]
        : [NSString stringWithFormat:@"%ld 小时", (long)hours];
}

static NSString *ERLaunchAgentIdentifier(void) {
    return @"local.codex.eyerest";
}

static NSString *ERLaunchAgentPath(void) {
    NSString *agentsDir = [NSHomeDirectory() stringByAppendingPathComponent:@"Library/LaunchAgents"];
    return [agentsDir stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.plist", ERLaunchAgentIdentifier()]];
}

static NSString *ERCurrentAppPath(void) {
    NSString *bundlePath = NSBundle.mainBundle.bundlePath;
    if (bundlePath.length > 0) return bundlePath;
    return @"/Applications/松一下.app";
}

static BOOL ERRunLaunchctl(NSArray<NSString *> *arguments) {
    NSTask *task = [[NSTask alloc] init];
    task.launchPath = @"/bin/launchctl";
    task.arguments = arguments;
    @try {
        [task launch];
        [task waitUntilExit];
        return task.terminationStatus == 0;
    } @catch (NSException *exception) {
        return NO;
    }
}

static void ERApplyLaunchAtLogin(BOOL enabled) {
    NSFileManager *fileManager = NSFileManager.defaultManager;
    NSString *plistPath = ERLaunchAgentPath();
    NSString *agentsDir = [plistPath stringByDeletingLastPathComponent];
    NSString *domain = [NSString stringWithFormat:@"gui/%d", getuid()];
    NSString *appPath = ERCurrentAppPath();

    if (!enabled) {
        ERRunLaunchctl(@[@"bootout", domain, plistPath]);
        [fileManager removeItemAtPath:plistPath error:nil];
        return;
    }

    [fileManager createDirectoryAtPath:agentsDir withIntermediateDirectories:YES attributes:nil error:nil];
    NSDictionary *plist = @{
        @"Label": ERLaunchAgentIdentifier(),
        @"ProgramArguments": @[@"/usr/bin/open", appPath],
        @"RunAtLoad": @YES,
        @"KeepAlive": @NO
    };
    NSData *data = [NSPropertyListSerialization dataWithPropertyList:plist format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
    [data writeToFile:plistPath atomically:YES];
    ERRunLaunchctl(@[@"bootout", domain, plistPath]);
    ERRunLaunchctl(@[@"bootstrap", domain, plistPath]);
    ERRunLaunchctl(@[@"enable", [NSString stringWithFormat:@"%@/%@", domain, ERLaunchAgentIdentifier()]]);
}

static NSView *ERRoundedView(NSRect frame, NSColor *color, CGFloat radius) {
    NSView *view = [[NSView alloc] initWithFrame:frame];
    view.wantsLayer = YES;
    view.layer.backgroundColor = color.CGColor;
    view.layer.cornerRadius = radius;
    view.layer.masksToBounds = YES;
    return view;
}

static CAGradientLayer *ERGradientLayer(NSRect frame, NSArray<NSColor *> *colors, CGPoint start, CGPoint end) {
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = frame;
    NSMutableArray *cgColors = [NSMutableArray arrayWithCapacity:colors.count];
    for (NSColor *color in colors) {
        [cgColors addObject:(__bridge id)color.CGColor];
    }
    gradient.colors = cgColors;
    gradient.startPoint = start;
    gradient.endPoint = end;
    return gradient;
}

static ERTheme ERThemeForStyle(ERRestStyle style) {
    ERTheme theme;
    theme.settingsBackground = ERColor(0.95, 0.96, 0.98, 1);
    theme.settingsHeader = [NSColor colorWithWhite:1 alpha:0.70];
    theme.card = NSColor.whiteColor;
    theme.cardBorder = ERColor(0.82, 0.84, 0.88, 0.75);
    theme.backgroundA = ERColor(0.88, 0.93, 0.96, 1);
    theme.backgroundB = ERColor(0.70, 0.84, 0.90, 1);
    theme.foreground = NSColor.labelColor;
    theme.secondary = NSColor.secondaryLabelColor;
    theme.accent = NSColor.controlAccentColor;
    theme.cornerRadius = 24;
    theme.pixel = NO;

    switch (style) {
        case ERRestStyleBreath:
            theme.backgroundA = ERColor(0.84, 0.94, 0.96, 1);
            theme.backgroundB = ERColor(0.94, 0.97, 0.96, 1);
            theme.accent = ERColor(0.10, 0.55, 0.62, 1);
            break;
        case ERRestStyleForest:
            theme.settingsBackground = ERColor(0.91, 0.95, 0.91, 1);
            theme.card = ERColor(0.98, 1.00, 0.96, 1);
            theme.cardBorder = ERColor(0.72, 0.82, 0.70, 1);
            theme.backgroundA = ERColor(0.08, 0.27, 0.18, 1);
            theme.backgroundB = ERColor(0.34, 0.55, 0.30, 1);
            theme.foreground = NSColor.whiteColor;
            theme.secondary = [NSColor colorWithWhite:1 alpha:0.78];
            theme.accent = ERColor(0.78, 0.96, 0.68, 1);
            break;
        case ERRestStylePixel:
            theme.settingsBackground = ERColor(0.90, 0.94, 0.98, 1);
            theme.card = ERColor(0.98, 0.99, 1.00, 1);
            theme.cardBorder = ERColor(0.48, 0.58, 0.72, 1);
            theme.backgroundA = ERColor(0.31, 0.64, 0.88, 1);
            theme.backgroundB = ERColor(0.82, 0.93, 0.98, 1);
            theme.accent = ERColor(0.15, 0.29, 0.55, 1);
            theme.cornerRadius = 6;
            theme.pixel = YES;
            break;
        case ERRestStyleToy:
            theme.settingsBackground = ERColor(1.00, 0.94, 0.95, 1);
            theme.card = ERColor(1.00, 0.98, 0.99, 1);
            theme.cardBorder = ERColor(0.96, 0.72, 0.78, 1);
            theme.backgroundA = ERColor(1.00, 0.70, 0.78, 1);
            theme.backgroundB = ERColor(0.70, 0.85, 1.00, 1);
            theme.accent = ERColor(0.86, 0.24, 0.43, 1);
            theme.cornerRadius = 34;
            break;
        case ERRestStyleNight:
            theme.settingsBackground = ERColor(0.10, 0.11, 0.15, 1);
            theme.settingsHeader = ERColor(0.13, 0.14, 0.20, 0.92);
            theme.card = ERColor(0.16, 0.17, 0.23, 1);
            theme.cardBorder = ERColor(0.28, 0.31, 0.42, 1);
            theme.backgroundA = ERColor(0.04, 0.05, 0.10, 1);
            theme.backgroundB = ERColor(0.13, 0.15, 0.30, 1);
            theme.foreground = NSColor.whiteColor;
            theme.secondary = [NSColor colorWithWhite:1 alpha:0.70];
            theme.accent = ERColor(0.65, 0.76, 1, 1);
            break;
    }
    return theme;
}

@interface ERSettings : NSObject
@property(nonatomic) BOOL eyeEnabled;
@property(nonatomic) EREyeMode eyeMode;
@property(nonatomic) NSInteger eyeFocusSeconds;
@property(nonatomic) NSInteger eyeRestSeconds;
@property(nonatomic) BOOL standEnabled;
@property(nonatomic) NSInteger standIntervalSeconds;
@property(nonatomic) NSInteger standDurationSeconds;
@property(nonatomic) BOOL showRestWindow;
@property(nonatomic) BOOL notificationsEnabled;
@property(nonatomic) ERRestStyle restStyle;
@property(nonatomic) ERMenuBarMode menuBarMode;
@property(nonatomic) BOOL launchAtLogin;
+ (instancetype)load;
- (void)save;
- (void)applyEyePreset:(EREyeMode)mode;
@end

@implementation ERSettings

+ (instancetype)load {
    ERSettings *settings = [[ERSettings alloc] init];
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSDictionary *registered = @{
        ERSettingsEyeEnabledKey: @YES,
        ERSettingsEyeModeKey: @(EREyeMode202020),
        ERSettingsEyeFocusSecondsKey: @(20 * 60),
        ERSettingsEyeRestSecondsKey: @20,
        ERSettingsStandEnabledKey: @YES,
        ERSettingsStandIntervalSecondsKey: @(2 * 60 * 60),
        ERSettingsStandDurationSecondsKey: @(20 * 60),
        ERSettingsShowRestWindowKey: @YES,
        ERSettingsNotificationsKey: @YES,
        ERSettingsRestStyleKey: @(ERRestStyleBreath),
        ERSettingsMenuBarModeKey: @(ERMenuBarModeBoth),
        ERSettingsLaunchAtLoginKey: @NO
    };
    [defaults registerDefaults:registered];

    settings.eyeEnabled = [defaults boolForKey:ERSettingsEyeEnabledKey];
    settings.eyeMode = [defaults integerForKey:ERSettingsEyeModeKey];
    settings.eyeFocusSeconds = [defaults integerForKey:ERSettingsEyeFocusSecondsKey];
    settings.eyeRestSeconds = [defaults integerForKey:ERSettingsEyeRestSecondsKey];
    settings.standEnabled = [defaults boolForKey:ERSettingsStandEnabledKey];
    settings.standIntervalSeconds = [defaults integerForKey:ERSettingsStandIntervalSecondsKey];
    settings.standDurationSeconds = [defaults integerForKey:ERSettingsStandDurationSecondsKey];
    settings.showRestWindow = [defaults boolForKey:ERSettingsShowRestWindowKey];
    settings.notificationsEnabled = [defaults boolForKey:ERSettingsNotificationsKey];
    settings.restStyle = [defaults integerForKey:ERSettingsRestStyleKey];
    settings.menuBarMode = [defaults integerForKey:ERSettingsMenuBarModeKey];
    settings.launchAtLogin = [defaults boolForKey:ERSettingsLaunchAtLoginKey];

    if (settings.eyeFocusSeconds <= 0) {
        NSInteger oldWorkMinutes = [defaults integerForKey:@"workMinutes"];
        settings.eyeFocusSeconds = MAX(1, oldWorkMinutes) * 60;
    }
    if (settings.eyeRestSeconds <= 0) {
        NSInteger oldRestSeconds = [defaults integerForKey:@"restSeconds"];
        settings.eyeRestSeconds = MAX(20, oldRestSeconds);
    }
    settings.eyeFocusSeconds = ERClampInteger(settings.eyeFocusSeconds, 10, 8 * 60 * 60);
    settings.eyeRestSeconds = ERClampInteger(settings.eyeRestSeconds, 10, 60 * 60);
    settings.standIntervalSeconds = ERClampInteger(settings.standIntervalSeconds, 10, 8 * 60 * 60);
    settings.standDurationSeconds = ERClampInteger(settings.standDurationSeconds, 10, 2 * 60 * 60);
    settings.restStyle = ERClampInteger(settings.restStyle, ERRestStyleBreath, ERRestStyleNight);
    settings.menuBarMode = ERClampInteger(settings.menuBarMode, ERMenuBarModeBoth, ERMenuBarModeSmart);
    return settings;
}

- (void)save {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setBool:self.eyeEnabled forKey:ERSettingsEyeEnabledKey];
    [defaults setInteger:self.eyeMode forKey:ERSettingsEyeModeKey];
    [defaults setInteger:self.eyeFocusSeconds forKey:ERSettingsEyeFocusSecondsKey];
    [defaults setInteger:self.eyeRestSeconds forKey:ERSettingsEyeRestSecondsKey];
    [defaults setBool:self.standEnabled forKey:ERSettingsStandEnabledKey];
    [defaults setInteger:self.standIntervalSeconds forKey:ERSettingsStandIntervalSecondsKey];
    [defaults setInteger:self.standDurationSeconds forKey:ERSettingsStandDurationSecondsKey];
    [defaults setBool:self.showRestWindow forKey:ERSettingsShowRestWindowKey];
    [defaults setBool:self.notificationsEnabled forKey:ERSettingsNotificationsKey];
    [defaults setInteger:self.restStyle forKey:ERSettingsRestStyleKey];
    [defaults setInteger:self.menuBarMode forKey:ERSettingsMenuBarModeKey];
    [defaults setBool:self.launchAtLogin forKey:ERSettingsLaunchAtLoginKey];
}

- (void)applyEyePreset:(EREyeMode)mode {
    self.eyeMode = mode;
    switch (mode) {
        case EREyeMode202020:
            self.eyeFocusSeconds = 20 * 60;
            self.eyeRestSeconds = 20;
            break;
        case EREyeModePomodoro:
            self.eyeFocusSeconds = 25 * 60;
            self.eyeRestSeconds = 5 * 60;
            break;
        case EREyeModeCustom:
            break;
    }
    [self save];
}

@end

@class ERAppDelegate;

@interface EROverlayWindow : NSWindow
@end

@implementation EROverlayWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

@end

@interface ERTimeInput : NSObject
@property(nonatomic, strong) NSTextField *minutesField;
@property(nonatomic, strong) NSTextField *secondsField;
- (NSInteger)secondsWithMinimum:(NSInteger)minimum maximum:(NSInteger)maximum;
- (void)setSeconds:(NSInteger)seconds;
@end

@implementation ERTimeInput

- (NSInteger)secondsWithMinimum:(NSInteger)minimum maximum:(NSInteger)maximum {
    NSInteger minutes = MAX(0, self.minutesField.integerValue);
    NSInteger seconds = ERClampInteger(self.secondsField.integerValue, 0, 59);
    NSInteger total = minutes * 60 + seconds;
    return ERClampInteger(total, minimum, maximum);
}

- (void)setSeconds:(NSInteger)seconds {
    seconds = MAX(0, seconds);
    self.minutesField.integerValue = seconds / 60;
    self.secondsField.integerValue = seconds % 60;
}

@end

@interface ERRestWindowController : NSWindowController
@property(nonatomic, weak) ERAppDelegate *appDelegate;
@property(nonatomic) ERReminderKind kind;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *messageLabel;
@property(nonatomic, strong) NSTextField *timerLabel;
@property(nonatomic, strong) NSImageView *iconView;
@property(nonatomic, strong) NSProgressIndicator *progressIndicator;
@property(nonatomic, strong) NSView *backgroundView;
@property(nonatomic, strong) NSButton *finishButton;
@property(nonatomic, strong) NSButton *extendButton;
@property(nonatomic, strong) NSButton *snoozeButton;
@property(nonatomic, strong) NSButton *skipButton;
@property(nonatomic, strong) NSView *focusCard;
@property(nonatomic, strong) NSTextField *brandLabel;
@property(nonatomic, strong) NSTextField *styleHintLabel;
@property(nonatomic, strong) NSView *actionSuggestionPill;
@property(nonatomic, strong) NSImageView *actionSuggestionIcon;
@property(nonatomic, strong) NSTextField *actionSuggestionLabel;
@property(nonatomic, strong) NSArray<NSString *> *actionSuggestions;
@property(nonatomic, strong) NSArray<NSString *> *actionSuggestionSymbols;
@property(nonatomic) NSInteger activeSuggestionIndex;
@property(nonatomic) NSTimeInterval totalDuration;
@property(nonatomic) ERRestStyle currentStyle;
- (instancetype)initWithAppDelegate:(ERAppDelegate *)appDelegate;
- (void)configureForKind:(ERReminderKind)kind settings:(ERSettings *)settings duration:(NSTimeInterval)duration;
- (void)updateRemaining:(NSTimeInterval)remaining;
- (void)configureActionSuggestionsForKind:(ERReminderKind)kind settings:(ERSettings *)settings;
- (void)updateActionSuggestionForRemaining:(NSTimeInterval)remaining;
- (void)layoutRestContent;
- (void)refitToCurrentScreen;
- (void)presentOverlay;
@end

@interface ERSettingsWindowController : NSWindowController
@property(nonatomic, weak) ERAppDelegate *appDelegate;
@property(nonatomic, strong) ERSettings *settings;
@property(nonatomic, strong) NSButton *eyeEnabledSwitch;
@property(nonatomic, strong) NSPopUpButton *eyeModePopup;
@property(nonatomic, strong) ERTimeInput *eyeFocusInput;
@property(nonatomic, strong) ERTimeInput *eyeRestInput;
@property(nonatomic, strong) NSButton *standEnabledSwitch;
@property(nonatomic, strong) ERTimeInput *standIntervalInput;
@property(nonatomic, strong) ERTimeInput *standDurationInput;
@property(nonatomic, strong) NSButton *notificationSwitch;
@property(nonatomic, strong) NSButton *restWindowSwitch;
@property(nonatomic, strong) NSButton *launchAtLoginSwitch;
@property(nonatomic, strong) NSPopUpButton *menuBarModePopup;
@property(nonatomic, strong) NSPopUpButton *restStylePopup;
@property(nonatomic, strong) NSTextField *summaryLabel;
@property(nonatomic, strong) NSTextField *statsOverviewLabel;
@property(nonatomic, strong) NSTextField *statsMonthLabel;
@property(nonatomic, strong) NSTextField *statsQualityLabel;
@property(nonatomic, strong) NSTextField *statsStandLabel;
@property(nonatomic, strong) NSTextField *statsStreakLabel;
@property(nonatomic, strong) NSButton *exportStatsButton;
@property(nonatomic, strong) NSButton *exportBackupButton;
@property(nonatomic, strong) NSArray<NSView *> *statsBars;
@property(nonatomic, strong) NSArray<NSTextField *> *statsBarLabels;
@property(nonatomic, strong) NSArray<NSView *> *heatmapCells;
@property(nonatomic, strong) NSArray<NSTextField *> *heatmapLabels;
@property(nonatomic, strong) NSView *stylePreviewShell;
@property(nonatomic, strong) NSView *stylePreviewCanvas;
@property(nonatomic, strong) NSImageView *stylePreviewIcon;
@property(nonatomic, strong) NSTextField *stylePreviewEyebrow;
@property(nonatomic, strong) NSTextField *stylePreviewTimer;
@property(nonatomic, strong) NSTextField *stylePreviewTitle;
@property(nonatomic, strong) NSTextField *stylePreviewHint;
@property(nonatomic, strong) NSArray<NSView *> *stylePreviewDecorations;
@property(nonatomic, strong) NSArray<NSView *> *pages;
@property(nonatomic, strong) NSView *eyeCard;
@property(nonatomic, strong) NSView *standCard;
@property(nonatomic, strong) NSView *alertCard;
@property(nonatomic, strong) NSView *statsCard;
@property(nonatomic, strong) NSView *contentView;
@property(nonatomic, strong) NSVisualEffectView *headerView;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSArray<NSButton *> *sidebarButtons;
@property(nonatomic, strong) NSArray<NSTextField *> *pageTitleLabels;
@property(nonatomic, strong) NSArray<NSTextField *> *pageSubtitleLabels;
@property(nonatomic, strong) NSArray<NSTextField *> *fieldLabels;
@property(nonatomic, strong) NSArray<NSView *> *settingRowViews;
@property(nonatomic, strong) NSArray<NSView *> *settingDividerViews;
@property(nonatomic, strong) NSSegmentedControl *paneControl;
@property(nonatomic) NSInteger selectedPage;
- (instancetype)initWithSettings:(ERSettings *)settings appDelegate:(ERAppDelegate *)appDelegate;
- (void)refreshControls;
- (void)refreshStats;
- (void)exportStatsCSV:(id)sender;
- (void)exportStatsJSON:(id)sender;
@end

@interface ERAppDelegate : NSObject <NSApplicationDelegate, UNUserNotificationCenterDelegate, NSMenuDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *menu;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, strong) ERSettings *settings;
@property(nonatomic, strong) NSDate *eyeDueAt;
@property(nonatomic, strong) NSDate *eyeRestEndsAt;
@property(nonatomic, strong) NSDate *standDueAt;
@property(nonatomic, strong) NSDate *standRestEndsAt;
@property(nonatomic, strong) NSDate *pauseStartedAt;
@property(nonatomic, strong) NSDate *pausedUntil;
@property(nonatomic) BOOL eyeResting;
@property(nonatomic) BOOL standResting;
@property(nonatomic) BOOL paused;
@property(nonatomic) NSInteger todayEyeDone;
@property(nonatomic) NSInteger todayStandDone;
@property(nonatomic) NSInteger todayStandSeconds;
@property(nonatomic) NSInteger todaySnoozed;
@property(nonatomic) NSInteger todaySkipped;
@property(nonatomic, strong) ERRestWindowController *restWindowController;
@property(nonatomic, strong) ERSettingsWindowController *settingsWindowController;
- (void)finishRestForKind:(ERReminderKind)kind;
- (void)extendRestForKind:(ERReminderKind)kind bySeconds:(NSTimeInterval)seconds;
- (void)snoozeRestForKind:(ERReminderKind)kind bySeconds:(NSTimeInterval)seconds;
- (void)skipRestForKind:(ERReminderKind)kind;
- (void)settingsDidChangeShouldReset:(BOOL)shouldReset;
- (void)settleExpiredRests;
- (void)repairRestOverlayAfterDisplayChange;
- (void)repairRestStateIfNeeded;
- (void)closeOrphanRestWindows;
- (NSTimeInterval)configuredRestDurationForKind:(ERReminderKind)kind;
- (NSDate *)restEndDateForKind:(ERReminderKind)kind;
- (void)ensureRestWindowForKind:(ERReminderKind)kind remaining:(NSTimeInterval)remaining;
- (void)loadTodayStats;
- (void)saveTodayStats;
- (void)resetTodayStatsIfNeeded;
- (void)applyPreferenceSideEffects;
- (void)updateStatusItemAppearance;
- (NSDictionary *)statsHistoryIncludingToday;
@end

@implementation ERSettingsWindowController

- (instancetype)initWithSettings:(ERSettings *)settings appDelegate:(ERAppDelegate *)appDelegate {
    NSRect frame = NSMakeRect(0, 0, 780, 540);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable
                                                     backing:NSBackingStoreBuffered
                                                       defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;

    self.settings = settings;
    self.appDelegate = appDelegate;
    window.title = [NSString stringWithFormat:@"%@ 设置", ERBrandName];
    window.releasedWhenClosed = NO;
    window.level = NSFloatingWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    [window center];

    NSView *content = [[NSView alloc] initWithFrame:frame];
    content.wantsLayer = YES;
    content.layer.backgroundColor = ERColor(0.95, 0.96, 0.98, 1).CGColor;
    window.contentView = content;
    self.contentView = content;
    self.fieldLabels = @[];
    self.settingRowViews = @[];
    self.settingDividerViews = @[];

    NSVisualEffectView *header = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 196, 540)];
    header.material = NSVisualEffectMaterialSidebar;
    header.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    header.state = NSVisualEffectStateActive;
    [content addSubview:header];
    self.headerView = header;

    NSTextField *title = [NSTextField labelWithString:ERBrandName];
    title.frame = NSMakeRect(22, 486, 140, 28);
    title.font = [NSFont systemFontOfSize:22 weight:NSFontWeightSemibold];
    [header addSubview:title];
    self.titleLabel = title;

    self.summaryLabel = [NSTextField labelWithString:@""];
    self.summaryLabel.frame = NSMakeRect(22, 452, 150, 34);
    self.summaryLabel.font = [NSFont systemFontOfSize:13];
    self.summaryLabel.textColor = NSColor.secondaryLabelColor;
    [header addSubview:self.summaryLabel];

    self.paneControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.paneControl.segmentCount = 4;
    [self.paneControl setLabel:@"眼睛" forSegment:0];
    [self.paneControl setLabel:@"站立" forSegment:1];
    [self.paneControl setLabel:@"显示" forSegment:2];
    [self.paneControl setLabel:@"统计" forSegment:3];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"眼睛"] forSegment:0];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"figure.stand" accessibilityDescription:@"站立"] forSegment:1];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"bell" accessibilityDescription:@"显示"] forSegment:2];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:@"统计"] forSegment:3];
    self.paneControl.segmentStyle = NSSegmentStyleSeparated;
    self.paneControl.target = self;
    self.paneControl.action = @selector(selectPane:);

    NSArray<NSString *> *navTitles = @[@"眼睛休息", @"站立提醒", @"显示方式", @"休息统计"];
    NSArray<NSString *> *navIcons = @[@"eye", @"figure.stand", @"bell", @"chart.bar"];
    NSMutableArray *navButtons = [NSMutableArray arrayWithCapacity:navTitles.count];
    for (NSInteger index = 0; index < navTitles.count; index++) {
        NSButton *button = [NSButton buttonWithTitle:navTitles[index] target:self action:@selector(selectSidebarPane:)];
        button.frame = NSMakeRect(16, 392 - index * 42, 164, 34);
        [button setButtonType:NSButtonTypeToggle];
        button.bezelStyle = NSBezelStyleTexturedRounded;
        button.image = [NSImage imageWithSystemSymbolName:navIcons[index] accessibilityDescription:navTitles[index]];
        button.imagePosition = NSImageLeft;
        button.alignment = NSTextAlignmentLeft;
        button.tag = index;
        [header addSubview:button];
        [navButtons addObject:button];
    }
    self.sidebarButtons = navButtons;

    NSView *eyePage = [self pageViewWithTitle:@"眼睛休息提醒" subtitle:@"调试时可以填 0 分 10 秒。20-20-20 默认是 20 分钟后看远处 20 秒。"];
    self.eyeCard = eyePage.subviews.lastObject;
    [self buildEyeSectionInView:eyePage];
    [content addSubview:eyePage];

    NSView *standPage = [self pageViewWithTitle:@"站立提醒" subtitle:@"默认每 2 小时提醒一次，站立 20 分钟。它和眼睛提醒独立计时。"];
    self.standCard = standPage.subviews.lastObject;
    [self buildStandSectionInView:standPage];
    [content addSubview:standPage];

    NSView *alertPage = [self pageViewWithTitle:@"提醒方式" subtitle:@"选择到点时如何提醒你。系统通知仍需在 macOS 通知设置里允许。"];
    self.alertCard = alertPage.subviews.lastObject;
    [self buildAlertSectionInView:alertPage];
    [content addSubview:alertPage];

    NSView *statsPage = [self pageViewWithTitle:@"休息统计" subtitle:@"看看最近 7 天有没有真的把休息做起来。统计只保存在本机。"];
    self.statsCard = statsPage.subviews.lastObject;
    [self buildStatsSectionInView:statsPage];
    [content addSubview:statsPage];

    self.pages = @[eyePage, standPage, alertPage, statsPage];
    self.pageTitleLabels = @[
        [eyePage.subviews objectAtIndex:0],
        [standPage.subviews objectAtIndex:0],
        [alertPage.subviews objectAtIndex:0],
        [statsPage.subviews objectAtIndex:0]
    ];
    self.pageSubtitleLabels = @[
        [eyePage.subviews objectAtIndex:1],
        [standPage.subviews objectAtIndex:1],
        [alertPage.subviews objectAtIndex:1],
        [statsPage.subviews objectAtIndex:1]
    ];

    NSButton *applyButton = [NSButton buttonWithTitle:@"应用" target:self action:@selector(applySettings:)];
    applyButton.frame = NSMakeRect(664, 24, 84, 32);
    applyButton.bezelStyle = NSBezelStyleRounded;
    applyButton.keyEquivalent = @"\r";
    [content addSubview:applyButton];

    NSButton *resetButton = [NSButton buttonWithTitle:@"恢复默认" target:self action:@selector(resetDefaults:)];
    resetButton.frame = NSMakeRect(562, 24, 90, 32);
    resetButton.bezelStyle = NSBezelStyleRounded;
    [content addSubview:resetButton];

    self.selectedPage = 0;
    [self updateSelectedPage];
    [self refreshControls];
    return self;
}

- (NSView *)pageViewWithTitle:(NSString *)titleText subtitle:(NSString *)subtitle {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(222, 92, 528, 336)];

    NSTextField *title = [NSTextField labelWithString:titleText];
    title.frame = NSMakeRect(0, 300, 390, 30);
    title.font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
    [view addSubview:title];

    NSTextField *sub = [NSTextField wrappingLabelWithString:subtitle];
    sub.frame = NSMakeRect(0, 250, 500, 40);
    sub.font = [NSFont systemFontOfSize:13];
    sub.textColor = NSColor.secondaryLabelColor;
    [view addSubview:sub];

    NSView *card = ERRoundedView(NSMakeRect(0, 0, 528, 216), NSColor.whiteColor, 16);
    card.layer.borderColor = ERColor(0.82, 0.84, 0.88, 0.7).CGColor;
    card.layer.borderWidth = 1;
    [view addSubview:card];
    return view;
}

- (void)addSettingRowsToCard:(NSView *)card frames:(NSArray<NSValue *> *)frames dividerX:(CGFloat)dividerX dividerWidth:(CGFloat)dividerWidth {
    NSMutableArray<NSView *> *rows = [self.settingRowViews mutableCopy];
    NSMutableArray<NSView *> *dividers = [self.settingDividerViews mutableCopy];
    for (NSInteger index = 0; index < frames.count; index++) {
        NSRect frame = frames[index].rectValue;
        NSView *row = ERRoundedView(frame, [NSColor colorWithWhite:1 alpha:0.34], 10);
        [card addSubview:row];
        [rows addObject:row];

        if (index < frames.count - 1) {
            NSView *divider = [[NSView alloc] initWithFrame:NSMakeRect(dividerX, frame.origin.y - 1, dividerWidth, 1)];
            divider.wantsLayer = YES;
            divider.layer.backgroundColor = ERColor(0.82, 0.84, 0.88, 0.48).CGColor;
            [card addSubview:divider];
            [dividers addObject:divider];
        }
    }
    self.settingRowViews = rows;
    self.settingDividerViews = dividers;
}

- (void)buildEyeSectionInView:(NSView *)view {
    NSView *card = self.eyeCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(14, 148, 500, 50)],
        [NSValue valueWithRect:NSMakeRect(14, 104, 500, 42)],
        [NSValue valueWithRect:NSMakeRect(14, 62, 500, 42)],
        [NSValue valueWithRect:NSMakeRect(14, 20, 500, 42)]
    ] dividerX:136 dividerWidth:354];

    self.eyeEnabledSwitch = [NSButton checkboxWithTitle:@"启用眼睛休息提醒" target:self action:@selector(toggleOnly:)];
    self.eyeEnabledSwitch.frame = NSMakeRect(24, 158, 180, 24);
    [card addSubview:self.eyeEnabledSwitch];

    [card addSubview:[self fieldLabel:@"使用电脑：" frame:NSMakeRect(24, 114, 96, 22)]];
    self.eyeFocusInput = [self addTimeFieldsToView:card x:140 y:110];

    [card addSubview:[self fieldLabel:@"休息：" frame:NSMakeRect(24, 72, 96, 22)]];
    self.eyeRestInput = [self addTimeFieldsToView:card x:140 y:68];

    [card addSubview:[self fieldLabel:@"节奏：" frame:NSMakeRect(24, 30, 96, 22)]];
    self.eyeModePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 26, 190, 30) pullsDown:NO];
    [self.eyeModePopup addItemsWithTitles:@[EREyeModeTitle(EREyeMode202020), EREyeModeTitle(EREyeModePomodoro), EREyeModeTitle(EREyeModeCustom)]];
    self.eyeModePopup.target = self;
    self.eyeModePopup.action = @selector(eyeModeChanged:);
    [card addSubview:self.eyeModePopup];

    NSButton *ruleButton = [NSButton buttonWithTitle:@"20-20-20" target:self action:@selector(use202020:)];
    ruleButton.frame = NSMakeRect(354, 26, 96, 30);
    ruleButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:ruleButton];
}

- (void)buildStandSectionInView:(NSView *)view {
    NSView *card = self.standCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(14, 148, 500, 50)],
        [NSValue valueWithRect:NSMakeRect(14, 104, 500, 42)],
        [NSValue valueWithRect:NSMakeRect(14, 62, 500, 42)]
    ] dividerX:136 dividerWidth:354];

    self.standEnabledSwitch = [NSButton checkboxWithTitle:@"启用站立提醒" target:self action:@selector(toggleOnly:)];
    self.standEnabledSwitch.frame = NSMakeRect(24, 158, 160, 24);
    [card addSubview:self.standEnabledSwitch];

    [card addSubview:[self fieldLabel:@"每隔：" frame:NSMakeRect(24, 114, 96, 22)]];
    self.standIntervalInput = [self addTimeFieldsToView:card x:140 y:110];

    [card addSubview:[self fieldLabel:@"站立：" frame:NSMakeRect(24, 72, 96, 22)]];
    self.standDurationInput = [self addTimeFieldsToView:card x:140 y:68];
}

- (void)buildAlertSectionInView:(NSView *)view {
    NSView *card = self.alertCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(14, 166, 316, 38)],
        [NSValue valueWithRect:NSMakeRect(14, 128, 316, 38)],
        [NSValue valueWithRect:NSMakeRect(14, 90, 316, 38)],
        [NSValue valueWithRect:NSMakeRect(14, 50, 316, 40)],
        [NSValue valueWithRect:NSMakeRect(14, 10, 316, 40)]
    ] dividerX:136 dividerWidth:180];

    self.notificationSwitch = [NSButton checkboxWithTitle:@"系统通知" target:self action:@selector(toggleOnly:)];
    self.notificationSwitch.frame = NSMakeRect(24, 174, 160, 24);
    [card addSubview:self.notificationSwitch];

    self.restWindowSwitch = [NSButton checkboxWithTitle:@"提醒窗口" target:self action:@selector(toggleOnly:)];
    self.restWindowSwitch.frame = NSMakeRect(24, 136, 160, 24);
    [card addSubview:self.restWindowSwitch];

    self.launchAtLoginSwitch = [NSButton checkboxWithTitle:@"登录时自动启动" target:self action:@selector(toggleOnly:)];
    self.launchAtLoginSwitch.frame = NSMakeRect(24, 98, 180, 24);
    [card addSubview:self.launchAtLoginSwitch];

    [card addSubview:[self fieldLabel:@"菜单栏：" frame:NSMakeRect(24, 58, 96, 22)]];
    self.menuBarModePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 54, 190, 30) pullsDown:NO];
    [self.menuBarModePopup addItemsWithTitles:@[
        ERMenuBarModeTitle(ERMenuBarModeBoth),
        ERMenuBarModeTitle(ERMenuBarModeEye),
        ERMenuBarModeTitle(ERMenuBarModeStand),
        ERMenuBarModeTitle(ERMenuBarModeCompact),
        ERMenuBarModeTitle(ERMenuBarModeSmart),
    ]];
    self.menuBarModePopup.target = self;
    self.menuBarModePopup.action = @selector(toggleOnly:);
    [card addSubview:self.menuBarModePopup];

    [card addSubview:[self fieldLabel:@"画面风格：" frame:NSMakeRect(24, 20, 96, 22)]];
    self.restStylePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 16, 190, 30) pullsDown:NO];
    [self.restStylePopup addItemsWithTitles:@[
        ERRestStyleTitle(ERRestStyleBreath),
        ERRestStyleTitle(ERRestStyleForest),
        ERRestStyleTitle(ERRestStylePixel),
        ERRestStyleTitle(ERRestStyleToy),
        ERRestStyleTitle(ERRestStyleNight),
    ]];
    self.restStylePopup.target = self;
    self.restStylePopup.action = @selector(toggleOnly:);
    [card addSubview:self.restStylePopup];

    self.stylePreviewShell = ERRoundedView(NSMakeRect(344, 18, 160, 180), [NSColor colorWithWhite:1 alpha:0.42], 16);
    self.stylePreviewShell.layer.borderWidth = 1;
    [card addSubview:self.stylePreviewShell];

    self.stylePreviewEyebrow = [NSTextField labelWithString:@"风格预览"];
    self.stylePreviewEyebrow.frame = NSMakeRect(14, 150, 132, 18);
    self.stylePreviewEyebrow.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    [self.stylePreviewShell addSubview:self.stylePreviewEyebrow];

    self.stylePreviewCanvas = ERRoundedView(NSMakeRect(14, 64, 132, 76), NSColor.whiteColor, 14);
    self.stylePreviewCanvas.layer.borderWidth = 1;
    [self.stylePreviewShell addSubview:self.stylePreviewCanvas];

    self.stylePreviewIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(18, 26, 28, 28)];
    self.stylePreviewIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:24 weight:NSFontWeightSemibold];
    [self.stylePreviewCanvas addSubview:self.stylePreviewIcon];

    self.stylePreviewTimer = [NSTextField labelWithString:@"00:20"];
    self.stylePreviewTimer.frame = NSMakeRect(54, 28, 62, 24);
    self.stylePreviewTimer.font = [NSFont monospacedDigitSystemFontOfSize:19 weight:NSFontWeightSemibold];
    self.stylePreviewTimer.alignment = NSTextAlignmentRight;
    [self.stylePreviewCanvas addSubview:self.stylePreviewTimer];

    self.stylePreviewTitle = [NSTextField labelWithString:@""];
    self.stylePreviewTitle.frame = NSMakeRect(14, 38, 132, 20);
    self.stylePreviewTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    [self.stylePreviewShell addSubview:self.stylePreviewTitle];

    self.stylePreviewHint = [NSTextField wrappingLabelWithString:@""];
    self.stylePreviewHint.frame = NSMakeRect(14, 8, 132, 30);
    self.stylePreviewHint.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
    [self.stylePreviewShell addSubview:self.stylePreviewHint];
}

- (void)buildStatsSectionInView:(NSView *)view {
    NSView *card = self.statsCard;
    self.statsOverviewLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsOverviewLabel.frame = NSMakeRect(24, 184, 300, 22);
    self.statsOverviewLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.statsOverviewLabel.textColor = NSColor.labelColor;
    [card addSubview:self.statsOverviewLabel];

    self.exportStatsButton = [NSButton buttonWithTitle:@"导出 CSV" target:self action:@selector(exportStatsCSV:)];
    self.exportStatsButton.frame = NSMakeRect(330, 180, 84, 30);
    self.exportStatsButton.bezelStyle = NSBezelStyleRounded;
    self.exportStatsButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.exportStatsButton];

    self.exportBackupButton = [NSButton buttonWithTitle:@"备份 JSON" target:self action:@selector(exportStatsJSON:)];
    self.exportBackupButton.frame = NSMakeRect(420, 180, 92, 30);
    self.exportBackupButton.bezelStyle = NSBezelStyleRounded;
    self.exportBackupButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.exportBackupButton];

    self.statsMonthLabel = [NSTextField labelWithString:@""];
    self.statsMonthLabel.frame = NSMakeRect(24, 156, 480, 20);
    self.statsMonthLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.statsMonthLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsMonthLabel];

    self.statsQualityLabel = [self metricLabelWithFrame:NSMakeRect(24, 124, 150, 24)];
    [card addSubview:self.statsQualityLabel];
    self.statsStandLabel = [self metricLabelWithFrame:NSMakeRect(190, 124, 150, 24)];
    [card addSubview:self.statsStandLabel];
    self.statsStreakLabel = [self metricLabelWithFrame:NSMakeRect(356, 124, 150, 24)];
    [card addSubview:self.statsStreakLabel];

    NSArray<NSString *> *dayTitles = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    NSMutableArray *bars = [NSMutableArray array];
    NSMutableArray *labels = [NSMutableArray array];
    CGFloat startX = 24;
    CGFloat gap = 8;
    CGFloat barWidth = 28;
    CGFloat baseY = 34;
    for (NSInteger index = 0; index < 7; index++) {
        CGFloat x = startX + index * (barWidth + gap);
        NSView *slot = ERRoundedView(NSMakeRect(x, baseY, barWidth, 72), ERColor(0.93, 0.94, 0.97, 1), 12);
        [card addSubview:slot];
        [bars addObject:slot];

        NSTextField *label = [NSTextField labelWithString:dayTitles[index]];
        label.frame = NSMakeRect(x - 10, 10, 48, 22);
        label.alignment = NSTextAlignmentCenter;
        label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        label.textColor = NSColor.secondaryLabelColor;
        [card addSubview:label];
        [labels addObject:label];
    }
    self.statsBars = bars;
    self.statsBarLabels = labels;

    NSTextField *heatmapTitle = [NSTextField labelWithString:@"近 30 天热力"];
    heatmapTitle.frame = NSMakeRect(320, 100, 160, 18);
    heatmapTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    heatmapTitle.textColor = NSColor.secondaryLabelColor;
    [card addSubview:heatmapTitle];

    NSMutableArray *cells = [NSMutableArray array];
    CGFloat cell = 14;
    CGFloat cellGap = 4;
    CGFloat originX = 320;
    CGFloat originY = 28;
    for (NSInteger index = 0; index < 30; index++) {
        NSInteger row = index / 6;
        NSInteger column = index % 6;
        NSView *day = ERRoundedView(NSMakeRect(originX + column * (cell + cellGap),
                                               originY + (4 - row) * (cell + cellGap),
                                               cell,
                                               cell),
                                    ERColor(0.90, 0.91, 0.94, 1),
                                    4);
        [card addSubview:day];
        [cells addObject:day];
    }
    self.heatmapCells = cells;
    self.heatmapLabels = @[heatmapTitle];
}

- (NSTextField *)metricLabelWithFrame:(NSRect)frame {
    NSTextField *label = [NSTextField labelWithString:@""];
    label.frame = frame;
    label.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightMedium];
    label.textColor = NSColor.secondaryLabelColor;
    label.alignment = NSTextAlignmentCenter;
    return label;
}

- (NSTextField *)fieldLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.font = [NSFont systemFontOfSize:13];
    label.textColor = NSColor.secondaryLabelColor;
    label.alignment = NSTextAlignmentRight;
    self.fieldLabels = [self.fieldLabels arrayByAddingObject:label];
    return label;
}

- (ERTimeInput *)addTimeInputToView:(NSView *)view label:(NSString *)labelText x:(CGFloat)x y:(CGFloat)y {
    [view addSubview:[self fieldLabel:labelText frame:NSMakeRect(x, y + 4, 94, 22)]];
    return [self addTimeFieldsToView:view x:x + 110 y:y];
}

- (ERTimeInput *)addTimeFieldsToView:(NSView *)view x:(CGFloat)x y:(CGFloat)y {
    ERTimeInput *input = [[ERTimeInput alloc] init];
    input.minutesField = [self timeTextFieldWithFrame:NSMakeRect(x, y, 64, 28)];
    input.secondsField = [self timeTextFieldWithFrame:NSMakeRect(x + 114, y, 56, 28)];
    [view addSubview:input.minutesField];
    [view addSubview:input.secondsField];

    NSTextField *minuteLabel = [NSTextField labelWithString:@"分"];
    minuteLabel.frame = NSMakeRect(x + 72, y + 5, 22, 20);
    minuteLabel.textColor = NSColor.secondaryLabelColor;
    [view addSubview:minuteLabel];

    NSTextField *secondLabel = [NSTextField labelWithString:@"秒"];
    secondLabel.frame = NSMakeRect(x + 178, y + 5, 22, 20);
    secondLabel.textColor = NSColor.secondaryLabelColor;
    [view addSubview:secondLabel];
    return input;
}

- (NSTextField *)timeTextFieldWithFrame:(NSRect)frame {
    NSTextField *field = [[NSTextField alloc] initWithFrame:frame];
    field.alignment = NSTextAlignmentRight;
    field.font = [NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightRegular];
    field.bezelStyle = NSTextFieldRoundedBezel;
    field.target = self;
    field.action = @selector(applySettings:);
    return field;
}

- (void)selectPane:(NSSegmentedControl *)sender {
    self.selectedPage = sender.selectedSegment;
    [self updateSelectedPage];
}

- (void)selectSidebarPane:(NSButton *)sender {
    self.selectedPage = sender.tag;
    [self updateSelectedPage];
}

- (void)updateSelectedPage {
    for (NSInteger index = 0; index < self.pages.count; index++) {
        self.pages[index].hidden = index != self.selectedPage;
    }
    self.paneControl.selectedSegment = self.selectedPage;
    for (NSButton *button in self.sidebarButtons) {
        button.state = button.tag == self.selectedPage ? NSControlStateValueOn : NSControlStateValueOff;
    }
}

- (void)refreshControls {
    self.eyeEnabledSwitch.state = self.settings.eyeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.eyeModePopup selectItemAtIndex:self.settings.eyeMode];
    [self.eyeFocusInput setSeconds:self.settings.eyeFocusSeconds];
    [self.eyeRestInput setSeconds:self.settings.eyeRestSeconds];
    self.standEnabledSwitch.state = self.settings.standEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.standIntervalInput setSeconds:self.settings.standIntervalSeconds];
    [self.standDurationInput setSeconds:self.settings.standDurationSeconds];
    self.notificationSwitch.state = self.settings.notificationsEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.restWindowSwitch.state = self.settings.showRestWindow ? NSControlStateValueOn : NSControlStateValueOff;
    self.launchAtLoginSwitch.state = self.settings.launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
    [self.menuBarModePopup selectItemAtIndex:self.settings.menuBarMode];
    [self.restStylePopup selectItemAtIndex:self.settings.restStyle];
    self.summaryLabel.stringValue = [NSString stringWithFormat:@"眼睛：%@ %@ / %@ · 站立：每 %@ 站 %@",
                                     self.settings.eyeEnabled ? @"开启" : @"关闭",
                                     ERFormatDuration(self.settings.eyeFocusSeconds),
                                     ERFormatDuration(self.settings.eyeRestSeconds),
                                     ERFormatDuration(self.settings.standIntervalSeconds),
                                     ERFormatDuration(self.settings.standDurationSeconds)];
    [self applySettingsTheme];
    [self refreshStats];
}

- (void)refreshStats {
    NSDictionary *history = [self.appDelegate statsHistoryIncludingToday];
    NSArray<NSString *> *dates = ERRecentDateKeys(7);
    NSArray<NSString *> *monthDates = ERRecentDateKeys(30);
    NSInteger weekDone = 0;
    NSInteger weekSnoozed = 0;
    NSInteger weekSkipped = 0;
    NSInteger weekStandSeconds = 0;
    NSInteger monthDone = 0;
    NSInteger monthActiveDays = 0;
    NSInteger maxDone = 1;
    NSMutableArray<NSNumber *> *dailyDone = [NSMutableArray arrayWithCapacity:dates.count];

    for (NSString *dateKey in dates) {
        NSDictionary *entry = history[dateKey];
        NSInteger done = [entry[@"eye"] integerValue] + [entry[@"stand"] integerValue];
        NSInteger snoozed = [entry[@"snoozed"] integerValue];
        NSInteger skipped = [entry[@"skipped"] integerValue];
        NSInteger standSeconds = [entry[@"standSeconds"] integerValue];
        weekDone += done;
        weekSnoozed += snoozed;
        weekSkipped += skipped;
        weekStandSeconds += standSeconds;
        maxDone = MAX(maxDone, done);
        [dailyDone addObject:@(done)];
    }

    for (NSString *dateKey in monthDates) {
        NSDictionary *entry = history[dateKey];
        NSInteger done = [entry[@"eye"] integerValue] + [entry[@"stand"] integerValue];
        monthDone += done;
        maxDone = MAX(maxDone, done);
        if (done > 0) {
            monthActiveDays += 1;
        }
    }

    NSInteger streak = 0;
    for (NSString *dateKey in [ERRecentDateKeys(30) reverseObjectEnumerator]) {
        NSDictionary *entry = history[dateKey];
        NSInteger done = [entry[@"eye"] integerValue] + [entry[@"stand"] integerValue];
        if (done <= 0) break;
        streak += 1;
    }

    NSInteger friction = weekDone + weekSnoozed + weekSkipped;
    NSInteger skipRate = friction > 0 ? (NSInteger)llround((double)weekSkipped * 100.0 / (double)friction) : 0;

    self.statsOverviewLabel.stringValue = [NSString stringWithFormat:@"今天完成 %ld 次休息，本周完成 %ld 次。稍后/跳过共 %ld 次。",
                                           (long)(self.appDelegate.todayEyeDone + self.appDelegate.todayStandDone),
                                           (long)weekDone,
                                           (long)(weekSnoozed + weekSkipped)];
    self.statsMonthLabel.stringValue = [NSString stringWithFormat:@"近 30 天完成 %ld 次，活跃 %ld 天。", (long)monthDone, (long)monthActiveDays];
    self.statsQualityLabel.stringValue = [NSString stringWithFormat:@"跳过率 %ld%%", (long)skipRate];
    self.statsStandLabel.stringValue = [NSString stringWithFormat:@"站立 %@", ERFormatShortMinutes(weekStandSeconds)];
    self.statsStreakLabel.stringValue = [NSString stringWithFormat:@"连续 %ld 天", (long)streak];

    ERTheme theme = ERThemeForStyle(self.settings.restStyle);
    for (NSInteger index = 0; index < self.statsBars.count; index++) {
        NSView *bar = self.statsBars[index];
        NSInteger done = [dailyDone[index] integerValue];
        CGFloat ratio = done <= 0 ? 0.12 : MAX(0.22, MIN(1.0, (CGFloat)done / (CGFloat)maxDone));
        CGFloat height = 16 + ratio * 56;
        NSRect frame = bar.frame;
        frame.origin.y = 34;
        frame.size.height = height;
        bar.frame = frame;
        bar.layer.backgroundColor = [theme.accent colorWithAlphaComponent:done <= 0 ? 0.18 : 0.55].CGColor;
        self.statsBarLabels[index].stringValue = [NSString stringWithFormat:@"%@\n%ld", ERShortDateTitle(dates[index]), (long)done];
    }

    for (NSInteger index = 0; index < self.heatmapCells.count && index < monthDates.count; index++) {
        NSDictionary *entry = history[monthDates[index]];
        NSInteger done = [entry[@"eye"] integerValue] + [entry[@"stand"] integerValue];
        CGFloat ratio = done <= 0 ? 0.0 : MIN(1.0, (CGFloat)done / (CGFloat)MAX(1, maxDone));
        CGFloat alpha = done <= 0 ? 0.14 : 0.28 + ratio * 0.55;
        NSView *cell = self.heatmapCells[index];
        cell.layer.backgroundColor = [theme.accent colorWithAlphaComponent:alpha].CGColor;
        cell.toolTip = [NSString stringWithFormat:@"%@ · %ld 次", monthDates[index], (long)done];
    }
}

- (void)exportStatsCSV:(id)sender {
    NSDictionary *history = [self.appDelegate statsHistoryIncludingToday];
    NSArray<NSString *> *dates = ERRecentDateKeys(30);
    NSMutableString *csv = [NSMutableString stringWithString:@"date,eye_done,stand_done,stand_minutes,snoozed,skipped,total_done\n"];
    for (NSString *dateKey in dates) {
        NSDictionary *entry = history[dateKey];
        NSInteger eye = [entry[@"eye"] integerValue];
        NSInteger stand = [entry[@"stand"] integerValue];
        NSInteger standMinutes = (NSInteger)llround((double)[entry[@"standSeconds"] integerValue] / 60.0);
        NSInteger snoozed = [entry[@"snoozed"] integerValue];
        NSInteger skipped = [entry[@"skipped"] integerValue];
        [csv appendFormat:@"%@,%ld,%ld,%ld,%ld,%ld,%ld\n",
         dateKey,
         (long)eye,
         (long)stand,
         (long)standMinutes,
         (long)snoozed,
         (long)skipped,
         (long)(eye + stand)];
    }

    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"导出休息统计";
    panel.nameFieldStringValue = [NSString stringWithFormat:@"songyixia-stats-%@.csv", ERTodayKey()];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"csv"]];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) return;
        [csv writeToURL:panel.URL atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }];
}

- (void)exportStatsJSON:(id)sender {
    NSDictionary *history = [self.appDelegate statsHistoryIncludingToday];
    NSArray<NSString *> *dates = ERRecentDateKeys(30);
    NSMutableArray<NSDictionary *> *entries = [NSMutableArray arrayWithCapacity:dates.count];
    for (NSString *dateKey in dates) {
        NSDictionary *entry = history[dateKey] ?: @{};
        NSInteger eye = [entry[@"eye"] integerValue];
        NSInteger stand = [entry[@"stand"] integerValue];
        NSInteger standSeconds = [entry[@"standSeconds"] integerValue];
        NSInteger snoozed = [entry[@"snoozed"] integerValue];
        NSInteger skipped = [entry[@"skipped"] integerValue];
        [entries addObject:@{
            @"date": dateKey,
            @"eyeDone": @(eye),
            @"standDone": @(stand),
            @"standSeconds": @(standSeconds),
            @"snoozed": @(snoozed),
            @"skipped": @(skipped),
            @"totalDone": @(eye + stand)
        }];
    }

    NSDictionary *payload = @{
        @"app": ERBrandName,
        @"schemaVersion": @1,
        @"exportedAt": [[NSISO8601DateFormatter new] stringFromDate:NSDate.date],
        @"settings": @{
            @"eyeEnabled": @(self.settings.eyeEnabled),
            @"eyeMode": EREyeModeTitle(self.settings.eyeMode),
            @"eyeFocusSeconds": @(self.settings.eyeFocusSeconds),
            @"eyeRestSeconds": @(self.settings.eyeRestSeconds),
            @"standEnabled": @(self.settings.standEnabled),
            @"standIntervalSeconds": @(self.settings.standIntervalSeconds),
            @"standDurationSeconds": @(self.settings.standDurationSeconds),
            @"showRestWindow": @(self.settings.showRestWindow),
            @"notificationsEnabled": @(self.settings.notificationsEnabled),
            @"restStyle": ERRestStyleTitle(self.settings.restStyle),
            @"menuBarMode": ERMenuBarModeTitle(self.settings.menuBarMode),
            @"launchAtLogin": @(self.settings.launchAtLogin)
        },
        @"stats": @{
            @"rangeDays": @30,
            @"entries": entries
        }
    };

    NSData *data = [NSJSONSerialization dataWithJSONObject:payload options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys error:nil];
    if (!data) return;

    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.title = @"备份休息数据";
    panel.nameFieldStringValue = [NSString stringWithFormat:@"songyixia-backup-%@.json", ERTodayKey()];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"json"]];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) return;
        [data writeToURL:panel.URL atomically:YES];
    }];
}

- (void)applySettingsTheme {
    ERTheme theme = ERThemeForStyle(self.settings.restStyle);
    self.contentView.layer.backgroundColor = theme.settingsBackground.CGColor;
    self.headerView.wantsLayer = YES;
    self.headerView.layer.backgroundColor = theme.settingsHeader.CGColor;
    self.eyeCard.layer.backgroundColor = theme.card.CGColor;
    self.standCard.layer.backgroundColor = theme.card.CGColor;
    self.alertCard.layer.backgroundColor = theme.card.CGColor;
    self.statsCard.layer.backgroundColor = theme.card.CGColor;
    self.eyeCard.layer.borderColor = theme.cardBorder.CGColor;
    self.standCard.layer.borderColor = theme.cardBorder.CGColor;
    self.alertCard.layer.borderColor = theme.cardBorder.CGColor;
    self.statsCard.layer.borderColor = theme.cardBorder.CGColor;
    self.eyeCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.standCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.alertCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.statsCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.titleLabel.textColor = theme.foreground == NSColor.whiteColor ? NSColor.whiteColor : NSColor.labelColor;
    self.summaryLabel.textColor = theme.secondary;
    self.statsOverviewLabel.textColor = theme.foreground == NSColor.whiteColor ? NSColor.whiteColor : NSColor.labelColor;
    self.statsMonthLabel.textColor = theme.secondary;
    self.statsQualityLabel.textColor = theme.secondary;
    self.statsStandLabel.textColor = theme.secondary;
    self.statsStreakLabel.textColor = theme.secondary;
    self.exportStatsButton.contentTintColor = theme.accent;
    self.exportBackupButton.contentTintColor = theme.accent;
    for (NSTextField *label in self.pageTitleLabels) {
        label.textColor = theme.foreground == NSColor.whiteColor ? NSColor.whiteColor : NSColor.labelColor;
    }
    for (NSTextField *label in self.pageSubtitleLabels) {
        label.textColor = theme.secondary;
    }
    for (NSTextField *label in self.fieldLabels) {
        label.textColor = theme.secondary;
    }
    for (NSTextField *label in self.statsBarLabels) {
        label.textColor = theme.secondary;
    }
    for (NSTextField *label in self.heatmapLabels) {
        label.textColor = theme.secondary;
    }
    BOOL darkStyle = theme.foreground == NSColor.whiteColor;
    NSColor *rowColor = darkStyle
        ? [NSColor colorWithWhite:1 alpha:0.045]
        : [NSColor colorWithWhite:1 alpha:0.42];
    NSColor *dividerColor = darkStyle
        ? [NSColor colorWithWhite:1 alpha:0.10]
        : [theme.cardBorder colorWithAlphaComponent:0.48];
    for (NSView *row in self.settingRowViews) {
        row.layer.backgroundColor = rowColor.CGColor;
        row.layer.cornerRadius = theme.cornerRadius == 6 ? 6 : 10;
    }
    for (NSView *divider in self.settingDividerViews) {
        divider.layer.backgroundColor = dividerColor.CGColor;
    }
    [self refreshStylePreview];
}

- (void)refreshStylePreview {
    if (!self.stylePreviewShell || !self.stylePreviewCanvas) return;

    ERRestStyle style = self.settings.restStyle;
    ERTheme theme = ERThemeForStyle(style);
    BOOL darkStyle = theme.foreground == NSColor.whiteColor;
    NSColor *canvasTextColor = darkStyle ? NSColor.whiteColor : NSColor.labelColor;
    NSColor *shellBackground = [theme.settingsBackground colorWithAlphaComponent:darkStyle ? 0.48 : 0.72];
    CGFloat radius = theme.cornerRadius == 6 ? 8 : 16;

    self.stylePreviewShell.layer.backgroundColor = shellBackground.CGColor;
    self.stylePreviewShell.layer.borderColor = theme.cardBorder.CGColor;
    self.stylePreviewShell.layer.cornerRadius = radius;
    self.stylePreviewCanvas.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:0.72].CGColor;
    self.stylePreviewCanvas.layer.cornerRadius = radius;

    NSArray<CALayer *> *oldLayers = [self.stylePreviewCanvas.layer.sublayers copy];
    for (CALayer *layer in oldLayers) {
        if ([layer.name isEqualToString:@"stylePreviewGradient"]) {
            [layer removeFromSuperlayer];
        }
    }
    CAGradientLayer *gradient = ERGradientLayer(self.stylePreviewCanvas.bounds,
                                                @[theme.backgroundA, theme.backgroundB],
                                                CGPointMake(0, 0),
                                                CGPointMake(1, 1));
    gradient.name = @"stylePreviewGradient";
    gradient.cornerRadius = radius;
    [self.stylePreviewCanvas.layer insertSublayer:gradient atIndex:0];

    for (NSView *view in self.stylePreviewDecorations) {
        [view removeFromSuperview];
    }
    NSMutableArray<NSView *> *decorations = [NSMutableArray array];
    NSColor *accentSoft = [theme.accent colorWithAlphaComponent:darkStyle ? 0.34 : 0.24];
    NSColor *accentStrong = [theme.accent colorWithAlphaComponent:darkStyle ? 0.82 : 0.62];

    if (style == ERRestStylePixel) {
        NSArray<NSValue *> *frames = @[
            [NSValue valueWithRect:NSMakeRect(12, 12, 18, 18)],
            [NSValue valueWithRect:NSMakeRect(94, 50, 16, 16)],
            [NSValue valueWithRect:NSMakeRect(108, 16, 10, 10)]
        ];
        for (NSValue *value in frames) {
            NSView *block = ERRoundedView(value.rectValue, accentSoft, 1);
            [self.stylePreviewCanvas addSubview:block positioned:NSWindowBelow relativeTo:self.stylePreviewIcon];
            [decorations addObject:block];
        }
    } else {
        NSArray<NSValue *> *frames = @[
            [NSValue valueWithRect:NSMakeRect(8, 10, 28, 28)],
            [NSValue valueWithRect:NSMakeRect(94, 48, 22, 22)],
            [NSValue valueWithRect:NSMakeRect(108, 16, 10, 10)]
        ];
        for (NSInteger index = 0; index < frames.count; index++) {
            NSColor *color = index == 1 ? accentStrong : accentSoft;
            NSView *dot = ERRoundedView(frames[index].rectValue, color, frames[index].rectValue.size.width / 2.0);
            [self.stylePreviewCanvas addSubview:dot positioned:NSWindowBelow relativeTo:self.stylePreviewIcon];
            [decorations addObject:dot];
        }
    }
    self.stylePreviewDecorations = decorations;

    NSString *symbolName = @"eye";
    if (style == ERRestStyleForest) symbolName = @"leaf";
    if (style == ERRestStylePixel) symbolName = @"rectangle.grid.2x2";
    if (style == ERRestStyleToy) symbolName = @"sparkles";
    if (style == ERRestStyleNight) symbolName = @"moon.stars";
    self.stylePreviewIcon.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:ERRestStyleTitle(style)];
    self.stylePreviewIcon.contentTintColor = theme.accent;

    self.stylePreviewEyebrow.textColor = theme.secondary;
    self.stylePreviewTimer.textColor = canvasTextColor;
    self.stylePreviewTitle.stringValue = ERRestStyleTitle(style);
    self.stylePreviewTitle.textColor = darkStyle ? NSColor.whiteColor : NSColor.labelColor;
    self.stylePreviewHint.stringValue = ERRestStyleHint(style);
    self.stylePreviewHint.textColor = theme.secondary;
}

- (void)collectFieldsIntoSettings {
    self.settings.eyeEnabled = self.eyeEnabledSwitch.state == NSControlStateValueOn;
    self.settings.eyeMode = self.eyeModePopup.indexOfSelectedItem;
    self.settings.eyeFocusSeconds = [self.eyeFocusInput secondsWithMinimum:10 maximum:8 * 60 * 60];
    self.settings.eyeRestSeconds = [self.eyeRestInput secondsWithMinimum:10 maximum:60 * 60];
    self.settings.standEnabled = self.standEnabledSwitch.state == NSControlStateValueOn;
    self.settings.standIntervalSeconds = [self.standIntervalInput secondsWithMinimum:10 maximum:8 * 60 * 60];
    self.settings.standDurationSeconds = [self.standDurationInput secondsWithMinimum:10 maximum:2 * 60 * 60];
    self.settings.notificationsEnabled = self.notificationSwitch.state == NSControlStateValueOn;
    self.settings.showRestWindow = self.restWindowSwitch.state == NSControlStateValueOn;
    self.settings.launchAtLogin = self.launchAtLoginSwitch.state == NSControlStateValueOn;
    self.settings.menuBarMode = self.menuBarModePopup.indexOfSelectedItem;
    self.settings.restStyle = self.restStylePopup.indexOfSelectedItem;

    BOOL matches202020 = self.settings.eyeFocusSeconds == 20 * 60 && self.settings.eyeRestSeconds == 20;
    BOOL matchesPomodoro = self.settings.eyeFocusSeconds == 25 * 60 && self.settings.eyeRestSeconds == 5 * 60;
    if (!matches202020 && !matchesPomodoro) {
        self.settings.eyeMode = EREyeModeCustom;
    }
}

- (void)applySettings:(id)sender {
    BOOL timingChanged =
        self.settings.eyeEnabled != (self.eyeEnabledSwitch.state == NSControlStateValueOn) ||
        self.settings.eyeMode != self.eyeModePopup.indexOfSelectedItem ||
        self.settings.eyeFocusSeconds != [self.eyeFocusInput secondsWithMinimum:10 maximum:8 * 60 * 60] ||
        self.settings.eyeRestSeconds != [self.eyeRestInput secondsWithMinimum:10 maximum:60 * 60] ||
        self.settings.standEnabled != (self.standEnabledSwitch.state == NSControlStateValueOn) ||
        self.settings.standIntervalSeconds != [self.standIntervalInput secondsWithMinimum:10 maximum:8 * 60 * 60] ||
        self.settings.standDurationSeconds != [self.standDurationInput secondsWithMinimum:10 maximum:2 * 60 * 60];
    [self collectFieldsIntoSettings];
    [self.settings save];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:timingChanged];
}

- (void)toggleOnly:(id)sender {
    [self applySettings:sender];
}

- (void)eyeModeChanged:(id)sender {
    [self collectFieldsIntoSettings];
    [self.settings applyEyePreset:self.eyeModePopup.indexOfSelectedItem];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:YES];
}

- (void)use202020:(id)sender {
    [self.settings applyEyePreset:EREyeMode202020];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:YES];
}

- (void)resetDefaults:(id)sender {
    self.settings.eyeEnabled = YES;
    [self.settings applyEyePreset:EREyeMode202020];
    self.settings.standEnabled = YES;
    self.settings.standIntervalSeconds = 2 * 60 * 60;
    self.settings.standDurationSeconds = 20 * 60;
    self.settings.notificationsEnabled = YES;
    self.settings.showRestWindow = YES;
    self.settings.launchAtLogin = NO;
    self.settings.menuBarMode = ERMenuBarModeBoth;
    self.settings.restStyle = ERRestStyleBreath;
    [self.settings save];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:YES];
}

@end

@implementation ERRestWindowController

- (instancetype)initWithAppDelegate:(ERAppDelegate *)appDelegate {
    NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSRect frame = screen ? screen.frame : NSMakeRect(0, 0, 1280, 800);
    NSWindow *window = [[EROverlayWindow alloc] initWithContentRect:frame
                                                          styleMask:NSWindowStyleMaskBorderless
                                                            backing:NSBackingStoreBuffered
                                                              defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;
    self.appDelegate = appDelegate;

    window.identifier = ERRestOverlayWindowIdentifier;
    window.level = NSStatusWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary;
    window.opaque = YES;
    window.acceptsMouseMovedEvents = YES;
    window.ignoresMouseEvents = NO;
    [window setFrame:frame display:NO];

    NSView *content = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    content.wantsLayer = YES;
    window.contentView = content;
    self.backgroundView = content;

    CGFloat cardWidth = MIN(760, MAX(420, frame.size.width - 160));
    CGFloat cardHeight = MIN(520, MAX(460, frame.size.height - 120));
    self.focusCard = ERRoundedView(NSMakeRect(0, 0, cardWidth, cardHeight),
                                   [NSColor colorWithWhite:1 alpha:0.18],
                                   28);
    self.focusCard.layer.borderWidth = 1;
    self.focusCard.layer.borderColor = [NSColor colorWithWhite:1 alpha:0.24].CGColor;
    [content addSubview:self.focusCard];

    self.brandLabel = [NSTextField labelWithString:ERBrandName];
    self.brandLabel.font = [NSFont systemFontOfSize:15 weight:NSFontWeightSemibold];
    [self.focusCard addSubview:self.brandLabel];

    self.iconView = [[NSImageView alloc] initWithFrame:NSZeroRect];
    self.iconView.imageScaling = NSImageScaleProportionallyUpOrDown;
    [self.focusCard addSubview:self.iconView];

    self.titleLabel = [NSTextField labelWithString:@""];
    self.titleLabel.alignment = NSTextAlignmentCenter;
    self.titleLabel.font = [NSFont systemFontOfSize:44 weight:NSFontWeightSemibold];
    [self.focusCard addSubview:self.titleLabel];

    self.messageLabel = [NSTextField wrappingLabelWithString:@""];
    self.messageLabel.alignment = NSTextAlignmentCenter;
    self.messageLabel.font = [NSFont systemFontOfSize:18 weight:NSFontWeightRegular];
    [self.focusCard addSubview:self.messageLabel];

    self.timerLabel = [NSTextField labelWithString:@"00:20"];
    self.timerLabel.alignment = NSTextAlignmentCenter;
    self.timerLabel.font = [NSFont monospacedDigitSystemFontOfSize:82 weight:NSFontWeightMedium];
    [self.focusCard addSubview:self.timerLabel];

    self.progressIndicator = [[NSProgressIndicator alloc] initWithFrame:NSZeroRect];
    self.progressIndicator.indeterminate = NO;
    self.progressIndicator.minValue = 0;
    self.progressIndicator.maxValue = 1;
    self.progressIndicator.doubleValue = 1;
    [self.focusCard addSubview:self.progressIndicator];

    self.actionSuggestionPill = ERRoundedView(NSZeroRect, [NSColor colorWithWhite:1 alpha:0.16], 18);
    self.actionSuggestionPill.layer.borderWidth = 1;
    [self.focusCard addSubview:self.actionSuggestionPill];

    self.actionSuggestionIcon = [[NSImageView alloc] initWithFrame:NSZeroRect];
    self.actionSuggestionIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:17 weight:NSFontWeightSemibold];
    [self.actionSuggestionPill addSubview:self.actionSuggestionIcon];

    self.actionSuggestionLabel = [NSTextField wrappingLabelWithString:@""];
    self.actionSuggestionLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    self.actionSuggestionLabel.maximumNumberOfLines = 2;
    [self.actionSuggestionPill addSubview:self.actionSuggestionLabel];

    self.styleHintLabel = [NSTextField labelWithString:@""];
    self.styleHintLabel.alignment = NSTextAlignmentRight;
    self.styleHintLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    [self.focusCard addSubview:self.styleHintLabel];

    self.finishButton = [NSButton buttonWithTitle:@"完成" target:self action:@selector(finish:)];
    self.finishButton.bezelStyle = NSBezelStyleRounded;
    self.finishButton.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    self.finishButton.keyEquivalent = @"\r";
    [self.focusCard addSubview:self.finishButton];

    self.snoozeButton = [NSButton buttonWithTitle:@"稍后 5 分钟" target:self action:@selector(snooze:)];
    self.snoozeButton.bezelStyle = NSBezelStyleRounded;
    self.snoozeButton.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    [self.focusCard addSubview:self.snoozeButton];

    self.skipButton = [NSButton buttonWithTitle:@"跳过本次" target:self action:@selector(skip:)];
    self.skipButton.bezelStyle = NSBezelStyleRounded;
    self.skipButton.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    [self.focusCard addSubview:self.skipButton];

    self.extendButton = [NSButton buttonWithTitle:@"延长 1 分钟" target:self action:@selector(extend:)];
    self.extendButton.bezelStyle = NSBezelStyleRounded;
    self.extendButton.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    [self.focusCard addSubview:self.extendButton];
    [self layoutRestContent];
    return self;
}

- (void)configureForKind:(ERReminderKind)kind settings:(ERSettings *)settings duration:(NSTimeInterval)duration {
    self.kind = kind;
    self.totalDuration = MAX(1, duration);
    self.currentStyle = settings.restStyle;
    [self applyStyle:settings.restStyle];
    [self configureActionSuggestionsForKind:kind settings:settings];

    if (kind == ERReminderKindStand) {
        self.iconView.image = [NSImage imageWithSystemSymbolName:@"figure.stand" accessibilityDescription:@"Stand"];
        self.titleLabel.stringValue = @"站起来活动一下";
        self.messageLabel.stringValue = @"离开椅子，站立或轻微走动。让肩颈、腰背和注意力都换个姿势。";
        return;
    }

    if (settings.eyeMode == EREyeModePomodoro) {
        self.iconView.image = [NSImage imageWithSystemSymbolName:@"timer" accessibilityDescription:@"Pomodoro"];
        self.titleLabel.stringValue = @"番茄休息";
        self.messageLabel.stringValue = @"站起来、喝水、走几步。下一轮专注会更轻松。";
    } else {
        self.iconView.image = [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"Eye"];
        self.titleLabel.stringValue = @"看向 6 米外";
        self.messageLabel.stringValue = @"抬头眺望远方，让眼睛从屏幕焦距里出来。慢慢眨眼，至少 20 秒。";
    }
}

- (void)configureActionSuggestionsForKind:(ERReminderKind)kind settings:(ERSettings *)settings {
    if (kind == ERReminderKindStand) {
        self.actionSuggestions = @[
            @"先离开椅子，双脚踩稳地面。",
            @"肩膀向后绕 5 圈，把脖子放松。",
            @"走到窗边或倒杯水，让身体醒过来。",
            @"活动脚踝和小腿，给循环一点时间。",
            @"回来前再深呼吸 4 次。"
        ];
        self.actionSuggestionSymbols = @[@"figure.stand", @"arrow.triangle.2.circlepath", @"drop.fill", @"figure.walk", @"wind"];
    } else if (settings.eyeMode == EREyeModePomodoro) {
        self.actionSuggestions = @[
            @"先把手从键盘上拿开，离开屏幕。",
            @"喝几口水，顺便看向远处。",
            @"站起来走 20 步，让注意力重启。",
            @"回来前只想好下一件小事。"
        ];
        self.actionSuggestionSymbols = @[@"timer", @"drop.fill", @"figure.walk", @"checkmark.circle"];
    } else {
        self.actionSuggestions = @[
            @"把视线投到 6 米外，不盯屏幕边缘。",
            @"慢慢眨眼 5 次，让眼球湿润一点。",
            @"看向窗外或房间最远处，放松焦距。",
            @"肩膀落下，顺便深呼吸。"
        ];
        self.actionSuggestionSymbols = @[@"eye", @"sparkles", @"rectangle.on.rectangle", @"wind"];
    }
    self.activeSuggestionIndex = -1;
    [self updateActionSuggestionForRemaining:self.totalDuration];
}

- (void)layoutRestContent {
    NSRect bounds = self.backgroundView.bounds;
    CGFloat cardWidth = MIN(760, MAX(420, bounds.size.width - 160));
    CGFloat cardHeight = MIN(520, MAX(460, bounds.size.height - 120));
    CGFloat centerX = bounds.size.width / 2.0;
    CGFloat centerY = bounds.size.height / 2.0;
    self.focusCard.frame = NSMakeRect(centerX - cardWidth / 2.0, centerY - cardHeight / 2.0, cardWidth, cardHeight);

    CGFloat cardCenterX = cardWidth / 2.0;
    CGFloat buttonY = MAX(14, cardHeight / 2.0 - 218);
    CGFloat suggestionY = buttonY + 52;
    CGFloat progressY = suggestionY + 48;
    CGFloat timerY = progressY + 14;
    CGFloat messageY = timerY + 92;
    CGFloat titleY = messageY + 56;
    CGFloat iconY = titleY + 68;
    CGFloat pillWidth = MIN(560, cardWidth - 104);
    self.brandLabel.frame = NSMakeRect(28, cardHeight - 48, 160, 22);
    self.styleHintLabel.frame = NSMakeRect(200, cardHeight - 48, cardWidth - 228, 22);
    self.iconView.frame = NSMakeRect(cardCenterX - 44, iconY, 88, 72);
    self.titleLabel.frame = NSMakeRect(40, titleY, cardWidth - 80, 58);
    self.messageLabel.frame = NSMakeRect(68, messageY, cardWidth - 136, 48);
    self.timerLabel.frame = NSMakeRect(cardCenterX - 250, timerY, 500, 92);
    self.progressIndicator.frame = NSMakeRect(cardCenterX - 230, progressY, 460, 10);
    self.actionSuggestionPill.frame = NSMakeRect(cardCenterX - pillWidth / 2.0, suggestionY, pillWidth, 36);
    self.actionSuggestionIcon.frame = NSMakeRect(16, 8, 20, 20);
    self.actionSuggestionLabel.frame = NSMakeRect(46, 5, pillWidth - 62, 26);
    self.finishButton.frame = NSMakeRect(cardCenterX - 268, buttonY, 96, 40);
    self.snoozeButton.frame = NSMakeRect(cardCenterX - 150, buttonY, 124, 40);
    self.skipButton.frame = NSMakeRect(cardCenterX - 4, buttonY, 108, 40);
    self.extendButton.frame = NSMakeRect(cardCenterX + 126, buttonY, 132, 40);
}

- (void)refitToCurrentScreen {
    NSScreen *screen = self.window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSRect frame = screen ? screen.frame : NSMakeRect(0, 0, 1280, 800);
    [self.window setFrame:frame display:YES animate:NO];
    self.backgroundView.frame = NSMakeRect(0, 0, frame.size.width, frame.size.height);
    [self layoutRestContent];
    [self applyStyle:self.currentStyle];
}

- (void)presentOverlay {
    [self refitToCurrentScreen];
    [self showWindow:nil];
    [self.window orderFrontRegardless];
    [NSApp activateIgnoringOtherApps:YES];
    [self.window makeKeyAndOrderFront:nil];
}

- (void)applyStyle:(ERRestStyle)style {
    ERTheme theme = ERThemeForStyle(style);
    self.currentStyle = style;

    [self.backgroundView.layer.sublayers makeObjectsPerformSelector:@selector(removeFromSuperlayer)];
    [self.backgroundView.layer insertSublayer:ERGradientLayer(self.backgroundView.bounds, @[theme.backgroundA, theme.backgroundB], CGPointMake(0, 0), CGPointMake(1, 1)) atIndex:0];
    [self addDecorationsForStyle:style theme:theme];
    self.focusCard.layer.backgroundColor = [theme.card colorWithAlphaComponent:(style == ERRestStyleNight ? 0.14 : 0.24)].CGColor;
    self.focusCard.layer.borderColor = theme.cardBorder.CGColor;
    self.focusCard.layer.cornerRadius = theme.cornerRadius;
    self.iconView.contentTintColor = theme.accent;
    self.brandLabel.textColor = theme.secondary;
    self.titleLabel.textColor = theme.foreground;
    self.messageLabel.textColor = theme.secondary;
    self.timerLabel.textColor = theme.foreground;
    self.styleHintLabel.stringValue = ERRestStyleHint(style);
    self.styleHintLabel.textColor = theme.secondary;
    self.actionSuggestionPill.layer.backgroundColor = [theme.card colorWithAlphaComponent:(style == ERRestStyleNight ? 0.18 : 0.30)].CGColor;
    self.actionSuggestionPill.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:0.78].CGColor;
    self.actionSuggestionPill.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 18;
    self.actionSuggestionIcon.contentTintColor = theme.accent;
    self.actionSuggestionLabel.textColor = theme.foreground;
    self.finishButton.contentTintColor = theme.accent;
    self.snoozeButton.contentTintColor = theme.accent;
    self.skipButton.contentTintColor = theme.accent;
    self.extendButton.contentTintColor = theme.accent;
}

- (void)addDecorationsForStyle:(ERRestStyle)style theme:(ERTheme)theme {
    NSRect bounds = self.backgroundView.bounds;
    if (style == ERRestStylePixel) {
        CGFloat block = 28;
        CALayer *sun = [CALayer layer];
        sun.frame = CGRectMake(bounds.size.width - 180, bounds.size.height - 180, 76, 76);
        sun.backgroundColor = ERColor(1.00, 0.86, 0.32, 0.85).CGColor;
        [self.backgroundView.layer addSublayer:sun];
        for (NSInteger i = 0; i < 9; i++) {
            CALayer *cloud = [CALayer layer];
            cloud.frame = CGRectMake(80 + i * 42, bounds.size.height - 130 - (i % 2) * 34, block, block);
            cloud.backgroundColor = [NSColor colorWithWhite:1 alpha:0.70].CGColor;
            [self.backgroundView.layer addSublayer:cloud];
        }
        CALayer *mountain = [CALayer layer];
        mountain.frame = CGRectMake(0, 0, bounds.size.width, 120);
        mountain.backgroundColor = ERColor(0.22, 0.45, 0.36, 0.55).CGColor;
        [self.backgroundView.layer addSublayer:mountain];
    } else if (style == ERRestStyleToy) {
        NSArray<NSColor *> *colors = @[ERColor(1, 1, 1, 0.18), ERColor(1, 0.85, 0.35, 0.24), ERColor(0.55, 0.85, 1, 0.22)];
        for (NSInteger i = 0; i < 7; i++) {
            CALayer *bubble = [CALayer layer];
            CGFloat size = 80 + (i % 3) * 34;
            bubble.frame = CGRectMake(70 + i * 190, 90 + (i % 2) * 360, size, size);
            bubble.cornerRadius = size / 2.0;
            bubble.backgroundColor = [colors objectAtIndex:(i % colors.count)].CGColor;
            [self.backgroundView.layer addSublayer:bubble];
        }
        for (NSInteger i = 0; i < 5; i++) {
            CALayer *block = [CALayer layer];
            block.frame = CGRectMake(bounds.size.width - 280 + i * 46, 78 + (i % 2) * 22, 36, 36);
            block.cornerRadius = 10;
            block.backgroundColor = [colors objectAtIndex:((i + 1) % colors.count)].CGColor;
            [self.backgroundView.layer addSublayer:block];
        }
    } else if (style == ERRestStyleForest) {
        CALayer *ground = [CALayer layer];
        ground.frame = CGRectMake(0, 0, bounds.size.width, 96);
        ground.backgroundColor = ERColor(0.05, 0.20, 0.12, 0.42).CGColor;
        [self.backgroundView.layer addSublayer:ground];
        for (NSInteger i = 0; i < 8; i++) {
            CALayer *tree = [CALayer layer];
            tree.frame = CGRectMake(40 + i * 180, 0, 80, 180 + (i % 3) * 40);
            tree.backgroundColor = ERColor(0.04, 0.18, 0.11, 0.30).CGColor;
            tree.cornerRadius = 38;
            [self.backgroundView.layer addSublayer:tree];
        }
    } else if (style == ERRestStyleNight) {
        CALayer *moon = [CALayer layer];
        moon.frame = CGRectMake(bounds.size.width - 190, bounds.size.height - 170, 82, 82);
        moon.cornerRadius = 41;
        moon.backgroundColor = ERColor(0.88, 0.92, 1.00, 0.78).CGColor;
        [self.backgroundView.layer addSublayer:moon];
        for (NSInteger i = 0; i < 30; i++) {
            CALayer *star = [CALayer layer];
            CGFloat size = 2 + (i % 3);
            star.frame = CGRectMake(40 + (i * 97) % (NSInteger)bounds.size.width, 80 + (i * 53) % (NSInteger)(bounds.size.height - 120), size, size);
            star.cornerRadius = size / 2;
            star.backgroundColor = [NSColor colorWithWhite:1 alpha:0.55].CGColor;
            [self.backgroundView.layer addSublayer:star];
        }
    }
}

- (void)updateRemaining:(NSTimeInterval)remaining {
    self.timerLabel.stringValue = ERFormatDuration(remaining);
    self.progressIndicator.doubleValue = MAX(0, MIN(1, remaining / MAX(1, self.totalDuration)));
    [self updateActionSuggestionForRemaining:remaining];
}

- (void)updateActionSuggestionForRemaining:(NSTimeInterval)remaining {
    NSInteger count = self.actionSuggestions.count;
    if (count <= 0) return;

    NSTimeInterval elapsed = MAX(0, self.totalDuration - MAX(0, remaining));
    CGFloat ratio = MIN(0.999, MAX(0, elapsed / MAX(1, self.totalDuration)));
    NSInteger index = MIN(count - 1, (NSInteger)floor(ratio * count));
    if (index == self.activeSuggestionIndex) return;

    self.activeSuggestionIndex = index;
    NSString *suggestion = self.actionSuggestions[index];
    self.actionSuggestionLabel.stringValue = [NSString stringWithFormat:@"建议 %ld/%ld · %@",
                                              (long)index + 1,
                                              (long)count,
                                              suggestion];

    NSString *symbolName = index < self.actionSuggestionSymbols.count ? self.actionSuggestionSymbols[index] : @"sparkles";
    self.actionSuggestionIcon.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"动作建议"];
}

- (void)finish:(id)sender {
    [self close];
    [self.appDelegate finishRestForKind:self.kind];
}

- (void)extend:(id)sender {
    [self.appDelegate extendRestForKind:self.kind bySeconds:60];
}

- (void)snooze:(id)sender {
    [self close];
    [self.appDelegate snoozeRestForKind:self.kind bySeconds:5 * 60];
}

- (void)skip:(id)sender {
    [self close];
    [self.appDelegate skipRestForKind:self.kind];
}

@end

@implementation ERAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
    self.settings = [ERSettings load];

    UNUserNotificationCenter.currentNotificationCenter.delegate = self;
    [UNUserNotificationCenter.currentNotificationCenter requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionSound
                                                                      completionHandler:^(BOOL granted, NSError * _Nullable error) {}];

    self.statusItem = [NSStatusBar.systemStatusBar statusItemWithLength:NSVariableStatusItemLength];
    self.statusItem.button.image = [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:ERBrandName];
    self.statusItem.button.imagePosition = NSImageLeft;

    [self loadTodayStats];
    [self rebuildMenu];
    [self resetAllTimers];
    [self applyPreferenceSideEffects];

    self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(tick:) userInfo:nil repeats:YES];
    [NSRunLoop.mainRunLoop addTimer:self.timer forMode:NSRunLoopCommonModes];

    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(workspaceDidWake:)
                                                           name:NSWorkspaceDidWakeNotification
                                                         object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(workspaceWillSuspend:)
                                                           name:NSWorkspaceWillSleepNotification
                                                         object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(workspaceDidWake:)
                                                           name:NSWorkspaceScreensDidWakeNotification
                                                         object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(workspaceWillSuspend:)
                                                           name:NSWorkspaceScreensDidSleepNotification
                                                         object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(workspaceDidWake:)
                                                           name:NSWorkspaceSessionDidBecomeActiveNotification
                                                         object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(workspaceWillSuspend:)
                                                           name:NSWorkspaceSessionDidResignActiveNotification
                                                         object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(screenParametersChanged:)
                                               name:NSApplicationDidChangeScreenParametersNotification
                                             object:nil];
}

- (void)loadTodayStats {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *today = ERTodayKey();
    NSString *savedDate = [defaults stringForKey:ERStatsDateKey];
    if (![savedDate isEqualToString:today]) {
        self.todayEyeDone = 0;
        self.todayStandDone = 0;
        self.todayStandSeconds = 0;
        self.todaySnoozed = 0;
        self.todaySkipped = 0;
        [self saveTodayStats];
        return;
    }
    self.todayEyeDone = [defaults integerForKey:ERStatsEyeDoneKey];
    self.todayStandDone = [defaults integerForKey:ERStatsStandDoneKey];
    self.todayStandSeconds = [defaults integerForKey:ERStatsStandSecondsKey];
    self.todaySnoozed = [defaults integerForKey:ERStatsSnoozedKey];
    self.todaySkipped = [defaults integerForKey:ERStatsSkippedKey];
}

- (void)saveTodayStats {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:ERTodayKey() forKey:ERStatsDateKey];
    [defaults setInteger:self.todayEyeDone forKey:ERStatsEyeDoneKey];
    [defaults setInteger:self.todayStandDone forKey:ERStatsStandDoneKey];
    [defaults setInteger:self.todayStandSeconds forKey:ERStatsStandSecondsKey];
    [defaults setInteger:self.todaySnoozed forKey:ERStatsSnoozedKey];
    [defaults setInteger:self.todaySkipped forKey:ERStatsSkippedKey];

    NSMutableDictionary *history = [[defaults dictionaryForKey:ERStatsHistoryKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *today = ERTodayKey();
    history[today] = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped)
    };

    NSSet *recent = [NSSet setWithArray:ERRecentDateKeys(30)];
    for (NSString *dateKey in history.allKeys) {
        if (![recent containsObject:dateKey]) {
            [history removeObjectForKey:dateKey];
        }
    }
    [defaults setObject:history forKey:ERStatsHistoryKey];
}

- (void)resetTodayStatsIfNeeded {
    NSString *savedDate = [NSUserDefaults.standardUserDefaults stringForKey:ERStatsDateKey];
    if (![savedDate isEqualToString:ERTodayKey()]) {
        [self loadTodayStats];
    }
}

- (NSDictionary *)statsHistoryIncludingToday {
    NSMutableDictionary *history = [[NSUserDefaults.standardUserDefaults dictionaryForKey:ERStatsHistoryKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    history[ERTodayKey()] = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped)
    };
    return history;
}

- (void)applyPreferenceSideEffects {
    ERApplyLaunchAtLogin(self.settings.launchAtLogin);
    [self updateStatusItemAppearance];
}

- (void)workspaceDidWake:(NSNotification *)notification {
    [self repairRestOverlayAfterDisplayChange];
}

- (void)workspaceWillSuspend:(NSNotification *)notification {
    if (self.restWindowController) {
        [self.restWindowController.window orderOut:nil];
    }
    [self publishState];
}

- (void)screenParametersChanged:(NSNotification *)notification {
    [self repairRestOverlayAfterDisplayChange];
}

- (void)repairRestOverlayAfterDisplayChange {
    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    if (!self.restWindowController) {
        [self publishState];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self settleExpiredRests];
        [self repairRestStateIfNeeded];
        if (!self.restWindowController) return;
        [self.restWindowController presentOverlay];
        [self publishState];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self settleExpiredRests];
        [self repairRestStateIfNeeded];
        if (!self.restWindowController) return;
        [self.restWindowController presentOverlay];
        [self publishState];
    });
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (void)rebuildMenu {
    self.menu = [[NSMenu alloc] initWithTitle:ERBrandName];
    self.menu.delegate = self;
    self.statusItem.menu = self.menu;
    [self.menu removeAllItems];

    NSMenuItem *status = [[NSMenuItem alloc] initWithTitle:@"启动中" action:nil keyEquivalent:@""];
    status.tag = 100;
    status.enabled = NO;
    [self.menu addItem:status];
    [self.menu addItem:NSMenuItem.separatorItem];

    NSMenuItem *eyeStatus = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    eyeStatus.tag = 101;
    eyeStatus.enabled = NO;
    [self.menu addItem:eyeStatus];

    NSMenuItem *standStatus = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    standStatus.tag = 102;
    standStatus.enabled = NO;
    [self.menu addItem:standStatus];

    NSMenuItem *todayStats = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    todayStats.tag = 106;
    todayStats.enabled = NO;
    [self.menu addItem:todayStats];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"打开设置..." action:@selector(openSettings:) keyEquivalent:@","];
    settings.target = self;
    [self.menu addItem:settings];

    NSMenuItem *pause = [[NSMenuItem alloc] initWithTitle:@"暂停" action:@selector(togglePause:) keyEquivalent:@"p"];
    pause.target = self;
    pause.tag = 103;
    [self.menu addItem:pause];

    NSMenu *pauseMenu = [[NSMenu alloc] initWithTitle:@"暂停提醒"];
    NSArray<NSArray *> *pauseItems = @[
        @[@"暂停 30 分钟", @(30 * 60), @"pauseFor:"],
        @[@"暂停 1 小时", @(60 * 60), @"pauseFor:"],
        @[@"今天不提醒", @(0), @"pauseToday:"]
    ];
    for (NSArray *itemInfo in pauseItems) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:itemInfo[0] action:NSSelectorFromString(itemInfo[2]) keyEquivalent:@""];
        item.target = self;
        item.representedObject = itemInfo[1];
        [pauseMenu addItem:item];
    }
    NSMenuItem *pauseGroup = [[NSMenuItem alloc] initWithTitle:@"暂停提醒" action:nil keyEquivalent:@""];
    pauseGroup.submenu = pauseMenu;
    [self.menu addItem:pauseGroup];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *eyeNow = [[NSMenuItem alloc] initWithTitle:@"眼睛：现在休息" action:@selector(restEyeNow:) keyEquivalent:@"e"];
    eyeNow.target = self;
    [self.menu addItem:eyeNow];

    NSMenuItem *eyeSnooze = [[NSMenuItem alloc] initWithTitle:@"眼睛稍后 5 分钟" action:@selector(snoozeEyeFive:) keyEquivalent:@""];
    eyeSnooze.target = self;
    [self.menu addItem:eyeSnooze];

    NSMenuItem *eyeSkip = [[NSMenuItem alloc] initWithTitle:@"眼睛跳过本次" action:@selector(skipEye:) keyEquivalent:@""];
    eyeSkip.target = self;
    [self.menu addItem:eyeSkip];

    NSMenuItem *standNow = [[NSMenuItem alloc] initWithTitle:@"站立：现在开始" action:@selector(restStandNow:) keyEquivalent:@"s"];
    standNow.target = self;
    [self.menu addItem:standNow];

    NSMenuItem *standSnooze = [[NSMenuItem alloc] initWithTitle:@"站立稍后 5 分钟" action:@selector(snoozeStandFive:) keyEquivalent:@""];
    standSnooze.target = self;
    [self.menu addItem:standSnooze];

    NSMenuItem *standSkip = [[NSMenuItem alloc] initWithTitle:@"站立跳过本次" action:@selector(skipStand:) keyEquivalent:@""];
    standSkip.target = self;
    [self.menu addItem:standSkip];

    NSMenuItem *reset = [[NSMenuItem alloc] initWithTitle:@"重新开始全部计时" action:@selector(resetAllAction:) keyEquivalent:@"n"];
    reset.target = self;
    [self.menu addItem:reset];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *notifications = [[NSMenuItem alloc] initWithTitle:@"系统通知" action:@selector(toggleNotifications:) keyEquivalent:@""];
    notifications.target = self;
    notifications.tag = 104;
    [self.menu addItem:notifications];

    NSMenuItem *window = [[NSMenuItem alloc] initWithTitle:@"提醒窗口" action:@selector(toggleRestWindow:) keyEquivalent:@""];
    window.target = self;
    window.tag = 105;
    [self.menu addItem:window];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"退出 %@", ERBrandName] action:@selector(terminate:) keyEquivalent:@"q"];
    quit.target = NSApp;
    [self.menu addItem:quit];
    [self refreshMenuOnly];
}

- (NSTimeInterval)remainingUntil:(NSDate *)date {
    if (!date) return 0;
    NSDate *reference = self.paused ? self.pauseStartedAt : NSDate.date;
    return MAX(0, [date timeIntervalSinceDate:reference]);
}

- (void)resetAllTimers {
    [self resetEyeTimer];
    [self resetStandTimer];
    [self.restWindowController close];
    self.restWindowController = nil;
    [self publishState];
}

- (void)resetEyeTimer {
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil;
}

- (void)resetStandTimer {
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.standDueAt = self.settings.standEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.standIntervalSeconds] : nil;
}

- (void)tick:(NSTimer *)timer {
    [self resetTodayStatsIfNeeded];
    if (self.pausedUntil && [self.pausedUntil timeIntervalSinceNow] <= 0) {
        [self resumeFromPause];
    }
    if (!self.paused) {
        [self evaluateReminderKind:ERReminderKindEye];
        [self evaluateReminderKind:ERReminderKindStand];
        [self repairRestStateIfNeeded];
    }
    [self publishState];
}

- (void)settleExpiredRests {
    if (self.paused) return;
    NSDate *now = NSDate.date;
    if (self.eyeResting && self.eyeRestEndsAt && [self.eyeRestEndsAt timeIntervalSinceDate:now] <= 0) {
        [self finishRestForKind:ERReminderKindEye];
    }
    if (self.standResting && self.standRestEndsAt && [self.standRestEndsAt timeIntervalSinceDate:now] <= 0) {
        [self finishRestForKind:ERReminderKindStand];
    }
}

- (NSTimeInterval)configuredRestDurationForKind:(ERReminderKind)kind {
    return kind == ERReminderKindEye ? self.settings.eyeRestSeconds : self.settings.standDurationSeconds;
}

- (NSDate *)restEndDateForKind:(ERReminderKind)kind {
    return kind == ERReminderKindEye ? self.eyeRestEndsAt : self.standRestEndsAt;
}

- (void)ensureRestWindowForKind:(ERReminderKind)kind remaining:(NSTimeInterval)remaining {
    if (!self.settings.showRestWindow || remaining <= 0) return;
    [self.settingsWindowController close];
    [self.restWindowController close];
    self.restWindowController = [[ERRestWindowController alloc] initWithAppDelegate:self];
    [self.restWindowController configureForKind:kind
                                       settings:self.settings
                                       duration:[self configuredRestDurationForKind:kind]];
    [self.restWindowController updateRemaining:remaining];
    [self.restWindowController presentOverlay];
}

- (void)repairRestStateIfNeeded {
    if (self.paused) return;

    [self closeOrphanRestWindows];
    [self settleExpiredRests];

    if (self.eyeResting && !self.settings.eyeEnabled) {
        self.eyeResting = NO;
        self.eyeRestEndsAt = nil;
    }
    if (self.standResting && !self.settings.standEnabled) {
        self.standResting = NO;
        self.standRestEndsAt = nil;
    }

    if (self.eyeResting && self.standResting) {
        ERReminderKind keepKind = self.restWindowController
            ? self.restWindowController.kind
            : ([self remainingUntil:self.eyeRestEndsAt] <= [self remainingUntil:self.standRestEndsAt] ? ERReminderKindEye : ERReminderKindStand);
        if (keepKind == ERReminderKindEye) {
            self.standResting = NO;
            self.standRestEndsAt = nil;
            self.standDueAt = self.settings.standEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.standIntervalSeconds] : nil;
        } else {
            self.eyeResting = NO;
            self.eyeRestEndsAt = nil;
            self.eyeDueAt = self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil;
        }
    }

    BOOL eyeActive = self.eyeResting && self.settings.eyeEnabled;
    BOOL standActive = self.standResting && self.settings.standEnabled;
    if (!eyeActive && !standActive) {
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        return;
    }

    ERReminderKind activeKind = eyeActive ? ERReminderKindEye : ERReminderKindStand;
    NSDate *endDate = [self restEndDateForKind:activeKind];
    if (!endDate) {
        if (activeKind == ERReminderKindEye) {
            [self resetEyeTimer];
        } else {
            [self resetStandTimer];
        }
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        return;
    }

    NSTimeInterval remaining = [self remainingUntil:endDate];
    if (remaining <= 0) {
        [self finishRestForKind:activeKind];
        return;
    }

    if (!self.settings.showRestWindow) {
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        return;
    }

    if (!self.restWindowController || self.restWindowController.kind != activeKind) {
        [self ensureRestWindowForKind:activeKind remaining:remaining];
        return;
    }

    [self.restWindowController updateRemaining:remaining];
    if (!self.restWindowController.window.visible || !self.restWindowController.window.screen) {
        [self.restWindowController presentOverlay];
    }
    [self closeOrphanRestWindows];
}

- (void)closeOrphanRestWindows {
    NSWindow *activeWindow = self.restWindowController.window;
    for (NSWindow *window in [NSApp.windows copy]) {
        if (window == activeWindow) continue;
        if ([window.identifier isEqualToString:ERRestOverlayWindowIdentifier]) {
            [window close];
        }
    }
}

- (void)evaluateReminderKind:(ERReminderKind)kind {
    BOOL enabled = kind == ERReminderKindEye ? self.settings.eyeEnabled : self.settings.standEnabled;
    if (!enabled) return;

    BOOL resting = kind == ERReminderKindEye ? self.eyeResting : self.standResting;
    BOOL otherResting = kind == ERReminderKindEye ? self.standResting : self.eyeResting;
    NSDate *date = resting
        ? (kind == ERReminderKindEye ? self.eyeRestEndsAt : self.standRestEndsAt)
        : (kind == ERReminderKindEye ? self.eyeDueAt : self.standDueAt);
    if ([self remainingUntil:date] > 0) return;

    if (resting) {
        [self finishRestForKind:kind];
    } else {
        if (otherResting) return;
        [self beginRestForKind:kind];
    }
}

- (void)beginRestForKind:(ERReminderKind)kind {
    NSTimeInterval duration = kind == ERReminderKindEye ? self.settings.eyeRestSeconds : self.settings.standDurationSeconds;
    if (kind == ERReminderKindEye) {
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:duration];
    } else {
        self.standResting = YES;
        self.standRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:duration];
    }

    [self showNotificationForKind:kind duration:duration];
    if (self.settings.showRestWindow) {
        [self.settingsWindowController close];
        [self.restWindowController close];
        self.restWindowController = nil;
        self.restWindowController = [[ERRestWindowController alloc] initWithAppDelegate:self];
        [self.restWindowController configureForKind:kind settings:self.settings duration:duration];
        [self.restWindowController updateRemaining:duration];
        [self.restWindowController presentOverlay];
    }
}

- (void)finishRestForKind:(ERReminderKind)kind {
    if (kind == ERReminderKindEye && self.eyeResting) {
        self.todayEyeDone += 1;
    }
    if (kind == ERReminderKindStand && self.standResting) {
        self.todayStandDone += 1;
        self.todayStandSeconds += self.settings.standDurationSeconds;
    }
    [self saveTodayStats];

    if (kind == ERReminderKindEye) {
        [self resetEyeTimer];
    } else {
        [self resetStandTimer];
    }

    if (self.restWindowController.kind == kind) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self.settingsWindowController refreshStats];
    [self publishState];
}

- (void)snoozeRestForKind:(ERReminderKind)kind bySeconds:(NSTimeInterval)seconds {
    self.todaySnoozed += 1;
    [self saveTodayStats];

    if (kind == ERReminderKindEye) {
        self.eyeResting = NO;
        self.eyeRestEndsAt = nil;
        self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:seconds];
    } else {
        self.standResting = NO;
        self.standRestEndsAt = nil;
        self.standDueAt = [NSDate dateWithTimeIntervalSinceNow:seconds];
    }
    if (self.restWindowController.kind == kind) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self.settingsWindowController refreshStats];
    [self publishState];
}

- (void)skipRestForKind:(ERReminderKind)kind {
    self.todaySkipped += 1;
    [self saveTodayStats];

    if (kind == ERReminderKindEye) {
        [self resetEyeTimer];
    } else {
        [self resetStandTimer];
    }
    if (self.restWindowController.kind == kind) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self.settingsWindowController refreshStats];
    [self publishState];
}

- (void)extendRestForKind:(ERReminderKind)kind bySeconds:(NSTimeInterval)seconds {
    if (kind == ERReminderKindEye && self.eyeResting) {
        self.eyeRestEndsAt = [self.eyeRestEndsAt dateByAddingTimeInterval:seconds];
    }
    if (kind == ERReminderKindStand && self.standResting) {
        self.standRestEndsAt = [self.standRestEndsAt dateByAddingTimeInterval:seconds];
    }
    [self publishState];
}

- (void)showNotificationForKind:(ERReminderKind)kind duration:(NSTimeInterval)duration {
    if (!self.settings.notificationsEnabled) return;

    UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
    if (kind == ERReminderKindStand) {
        content.title = @"该站起来了";
        content.body = [NSString stringWithFormat:@"站立或走动 %@，给身体换个姿势。", ERFormatDuration(duration)];
    } else if (self.settings.eyeMode == EREyeModePomodoro) {
        content.title = @"番茄休息时间";
        content.body = [NSString stringWithFormat:@"离开屏幕 %@，回来再继续。", ERFormatDuration(duration)];
    } else {
        content.title = @"该抬头看看远处了";
        content.body = [NSString stringWithFormat:@"眺望 6 米外 %@，让眼睛放松一下。", ERFormatDuration(duration)];
    }
    content.sound = UNNotificationSound.defaultSound;

    NSString *identifier = [NSString stringWithFormat:@"eyerest-%@", NSUUID.UUID.UUIDString];
    UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier content:content trigger:nil];
    [UNUserNotificationCenter.currentNotificationCenter addNotificationRequest:request withCompletionHandler:nil];
}

- (void)publishState {
    [self updateStatusItemAppearance];

    if (self.restWindowController) {
        NSDate *date = self.restWindowController.kind == ERReminderKindEye ? self.eyeRestEndsAt : self.standRestEndsAt;
        [self.restWindowController updateRemaining:[self remainingUntil:date]];
    }
    [self refreshMenuOnly];
}

- (void)updateStatusItemAppearance {
    NSTimeInterval eyeRemaining = [self remainingUntil:(self.eyeResting ? self.eyeRestEndsAt : self.eyeDueAt)];
    NSTimeInterval standRemaining = [self remainingUntil:(self.standResting ? self.standRestEndsAt : self.standDueAt)];
    NSString *eyeText = self.settings.eyeEnabled ? ERFormatDuration(eyeRemaining) : @"关";
    NSString *standText = self.settings.standEnabled ? ERFormatDuration(standRemaining) : @"关";
    NSString *title = @"";

    if (self.paused) {
        title = self.settings.menuBarMode == ERMenuBarModeCompact ? @"" : @" 暂停";
    } else {
        switch (self.settings.menuBarMode) {
            case ERMenuBarModeBoth:
                title = [NSString stringWithFormat:@" 眼 %@ 站 %@", eyeText, standText];
                break;
            case ERMenuBarModeEye:
                title = [NSString stringWithFormat:@" 眼 %@", eyeText];
                break;
            case ERMenuBarModeStand:
                title = [NSString stringWithFormat:@" 站 %@", standText];
                break;
            case ERMenuBarModeCompact:
                title = @"";
                break;
            case ERMenuBarModeSmart: {
                if (self.eyeResting && self.settings.eyeEnabled) {
                    title = [NSString stringWithFormat:@" 眼休 %@", ERFormatMenuBarShortDuration(eyeRemaining)];
                } else if (self.standResting && self.settings.standEnabled) {
                    title = [NSString stringWithFormat:@" 站立 %@", ERFormatMenuBarShortDuration(standRemaining)];
                } else if (self.settings.eyeEnabled && eyeRemaining <= 5 * 60) {
                    title = [NSString stringWithFormat:@" 眼 %@", ERFormatMenuBarShortDuration(eyeRemaining)];
                } else if (self.settings.standEnabled && standRemaining <= 5 * 60) {
                    title = [NSString stringWithFormat:@" 站 %@", ERFormatMenuBarShortDuration(standRemaining)];
                } else if (self.settings.eyeEnabled && self.settings.standEnabled) {
                    NSInteger phase = ((NSInteger)[NSDate.date timeIntervalSince1970] / 20) % 2;
                    title = phase == 0
                        ? [NSString stringWithFormat:@" 眼 %@", ERFormatMenuBarShortDuration(eyeRemaining)]
                        : [NSString stringWithFormat:@" 站 %@", ERFormatMenuBarShortDuration(standRemaining)];
                } else if (self.settings.eyeEnabled) {
                    title = [NSString stringWithFormat:@" 眼 %@", ERFormatMenuBarShortDuration(eyeRemaining)];
                } else if (self.settings.standEnabled) {
                    title = [NSString stringWithFormat:@" 站 %@", ERFormatMenuBarShortDuration(standRemaining)];
                } else {
                    title = @" 关";
                }
                break;
            }
        }
    }
    self.statusItem.button.title = title;
}

- (void)refreshMenuOnly {
    NSMenuItem *status = [self.menu itemWithTag:100];
    if (self.pausedUntil) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm";
        status.title = [NSString stringWithFormat:@"暂停到 %@", [formatter stringFromDate:self.pausedUntil]];
    } else {
        status.title = self.paused ? @"已暂停" : @"节奏运行中";
    }

    NSMenuItem *eyeStatus = [self.menu itemWithTag:101];
    eyeStatus.title = self.settings.eyeEnabled
        ? [NSString stringWithFormat:@"眼睛：%@ %@", self.eyeResting ? @"休息中" : EREyeModeTitle(self.settings.eyeMode), ERFormatDuration([self remainingUntil:(self.eyeResting ? self.eyeRestEndsAt : self.eyeDueAt)])]
        : @"眼睛：已关闭";

    NSMenuItem *standStatus = [self.menu itemWithTag:102];
    standStatus.title = self.settings.standEnabled
        ? [NSString stringWithFormat:@"站立：%@ %@", self.standResting ? @"站立中" : @"下次提醒", ERFormatDuration([self remainingUntil:(self.standResting ? self.standRestEndsAt : self.standDueAt)])]
        : @"站立：已关闭";

    NSMenuItem *todayStats = [self.menu itemWithTag:106];
    todayStats.title = [NSString stringWithFormat:@"今天：眼睛 %ld 次 · 站立 %ld 次 · 稍后 %ld · 跳过 %ld",
                        (long)self.todayEyeDone,
                        (long)self.todayStandDone,
                        (long)self.todaySnoozed,
                        (long)self.todaySkipped];

    NSMenuItem *pause = [self.menu itemWithTag:103];
    pause.title = self.paused ? @"继续" : @"暂停";

    NSMenuItem *notifications = [self.menu itemWithTag:104];
    notifications.state = self.settings.notificationsEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *window = [self.menu itemWithTag:105];
    window.state = self.settings.showRestWindow ? NSControlStateValueOn : NSControlStateValueOff;
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center
       willPresentNotification:(UNNotification *)notification
         withCompletionHandler:(void (^)(UNNotificationPresentationOptions options))completionHandler {
    completionHandler(UNNotificationPresentationOptionBanner | UNNotificationPresentationOptionSound);
}

- (void)settingsDidChangeShouldReset:(BOOL)shouldReset {
    [self applyPreferenceSideEffects];
    [self rebuildMenu];
    [self.settingsWindowController refreshControls];
    if (shouldReset) {
        [self resetAllTimers];
    } else {
        [self publishState];
    }
}

- (void)resumeFromPause {
    NSTimeInterval pausedDuration = [NSDate.date timeIntervalSinceDate:self.pauseStartedAt];
    for (NSString *key in @[@"eyeDueAt", @"eyeRestEndsAt", @"standDueAt", @"standRestEndsAt"]) {
        NSDate *date = [self valueForKey:key];
        if (date) [self setValue:[date dateByAddingTimeInterval:pausedDuration] forKey:key];
    }
    self.pauseStartedAt = nil;
    self.paused = NO;
    self.pausedUntil = nil;
}

- (void)togglePause:(id)sender {
    if (self.paused) {
        [self resumeFromPause];
    } else {
        self.pauseStartedAt = NSDate.date;
        self.paused = YES;
    }
    [self publishState];
}

- (void)pauseFor:(NSMenuItem *)sender {
    NSTimeInterval seconds = [sender.representedObject doubleValue];
    self.paused = YES;
    self.pauseStartedAt = NSDate.date;
    self.pausedUntil = [NSDate dateWithTimeIntervalSinceNow:seconds];
    [self publishState];
}

- (void)pauseToday:(id)sender {
    NSCalendar *calendar = NSCalendar.currentCalendar;
    NSDate *now = NSDate.date;
    NSDateComponents *components = [calendar components:NSCalendarUnitYear | NSCalendarUnitMonth | NSCalendarUnitDay fromDate:now];
    components.day += 1;
    self.paused = YES;
    self.pauseStartedAt = now;
    self.pausedUntil = [calendar dateFromComponents:components];
    [self publishState];
}

- (void)restEyeNow:(id)sender {
    if (!self.settings.eyeEnabled) return;
    [self beginRestForKind:ERReminderKindEye];
    [self publishState];
}

- (void)restStandNow:(id)sender {
    if (!self.settings.standEnabled) return;
    [self beginRestForKind:ERReminderKindStand];
    [self publishState];
}

- (void)snoozeEyeFive:(id)sender {
    [self snoozeRestForKind:ERReminderKindEye bySeconds:5 * 60];
}

- (void)snoozeStandFive:(id)sender {
    [self snoozeRestForKind:ERReminderKindStand bySeconds:5 * 60];
}

- (void)skipEye:(id)sender {
    [self skipRestForKind:ERReminderKindEye];
}

- (void)skipStand:(id)sender {
    [self skipRestForKind:ERReminderKindStand];
}

- (void)resetAllAction:(id)sender {
    [self resetAllTimers];
}

- (void)openSettings:(id)sender {
    if (!self.settingsWindowController) {
        self.settingsWindowController = [[ERSettingsWindowController alloc] initWithSettings:self.settings appDelegate:self];
    }
    [self.settingsWindowController refreshControls];
    [self.settingsWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [self.settingsWindowController.window makeKeyAndOrderFront:nil];
    [self.settingsWindowController.window orderFrontRegardless];
}

- (void)toggleNotifications:(id)sender {
    self.settings.notificationsEnabled = !self.settings.notificationsEnabled;
    [self.settings save];
    [self.settingsWindowController refreshControls];
    [self publishState];
}

- (void)toggleRestWindow:(id)sender {
    self.settings.showRestWindow = !self.settings.showRestWindow;
    [self.settings save];
    [self.settingsWindowController refreshControls];
    [self publishState];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (!ERAcquireSingleInstanceLock()) {
            return 0;
        }
        NSApplication *application = NSApplication.sharedApplication;
        ERAppDelegate *delegate = [[ERAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
