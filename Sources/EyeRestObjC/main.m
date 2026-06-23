#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#import <EventKit/EventKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Carbon/Carbon.h>
#import <objc/runtime.h>
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

typedef NS_ENUM(NSInteger, ERStandRoutine) {
    ERStandRoutineBalanced = 0,
    ERStandRoutineNeckShoulder = 1,
    ERStandRoutineWalk = 2,
    ERStandRoutineReset = 3
};

typedef NS_ENUM(NSInteger, ERStandIntensity) {
    ERStandIntensityGentle = 0,
    ERStandIntensityStandard = 1,
    ERStandIntensityActive = 2
};

static NSString *const ERSettingsEyeEnabledKey = @"eyeEnabled";
static NSString *const ERSettingsEyeModeKey = @"eyeMode";
static NSString *const ERSettingsEyeFocusSecondsKey = @"eyeFocusSeconds";
static NSString *const ERSettingsEyeRestSecondsKey = @"eyeRestSeconds";
static NSString *const ERSettingsStandEnabledKey = @"standEnabled";
static NSString *const ERSettingsStandIntervalSecondsKey = @"standIntervalSeconds";
static NSString *const ERSettingsStandDurationSecondsKey = @"standDurationSeconds";
static NSString *const ERSettingsStandRoutineKey = @"standRoutine";
static NSString *const ERSettingsStandIntensityKey = @"standIntensity";
static NSString *const ERSettingsStandCustomStagesKey = @"standCustomStages";
static NSString *const ERSettingsShowRestWindowKey = @"showRestWindow";
static NSString *const ERSettingsRestWindowTopmostKey = @"restWindowTopmost";
static NSString *const ERSettingsNotificationsKey = @"notificationsEnabled";
static NSString *const ERSettingsRestStyleKey = @"restStyle";
static NSString *const ERSettingsMenuBarModeKey = @"menuBarMode";
static NSString *const ERSettingsLaunchAtLoginKey = @"launchAtLogin";
static NSString *const ERSettingsAutoFocusModeKey = @"autoFocusModeEnabled";
static NSString *const ERSettingsCalendarFocusModeKey = @"calendarFocusModeEnabled";
static NSString *const ERSettingsPresentationFocusModeKey = @"presentationFocusModeEnabled";
static NSString *const ERSettingsFocusAppTokensKey = @"focusAppTokens";
static NSString *const ERSettingsAutoPauseAppTokensKey = @"autoPauseAppTokens";
static NSString *const ERSettingsIgnoreAppTokensKey = @"ignoreAppTokens";
static NSString *const ERSettingsCalendarFocusTokensKey = @"calendarFocusTokens";
static NSString *const ERSettingsCalendarAutoPauseTokensKey = @"calendarAutoPauseTokens";
static NSString *const ERSettingsQuietHoursEnabledKey = @"quietHoursEnabled";
static NSString *const ERSettingsQuietHoursStartKey = @"quietHoursStartMinute";
static NSString *const ERSettingsQuietHoursEndKey = @"quietHoursEndMinute";
static NSString *const ERSettingsQuickSetupSeenKey = @"quickSetupSeen";
static NSString *const ERStatsDateKey = @"statsDate";
static NSString *const ERStatsEyeDoneKey = @"statsEyeDone";
static NSString *const ERStatsStandDoneKey = @"statsStandDone";
static NSString *const ERStatsStandSecondsKey = @"statsStandSeconds";
static NSString *const ERStatsSnoozedKey = @"statsSnoozed";
static NSString *const ERStatsSkippedKey = @"statsSkipped";
static NSString *const ERStatsManualDoneKey = @"statsManualDone";
static NSString *const ERStatsNotificationOnlyKey = @"statsNotificationOnly";
static NSString *const ERStatsAutoPauseSessionsKey = @"statsAutoPauseSessions";
static NSString *const ERStatsAutoPauseSecondsKey = @"statsAutoPauseSeconds";
static NSString *const ERStatsHistoryKey = @"statsHistory";
static NSString *const ERLastAutomationActionTextKey = @"lastAutomationActionText";
static NSString *const ERLastAutomationActionAtKey = @"lastAutomationActionAt";
static NSString *const ERRecoveryHistoryKey = @"recoveryHistory";
static NSString *const ERBrandName = @"松一下";
static NSString *const ERGitHubURLString = @"https://github.com/passionate11/-";
static NSString *const ERNewIssueURLString = @"https://github.com/passionate11/-/issues/new";
static NSString *const ERLatestReleaseURLString = @"https://github.com/passionate11/-/releases/latest";
static NSString *const ERLatestReleaseAPIURLString = @"https://api.github.com/repos/passionate11/-/releases/latest";
static NSString *const ERAutomationURLScheme = @"songyixia";
static NSString *const ERRestOverlayWindowIdentifier = @"local.codex.eyerest.rest-overlay";
static NSString *const EROpenSettingsNotificationName = @"local.codex.eyerest.open-settings";
static NSString *const ERRunRecoveryStressTestNotificationName = @"local.codex.eyerest.run-recovery-stress-test";
static const NSUInteger ERRecoveryHistoryLimit = 80;
static int ERSingleInstanceLockFD = -1;
static const void *ERAutomationAppendFieldAssociationKey = &ERAutomationAppendFieldAssociationKey;
static const void *ERAutomationAppendTokenAssociationKey = &ERAutomationAppendTokenAssociationKey;

static NSInteger ERClampInteger(NSInteger value, NSInteger minimum, NSInteger maximum);
static NSInteger ERCompareVersionStrings(NSString *left, NSString *right);
static NSString *ERCalendarAccessStatusText(void);

static void ERPostOpenSettingsRequest(void) {
    [NSDistributedNotificationCenter.defaultCenter postNotificationName:EROpenSettingsNotificationName
                                                                 object:nil
                                                               userInfo:nil
                                                     deliverImmediately:YES];
}

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

static NSString *ERFormatClockTime(NSDate *date) {
    if (!date) return @"--:--";
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.dateFormat = @"HH:mm:ss";
    return [formatter stringFromDate:date];
}

static NSString *ERAutomationURLString(NSString *command) {
    return [NSString stringWithFormat:@"%@://%@", ERAutomationURLScheme, command ?: @"settings"];
}

static NSArray<NSString *> *ERAutomationURLPathParts(NSURL *url) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSString *host = url.host.stringByRemovingPercentEncoding.lowercaseString;
    if (host.length > 0) {
        [parts addObject:host];
    }
    for (NSString *component in url.pathComponents) {
        if ([component isEqualToString:@"/"] || component.length == 0) continue;
        NSString *part = component.stringByRemovingPercentEncoding.lowercaseString;
        if (part.length > 0) {
            [parts addObject:part];
        }
    }
    return parts;
}

static NSTimeInterval ERAutomationDurationSecondsFromToken(NSString *token) {
    NSString *text = token.stringByRemovingPercentEncoding.lowercaseString;
    text = [text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (text.length == 0) return 0;

    NSTimeInterval multiplier = 60;
    BOOL matchedSuffix = NO;
    NSArray<NSArray<NSString *> *> *suffixGroups = @[
        @[@"hours", @"hour", @"hrs", @"hr", @"h", @"小时"],
        @[@"minutes", @"minute", @"mins", @"min", @"m", @"分钟", @"分"],
        @[@"seconds", @"second", @"secs", @"sec", @"s", @"秒"]
    ];
    NSArray<NSNumber *> *multipliers = @[@3600, @60, @1];
    for (NSInteger groupIndex = 0; groupIndex < suffixGroups.count; groupIndex++) {
        for (NSString *suffix in suffixGroups[groupIndex]) {
            if ([text hasSuffix:suffix] && text.length > suffix.length) {
                text = [text substringToIndex:text.length - suffix.length];
                multiplier = multipliers[groupIndex].doubleValue;
                matchedSuffix = YES;
                break;
            }
        }
        if (matchedSuffix) break;
    }

    double value = 0;
    NSScanner *scanner = [NSScanner scannerWithString:text];
    if (![scanner scanDouble:&value] || value <= 0) return 0;
    return MIN(24 * 60 * 60, MAX(10, value * multiplier));
}

static NSString *ERSystemEventTitle(NSString *name) {
    if ([name isEqualToString:NSWorkspaceDidWakeNotification]) return @"唤醒";
    if ([name isEqualToString:NSWorkspaceWillSleepNotification]) return @"睡眠";
    if ([name isEqualToString:NSWorkspaceScreensDidWakeNotification]) return @"屏幕唤醒";
    if ([name isEqualToString:NSWorkspaceScreensDidSleepNotification]) return @"屏幕睡眠";
    if ([name isEqualToString:NSWorkspaceSessionDidBecomeActiveNotification]) return @"解锁";
    if ([name isEqualToString:NSWorkspaceSessionDidResignActiveNotification]) return @"锁屏";
    if ([name isEqualToString:NSApplicationDidChangeScreenParametersNotification]) return @"屏幕变化";
    return @"系统事件";
}

static NSString *EREyeModeTitle(EREyeMode mode) {
    switch (mode) {
        case EREyeMode202020: return @"20-20-20";
        case EREyeModePomodoro: return @"番茄钟";
        case EREyeModeCustom: return @"自定义";
    }
}

static EREyeMode EREyeModeFromObject(id object, EREyeMode fallback) {
    if ([object respondsToSelector:@selector(integerValue)]) {
        return ERClampInteger([object integerValue], EREyeMode202020, EREyeModeCustom);
    }
    if (![object isKindOfClass:NSString.class]) return fallback;
    NSString *text = [(NSString *)object lowercaseString];
    if ([text containsString:@"20-20-20"] || [text containsString:@"202020"]) return EREyeMode202020;
    if ([text containsString:@"番茄"] || [text containsString:@"pomodoro"]) return EREyeModePomodoro;
    if ([text containsString:@"自定义"] || [text containsString:@"custom"]) return EREyeModeCustom;
    return fallback;
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

static ERRestStyle ERRestStyleFromObject(id object, ERRestStyle fallback) {
    if ([object respondsToSelector:@selector(integerValue)]) {
        return ERClampInteger([object integerValue], ERRestStyleBreath, ERRestStyleNight);
    }
    if (![object isKindOfClass:NSString.class]) return fallback;
    NSString *text = [(NSString *)object lowercaseString];
    if ([text containsString:@"呼吸"] || [text containsString:@"breath"]) return ERRestStyleBreath;
    if ([text containsString:@"森林"] || [text containsString:@"forest"]) return ERRestStyleForest;
    if ([text containsString:@"像素"] || [text containsString:@"pixel"]) return ERRestStylePixel;
    if ([text containsString:@"玩具"] || [text containsString:@"toy"]) return ERRestStyleToy;
    if ([text containsString:@"夜间"] || [text containsString:@"night"]) return ERRestStyleNight;
    return fallback;
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

static ERMenuBarMode ERMenuBarModeFromObject(id object, ERMenuBarMode fallback) {
    if ([object respondsToSelector:@selector(integerValue)]) {
        return ERClampInteger([object integerValue], ERMenuBarModeBoth, ERMenuBarModeSmart);
    }
    if (![object isKindOfClass:NSString.class]) return fallback;
    NSString *text = [(NSString *)object lowercaseString];
    if ([text containsString:@"眼睛 + 站立"] || [text containsString:@"both"]) return ERMenuBarModeBoth;
    if ([text containsString:@"只显示眼睛"] || [text isEqualToString:@"eye"]) return ERMenuBarModeEye;
    if ([text containsString:@"只显示站立"] || [text isEqualToString:@"stand"]) return ERMenuBarModeStand;
    if ([text containsString:@"极简"] || [text containsString:@"compact"]) return ERMenuBarModeCompact;
    if ([text containsString:@"智能"] || [text containsString:@"smart"]) return ERMenuBarModeSmart;
    return fallback;
}

static NSString *ERStandRoutineTitle(ERStandRoutine routine) {
    switch (routine) {
        case ERStandRoutineBalanced: return @"均衡活动";
        case ERStandRoutineNeckShoulder: return @"肩颈舒展";
        case ERStandRoutineWalk: return @"走动循环";
        case ERStandRoutineReset: return @"恢复放松";
    }
}

static ERStandRoutine ERStandRoutineFromObject(id object, ERStandRoutine fallback) {
    if ([object respondsToSelector:@selector(integerValue)]) {
        return ERClampInteger([object integerValue], ERStandRoutineBalanced, ERStandRoutineReset);
    }
    if (![object isKindOfClass:NSString.class]) return fallback;
    NSString *text = [(NSString *)object lowercaseString];
    if ([text containsString:@"均衡"] || [text containsString:@"balanced"]) return ERStandRoutineBalanced;
    if ([text containsString:@"肩颈"] || [text containsString:@"neck"]) return ERStandRoutineNeckShoulder;
    if ([text containsString:@"走动"] || [text containsString:@"walk"]) return ERStandRoutineWalk;
    if ([text containsString:@"恢复"] || [text containsString:@"reset"]) return ERStandRoutineReset;
    return fallback;
}

static NSString *ERStandRoutineSummary(ERStandRoutine routine) {
    switch (routine) {
        case ERStandRoutineBalanced: return @"起身、肩颈、走动、补水和收尾都照顾到。";
        case ERStandRoutineNeckShoulder: return @"更偏向久坐后的肩颈和上背舒展。";
        case ERStandRoutineWalk: return @"用走动和腿部活动把身体重新唤醒。";
        case ERStandRoutineReset: return @"轻量恢复，适合会议间隙或低打扰休息。";
    }
}

static NSString *ERStandIntensityTitle(ERStandIntensity intensity) {
    switch (intensity) {
        case ERStandIntensityGentle: return @"轻柔";
        case ERStandIntensityStandard: return @"标准";
        case ERStandIntensityActive: return @"活动一点";
    }
}

static ERStandIntensity ERStandIntensityFromObject(id object, ERStandIntensity fallback) {
    if ([object respondsToSelector:@selector(integerValue)]) {
        return ERClampInteger([object integerValue], ERStandIntensityGentle, ERStandIntensityActive);
    }
    if (![object isKindOfClass:NSString.class]) return fallback;
    NSString *text = [(NSString *)object lowercaseString];
    if ([text containsString:@"轻柔"] || [text containsString:@"gentle"]) return ERStandIntensityGentle;
    if ([text containsString:@"标准"] || [text containsString:@"standard"]) return ERStandIntensityStandard;
    if ([text containsString:@"活动"] || [text containsString:@"active"]) return ERStandIntensityActive;
    return fallback;
}

static NSString *ERStandIntensityHint(ERStandIntensity intensity) {
    switch (intensity) {
        case ERStandIntensityGentle: return @"动作更小，适合会议间隙或刚恢复状态。";
        case ERStandIntensityStandard: return @"保持默认节奏，舒展和走动都照顾到。";
        case ERStandIntensityActive: return @"多做一轮或多走几步，让身体真的热起来。";
    }
}

static NSString *ERStandIntensitySuffix(ERStandIntensity intensity) {
    switch (intensity) {
        case ERStandIntensityGentle: return @"轻柔版：动作幅度小一点，只做到舒服的位置。";
        case ERStandIntensityStandard: return @"标准版：按提示完成一轮，保持自然呼吸。";
        case ERStandIntensityActive: return @"活动版：状态允许的话，多做一轮或多走 20 步。";
    }
}

static NSString *ERStandIntensityPillNote(ERStandIntensity intensity) {
    switch (intensity) {
        case ERStandIntensityGentle: return @"轻柔版";
        case ERStandIntensityStandard: return @"标准版";
        case ERStandIntensityActive: return @"活动版";
    }
}

static NSString *ERStandAdjustedSuggestion(NSString *suggestion, ERStandIntensity intensity) {
    switch (intensity) {
        case ERStandIntensityGentle:
            return [NSString stringWithFormat:@"%@ 幅度小一点。", suggestion];
        case ERStandIntensityStandard:
            return suggestion;
        case ERStandIntensityActive:
            return [NSString stringWithFormat:@"%@ 状态好就多做一轮。", suggestion];
    }
}

static NSString *ERStandCompletionAdvice(ERStandRoutine routine, ERStandIntensity intensity) {
    if (intensity == ERStandIntensityGentle) {
        switch (routine) {
            case ERStandRoutineBalanced: return @"下一轮继续小幅度活动，别急着坐太紧。";
            case ERStandRoutineNeckShoulder: return @"回到桌前先把肩膀放低，再开始下一件事。";
            case ERStandRoutineWalk: return @"坐下前慢慢走回工位，让呼吸稳下来。";
            case ERStandRoutineReset: return @"接下来先做一件很小的事，把节奏接回来。";
        }
    }
    if (intensity == ERStandIntensityActive) {
        switch (routine) {
            case ERStandRoutineBalanced: return @"状态不错，下次可以多补一杯水或多走二十步。";
            case ERStandRoutineNeckShoulder: return @"接下来留意脖子别前探，屏幕稍微抬高一点。";
            case ERStandRoutineWalk: return @"回来前先喝口水，再坐下处理下一段工作。";
            case ERStandRoutineReset: return @"身体热起来了，下一段工作先从重点任务开始。";
        }
    }
    switch (routine) {
        case ERStandRoutineBalanced: return @"下一轮保持这个节奏，坐下后别立刻缩回去。";
        case ERStandRoutineNeckShoulder: return @"接下来留意肩膀别重新耸起来。";
        case ERStandRoutineWalk: return @"坐下前再看一眼远处，让腿和眼睛一起收尾。";
        case ERStandRoutineReset: return @"下一段工作先从一件小事开始。";
    }
}

static NSArray<NSString *> *ERDefaultFocusAppTokens(void) {
    return @[
        @"us.zoom.xos", @"zoom",
        @"com.tencent.meeting", @"com.tencent.wemeet", @"腾讯会议", @"voov",
        @"com.microsoft.teams", @"com.microsoft.teams2", @"teams",
        @"com.bytedance.feishu", @"com.larksuite.lark", @"feishu", @"lark", @"飞书",
        @"com.alibaba.dingtalkmac", @"dingtalk", @"钉钉",
        @"com.apple.iwork.keynote", @"keynote",
        @"com.microsoft.powerpoint", @"powerpoint",
        @"com.obsproject.obs-studio", @"obs",
        @"com.apple.facetime", @"facetime"
    ];
}

static NSArray<NSString *> *ERDefaultAutoPauseAppTokens(void) {
    return @[
        @"com.apple.quicktimeplayerx", @"quicktime",
        @"com.colliderli.iina", @"iina",
        @"org.videolan.vlc", @"vlc",
        @"steam", @"epic games"
    ];
}

static NSArray<NSString *> *ERDefaultIgnoreAppTokens(void) {
    return @[];
}

static NSArray<NSString *> *ERDefaultCalendarFocusTokens(void) {
    return @[
        @"会议", @"meeting", @"同步", @"sync", @"站会", @"standup",
        @"评审", @"review", @"1:1", @"one on one"
    ];
}

static NSArray<NSString *> *ERDefaultCalendarAutoPauseTokens(void) {
    return @[
        @"录制", @"直播", @"演讲", @"演示", @"presentation", @"面试",
        @"interview", @"讲座", @"webinar", @"路演", @"workshop"
    ];
}

static NSString *ERTrimmedString(NSString *text) {
    return [(text ?: @"") stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
}

static NSString *ERSanitizedStandCustomStagesTextFromObject(id object) {
    NSMutableArray<NSString *> *rawLines = [NSMutableArray array];
    if ([object isKindOfClass:NSString.class]) {
        [rawLines addObjectsFromArray:[(NSString *)object componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet]];
    } else if ([object isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)object) {
            if ([item isKindOfClass:NSString.class]) {
                [rawLines addObject:(NSString *)item];
            }
        }
    }

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSString *rawLine in rawLines) {
        NSString *line = ERTrimmedString(rawLine);
        if (line.length == 0) continue;
        if (line.length > 120) {
            line = [line substringToIndex:120];
        }
        [lines addObject:line];
        if (lines.count >= 8) break;
    }
    return [lines componentsJoinedByString:@"\n"];
}

static NSArray<NSDictionary<NSString *, NSString *> *> *ERStandCustomStageEntriesFromText(NSString *text) {
    NSString *sanitized = ERSanitizedStandCustomStagesTextFromObject(text);
    if (sanitized.length == 0) return @[];

    NSMutableArray<NSDictionary<NSString *, NSString *> *> *entries = [NSMutableArray array];
    NSCharacterSet *separatorSet = [NSCharacterSet characterSetWithCharactersInString:@":："];
    NSArray<NSString *> *lines = [sanitized componentsSeparatedByCharactersInSet:NSCharacterSet.newlineCharacterSet];
    for (NSString *line in lines) {
        NSString *title = @"";
        NSString *suggestion = ERTrimmedString(line);
        NSRange separatorRange = [line rangeOfCharacterFromSet:separatorSet];
        if (separatorRange.location != NSNotFound) {
            title = ERTrimmedString([line substringToIndex:separatorRange.location]);
            suggestion = ERTrimmedString([line substringFromIndex:NSMaxRange(separatorRange)]);
        }
        if (title.length == 0) {
            title = [NSString stringWithFormat:@"阶段 %ld", (long)entries.count + 1];
        }
        if (suggestion.length == 0) {
            suggestion = title;
        }
        [entries addObject:@{@"title": title, @"suggestion": suggestion}];
    }
    return entries;
}

static NSString *ERStandStageMessageWithIntensity(NSString *suggestion, ERStandIntensity intensity) {
    NSString *trimmed = ERTrimmedString(suggestion);
    if (trimmed.length == 0) return ERStandIntensitySuffix(intensity);
    NSCharacterSet *terminalSet = [NSCharacterSet characterSetWithCharactersInString:@"。.!！？?"];
    unichar lastCharacter = [trimmed characterAtIndex:trimmed.length - 1];
    NSString *separator = [terminalSet characterIsMember:lastCharacter] ? @"" : @"。";
    return [NSString stringWithFormat:@"%@%@%@", trimmed, separator, ERStandIntensitySuffix(intensity)];
}

static NSArray<NSString *> *ERSanitizedFocusAppTokensFromObject(id object) {
    NSMutableArray<NSString *> *rawTokens = [NSMutableArray array];
    NSCharacterSet *separators = [NSCharacterSet characterSetWithCharactersInString:@"\n,，;；"];
    if ([object isKindOfClass:NSString.class]) {
        [rawTokens addObjectsFromArray:[(NSString *)object componentsSeparatedByCharactersInSet:separators]];
    } else if ([object isKindOfClass:NSArray.class]) {
        for (id item in (NSArray *)object) {
            if (![item isKindOfClass:NSString.class]) continue;
            [rawTokens addObjectsFromArray:[(NSString *)item componentsSeparatedByCharactersInSet:separators]];
        }
    }

    NSMutableArray<NSString *> *tokens = [NSMutableArray array];
    NSMutableSet<NSString *> *seen = [NSMutableSet set];
    NSCharacterSet *trimSet = NSCharacterSet.whitespaceAndNewlineCharacterSet;
    for (NSString *rawToken in rawTokens) {
        NSString *token = [rawToken stringByTrimmingCharactersInSet:trimSet];
        if (token.length == 0) continue;
        NSString *normalized = token.lowercaseString;
        if ([seen containsObject:normalized]) continue;
        [seen addObject:normalized];
        [tokens addObject:token];
    }
    return tokens;
}

static NSString *ERJoinedFocusTokensByAppendingToken(NSString *existingText, NSString *token) {
    token = ERTrimmedString(token);
    if (token.length == 0) return existingText ?: @"";

    NSMutableArray<NSString *> *tokens = [NSMutableArray arrayWithArray:ERSanitizedFocusAppTokensFromObject(existingText ?: @"")];
    NSMutableSet<NSString *> *seen = [NSMutableSet setWithArray:[tokens valueForKey:@"lowercaseString"]];
    NSString *normalized = token.lowercaseString;
    if (![seen containsObject:normalized]) {
        [tokens addObject:token];
    }
    return [tokens componentsJoinedByString:@", "];
}

static BOOL ERApplicationMatchesFocusTokens(NSString *bundleIdentifier, NSString *appName, NSArray<NSString *> *tokens) {
    NSString *bundleText = (bundleIdentifier ?: @"").lowercaseString;
    NSString *nameText = (appName ?: @"").lowercaseString;
    if (bundleText.length == 0 && nameText.length == 0) return NO;

    for (NSString *token in tokens) {
        NSString *needle = [token.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (needle.length == 0) continue;
        if ([bundleText isEqualToString:needle] || [bundleText containsString:needle]) return YES;
        if ([nameText isEqualToString:needle] || [nameText containsString:needle]) return YES;
    }
    return NO;
}

static BOOL ERTextMatchesFocusTokens(NSString *text, NSArray<NSString *> *tokens) {
    NSString *haystack = (text ?: @"").lowercaseString;
    if (haystack.length == 0) return NO;
    for (NSString *token in tokens) {
        NSString *needle = [token.lowercaseString stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
        if (needle.length == 0) continue;
        if ([haystack containsString:needle]) return YES;
    }
    return NO;
}

static NSString *ERCalendarEventSearchText(EKEvent *event) {
    if (!event) return @"";
    NSArray<NSString *> *parts = @[
        event.title ?: @"",
        event.location ?: @"",
        event.calendar.title ?: @""
    ];
    return [parts componentsJoinedByString:@"\n"];
}

static BOOL ERCalendarEventMatchesTokens(EKEvent *event, NSArray<NSString *> *tokens) {
    return ERTextMatchesFocusTokens(ERCalendarEventSearchText(event), tokens);
}

static NSString *ERCalendarEventDiagnosticLine(EKEvent *event, NSDateFormatter *formatter, NSArray<NSString *> *focusTokens, NSArray<NSString *> *autoPauseTokens) {
    if (!event) return @"";
    NSString *title = event.title.length > 0 ? event.title : @"无标题";
    NSString *calendarTitle = event.calendar.title.length > 0 ? event.calendar.title : @"未知日历";
    NSString *startText = event.startDate ? [formatter stringFromDate:event.startDate] : @"未知开始";
    NSString *endText = event.endDate ? [formatter stringFromDate:event.endDate] : @"未知结束";
    BOOL pauseMatch = ERCalendarEventMatchesTokens(event, autoPauseTokens);
    BOOL focusMatch = ERCalendarEventMatchesTokens(event, focusTokens);
    NSString *policy = pauseMatch ? @"自动暂停" : (focusMatch ? @"只发通知" : @"默认会议");
    return [NSString stringWithFormat:@"- %@ · %@-%@ · %@ · %@", title, startText, endText, calendarTitle, policy];
}

static BOOL ERCalendarAccessGranted(void) {
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (@available(macOS 14.0, *)) {
        return status == EKAuthorizationStatusFullAccess;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    return status == EKAuthorizationStatusAuthorized;
#pragma clang diagnostic pop
}

static NSString *ERCalendarAccessStatusText(void) {
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    switch (status) {
        case EKAuthorizationStatusNotDetermined: return @"未授权";
        case EKAuthorizationStatusRestricted: return @"受限制";
        case EKAuthorizationStatusDenied: return @"已拒绝";
        default: return ERCalendarAccessGranted() ? @"已授权" : @"不可用";
    }
}

static BOOL ERPresentationModeDetected(void) {
    NSApplicationPresentationOptions options = NSApp.currentSystemPresentationOptions;
    NSApplicationPresentationOptions mask =
        NSApplicationPresentationFullScreen |
        NSApplicationPresentationHideDock |
        NSApplicationPresentationHideMenuBar |
        NSApplicationPresentationAutoHideDock |
        NSApplicationPresentationAutoHideMenuBar;
    return (options & mask) != 0;
}

static NSString *ERScreenDiagnosticSummary(void) {
    NSMutableArray<NSString *> *parts = [NSMutableArray array];
    NSArray<NSScreen *> *screens = NSScreen.screens;
    [parts addObject:[NSString stringWithFormat:@"屏幕 %ld", (long)screens.count]];
    for (NSInteger index = 0; index < screens.count; index++) {
        NSScreen *screen = screens[index];
        NSRect frame = screen.frame;
        NSRect visible = screen.visibleFrame;
        BOOL main = screen == NSScreen.mainScreen;
        [parts addObject:[NSString stringWithFormat:@"%@%ld %.0f,%.0f %.0fx%.0f 可见 %.0f,%.0f %.0fx%.0f",
                          main ? @"主" : @"屏",
                          (long)index + 1,
                          frame.origin.x,
                          frame.origin.y,
                          frame.size.width,
                          frame.size.height,
                          visible.origin.x,
                          visible.origin.y,
                          visible.size.width,
                          visible.size.height]];
    }
    return [parts componentsJoinedByString:@"；"];
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

static NSInteger ERCompareVersionStrings(NSString *left, NSString *right) {
    NSString *cleanLeft = [[left ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"vV"]];
    NSString *cleanRight = [[right ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"vV"]];
    NSArray<NSString *> *leftParts = [cleanLeft componentsSeparatedByString:@"."];
    NSArray<NSString *> *rightParts = [cleanRight componentsSeparatedByString:@"."];
    NSUInteger count = MAX(leftParts.count, rightParts.count);
    for (NSUInteger index = 0; index < count; index++) {
        NSInteger leftValue = index < leftParts.count ? leftParts[index].integerValue : 0;
        NSInteger rightValue = index < rightParts.count ? rightParts[index].integerValue : 0;
        if (leftValue < rightValue) return -1;
        if (leftValue > rightValue) return 1;
    }
    return 0;
}

static NSInteger ERSanitizedMinuteOfDay(NSInteger minute) {
    return ERClampInteger(minute, 0, 23 * 60 + 59);
}

static NSString *ERFormatClockMinute(NSInteger minute) {
    minute = ERSanitizedMinuteOfDay(minute);
    return [NSString stringWithFormat:@"%02ld:%02ld", (long)(minute / 60), (long)(minute % 60)];
}

static NSInteger ERMinuteOfDayFromClockString(NSString *text, NSInteger fallback) {
    NSString *trimmed = ERTrimmedString([text stringByReplacingOccurrencesOfString:@"：" withString:@":"]);
    if (trimmed.length == 0) return ERSanitizedMinuteOfDay(fallback);

    NSInteger hour = -1;
    NSInteger minute = -1;
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@":"];
    if (parts.count == 2) {
        hour = ERTrimmedString(parts[0]).integerValue;
        minute = ERTrimmedString(parts[1]).integerValue;
    } else if (trimmed.length == 3 || trimmed.length == 4) {
        NSString *hourText = [trimmed substringToIndex:trimmed.length - 2];
        NSString *minuteText = [trimmed substringFromIndex:trimmed.length - 2];
        hour = hourText.integerValue;
        minute = minuteText.integerValue;
    }
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        return ERSanitizedMinuteOfDay(fallback);
    }
    return hour * 60 + minute;
}

static NSInteger ERCurrentMinuteOfDay(void) {
    NSDateComponents *components = [NSCalendar.currentCalendar components:NSCalendarUnitHour | NSCalendarUnitMinute fromDate:NSDate.date];
    return components.hour * 60 + components.minute;
}

static BOOL ERQuietHoursContainsMinute(BOOL enabled, NSInteger startMinute, NSInteger endMinute, NSInteger minute) {
    if (!enabled) return NO;
    startMinute = ERSanitizedMinuteOfDay(startMinute);
    endMinute = ERSanitizedMinuteOfDay(endMinute);
    minute = ERSanitizedMinuteOfDay(minute);
    if (startMinute == endMinute) return NO;
    if (startMinute < endMinute) {
        return minute >= startMinute && minute < endMinute;
    }
    return minute >= startMinute || minute < endMinute;
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
    seconds = MAX(0, seconds);
    if (seconds < 60) {
        return [NSString stringWithFormat:@"%ld 秒", (long)seconds];
    }
    NSInteger minutes = (NSInteger)llround((double)seconds / 60.0);
    if (minutes < 60) {
        return [NSString stringWithFormat:@"%ld 分钟", (long)minutes];
    }
    NSInteger hours = minutes / 60;
    NSInteger remaining = minutes % 60;
    return remaining > 0
        ? [NSString stringWithFormat:@"%ld 小时 %ld 分", (long)hours, (long)remaining]
        : [NSString stringWithFormat:@"%ld 小时", (long)hours];
}

static NSInteger ERStatsInteger(NSDictionary *entry, NSString *key) {
    id value = entry[key];
    return [value respondsToSelector:@selector(integerValue)] ? [value integerValue] : 0;
}

static NSInteger ERPercent(NSInteger part, NSInteger total) {
    return total > 0 ? (NSInteger)llround((double)part * 100.0 / (double)total) : 0;
}

static NSString *ERLaunchAgentIdentifier(void) {
    return @"local.codex.eyerest";
}

static BOOL ERDefaultsHasPersistentValue(NSUserDefaults *defaults, NSString *key) {
    NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier ?: ERLaunchAgentIdentifier();
    NSDictionary *domain = [defaults persistentDomainForName:bundleIdentifier];
    return domain[key] != nil;
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

static CALayer *ERStyleMotifLayer(CGRect frame, NSColor *color, CGFloat radius, NSString *name) {
    CALayer *layer = [CALayer layer];
    layer.frame = frame;
    layer.backgroundColor = color.CGColor;
    layer.cornerRadius = radius;
    layer.masksToBounds = YES;
    layer.name = name;
    return layer;
}

static void ERRemoveStyleMotifLayers(CALayer *hostLayer, NSString *prefix) {
    NSArray<CALayer *> *layers = [hostLayer.sublayers copy];
    for (CALayer *layer in layers) {
        if ([layer.name hasPrefix:prefix]) {
            [layer removeFromSuperlayer];
        }
    }
}

static void ERInsertStyleMotifLayer(CALayer *hostLayer, CALayer *layer, NSUInteger *insertIndex) {
    NSUInteger boundedIndex = MIN(*insertIndex, hostLayer.sublayers.count);
    [hostLayer insertSublayer:layer atIndex:(unsigned int)boundedIndex];
    *insertIndex = boundedIndex + 1;
}

static void ERAddStyleMotifLayers(CALayer *hostLayer, NSRect bounds, ERRestStyle style, ERTheme theme, NSString *prefix, CGFloat intensity, BOOL compact, NSUInteger startIndex) {
    if (!hostLayer) return;
    ERRemoveStyleMotifLayers(hostLayer, prefix);

    CGFloat width = MAX(1, NSWidth(bounds));
    CGFloat height = MAX(1, NSHeight(bounds));
    CGFloat unit = compact ? 0.56 : 1.0;
    BOOL darkStyle = theme.foreground == NSColor.whiteColor;
    CGFloat softAlpha = MIN(0.90, (darkStyle ? 0.18 : 0.12) * intensity);
    CGFloat midAlpha = MIN(0.90, (darkStyle ? 0.30 : 0.22) * intensity);
    CGFloat strongAlpha = MIN(0.90, (darkStyle ? 0.48 : 0.34) * intensity);
    NSColor *accentSoft = [theme.accent colorWithAlphaComponent:softAlpha];
    NSColor *accentMid = [theme.accent colorWithAlphaComponent:midAlpha];
    NSColor *accentStrong = [theme.accent colorWithAlphaComponent:strongAlpha];
    NSColor *lightSoft = darkStyle
        ? [NSColor colorWithWhite:1 alpha:MIN(0.70, 0.16 * intensity)]
        : [NSColor colorWithWhite:1 alpha:MIN(0.70, 0.42 * intensity)];
    NSColor *shadowSoft = darkStyle
        ? [NSColor colorWithWhite:0 alpha:MIN(0.45, 0.14 * intensity)]
        : [theme.cardBorder colorWithAlphaComponent:MIN(0.60, 0.32 * intensity)];

    __block NSUInteger insertIndex = MIN(startIndex, hostLayer.sublayers.count);
    __block NSInteger motifIndex = 0;
    NSString *(^motifName)(void) = ^NSString *{
        return [NSString stringWithFormat:@"%@-%ld", prefix, (long)motifIndex++];
    };
    void (^addLayer)(CALayer *) = ^(CALayer *layer) {
        ERInsertStyleMotifLayer(hostLayer, layer, &insertIndex);
    };

    if (style == ERRestStyleBreath) {
        NSArray<NSValue *> *frames = @[
            [NSValue valueWithRect:NSMakeRect(-width * 0.06, height * 0.76, width * 0.38, 6 * unit)],
            [NSValue valueWithRect:NSMakeRect(width * 0.60, height * 0.18, width * 0.34, 5 * unit)],
            [NSValue valueWithRect:NSMakeRect(width * 0.12, height * 0.16, width * 0.44, 4 * unit)],
            [NSValue valueWithRect:NSMakeRect(width * 0.70, height * 0.64, width * 0.26, 4 * unit)]
        ];
        for (NSInteger index = 0; index < frames.count; index++) {
            NSRect frame = frames[index].rectValue;
            CALayer *line = ERStyleMotifLayer(frame, index % 2 == 0 ? accentSoft : lightSoft, frame.size.height / 2.0, motifName());
            addLayer(line);
        }
    } else if (style == ERRestStyleForest) {
        CALayer *ground = ERStyleMotifLayer(CGRectMake(0, 0, width, MAX(14, height * 0.13)), accentSoft, 0, motifName());
        addLayer(ground);
        NSInteger stemCount = compact ? 4 : 9;
        for (NSInteger index = 0; index < stemCount; index++) {
            CGFloat stemWidth = (compact ? 8 : 18) + (index % 2) * 4;
            CGFloat stemHeight = height * (compact ? 0.28 : 0.36) + (index % 3) * 18 * unit;
            CGFloat x = width * 0.08 + index * (width / MAX(1, stemCount));
            CALayer *stem = ERStyleMotifLayer(CGRectMake(x, MAX(0, height * 0.06), stemWidth, stemHeight), shadowSoft, stemWidth / 2.0, motifName());
            addLayer(stem);

            CALayer *leaf = ERStyleMotifLayer(CGRectMake(x - 5 * unit, stemHeight + height * 0.05, 30 * unit, 12 * unit), accentMid, 8 * unit, motifName());
            leaf.transform = CATransform3DMakeRotation((index % 2 == 0 ? -0.34 : 0.34), 0, 0, 1);
            addLayer(leaf);
        }
    } else if (style == ERRestStylePixel) {
        CGFloat block = MAX(6, 24 * unit);
        CALayer *sun = ERStyleMotifLayer(CGRectMake(width - 4 * block, height - 4 * block, 2.2 * block, 2.2 * block), ERColor(1.00, 0.84, 0.26, MIN(0.92, 0.72 * intensity)), 1, motifName());
        addLayer(sun);
        for (NSInteger index = 0; index < (compact ? 7 : 15); index++) {
            CGFloat x = width * 0.08 + (index % 7) * block * 1.08;
            CGFloat y = height * 0.72 - (index / 7) * block * 1.08;
            CALayer *tile = ERStyleMotifLayer(CGRectMake(x, y, block, block), index % 3 == 0 ? lightSoft : accentSoft, 1, motifName());
            addLayer(tile);
        }
        NSInteger steps = compact ? 6 : 14;
        for (NSInteger index = 0; index < steps; index++) {
            CGFloat stepHeight = block * (1 + (index % 3));
            CALayer *step = ERStyleMotifLayer(CGRectMake(index * block * 1.02, 0, block * 1.02, stepHeight), shadowSoft, 0, motifName());
            addLayer(step);
        }
    } else if (style == ERRestStyleToy) {
        NSArray<NSColor *> *colors = @[
            ERColor(1.00, 0.88, 0.22, MIN(0.90, 0.42 * intensity)),
            ERColor(0.35, 0.78, 1.00, MIN(0.90, 0.36 * intensity)),
            ERColor(1.00, 0.45, 0.62, MIN(0.90, 0.34 * intensity)),
            ERColor(0.68, 0.52, 1.00, MIN(0.90, 0.32 * intensity))
        ];
        NSInteger stickerCount = compact ? 4 : 9;
        for (NSInteger index = 0; index < stickerCount; index++) {
            CGFloat stickerWidth = (compact ? 32 : 74) + (index % 3) * 12 * unit;
            CGFloat stickerHeight = (compact ? 14 : 28) + (index % 2) * 8 * unit;
            CGFloat x = width * (0.08 + 0.11 * index);
            CGFloat y = height * (index % 2 == 0 ? 0.70 : 0.18) + (index % 3) * 12 * unit;
            CALayer *sticker = ERStyleMotifLayer(CGRectMake(x, y, stickerWidth, stickerHeight), colors[index % colors.count], 8 * unit, motifName());
            sticker.transform = CATransform3DMakeRotation((index % 2 == 0 ? -0.22 : 0.18), 0, 0, 1);
            addLayer(sticker);
        }
        NSInteger confettiCount = compact ? 6 : 16;
        for (NSInteger index = 0; index < confettiCount; index++) {
            CGFloat size = (compact ? 5 : 10) + (index % 2) * 3 * unit;
            CGFloat x = width * 0.05 + fmod(index * 47 * unit, width * 0.84);
            CGFloat y = height * 0.12 + fmod(index * 31 * unit, height * 0.72);
            CALayer *piece = ERStyleMotifLayer(CGRectMake(x, y, size, size), colors[(index + 2) % colors.count], 2 * unit, motifName());
            addLayer(piece);
        }
    } else if (style == ERRestStyleNight) {
        for (NSInteger index = 0; index < (compact ? 12 : 34); index++) {
            CGFloat size = (compact ? 2 : 3) + (index % 3) * unit;
            CGFloat x = width * 0.06 + fmod(index * 83 * unit, width * 0.88);
            CGFloat y = height * 0.20 + fmod(index * 47 * unit, height * 0.66);
            CALayer *star = ERStyleMotifLayer(CGRectMake(x, y, size, size), lightSoft, size / 2.0, motifName());
            addLayer(star);
        }
        CALayer *window = ERStyleMotifLayer(CGRectMake(width - width * 0.24, height - height * 0.28, width * 0.12, height * 0.14), accentMid, 7 * unit, motifName());
        addLayer(window);
        CALayer *horizon = ERStyleMotifLayer(CGRectMake(width * 0.10, height * 0.10, width * 0.64, 5 * unit), accentSoft, 3 * unit, motifName());
        addLayer(horizon);
        CALayer *horizonTwo = ERStyleMotifLayer(CGRectMake(width * 0.18, height * 0.16, width * 0.46, 3 * unit), accentStrong, 2 * unit, motifName());
        addLayer(horizonTwo);
    }
}

static ERTheme ERThemeForStyle(ERRestStyle style) {
    ERTheme theme;
    theme.settingsBackground = ERColor(0.96, 0.97, 0.985, 1);
    theme.settingsHeader = [NSColor colorWithWhite:1 alpha:0.58];
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
            theme.settingsBackground = ERColor(0.93, 0.96, 0.93, 1);
            theme.card = ERColor(0.98, 1.00, 0.96, 1);
            theme.cardBorder = ERColor(0.72, 0.82, 0.70, 1);
            theme.backgroundA = ERColor(0.08, 0.27, 0.18, 1);
            theme.backgroundB = ERColor(0.34, 0.55, 0.30, 1);
            theme.foreground = NSColor.whiteColor;
            theme.secondary = [NSColor colorWithWhite:1 alpha:0.78];
            theme.accent = ERColor(0.78, 0.96, 0.68, 1);
            break;
        case ERRestStylePixel:
            theme.settingsBackground = ERColor(0.92, 0.95, 0.99, 1);
            theme.card = ERColor(0.98, 0.99, 1.00, 1);
            theme.cardBorder = ERColor(0.48, 0.58, 0.72, 1);
            theme.backgroundA = ERColor(0.31, 0.64, 0.88, 1);
            theme.backgroundB = ERColor(0.82, 0.93, 0.98, 1);
            theme.accent = ERColor(0.15, 0.29, 0.55, 1);
            theme.cornerRadius = 6;
            theme.pixel = YES;
            break;
        case ERRestStyleToy:
            theme.settingsBackground = ERColor(1.00, 0.955, 0.965, 1);
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
@property(nonatomic) ERStandRoutine standRoutine;
@property(nonatomic) ERStandIntensity standIntensity;
@property(nonatomic, copy) NSString *standCustomStagesText;
@property(nonatomic) BOOL showRestWindow;
@property(nonatomic) BOOL restWindowTopmost;
@property(nonatomic) BOOL notificationsEnabled;
@property(nonatomic) ERRestStyle restStyle;
@property(nonatomic) ERMenuBarMode menuBarMode;
@property(nonatomic) BOOL launchAtLogin;
@property(nonatomic) BOOL autoFocusModeEnabled;
@property(nonatomic) BOOL calendarFocusModeEnabled;
@property(nonatomic) BOOL presentationFocusModeEnabled;
@property(nonatomic) BOOL quietHoursEnabled;
@property(nonatomic) NSInteger quietHoursStartMinute;
@property(nonatomic) NSInteger quietHoursEndMinute;
@property(nonatomic, strong) NSArray<NSString *> *focusAppTokens;
@property(nonatomic, strong) NSArray<NSString *> *autoPauseAppTokens;
@property(nonatomic, strong) NSArray<NSString *> *ignoreAppTokens;
@property(nonatomic, strong) NSArray<NSString *> *calendarFocusTokens;
@property(nonatomic, strong) NSArray<NSString *> *calendarAutoPauseTokens;
+ (instancetype)load;
- (void)save;
- (void)applyEyePreset:(EREyeMode)mode;
- (void)applyBackupSettingsDictionary:(NSDictionary *)dictionary;
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
        ERSettingsStandRoutineKey: @(ERStandRoutineBalanced),
        ERSettingsStandIntensityKey: @(ERStandIntensityStandard),
        ERSettingsStandCustomStagesKey: @"",
        ERSettingsShowRestWindowKey: @YES,
        ERSettingsRestWindowTopmostKey: @NO,
        ERSettingsNotificationsKey: @YES,
        ERSettingsRestStyleKey: @(ERRestStyleBreath),
        ERSettingsMenuBarModeKey: @(ERMenuBarModeBoth),
        ERSettingsLaunchAtLoginKey: @NO,
        ERSettingsAutoFocusModeKey: @YES,
        ERSettingsCalendarFocusModeKey: @NO,
        ERSettingsPresentationFocusModeKey: @YES,
        ERSettingsQuietHoursEnabledKey: @NO,
        ERSettingsQuietHoursStartKey: @(22 * 60),
        ERSettingsQuietHoursEndKey: @(7 * 60),
        ERSettingsQuickSetupSeenKey: @NO,
        ERSettingsFocusAppTokensKey: ERDefaultFocusAppTokens(),
        ERSettingsAutoPauseAppTokensKey: ERDefaultAutoPauseAppTokens(),
        ERSettingsIgnoreAppTokensKey: ERDefaultIgnoreAppTokens(),
        ERSettingsCalendarFocusTokensKey: ERDefaultCalendarFocusTokens(),
        ERSettingsCalendarAutoPauseTokensKey: ERDefaultCalendarAutoPauseTokens()
    };
    [defaults registerDefaults:registered];

    settings.eyeEnabled = [defaults boolForKey:ERSettingsEyeEnabledKey];
    settings.eyeMode = [defaults integerForKey:ERSettingsEyeModeKey];
    settings.eyeFocusSeconds = [defaults integerForKey:ERSettingsEyeFocusSecondsKey];
    settings.eyeRestSeconds = [defaults integerForKey:ERSettingsEyeRestSecondsKey];
    settings.standEnabled = [defaults boolForKey:ERSettingsStandEnabledKey];
    settings.standIntervalSeconds = [defaults integerForKey:ERSettingsStandIntervalSecondsKey];
    settings.standDurationSeconds = [defaults integerForKey:ERSettingsStandDurationSecondsKey];
    settings.standRoutine = [defaults integerForKey:ERSettingsStandRoutineKey];
    settings.standIntensity = [defaults integerForKey:ERSettingsStandIntensityKey];
    settings.standCustomStagesText = ERSanitizedStandCustomStagesTextFromObject([defaults objectForKey:ERSettingsStandCustomStagesKey]);
    settings.showRestWindow = [defaults boolForKey:ERSettingsShowRestWindowKey];
    settings.restWindowTopmost = [defaults boolForKey:ERSettingsRestWindowTopmostKey];
    settings.notificationsEnabled = [defaults boolForKey:ERSettingsNotificationsKey];
    settings.restStyle = [defaults integerForKey:ERSettingsRestStyleKey];
    settings.menuBarMode = [defaults integerForKey:ERSettingsMenuBarModeKey];
    settings.launchAtLogin = [defaults boolForKey:ERSettingsLaunchAtLoginKey];
    settings.autoFocusModeEnabled = [defaults boolForKey:ERSettingsAutoFocusModeKey];
    settings.calendarFocusModeEnabled = [defaults boolForKey:ERSettingsCalendarFocusModeKey];
    settings.presentationFocusModeEnabled = [defaults boolForKey:ERSettingsPresentationFocusModeKey];
    settings.quietHoursEnabled = [defaults boolForKey:ERSettingsQuietHoursEnabledKey];
    settings.quietHoursStartMinute = ERSanitizedMinuteOfDay([defaults integerForKey:ERSettingsQuietHoursStartKey]);
    settings.quietHoursEndMinute = ERSanitizedMinuteOfDay([defaults integerForKey:ERSettingsQuietHoursEndKey]);
    BOOL hasFocusTokens = ERDefaultsHasPersistentValue(defaults, ERSettingsFocusAppTokensKey);
    id focusTokensObject = [defaults objectForKey:ERSettingsFocusAppTokensKey];
    settings.focusAppTokens = ERSanitizedFocusAppTokensFromObject(focusTokensObject);
    if (!hasFocusTokens) {
        settings.focusAppTokens = ERDefaultFocusAppTokens();
    }
    BOOL hasAutoPauseTokens = ERDefaultsHasPersistentValue(defaults, ERSettingsAutoPauseAppTokensKey);
    id autoPauseTokensObject = [defaults objectForKey:ERSettingsAutoPauseAppTokensKey];
    settings.autoPauseAppTokens = ERSanitizedFocusAppTokensFromObject(autoPauseTokensObject);
    if (!hasAutoPauseTokens) {
        settings.autoPauseAppTokens = ERDefaultAutoPauseAppTokens();
    }
    BOOL hasIgnoreTokens = ERDefaultsHasPersistentValue(defaults, ERSettingsIgnoreAppTokensKey);
    id ignoreTokensObject = [defaults objectForKey:ERSettingsIgnoreAppTokensKey];
    settings.ignoreAppTokens = ERSanitizedFocusAppTokensFromObject(ignoreTokensObject);
    if (!hasIgnoreTokens) {
        settings.ignoreAppTokens = ERDefaultIgnoreAppTokens();
    }
    BOOL hasCalendarFocusTokens = ERDefaultsHasPersistentValue(defaults, ERSettingsCalendarFocusTokensKey);
    id calendarFocusTokensObject = [defaults objectForKey:ERSettingsCalendarFocusTokensKey];
    settings.calendarFocusTokens = ERSanitizedFocusAppTokensFromObject(calendarFocusTokensObject);
    if (!hasCalendarFocusTokens) {
        settings.calendarFocusTokens = ERDefaultCalendarFocusTokens();
    }
    BOOL hasCalendarAutoPauseTokens = ERDefaultsHasPersistentValue(defaults, ERSettingsCalendarAutoPauseTokensKey);
    id calendarAutoPauseTokensObject = [defaults objectForKey:ERSettingsCalendarAutoPauseTokensKey];
    settings.calendarAutoPauseTokens = ERSanitizedFocusAppTokensFromObject(calendarAutoPauseTokensObject);
    if (!hasCalendarAutoPauseTokens) {
        settings.calendarAutoPauseTokens = ERDefaultCalendarAutoPauseTokens();
    }

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
    settings.standRoutine = ERClampInteger(settings.standRoutine, ERStandRoutineBalanced, ERStandRoutineReset);
    settings.standIntensity = ERClampInteger(settings.standIntensity, ERStandIntensityGentle, ERStandIntensityActive);
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
    [defaults setInteger:self.standRoutine forKey:ERSettingsStandRoutineKey];
    [defaults setInteger:self.standIntensity forKey:ERSettingsStandIntensityKey];
    [defaults setObject:ERSanitizedStandCustomStagesTextFromObject(self.standCustomStagesText) forKey:ERSettingsStandCustomStagesKey];
    [defaults setBool:self.showRestWindow forKey:ERSettingsShowRestWindowKey];
    [defaults setBool:self.restWindowTopmost forKey:ERSettingsRestWindowTopmostKey];
    [defaults setBool:self.notificationsEnabled forKey:ERSettingsNotificationsKey];
    [defaults setInteger:self.restStyle forKey:ERSettingsRestStyleKey];
    [defaults setInteger:self.menuBarMode forKey:ERSettingsMenuBarModeKey];
    [defaults setBool:self.launchAtLogin forKey:ERSettingsLaunchAtLoginKey];
    [defaults setBool:self.autoFocusModeEnabled forKey:ERSettingsAutoFocusModeKey];
    [defaults setBool:self.calendarFocusModeEnabled forKey:ERSettingsCalendarFocusModeKey];
    [defaults setBool:self.presentationFocusModeEnabled forKey:ERSettingsPresentationFocusModeKey];
    [defaults setBool:self.quietHoursEnabled forKey:ERSettingsQuietHoursEnabledKey];
    [defaults setInteger:ERSanitizedMinuteOfDay(self.quietHoursStartMinute) forKey:ERSettingsQuietHoursStartKey];
    [defaults setInteger:ERSanitizedMinuteOfDay(self.quietHoursEndMinute) forKey:ERSettingsQuietHoursEndKey];
    [defaults setObject:ERSanitizedFocusAppTokensFromObject(self.focusAppTokens) forKey:ERSettingsFocusAppTokensKey];
    [defaults setObject:ERSanitizedFocusAppTokensFromObject(self.autoPauseAppTokens) forKey:ERSettingsAutoPauseAppTokensKey];
    [defaults setObject:ERSanitizedFocusAppTokensFromObject(self.ignoreAppTokens) forKey:ERSettingsIgnoreAppTokensKey];
    [defaults setObject:ERSanitizedFocusAppTokensFromObject(self.calendarFocusTokens) forKey:ERSettingsCalendarFocusTokensKey];
    [defaults setObject:ERSanitizedFocusAppTokensFromObject(self.calendarAutoPauseTokens) forKey:ERSettingsCalendarAutoPauseTokensKey];
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

- (void)applyBackupSettingsDictionary:(NSDictionary *)dictionary {
    if (![dictionary isKindOfClass:NSDictionary.class]) return;

    id value = nil;
    value = dictionary[@"eyeEnabled"];
    if (value) self.eyeEnabled = [value boolValue];
    value = dictionary[@"eyeMode"];
    if (value) self.eyeMode = EREyeModeFromObject(value, self.eyeMode);
    value = dictionary[@"eyeFocusSeconds"];
    if (value) self.eyeFocusSeconds = ERClampInteger([value integerValue], 10, 8 * 60 * 60);
    value = dictionary[@"eyeRestSeconds"];
    if (value) self.eyeRestSeconds = ERClampInteger([value integerValue], 10, 60 * 60);

    value = dictionary[@"standEnabled"];
    if (value) self.standEnabled = [value boolValue];
    value = dictionary[@"standIntervalSeconds"];
    if (value) self.standIntervalSeconds = ERClampInteger([value integerValue], 10, 8 * 60 * 60);
    value = dictionary[@"standDurationSeconds"];
    if (value) self.standDurationSeconds = ERClampInteger([value integerValue], 10, 2 * 60 * 60);
    value = dictionary[@"standRoutine"];
    if (value) self.standRoutine = ERStandRoutineFromObject(value, self.standRoutine);
    value = dictionary[@"standIntensity"];
    if (value) self.standIntensity = ERStandIntensityFromObject(value, self.standIntensity);
    value = dictionary[@"standCustomStages"];
    if (value) self.standCustomStagesText = ERSanitizedStandCustomStagesTextFromObject(value);

    value = dictionary[@"showRestWindow"];
    if (value) self.showRestWindow = [value boolValue];
    value = dictionary[@"restWindowTopmost"];
    if (value) self.restWindowTopmost = [value boolValue];
    value = dictionary[@"notificationsEnabled"];
    if (value) self.notificationsEnabled = [value boolValue];
    value = dictionary[@"restStyle"];
    if (value) self.restStyle = ERRestStyleFromObject(value, self.restStyle);
    value = dictionary[@"menuBarMode"];
    if (value) self.menuBarMode = ERMenuBarModeFromObject(value, self.menuBarMode);
    value = dictionary[@"launchAtLogin"];
    if (value) self.launchAtLogin = [value boolValue];

    value = dictionary[@"autoFocusModeEnabled"];
    if (value) self.autoFocusModeEnabled = [value boolValue];
    value = dictionary[@"calendarFocusModeEnabled"];
    if (value) self.calendarFocusModeEnabled = [value boolValue];
    value = dictionary[@"presentationFocusModeEnabled"];
    if (value) self.presentationFocusModeEnabled = [value boolValue];
    value = dictionary[@"quietHoursEnabled"];
    if (value) self.quietHoursEnabled = [value boolValue];
    value = dictionary[@"quietHoursStart"];
    if (value) self.quietHoursStartMinute = ERMinuteOfDayFromClockString([value description], self.quietHoursStartMinute);
    value = dictionary[@"quietHoursEnd"];
    if (value) self.quietHoursEndMinute = ERMinuteOfDayFromClockString([value description], self.quietHoursEndMinute);

    value = dictionary[@"focusAppTokens"];
    if (value) self.focusAppTokens = ERSanitizedFocusAppTokensFromObject(value);
    value = dictionary[@"autoPauseAppTokens"];
    if (value) self.autoPauseAppTokens = ERSanitizedFocusAppTokensFromObject(value);
    value = dictionary[@"ignoreAppTokens"];
    if (value) self.ignoreAppTokens = ERSanitizedFocusAppTokensFromObject(value);
    value = dictionary[@"calendarFocusTokens"];
    if (value) self.calendarFocusTokens = ERSanitizedFocusAppTokensFromObject(value);
    value = dictionary[@"calendarAutoPauseTokens"];
    if (value) self.calendarAutoPauseTokens = ERSanitizedFocusAppTokensFromObject(value);
}

@end

@class ERAppDelegate;

@interface NSObject (ERRestOverlayYielding)
- (BOOL)er_shouldYieldForMouseDown:(NSEvent *)event;
- (void)er_yieldRestOverlayForUserFocusChange:(id)sender;
@end

@interface EROverlayWindow : NSWindow
@end

@implementation EROverlayWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

- (BOOL)canBecomeMainWindow {
    return YES;
}

- (void)sendEvent:(NSEvent *)event {
    if (event.type == NSEventTypeLeftMouseDown) {
        id controller = self.windowController;
        if ([controller respondsToSelector:@selector(er_shouldYieldForMouseDown:)] &&
            [controller er_shouldYieldForMouseDown:event]) {
            [controller er_yieldRestOverlayForUserFocusChange:self];
            return;
        }
    }
    [super sendEvent:event];
}

- (void)mouseDown:(NSEvent *)event {
    id controller = self.windowController;
    if ([controller respondsToSelector:@selector(er_shouldYieldForMouseDown:)] &&
        [controller er_shouldYieldForMouseDown:event]) {
        [controller er_yieldRestOverlayForUserFocusChange:self];
        return;
    }
    [super mouseDown:event];
}

- (void)keyDown:(NSEvent *)event {
    if (event.keyCode == 53 || [event.charactersIgnoringModifiers isEqualToString:@"\x1b"]) {
        id controller = self.windowController;
        if ([controller respondsToSelector:@selector(cancelOperation:)]) {
            [controller cancelOperation:self];
            return;
        }
    }
    [super keyDown:event];
}

@end

@interface ERRestOverlayContentView : NSView
@end

@implementation ERRestOverlayContentView

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

@end

@interface ERRestActionButton : NSButton
@end

@implementation ERRestActionButton

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

@end

@interface ERSettingsWindow : NSWindow
@end

@implementation ERSettingsWindow

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
@property(nonatomic, strong) NSView *standStagePanel;
@property(nonatomic, strong) NSTextField *standStageEyebrowLabel;
@property(nonatomic, strong) NSTextField *standStageCurrentLabel;
@property(nonatomic, strong) NSTextField *standStageNextLabel;
@property(nonatomic, strong) NSView *standStageProgressTrack;
@property(nonatomic, strong) NSView *standStageProgressFill;
@property(nonatomic, strong) NSArray<NSString *> *actionStageTitles;
@property(nonatomic, strong) NSArray<NSString *> *actionStageMessages;
@property(nonatomic, strong) NSArray<NSString *> *actionSuggestions;
@property(nonatomic, strong) NSArray<NSString *> *actionSuggestionSymbols;
@property(nonatomic) NSInteger activeSuggestionIndex;
@property(nonatomic) NSTimeInterval totalDuration;
@property(nonatomic) ERRestStyle currentStyle;
- (instancetype)initWithAppDelegate:(ERAppDelegate *)appDelegate;
- (ERRestActionButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action;
- (void)configureForKind:(ERReminderKind)kind settings:(ERSettings *)settings duration:(NSTimeInterval)duration;
- (void)updateRemaining:(NSTimeInterval)remaining;
- (void)configureActionSuggestionsForKind:(ERReminderKind)kind settings:(ERSettings *)settings;
- (void)applyWindowLevelForSettings:(ERSettings *)settings;
- (void)refreshActionBindings;
- (BOOL)hasHealthyActionBindings;
- (void)updateActionSuggestionForRemaining:(NSTimeInterval)remaining;
- (void)layoutRestContent;
- (void)refitToCurrentScreen;
- (void)presentOverlay;
@end

@interface ERSettingsWindowController : NSWindowController <NSWindowDelegate>
@property(nonatomic, weak) ERAppDelegate *appDelegate;
@property(nonatomic, strong) ERSettings *settings;
@property(nonatomic, strong) NSButton *eyeEnabledSwitch;
@property(nonatomic, strong) NSPopUpButton *eyeModePopup;
@property(nonatomic, strong) ERTimeInput *eyeFocusInput;
@property(nonatomic, strong) ERTimeInput *eyeRestInput;
@property(nonatomic, strong) NSView *eyeSummaryBand;
@property(nonatomic, strong) NSImageView *eyeSummaryIcon;
@property(nonatomic, strong) NSTextField *eyeSummaryTitleLabel;
@property(nonatomic, strong) NSTextField *eyeSummaryDetailLabel;
@property(nonatomic, strong) NSTextField *eyeSummaryBadgeLabel;
@property(nonatomic, strong) NSButton *standEnabledSwitch;
@property(nonatomic, strong) ERTimeInput *standIntervalInput;
@property(nonatomic, strong) ERTimeInput *standDurationInput;
@property(nonatomic, strong) NSPopUpButton *standRoutinePopup;
@property(nonatomic, strong) NSTextField *standRoutineHintLabel;
@property(nonatomic, strong) NSPopUpButton *standIntensityPopup;
@property(nonatomic, strong) NSTextField *standIntensityHintLabel;
@property(nonatomic, strong) NSButton *standCustomStagesButton;
@property(nonatomic, strong) NSTextField *standCustomStagesSummaryLabel;
@property(nonatomic, strong) NSView *standSummaryBand;
@property(nonatomic, strong) NSImageView *standSummaryIcon;
@property(nonatomic, strong) NSTextField *standSummaryTitleLabel;
@property(nonatomic, strong) NSTextField *standSummaryDetailLabel;
@property(nonatomic, strong) NSTextField *standSummaryBadgeLabel;
@property(nonatomic, strong) NSButton *notificationSwitch;
@property(nonatomic, strong) NSButton *restWindowSwitch;
@property(nonatomic, strong) NSButton *restWindowTopmostSwitch;
@property(nonatomic, strong) NSButton *launchAtLoginSwitch;
@property(nonatomic, strong) NSButton *autoFocusSwitch;
@property(nonatomic, strong) NSButton *calendarFocusSwitch;
@property(nonatomic, strong) NSButton *presentationFocusSwitch;
@property(nonatomic, strong) NSButton *quietHoursSwitch;
@property(nonatomic, strong) NSTextField *quietHoursStartField;
@property(nonatomic, strong) NSTextField *quietHoursEndField;
@property(nonatomic, strong) NSTextField *quietHoursStatusLabel;
@property(nonatomic, strong) NSTextField *focusAppTokensField;
@property(nonatomic, strong) NSTextField *autoPauseAppTokensField;
@property(nonatomic, strong) NSTextField *ignoreAppTokensField;
@property(nonatomic, strong) NSTextField *calendarFocusTokensField;
@property(nonatomic, strong) NSTextField *calendarAutoPauseTokensField;
@property(nonatomic, strong) NSTextField *focusAppMatchLabel;
@property(nonatomic, strong) NSTextField *calendarStatusLabel;
@property(nonatomic, strong) NSTextField *focusAppHintLabel;
@property(nonatomic, strong) NSTextField *automationPolicyLabel;
@property(nonatomic, strong) NSTextField *automationLastActionLabel;
@property(nonatomic, strong) NSView *automationStatusStripe;
@property(nonatomic, strong) NSButton *focusAppResetButton;
@property(nonatomic, strong) NSPopUpButton *menuBarModePopup;
@property(nonatomic, strong) NSPopUpButton *restStylePopup;
@property(nonatomic, strong) NSTextField *summaryLabel;
@property(nonatomic, strong) NSTextField *overviewEyeStatusLabel;
@property(nonatomic, strong) NSTextField *overviewEyeTimerLabel;
@property(nonatomic, strong) NSTextField *overviewEyeMetaLabel;
@property(nonatomic, strong) NSProgressIndicator *overviewEyeProgress;
@property(nonatomic, strong) NSImageView *overviewEyeIcon;
@property(nonatomic, strong) NSTextField *overviewStandStatusLabel;
@property(nonatomic, strong) NSTextField *overviewStandTimerLabel;
@property(nonatomic, strong) NSTextField *overviewStandMetaLabel;
@property(nonatomic, strong) NSProgressIndicator *overviewStandProgress;
@property(nonatomic, strong) NSImageView *overviewStandIcon;
@property(nonatomic, strong) NSView *overviewStatusBand;
@property(nonatomic, strong) NSImageView *overviewStatusIcon;
@property(nonatomic, strong) NSTextField *overviewStatusTitleLabel;
@property(nonatomic, strong) NSTextField *overviewStatusDetailLabel;
@property(nonatomic, strong) NSTextField *overviewStatusBadgeLabel;
@property(nonatomic, strong) NSTextField *overviewTodayLabel;
@property(nonatomic, strong) NSTextField *overviewModeLabel;
@property(nonatomic, strong) NSTextField *overviewHintLabel;
@property(nonatomic, strong) NSView *overviewActionBar;
@property(nonatomic, strong) NSArray<NSView *> *overviewActionButtonShells;
@property(nonatomic, strong) NSButton *overviewRestEyeButton;
@property(nonatomic, strong) NSButton *overviewRestStandButton;
@property(nonatomic, strong) NSButton *overviewPauseButton;
@property(nonatomic, strong) NSButton *overviewIssueButton;
@property(nonatomic, strong) NSButton *overviewQuickSetupButton;
@property(nonatomic, strong) NSArray<NSButton *> *overviewActionButtons;
@property(nonatomic, strong) NSTextField *statsOverviewLabel;
@property(nonatomic, strong) NSTextField *statsMonthLabel;
@property(nonatomic, strong) NSTextField *statsStrategyLabel;
@property(nonatomic, strong) NSTextField *statsInsightLabel;
@property(nonatomic, strong) NSTextField *statsQualityLabel;
@property(nonatomic, strong) NSTextField *statsStandLabel;
@property(nonatomic, strong) NSTextField *statsStreakLabel;
@property(nonatomic, strong) NSTextField *statsMonthDetailLabel;
@property(nonatomic, strong) NSButton *exportStatsButton;
@property(nonatomic, strong) NSButton *exportBackupButton;
@property(nonatomic, strong) NSButton *importBackupButton;
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
@property(nonatomic, strong) NSView *overviewCard;
@property(nonatomic, strong) NSArray<NSView *> *overviewTiles;
@property(nonatomic, strong) NSArray<NSTextField *> *overviewLabels;
@property(nonatomic, strong) NSView *eyeCard;
@property(nonatomic, strong) NSView *standCard;
@property(nonatomic, strong) NSArray<NSView *> *summaryBandViews;
@property(nonatomic, strong) NSArray<NSTextField *> *summaryBandLabels;
@property(nonatomic, strong) NSArray<NSImageView *> *summaryBandIcons;
@property(nonatomic, strong) NSView *alertCard;
@property(nonatomic, strong) NSView *automationCard;
@property(nonatomic, strong) NSView *statsCard;
@property(nonatomic, strong) NSView *contentView;
@property(nonatomic, strong) NSVisualEffectView *headerView;
@property(nonatomic, strong) NSView *sidebarDividerView;
@property(nonatomic, strong) NSView *sidebarBrandBadge;
@property(nonatomic, strong) NSImageView *sidebarBrandIcon;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *sidebarSubtitleLabel;
@property(nonatomic, strong) NSView *sidebarSummaryCard;
@property(nonatomic, strong) NSTextField *sidebarEyebrowLabel;
@property(nonatomic, strong) NSTextField *sidebarSectionLabel;
@property(nonatomic, strong) NSTextField *sidebarFooterLabel;
@property(nonatomic, strong) NSArray<NSTextField *> *sidebarLabels;
@property(nonatomic, strong) NSArray<NSButton *> *sidebarButtons;
@property(nonatomic, strong) NSArray<NSView *> *sidebarSelectionViews;
@property(nonatomic, strong) NSArray<NSTextField *> *sidebarNavTitleLabels;
@property(nonatomic, strong) NSArray<NSImageView *> *sidebarNavIconViews;
@property(nonatomic, strong) NSArray<NSView *> *pageIconBadgeViews;
@property(nonatomic, strong) NSArray<NSImageView *> *pageIconViews;
@property(nonatomic, strong) NSArray<NSView *> *pageAccentViews;
@property(nonatomic, strong) NSArray<NSTextField *> *pageTitleLabels;
@property(nonatomic, strong) NSArray<NSTextField *> *pageSubtitleLabels;
@property(nonatomic, strong) NSArray<NSTextField *> *fieldLabels;
@property(nonatomic, strong) NSArray<NSView *> *settingRowViews;
@property(nonatomic, strong) NSArray<NSView *> *settingDividerViews;
@property(nonatomic, strong) NSVisualEffectView *footerView;
@property(nonatomic, strong) NSView *footerDivider;
@property(nonatomic, strong) NSButton *applyButton;
@property(nonatomic, strong) NSButton *resetButton;
@property(nonatomic, strong) NSSegmentedControl *paneControl;
@property(nonatomic) NSInteger selectedPage;
- (instancetype)initWithSettings:(ERSettings *)settings appDelegate:(ERAppDelegate *)appDelegate;
- (void)refreshControls;
- (void)refreshOverview;
- (void)refreshStats;
- (void)refreshAutomationStatus;
- (void)refreshSidebarAppearance;
- (void)openQuickSetup:(id)sender;
- (void)setSelectedPageIndex:(NSInteger)pageIndex;
- (void)exportStatsCSV:(id)sender;
- (void)exportStatsJSON:(id)sender;
- (void)importBackupJSON:(id)sender;
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
@property(nonatomic) BOOL focusModeEnabled;
@property(nonatomic) BOOL autoFocusActive;
@property(nonatomic) BOOL autoPauseActive;
@property(nonatomic) BOOL appAutoPauseActive;
@property(nonatomic) BOOL autoIgnoreActive;
@property(nonatomic) BOOL calendarFocusActive;
@property(nonatomic) BOOL calendarAutoPauseActive;
@property(nonatomic) BOOL presentationFocusActive;
@property(nonatomic) BOOL quietHoursActive;
@property(nonatomic) BOOL calendarAccessRequested;
@property(nonatomic, strong) EKEventStore *eventStore;
@property(nonatomic, strong) NSDate *lastCalendarRefreshAt;
@property(nonatomic, copy) NSString *currentCalendarEventTitle;
@property(nonatomic, copy) NSString *frontmostAppName;
@property(nonatomic, copy) NSString *frontmostAppBundleIdentifier;
@property(nonatomic, copy) NSString *lastExternalAppName;
@property(nonatomic, copy) NSString *lastExternalAppBundleIdentifier;
@property(nonatomic) NSInteger todayEyeDone;
@property(nonatomic) NSInteger todayStandDone;
@property(nonatomic) NSInteger todayStandSeconds;
@property(nonatomic) NSInteger todaySnoozed;
@property(nonatomic) NSInteger todaySkipped;
@property(nonatomic) NSInteger todayManualDone;
@property(nonatomic) NSInteger todayNotificationOnly;
@property(nonatomic) NSInteger todayAutoPauseSessions;
@property(nonatomic) NSInteger todayAutoPauseSeconds;
@property(nonatomic) BOOL autoPauseSessionActive;
@property(nonatomic, strong) NSDate *lastAutomationActionAt;
@property(nonatomic, copy) NSString *lastAutomationActionText;
@property(nonatomic, strong) NSDate *lastStandCompletedAt;
@property(nonatomic, copy) NSString *lastStandCompletionText;
@property(nonatomic, copy) NSString *lastStandCompletionAdvice;
@property(nonatomic, strong) NSDate *lastSystemEventAt;
@property(nonatomic, copy) NSString *lastSystemEventTitle;
@property(nonatomic, copy) NSString *lastRecoveryDetail;
@property(nonatomic, copy) NSString *lastScreenDiagnosticSummary;
@property(nonatomic, copy) NSString *lastDisplayChangePreviousSummary;
@property(nonatomic, copy) NSString *lastDisplayChangeCurrentSummary;
@property(nonatomic, strong) NSDate *lastDisplayChangeAt;
@property(nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *recoveryEventHistory;
@property(nonatomic) NSUInteger recoveryFollowUpGeneration;
@property(nonatomic) NSUInteger recoveryStressTestGeneration;
@property(nonatomic) NSUInteger lunchRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger sleepHiddenRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger displayRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger displayBoundsStressTestGeneration;
@property(nonatomic) NSUInteger settingsWindowRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger realDisplayCheckGeneration;
@property(nonatomic) NSUInteger overlayYieldStressTestGeneration;
@property(nonatomic) NSUInteger windowLayerPolicyStressTestGeneration;
@property(nonatomic) NSUInteger recoveryMatrixSuiteGeneration;
@property(nonatomic) NSUInteger automationPolicyStressTestGeneration;
@property(nonatomic) NSUInteger presentationPolicyStressTestGeneration;
@property(nonatomic) NSUInteger realPresentationPolicyCheckGeneration;
@property(nonatomic) NSUInteger calendarPolicyStressTestGeneration;
@property(nonatomic) NSUInteger realCalendarPolicyCheckGeneration;
@property(nonatomic) NSUInteger longAwayRecoveryStressTestGeneration;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *longAwayRecoveryStatsSnapshot;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *automationPolicyStatsSnapshot;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *presentationPolicyStatsSnapshot;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *realPresentationPolicyStatsSnapshot;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *calendarPolicyStatsSnapshot;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *realCalendarPolicyStatsSnapshot;
@property(nonatomic, strong) ERRestWindowController *restWindowController;
@property(nonatomic, strong) ERSettingsWindowController *settingsWindowController;
@property(nonatomic) BOOL restOverlayYielded;
- (void)finishRestForKind:(ERReminderKind)kind;
- (void)finishRestForKind:(ERReminderKind)kind manually:(BOOL)manually;
- (void)extendRestForKind:(ERReminderKind)kind bySeconds:(NSTimeInterval)seconds;
- (void)snoozeRestForKind:(ERReminderKind)kind bySeconds:(NSTimeInterval)seconds;
- (void)skipRestForKind:(ERReminderKind)kind;
- (void)emergencyCloseRestOverlay:(id)sender;
- (void)settingsDidChangeShouldReset:(BOOL)shouldReset;
- (void)settleExpiredRests;
- (void)repairRestOverlayAfterDisplayChange;
- (BOOL)repairSettingsWindowAfterDisplayChange;
- (void)repairRestOverlayAfterSystemEvent:(NSNotification *)notification;
- (void)scheduleRecoveryFollowUpChecksWithTitle:(NSString *)eventTitle;
- (void)runRecoveryFollowUpCheckWithTitle:(NSString *)eventTitle pass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)applicationDidResignActive:(NSNotification *)notification;
- (void)normalizeWindowLevelsForCurrentSettings;
- (void)demoteSettingsWindowAfterResignActive;
- (void)frontmostApplicationDidChange:(NSNotification *)notification;
- (void)activeSpaceDidChange:(NSNotification *)notification;
- (void)repairRestStateIfNeeded;
- (NSInteger)closeOrphanRestWindows;
- (void)noteRecoveryEventTitle:(NSString *)title detail:(NSString *)detail;
- (NSString *)recoveryDiagnosticText;
- (NSArray<NSString *> *)recoveryHistoryLines;
- (BOOL)recoveryHistoryContainsAny:(NSArray<NSString *> *)needles;
- (NSString *)detailedRecoveryDiagnosticText;
- (NSString *)applicationDiagnosticText;
- (NSString *)displayDiagnosticText;
- (NSArray<NSDictionary<NSString *, id> *> *)recoveryScenarioDefinitions;
- (NSString *)recoveryMatrixDiagnosticText;
- (NSString *)recoveryReportDiagnosticText;
- (NSString *)supportBundleDiagnosticText;
- (NSString *)issueBundleDiagnosticText;
- (NSString *)productSupportSummaryText;
- (NSString *)installGuideText;
- (NSString *)distributionPlanText;
- (NSString *)roadmapStatusText;
- (NSString *)autoUpdateReadinessText;
- (void)copyRecoveryDiagnostic:(id)sender;
- (void)copyApplicationDiagnostic:(id)sender;
- (void)copyDisplayDiagnostic:(id)sender;
- (void)copyRecoveryMatrixDiagnostic:(id)sender;
- (void)copyRecoveryReportDiagnostic:(id)sender;
- (void)copySupportBundleDiagnostic:(id)sender;
- (void)copyIssueBundleDiagnostic:(id)sender;
- (void)copyInstallGuide:(id)sender;
- (void)copyDistributionPlan:(id)sender;
- (void)copyRoadmapStatus:(id)sender;
- (void)copyAutoUpdateReadiness:(id)sender;
- (void)restEyeNow:(id)sender;
- (void)restStandNow:(id)sender;
- (void)pauseForSeconds:(NSTimeInterval)seconds;
- (void)runRecoverySelfCheck:(id)sender;
- (void)runRecoveryStressTest:(id)sender;
- (void)handleRecoveryStressTestRequest:(NSNotification *)notification;
- (void)runRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting previousStandDueAt:(NSDate *)previousStandDueAt previousStandRestEndsAt:(NSDate *)previousStandRestEndsAt previousStandResting:(BOOL)previousStandResting previousRestOverlayYielded:(BOOL)previousRestOverlayYielded diagnosticRestStarted:(BOOL)diagnosticRestStarted;
- (void)runLunchRecoveryStressTest:(id)sender;
- (void)runLunchRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runSleepHiddenRecoveryStressTest:(id)sender;
- (void)runSleepHiddenRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost;
- (void)runDisplayRecoveryStressTest:(id)sender;
- (void)runDisplayRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runDisplayBoundsStressTest:(id)sender;
- (void)runDisplayBoundsStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runSettingsWindowRecoveryStressTest:(id)sender;
- (void)runSettingsWindowRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runDisplayChangeTraceSelfCheck:(id)sender;
- (void)runRealDisplayCheck:(id)sender;
- (void)runRealDisplayCheckPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting previousStandDueAt:(NSDate *)previousStandDueAt previousStandRestEndsAt:(NSDate *)previousStandRestEndsAt previousStandResting:(BOOL)previousStandResting previousRestOverlayYielded:(BOOL)previousRestOverlayYielded;
- (void)runOverlayYieldStressTest:(id)sender;
- (void)runOverlayYieldStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost;
- (void)runWindowLayerPolicyStressTest:(id)sender;
- (void)runWindowLayerPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost;
- (void)runRecoveryMatrixSuite:(id)sender;
- (void)runRecoveryMatrixSuiteStep:(NSInteger)index total:(NSInteger)total title:(NSString *)title action:(NSString *)action generation:(NSUInteger)generation;
- (void)finishRecoveryMatrixSuiteWithTotal:(NSInteger)total generation:(NSUInteger)generation;
- (void)runAutomationPolicyStressTest:(id)sender;
- (void)runAutomationPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt;
- (void)runPresentationPolicyStressTest:(id)sender;
- (void)runPresentationPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt;
- (void)runRealPresentationPolicyCheck:(id)sender;
- (void)runRealPresentationPolicyCheckPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting;
- (void)runCalendarPolicyStressTest:(id)sender;
- (void)runCalendarPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt;
- (void)runRealCalendarPolicyCheck:(id)sender;
- (void)runRealCalendarPolicyCheckPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting;
- (void)runLongAwayRecoveryStressTest:(id)sender;
- (void)runLongAwayRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (NSString *)recoveryWindowDiagnosticLine;
- (void)yieldRestOverlayForUserFocusChange;
- (void)cleanupDiagnosticEyeRest;
- (void)showAbout:(id)sender;
- (void)openIssueFeedback:(id)sender;
- (void)checkForUpdates:(id)sender;
- (BOOL)quickRhythmMatchesItemInfo:(NSArray *)itemInfo;
- (BOOL)applyQuickRhythmToken:(NSString *)token detail:(NSString **)detail;
- (void)applyQuickRhythm:(NSMenuItem *)sender;
- (void)applyQuickSetupProfile:(NSString *)profile;
- (void)showQuickSetup:(id)sender;
- (void)quickSetupProfileChanged:(id)sender;
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
- (BOOL)handleAutomationURL:(NSURL *)url;
- (void)copyAutomationURL:(NSMenuItem *)sender;
- (NSString *)focusAutomationTemplateText;
- (void)copyFocusAutomationTemplate:(id)sender;
- (NSString *)automationDiagnosticText;
- (void)copyAutomationDiagnostic:(id)sender;
- (void)presentSettingsWindow;
- (void)presentSettingsPage:(NSString *)pageToken;
- (NSTimeInterval)remainingUntil:(NSDate *)date;
- (void)toggleRestWindowTopmost:(id)sender;
- (NSTimeInterval)configuredRestDurationForKind:(ERReminderKind)kind;
- (NSDate *)restEndDateForKind:(ERReminderKind)kind;
- (void)ensureRestWindowForKind:(ERReminderKind)kind remaining:(NSTimeInterval)remaining;
- (void)loadTodayStats;
- (void)saveTodayStats;
- (void)resetTodayStatsIfNeeded;
- (void)loadRecoveryHistory;
- (void)saveRecoveryHistory;
- (void)applyPreferenceSideEffects;
- (void)refreshFocusModeState;
- (void)requestCalendarAccessIfNeeded;
- (void)refreshCalendarFocusStateIfNeeded:(BOOL)force;
- (BOOL)isCurrentCalendarEvent:(EKEvent *)event now:(NSDate *)now;
- (NSString *)calendarDiagnosticText;
- (void)copyCalendarDiagnostic:(id)sender;
- (void)shiftReminderDatesBySeconds:(NSTimeInterval)seconds;
- (BOOL)isQuietHoursActiveNow;
- (BOOL)isLightDistractionModeActive;
- (NSString *)focusModeStatusText;
- (NSDictionary<NSString *, NSString *> *)automationPolicyExplanation;
- (void)recordAutomationAction:(NSString *)action reason:(NSString *)reason;
- (NSString *)lastAutomationActionSummary;
- (void)updateStatusItemAppearance;
- (NSDictionary *)statsHistoryIncludingToday;
@end

@implementation ERSettingsWindowController

- (instancetype)initWithSettings:(ERSettings *)settings appDelegate:(ERAppDelegate *)appDelegate {
    NSRect frame = NSMakeRect(0, 0, 944, 592);
    ERSettingsWindow *window = [[ERSettingsWindow alloc] initWithContentRect:frame
                                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                                                                     backing:NSBackingStoreBuffered
                                                                       defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;

    self.settings = settings;
    self.appDelegate = appDelegate;
    window.title = [NSString stringWithFormat:@"%@ 设置", ERBrandName];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.movableByWindowBackground = YES;
    window.delegate = self;
    window.releasedWhenClosed = NO;
    window.level = NSNormalWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorManaged;
    [window center];

    NSView *content = [[NSView alloc] initWithFrame:frame];
    content.wantsLayer = YES;
    content.layer.backgroundColor = ERColor(0.955, 0.965, 0.985, 1).CGColor;
    window.contentView = content;
    self.contentView = content;
    self.fieldLabels = @[];
    self.settingRowViews = @[];
    self.settingDividerViews = @[];
    self.summaryBandViews = @[];
    self.summaryBandLabels = @[];
    self.summaryBandIcons = @[];
    self.sidebarNavTitleLabels = @[];
    self.sidebarNavIconViews = @[];
    self.pageIconBadgeViews = @[];
    self.pageIconViews = @[];
    self.pageAccentViews = @[];

    NSVisualEffectView *header = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(0, 0, 232, 592)];
    header.material = NSVisualEffectMaterialSidebar;
    header.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    header.state = NSVisualEffectStateActive;
    [content addSubview:header];
    self.headerView = header;

    self.sidebarDividerView = [[NSView alloc] initWithFrame:NSMakeRect(231, 0, 1, 592)];
    self.sidebarDividerView.wantsLayer = YES;
    [content addSubview:self.sidebarDividerView positioned:NSWindowAbove relativeTo:header];

    self.sidebarBrandBadge = ERRoundedView(NSMakeRect(24, 512, 46, 46), [NSColor colorWithWhite:1 alpha:0.42], 14);
    self.sidebarBrandBadge.layer.borderWidth = 1;
    [header addSubview:self.sidebarBrandBadge];

    self.sidebarBrandIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(11, 11, 24, 24)];
    self.sidebarBrandIcon.image = [NSImage imageWithSystemSymbolName:@"leaf" accessibilityDescription:ERBrandName];
    self.sidebarBrandIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:21 weight:NSFontWeightSemibold];
    [self.sidebarBrandBadge addSubview:self.sidebarBrandIcon];

    NSTextField *title = [NSTextField labelWithString:ERBrandName];
    title.frame = NSMakeRect(82, 535, 126, 22);
    title.font = [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold];
    [header addSubview:title];
    self.titleLabel = title;

    NSTextField *subtitle = [NSTextField labelWithString:@"轻量休息节奏"];
    subtitle.frame = NSMakeRect(82, 513, 128, 18);
    subtitle.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    [header addSubview:subtitle];
    self.sidebarSubtitleLabel = subtitle;

    self.sidebarSummaryCard = ERRoundedView(NSMakeRect(20, 424, 192, 70), [NSColor colorWithWhite:1 alpha:0.36], 12);
    self.sidebarSummaryCard.layer.borderWidth = 1;
    self.sidebarSummaryCard.layer.masksToBounds = NO;
    [header addSubview:self.sidebarSummaryCard];

    self.sidebarEyebrowLabel = [NSTextField labelWithString:@"今日节奏"];
    self.sidebarEyebrowLabel.frame = NSMakeRect(14, 46, 150, 16);
    self.sidebarEyebrowLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    [self.sidebarSummaryCard addSubview:self.sidebarEyebrowLabel];

    self.summaryLabel = [NSTextField labelWithString:@""];
    self.summaryLabel.frame = NSMakeRect(14, 10, 164, 31);
    self.summaryLabel.font = [NSFont monospacedDigitSystemFontOfSize:11.5 weight:NSFontWeightMedium];
    self.summaryLabel.textColor = NSColor.secondaryLabelColor;
    [self.sidebarSummaryCard addSubview:self.summaryLabel];

    NSTextField *navCaption = [NSTextField labelWithString:@"设置项目"];
    navCaption.frame = NSMakeRect(28, 390, 160, 16);
    navCaption.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    [header addSubview:navCaption];
    self.sidebarSectionLabel = navCaption;

    NSDictionary *info = NSBundle.mainBundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"0.1.44";
    self.sidebarFooterLabel = [NSTextField labelWithString:[NSString stringWithFormat:@"版本 %@", version]];
    self.sidebarFooterLabel.frame = NSMakeRect(28, 26, 166, 18);
    self.sidebarFooterLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    [header addSubview:self.sidebarFooterLabel];
    self.sidebarLabels = @[subtitle, self.sidebarEyebrowLabel, navCaption, self.sidebarFooterLabel];

    self.paneControl = [[NSSegmentedControl alloc] initWithFrame:NSZeroRect];
    self.paneControl.segmentCount = 6;
    [self.paneControl setLabel:@"概览" forSegment:0];
    [self.paneControl setLabel:@"眼睛" forSegment:1];
    [self.paneControl setLabel:@"站立" forSegment:2];
    [self.paneControl setLabel:@"显示" forSegment:3];
    [self.paneControl setLabel:@"自动" forSegment:4];
    [self.paneControl setLabel:@"统计" forSegment:5];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"rectangle.grid.2x2" accessibilityDescription:@"概览"] forSegment:0];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"眼睛"] forSegment:1];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"figure.stand" accessibilityDescription:@"站立"] forSegment:2];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"bell" accessibilityDescription:@"显示"] forSegment:3];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:@"自动"] forSegment:4];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:@"统计"] forSegment:5];
    self.paneControl.segmentStyle = NSSegmentStyleSeparated;
    self.paneControl.target = self;
    self.paneControl.action = @selector(selectPane:);

    NSArray<NSString *> *navTitles = @[@"今日概览", @"眼睛休息", @"站立提醒", @"显示方式", @"自动化", @"休息统计"];
    NSArray<NSString *> *navIcons = @[@"rectangle.grid.2x2", @"eye", @"figure.stand", @"bell", @"wand.and.stars", @"chart.bar"];
    NSMutableArray *navButtons = [NSMutableArray arrayWithCapacity:navTitles.count];
    NSMutableArray *selectionViews = [NSMutableArray arrayWithCapacity:navTitles.count];
    NSMutableArray *navTitleLabels = [NSMutableArray arrayWithCapacity:navTitles.count];
    NSMutableArray *navIconViews = [NSMutableArray arrayWithCapacity:navTitles.count];
    for (NSInteger index = 0; index < navTitles.count; index++) {
        NSView *selection = ERRoundedView(NSMakeRect(18, 344 - index * 40, 196, 34), NSColor.clearColor, 9);
        selection.layer.masksToBounds = NO;
        [header addSubview:selection];
        [selectionViews addObject:selection];

        NSImageView *navIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(15, 8, 18, 18)];
        navIcon.image = [NSImage imageWithSystemSymbolName:navIcons[index] accessibilityDescription:navTitles[index]];
        navIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:15 weight:NSFontWeightMedium];
        [selection addSubview:navIcon];
        [navIconViews addObject:navIcon];

        NSTextField *navTitle = [NSTextField labelWithString:navTitles[index]];
        navTitle.frame = NSMakeRect(46, 7, 126, 18);
        navTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
        [selection addSubview:navTitle];
        [navTitleLabels addObject:navTitle];

        NSButton *button = [NSButton buttonWithTitle:@"" target:self action:@selector(selectSidebarPane:)];
        button.frame = selection.frame;
        [button setButtonType:NSButtonTypeToggle];
        button.bezelStyle = NSBezelStyleShadowlessSquare;
        button.bordered = NO;
        button.transparent = YES;
        button.focusRingType = NSFocusRingTypeNone;
        button.toolTip = navTitles[index];
        button.tag = index;
        [header addSubview:button];
        [navButtons addObject:button];
    }
    self.sidebarButtons = navButtons;
    self.sidebarSelectionViews = selectionViews;
    self.sidebarNavTitleLabels = navTitleLabels;
    self.sidebarNavIconViews = navIconViews;

    NSView *overviewPage = [self pageViewWithTitle:@"今日概览" subtitle:@"眼睛和站立是两条独立节奏，这里只放当前最需要看的状态。" symbol:@"rectangle.grid.2x2"];
    self.overviewCard = overviewPage.subviews.lastObject;
    [self buildOverviewSectionInView:overviewPage];
    [content addSubview:overviewPage];

    NSView *eyePage = [self pageViewWithTitle:@"眼睛休息提醒" subtitle:@"调试时可以填 0 分 10 秒。20-20-20 默认是 20 分钟后看远处 20 秒。" symbol:@"eye"];
    self.eyeCard = eyePage.subviews.lastObject;
    [self buildEyeSectionInView:eyePage];
    [content addSubview:eyePage];

    NSView *standPage = [self pageViewWithTitle:@"站立提醒" subtitle:@"默认每 2 小时提醒一次，站立 20 分钟。它和眼睛提醒独立计时。" symbol:@"figure.stand"];
    self.standCard = standPage.subviews.lastObject;
    [self buildStandSectionInView:standPage];
    [content addSubview:standPage];

    NSView *alertPage = [self pageViewWithTitle:@"提醒方式" subtitle:@"选择到点时如何提醒你。系统通知仍需在 macOS 通知设置里允许。" symbol:@"bell"];
    self.alertCard = alertPage.subviews.lastObject;
    [self buildAlertSectionInView:alertPage];
    [content addSubview:alertPage];

    NSView *automationPage = [self pageViewWithTitle:@"自动化" subtitle:@"会议、演示、视频或游戏时自动切到轻打扰：继续计时和通知，不弹全屏休息页。" symbol:@"wand.and.stars"];
    self.automationCard = automationPage.subviews.lastObject;
    [self buildAutomationSectionInView:automationPage];
    [content addSubview:automationPage];

    NSView *statsPage = [self pageViewWithTitle:@"休息统计" subtitle:@"看看最近 7 天有没有真的把休息做起来。统计只保存在本机。" symbol:@"chart.bar"];
    self.statsCard = statsPage.subviews.lastObject;
    [self buildStatsSectionInView:statsPage];
    [content addSubview:statsPage];

    self.pages = @[overviewPage, eyePage, standPage, alertPage, automationPage, statsPage];
    self.pageTitleLabels = @[
        [overviewPage.subviews objectAtIndex:0],
        [eyePage.subviews objectAtIndex:0],
        [standPage.subviews objectAtIndex:0],
        [alertPage.subviews objectAtIndex:0],
        [automationPage.subviews objectAtIndex:0],
        [statsPage.subviews objectAtIndex:0]
    ];
    self.pageSubtitleLabels = @[
        [overviewPage.subviews objectAtIndex:1],
        [eyePage.subviews objectAtIndex:1],
        [standPage.subviews objectAtIndex:1],
        [alertPage.subviews objectAtIndex:1],
        [automationPage.subviews objectAtIndex:1],
        [statsPage.subviews objectAtIndex:1]
    ];

    NSVisualEffectView *footer = [[NSVisualEffectView alloc] initWithFrame:NSMakeRect(232, 0, 712, 66)];
    footer.material = NSVisualEffectMaterialContentBackground;
    footer.blendingMode = NSVisualEffectBlendingModeWithinWindow;
    footer.state = NSVisualEffectStateActive;
    [content addSubview:footer positioned:NSWindowAbove relativeTo:nil];
    self.footerView = footer;

    NSView *footerDivider = [[NSView alloc] initWithFrame:NSMakeRect(0, 65, 712, 1)];
    footerDivider.wantsLayer = YES;
    [footer addSubview:footerDivider];
    self.footerDivider = footerDivider;

    self.applyButton = [NSButton buttonWithTitle:@"应用" target:self action:@selector(applySettings:)];
    self.applyButton.frame = NSMakeRect(592, 17, 88, 32);
    self.applyButton.bezelStyle = NSBezelStyleRounded;
    self.applyButton.keyEquivalent = @"\r";
    [footer addSubview:self.applyButton];

    self.resetButton = [NSButton buttonWithTitle:@"恢复默认" target:self action:@selector(resetDefaults:)];
    self.resetButton.frame = NSMakeRect(480, 17, 96, 32);
    self.resetButton.bezelStyle = NSBezelStyleRounded;
    [footer addSubview:self.resetButton];

    self.selectedPage = 0;
    [self updateSelectedPage];
    [self refreshControls];
    return self;
}

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
}

- (NSView *)pageViewWithTitle:(NSString *)titleText subtitle:(NSString *)subtitle symbol:(NSString *)symbolName {
    NSView *view = [[NSView alloc] initWithFrame:NSMakeRect(256, 86, 648, 430)];

    NSTextField *title = [NSTextField labelWithString:titleText];
    title.frame = NSMakeRect(54, 390, 486, 30);
    title.font = [NSFont systemFontOfSize:24 weight:NSFontWeightSemibold];
    [view addSubview:title];

    NSTextField *sub = [NSTextField wrappingLabelWithString:subtitle];
    sub.frame = NSMakeRect(54, 346, 568, 38);
    sub.font = [NSFont systemFontOfSize:13.5];
    sub.textColor = NSColor.secondaryLabelColor;
    sub.maximumNumberOfLines = 2;
    [view addSubview:sub];

    NSView *accent = ERRoundedView(NSMakeRect(54, 381, 88, 3), NSColor.controlAccentColor, 1.5);
    [view addSubview:accent];
    self.pageAccentViews = [self.pageAccentViews arrayByAddingObject:accent] ?: @[accent];

    NSView *iconBadge = ERRoundedView(NSMakeRect(0, 380, 42, 42), [NSColor colorWithWhite:1 alpha:0.48], 12);
    iconBadge.layer.borderWidth = 1;
    [view addSubview:iconBadge];

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(9, 9, 24, 24)];
    icon.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:titleText];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:22 weight:NSFontWeightSemibold];
    [iconBadge addSubview:icon];
    self.pageIconBadgeViews = [self.pageIconBadgeViews arrayByAddingObject:iconBadge] ?: @[iconBadge];
    self.pageIconViews = [self.pageIconViews arrayByAddingObject:icon] ?: @[icon];

    NSView *card = ERRoundedView(NSMakeRect(0, 0, 648, 306), NSColor.whiteColor, 14);
    card.layer.borderColor = ERColor(0.82, 0.84, 0.88, 0.56).CGColor;
    card.layer.borderWidth = 1;
    card.layer.masksToBounds = NO;
    card.layer.shadowColor = [NSColor.blackColor colorWithAlphaComponent:0.14].CGColor;
    card.layer.shadowOpacity = 0.08;
    card.layer.shadowRadius = 16;
    card.layer.shadowOffset = CGSizeMake(0, -4);
    [view addSubview:card];
    return view;
}

- (void)addSettingRowsToCard:(NSView *)card frames:(NSArray<NSValue *> *)frames dividerX:(CGFloat)dividerX dividerWidth:(CGFloat)dividerWidth {
    NSMutableArray<NSView *> *rows = [self.settingRowViews mutableCopy];
    NSMutableArray<NSView *> *dividers = [self.settingDividerViews mutableCopy];
    for (NSInteger index = 0; index < frames.count; index++) {
        NSRect frame = frames[index].rectValue;
        NSView *row = ERRoundedView(frame, [NSColor colorWithWhite:1 alpha:0.18], 0);
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

- (NSView *)summaryBandInCard:(NSView *)card
                        frame:(NSRect)frame
                       symbol:(NSString *)symbol
                         icon:(NSImageView **)iconOut
                        title:(NSTextField **)titleOut
                       detail:(NSTextField **)detailOut
                        badge:(NSTextField **)badgeOut {
    NSView *band = ERRoundedView(frame, [NSColor colorWithWhite:1 alpha:0.48], 14);
    band.layer.borderWidth = 1;
    [card addSubview:band];

    NSImageView *icon = [[NSImageView alloc] initWithFrame:NSMakeRect(14, frame.size.height - 34, 24, 24)];
    icon.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:nil];
    icon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:21 weight:NSFontWeightSemibold];
    [band addSubview:icon];

    NSTextField *title = [NSTextField labelWithString:@""];
    title.frame = NSMakeRect(48, frame.size.height - 24, 230, 18);
    title.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [band addSubview:title];

    NSTextField *detail = [NSTextField labelWithString:@""];
    detail.frame = NSMakeRect(48, 9, 330, 18);
    detail.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    [band addSubview:detail];

    NSTextField *badge = [NSTextField labelWithString:@""];
    badge.frame = NSMakeRect(frame.size.width - 132, frame.size.height - 28, 112, 20);
    badge.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    badge.alignment = NSTextAlignmentRight;
    [band addSubview:badge];

    if (iconOut) *iconOut = icon;
    if (titleOut) *titleOut = title;
    if (detailOut) *detailOut = detail;
    if (badgeOut) *badgeOut = badge;
    self.summaryBandViews = [self.summaryBandViews arrayByAddingObject:band] ?: @[band];
    self.summaryBandLabels = [[self.summaryBandLabels arrayByAddingObjectsFromArray:@[title, detail, badge]] copy] ?: @[title, detail, badge];
    self.summaryBandIcons = [self.summaryBandIcons arrayByAddingObject:icon] ?: @[icon];
    return band;
}

- (NSProgressIndicator *)overviewProgressWithFrame:(NSRect)frame {
    NSProgressIndicator *progress = [[NSProgressIndicator alloc] initWithFrame:frame];
    progress.indeterminate = NO;
    progress.minValue = 0;
    progress.maxValue = 1;
    progress.doubleValue = 0;
    progress.controlSize = NSControlSizeSmall;
    [progress setUsesThreadedAnimation:NO];
    return progress;
}

- (void)buildOverviewSectionInView:(NSView *)view {
    NSView *card = self.overviewCard;
    NSMutableArray<NSView *> *tiles = [NSMutableArray array];
    NSMutableArray<NSTextField *> *labels = [NSMutableArray array];
    NSMutableArray<NSView *> *actionShells = [NSMutableArray array];

    self.overviewStatusBand = ERRoundedView(NSMakeRect(24, 236, 600, 52), [NSColor colorWithWhite:1 alpha:0.38], 13);
    self.overviewStatusBand.layer.borderWidth = 1;
    [card addSubview:self.overviewStatusBand];
    [tiles addObject:self.overviewStatusBand];

    self.overviewStatusIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(16, 11, 24, 24)];
    self.overviewStatusIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:21 weight:NSFontWeightSemibold];
    [self.overviewStatusBand addSubview:self.overviewStatusIcon];

    self.overviewStatusTitleLabel = [NSTextField labelWithString:@""];
    self.overviewStatusTitleLabel.frame = NSMakeRect(52, 26, 330, 18);
    self.overviewStatusTitleLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [self.overviewStatusBand addSubview:self.overviewStatusTitleLabel];
    [labels addObject:self.overviewStatusTitleLabel];

    self.overviewStatusDetailLabel = [NSTextField labelWithString:@""];
    self.overviewStatusDetailLabel.frame = NSMakeRect(52, 9, 410, 16);
    self.overviewStatusDetailLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    [self.overviewStatusBand addSubview:self.overviewStatusDetailLabel];
    [labels addObject:self.overviewStatusDetailLabel];

    self.overviewStatusBadgeLabel = [NSTextField labelWithString:@""];
    self.overviewStatusBadgeLabel.frame = NSMakeRect(474, 16, 106, 20);
    self.overviewStatusBadgeLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.overviewStatusBadgeLabel.alignment = NSTextAlignmentRight;
    [self.overviewStatusBand addSubview:self.overviewStatusBadgeLabel];
    [labels addObject:self.overviewStatusBadgeLabel];

    NSView *eyeTile = ERRoundedView(NSMakeRect(24, 132, 290, 90), [NSColor colorWithWhite:1 alpha:0.38], 13);
    eyeTile.layer.borderWidth = 1;
    [card addSubview:eyeTile];
    [tiles addObject:eyeTile];

    NSView *standTile = ERRoundedView(NSMakeRect(334, 132, 290, 90), [NSColor colorWithWhite:1 alpha:0.38], 13);
    standTile.layer.borderWidth = 1;
    [card addSubview:standTile];
    [tiles addObject:standTile];

    self.overviewEyeIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(16, 54, 22, 22)];
    self.overviewEyeIcon.image = [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"眼睛"];
    self.overviewEyeIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightSemibold];
    [eyeTile addSubview:self.overviewEyeIcon];

    self.overviewEyeStatusLabel = [NSTextField labelWithString:@""];
    self.overviewEyeStatusLabel.frame = NSMakeRect(46, 58, 186, 20);
    self.overviewEyeStatusLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [eyeTile addSubview:self.overviewEyeStatusLabel];
    [labels addObject:self.overviewEyeStatusLabel];

    self.overviewEyeTimerLabel = [NSTextField labelWithString:@""];
    self.overviewEyeTimerLabel.frame = NSMakeRect(16, 25, 258, 32);
    self.overviewEyeTimerLabel.font = [NSFont monospacedDigitSystemFontOfSize:29 weight:NSFontWeightSemibold];
    [eyeTile addSubview:self.overviewEyeTimerLabel];
    [labels addObject:self.overviewEyeTimerLabel];

    self.overviewEyeProgress = [self overviewProgressWithFrame:NSMakeRect(16, 20, 258, 4)];
    [eyeTile addSubview:self.overviewEyeProgress];

    self.overviewEyeMetaLabel = [NSTextField labelWithString:@""];
    self.overviewEyeMetaLabel.frame = NSMakeRect(16, 4, 258, 15);
    self.overviewEyeMetaLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    [eyeTile addSubview:self.overviewEyeMetaLabel];
    [labels addObject:self.overviewEyeMetaLabel];

    self.overviewStandIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(16, 54, 22, 22)];
    self.overviewStandIcon.image = [NSImage imageWithSystemSymbolName:@"figure.stand" accessibilityDescription:@"站立"];
    self.overviewStandIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:20 weight:NSFontWeightSemibold];
    [standTile addSubview:self.overviewStandIcon];

    self.overviewStandStatusLabel = [NSTextField labelWithString:@""];
    self.overviewStandStatusLabel.frame = NSMakeRect(46, 58, 186, 20);
    self.overviewStandStatusLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [standTile addSubview:self.overviewStandStatusLabel];
    [labels addObject:self.overviewStandStatusLabel];

    self.overviewStandTimerLabel = [NSTextField labelWithString:@""];
    self.overviewStandTimerLabel.frame = NSMakeRect(16, 25, 258, 32);
    self.overviewStandTimerLabel.font = [NSFont monospacedDigitSystemFontOfSize:29 weight:NSFontWeightSemibold];
    [standTile addSubview:self.overviewStandTimerLabel];
    [labels addObject:self.overviewStandTimerLabel];

    self.overviewStandProgress = [self overviewProgressWithFrame:NSMakeRect(16, 20, 258, 4)];
    [standTile addSubview:self.overviewStandProgress];

    self.overviewStandMetaLabel = [NSTextField labelWithString:@""];
    self.overviewStandMetaLabel.frame = NSMakeRect(16, 4, 258, 15);
    self.overviewStandMetaLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    [standTile addSubview:self.overviewStandMetaLabel];
    [labels addObject:self.overviewStandMetaLabel];

    self.overviewTodayLabel = [NSTextField wrappingLabelWithString:@""];
    self.overviewTodayLabel.frame = NSMakeRect(30, 100, 286, 18);
    self.overviewTodayLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.overviewTodayLabel.maximumNumberOfLines = 2;
    [card addSubview:self.overviewTodayLabel];
    [labels addObject:self.overviewTodayLabel];

    self.overviewModeLabel = [NSTextField wrappingLabelWithString:@""];
    self.overviewModeLabel.frame = NSMakeRect(334, 100, 286, 18);
    self.overviewModeLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.overviewModeLabel.maximumNumberOfLines = 2;
    [card addSubview:self.overviewModeLabel];
    [labels addObject:self.overviewModeLabel];

    self.overviewHintLabel = [NSTextField wrappingLabelWithString:@""];
    self.overviewHintLabel.frame = NSMakeRect(30, 68, 590, 18);
    self.overviewHintLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.overviewHintLabel.maximumNumberOfLines = 1;
    [card addSubview:self.overviewHintLabel];
    [labels addObject:self.overviewHintLabel];

    self.overviewActionBar = ERRoundedView(NSMakeRect(24, 22, 600, 34), [NSColor colorWithWhite:1 alpha:0.25], 11);
    self.overviewActionBar.layer.borderWidth = 1;
    [card addSubview:self.overviewActionBar];
    [tiles addObject:self.overviewActionBar];

    NSArray<NSValue *> *actionFrames = @[
        [NSValue valueWithRect:NSMakeRect(8, 5, 110, 24)],
        [NSValue valueWithRect:NSMakeRect(126, 5, 110, 24)],
        [NSValue valueWithRect:NSMakeRect(244, 5, 110, 24)],
        [NSValue valueWithRect:NSMakeRect(362, 5, 110, 24)],
        [NSValue valueWithRect:NSMakeRect(480, 5, 112, 24)]
    ];
    for (NSValue *value in actionFrames) {
        NSView *shell = ERRoundedView(value.rectValue, [NSColor colorWithWhite:1 alpha:0.34], 7);
        shell.layer.borderWidth = 1;
        [self.overviewActionBar addSubview:shell];
        [actionShells addObject:shell];
    }

    self.overviewRestEyeButton = [self overviewActionButtonWithTitle:@"眼睛" symbol:@"eye" action:@selector(overviewRestEyeNow:) frame:actionFrames[0].rectValue];
    self.overviewRestEyeButton.toolTip = @"立即开始一次眼睛休息";
    [self.overviewActionBar addSubview:self.overviewRestEyeButton];

    self.overviewRestStandButton = [self overviewActionButtonWithTitle:@"站立" symbol:@"figure.stand" action:@selector(overviewRestStandNow:) frame:actionFrames[1].rectValue];
    self.overviewRestStandButton.toolTip = @"立即开始一次站立提醒";
    [self.overviewActionBar addSubview:self.overviewRestStandButton];

    self.overviewPauseButton = [self overviewActionButtonWithTitle:@"暂停 30" symbol:@"pause" action:@selector(overviewPauseThirtyMinutes:) frame:actionFrames[2].rectValue];
    self.overviewPauseButton.toolTip = @"暂停提醒 30 分钟";
    [self.overviewActionBar addSubview:self.overviewPauseButton];

    self.overviewIssueButton = [self overviewActionButtonWithTitle:@"反馈包" symbol:@"doc.on.doc" action:@selector(overviewCopyIssueBundle:) frame:actionFrames[3].rectValue];
    self.overviewIssueButton.toolTip = @"复制问题反馈包";
    [self.overviewActionBar addSubview:self.overviewIssueButton];

    self.overviewQuickSetupButton = [self overviewActionButtonWithTitle:@"配置" symbol:@"slider.horizontal.3" action:@selector(openQuickSetup:) frame:actionFrames[4].rectValue];
    self.overviewQuickSetupButton.toolTip = @"打开快速配置";
    [self.overviewActionBar addSubview:self.overviewQuickSetupButton];

    self.overviewActionButtons = @[
        self.overviewRestEyeButton,
        self.overviewRestStandButton,
        self.overviewPauseButton,
        self.overviewIssueButton,
        self.overviewQuickSetupButton
    ];
    self.overviewActionButtonShells = actionShells;

    self.overviewTiles = tiles;
    self.overviewLabels = labels;
}

- (void)buildEyeSectionInView:(NSView *)view {
    NSView *card = self.eyeCard;
    NSImageView *eyeSummaryIcon = nil;
    NSTextField *eyeSummaryTitle = nil;
    NSTextField *eyeSummaryDetail = nil;
    NSTextField *eyeSummaryBadge = nil;
    self.eyeSummaryBand = [self summaryBandInCard:card
                                            frame:NSMakeRect(24, 232, 600, 54)
                                           symbol:@"eye"
                                             icon:&eyeSummaryIcon
                                            title:&eyeSummaryTitle
                                           detail:&eyeSummaryDetail
                                            badge:&eyeSummaryBadge];
    self.eyeSummaryIcon = eyeSummaryIcon;
    self.eyeSummaryTitleLabel = eyeSummaryTitle;
    self.eyeSummaryDetailLabel = eyeSummaryDetail;
    self.eyeSummaryBadgeLabel = eyeSummaryBadge;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(24, 176, 600, 42)],
        [NSValue valueWithRect:NSMakeRect(24, 128, 600, 42)],
        [NSValue valueWithRect:NSMakeRect(24, 80, 600, 42)],
        [NSValue valueWithRect:NSMakeRect(24, 32, 600, 42)]
    ] dividerX:158 dividerWidth:442];

    self.eyeEnabledSwitch = [NSButton checkboxWithTitle:@"启用眼睛休息提醒" target:self action:@selector(toggleOnly:)];
    self.eyeEnabledSwitch.frame = NSMakeRect(38, 185, 190, 24);
    [card addSubview:self.eyeEnabledSwitch];

    [card addSubview:[self fieldLabel:@"使用电脑：" frame:NSMakeRect(38, 139, 104, 22)]];
    self.eyeFocusInput = [self addTimeFieldsToView:card x:174 y:135];

    [card addSubview:[self fieldLabel:@"休息：" frame:NSMakeRect(38, 91, 104, 22)]];
    self.eyeRestInput = [self addTimeFieldsToView:card x:174 y:87];

    [card addSubview:[self fieldLabel:@"节奏：" frame:NSMakeRect(38, 43, 104, 22)]];
    self.eyeModePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(174, 39, 228, 30) pullsDown:NO];
    [self.eyeModePopup addItemsWithTitles:@[EREyeModeTitle(EREyeMode202020), EREyeModeTitle(EREyeModePomodoro), EREyeModeTitle(EREyeModeCustom)]];
    self.eyeModePopup.target = self;
    self.eyeModePopup.action = @selector(eyeModeChanged:);
    [card addSubview:self.eyeModePopup];

    NSButton *ruleButton = [NSButton buttonWithTitle:@"20-20-20" target:self action:@selector(use202020:)];
    ruleButton.frame = NSMakeRect(428, 39, 112, 30);
    ruleButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:ruleButton];
}

- (void)buildStandSectionInView:(NSView *)view {
    NSView *card = self.standCard;
    NSImageView *standSummaryIcon = nil;
    NSTextField *standSummaryTitle = nil;
    NSTextField *standSummaryDetail = nil;
    NSTextField *standSummaryBadge = nil;
    self.standSummaryBand = [self summaryBandInCard:card
                                              frame:NSMakeRect(24, 232, 600, 54)
                                             symbol:@"figure.stand"
                                               icon:&standSummaryIcon
                                              title:&standSummaryTitle
                                             detail:&standSummaryDetail
                                              badge:&standSummaryBadge];
    self.standSummaryIcon = standSummaryIcon;
    self.standSummaryTitleLabel = standSummaryTitle;
    self.standSummaryDetailLabel = standSummaryDetail;
    self.standSummaryBadgeLabel = standSummaryBadge;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(24, 184, 600, 34)],
        [NSValue valueWithRect:NSMakeRect(24, 146, 600, 34)],
        [NSValue valueWithRect:NSMakeRect(24, 108, 600, 34)],
        [NSValue valueWithRect:NSMakeRect(24, 70, 600, 34)],
        [NSValue valueWithRect:NSMakeRect(24, 32, 600, 32)]
    ] dividerX:158 dividerWidth:442];

    self.standEnabledSwitch = [NSButton checkboxWithTitle:@"启用站立提醒" target:self action:@selector(toggleOnly:)];
    self.standEnabledSwitch.frame = NSMakeRect(38, 189, 160, 24);
    [card addSubview:self.standEnabledSwitch];

    self.standCustomStagesSummaryLabel = [NSTextField labelWithString:@""];
    self.standCustomStagesSummaryLabel.frame = NSMakeRect(226, 190, 186, 22);
    self.standCustomStagesSummaryLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.standCustomStagesSummaryLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.standCustomStagesSummaryLabel];

    self.standCustomStagesButton = [NSButton buttonWithTitle:@"编辑阶段..." target:self action:@selector(editStandCustomStages:)];
    self.standCustomStagesButton.frame = NSMakeRect(462, 186, 132, 28);
    self.standCustomStagesButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:self.standCustomStagesButton];

    [card addSubview:[self fieldLabel:@"每隔：" frame:NSMakeRect(38, 153, 104, 22)]];
    self.standIntervalInput = [self addTimeFieldsToView:card x:174 y:149];

    [card addSubview:[self fieldLabel:@"站立：" frame:NSMakeRect(38, 115, 104, 22)]];
    self.standDurationInput = [self addTimeFieldsToView:card x:174 y:111];

    [card addSubview:[self fieldLabel:@"动作组合：" frame:NSMakeRect(38, 77, 104, 22)]];
    self.standRoutinePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(174, 73, 192, 28) pullsDown:NO];
    [self.standRoutinePopup addItemsWithTitles:@[
        ERStandRoutineTitle(ERStandRoutineBalanced),
        ERStandRoutineTitle(ERStandRoutineNeckShoulder),
        ERStandRoutineTitle(ERStandRoutineWalk),
        ERStandRoutineTitle(ERStandRoutineReset),
    ]];
    self.standRoutinePopup.target = self;
    self.standRoutinePopup.action = @selector(toggleOnly:);
    [card addSubview:self.standRoutinePopup];

    self.standRoutineHintLabel = [NSTextField wrappingLabelWithString:@""];
    self.standRoutineHintLabel.frame = NSMakeRect(386, 71, 214, 34);
    self.standRoutineHintLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    self.standRoutineHintLabel.maximumNumberOfLines = 2;
    self.standRoutineHintLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.standRoutineHintLabel];

    [card addSubview:[self fieldLabel:@"强度：" frame:NSMakeRect(38, 39, 104, 18)]];
    self.standIntensityPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(174, 34, 192, 28) pullsDown:NO];
    [self.standIntensityPopup addItemsWithTitles:@[
        ERStandIntensityTitle(ERStandIntensityGentle),
        ERStandIntensityTitle(ERStandIntensityStandard),
        ERStandIntensityTitle(ERStandIntensityActive),
    ]];
    self.standIntensityPopup.target = self;
    self.standIntensityPopup.action = @selector(toggleOnly:);
    [card addSubview:self.standIntensityPopup];

    self.standIntensityHintLabel = [NSTextField wrappingLabelWithString:@""];
    self.standIntensityHintLabel.frame = NSMakeRect(386, 34, 214, 26);
    self.standIntensityHintLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    self.standIntensityHintLabel.maximumNumberOfLines = 2;
    self.standIntensityHintLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.standIntensityHintLabel];
}

- (void)buildAlertSectionInView:(NSView *)view {
    NSView *card = self.alertCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(24, 232, 374, 32)],
        [NSValue valueWithRect:NSMakeRect(24, 196, 374, 32)],
        [NSValue valueWithRect:NSMakeRect(24, 160, 374, 32)],
        [NSValue valueWithRect:NSMakeRect(24, 124, 374, 32)],
        [NSValue valueWithRect:NSMakeRect(24, 88, 374, 32)],
        [NSValue valueWithRect:NSMakeRect(24, 52, 374, 32)]
    ] dividerX:158 dividerWidth:220];

    self.notificationSwitch = [NSButton checkboxWithTitle:@"系统通知" target:self action:@selector(toggleOnly:)];
    self.notificationSwitch.frame = NSMakeRect(38, 236, 160, 24);
    [card addSubview:self.notificationSwitch];

    self.restWindowSwitch = [NSButton checkboxWithTitle:@"提醒窗口" target:self action:@selector(toggleOnly:)];
    self.restWindowSwitch.frame = NSMakeRect(38, 200, 160, 24);
    [card addSubview:self.restWindowSwitch];

    self.restWindowTopmostSwitch = [NSButton checkboxWithTitle:@"置顶强提醒" target:self action:@selector(toggleOnly:)];
    self.restWindowTopmostSwitch.frame = NSMakeRect(38, 164, 160, 24);
    [card addSubview:self.restWindowTopmostSwitch];

    self.launchAtLoginSwitch = [NSButton checkboxWithTitle:@"登录时自动启动" target:self action:@selector(toggleOnly:)];
    self.launchAtLoginSwitch.frame = NSMakeRect(38, 128, 180, 24);
    [card addSubview:self.launchAtLoginSwitch];

    [card addSubview:[self fieldLabel:@"菜单栏：" frame:NSMakeRect(38, 96, 104, 22)]];
    self.menuBarModePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(174, 91, 198, 30) pullsDown:NO];
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

    [card addSubview:[self fieldLabel:@"画面风格：" frame:NSMakeRect(38, 60, 104, 22)]];
    self.restStylePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(174, 55, 198, 30) pullsDown:NO];
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

    self.stylePreviewShell = ERRoundedView(NSMakeRect(424, 52, 184, 212), [NSColor colorWithWhite:1 alpha:0.42], 16);
    self.stylePreviewShell.layer.borderWidth = 1;
    [card addSubview:self.stylePreviewShell];

    self.stylePreviewEyebrow = [NSTextField labelWithString:@"风格预览"];
    self.stylePreviewEyebrow.frame = NSMakeRect(16, 180, 152, 18);
    self.stylePreviewEyebrow.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    [self.stylePreviewShell addSubview:self.stylePreviewEyebrow];

    self.stylePreviewCanvas = ERRoundedView(NSMakeRect(16, 88, 152, 86), NSColor.whiteColor, 14);
    self.stylePreviewCanvas.layer.borderWidth = 1;
    [self.stylePreviewShell addSubview:self.stylePreviewCanvas];

    self.stylePreviewIcon = [[NSImageView alloc] initWithFrame:NSMakeRect(20, 28, 28, 28)];
    self.stylePreviewIcon.symbolConfiguration = [NSImageSymbolConfiguration configurationWithPointSize:24 weight:NSFontWeightSemibold];
    [self.stylePreviewCanvas addSubview:self.stylePreviewIcon];

    self.stylePreviewTimer = [NSTextField labelWithString:@"00:20"];
    self.stylePreviewTimer.frame = NSMakeRect(66, 30, 64, 24);
    self.stylePreviewTimer.font = [NSFont monospacedDigitSystemFontOfSize:19 weight:NSFontWeightSemibold];
    self.stylePreviewTimer.alignment = NSTextAlignmentRight;
    [self.stylePreviewCanvas addSubview:self.stylePreviewTimer];

    self.stylePreviewTitle = [NSTextField labelWithString:@""];
    self.stylePreviewTitle.frame = NSMakeRect(16, 56, 152, 20);
    self.stylePreviewTitle.font = [NSFont systemFontOfSize:14 weight:NSFontWeightSemibold];
    [self.stylePreviewShell addSubview:self.stylePreviewTitle];

    self.stylePreviewHint = [NSTextField wrappingLabelWithString:@""];
    self.stylePreviewHint.frame = NSMakeRect(16, 16, 152, 34);
    self.stylePreviewHint.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightRegular];
    [self.stylePreviewShell addSubview:self.stylePreviewHint];
}

- (void)buildAutomationSectionInView:(NSView *)view {
    NSView *card = self.automationCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(24, 190, 600, 80)],
        [NSValue valueWithRect:NSMakeRect(24, 128, 600, 54)],
        [NSValue valueWithRect:NSMakeRect(24, 74, 600, 48)],
        [NSValue valueWithRect:NSMakeRect(24, 30, 600, 38)]
    ] dividerX:38 dividerWidth:548];

    self.automationStatusStripe = ERRoundedView(NSMakeRect(184, 204, 3, 42), NSColor.controlAccentColor, 1.5);
    [card addSubview:self.automationStatusStripe];

    [card addSubview:[self captionLabel:@"策略结论" frame:NSMakeRect(38, 238, 100, 16)]];
    self.autoFocusSwitch = [NSButton checkboxWithTitle:@"启用自动策略" target:self action:@selector(toggleOnly:)];
    self.autoFocusSwitch.frame = NSMakeRect(38, 212, 126, 22);
    [card addSubview:self.autoFocusSwitch];

    self.focusAppMatchLabel = [NSTextField wrappingLabelWithString:@""];
    self.focusAppMatchLabel.frame = NSMakeRect(204, 230, 380, 18);
    self.focusAppMatchLabel.font = [NSFont systemFontOfSize:12.5 weight:NSFontWeightSemibold];
    self.focusAppMatchLabel.maximumNumberOfLines = 1;
    self.focusAppMatchLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.focusAppMatchLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.focusAppMatchLabel];

    self.automationPolicyLabel = [NSTextField wrappingLabelWithString:@""];
    self.automationPolicyLabel.frame = NSMakeRect(204, 213, 380, 16);
    self.automationPolicyLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.automationPolicyLabel.maximumNumberOfLines = 1;
    self.automationPolicyLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.automationPolicyLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.automationPolicyLabel];

    self.automationLastActionLabel = [NSTextField wrappingLabelWithString:@""];
    self.automationLastActionLabel.frame = NSMakeRect(204, 196, 380, 16);
    self.automationLastActionLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.automationLastActionLabel.maximumNumberOfLines = 1;
    self.automationLastActionLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.automationLastActionLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.automationLastActionLabel];

    [card addSubview:[self captionLabel:@"场景模式" frame:NSMakeRect(38, 156, 100, 16)]];
    self.calendarFocusSwitch = [NSButton checkboxWithTitle:@"日历会议" target:self action:@selector(toggleOnly:)];
    self.calendarFocusSwitch.frame = NSMakeRect(38, 136, 100, 22);
    [card addSubview:self.calendarFocusSwitch];

    self.presentationFocusSwitch = [NSButton checkboxWithTitle:@"全屏/演示" target:self action:@selector(toggleOnly:)];
    self.presentationFocusSwitch.frame = NSMakeRect(148, 136, 120, 22);
    [card addSubview:self.presentationFocusSwitch];

    self.calendarStatusLabel = [NSTextField wrappingLabelWithString:@""];
    self.calendarStatusLabel.frame = NSMakeRect(312, 132, 274, 34);
    self.calendarStatusLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.calendarStatusLabel.maximumNumberOfLines = 2;
    self.calendarStatusLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.calendarStatusLabel];

    [card addSubview:[self captionLabel:@"固定时段" frame:NSMakeRect(38, 102, 100, 16)]];
    self.quietHoursSwitch = [NSButton checkboxWithTitle:@"安静时段" target:self action:@selector(toggleOnly:)];
    self.quietHoursSwitch.frame = NSMakeRect(38, 82, 108, 22);
    [card addSubview:self.quietHoursSwitch];

    self.quietHoursStartField = [[NSTextField alloc] initWithFrame:NSMakeRect(164, 81, 64, 24)];
    self.quietHoursStartField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.quietHoursStartField.bezelStyle = NSTextFieldRoundedBezel;
    self.quietHoursStartField.alignment = NSTextAlignmentCenter;
    self.quietHoursStartField.placeholderString = @"22:00";
    self.quietHoursStartField.target = self;
    self.quietHoursStartField.action = @selector(applySettings:);
    [card addSubview:self.quietHoursStartField];

    NSTextField *quietHoursToLabel = [NSTextField labelWithString:@"到"];
    quietHoursToLabel.frame = NSMakeRect(236, 84, 20, 18);
    quietHoursToLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:quietHoursToLabel];

    self.quietHoursEndField = [[NSTextField alloc] initWithFrame:NSMakeRect(262, 81, 64, 24)];
    self.quietHoursEndField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.quietHoursEndField.bezelStyle = NSTextFieldRoundedBezel;
    self.quietHoursEndField.alignment = NSTextAlignmentCenter;
    self.quietHoursEndField.placeholderString = @"07:00";
    self.quietHoursEndField.target = self;
    self.quietHoursEndField.action = @selector(applySettings:);
    [card addSubview:self.quietHoursEndField];

    self.quietHoursStatusLabel = [NSTextField wrappingLabelWithString:@""];
    self.quietHoursStatusLabel.frame = NSMakeRect(348, 76, 238, 34);
    self.quietHoursStatusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.quietHoursStatusLabel.maximumNumberOfLines = 2;
    self.quietHoursStatusLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.quietHoursStatusLabel];

    [card addSubview:[self captionLabel:@"高级策略" frame:NSMakeRect(38, 52, 100, 16)]];
    NSButton *editKeywordsButton = [NSButton buttonWithTitle:@"编辑策略关键词..." target:self action:@selector(editAutomationKeywords:)];
    editKeywordsButton.frame = NSMakeRect(142, 36, 142, 28);
    editKeywordsButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:editKeywordsButton];

    self.focusAppResetButton = [NSButton buttonWithTitle:@"默认" target:self action:@selector(resetFocusApps:)];
    self.focusAppResetButton.frame = NSMakeRect(514, 36, 72, 28);
    self.focusAppResetButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:self.focusAppResetButton];

    self.focusAppHintLabel = [NSTextField wrappingLabelWithString:@"优先级：不处理 > 自动暂停 > 只发通知。"];
    self.focusAppHintLabel.frame = NSMakeRect(312, 34, 184, 32);
    self.focusAppHintLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.focusAppHintLabel.maximumNumberOfLines = 2;
    self.focusAppHintLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.focusAppHintLabel];
}

- (void)buildStatsSectionInView:(NSView *)view {
    NSView *card = self.statsCard;
    self.statsOverviewLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsOverviewLabel.frame = NSMakeRect(32, 238, 348, 22);
    self.statsOverviewLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.statsOverviewLabel.textColor = NSColor.labelColor;
    [card addSubview:self.statsOverviewLabel];

    self.exportStatsButton = [NSButton buttonWithTitle:@"导出 CSV" target:self action:@selector(exportStatsCSV:)];
    self.exportStatsButton.frame = NSMakeRect(360, 234, 76, 30);
    self.exportStatsButton.bezelStyle = NSBezelStyleRounded;
    self.exportStatsButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.exportStatsButton];

    self.exportBackupButton = [NSButton buttonWithTitle:@"备份 JSON" target:self action:@selector(exportStatsJSON:)];
    self.exportBackupButton.frame = NSMakeRect(444, 234, 76, 30);
    self.exportBackupButton.bezelStyle = NSBezelStyleRounded;
    self.exportBackupButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.exportBackupButton];

    self.importBackupButton = [NSButton buttonWithTitle:@"恢复 JSON" target:self action:@selector(importBackupJSON:)];
    self.importBackupButton.frame = NSMakeRect(528, 234, 76, 30);
    self.importBackupButton.bezelStyle = NSBezelStyleRounded;
    self.importBackupButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.importBackupButton];

    self.statsMonthLabel = [NSTextField labelWithString:@""];
    self.statsMonthLabel.frame = NSMakeRect(32, 210, 540, 20);
    self.statsMonthLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.statsMonthLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsMonthLabel];

    self.statsStrategyLabel = [NSTextField labelWithString:@""];
    self.statsStrategyLabel.frame = NSMakeRect(32, 188, 540, 20);
    self.statsStrategyLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.statsStrategyLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsStrategyLabel];

    self.statsInsightLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsInsightLabel.frame = NSMakeRect(32, 160, 540, 24);
    self.statsInsightLabel.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    self.statsInsightLabel.maximumNumberOfLines = 2;
    self.statsInsightLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsInsightLabel];

    self.statsQualityLabel = [self metricLabelWithFrame:NSMakeRect(32, 130, 158, 24)];
    [card addSubview:self.statsQualityLabel];
    self.statsStandLabel = [self metricLabelWithFrame:NSMakeRect(214, 130, 158, 24)];
    [card addSubview:self.statsStandLabel];
    self.statsStreakLabel = [self metricLabelWithFrame:NSMakeRect(396, 130, 158, 24)];
    [card addSubview:self.statsStreakLabel];

    NSArray<NSString *> *dayTitles = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    NSMutableArray *bars = [NSMutableArray array];
    NSMutableArray *labels = [NSMutableArray array];
    CGFloat startX = 32;
    CGFloat gap = 10;
    CGFloat barWidth = 30;
    CGFloat baseY = 36;
    for (NSInteger index = 0; index < 7; index++) {
        CGFloat x = startX + index * (barWidth + gap);
        NSView *slot = ERRoundedView(NSMakeRect(x, baseY, barWidth, 72), ERColor(0.93, 0.94, 0.97, 1), 12);
        [card addSubview:slot];
        [bars addObject:slot];

        NSTextField *label = [NSTextField labelWithString:dayTitles[index]];
        label.frame = NSMakeRect(x - 10, 12, 50, 22);
        label.alignment = NSTextAlignmentCenter;
        label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        label.textColor = NSColor.secondaryLabelColor;
        [card addSubview:label];
        [labels addObject:label];
    }
    self.statsBars = bars;
    self.statsBarLabels = labels;

    NSTextField *heatmapTitle = [NSTextField labelWithString:@"近 30 天热力"];
    heatmapTitle.frame = NSMakeRect(360, 98, 160, 18);
    heatmapTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    heatmapTitle.textColor = NSColor.secondaryLabelColor;
    [card addSubview:heatmapTitle];

    self.statsMonthDetailLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsMonthDetailLabel.frame = NSMakeRect(360, 72, 220, 22);
    self.statsMonthDetailLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    self.statsMonthDetailLabel.maximumNumberOfLines = 2;
    self.statsMonthDetailLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsMonthDetailLabel];

    NSMutableArray *cells = [NSMutableArray array];
    CGFloat cell = 14;
    CGFloat cellGap = 4;
    CGFloat originX = 360;
    CGFloat originY = 26;
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
    self.heatmapLabels = @[heatmapTitle, self.statsMonthDetailLabel];
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

- (NSTextField *)captionLabel:(NSString *)text frame:(NSRect)frame {
    NSTextField *label = [NSTextField labelWithString:text];
    label.frame = frame;
    label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    label.textColor = NSColor.secondaryLabelColor;
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

- (NSButton *)overviewActionButtonWithTitle:(NSString *)title symbol:(NSString *)symbol action:(SEL)action frame:(NSRect)frame {
    NSButton *button = [NSButton buttonWithTitle:title target:self action:action];
    button.frame = frame;
    button.bezelStyle = NSBezelStyleShadowlessSquare;
    button.bordered = NO;
    button.transparent = YES;
    button.focusRingType = NSFocusRingTypeNone;
    button.image = [NSImage imageWithSystemSymbolName:symbol accessibilityDescription:title];
    button.imagePosition = NSImageLeft;
    button.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    return button;
}

- (void)overviewRestEyeNow:(id)sender {
    [self.appDelegate restEyeNow:sender];
    [self refreshOverview];
}

- (void)overviewRestStandNow:(id)sender {
    [self.appDelegate restStandNow:sender];
    [self refreshOverview];
}

- (void)overviewPauseThirtyMinutes:(id)sender {
    [self.appDelegate pauseForSeconds:30 * 60];
    [self refreshOverview];
}

- (void)overviewCopyIssueBundle:(id)sender {
    [self.appDelegate copyIssueBundleDiagnostic:sender];
    [self refreshOverview];
}

- (void)openQuickSetup:(id)sender {
    [self.appDelegate showQuickSetup:sender];
    [self refreshOverview];
}

- (void)setSelectedPageIndex:(NSInteger)pageIndex {
    self.selectedPage = ERClampInteger(pageIndex, 0, (NSInteger)self.pages.count - 1);
    [self updateSelectedPage];
}

- (void)refreshTimingSummaries {
    if (self.eyeSummaryTitleLabel) {
        self.eyeSummaryIcon.image = [NSImage imageWithSystemSymbolName:(self.settings.eyeMode == EREyeModePomodoro ? @"timer" : @"eye")
                                                 accessibilityDescription:@"眼睛休息"];
        self.eyeSummaryTitleLabel.stringValue = self.settings.eyeEnabled
            ? [NSString stringWithFormat:@"%@ · %@", EREyeModeTitle(self.settings.eyeMode), ERFormatDuration(self.settings.eyeFocusSeconds)]
            : @"眼睛休息已关闭";
        self.eyeSummaryDetailLabel.stringValue = self.settings.eyeEnabled
            ? [NSString stringWithFormat:@"使用电脑 %@ 后，离屏休息 %@。", ERFormatDuration(self.settings.eyeFocusSeconds), ERFormatDuration(self.settings.eyeRestSeconds)]
            : @"关闭后不会安排眼睛休息提醒。";
        self.eyeSummaryBadgeLabel.stringValue = self.settings.eyeEnabled ? ERFormatDuration(self.settings.eyeRestSeconds) : @"关闭";
    }

    if (self.standSummaryTitleLabel) {
        BOOL hasCustomStages = ERStandCustomStageEntriesFromText(self.settings.standCustomStagesText).count > 0;
        self.standSummaryIcon.image = [NSImage imageWithSystemSymbolName:(hasCustomStages ? @"list.bullet.rectangle" : @"figure.stand")
                                                   accessibilityDescription:@"站立提醒"];
        self.standSummaryTitleLabel.stringValue = self.settings.standEnabled
            ? [NSString stringWithFormat:@"%@ · %@", hasCustomStages ? @"自定义阶段" : ERStandRoutineTitle(self.settings.standRoutine), ERStandIntensityTitle(self.settings.standIntensity)]
            : @"站立提醒已关闭";
        self.standSummaryDetailLabel.stringValue = self.settings.standEnabled
            ? [NSString stringWithFormat:@"每隔 %@，站立 %@。", ERFormatDuration(self.settings.standIntervalSeconds), ERFormatDuration(self.settings.standDurationSeconds)]
            : @"关闭后不会安排站立活动提醒。";
        self.standSummaryBadgeLabel.stringValue = self.settings.standEnabled ? ERFormatDuration(self.settings.standDurationSeconds) : @"关闭";
    }
}

- (void)updateSelectedPage {
    for (NSInteger index = 0; index < self.pages.count; index++) {
        self.pages[index].hidden = index != self.selectedPage;
    }
    self.paneControl.selectedSegment = self.selectedPage;
    for (NSButton *button in self.sidebarButtons) {
        button.state = button.tag == self.selectedPage ? NSControlStateValueOn : NSControlStateValueOff;
    }
    [self refreshSidebarAppearance];
}

- (void)refreshControls {
    self.eyeEnabledSwitch.state = self.settings.eyeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.eyeModePopup selectItemAtIndex:self.settings.eyeMode];
    [self.eyeFocusInput setSeconds:self.settings.eyeFocusSeconds];
    [self.eyeRestInput setSeconds:self.settings.eyeRestSeconds];
    self.standEnabledSwitch.state = self.settings.standEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    [self.standIntervalInput setSeconds:self.settings.standIntervalSeconds];
    [self.standDurationInput setSeconds:self.settings.standDurationSeconds];
    [self.standRoutinePopup selectItemAtIndex:self.settings.standRoutine];
    self.standRoutineHintLabel.stringValue = ERStandRoutineSummary(self.settings.standRoutine);
    [self.standIntensityPopup selectItemAtIndex:self.settings.standIntensity];
    self.standIntensityHintLabel.stringValue = ERStandIntensityHint(self.settings.standIntensity);
    NSInteger customStageCount = ERStandCustomStageEntriesFromText(self.settings.standCustomStagesText).count;
    self.standCustomStagesSummaryLabel.stringValue = customStageCount > 0
        ? [NSString stringWithFormat:@"自定义 %ld 个阶段", (long)customStageCount]
        : @"使用内置动作";
    self.notificationSwitch.state = self.settings.notificationsEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.restWindowSwitch.state = self.settings.showRestWindow ? NSControlStateValueOn : NSControlStateValueOff;
    self.restWindowTopmostSwitch.state = self.settings.restWindowTopmost ? NSControlStateValueOn : NSControlStateValueOff;
    self.restWindowTopmostSwitch.enabled = self.settings.showRestWindow;
    self.launchAtLoginSwitch.state = self.settings.launchAtLogin ? NSControlStateValueOn : NSControlStateValueOff;
    self.autoFocusSwitch.state = self.settings.autoFocusModeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.calendarFocusSwitch.state = self.settings.calendarFocusModeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.presentationFocusSwitch.state = self.settings.presentationFocusModeEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.quietHoursSwitch.state = self.settings.quietHoursEnabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.quietHoursStartField.stringValue = ERFormatClockMinute(self.settings.quietHoursStartMinute);
    self.quietHoursEndField.stringValue = ERFormatClockMinute(self.settings.quietHoursEndMinute);
    self.focusAppTokensField.stringValue = [self.settings.focusAppTokens componentsJoinedByString:@", "];
    self.autoPauseAppTokensField.stringValue = [self.settings.autoPauseAppTokens componentsJoinedByString:@", "];
    self.ignoreAppTokensField.stringValue = [self.settings.ignoreAppTokens componentsJoinedByString:@", "];
    self.calendarFocusTokensField.stringValue = [self.settings.calendarFocusTokens componentsJoinedByString:@", "];
    self.calendarAutoPauseTokensField.stringValue = [self.settings.calendarAutoPauseTokens componentsJoinedByString:@", "];
    [self.menuBarModePopup selectItemAtIndex:self.settings.menuBarMode];
    [self.restStylePopup selectItemAtIndex:self.settings.restStyle];
    [self.appDelegate refreshFocusModeState];
    [self refreshAutomationStatus];
    self.summaryLabel.stringValue = [NSString stringWithFormat:@"眼 %@ / %@\n站 %@ / %@",
                                     self.settings.eyeEnabled ? ERFormatDuration(self.settings.eyeFocusSeconds) : @"关闭",
                                     self.settings.eyeEnabled ? ERFormatDuration(self.settings.eyeRestSeconds) : @"--",
                                     self.settings.standEnabled ? ERFormatDuration(self.settings.standIntervalSeconds) : @"关闭",
                                     self.settings.standEnabled ? ERFormatDuration(self.settings.standDurationSeconds) : @"--"];
    [self refreshTimingSummaries];
    [self applySettingsTheme];
    [self refreshStats];
    [self refreshOverview];
}

- (void)refreshOverview {
    if (!self.overviewEyeStatusLabel) return;

    NSTimeInterval eyeTotal = self.appDelegate.eyeResting ? self.settings.eyeRestSeconds : self.settings.eyeFocusSeconds;
    NSTimeInterval eyeRemaining = [self.appDelegate remainingUntil:(self.appDelegate.eyeResting ? self.appDelegate.eyeRestEndsAt : self.appDelegate.eyeDueAt)];
    NSTimeInterval standTotal = self.appDelegate.standResting ? self.settings.standDurationSeconds : self.settings.standIntervalSeconds;
    NSTimeInterval standRemaining = [self.appDelegate remainingUntil:(self.appDelegate.standResting ? self.appDelegate.standRestEndsAt : self.appDelegate.standDueAt)];

    if (!self.settings.eyeEnabled) {
        self.overviewEyeStatusLabel.stringValue = @"眼睛提醒关闭";
        self.overviewEyeTimerLabel.stringValue = @"--:--";
        self.overviewEyeMetaLabel.stringValue = @"在眼睛页重新开启";
        self.overviewEyeProgress.doubleValue = 0;
    } else {
        self.overviewEyeStatusLabel.stringValue = self.appDelegate.eyeResting ? @"眼睛休息中" : EREyeModeTitle(self.settings.eyeMode);
        self.overviewEyeTimerLabel.stringValue = ERFormatDuration(eyeRemaining);
        self.overviewEyeMetaLabel.stringValue = self.appDelegate.eyeResting
            ? [NSString stringWithFormat:@"远眺 %@", ERFormatDuration(self.settings.eyeRestSeconds)]
            : [NSString stringWithFormat:@"专注 %@ 后休息", ERFormatDuration(self.settings.eyeFocusSeconds)];
        self.overviewEyeProgress.doubleValue = eyeTotal > 0 ? MAX(0, MIN(1, 1 - eyeRemaining / eyeTotal)) : 0;
    }

    if (!self.settings.standEnabled) {
        self.overviewStandStatusLabel.stringValue = @"站立提醒关闭";
        self.overviewStandTimerLabel.stringValue = @"--:--";
        self.overviewStandMetaLabel.stringValue = @"在站立页重新开启";
        self.overviewStandProgress.doubleValue = 0;
    } else {
        self.overviewStandStatusLabel.stringValue = self.appDelegate.standResting ? @"站立进行中" : @"下次站立";
        self.overviewStandTimerLabel.stringValue = ERFormatDuration(standRemaining);
        self.overviewStandMetaLabel.stringValue = self.appDelegate.standResting
            ? [NSString stringWithFormat:@"%@ · %@", ERStandRoutineTitle(self.settings.standRoutine), ERStandIntensityTitle(self.settings.standIntensity)]
            : [NSString stringWithFormat:@"每 %@ 站 %@", ERFormatDuration(self.settings.standIntervalSeconds), ERFormatDuration(self.settings.standDurationSeconds)];
        self.overviewStandProgress.doubleValue = standTotal > 0 ? MAX(0, MIN(1, 1 - standRemaining / standTotal)) : 0;
    }

    self.overviewRestEyeButton.enabled = self.settings.eyeEnabled && !self.appDelegate.eyeResting;
    self.overviewRestStandButton.enabled = self.settings.standEnabled && !self.appDelegate.standResting;
    self.overviewPauseButton.enabled = !self.appDelegate.paused;
    self.overviewPauseButton.title = self.appDelegate.paused ? @"已暂停" : @"暂停 30";
    self.overviewIssueButton.enabled = YES;

    NSInteger done = self.appDelegate.todayEyeDone + self.appDelegate.todayStandDone;
    self.overviewTodayLabel.stringValue = [NSString stringWithFormat:@"今天 %ld 次 · 眼 %ld · 站 %ld",
                                           (long)done,
                                           (long)self.appDelegate.todayEyeDone,
                                           (long)self.appDelegate.todayStandDone];

    NSString *modeText = @"正常提醒";
    NSString *statusTitle = @"下一次提醒";
    NSString *statusDetail = @"眼睛和站立按各自节奏计时。";
    NSString *statusBadge = @"正常";
    NSString *statusSymbol = @"bell.badge";
    if (self.appDelegate.paused) {
        modeText = self.appDelegate.pausedUntil ? [NSString stringWithFormat:@"暂停到 %@", ERFormatClockTime(self.appDelegate.pausedUntil)] : @"暂停中";
        statusTitle = @"提醒已暂停";
        statusDetail = modeText;
        statusBadge = @"暂停";
        statusSymbol = @"pause.circle.fill";
    } else if (self.appDelegate.autoPauseActive) {
        modeText = self.appDelegate.calendarAutoPauseActive ? @"日程自动暂停中" : @"应用自动暂停中";
        statusTitle = modeText;
        statusDetail = @"计时会顺延，休息页不会弹出来。";
        statusBadge = @"自动";
        statusSymbol = @"pause.rectangle.fill";
    } else if ([self.appDelegate isLightDistractionModeActive]) {
        modeText = [self.appDelegate focusModeStatusText];
        statusTitle = @"轻打扰中";
        statusDetail = modeText;
        statusBadge = @"只通知";
        statusSymbol = @"bell.slash.fill";
    } else if (self.appDelegate.eyeResting) {
        statusTitle = @"正在眼睛休息";
        statusDetail = [NSString stringWithFormat:@"剩余 %@，完成后会重新开始计时。", ERFormatDuration(eyeRemaining)];
        statusBadge = @"休息中";
        statusSymbol = @"eye.fill";
    } else if (self.appDelegate.standResting) {
        statusTitle = @"正在站立活动";
        statusDetail = [NSString stringWithFormat:@"剩余 %@，%@。", ERFormatDuration(standRemaining), ERStandRoutineTitle(self.settings.standRoutine)];
        statusBadge = @"站立中";
        statusSymbol = @"figure.stand";
    } else if (!self.settings.eyeEnabled && !self.settings.standEnabled) {
        statusTitle = @"提醒都已关闭";
        statusDetail = @"可以在眼睛或站立页面重新开启。";
        statusBadge = @"关闭";
        statusSymbol = @"bell.slash";
    } else if (!self.settings.standEnabled || (self.settings.eyeEnabled && eyeRemaining <= standRemaining)) {
        statusTitle = @"下一次眼睛休息";
        statusDetail = [NSString stringWithFormat:@"%@ 后看向 6 米外。", ERFormatDuration(eyeRemaining)];
        statusBadge = EREyeModeTitle(self.settings.eyeMode);
        statusSymbol = self.settings.eyeMode == EREyeModePomodoro ? @"timer" : @"eye";
    } else {
        statusTitle = @"下一次站立提醒";
        statusDetail = [NSString stringWithFormat:@"%@ 后%@。", ERFormatDuration(standRemaining), ERStandRoutineTitle(self.settings.standRoutine)];
        statusBadge = ERStandIntensityTitle(self.settings.standIntensity);
        statusSymbol = @"figure.stand";
    }
    self.overviewStatusIcon.image = [NSImage imageWithSystemSymbolName:statusSymbol accessibilityDescription:statusTitle];
    self.overviewStatusTitleLabel.stringValue = statusTitle;
    self.overviewStatusDetailLabel.stringValue = statusDetail;
    self.overviewStatusBadgeLabel.stringValue = statusBadge;
    self.overviewModeLabel.stringValue = [NSString stringWithFormat:@"当前模式：%@ · %@", modeText, ERRestStyleTitle(self.settings.restStyle)];

    if (self.appDelegate.paused || self.appDelegate.autoPauseActive) {
        self.overviewHintLabel.stringValue = @"提醒已暂缓，计时会在恢复后继续保持节奏。";
    } else if (self.appDelegate.eyeResting || self.appDelegate.standResting) {
        self.overviewHintLabel.stringValue = @"正在休息时可以完成、稍后或跳过；普通模式下切走窗口会让开。";
    } else if (standRemaining < eyeRemaining && self.settings.standEnabled) {
        self.overviewHintLabel.stringValue = @"下一次更可能是站立提醒，提前把水杯和桌面留一点空间。";
    } else {
        self.overviewHintLabel.stringValue = @"下一次更可能是眼睛休息，远处找一个固定参照点会更自然。";
    }
}

- (void)refreshAutomationStatus {
    if (!self.focusAppMatchLabel) return;
    NSDictionary<NSString *, NSString *> *policy = [self.appDelegate automationPolicyExplanation];
    NSString *action = policy[@"action"] ?: @"当前策略";
    NSString *reason = policy[@"reason"] ?: [self.appDelegate focusModeStatusText];
    NSString *suggestion = policy[@"suggestion"] ?: @"";
    NSString *lastAction = policy[@"lastAction"] ?: @"最近动作：暂无记录";
    self.focusAppMatchLabel.stringValue = [NSString stringWithFormat:@"%@：%@", action, reason];
    self.automationPolicyLabel.stringValue = [NSString stringWithFormat:@"建议：%@", suggestion];
    self.automationLastActionLabel.stringValue = lastAction;
    if (self.appDelegate.quietHoursActive) {
        self.quietHoursStatusLabel.stringValue = [NSString stringWithFormat:@"%@-%@ · 只发通知",
                                                   ERFormatClockMinute(self.settings.quietHoursStartMinute),
                                                   ERFormatClockMinute(self.settings.quietHoursEndMinute)];
    } else if (self.settings.quietHoursEnabled) {
        self.quietHoursStatusLabel.stringValue = [NSString stringWithFormat:@"%@-%@ · 未命中",
                                                   ERFormatClockMinute(self.settings.quietHoursStartMinute),
                                                   ERFormatClockMinute(self.settings.quietHoursEndMinute)];
    } else {
        self.quietHoursStatusLabel.stringValue = @"关闭后不按时间降打扰。";
    }
    NSString *calendarStatus = ERCalendarAccessStatusText();
    if (self.appDelegate.calendarAutoPauseActive) {
        NSString *title = self.appDelegate.currentCalendarEventTitle.length > 0 ? self.appDelegate.currentCalendarEventTitle : @"当前日程";
        self.calendarStatusLabel.stringValue = [NSString stringWithFormat:@"日程中：%@ · 自动暂停", title];
    } else if (self.appDelegate.presentationFocusActive) {
        self.calendarStatusLabel.stringValue = @"全屏/演示中：只发通知";
    } else if (self.appDelegate.calendarFocusActive) {
        NSString *title = self.appDelegate.currentCalendarEventTitle.length > 0 ? self.appDelegate.currentCalendarEventTitle : @"当前会议";
        self.calendarStatusLabel.stringValue = [NSString stringWithFormat:@"会议中：%@ · 只发通知", title];
    } else if (self.settings.calendarFocusModeEnabled || self.settings.presentationFocusModeEnabled) {
        self.calendarStatusLabel.stringValue = [NSString stringWithFormat:@"日历：%@ · 当前无会议/演示", calendarStatus];
    } else {
        self.calendarStatusLabel.stringValue = @"关闭后不会读取日历或检测演示。";
    }
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
    NSInteger previousWeekDone = 0;
    NSInteger monthSkipped = 0;
    NSInteger monthSnoozed = 0;
    NSInteger bestDayDone = 0;
    NSString *bestDayTitle = @"--";
    NSInteger maxDone = 1;
    NSInteger weekManualDone = 0;
    NSInteger weekNotificationOnly = 0;
    NSInteger weekAutoPauseSessions = 0;
    NSInteger weekAutoPauseSeconds = 0;
    NSMutableArray<NSNumber *> *dailyDone = [NSMutableArray arrayWithCapacity:dates.count];

    for (NSString *dateKey in dates) {
        NSDictionary *entry = history[dateKey];
        NSInteger done = ERStatsInteger(entry, @"eye") + ERStatsInteger(entry, @"stand");
        NSInteger snoozed = ERStatsInteger(entry, @"snoozed");
        NSInteger skipped = ERStatsInteger(entry, @"skipped");
        NSInteger standSeconds = ERStatsInteger(entry, @"standSeconds");
        weekDone += done;
        weekSnoozed += snoozed;
        weekSkipped += skipped;
        weekStandSeconds += standSeconds;
        weekManualDone += ERStatsInteger(entry, @"manualDone");
        weekNotificationOnly += ERStatsInteger(entry, @"notificationOnly");
        weekAutoPauseSessions += ERStatsInteger(entry, @"autoPauseSessions");
        weekAutoPauseSeconds += ERStatsInteger(entry, @"autoPauseSeconds");
        maxDone = MAX(maxDone, done);
        [dailyDone addObject:@(done)];
    }

    for (NSString *dateKey in monthDates) {
        NSDictionary *entry = history[dateKey];
        NSInteger done = ERStatsInteger(entry, @"eye") + ERStatsInteger(entry, @"stand");
        NSInteger snoozed = ERStatsInteger(entry, @"snoozed");
        NSInteger skipped = ERStatsInteger(entry, @"skipped");
        monthDone += done;
        monthSnoozed += snoozed;
        monthSkipped += skipped;
        maxDone = MAX(maxDone, done);
        if (done > bestDayDone) {
            bestDayDone = done;
            bestDayTitle = ERShortDateTitle(dateKey);
        }
        if (done > 0) {
            monthActiveDays += 1;
        }
    }

    NSArray<NSString *> *twoWeekDates = ERRecentDateKeys(14);
    for (NSInteger index = 0; index < twoWeekDates.count - 7; index++) {
        NSDictionary *entry = history[twoWeekDates[index]];
        previousWeekDone += ERStatsInteger(entry, @"eye") + ERStatsInteger(entry, @"stand");
    }

    NSInteger streak = 0;
    for (NSString *dateKey in [ERRecentDateKeys(30) reverseObjectEnumerator]) {
        NSDictionary *entry = history[dateKey];
        NSInteger done = ERStatsInteger(entry, @"eye") + ERStatsInteger(entry, @"stand");
        if (done <= 0) break;
        streak += 1;
    }

    NSInteger friction = weekDone + weekSnoozed + weekSkipped;
    NSInteger skipRate = ERPercent(weekSkipped, friction);
    NSInteger monthFriction = monthDone + monthSnoozed + monthSkipped;
    NSInteger monthSkipRate = ERPercent(monthSkipped, monthFriction);
    NSInteger delta = weekDone - previousWeekDone;
    NSInteger activeRate = ERPercent(monthActiveDays, 30);
    double dailyAverage = (double)monthDone / 30.0;
    NSInteger strategyEvents = weekManualDone + weekNotificationOnly + weekAutoPauseSessions;
    NSInteger manualRate = ERPercent(weekManualDone, strategyEvents);
    NSInteger notificationRate = ERPercent(weekNotificationOnly, strategyEvents);
    NSInteger autoPauseRate = ERPercent(weekAutoPauseSessions, strategyEvents);

    self.statsOverviewLabel.stringValue = [NSString stringWithFormat:@"今天完成 %ld 次休息，本周完成 %ld 次。稍后/跳过共 %ld 次。",
                                           (long)(self.appDelegate.todayEyeDone + self.appDelegate.todayStandDone),
                                           (long)weekDone,
                                           (long)(weekSnoozed + weekSkipped)];
    self.statsMonthLabel.stringValue = [NSString stringWithFormat:@"近 30 天完成 %ld 次，活跃 %ld 天，跳过率 %ld%%。",
                                        (long)monthDone,
                                        (long)monthActiveDays,
                                        (long)monthSkipRate];
    if (strategyEvents > 0) {
        self.statsStrategyLabel.stringValue = [NSString stringWithFormat:@"本周策略：手动完成 %ld%% · 只发通知 %ld%% · 自动暂停 %ld%% / %@",
                                               (long)manualRate,
                                               (long)notificationRate,
                                               (long)autoPauseRate,
                                               ERFormatShortMinutes(weekAutoPauseSeconds)];
    } else {
        self.statsStrategyLabel.stringValue = @"本周策略：还没有足够的自动化统计。";
    }
    self.statsMonthDetailLabel.stringValue = [NSString stringWithFormat:@"活跃率 %ld%% · 日均 %.1f 次 · 最佳 %@/%ld 次",
                                              (long)activeRate,
                                              dailyAverage,
                                              bestDayTitle,
                                              (long)bestDayDone];
    if (monthDone == 0) {
        self.statsInsightLabel.stringValue = @"趋势：还没有足够数据。先完成几次休息，统计会开始有意义。";
    } else if (delta >= 3) {
        self.statsInsightLabel.stringValue = [NSString stringWithFormat:@"趋势：本周比上周多 %ld 次，节奏正在变稳。", (long)delta];
    } else if (delta <= -3) {
        self.statsInsightLabel.stringValue = [NSString stringWithFormat:@"趋势：本周比上周少 %ld 次，可以把提醒调轻一点，先恢复完成率。", (long)llabs(delta)];
    } else if (weekAutoPauseSeconds >= 60 * 60) {
        self.statsInsightLabel.stringValue = @"趋势：自动暂停时间偏长，可以检查视频/游戏白名单是否过宽。";
    } else if (weekNotificationOnly >= weekDone && weekNotificationOnly >= 3) {
        self.statsInsightLabel.stringValue = @"趋势：最近多是只发通知，会议或演示中打扰已经降下来了。";
    } else if (skipRate >= 35) {
        self.statsInsightLabel.stringValue = @"趋势：本周跳过偏多，建议把提醒间隔调长一点，降低打扰。";
    } else if (weekStandSeconds < 10 * 60 && self.settings.standEnabled) {
        self.statsInsightLabel.stringValue = @"趋势：站立时间偏少，下一步先把站立提醒做起来。";
    } else if (streak >= 3) {
        self.statsInsightLabel.stringValue = [NSString stringWithFormat:@"趋势：已经连续 %ld 天有休息记录，保持这个轻节奏。", (long)streak];
    } else {
        self.statsInsightLabel.stringValue = [NSString stringWithFormat:@"趋势：近 30 天平均每天 %.1f 次，先追求不断档。", (double)monthDone / 30.0];
    }
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
        frame.origin.y = 28;
        frame.size.height = height;
        bar.frame = frame;
        bar.layer.backgroundColor = [theme.accent colorWithAlphaComponent:done <= 0 ? 0.18 : 0.55].CGColor;
        self.statsBarLabels[index].stringValue = [NSString stringWithFormat:@"%@\n%ld", ERShortDateTitle(dates[index]), (long)done];
    }

    for (NSInteger index = 0; index < self.heatmapCells.count && index < monthDates.count; index++) {
        NSDictionary *entry = history[monthDates[index]];
        NSInteger done = ERStatsInteger(entry, @"eye") + ERStatsInteger(entry, @"stand");
        CGFloat ratio = done <= 0 ? 0.0 : MIN(1.0, (CGFloat)done / (CGFloat)MAX(1, maxDone));
        CGFloat alpha = done <= 0 ? 0.14 : 0.28 + ratio * 0.55;
        NSView *cell = self.heatmapCells[index];
        cell.layer.backgroundColor = [theme.accent colorWithAlphaComponent:alpha].CGColor;
        cell.toolTip = [NSString stringWithFormat:@"%@ · 完成 %ld · 只发通知 %ld · 暂停 %@",
                        monthDates[index],
                        (long)done,
                        (long)ERStatsInteger(entry, @"notificationOnly"),
                        ERFormatShortMinutes(ERStatsInteger(entry, @"autoPauseSeconds"))];
    }
}

- (void)exportStatsCSV:(id)sender {
    NSDictionary *history = [self.appDelegate statsHistoryIncludingToday];
    NSArray<NSString *> *dates = ERRecentDateKeys(30);
    NSMutableString *csv = [NSMutableString stringWithString:@"date,eye_done,stand_done,stand_minutes,snoozed,skipped,manual_done,notification_only,auto_pause_sessions,auto_pause_minutes,total_done\n"];
    for (NSString *dateKey in dates) {
        NSDictionary *entry = history[dateKey];
        NSInteger eye = ERStatsInteger(entry, @"eye");
        NSInteger stand = ERStatsInteger(entry, @"stand");
        NSInteger standMinutes = (NSInteger)llround((double)ERStatsInteger(entry, @"standSeconds") / 60.0);
        NSInteger snoozed = ERStatsInteger(entry, @"snoozed");
        NSInteger skipped = ERStatsInteger(entry, @"skipped");
        NSInteger manualDone = ERStatsInteger(entry, @"manualDone");
        NSInteger notificationOnly = ERStatsInteger(entry, @"notificationOnly");
        NSInteger autoPauseSessions = ERStatsInteger(entry, @"autoPauseSessions");
        NSInteger autoPauseMinutes = (NSInteger)llround((double)ERStatsInteger(entry, @"autoPauseSeconds") / 60.0);
        [csv appendFormat:@"%@,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld,%ld\n",
         dateKey,
         (long)eye,
         (long)stand,
         (long)standMinutes,
         (long)snoozed,
         (long)skipped,
         (long)manualDone,
         (long)notificationOnly,
         (long)autoPauseSessions,
         (long)autoPauseMinutes,
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
        NSInteger eye = ERStatsInteger(entry, @"eye");
        NSInteger stand = ERStatsInteger(entry, @"stand");
        NSInteger standSeconds = ERStatsInteger(entry, @"standSeconds");
        NSInteger snoozed = ERStatsInteger(entry, @"snoozed");
        NSInteger skipped = ERStatsInteger(entry, @"skipped");
        NSInteger manualDone = ERStatsInteger(entry, @"manualDone");
        NSInteger notificationOnly = ERStatsInteger(entry, @"notificationOnly");
        NSInteger autoPauseSessions = ERStatsInteger(entry, @"autoPauseSessions");
        NSInteger autoPauseSeconds = ERStatsInteger(entry, @"autoPauseSeconds");
        [entries addObject:@{
            @"date": dateKey,
            @"eyeDone": @(eye),
            @"standDone": @(stand),
            @"standSeconds": @(standSeconds),
            @"snoozed": @(snoozed),
            @"skipped": @(skipped),
            @"manualDone": @(manualDone),
            @"notificationOnly": @(notificationOnly),
            @"autoPauseSessions": @(autoPauseSessions),
            @"autoPauseSeconds": @(autoPauseSeconds),
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
            @"standRoutine": ERStandRoutineTitle(self.settings.standRoutine),
            @"standIntensity": ERStandIntensityTitle(self.settings.standIntensity),
            @"standCustomStages": ERSanitizedStandCustomStagesTextFromObject(self.settings.standCustomStagesText),
            @"showRestWindow": @(self.settings.showRestWindow),
            @"restWindowTopmost": @(self.settings.restWindowTopmost),
            @"notificationsEnabled": @(self.settings.notificationsEnabled),
            @"restStyle": ERRestStyleTitle(self.settings.restStyle),
            @"menuBarMode": ERMenuBarModeTitle(self.settings.menuBarMode),
            @"launchAtLogin": @(self.settings.launchAtLogin),
            @"autoFocusModeEnabled": @(self.settings.autoFocusModeEnabled),
            @"calendarFocusModeEnabled": @(self.settings.calendarFocusModeEnabled),
            @"presentationFocusModeEnabled": @(self.settings.presentationFocusModeEnabled),
            @"quietHoursEnabled": @(self.settings.quietHoursEnabled),
            @"quietHoursStart": ERFormatClockMinute(self.settings.quietHoursStartMinute),
            @"quietHoursEnd": ERFormatClockMinute(self.settings.quietHoursEndMinute),
            @"focusAppTokens": self.settings.focusAppTokens ?: @[],
            @"autoPauseAppTokens": self.settings.autoPauseAppTokens ?: @[],
            @"ignoreAppTokens": self.settings.ignoreAppTokens ?: @[],
            @"calendarFocusTokens": self.settings.calendarFocusTokens ?: @[],
            @"calendarAutoPauseTokens": self.settings.calendarAutoPauseTokens ?: @[]
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

- (void)importBackupJSON:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.title = @"恢复休息数据";
    panel.allowsMultipleSelection = NO;
    panel.canChooseDirectories = NO;
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"json"]];
    [panel beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK) return;

        NSData *data = [NSData dataWithContentsOfURL:panel.URL];
        if (!data) return;
        NSError *error = nil;
        id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (![object isKindOfClass:NSDictionary.class]) return;
        NSDictionary *payload = (NSDictionary *)object;

        NSDictionary *settingsDictionary = [payload[@"settings"] isKindOfClass:NSDictionary.class] ? payload[@"settings"] : nil;
        BOOL restoredSettings = settingsDictionary != nil;
        if (settingsDictionary) {
            [self.settings applyBackupSettingsDictionary:settingsDictionary];
            [self.settings save];
        }

        NSDictionary *statsDictionary = [payload[@"stats"] isKindOfClass:NSDictionary.class] ? payload[@"stats"] : nil;
        NSArray *entries = [statsDictionary[@"entries"] isKindOfClass:NSArray.class] ? statsDictionary[@"entries"] : @[];
        NSMutableDictionary *history = [NSMutableDictionary dictionary];
        NSSet *recentDates = [NSSet setWithArray:ERRecentDateKeys(30)];
        for (id item in entries) {
            if (![item isKindOfClass:NSDictionary.class]) continue;
            NSDictionary *entry = (NSDictionary *)item;
            NSString *dateKey = [entry[@"date"] isKindOfClass:NSString.class] ? entry[@"date"] : nil;
            if (![recentDates containsObject:dateKey]) continue;
            history[dateKey] = @{
                @"eye": @(ERStatsInteger(entry, @"eyeDone")),
                @"stand": @(ERStatsInteger(entry, @"standDone")),
                @"standSeconds": @(ERStatsInteger(entry, @"standSeconds")),
                @"snoozed": @(ERStatsInteger(entry, @"snoozed")),
                @"skipped": @(ERStatsInteger(entry, @"skipped")),
                @"manualDone": @(ERStatsInteger(entry, @"manualDone")),
                @"notificationOnly": @(ERStatsInteger(entry, @"notificationOnly")),
                @"autoPauseSessions": @(ERStatsInteger(entry, @"autoPauseSessions")),
                @"autoPauseSeconds": @(ERStatsInteger(entry, @"autoPauseSeconds"))
            };
        }
        if (history.count > 0) {
            [NSUserDefaults.standardUserDefaults setObject:history forKey:ERStatsHistoryKey];
            [NSUserDefaults.standardUserDefaults setObject:ERTodayKey() forKey:ERStatsDateKey];
            [self.appDelegate loadTodayStats];
        }

        [NSUserDefaults.standardUserDefaults synchronize];
        NSString *summary = nil;
        if (restoredSettings && history.count > 0) {
            summary = [NSString stringWithFormat:@"已恢复设置和 %ld 天统计", (long)history.count];
        } else if (restoredSettings) {
            summary = @"已恢复设置";
        } else if (history.count > 0) {
            summary = [NSString stringWithFormat:@"已恢复 %ld 天统计", (long)history.count];
        } else {
            summary = @"没有可恢复的数据";
        }
        [self.appDelegate noteRecoveryEventTitle:@"数据恢复"
                                          detail:summary];
        [self refreshControls];
        [self.appDelegate settingsDidChangeShouldReset:YES];
    }];
}

- (void)applySettingsTheme {
    ERTheme theme = ERThemeForStyle(self.settings.restStyle);
    BOOL settingsDarkStyle = self.settings.restStyle == ERRestStyleNight;
    NSColor *settingsPrimaryTextColor = settingsDarkStyle ? NSColor.whiteColor : NSColor.labelColor;
    NSColor *settingsSecondaryTextColor = settingsDarkStyle ? theme.secondary : NSColor.secondaryLabelColor;
    self.contentView.layer.backgroundColor = theme.settingsBackground.CGColor;
    self.headerView.wantsLayer = YES;
    self.headerView.material = settingsDarkStyle ? NSVisualEffectMaterialUnderWindowBackground : NSVisualEffectMaterialSidebar;
    self.headerView.layer.backgroundColor = theme.settingsHeader.CGColor;
    self.sidebarDividerView.layer.backgroundColor = [theme.cardBorder colorWithAlphaComponent:settingsDarkStyle ? 0.34 : 0.38].CGColor;
    self.sidebarBrandBadge.layer.backgroundColor = (settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.075]
        : [theme.card colorWithAlphaComponent:0.62]).CGColor;
    self.sidebarBrandBadge.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:settingsDarkStyle ? 0.42 : 0.46].CGColor;
    self.sidebarBrandBadge.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 13;
    self.sidebarBrandIcon.contentTintColor = theme.accent;
    self.sidebarSummaryCard.layer.backgroundColor = (settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.065]
        : [theme.card colorWithAlphaComponent:0.48]).CGColor;
    self.sidebarSummaryCard.layer.borderColor = (settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.10]
        : [NSColor colorWithWhite:1 alpha:0.34]).CGColor;
    self.sidebarSummaryCard.layer.cornerRadius = 12;
    self.sidebarSummaryCard.layer.shadowColor = [NSColor.blackColor colorWithAlphaComponent:settingsDarkStyle ? 0.34 : 0.14].CGColor;
    self.sidebarSummaryCard.layer.shadowOpacity = settingsDarkStyle ? 0.08 : 0.025;
    self.sidebarSummaryCard.layer.shadowRadius = 8;
    self.sidebarSummaryCard.layer.shadowOffset = CGSizeMake(0, -2);
    self.footerView.wantsLayer = YES;
    self.footerView.material = settingsDarkStyle ? NSVisualEffectMaterialUnderWindowBackground : NSVisualEffectMaterialContentBackground;
    self.footerView.layer.backgroundColor = theme.settingsHeader.CGColor;
    self.footerDivider.layer.backgroundColor = [theme.cardBorder colorWithAlphaComponent:0.58].CGColor;
    self.overviewCard.layer.backgroundColor = theme.card.CGColor;
    self.eyeCard.layer.backgroundColor = theme.card.CGColor;
    self.standCard.layer.backgroundColor = theme.card.CGColor;
    self.alertCard.layer.backgroundColor = theme.card.CGColor;
    self.automationCard.layer.backgroundColor = theme.card.CGColor;
    self.statsCard.layer.backgroundColor = theme.card.CGColor;
    self.overviewCard.layer.borderColor = theme.cardBorder.CGColor;
    self.eyeCard.layer.borderColor = theme.cardBorder.CGColor;
    self.standCard.layer.borderColor = theme.cardBorder.CGColor;
    self.alertCard.layer.borderColor = theme.cardBorder.CGColor;
    self.automationCard.layer.borderColor = theme.cardBorder.CGColor;
    self.statsCard.layer.borderColor = theme.cardBorder.CGColor;
    self.overviewCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.eyeCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.standCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.alertCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.automationCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.statsCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    NSArray<NSView *> *themeCards = @[self.overviewCard, self.eyeCard, self.standCard, self.alertCard, self.automationCard, self.statsCard];
    for (NSView *card in themeCards) {
        card.layer.masksToBounds = NO;
        card.layer.shadowColor = [NSColor.blackColor colorWithAlphaComponent:settingsDarkStyle ? 0.30 : 0.12].CGColor;
        card.layer.shadowOpacity = settingsDarkStyle ? 0.15 : 0.040;
        card.layer.shadowRadius = settingsDarkStyle ? 18 : 12;
        card.layer.shadowOffset = CGSizeMake(0, -3);
        ERRemoveStyleMotifLayers(card.layer, @"settings-card-motif");
        if (self.settings.restStyle == ERRestStylePixel || self.settings.restStyle == ERRestStyleToy) {
            ERAddStyleMotifLayers(card.layer, card.bounds, self.settings.restStyle, theme, @"settings-card-motif", 0.055, YES, 0);
        }
    }
    self.titleLabel.textColor = settingsPrimaryTextColor;
    self.summaryLabel.textColor = settingsSecondaryTextColor;
    for (NSTextField *label in self.sidebarLabels) {
        if (label == self.sidebarEyebrowLabel || label == self.sidebarSectionLabel) {
            label.textColor = [theme.accent colorWithAlphaComponent:settingsDarkStyle ? 0.90 : 0.78];
        } else {
            label.textColor = settingsDarkStyle ? theme.secondary : NSColor.tertiaryLabelColor;
        }
    }
    NSColor *pageIconBadgeColor = settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.085]
        : [theme.card colorWithAlphaComponent:0.72];
    NSColor *pageIconBorderColor = [theme.cardBorder colorWithAlphaComponent:settingsDarkStyle ? 0.50 : 0.62];
    for (NSView *badge in self.pageIconBadgeViews) {
        badge.layer.backgroundColor = pageIconBadgeColor.CGColor;
        badge.layer.borderColor = pageIconBorderColor.CGColor;
        badge.layer.borderWidth = 1;
        badge.layer.cornerRadius = theme.cornerRadius == 6 ? 7 : 12;
    }
    for (NSImageView *icon in self.pageIconViews) {
        icon.contentTintColor = theme.accent;
    }
    for (NSView *accent in self.pageAccentViews) {
        accent.layer.backgroundColor = [theme.accent colorWithAlphaComponent:settingsDarkStyle ? 0.92 : 0.76].CGColor;
        accent.layer.cornerRadius = theme.cornerRadius == 6 ? 1 : 1.5;
    }
    [self refreshSidebarAppearance];
    for (NSTextField *label in self.overviewLabels) {
        label.textColor = label == self.overviewEyeTimerLabel || label == self.overviewStandTimerLabel ? settingsPrimaryTextColor : settingsSecondaryTextColor;
    }
    self.overviewStatusTitleLabel.textColor = settingsPrimaryTextColor;
    self.overviewStatusDetailLabel.textColor = settingsSecondaryTextColor;
    self.overviewStatusBadgeLabel.textColor = theme.accent;
    self.overviewEyeStatusLabel.textColor = settingsPrimaryTextColor;
    self.overviewStandStatusLabel.textColor = settingsPrimaryTextColor;
    self.overviewStatusIcon.contentTintColor = theme.accent;
    self.overviewEyeIcon.contentTintColor = theme.accent;
    self.overviewStandIcon.contentTintColor = theme.accent;
    for (NSImageView *icon in self.summaryBandIcons) {
        icon.contentTintColor = theme.accent;
    }
    for (NSTextField *label in self.summaryBandLabels) {
        BOOL isBadge = label == self.eyeSummaryBadgeLabel || label == self.standSummaryBadgeLabel;
        BOOL isTitle = label == self.eyeSummaryTitleLabel || label == self.standSummaryTitleLabel;
        label.textColor = isBadge ? theme.accent : (isTitle ? settingsPrimaryTextColor : settingsSecondaryTextColor);
    }
    self.focusAppMatchLabel.textColor = settingsSecondaryTextColor;
    self.automationPolicyLabel.textColor = settingsSecondaryTextColor;
    self.automationLastActionLabel.textColor = settingsSecondaryTextColor;
    self.automationStatusStripe.layer.backgroundColor = theme.accent.CGColor;
    self.calendarStatusLabel.textColor = settingsSecondaryTextColor;
    self.quietHoursStatusLabel.textColor = settingsSecondaryTextColor;
    self.focusAppHintLabel.textColor = settingsSecondaryTextColor;
    self.standRoutineHintLabel.textColor = settingsSecondaryTextColor;
    self.standIntensityHintLabel.textColor = settingsSecondaryTextColor;
    self.standCustomStagesSummaryLabel.textColor = settingsSecondaryTextColor;
    self.standCustomStagesButton.contentTintColor = theme.accent;
    for (NSButton *button in self.overviewActionButtons) {
        button.contentTintColor = theme.accent;
    }
    self.applyButton.contentTintColor = theme.accent;
    self.resetButton.contentTintColor = settingsSecondaryTextColor;
    self.statsOverviewLabel.textColor = settingsPrimaryTextColor;
    self.statsMonthLabel.textColor = settingsSecondaryTextColor;
    self.statsStrategyLabel.textColor = settingsSecondaryTextColor;
    self.statsInsightLabel.textColor = settingsSecondaryTextColor;
    self.statsQualityLabel.textColor = settingsSecondaryTextColor;
    self.statsStandLabel.textColor = settingsSecondaryTextColor;
    self.statsStreakLabel.textColor = settingsSecondaryTextColor;
    self.exportStatsButton.contentTintColor = theme.accent;
    self.exportBackupButton.contentTintColor = theme.accent;
    self.importBackupButton.contentTintColor = theme.accent;
    for (NSTextField *label in self.pageTitleLabels) {
        label.textColor = settingsPrimaryTextColor;
    }
    for (NSTextField *label in self.pageSubtitleLabels) {
        label.textColor = settingsSecondaryTextColor;
    }
    for (NSTextField *label in self.fieldLabels) {
        label.textColor = settingsSecondaryTextColor;
    }
    for (NSTextField *label in self.statsBarLabels) {
        label.textColor = settingsSecondaryTextColor;
    }
    for (NSTextField *label in self.heatmapLabels) {
        label.textColor = settingsSecondaryTextColor;
    }
    NSColor *rowColor = settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.032]
        : [theme.cardBorder colorWithAlphaComponent:0.075];
    NSColor *tileColor = settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.092]
        : [NSColor colorWithWhite:1 alpha:0.40];
    NSColor *dividerColor = settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.10]
        : [theme.cardBorder colorWithAlphaComponent:0.34];
    for (NSView *tile in self.overviewTiles) {
        tile.layer.backgroundColor = tileColor.CGColor;
        tile.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:0.48].CGColor;
        tile.layer.cornerRadius = theme.cornerRadius == 6 ? 6 : 14;
    }
    for (NSView *band in self.summaryBandViews) {
        band.layer.backgroundColor = tileColor.CGColor;
        band.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:0.48].CGColor;
        band.layer.cornerRadius = theme.cornerRadius == 6 ? 6 : 14;
    }
    self.overviewActionBar.layer.backgroundColor = (settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.075]
        : [theme.cardBorder colorWithAlphaComponent:0.095]).CGColor;
    self.overviewActionBar.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:0.26].CGColor;
    self.overviewActionBar.layer.cornerRadius = theme.cornerRadius == 6 ? 6 : 10;
    NSColor *actionShellColor = settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.070]
        : [NSColor colorWithWhite:1 alpha:0.40];
    NSColor *actionShellBorder = settingsDarkStyle
        ? [NSColor colorWithWhite:1 alpha:0.10]
        : [theme.cardBorder colorWithAlphaComponent:0.24];
    for (NSView *shell in self.overviewActionButtonShells) {
        shell.layer.backgroundColor = actionShellColor.CGColor;
        shell.layer.borderColor = actionShellBorder.CGColor;
        shell.layer.cornerRadius = theme.cornerRadius == 6 ? 4 : 7;
    }
    self.automationStatusStripe.layer.cornerRadius = theme.cornerRadius == 6 ? 1 : 1.5;
    for (NSView *row in self.settingRowViews) {
        row.layer.backgroundColor = rowColor.CGColor;
        row.layer.cornerRadius = 0;
    }
    for (NSView *divider in self.settingDividerViews) {
        divider.layer.backgroundColor = dividerColor.CGColor;
    }
    [self refreshStylePreview];
}

- (void)refreshSidebarAppearance {
    if (!self.sidebarButtons) return;
    ERTheme theme = ERThemeForStyle(self.settings.restStyle);
    BOOL settingsDarkStyle = self.settings.restStyle == ERRestStyleNight;
    NSColor *selectedColor = settingsDarkStyle
        ? [theme.accent colorWithAlphaComponent:0.20]
        : [theme.card colorWithAlphaComponent:0.66];
    NSColor *idleColor = NSColor.clearColor;
    NSColor *selectedBorderColor = [theme.accent colorWithAlphaComponent:settingsDarkStyle ? 0.34 : 0.18];
    NSColor *selectedTextColor = settingsDarkStyle ? NSColor.whiteColor : NSColor.labelColor;
    NSColor *normalTextColor = settingsDarkStyle ? theme.secondary : NSColor.secondaryLabelColor;

    for (NSInteger index = 0; index < self.sidebarButtons.count; index++) {
        NSButton *button = self.sidebarButtons[index];
        BOOL selected = index == self.selectedPage;
        if (index < self.sidebarSelectionViews.count) {
            NSView *selection = self.sidebarSelectionViews[index];
            selection.hidden = NO;
            selection.layer.backgroundColor = (selected ? selectedColor : idleColor).CGColor;
            selection.layer.borderWidth = selected ? 1 : 0;
            selection.layer.borderColor = selectedBorderColor.CGColor;
            selection.layer.cornerRadius = 9;
            selection.layer.shadowColor = [NSColor.blackColor colorWithAlphaComponent:settingsDarkStyle ? 0.28 : 0.10].CGColor;
            selection.layer.shadowOpacity = selected ? (settingsDarkStyle ? 0.11 : 0.035) : 0;
            selection.layer.shadowRadius = selected ? 6 : 0;
            selection.layer.shadowOffset = CGSizeMake(0, -2);
        }
        if (index < self.sidebarNavIconViews.count) {
            self.sidebarNavIconViews[index].contentTintColor = selected ? theme.accent : normalTextColor;
        }
        if (index < self.sidebarNavTitleLabels.count) {
            NSTextField *label = self.sidebarNavTitleLabels[index];
            label.font = [NSFont systemFontOfSize:13 weight:selected ? NSFontWeightSemibold : NSFontWeightMedium];
            label.textColor = selected ? selectedTextColor : normalTextColor;
        }
    }
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

    ERAddStyleMotifLayers(self.stylePreviewCanvas.layer, self.stylePreviewCanvas.bounds, style, theme, @"stylePreviewMotif", 1.42, YES, 1);

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
    self.settings.standRoutine = ERClampInteger(self.standRoutinePopup.indexOfSelectedItem, ERStandRoutineBalanced, ERStandRoutineReset);
    self.settings.standIntensity = ERClampInteger(self.standIntensityPopup.indexOfSelectedItem, ERStandIntensityGentle, ERStandIntensityActive);
    self.settings.notificationsEnabled = self.notificationSwitch.state == NSControlStateValueOn;
    self.settings.showRestWindow = self.restWindowSwitch.state == NSControlStateValueOn;
    self.settings.restWindowTopmost = self.restWindowTopmostSwitch.state == NSControlStateValueOn;
    self.settings.launchAtLogin = self.launchAtLoginSwitch.state == NSControlStateValueOn;
    self.settings.autoFocusModeEnabled = self.autoFocusSwitch.state == NSControlStateValueOn;
    self.settings.calendarFocusModeEnabled = self.calendarFocusSwitch.state == NSControlStateValueOn;
    self.settings.presentationFocusModeEnabled = self.presentationFocusSwitch.state == NSControlStateValueOn;
    self.settings.quietHoursEnabled = self.quietHoursSwitch.state == NSControlStateValueOn;
    self.settings.quietHoursStartMinute = ERMinuteOfDayFromClockString(self.quietHoursStartField.stringValue, self.settings.quietHoursStartMinute);
    self.settings.quietHoursEndMinute = ERMinuteOfDayFromClockString(self.quietHoursEndField.stringValue, self.settings.quietHoursEndMinute);
    if (self.focusAppTokensField) {
        self.settings.focusAppTokens = ERSanitizedFocusAppTokensFromObject(self.focusAppTokensField.stringValue);
    }
    if (self.autoPauseAppTokensField) {
        self.settings.autoPauseAppTokens = ERSanitizedFocusAppTokensFromObject(self.autoPauseAppTokensField.stringValue);
    }
    if (self.ignoreAppTokensField) {
        self.settings.ignoreAppTokens = ERSanitizedFocusAppTokensFromObject(self.ignoreAppTokensField.stringValue);
    }
    if (self.calendarFocusTokensField) {
        self.settings.calendarFocusTokens = ERSanitizedFocusAppTokensFromObject(self.calendarFocusTokensField.stringValue);
    }
    if (self.calendarAutoPauseTokensField) {
        self.settings.calendarAutoPauseTokens = ERSanitizedFocusAppTokensFromObject(self.calendarAutoPauseTokensField.stringValue);
    }
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
    [self.appDelegate requestCalendarAccessIfNeeded];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:timingChanged];
}

- (void)toggleOnly:(id)sender {
    [self applySettings:sender];
}

- (void)editStandCustomStages:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"自定义站立阶段";
    alert.informativeText = @"每行一个阶段，格式：阶段名：动作说明。留空就使用内置动作组合。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"清空"];
    [alert addButtonWithTitle:@"取消"];

    NSScrollView *scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 460, 150)];
    scrollView.hasVerticalScroller = YES;
    scrollView.borderType = NSBezelBorder;
    NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 460, 150)];
    textView.font = [NSFont systemFontOfSize:13];
    textView.string = self.settings.standCustomStagesText.length > 0
        ? self.settings.standCustomStagesText
        : @"起身：双脚踩稳，离开椅背。\n肩颈：肩膀向后绕 5 圈。\n走动：走到窗边或房间另一侧。\n收尾：深呼吸 4 次，再回到桌前。";
    scrollView.documentView = textView;
    alert.accessoryView = scrollView;

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) {
            self.settings.standCustomStagesText = ERSanitizedStandCustomStagesTextFromObject(textView.string);
        } else if (response == NSAlertSecondButtonReturn) {
            self.settings.standCustomStagesText = @"";
        } else {
            return;
        }
        [self.settings save];
        [self refreshControls];
        [self.appDelegate settingsDidChangeShouldReset:NO];
    }];
}

- (void)editAutomationKeywords:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = @"策略关键词";
    alert.informativeText = @"多个关键词用逗号、分号或换行分隔。优先级：不处理 > 自动暂停 > 只发通知。恢复默认会回到内置会议、视频、游戏和日程关键词。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"恢复默认"];
    [alert addButtonWithTitle:@"取消"];

    NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 560, 370)];
    NSTextField *priorityHint = [NSTextField wrappingLabelWithString:@"命中多个策略时，会按“不处理 > 自动暂停 > 只发通知”处理。"];
    priorityHint.frame = NSMakeRect(0, 344, 548, 20);
    priorityHint.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    priorityHint.textColor = NSColor.secondaryLabelColor;
    [panel addSubview:priorityHint];

    NSTextField *appSectionTitle = [NSTextField labelWithString:@"应用策略"];
    appSectionTitle.frame = NSMakeRect(0, 310, 180, 20);
    appSectionTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [panel addSubview:appSectionTitle];

    NSTextField *appSectionDetail = [NSTextField labelWithString:@"按前台应用名称或 bundle id 命中。"];
    appSectionDetail.frame = NSMakeRect(0, 292, 420, 18);
    appSectionDetail.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    appSectionDetail.textColor = NSColor.secondaryLabelColor;
    [panel addSubview:appSectionDetail];

    NSString *externalBundle = self.appDelegate.lastExternalAppBundleIdentifier.length > 0
        ? self.appDelegate.lastExternalAppBundleIdentifier
        : self.appDelegate.frontmostAppBundleIdentifier;
    NSString *externalName = self.appDelegate.lastExternalAppName.length > 0
        ? self.appDelegate.lastExternalAppName
        : self.appDelegate.frontmostAppName;
    NSString *currentAppToken = externalBundle.length > 0 ? externalBundle : externalName;
    NSString *currentAppTitle = externalName.length > 0
        ? [NSString stringWithFormat:@"当前应用：%@", externalName]
        : @"当前应用：未识别";
    NSTextField *currentAppLabel = [NSTextField labelWithString:currentAppTitle];
    currentAppLabel.frame = NSMakeRect(0, 260, 224, 18);
    currentAppLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    currentAppLabel.textColor = NSColor.secondaryLabelColor;
    [panel addSubview:currentAppLabel];

    NSView *separator = [[NSView alloc] initWithFrame:NSMakeRect(0, 132, 548, 1)];
    separator.wantsLayer = YES;
    separator.layer.backgroundColor = NSColor.separatorColor.CGColor;
    [panel addSubview:separator];

    NSTextField *calendarSectionTitle = [NSTextField labelWithString:@"日程策略"];
    calendarSectionTitle.frame = NSMakeRect(0, 106, 180, 20);
    calendarSectionTitle.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    [panel addSubview:calendarSectionTitle];

    NSTextField *calendarSectionDetail = [NSTextField labelWithString:@"按日程标题、地点或日历名称命中。"];
    calendarSectionDetail.frame = NSMakeRect(0, 88, 420, 18);
    calendarSectionDetail.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    calendarSectionDetail.textColor = NSColor.secondaryLabelColor;
    [panel addSubview:calendarSectionDetail];

    NSArray<NSString *> *labels = @[@"只通知", @"自动暂停", @"不处理", @"只通知", @"自动暂停"];
    NSArray<NSString *> *values = @[
        [self.settings.focusAppTokens componentsJoinedByString:@", "],
        [self.settings.autoPauseAppTokens componentsJoinedByString:@", "],
        [self.settings.ignoreAppTokens componentsJoinedByString:@", "],
        [self.settings.calendarFocusTokens componentsJoinedByString:@", "],
        [self.settings.calendarAutoPauseTokens componentsJoinedByString:@", "]
    ];
    NSArray<NSString *> *placeholders = @[
        @"应用只通知：会议、演示类应用，不弹休息页",
        @"应用自动暂停：视频、游戏类应用，暂停计时并顺延",
        @"应用不处理：误命中兜底，照常提醒",
        @"日程只通知：会议、站会，不弹休息页",
        @"日程自动暂停：录制、直播、面试，暂停计时并顺延"
    ];
    NSArray<NSNumber *> *rowYs = @[
        @218,
        @182,
        @146,
        @52,
        @16
    ];
    NSMutableArray<NSTextField *> *fields = [NSMutableArray arrayWithCapacity:labels.count];
    for (NSInteger index = 0; index < labels.count; index++) {
        CGFloat y = rowYs[index].doubleValue;
        NSTextField *label = [NSTextField labelWithString:[NSString stringWithFormat:@"%@：", labels[index]]];
        label.frame = NSMakeRect(0, y + 4, 98, 22);
        label.alignment = NSTextAlignmentRight;
        label.textColor = NSColor.secondaryLabelColor;
        [panel addSubview:label];

        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(112, y, 436, 26)];
        field.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        field.bezelStyle = NSTextFieldRoundedBezel;
        field.placeholderString = placeholders[index];
        field.stringValue = values[index];
        [panel addSubview:field];
        [fields addObject:field];
    }

    NSArray<NSString *> *appendTitles = @[@"加到只通知", @"加到自动暂停", @"加到不处理"];
    for (NSInteger index = 0; index < appendTitles.count; index++) {
        NSButton *button = [NSButton buttonWithTitle:appendTitles[index] target:nil action:nil];
        button.frame = NSMakeRect(236 + index * 104, 254, 96, 28);
        button.bezelStyle = NSBezelStyleRounded;
        button.enabled = currentAppToken.length > 0;
        button.toolTip = currentAppToken.length > 0
            ? [NSString stringWithFormat:@"追加 %@", currentAppToken]
            : @"没有可追加的前台应用";
        NSTextField *targetField = fields[index];
        objc_setAssociatedObject(button, ERAutomationAppendFieldAssociationKey, targetField, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, ERAutomationAppendTokenAssociationKey, currentAppToken ?: @"", OBJC_ASSOCIATION_COPY_NONATOMIC);
        button.target = self;
        button.action = @selector(appendCurrentAppToAutomationKeywordField:);
        [panel addSubview:button];
    }
    alert.accessoryView = panel;

    [alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse response) {
        if (response == NSAlertSecondButtonReturn) {
            self.settings.focusAppTokens = ERDefaultFocusAppTokens();
            self.settings.autoPauseAppTokens = ERDefaultAutoPauseAppTokens();
            self.settings.ignoreAppTokens = ERDefaultIgnoreAppTokens();
            self.settings.calendarFocusTokens = ERDefaultCalendarFocusTokens();
            self.settings.calendarAutoPauseTokens = ERDefaultCalendarAutoPauseTokens();
        } else if (response == NSAlertFirstButtonReturn) {
            self.settings.focusAppTokens = ERSanitizedFocusAppTokensFromObject(fields[0].stringValue);
            self.settings.autoPauseAppTokens = ERSanitizedFocusAppTokensFromObject(fields[1].stringValue);
            self.settings.ignoreAppTokens = ERSanitizedFocusAppTokensFromObject(fields[2].stringValue);
            self.settings.calendarFocusTokens = ERSanitizedFocusAppTokensFromObject(fields[3].stringValue);
            self.settings.calendarAutoPauseTokens = ERSanitizedFocusAppTokensFromObject(fields[4].stringValue);
        } else {
            return;
        }
        [self.settings save];
        [self refreshControls];
        [self.appDelegate settingsDidChangeShouldReset:NO];
    }];
}

- (void)appendCurrentAppToAutomationKeywordField:(NSButton *)sender {
    NSTextField *field = objc_getAssociatedObject(sender, ERAutomationAppendFieldAssociationKey);
    NSString *token = objc_getAssociatedObject(sender, ERAutomationAppendTokenAssociationKey);
    if (![field isKindOfClass:NSTextField.class] || token.length == 0) return;
    field.stringValue = ERJoinedFocusTokensByAppendingToken(field.stringValue, token);
    sender.state = NSControlStateValueOn;
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
    self.settings.standRoutine = ERStandRoutineBalanced;
    self.settings.standIntensity = ERStandIntensityStandard;
    self.settings.standCustomStagesText = @"";
    self.settings.notificationsEnabled = YES;
    self.settings.showRestWindow = YES;
    self.settings.restWindowTopmost = NO;
    self.settings.launchAtLogin = NO;
    self.settings.autoFocusModeEnabled = YES;
    self.settings.calendarFocusModeEnabled = NO;
    self.settings.presentationFocusModeEnabled = YES;
    self.settings.quietHoursEnabled = NO;
    self.settings.quietHoursStartMinute = 22 * 60;
    self.settings.quietHoursEndMinute = 7 * 60;
    self.settings.focusAppTokens = ERDefaultFocusAppTokens();
    self.settings.autoPauseAppTokens = ERDefaultAutoPauseAppTokens();
    self.settings.ignoreAppTokens = ERDefaultIgnoreAppTokens();
    self.settings.calendarFocusTokens = ERDefaultCalendarFocusTokens();
    self.settings.calendarAutoPauseTokens = ERDefaultCalendarAutoPauseTokens();
    self.settings.menuBarMode = ERMenuBarModeBoth;
    self.settings.restStyle = ERRestStyleBreath;
    [self.settings save];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:YES];
}

- (void)resetFocusApps:(id)sender {
    self.settings.autoFocusModeEnabled = YES;
    self.settings.calendarFocusModeEnabled = NO;
    self.settings.presentationFocusModeEnabled = YES;
    self.settings.quietHoursEnabled = NO;
    self.settings.quietHoursStartMinute = 22 * 60;
    self.settings.quietHoursEndMinute = 7 * 60;
    self.settings.focusAppTokens = ERDefaultFocusAppTokens();
    self.settings.autoPauseAppTokens = ERDefaultAutoPauseAppTokens();
    self.settings.ignoreAppTokens = ERDefaultIgnoreAppTokens();
    self.settings.calendarFocusTokens = ERDefaultCalendarFocusTokens();
    self.settings.calendarAutoPauseTokens = ERDefaultCalendarAutoPauseTokens();
    [self.settings save];
    [self refreshControls];
    [self.appDelegate settingsDidChangeShouldReset:NO];
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
    window.level = NSNormalWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorManaged;
    window.opaque = YES;
    window.acceptsMouseMovedEvents = YES;
    window.ignoresMouseEvents = NO;
    [window setFrame:frame display:NO];

    NSView *content = [[ERRestOverlayContentView alloc] initWithFrame:NSMakeRect(0, 0, frame.size.width, frame.size.height)];
    content.wantsLayer = YES;
    window.contentView = content;
    self.backgroundView = content;

    CGFloat cardWidth = MIN(760, MAX(420, frame.size.width - 160));
    CGFloat cardHeight = MIN(520, MAX(460, frame.size.height - 120));
    self.focusCard = [[ERRestOverlayContentView alloc] initWithFrame:NSMakeRect(0, 0, cardWidth, cardHeight)];
    self.focusCard.wantsLayer = YES;
    self.focusCard.layer.backgroundColor = [NSColor colorWithWhite:1 alpha:0.18].CGColor;
    self.focusCard.layer.cornerRadius = 28;
    self.focusCard.layer.masksToBounds = YES;
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

    self.standStagePanel = ERRoundedView(NSZeroRect, [NSColor colorWithWhite:1 alpha:0.14], 18);
    self.standStagePanel.layer.borderWidth = 1;
    [self.focusCard addSubview:self.standStagePanel];

    self.standStageEyebrowLabel = [NSTextField labelWithString:@""];
    self.standStageEyebrowLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightSemibold];
    [self.standStagePanel addSubview:self.standStageEyebrowLabel];

    self.standStageCurrentLabel = [NSTextField wrappingLabelWithString:@""];
    self.standStageCurrentLabel.font = [NSFont systemFontOfSize:13 weight:NSFontWeightSemibold];
    self.standStageCurrentLabel.maximumNumberOfLines = 1;
    [self.standStagePanel addSubview:self.standStageCurrentLabel];

    self.standStageNextLabel = [NSTextField wrappingLabelWithString:@""];
    self.standStageNextLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.standStageNextLabel.maximumNumberOfLines = 1;
    [self.standStagePanel addSubview:self.standStageNextLabel];

    self.standStageProgressTrack = ERRoundedView(NSZeroRect, [NSColor colorWithWhite:1 alpha:0.18], 4);
    [self.standStagePanel addSubview:self.standStageProgressTrack];

    self.standStageProgressFill = ERRoundedView(NSZeroRect, NSColor.controlAccentColor, 4);
    [self.standStageProgressTrack addSubview:self.standStageProgressFill];

    self.styleHintLabel = [NSTextField labelWithString:@""];
    self.styleHintLabel.alignment = NSTextAlignmentRight;
    self.styleHintLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    [self.focusCard addSubview:self.styleHintLabel];

    self.finishButton = [self actionButtonWithTitle:@"完成" action:@selector(finish:)];
    self.finishButton.keyEquivalent = @"\r";
    [self.focusCard addSubview:self.finishButton];

    self.snoozeButton = [self actionButtonWithTitle:@"稍后 5 分钟" action:@selector(snooze:)];
    [self.focusCard addSubview:self.snoozeButton];

    self.skipButton = [self actionButtonWithTitle:@"跳过本次" action:@selector(skip:)];
    [self.focusCard addSubview:self.skipButton];

    self.extendButton = [self actionButtonWithTitle:@"延长 1 分钟" action:@selector(extend:)];
    [self.focusCard addSubview:self.extendButton];
    [self refreshActionBindings];
    [self layoutRestContent];
    return self;
}

- (ERRestActionButton *)actionButtonWithTitle:(NSString *)title action:(SEL)action {
    ERRestActionButton *button = [[ERRestActionButton alloc] initWithFrame:NSZeroRect];
    button.title = title;
    button.target = self;
    button.action = action;
    button.bezelStyle = NSBezelStyleRounded;
    button.font = [NSFont systemFontOfSize:15 weight:NSFontWeightMedium];
    return button;
}

- (void)refreshActionBindings {
    self.window.ignoresMouseEvents = NO;
    self.window.acceptsMouseMovedEvents = YES;
    self.finishButton.target = self;
    self.finishButton.action = @selector(finish:);
    self.finishButton.keyEquivalent = @"\r";
    self.snoozeButton.target = self;
    self.snoozeButton.action = @selector(snooze:);
    self.skipButton.target = self;
    self.skipButton.action = @selector(skip:);
    self.extendButton.target = self;
    self.extendButton.action = @selector(extend:);
    self.finishButton.enabled = YES;
    self.snoozeButton.enabled = YES;
    self.skipButton.enabled = YES;
    self.extendButton.enabled = YES;
}

- (BOOL)hasHealthyActionBindings {
    return self.appDelegate &&
        self.window &&
        !self.window.ignoresMouseEvents &&
        [self.finishButton isKindOfClass:ERRestActionButton.class] &&
        self.finishButton.target == self &&
        self.finishButton.action == @selector(finish:) &&
        self.finishButton.enabled &&
        [self.snoozeButton isKindOfClass:ERRestActionButton.class] &&
        self.snoozeButton.target == self &&
        self.snoozeButton.action == @selector(snooze:) &&
        self.snoozeButton.enabled &&
        [self.skipButton isKindOfClass:ERRestActionButton.class] &&
        self.skipButton.target == self &&
        self.skipButton.action == @selector(skip:) &&
        self.skipButton.enabled &&
        [self.extendButton isKindOfClass:ERRestActionButton.class] &&
        self.extendButton.target == self &&
        self.extendButton.action == @selector(extend:) &&
        self.extendButton.enabled;
}

- (void)configureForKind:(ERReminderKind)kind settings:(ERSettings *)settings duration:(NSTimeInterval)duration {
    self.kind = kind;
    self.totalDuration = MAX(1, duration);
    self.currentStyle = settings.restStyle;
    [self refreshActionBindings];
    [self applyStyle:settings.restStyle];
    [self applyWindowLevelForSettings:settings];

    if (kind == ERReminderKindStand) {
        self.iconView.image = [NSImage imageWithSystemSymbolName:@"figure.stand" accessibilityDescription:@"Stand"];
        BOOL hasCustomStages = ERStandCustomStageEntriesFromText(settings.standCustomStagesText).count > 0;
        self.titleLabel.stringValue = [NSString stringWithFormat:@"站立 · %@ · %@",
                                       hasCustomStages ? @"自定义阶段" : ERStandRoutineTitle(settings.standRoutine),
                                       ERStandIntensityTitle(settings.standIntensity)];
        self.messageLabel.stringValue = hasCustomStages
            ? [NSString stringWithFormat:@"跟着你自己设置的阶段活动。%@", ERStandIntensitySuffix(settings.standIntensity)]
            : [NSString stringWithFormat:@"%@ %@", ERStandRoutineSummary(settings.standRoutine), ERStandIntensitySuffix(settings.standIntensity)];
    } else if (settings.eyeMode == EREyeModePomodoro) {
        self.iconView.image = [NSImage imageWithSystemSymbolName:@"timer" accessibilityDescription:@"Pomodoro"];
        self.titleLabel.stringValue = @"番茄休息";
        self.messageLabel.stringValue = @"站起来、喝水、走几步。下一轮专注会更轻松。";
    } else {
        self.iconView.image = [NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"Eye"];
        self.titleLabel.stringValue = @"看向 6 米外";
        self.messageLabel.stringValue = @"抬头眺望远方，让眼睛从屏幕焦距里出来。慢慢眨眼，至少 20 秒。";
    }
    [self configureActionSuggestionsForKind:kind settings:settings];
}

- (void)configureActionSuggestionsForKind:(ERReminderKind)kind settings:(ERSettings *)settings {
    if (kind == ERReminderKindStand) {
        NSArray<NSDictionary<NSString *, NSString *> *> *customStages = ERStandCustomStageEntriesFromText(settings.standCustomStagesText);
        if (customStages.count > 0) {
            NSMutableArray<NSString *> *titles = [NSMutableArray arrayWithCapacity:customStages.count];
            NSMutableArray<NSString *> *messages = [NSMutableArray arrayWithCapacity:customStages.count];
            NSMutableArray<NSString *> *suggestions = [NSMutableArray arrayWithCapacity:customStages.count];
            NSMutableArray<NSString *> *symbols = [NSMutableArray arrayWithCapacity:customStages.count];
            NSArray<NSString *> *symbolCycle = @[@"figure.stand", @"arrow.triangle.2.circlepath", @"figure.walk", @"wind", @"checkmark.circle"];
            for (NSInteger index = 0; index < customStages.count; index++) {
                NSDictionary<NSString *, NSString *> *entry = customStages[index];
                NSString *title = entry[@"title"] ?: [NSString stringWithFormat:@"阶段 %ld", (long)index + 1];
                NSString *suggestion = entry[@"suggestion"] ?: title;
                [titles addObject:title];
                [messages addObject:ERStandStageMessageWithIntensity(suggestion, settings.standIntensity)];
                [suggestions addObject:suggestion];
                [symbols addObject:symbolCycle[index % symbolCycle.count]];
            }
            self.actionStageTitles = titles;
            self.actionStageMessages = messages;
            self.actionSuggestions = suggestions;
            self.actionSuggestionSymbols = symbols;
        } else {
            switch (settings.standRoutine) {
                case ERStandRoutineNeckShoulder:
                    self.actionStageTitles = @[@"抬胸", @"肩绕", @"颈侧", @"胸背", @"收尾"];
                    self.actionStageMessages = @[
                        @"先站高一点，让胸口离开桌面姿势。",
                        @"肩膀慢慢向后绕圈，动作小一点也可以。",
                        @"头轻轻侧向一边，别压迫颈部。",
                        @"双手向后打开，让上背从含胸里出来。",
                        @"放松下巴和肩膀，再慢慢回到桌前。"
                    ];
                    self.actionSuggestions = @[
                        @"双脚踩稳，胸口向上，肩膀自然落下。",
                        @"肩膀向后绕 8 圈，再向前绕 5 圈。",
                        @"左右侧颈各停 2 次，只做到舒服的位置。",
                        @"双手在身后轻轻打开，深呼吸 4 次。",
                        @"下巴微收，肩膀放低，确认脖子轻一点。"
                    ];
                    self.actionSuggestionSymbols = @[@"figure.stand", @"arrow.triangle.2.circlepath", @"person.crop.circle", @"figure.strengthtraining.traditional", @"checkmark.circle"];
                    break;
                case ERStandRoutineWalk:
                    self.actionStageTitles = @[@"起身", @"走动", @"腿部", @"脚踝", @"回桌"];
                    self.actionStageMessages = @[
                        @"从椅子上离开，别急着回到屏幕前。",
                        @"走到房间另一侧，让腰背和腿真的动起来。",
                        @"活动大腿和小腿，打断久坐的僵硬。",
                        @"脚踝转一转，顺便让小腿放松。",
                        @"回到桌前前，先把下一件事想清楚。"
                    ];
                    self.actionSuggestions = @[
                        @"站起来，离开桌边至少几步。",
                        @"走 20 到 40 步，经过窗边就看一眼远处。",
                        @"轻轻提踵 10 次，膝盖保持放松。",
                        @"左右脚踝各绕 8 圈，脚尖点地也行。",
                        @"慢慢走回桌前，只带回下一件小事。"
                    ];
                    self.actionSuggestionSymbols = @[@"figure.stand", @"figure.walk", @"figure.walk.motion", @"figure.cooldown", @"checkmark.circle"];
                    break;
                case ERStandRoutineReset:
                    self.actionStageTitles = @[@"站稳", @"呼吸", @"远眺", @"补水", @"收尾"];
                    self.actionStageMessages = @[
                        @"这次不用强度，先让身体从座位里出来。",
                        @"把呼吸放慢，肩膀跟着落下来。",
                        @"看向远处，把注意力从屏幕里拿出来。",
                        @"喝几口水，给自己一个轻量重启。",
                        @"确认身体和注意力都松一点，再继续。"
                    ];
                    self.actionSuggestions = @[
                        @"双脚踩稳，手离开键盘，停 3 秒。",
                        @"吸气 4 拍，呼气 6 拍，重复 4 次。",
                        @"看向 6 米外或窗外，不急着聚焦。",
                        @"喝水，顺便放松手腕和下巴。",
                        @"给下一段工作定一个很小的起点。"
                    ];
                    self.actionSuggestionSymbols = @[@"figure.stand", @"wind", @"eye", @"drop.fill", @"checkmark.circle"];
                    break;
                case ERStandRoutineBalanced:
                default:
                    self.actionStageTitles = @[@"起身", @"肩颈", @"走动", @"补水", @"收尾"];
                    self.actionStageMessages = @[
                        @"先站稳，离开椅背，膝盖微松。",
                        @"肩膀向后绕圈，脖子慢慢转动。",
                        @"离开桌边走一小圈，让腰背换个姿势。",
                        @"喝几口水，活动脚踝和小腿。",
                        @"深呼吸，确认身体轻一点再回来。"
                    ];
                    self.actionSuggestions = @[
                        @"双脚踩稳地面，离开椅背。",
                        @"肩膀向后绕 5 圈，左右转头各 3 次。",
                        @"走到窗边或房间另一侧，再走回来。",
                        @"喝水，顺便活动脚踝和小腿。",
                        @"深呼吸 4 次，慢慢回到桌前。"
                    ];
                    self.actionSuggestionSymbols = @[@"figure.stand", @"arrow.triangle.2.circlepath", @"figure.walk", @"drop.fill", @"wind"];
                    break;
            }
        }
        NSMutableArray<NSString *> *adjustedSuggestions = [NSMutableArray arrayWithCapacity:self.actionSuggestions.count];
        for (NSString *suggestion in self.actionSuggestions) {
            [adjustedSuggestions addObject:ERStandAdjustedSuggestion(suggestion, settings.standIntensity)];
        }
        self.actionSuggestions = adjustedSuggestions;
    } else if (settings.eyeMode == EREyeModePomodoro) {
        self.actionStageTitles = @[@"离屏", @"补水", @"走动", @"收尾"];
        self.actionStageMessages = @[];
        self.actionSuggestions = @[
            @"先把手从键盘上拿开，离开屏幕。",
            @"喝几口水，顺便看向远处。",
            @"站起来走 20 步，让注意力重启。",
            @"回来前只想好下一件小事。"
        ];
        self.actionSuggestionSymbols = @[@"timer", @"drop.fill", @"figure.walk", @"checkmark.circle"];
    } else {
        self.actionStageTitles = @[@"远眺", @"眨眼", @"放焦", @"呼吸"];
        self.actionStageMessages = @[];
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

- (void)applyWindowLevelForSettings:(ERSettings *)settings {
    BOOL topmost = settings.restWindowTopmost;
    self.window.level = topmost ? NSStatusWindowLevel : NSNormalWindowLevel;
    self.window.collectionBehavior = topmost
        ? (NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorFullScreenAuxiliary)
        : NSWindowCollectionBehaviorManaged;
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
    self.standStagePanel.frame = NSMakeRect(cardCenterX - pillWidth / 2.0, buttonY + 50, pillWidth, 76);
    self.standStageEyebrowLabel.frame = NSMakeRect(16, 54, pillWidth - 32, 16);
    self.standStageCurrentLabel.frame = NSMakeRect(16, 33, pillWidth - 32, 17);
    self.standStageNextLabel.frame = NSMakeRect(16, 17, pillWidth - 32, 14);
    self.standStageProgressTrack.frame = NSMakeRect(16, 8, pillWidth - 32, 5);
    self.standStageProgressFill.frame = NSMakeRect(0, 0, 1, 5);
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
    [self refreshActionBindings];
    [self applyWindowLevelForSettings:self.appDelegate.settings];
    [self refitToCurrentScreen];
    if (self.appDelegate.settings.restWindowTopmost) {
        [self showWindow:nil];
        [self.window orderFrontRegardless];
        [NSApp activateIgnoringOtherApps:YES];
        [self.window makeKeyAndOrderFront:nil];
    } else {
        [self.window orderFront:nil];
    }
}

- (void)applyStyle:(ERRestStyle)style {
    ERTheme theme = ERThemeForStyle(style);
    self.currentStyle = style;

    ERRemoveStyleMotifLayers(self.backgroundView.layer, @"restBackdropGradient");
    ERRemoveStyleMotifLayers(self.backgroundView.layer, @"rest-backdrop-motif");
    CAGradientLayer *backdrop = ERGradientLayer(self.backgroundView.bounds, @[theme.backgroundA, theme.backgroundB], CGPointMake(0, 0), CGPointMake(1, 1));
    backdrop.name = @"restBackdropGradient";
    [self.backgroundView.layer insertSublayer:backdrop atIndex:0];
    [self addDecorationsForStyle:style theme:theme];

    ERRemoveStyleMotifLayers(self.focusCard.layer, @"rest-card-motif");
    CGFloat cardAlpha = style == ERRestStyleNight ? 0.18 : (style == ERRestStyleToy ? 0.38 : (style == ERRestStylePixel ? 0.46 : 0.30));
    self.focusCard.layer.backgroundColor = [theme.card colorWithAlphaComponent:cardAlpha].CGColor;
    self.focusCard.layer.borderColor = theme.cardBorder.CGColor;
    self.focusCard.layer.cornerRadius = theme.cornerRadius;
    self.focusCard.layer.borderWidth = style == ERRestStylePixel ? 2 : 1;
    self.focusCard.layer.shadowOpacity = style == ERRestStylePixel ? 0.0 : (style == ERRestStyleNight ? 0.30 : 0.18);
    self.focusCard.layer.shadowRadius = style == ERRestStylePixel ? 0 : 28;
    self.focusCard.layer.shadowOffset = CGSizeMake(0, style == ERRestStylePixel ? 0 : -10);
    self.focusCard.layer.shadowColor = [NSColor.blackColor colorWithAlphaComponent:0.28].CGColor;
    ERAddStyleMotifLayers(self.focusCard.layer, self.focusCard.bounds, style, theme, @"rest-card-motif", 0.18, YES, 0);
    for (CALayer *layer in self.focusCard.layer.sublayers) {
        if ([layer.name hasPrefix:@"rest-card-motif"]) {
            layer.zPosition = -1;
        }
    }

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
    self.standStagePanel.layer.backgroundColor = [theme.card colorWithAlphaComponent:(style == ERRestStyleNight ? 0.16 : 0.26)].CGColor;
    self.standStagePanel.layer.borderColor = [theme.cardBorder colorWithAlphaComponent:0.72].CGColor;
    self.standStagePanel.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 18;
    self.standStageEyebrowLabel.textColor = theme.secondary;
    self.standStageCurrentLabel.textColor = theme.foreground;
    self.standStageNextLabel.textColor = theme.secondary;
    self.standStageProgressTrack.layer.backgroundColor = [theme.cardBorder colorWithAlphaComponent:0.42].CGColor;
    self.standStageProgressFill.layer.backgroundColor = theme.accent.CGColor;
    self.finishButton.contentTintColor = theme.accent;
    self.snoozeButton.contentTintColor = theme.accent;
    self.skipButton.contentTintColor = theme.accent;
    self.extendButton.contentTintColor = theme.accent;
}

- (void)addDecorationsForStyle:(ERRestStyle)style theme:(ERTheme)theme {
    ERAddStyleMotifLayers(self.backgroundView.layer, self.backgroundView.bounds, style, theme, @"rest-backdrop-motif", 0.54, NO, 1);
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
    BOOL stageChanged = index != self.activeSuggestionIndex;
    NSString *suggestion = self.actionSuggestions[index];
    NSString *stageTitle = index < self.actionStageTitles.count ? self.actionStageTitles[index] : @"建议";
    NSString *nextTitle = index + 1 < self.actionStageTitles.count ? self.actionStageTitles[index + 1] : @"完成";
    NSString *nextSuggestion = index + 1 < self.actionSuggestions.count ? self.actionSuggestions[index + 1] : @"回到桌前前，确认身体轻一点。";
    CGFloat stageStart = (CGFloat)index / MAX(1, count);
    CGFloat stageEnd = (CGFloat)(index + 1) / MAX(1, count);
    CGFloat stageProgress = (ratio - stageStart) / MAX(0.001, stageEnd - stageStart);
    stageProgress = MIN(1, MAX(0.04, stageProgress));

    if (self.kind == ERReminderKindStand) {
        self.actionSuggestionPill.hidden = YES;
        self.progressIndicator.hidden = YES;
        self.standStagePanel.hidden = NO;
        self.standStageEyebrowLabel.stringValue = [NSString stringWithFormat:@"阶段 %ld/%ld · %@", (long)index + 1, (long)count, stageTitle];
        self.standStageCurrentLabel.stringValue = [NSString stringWithFormat:@"现在：%@", suggestion];
        self.standStageNextLabel.stringValue = [NSString stringWithFormat:@"下一步：%@ · %@", nextTitle, nextSuggestion];
        NSRect fillFrame = self.standStageProgressTrack.bounds;
        fillFrame.size.width = MAX(6, fillFrame.size.width * stageProgress);
        self.standStageProgressFill.frame = fillFrame;
    } else {
        self.actionSuggestionPill.hidden = NO;
        self.progressIndicator.hidden = NO;
        self.standStagePanel.hidden = YES;
        self.actionSuggestionLabel.stringValue = [NSString stringWithFormat:@"阶段 %ld/%ld · %@ · %@",
                                                  (long)index + 1,
                                                  (long)count,
                                                  stageTitle,
                                                  suggestion];
    }

    if (stageChanged) {
        self.activeSuggestionIndex = index;
        if (index < self.actionStageMessages.count) {
            self.messageLabel.stringValue = self.actionStageMessages[index];
        }

        NSString *symbolName = index < self.actionSuggestionSymbols.count ? self.actionSuggestionSymbols[index] : @"sparkles";
        self.actionSuggestionIcon.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"动作建议"];
    }
}

- (void)finish:(id)sender {
    ERRestWindowController *controller = self;
    [controller.appDelegate finishRestForKind:controller.kind manually:YES];
    [controller close];
}

- (void)extend:(id)sender {
    [self.appDelegate extendRestForKind:self.kind bySeconds:60];
}

- (void)snooze:(id)sender {
    ERRestWindowController *controller = self;
    [controller.appDelegate snoozeRestForKind:controller.kind bySeconds:5 * 60];
    [controller close];
}

- (void)skip:(id)sender {
    ERRestWindowController *controller = self;
    [controller.appDelegate skipRestForKind:controller.kind];
    [controller close];
}

- (void)cancelOperation:(id)sender {
    ERRestWindowController *controller = self;
    [controller.appDelegate skipRestForKind:controller.kind];
    [controller close];
}

- (BOOL)er_shouldYieldForMouseDown:(NSEvent *)event {
    if (self.appDelegate.settings.restWindowTopmost) return NO;
    NSPoint location = event.locationInWindow;
    NSArray<NSView *> *interactiveViews = @[self.finishButton, self.snoozeButton, self.skipButton, self.extendButton];
    for (NSView *view in interactiveViews) {
        NSPoint point = [view convertPoint:location fromView:nil];
        if (NSPointInRect(point, view.bounds)) {
            return NO;
        }
    }
    return YES;
}

- (void)er_yieldRestOverlayForUserFocusChange:(id)sender {
    [self.appDelegate yieldRestOverlayForUserFocusChange];
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
    [self loadRecoveryHistory];
    self.lastAutomationActionText = [NSUserDefaults.standardUserDefaults stringForKey:ERLastAutomationActionTextKey];
    self.lastAutomationActionAt = [NSUserDefaults.standardUserDefaults objectForKey:ERLastAutomationActionAtKey];
    self.lastScreenDiagnosticSummary = ERScreenDiagnosticSummary();
    [self rebuildMenu];
    [self resetAllTimers];
    [self applyPreferenceSideEffects];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(handleOpenSettingsRequest:)
                                                          name:EROpenSettingsNotificationName
                                                        object:nil];
    [NSDistributedNotificationCenter.defaultCenter addObserver:self
                                                      selector:@selector(handleRecoveryStressTestRequest:)
                                                          name:ERRunRecoveryStressTestNotificationName
                                                        object:nil];
    [NSAppleEventManager.sharedAppleEventManager setEventHandler:self
                                                    andSelector:@selector(handleGetURLEvent:withReplyEvent:)
                                                  forEventClass:kInternetEventClass
                                                     andEventID:kAEGetURL];

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
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(frontmostApplicationDidChange:)
                                                           name:NSWorkspaceDidActivateApplicationNotification
                                                         object:nil];
    [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self
                                                       selector:@selector(activeSpaceDidChange:)
                                                           name:NSWorkspaceActiveSpaceDidChangeNotification
                                                         object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(screenParametersChanged:)
                                               name:NSApplicationDidChangeScreenParametersNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(applicationDidResignActive:)
                                               name:NSApplicationDidResignActiveNotification
                                             object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(calendarStoreChanged:)
                                               name:EKEventStoreChangedNotification
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
        self.todayManualDone = 0;
        self.todayNotificationOnly = 0;
        self.todayAutoPauseSessions = 0;
        self.todayAutoPauseSeconds = 0;
        [self saveTodayStats];
        return;
    }
    self.todayEyeDone = [defaults integerForKey:ERStatsEyeDoneKey];
    self.todayStandDone = [defaults integerForKey:ERStatsStandDoneKey];
    self.todayStandSeconds = [defaults integerForKey:ERStatsStandSecondsKey];
    self.todaySnoozed = [defaults integerForKey:ERStatsSnoozedKey];
    self.todaySkipped = [defaults integerForKey:ERStatsSkippedKey];
    self.todayManualDone = [defaults integerForKey:ERStatsManualDoneKey];
    self.todayNotificationOnly = [defaults integerForKey:ERStatsNotificationOnlyKey];
    self.todayAutoPauseSessions = [defaults integerForKey:ERStatsAutoPauseSessionsKey];
    self.todayAutoPauseSeconds = [defaults integerForKey:ERStatsAutoPauseSecondsKey];
}

- (void)saveTodayStats {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:ERTodayKey() forKey:ERStatsDateKey];
    [defaults setInteger:self.todayEyeDone forKey:ERStatsEyeDoneKey];
    [defaults setInteger:self.todayStandDone forKey:ERStatsStandDoneKey];
    [defaults setInteger:self.todayStandSeconds forKey:ERStatsStandSecondsKey];
    [defaults setInteger:self.todaySnoozed forKey:ERStatsSnoozedKey];
    [defaults setInteger:self.todaySkipped forKey:ERStatsSkippedKey];
    [defaults setInteger:self.todayManualDone forKey:ERStatsManualDoneKey];
    [defaults setInteger:self.todayNotificationOnly forKey:ERStatsNotificationOnlyKey];
    [defaults setInteger:self.todayAutoPauseSessions forKey:ERStatsAutoPauseSessionsKey];
    [defaults setInteger:self.todayAutoPauseSeconds forKey:ERStatsAutoPauseSecondsKey];

    NSMutableDictionary *history = [[defaults dictionaryForKey:ERStatsHistoryKey] mutableCopy] ?: [NSMutableDictionary dictionary];
    NSString *today = ERTodayKey();
    history[today] = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    NSSet *recent = [NSSet setWithArray:ERRecentDateKeys(30)];
    for (NSString *dateKey in history.allKeys) {
        if (![recent containsObject:dateKey]) {
            [history removeObjectForKey:dateKey];
        }
    }
    [defaults setObject:history forKey:ERStatsHistoryKey];
}

- (void)loadRecoveryHistory {
    NSArray *savedHistory = [NSUserDefaults.standardUserDefaults arrayForKey:ERRecoveryHistoryKey];
    NSMutableArray<NSDictionary<NSString *, id> *> *history = [NSMutableArray array];

    for (id item in savedHistory) {
        if (![item isKindOfClass:NSDictionary.class]) continue;
        NSDictionary *entry = (NSDictionary *)item;
        NSDate *time = [entry[@"time"] isKindOfClass:NSDate.class] ? entry[@"time"] : nil;
        if (!time) continue;
        NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"系统事件";
        NSString *detail = [entry[@"detail"] isKindOfClass:NSString.class] ? entry[@"detail"] : @"状态正常";
        [history addObject:@{
            @"time": time,
            @"title": title,
            @"detail": detail
        }];
        if (history.count >= ERRecoveryHistoryLimit) break;
    }

    self.recoveryEventHistory = history;
    NSDictionary<NSString *, id> *latest = history.firstObject;
    if (latest) {
        self.lastSystemEventAt = [latest[@"time"] isKindOfClass:NSDate.class] ? latest[@"time"] : nil;
        self.lastSystemEventTitle = [latest[@"title"] isKindOfClass:NSString.class] ? latest[@"title"] : @"系统事件";
        self.lastRecoveryDetail = [latest[@"detail"] isKindOfClass:NSString.class] ? latest[@"detail"] : @"状态正常";
    }
}

- (void)saveRecoveryHistory {
    NSMutableArray<NSDictionary<NSString *, id> *> *history = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *entry in self.recoveryEventHistory) {
        NSDate *time = [entry[@"time"] isKindOfClass:NSDate.class] ? entry[@"time"] : nil;
        if (!time) continue;
        NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"系统事件";
        NSString *detail = [entry[@"detail"] isKindOfClass:NSString.class] ? entry[@"detail"] : @"状态正常";
        [history addObject:@{
            @"time": time,
            @"title": title,
            @"detail": detail
        }];
        if (history.count >= ERRecoveryHistoryLimit) break;
    }
    [NSUserDefaults.standardUserDefaults setObject:history forKey:ERRecoveryHistoryKey];
}

- (void)resetTodayStatsIfNeeded {
    NSString *savedDate = [NSUserDefaults.standardUserDefaults stringForKey:ERStatsDateKey];
    if (![savedDate isEqualToString:ERTodayKey()]) {
        self.autoPauseActive = NO;
        self.autoPauseSessionActive = NO;
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
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };
    return history;
}

- (void)applyPreferenceSideEffects {
    ERApplyLaunchAtLogin(self.settings.launchAtLogin);
    [self requestCalendarAccessIfNeeded];
    [self updateStatusItemAppearance];
    [self normalizeWindowLevelsForCurrentSettings];
}

- (void)requestCalendarAccessIfNeeded {
    if (!self.settings.autoFocusModeEnabled || !self.settings.calendarFocusModeEnabled || self.calendarAccessRequested || ERCalendarAccessGranted()) return;
    EKAuthorizationStatus status = [EKEventStore authorizationStatusForEntityType:EKEntityTypeEvent];
    if (status != EKAuthorizationStatusNotDetermined) {
        [self refreshCalendarFocusStateIfNeeded:YES];
        return;
    }
    self.calendarAccessRequested = YES;
    if (!self.eventStore) {
        self.eventStore = [[EKEventStore alloc] init];
    }
    void (^completion)(BOOL, NSError *) = ^(BOOL granted, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.calendarAccessRequested = NO;
            [self refreshCalendarFocusStateIfNeeded:YES];
            [self.settingsWindowController refreshAutomationStatus];
            [self publishState];
        });
    };
    if (@available(macOS 14.0, *)) {
        [self.eventStore requestFullAccessToEventsWithCompletion:completion];
    } else {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
        [self.eventStore requestAccessToEntityType:EKEntityTypeEvent completion:completion];
#pragma clang diagnostic pop
    }
}

- (BOOL)isCurrentCalendarEvent:(EKEvent *)event now:(NSDate *)now {
    if (!event || event.isAllDay || event.status == EKEventStatusCanceled) return NO;
    if (!event.startDate || !event.endDate) return NO;
    if ([event.startDate timeIntervalSinceDate:now] > 0 || [event.endDate timeIntervalSinceDate:now] <= 0) return NO;
    return YES;
}

- (void)refreshCalendarFocusStateIfNeeded:(BOOL)force {
    if (!self.settings.autoFocusModeEnabled || !self.settings.calendarFocusModeEnabled || !ERCalendarAccessGranted()) {
        self.calendarFocusActive = NO;
        self.calendarAutoPauseActive = NO;
        self.currentCalendarEventTitle = nil;
        self.lastCalendarRefreshAt = nil;
        return;
    }
    NSDate *now = NSDate.date;
    if (!force && self.lastCalendarRefreshAt && [now timeIntervalSinceDate:self.lastCalendarRefreshAt] < 60) {
        return;
    }
    self.lastCalendarRefreshAt = now;
    if (!self.eventStore) {
        self.eventStore = [[EKEventStore alloc] init];
    }
    NSDate *start = [now dateByAddingTimeInterval:-60];
    NSDate *end = [now dateByAddingTimeInterval:60];
    NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:start endDate:end calendars:nil];
    NSArray<EKEvent *> *events = [self.eventStore eventsMatchingPredicate:predicate];
    EKEvent *fallbackEvent = nil;
    EKEvent *focusEvent = nil;
    EKEvent *autoPauseEvent = nil;
    for (EKEvent *event in events) {
        if (![self isCurrentCalendarEvent:event now:now]) continue;
        if (!fallbackEvent) fallbackEvent = event;
        if (!focusEvent && ERCalendarEventMatchesTokens(event, self.settings.calendarFocusTokens)) {
            focusEvent = event;
        }
        if (ERCalendarEventMatchesTokens(event, self.settings.calendarAutoPauseTokens)) {
            autoPauseEvent = event;
            break;
        }
    }
    EKEvent *activeEvent = autoPauseEvent ?: focusEvent ?: fallbackEvent;
    self.calendarAutoPauseActive = autoPauseEvent != nil;
    self.calendarFocusActive = !self.calendarAutoPauseActive && activeEvent != nil;
    self.currentCalendarEventTitle = activeEvent.title;
}

- (NSString *)calendarDiagnosticText {
    [self refreshCalendarFocusStateIfNeeded:YES];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 日历诊断", ERBrandName]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"日历授权：%@", ERCalendarAccessStatusText()]];
    [lines addObject:[NSString stringWithFormat:@"自动策略：%@ · 日历联动 %@",
                      self.settings.autoFocusModeEnabled ? @"开" : @"关",
                      self.settings.calendarFocusModeEnabled ? @"开" : @"关"]];
    [lines addObject:[NSString stringWithFormat:@"当前策略：%@", [self focusModeStatusText]]];
    [lines addObject:[NSString stringWithFormat:@"状态标记：calendar=%@ · calendarPause=%@ · autoFocus=%@ · autoPause=%@",
                      self.calendarFocusActive ? @"YES" : @"NO",
                      self.calendarAutoPauseActive ? @"YES" : @"NO",
                      self.autoFocusActive ? @"YES" : @"NO",
                      self.autoPauseActive ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"只通知关键词：%@", [self.settings.calendarFocusTokens componentsJoinedByString:@", "]]];
    [lines addObject:[NSString stringWithFormat:@"自动暂停关键词：%@", [self.settings.calendarAutoPauseTokens componentsJoinedByString:@", "]]];

    if (!self.settings.autoFocusModeEnabled || !self.settings.calendarFocusModeEnabled) {
        [lines addObject:@"真实事件：日历联动未开启，未读取事件。"];
        return [lines componentsJoinedByString:@"\n"];
    }
    if (!ERCalendarAccessGranted()) {
        [lines addObject:@"真实事件：尚未授权或系统不可用，无法读取当前日程。"];
        [lines addObject:@"处理建议：在系统设置里允许松一下访问日历，然后重新运行诊断。"];
        return [lines componentsJoinedByString:@"\n"];
    }

    if (!self.eventStore) {
        self.eventStore = [[EKEventStore alloc] init];
    }
    NSDate *now = NSDate.date;
    NSDate *start = [now dateByAddingTimeInterval:-300];
    NSDate *end = [now dateByAddingTimeInterval:300];
    NSPredicate *predicate = [self.eventStore predicateForEventsWithStartDate:start endDate:end calendars:nil];
    NSArray<EKEvent *> *events = [self.eventStore eventsMatchingPredicate:predicate];
    NSMutableArray<EKEvent *> *currentEvents = [NSMutableArray array];
    for (EKEvent *event in events) {
        if ([self isCurrentCalendarEvent:event now:now]) {
            [currentEvents addObject:event];
        }
    }

    if (currentEvents.count == 0) {
        [lines addObject:@"真实事件：当前没有进行中的日程。"];
        return [lines componentsJoinedByString:@"\n"];
    }

    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.locale = NSLocale.currentLocale;
    formatter.dateFormat = @"HH:mm";
    [lines addObject:[NSString stringWithFormat:@"真实事件：当前 %ld 个进行中", (long)currentEvents.count]];
    for (EKEvent *event in currentEvents) {
        [lines addObject:ERCalendarEventDiagnosticLine(event, formatter, self.settings.calendarFocusTokens, self.settings.calendarAutoPauseTokens)];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (void)copyCalendarDiagnostic:(id)sender {
    NSString *text = [self calendarDiagnosticText];
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:text forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"日历诊断" detail:@"已复制真实日历诊断"];
    [self publishState];
}

- (void)refreshFocusModeState {
    NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
    self.frontmostAppBundleIdentifier = frontmost.bundleIdentifier;
    self.frontmostAppName = frontmost.localizedName;
    if (frontmost && frontmost.processIdentifier != NSProcessInfo.processInfo.processIdentifier) {
        self.lastExternalAppBundleIdentifier = frontmost.bundleIdentifier;
        self.lastExternalAppName = frontmost.localizedName;
    }
    [self refreshCalendarFocusStateIfNeeded:NO];
    self.presentationFocusActive = self.settings.autoFocusModeEnabled && self.settings.presentationFocusModeEnabled && ERPresentationModeDetected();

    BOOL ignored = NO;
    BOOL appPaused = NO;
    BOOL paused = NO;
    BOOL focused = NO;
    BOOL quietHours = NO;
    if (self.settings.autoFocusModeEnabled) {
        ignored = ERApplicationMatchesFocusTokens(self.frontmostAppBundleIdentifier, self.frontmostAppName, self.settings.ignoreAppTokens);
        if (!ignored) {
            appPaused = ERApplicationMatchesFocusTokens(self.frontmostAppBundleIdentifier, self.frontmostAppName, self.settings.autoPauseAppTokens);
            paused = appPaused || self.calendarAutoPauseActive;
            quietHours = [self isQuietHoursActiveNow];
            focused = !paused && (quietHours || self.presentationFocusActive || self.calendarFocusActive || ERApplicationMatchesFocusTokens(self.frontmostAppBundleIdentifier, self.frontmostAppName, self.settings.focusAppTokens));
        }
    }
    BOOL shouldRecordAutoPauseStart = paused && !self.paused && !self.autoPauseActive && !self.autoPauseSessionActive;
    BOOL shouldRecordAutoPauseEnd = !paused && self.autoPauseActive;
    if (shouldRecordAutoPauseStart) {
        self.todayAutoPauseSessions += 1;
        self.autoPauseSessionActive = YES;
        [self saveTodayStats];
    } else if (shouldRecordAutoPauseEnd) {
        self.autoPauseSessionActive = NO;
    }
    self.autoIgnoreActive = ignored;
    self.appAutoPauseActive = appPaused;
    self.quietHoursActive = quietHours;
    self.autoPauseActive = paused;
    if (ignored || !self.settings.autoFocusModeEnabled) {
        self.presentationFocusActive = NO;
        self.calendarFocusActive = NO;
        self.calendarAutoPauseActive = NO;
        self.quietHoursActive = NO;
    }
    self.autoFocusActive = focused;
    if (shouldRecordAutoPauseStart) {
        NSDictionary<NSString *, NSString *> *policy = [self automationPolicyExplanation];
        [self recordAutomationAction:@"自动暂停开始" reason:policy[@"reason"]];
    } else if (shouldRecordAutoPauseEnd) {
        [self recordAutomationAction:@"自动暂停结束" reason:@"恢复正常计时"];
    }
    [self.settingsWindowController refreshAutomationStatus];
}

- (void)shiftReminderDatesBySeconds:(NSTimeInterval)seconds {
    for (NSString *key in @[@"eyeDueAt", @"eyeRestEndsAt", @"standDueAt", @"standRestEndsAt"]) {
        NSDate *date = [self valueForKey:key];
        if (date) [self setValue:[date dateByAddingTimeInterval:seconds] forKey:key];
    }
}

- (BOOL)isQuietHoursActiveNow {
    return ERQuietHoursContainsMinute(self.settings.quietHoursEnabled,
                                      self.settings.quietHoursStartMinute,
                                      self.settings.quietHoursEndMinute,
                                      ERCurrentMinuteOfDay());
}

- (BOOL)isLightDistractionModeActive {
    return self.focusModeEnabled || self.autoFocusActive;
}

- (void)recordAutomationAction:(NSString *)action reason:(NSString *)reason {
    if (action.length == 0) return;
    NSString *detail = reason.length > 0 ? [NSString stringWithFormat:@"%@ · %@", action, reason] : action;
    self.lastAutomationActionText = detail;
    self.lastAutomationActionAt = NSDate.date;
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    [defaults setObject:detail forKey:ERLastAutomationActionTextKey];
    [defaults setObject:self.lastAutomationActionAt forKey:ERLastAutomationActionAtKey];
    [self.settingsWindowController refreshAutomationStatus];
}

- (NSString *)lastAutomationActionSummary {
    if (self.lastAutomationActionText.length == 0) {
        return @"最近动作：暂无记录";
    }
    NSString *time = self.lastAutomationActionAt ? ERFormatClockTime(self.lastAutomationActionAt) : @"未知时间";
    return [NSString stringWithFormat:@"最近动作：%@ · %@", time, self.lastAutomationActionText];
}

- (NSString *)focusModeStatusText {
    if (!self.settings.autoFocusModeEnabled) {
        return @"自动轻打扰已关闭。";
    }
    NSString *name = self.frontmostAppName.length > 0 ? self.frontmostAppName : @"当前应用";
    NSString *bundle = self.frontmostAppBundleIdentifier.length > 0 ? self.frontmostAppBundleIdentifier : @"未识别 bundle id";
    if (self.autoIgnoreActive) {
        return [NSString stringWithFormat:@"不处理：%@ · %@", name, bundle];
    }
    if (self.autoPauseActive) {
        if (self.calendarAutoPauseActive && !self.appAutoPauseActive) {
            NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前日程";
            return [NSString stringWithFormat:@"日程暂停：%@", eventTitle];
        }
        return [NSString stringWithFormat:@"自动暂停：%@ · %@", name, bundle];
    }
    if (self.presentationFocusActive) {
        return @"全屏/演示：只发通知";
    }
    if (self.quietHoursActive) {
        return [NSString stringWithFormat:@"安静时段：%@-%@ · 只发通知",
                ERFormatClockMinute(self.settings.quietHoursStartMinute),
                ERFormatClockMinute(self.settings.quietHoursEndMinute)];
    }
    if (self.calendarFocusActive) {
        NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前会议";
        return [NSString stringWithFormat:@"日历会议：%@ · 只发通知", eventTitle];
    }
    if (self.autoFocusActive) {
        return [NSString stringWithFormat:@"只发通知：%@ · %@", name, bundle];
    }
    return [NSString stringWithFormat:@"当前：%@ · %@", name, bundle];
}

- (NSDictionary<NSString *, NSString *> *)automationPolicyExplanation {
    NSString *name = self.frontmostAppName.length > 0 ? self.frontmostAppName : @"当前应用";
    NSString *bundle = self.frontmostAppBundleIdentifier.length > 0 ? self.frontmostAppBundleIdentifier : @"未识别 bundle id";
    NSString *action = @"正常提醒";
    NSString *reason = [NSString stringWithFormat:@"%@ · %@", name, bundle];
    NSString *suggestion = @"到点会按设置弹出休息页并发送通知。";

    if (!self.settings.autoFocusModeEnabled) {
        action = @"正常提醒";
        reason = @"自动策略已关闭";
        suggestion = @"需要会议、演示或视频时降打扰，可以开启自动策略。";
    } else if (self.autoIgnoreActive) {
        action = @"正常提醒";
        reason = [NSString stringWithFormat:@"忽略策略命中：%@ · %@", name, bundle];
        suggestion = @"此应用会跳过自动策略；若命中不对，可编辑策略关键词。";
    } else if (self.autoPauseActive) {
        action = @"自动暂停";
        if (self.calendarAutoPauseActive && !self.appAutoPauseActive) {
            NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前日程";
            reason = [NSString stringWithFormat:@"日程暂停关键词命中：%@", eventTitle];
            suggestion = @"计时会顺延且不弹休息页；可在日程策略里调整暂停关键词。";
        } else {
            reason = [NSString stringWithFormat:@"自动暂停应用命中：%@ · %@", name, bundle];
            suggestion = @"计时会顺延且不弹休息页；若暂停过多，可移出自动暂停关键词。";
        }
    } else if (self.focusModeEnabled) {
        action = @"只发通知";
        reason = @"手动轻打扰已开启";
        suggestion = @"休息页不会弹出；结束专注后可在菜单栏关闭轻打扰。";
    } else if (self.presentationFocusActive) {
        action = @"只发通知";
        reason = @"检测到全屏/演示状态";
        suggestion = @"退出全屏或关闭演示联动后会恢复正常弹窗。";
    } else if (self.quietHoursActive) {
        action = @"只发通知";
        reason = [NSString stringWithFormat:@"安静时段命中：%@-%@",
                  ERFormatClockMinute(self.settings.quietHoursStartMinute),
                  ERFormatClockMinute(self.settings.quietHoursEndMinute)];
        suggestion = @"固定时段内不会弹全屏休息页；可调整开始和结束时间。";
    } else if (self.calendarFocusActive) {
        NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前会议";
        action = @"只发通知";
        reason = [NSString stringWithFormat:@"日历会议命中：%@", eventTitle];
        suggestion = @"会议中只保留通知；若误命中，可编辑日程关键词或关闭日历会议。";
    } else if (self.autoFocusActive) {
        action = @"只发通知";
        reason = [NSString stringWithFormat:@"轻打扰应用命中：%@ · %@", name, bundle];
        suggestion = @"当前应用在轻打扰列表里；若希望弹窗，可移出轻打扰关键词。";
    }

    NSString *diagnostic = [NSString stringWithFormat:@"最终动作：%@\n命中原因：%@\n最近动作：%@\n建议下一步：%@",
                            action,
                            reason,
                            [self lastAutomationActionSummary],
                            suggestion];
    return @{
        @"action": action,
        @"reason": reason,
        @"lastAction": [self lastAutomationActionSummary],
        @"suggestion": suggestion,
        @"diagnostic": diagnostic
    };
}

- (void)workspaceDidWake:(NSNotification *)notification {
    [self refreshFocusModeState];
    [self repairRestOverlayAfterSystemEvent:notification];
}

- (void)workspaceWillSuspend:(NSNotification *)notification {
    self.recoveryFollowUpGeneration += 1;
    [self noteRecoveryEventTitle:ERSystemEventTitle(notification.name) detail:@"已隐藏休息窗口，等待恢复检查"];
    if (self.restWindowController) {
        [self.restWindowController.window orderOut:nil];
    }
    [self publishState];
}

- (void)screenParametersChanged:(NSNotification *)notification {
    NSString *previousSummary = self.lastScreenDiagnosticSummary.length > 0 ? self.lastScreenDiagnosticSummary : @"未知";
    NSString *currentSummary = ERScreenDiagnosticSummary();
    self.lastDisplayChangePreviousSummary = previousSummary;
    self.lastDisplayChangeCurrentSummary = currentSummary;
    self.lastDisplayChangeAt = NSDate.date;
    self.lastScreenDiagnosticSummary = currentSummary;
    [self repairRestOverlayAfterSystemEvent:notification];
}

- (void)calendarStoreChanged:(NSNotification *)notification {
    [self refreshCalendarFocusStateIfNeeded:YES];
    [self repairRestStateIfNeeded];
    [self publishState];
}

- (void)activeSpaceDidChange:(NSNotification *)notification {
    [self refreshFocusModeState];
    [self repairRestStateIfNeeded];
    [self publishState];
}

- (void)frontmostApplicationDidChange:(NSNotification *)notification {
    [self refreshFocusModeState];
    NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
    BOOL switchedAwayFromRest = self.restWindowController &&
        self.restWindowController.window.visible &&
        !self.settings.restWindowTopmost &&
        frontmost &&
        frontmost.processIdentifier != NSProcessInfo.processInfo.processIdentifier;
    if (switchedAwayFromRest) {
        [self yieldRestOverlayForUserFocusChange];
    }
    [self repairRestStateIfNeeded];
    [self publishState];
}

- (void)applicationDidResignActive:(NSNotification *)notification {
    [self normalizeWindowLevelsForCurrentSettings];
    [self demoteSettingsWindowAfterResignActive];
    if (self.restWindowController && self.restWindowController.window.visible && !self.settings.restWindowTopmost) {
        [self yieldRestOverlayForUserFocusChange];
    }
}

- (void)normalizeWindowLevelsForCurrentSettings {
    NSWindow *settingsWindow = self.settingsWindowController.window;
    if (settingsWindow) {
        settingsWindow.level = NSNormalWindowLevel;
        settingsWindow.collectionBehavior = NSWindowCollectionBehaviorManaged;
    }
    if (self.restWindowController) {
        [self.restWindowController applyWindowLevelForSettings:self.settings];
    }
}

- (void)demoteSettingsWindowAfterResignActive {
    NSWindow *settingsWindow = self.settingsWindowController.window;
    if (!settingsWindow || !settingsWindow.visible) return;
    settingsWindow.level = NSNormalWindowLevel;
    settingsWindow.collectionBehavior = NSWindowCollectionBehaviorManaged;
    [settingsWindow orderBack:nil];
}

- (void)repairRestOverlayAfterDisplayChange {
    [self repairRestOverlayAfterSystemEvent:nil];
}

- (BOOL)repairSettingsWindowAfterDisplayChange {
    NSWindow *settingsWindow = self.settingsWindowController.window;
    if (!settingsWindow) return NO;

    settingsWindow.level = NSNormalWindowLevel;
    settingsWindow.collectionBehavior = NSWindowCollectionBehaviorManaged;

    NSScreen *screen = settingsWindow.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    if (!screen) return NO;

    BOOL intersectsAnyScreen = NO;
    for (NSScreen *candidate in NSScreen.screens) {
        if (NSIntersectsRect(settingsWindow.frame, candidate.visibleFrame)) {
            intersectsAnyScreen = YES;
            screen = candidate;
            break;
        }
    }

    NSRect visibleFrame = screen.visibleFrame;
    NSRect frame = settingsWindow.frame;
    CGFloat width = MIN(frame.size.width, visibleFrame.size.width);
    CGFloat height = MIN(frame.size.height, visibleFrame.size.height);
    CGFloat x = frame.origin.x;
    CGFloat y = frame.origin.y;
    if (!intersectsAnyScreen) {
        x = NSMidX(visibleFrame) - width / 2.0;
        y = NSMidY(visibleFrame) - height / 2.0;
    }
    x = MIN(NSMaxX(visibleFrame) - width, MAX(NSMinX(visibleFrame), x));
    y = MIN(NSMaxY(visibleFrame) - height, MAX(NSMinY(visibleFrame), y));

    NSRect repairedFrame = NSIntegralRect(NSMakeRect(x, y, width, height));
    BOOL changed = !NSEqualRects(NSIntegralRect(settingsWindow.frame), repairedFrame);
    if (changed) {
        [settingsWindow setFrame:repairedFrame display:YES animate:NO];
    }
    return changed;
}

- (void)repairRestOverlayAfterSystemEvent:(NSNotification *)notification {
    NSString *eventTitle = notification ? ERSystemEventTitle(notification.name) : @"显示恢复";
    NSDate *now = NSDate.date;
    NSMutableArray<NSString *> *details = [NSMutableArray array];
    if (self.eyeResting && self.eyeRestEndsAt && [self.eyeRestEndsAt timeIntervalSinceDate:now] <= 0) {
        [details addObject:@"结算眼睛休息"];
    }
    if (self.standResting && self.standRestEndsAt && [self.standRestEndsAt timeIntervalSinceDate:now] <= 0) {
        [details addObject:@"结算站立休息"];
    }

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    BOOL settingsWindowRepaired = [self repairSettingsWindowAfterDisplayChange];
    if (settingsWindowRepaired) {
        [details addObject:@"设置页回到屏幕内"];
    }
    NSInteger orphaned = [self closeOrphanRestWindows];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"关闭残留窗口 %ld 个", (long)orphaned]];
    }
    if (self.paused) {
        [details addObject:@"暂停中，不显示休息页"];
    } else if ([self isLightDistractionModeActive]) {
        [details addObject:@"轻打扰中，不显示休息页"];
    } else if (self.restWindowController) {
        [details addObject:@"休息页已恢复"];
    } else if (details.count == 0) {
        [details addObject:@"状态正常"];
    }
    if ([eventTitle isEqualToString:@"屏幕变化"] && self.lastDisplayChangePreviousSummary.length > 0 && self.lastDisplayChangeCurrentSummary.length > 0) {
        [details addObject:[NSString stringWithFormat:@"屏幕 %@ -> %@", self.lastDisplayChangePreviousSummary, self.lastDisplayChangeCurrentSummary]];
    }
    [self noteRecoveryEventTitle:eventTitle detail:[details componentsJoinedByString:@"，"]];
    if (notification) {
        [self scheduleRecoveryFollowUpChecksWithTitle:eventTitle];
    }

    if (!self.restWindowController) {
        [self publishState];
        return;
    }
    if (self.restOverlayYielded && !self.settings.restWindowTopmost) {
        [self publishState];
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        [self settleExpiredRests];
        [self repairRestStateIfNeeded];
        if (!self.restWindowController || (self.restOverlayYielded && !self.settings.restWindowTopmost)) return;
        [self.restWindowController presentOverlay];
        [self noteRecoveryEventTitle:eventTitle detail:@"休息页已置前"];
        [self publishState];
    });
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self settleExpiredRests];
        [self repairRestStateIfNeeded];
        if (!self.restWindowController || (self.restOverlayYielded && !self.settings.restWindowTopmost)) return;
        [self.restWindowController presentOverlay];
        [self noteRecoveryEventTitle:eventTitle detail:@"休息页二次校准完成"];
        [self publishState];
    });
}

- (void)scheduleRecoveryFollowUpChecksWithTitle:(NSString *)eventTitle {
    self.recoveryFollowUpGeneration += 1;
    NSUInteger generation = self.recoveryFollowUpGeneration;
    NSArray<NSNumber *> *delays = @[@1.0, @3.0, @8.0];
    NSInteger total = delays.count;
    NSString *title = eventTitle.length > 0 ? eventTitle : @"系统恢复";

    for (NSInteger index = 0; index < total; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runRecoveryFollowUpCheckWithTitle:title pass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runRecoveryFollowUpCheckWithTitle:(NSString *)eventTitle pass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.recoveryFollowUpGeneration) return;

    [self refreshFocusModeState];
    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];
    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"第 %ld/%ld 次复查", (long)pass, (long)total]];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"关闭残留窗口 %ld 个", (long)orphaned]];
    }
    if (self.paused) {
        [details addObject:@"暂停中"];
    } else if ([self isLightDistractionModeActive]) {
        [details addObject:@"轻打扰中"];
    } else if (self.restWindowController && (!self.restOverlayYielded || self.settings.restWindowTopmost)) {
        [self.restWindowController presentOverlay];
        [details addObject:@"休息页已校准"];
    } else if (self.restOverlayYielded) {
        [details addObject:@"休息页已让开"];
    } else {
        [details addObject:@"状态正常"];
    }

    [self noteRecoveryEventTitle:eventTitle detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return NO;
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)sender hasVisibleWindows:(BOOL)flag {
    [self openSettings:nil];
    return YES;
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

    NSMenuItem *standAdvice = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    standAdvice.tag = 109;
    standAdvice.enabled = NO;
    standAdvice.hidden = YES;
    [self.menu addItem:standAdvice];

    NSMenuItem *todayStats = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    todayStats.tag = 106;
    todayStats.enabled = NO;
    [self.menu addItem:todayStats];

    NSMenuItem *recoveryStatus = [[NSMenuItem alloc] initWithTitle:@"" action:nil keyEquivalent:@""];
    recoveryStatus.tag = 108;
    recoveryStatus.enabled = NO;
    [self.menu addItem:recoveryStatus];

    NSMenu *diagnosticMenu = [[NSMenu alloc] initWithTitle:@"排查中心"];

    NSMenuItem *copyIssueBundleDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制问题反馈包" action:@selector(copyIssueBundleDiagnostic:) keyEquivalent:@""];
    copyIssueBundleDiagnostic.target = self;
    [diagnosticMenu addItem:copyIssueBundleDiagnostic];

    NSMenuItem *copyInstallGuide = [[NSMenuItem alloc] initWithTitle:@"复制安装更新说明" action:@selector(copyInstallGuide:) keyEquivalent:@""];
    copyInstallGuide.target = self;
    [diagnosticMenu addItem:copyInstallGuide];

    NSMenuItem *copySupportBundleDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制完整排查包" action:@selector(copySupportBundleDiagnostic:) keyEquivalent:@""];
    copySupportBundleDiagnostic.target = self;
    [diagnosticMenu addItem:copySupportBundleDiagnostic];

    NSMenuItem *copyRecoveryReportDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制恢复问题报告" action:@selector(copyRecoveryReportDiagnostic:) keyEquivalent:@""];
    copyRecoveryReportDiagnostic.target = self;
    [diagnosticMenu addItem:copyRecoveryReportDiagnostic];

    NSMenuItem *copyRecoveryMatrixDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制恢复场景矩阵" action:@selector(copyRecoveryMatrixDiagnostic:) keyEquivalent:@""];
    copyRecoveryMatrixDiagnostic.target = self;
    [diagnosticMenu addItem:copyRecoveryMatrixDiagnostic];

    [diagnosticMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *copyAppDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制应用诊断" action:@selector(copyApplicationDiagnostic:) keyEquivalent:@""];
    copyAppDiagnostic.target = self;
    [diagnosticMenu addItem:copyAppDiagnostic];

    NSMenuItem *copyRecovery = [[NSMenuItem alloc] initWithTitle:@"复制恢复诊断" action:@selector(copyRecoveryDiagnostic:) keyEquivalent:@""];
    copyRecovery.target = self;
    [diagnosticMenu addItem:copyRecovery];

    NSMenuItem *copyDisplayDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制显示环境诊断" action:@selector(copyDisplayDiagnostic:) keyEquivalent:@""];
    copyDisplayDiagnostic.target = self;
    [diagnosticMenu addItem:copyDisplayDiagnostic];

    NSMenuItem *calendarDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制真实日历诊断" action:@selector(copyCalendarDiagnostic:) keyEquivalent:@""];
    calendarDiagnostic.target = self;
    [diagnosticMenu addItem:calendarDiagnostic];

    NSMenuItem *automationDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制自动化诊断" action:@selector(copyAutomationDiagnostic:) keyEquivalent:@""];
    automationDiagnostic.target = self;
    [diagnosticMenu addItem:automationDiagnostic];

    [diagnosticMenu addItem:NSMenuItem.separatorItem];

    NSMenuItem *recoverySelfCheck = [[NSMenuItem alloc] initWithTitle:@"运行恢复自检" action:@selector(runRecoverySelfCheck:) keyEquivalent:@""];
    recoverySelfCheck.target = self;
    [diagnosticMenu addItem:recoverySelfCheck];

    NSMenuItem *recoveryMatrixSuite = [[NSMenuItem alloc] initWithTitle:@"运行恢复矩阵套件" action:@selector(runRecoveryMatrixSuite:) keyEquivalent:@""];
    recoveryMatrixSuite.target = self;
    [diagnosticMenu addItem:recoveryMatrixSuite];

    NSMenuItem *recoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行恢复压测" action:@selector(runRecoveryStressTest:) keyEquivalent:@""];
    recoveryStressTest.target = self;
    [diagnosticMenu addItem:recoveryStressTest];

    NSMenuItem *lunchRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行午休恢复压测" action:@selector(runLunchRecoveryStressTest:) keyEquivalent:@""];
    lunchRecoveryStressTest.target = self;
    [diagnosticMenu addItem:lunchRecoveryStressTest];

    NSMenuItem *sleepHiddenRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行睡眠隐藏恢复压测" action:@selector(runSleepHiddenRecoveryStressTest:) keyEquivalent:@""];
    sleepHiddenRecoveryStressTest.target = self;
    [diagnosticMenu addItem:sleepHiddenRecoveryStressTest];

    NSMenuItem *longAwayRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行长离开恢复压测" action:@selector(runLongAwayRecoveryStressTest:) keyEquivalent:@""];
    longAwayRecoveryStressTest.target = self;
    [diagnosticMenu addItem:longAwayRecoveryStressTest];

    NSMenuItem *displayRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行显示恢复压测" action:@selector(runDisplayRecoveryStressTest:) keyEquivalent:@""];
    displayRecoveryStressTest.target = self;
    [diagnosticMenu addItem:displayRecoveryStressTest];

    NSMenuItem *settingsWindowRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行设置窗口恢复压测" action:@selector(runSettingsWindowRecoveryStressTest:) keyEquivalent:@""];
    settingsWindowRecoveryStressTest.target = self;
    [diagnosticMenu addItem:settingsWindowRecoveryStressTest];

    NSMenuItem *displayBoundsStressTest = [[NSMenuItem alloc] initWithTitle:@"运行显示边界压测" action:@selector(runDisplayBoundsStressTest:) keyEquivalent:@""];
    displayBoundsStressTest.target = self;
    [diagnosticMenu addItem:displayBoundsStressTest];

    NSMenuItem *displayChangeTraceSelfCheck = [[NSMenuItem alloc] initWithTitle:@"运行显示变化追踪自检" action:@selector(runDisplayChangeTraceSelfCheck:) keyEquivalent:@""];
    displayChangeTraceSelfCheck.target = self;
    [diagnosticMenu addItem:displayChangeTraceSelfCheck];

    NSMenuItem *realDisplayCheck = [[NSMenuItem alloc] initWithTitle:@"运行真实显示环境自检" action:@selector(runRealDisplayCheck:) keyEquivalent:@""];
    realDisplayCheck.target = self;
    [diagnosticMenu addItem:realDisplayCheck];

    NSMenuItem *overlayYieldStressTest = [[NSMenuItem alloc] initWithTitle:@"运行窗口让开压测" action:@selector(runOverlayYieldStressTest:) keyEquivalent:@""];
    overlayYieldStressTest.target = self;
    [diagnosticMenu addItem:overlayYieldStressTest];

    NSMenuItem *windowLayerPolicyStressTest = [[NSMenuItem alloc] initWithTitle:@"运行窗口层级压测" action:@selector(runWindowLayerPolicyStressTest:) keyEquivalent:@""];
    windowLayerPolicyStressTest.target = self;
    [diagnosticMenu addItem:windowLayerPolicyStressTest];

    NSMenuItem *automationPolicyStressTest = [[NSMenuItem alloc] initWithTitle:@"运行自动化策略压测" action:@selector(runAutomationPolicyStressTest:) keyEquivalent:@""];
    automationPolicyStressTest.target = self;
    [diagnosticMenu addItem:automationPolicyStressTest];

    NSMenuItem *presentationPolicyStressTest = [[NSMenuItem alloc] initWithTitle:@"运行演示策略压测" action:@selector(runPresentationPolicyStressTest:) keyEquivalent:@""];
    presentationPolicyStressTest.target = self;
    [diagnosticMenu addItem:presentationPolicyStressTest];

    NSMenuItem *realPresentationPolicyCheck = [[NSMenuItem alloc] initWithTitle:@"运行真实演示联动自检" action:@selector(runRealPresentationPolicyCheck:) keyEquivalent:@""];
    realPresentationPolicyCheck.target = self;
    [diagnosticMenu addItem:realPresentationPolicyCheck];

    NSMenuItem *calendarPolicyStressTest = [[NSMenuItem alloc] initWithTitle:@"运行日历策略压测" action:@selector(runCalendarPolicyStressTest:) keyEquivalent:@""];
    calendarPolicyStressTest.target = self;
    [diagnosticMenu addItem:calendarPolicyStressTest];

    NSMenuItem *realCalendarPolicyCheck = [[NSMenuItem alloc] initWithTitle:@"运行真实日历联动自检" action:@selector(runRealCalendarPolicyCheck:) keyEquivalent:@""];
    realCalendarPolicyCheck.target = self;
    [diagnosticMenu addItem:realCalendarPolicyCheck];

    NSMenuItem *diagnosticGroup = [[NSMenuItem alloc] initWithTitle:@"排查中心" action:nil keyEquivalent:@""];
    diagnosticGroup.submenu = diagnosticMenu;
    [self.menu addItem:diagnosticGroup];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"打开设置..." action:@selector(openSettings:) keyEquivalent:@","];
    settings.target = self;
    [self.menu addItem:settings];

    NSMenuItem *quickSetup = [[NSMenuItem alloc] initWithTitle:@"快速配置..." action:@selector(showQuickSetup:) keyEquivalent:@""];
    quickSetup.target = self;
    [self.menu addItem:quickSetup];

    NSMenuItem *pause = [[NSMenuItem alloc] initWithTitle:@"暂停" action:@selector(togglePause:) keyEquivalent:@"p"];
    pause.target = self;
    pause.tag = 103;
    [self.menu addItem:pause];

    NSMenuItem *focusMode = [[NSMenuItem alloc] initWithTitle:@"工作模式：轻打扰" action:@selector(toggleFocusMode:) keyEquivalent:@"f"];
    focusMode.target = self;
    focusMode.tag = 107;
    [self.menu addItem:focusMode];

    NSMenu *automationURLMenu = [[NSMenu alloc] initWithTitle:@"复制自动化链接"];
    NSArray<NSArray<NSString *> *> *automationURLs = @[
        @[@"轻打扰开启", ERAutomationURLString(@"focus/on")],
        @[@"轻打扰关闭", ERAutomationURLString(@"focus/off")],
        @[@"轻打扰切换", ERAutomationURLString(@"focus/toggle")],
        @[@"打开设置", ERAutomationURLString(@"settings")],
        @[@"打开眼睛设置", ERAutomationURLString(@"settings/eye")],
        @[@"打开站立设置", ERAutomationURLString(@"settings/stand")],
        @[@"快速配置：均衡护眼", ERAutomationURLString(@"setup/balanced")],
        @[@"快速配置：番茄专注", ERAutomationURLString(@"setup/pomodoro")],
        @[@"快速配置：久坐打断", ERAutomationURLString(@"setup/stand")],
        @[@"快速配置：调试", ERAutomationURLString(@"setup/debug")],
        @[@"立即眼睛休息", ERAutomationURLString(@"rest/eye")],
        @[@"立即站立", ERAutomationURLString(@"rest/stand")],
        @[@"快速节奏：20-20-20", ERAutomationURLString(@"rhythm/202020")],
        @[@"快速节奏：番茄", ERAutomationURLString(@"rhythm/pomodoro")],
        @[@"快速节奏：调试", ERAutomationURLString(@"rhythm/debug")],
        @[@"暂停 30 分钟", ERAutomationURLString(@"pause/30m")],
        @[@"继续提醒", ERAutomationURLString(@"resume")],
        @[@"恢复 JSON", ERAutomationURLString(@"backup/import")],
        @[@"运行恢复压测", ERAutomationURLString(@"diagnostics/recovery-stress")],
        @[@"运行午休恢复压测", ERAutomationURLString(@"diagnostics/lunch-recovery")],
        @[@"运行睡眠隐藏恢复压测", ERAutomationURLString(@"diagnostics/sleep-hidden-recovery")],
        @[@"运行长离开恢复压测", ERAutomationURLString(@"diagnostics/long-away-recovery")],
        @[@"运行显示恢复压测", ERAutomationURLString(@"diagnostics/display-recovery")],
        @[@"运行设置窗口恢复压测", ERAutomationURLString(@"diagnostics/settings-window")],
        @[@"运行显示边界压测", ERAutomationURLString(@"diagnostics/display-bounds")],
        @[@"复制显示环境诊断", ERAutomationURLString(@"diagnostics/display-real")],
        @[@"复制恢复场景矩阵", ERAutomationURLString(@"diagnostics/recovery-matrix")],
        @[@"复制恢复问题报告", ERAutomationURLString(@"diagnostics/recovery-report")],
        @[@"复制问题反馈包", ERAutomationURLString(@"diagnostics/issue-bundle")],
        @[@"复制完整排查包", ERAutomationURLString(@"diagnostics/support-bundle")],
        @[@"复制路线图状态", ERAutomationURLString(@"diagnostics/roadmap-status")],
        @[@"复制自动更新评估", ERAutomationURLString(@"diagnostics/auto-update-readiness")],
        @[@"运行显示变化追踪自检", ERAutomationURLString(@"diagnostics/display-change-trace")],
        @[@"运行真实显示环境自检", ERAutomationURLString(@"diagnostics/display-live")],
        @[@"运行窗口让开压测", ERAutomationURLString(@"diagnostics/overlay-yield")],
        @[@"运行窗口层级压测", ERAutomationURLString(@"diagnostics/window-layer")],
        @[@"运行恢复矩阵套件", ERAutomationURLString(@"diagnostics/recovery-matrix-suite")],
        @[@"运行自动化策略压测", ERAutomationURLString(@"diagnostics/automation-policy")],
        @[@"运行演示策略压测", ERAutomationURLString(@"diagnostics/presentation-policy")],
        @[@"运行真实演示联动自检", ERAutomationURLString(@"diagnostics/presentation-live")],
        @[@"运行日历策略压测", ERAutomationURLString(@"diagnostics/calendar-policy")],
        @[@"运行真实日历联动自检", ERAutomationURLString(@"diagnostics/calendar-live")],
        @[@"复制真实日历诊断", ERAutomationURLString(@"diagnostics/calendar-real")]
    ];
    for (NSArray<NSString *> *itemInfo in automationURLs) {
        NSString *itemTitle = [itemInfo[0] hasPrefix:@"复制"] ? itemInfo[0] : [NSString stringWithFormat:@"复制%@", itemInfo[0]];
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:itemTitle
                                                      action:@selector(copyAutomationURL:)
                                               keyEquivalent:@""];
        item.target = self;
        item.representedObject = itemInfo[1];
        [automationURLMenu addItem:item];
    }
    NSMenuItem *automationURLGroup = [[NSMenuItem alloc] initWithTitle:@"复制自动化链接" action:nil keyEquivalent:@""];
    automationURLGroup.submenu = automationURLMenu;
    [self.menu addItem:automationURLGroup];

    NSMenuItem *automationTemplate = [[NSMenuItem alloc] initWithTitle:@"复制专注联动脚本" action:@selector(copyFocusAutomationTemplate:) keyEquivalent:@""];
    automationTemplate.target = self;
    [self.menu addItem:automationTemplate];

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

    NSMenu *quickRhythmMenu = [[NSMenu alloc] initWithTitle:@"快速节奏"];
    NSArray<NSArray *> *quickRhythms = @[
        @[@"20-20-20", @(20 * 60), @20, @(EREyeMode202020)],
        @[@"番茄 25/5", @(25 * 60), @(5 * 60), @(EREyeModePomodoro)],
        @[@"调试 10 秒", @10, @10, @(EREyeModeCustom)]
    ];
    for (NSArray *itemInfo in quickRhythms) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:itemInfo[0] action:@selector(applyQuickRhythm:) keyEquivalent:@""];
        item.target = self;
        item.representedObject = itemInfo;
        [quickRhythmMenu addItem:item];
    }
    NSMenuItem *quickRhythmGroup = [[NSMenuItem alloc] initWithTitle:@"快速节奏" action:nil keyEquivalent:@""];
    quickRhythmGroup.submenu = quickRhythmMenu;
    quickRhythmGroup.tag = 111;
    [self.menu addItem:quickRhythmGroup];

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

    NSMenuItem *emergencyClose = [[NSMenuItem alloc] initWithTitle:@"应急关闭休息页" action:@selector(emergencyCloseRestOverlay:) keyEquivalent:@"\x1b"];
    emergencyClose.target = self;
    [self.menu addItem:emergencyClose];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *notifications = [[NSMenuItem alloc] initWithTitle:@"系统通知" action:@selector(toggleNotifications:) keyEquivalent:@""];
    notifications.target = self;
    notifications.tag = 104;
    [self.menu addItem:notifications];

    NSMenuItem *window = [[NSMenuItem alloc] initWithTitle:@"提醒窗口" action:@selector(toggleRestWindow:) keyEquivalent:@""];
    window.target = self;
    window.tag = 105;
    [self.menu addItem:window];

    NSMenuItem *topmostWindow = [[NSMenuItem alloc] initWithTitle:@"置顶强提醒" action:@selector(toggleRestWindowTopmost:) keyEquivalent:@""];
    topmostWindow.target = self;
    topmostWindow.tag = 110;
    [self.menu addItem:topmostWindow];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *about = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"关于 %@...", ERBrandName] action:@selector(showAbout:) keyEquivalent:@""];
    about.target = self;
    [self.menu addItem:about];

    NSMenuItem *update = [[NSMenuItem alloc] initWithTitle:@"检查更新..." action:@selector(checkForUpdates:) keyEquivalent:@""];
    update.target = self;
    [self.menu addItem:update];

    NSMenuItem *distributionPlan = [[NSMenuItem alloc] initWithTitle:@"复制分发维护方案" action:@selector(copyDistributionPlan:) keyEquivalent:@""];
    distributionPlan.target = self;
    [self.menu addItem:distributionPlan];

    NSMenuItem *roadmapStatus = [[NSMenuItem alloc] initWithTitle:@"复制路线图状态" action:@selector(copyRoadmapStatus:) keyEquivalent:@""];
    roadmapStatus.target = self;
    [self.menu addItem:roadmapStatus];

    NSMenuItem *autoUpdateReadiness = [[NSMenuItem alloc] initWithTitle:@"复制自动更新评估" action:@selector(copyAutoUpdateReadiness:) keyEquivalent:@""];
    autoUpdateReadiness.target = self;
    [self.menu addItem:autoUpdateReadiness];

    NSMenuItem *feedback = [[NSMenuItem alloc] initWithTitle:@"反馈问题..." action:@selector(openIssueFeedback:) keyEquivalent:@""];
    feedback.target = self;
    [self.menu addItem:feedback];

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
    self.restOverlayYielded = NO;
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
    [self refreshFocusModeState];
    if (self.pausedUntil && [self.pausedUntil timeIntervalSinceNow] <= 0) {
        [self resumeFromPause];
    }
    if (!self.paused && !self.autoPauseActive) {
        [self evaluateReminderKind:ERReminderKindEye];
        [self evaluateReminderKind:ERReminderKindStand];
        [self repairRestStateIfNeeded];
    } else if (!self.paused && self.autoPauseActive) {
        [self shiftReminderDatesBySeconds:1];
        self.todayAutoPauseSeconds += 1;
        [self saveTodayStats];
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
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
    if (!self.settings.showRestWindow || [self isLightDistractionModeActive] || remaining <= 0) return;
    if (self.restOverlayYielded && !self.settings.restWindowTopmost) return;
    [self.restWindowController close];
    self.restWindowController = [[ERRestWindowController alloc] initWithAppDelegate:self];
    [self.restWindowController configureForKind:kind
                                       settings:self.settings
                                       duration:[self configuredRestDurationForKind:kind]];
    [self.restWindowController updateRemaining:remaining];
    [self.restWindowController presentOverlay];
}

- (void)repairRestStateIfNeeded {
    if (self.paused) {
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        return;
    }

    [self closeOrphanRestWindows];

    if (self.autoPauseActive) {
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        return;
    }

    [self settleExpiredRests];

    if ([self isLightDistractionModeActive] && self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }

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

    if (!self.settings.showRestWindow || [self isLightDistractionModeActive]) {
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        return;
    }

    if (self.restOverlayYielded && !self.settings.restWindowTopmost) {
        if (self.restWindowController.window.visible) {
            [self.restWindowController.window orderOut:nil];
        }
        return;
    }

    if (self.restWindowController && ![self.restWindowController hasHealthyActionBindings]) {
        [self.restWindowController close];
        self.restWindowController = nil;
        [self noteRecoveryEventTitle:@"窗口自检" detail:@"休息页按钮链路异常，已重建"];
    }

    if (!self.restWindowController || self.restWindowController.kind != activeKind) {
        [self ensureRestWindowForKind:activeKind remaining:remaining];
        return;
    }

    [self.restWindowController updateRemaining:remaining];
    NSWindow *restWindow = self.restWindowController.window;
    NSScreen *restScreen = restWindow.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSRect expectedFrame = restScreen ? restScreen.frame : NSMakeRect(0, 0, 1280, 800);
    BOOL frameMismatch = restWindow.screen && !NSEqualRects(NSIntegralRect(restWindow.frame), NSIntegralRect(expectedFrame));
    if (!restWindow.visible || !restWindow.screen || frameMismatch) {
        [self.restWindowController presentOverlay];
        if (frameMismatch) {
            [self noteRecoveryEventTitle:@"窗口自检" detail:@"休息页尺寸不匹配当前屏幕，已重新贴合"];
        }
    }
    [self closeOrphanRestWindows];
}

- (NSInteger)closeOrphanRestWindows {
    NSWindow *activeWindow = self.restWindowController.window;
    NSInteger closed = 0;
    for (NSWindow *window in [NSApp.windows copy]) {
        if (window == activeWindow) continue;
        if ([window.identifier isEqualToString:ERRestOverlayWindowIdentifier]) {
            [window close];
            closed += 1;
        }
    }
    return closed;
}

- (void)noteRecoveryEventTitle:(NSString *)title detail:(NSString *)detail {
    NSDate *now = NSDate.date;
    NSString *eventTitle = title.length > 0 ? title : @"系统事件";
    NSString *eventDetail = detail.length > 0 ? detail : @"状态正常";
    self.lastSystemEventAt = now;
    self.lastSystemEventTitle = eventTitle;
    self.lastRecoveryDetail = eventDetail;
    if (!self.recoveryEventHistory) {
        self.recoveryEventHistory = [NSMutableArray array];
    }
    [self.recoveryEventHistory insertObject:@{
        @"time": now,
        @"title": eventTitle,
        @"detail": eventDetail
    } atIndex:0];
    while (self.recoveryEventHistory.count > ERRecoveryHistoryLimit) {
        [self.recoveryEventHistory removeLastObject];
    }
    [self saveRecoveryHistory];
}

- (NSString *)recoveryDiagnosticText {
    if (!self.lastSystemEventAt) {
        return @"最近恢复：暂无记录";
    }
    NSString *historySuffix = self.recoveryEventHistory.count > 1
        ? [NSString stringWithFormat:@" · %ld 条", (long)self.recoveryEventHistory.count]
        : @"";
    return [NSString stringWithFormat:@"最近恢复：%@ %@ · %@%@",
            ERFormatClockTime(self.lastSystemEventAt),
            self.lastSystemEventTitle ?: @"系统事件",
            self.lastRecoveryDetail ?: @"状态正常",
            historySuffix];
}

- (NSArray<NSString *> *)recoveryHistoryLines {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *entry in self.recoveryEventHistory) {
        NSDate *time = [entry[@"time"] isKindOfClass:NSDate.class] ? entry[@"time"] : nil;
        NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"系统事件";
        NSString *detail = [entry[@"detail"] isKindOfClass:NSString.class] ? entry[@"detail"] : @"状态正常";
        [lines addObject:[NSString stringWithFormat:@"%@ %@ · %@",
                          ERFormatClockTime(time),
                          title,
                          detail]];
    }
    if (lines.count == 0) {
        [lines addObject:@"暂无恢复事件"];
    }
    return lines;
}

- (BOOL)recoveryHistoryContainsAny:(NSArray<NSString *> *)needles {
    if (needles.count == 0 || self.recoveryEventHistory.count == 0) return NO;
    for (NSDictionary<NSString *, id> *entry in self.recoveryEventHistory) {
        NSString *title = [entry[@"title"] isKindOfClass:NSString.class] ? entry[@"title"] : @"";
        NSString *detail = [entry[@"detail"] isKindOfClass:NSString.class] ? entry[@"detail"] : @"";
        NSString *combined = [NSString stringWithFormat:@"%@ %@", title, detail];
        for (NSString *needle in needles) {
            if (needle.length > 0 && [combined containsString:needle]) {
                return YES;
            }
        }
    }
    return NO;
}

- (NSString *)recoveryWindowDiagnosticLine {
    NSInteger orphaned = 0;
    for (NSWindow *window in NSApp.windows) {
        if ([window.identifier isEqualToString:ERRestOverlayWindowIdentifier] && window != self.restWindowController.window) {
            orphaned += 1;
        }
    }

    NSString *restWindowState = @"无";
    if (self.restWindowController) {
        NSMutableArray<NSString *> *parts = [NSMutableArray array];
        [parts addObject:self.restWindowController.window.visible ? @"可见" : @"不可见"];
        [parts addObject:self.restWindowController.window.screen ? @"有屏幕" : @"无屏幕"];
        [parts addObject:[self.restWindowController hasHealthyActionBindings] ? @"按钮正常" : @"按钮异常"];
        [parts addObject:[NSString stringWithFormat:@"level %ld", (long)self.restWindowController.window.level]];
        [parts addObject:[NSString stringWithFormat:@"behavior %lu", (unsigned long)self.restWindowController.window.collectionBehavior]];
        [parts addObject:[NSString stringWithFormat:@"key %@ main %@",
                          self.restWindowController.window.keyWindow ? @"YES" : @"NO",
                          self.restWindowController.window.mainWindow ? @"YES" : @"NO"]];
        restWindowState = [parts componentsJoinedByString:@"/"];
    }

    return [NSString stringWithFormat:@"窗口诊断：休息页 %@ · 已让开 %@ · app 窗口 %ld · 残留休息页 %ld · 屏幕 %ld",
            restWindowState,
            self.restOverlayYielded ? @"YES" : @"NO",
            (long)NSApp.windows.count,
            (long)orphaned,
            (long)NSScreen.screens.count];
}

- (NSString *)restOverlayViewDiagnosticLine {
    if (!self.restWindowController) return @"休息页视图：无";
    NSView *content = self.restWindowController.window.contentView;
    NSView *card = self.restWindowController.focusCard;
    NSRect contentFrame = content ? content.frame : NSZeroRect;
    NSRect cardFrame = card ? card.frame : NSZeroRect;
    NSInteger cardMotifLayers = 0;
    for (CALayer *layer in card.layer.sublayers) {
        if ([layer.name hasPrefix:@"rest-card-motif"]) {
            cardMotifLayers += 1;
        }
    }
    NSInteger backdropMotifLayers = 0;
    for (CALayer *layer in content.layer.sublayers) {
        if ([layer.name hasPrefix:@"rest-backdrop-motif"] || [layer.name isEqualToString:@"restBackdropGradient"]) {
            backdropMotifLayers += 1;
        }
    }
    return [NSString stringWithFormat:@"休息页视图：content %.0fx%.0f subviews %ld layers %ld motifLayers %ld · card %@ %.0f,%.0f %.0fx%.0f hidden %@ alpha %.2f subviews %ld layers %ld motifLayers %ld",
            contentFrame.size.width,
            contentFrame.size.height,
            (long)content.subviews.count,
            (long)content.layer.sublayers.count,
            (long)backdropMotifLayers,
            card.superview == content ? @"in-content" : @"detached",
            cardFrame.origin.x,
            cardFrame.origin.y,
            cardFrame.size.width,
            cardFrame.size.height,
            card.hidden ? @"YES" : @"NO",
            card.alphaValue,
            (long)card.subviews.count,
            (long)card.layer.sublayers.count,
            (long)cardMotifLayers];
}

- (NSString *)detailedRecoveryDiagnosticText {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 恢复诊断", ERBrandName]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[self recoveryDiagnosticText]];
    [lines addObject:@"最近事件："];
    for (NSString *line in [self recoveryHistoryLines]) {
        [lines addObject:[NSString stringWithFormat:@"- %@", line]];
    }
    [lines addObject:[NSString stringWithFormat:@"眼睛：%@ · 下次/结束 %@",
                      self.eyeResting ? @"休息中" : (self.settings.eyeEnabled ? @"计时中" : @"已关闭"),
                      ERFormatDuration([self remainingUntil:(self.eyeResting ? self.eyeRestEndsAt : self.eyeDueAt)])]];
    [lines addObject:[NSString stringWithFormat:@"站立：%@ · 下次/结束 %@",
                      self.standResting ? @"站立中" : (self.settings.standEnabled ? @"计时中" : @"已关闭"),
                      ERFormatDuration([self remainingUntil:(self.standResting ? self.standRestEndsAt : self.standDueAt)])]];
    [lines addObject:[NSString stringWithFormat:@"休息页：%@ · 窗口数 %ld",
                      self.restWindowController ? (self.restWindowController.window.visible ? @"可见" : @"存在但不可见") : @"无",
                      (long)NSApp.windows.count]];
    [lines addObject:[self recoveryWindowDiagnosticLine]];
    [lines addObject:[self restOverlayViewDiagnosticLine]];
    [lines addObject:[NSString stringWithFormat:@"暂停/轻打扰：paused=%@ autoPause=%@ focus=%@ presentation=%@ quiet=%@ calendar=%@",
                      self.paused ? @"YES" : @"NO",
                      self.autoPauseActive ? @"YES" : @"NO",
                      (self.focusModeEnabled || self.autoFocusActive) ? @"YES" : @"NO",
                      self.presentationFocusActive ? @"YES" : @"NO",
                      self.quietHoursActive ? @"YES" : @"NO",
                      self.calendarFocusActive ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"前台应用：%@ · %@",
                      self.frontmostAppName.length > 0 ? self.frontmostAppName : @"未知",
                      self.frontmostAppBundleIdentifier.length > 0 ? self.frontmostAppBundleIdentifier : @"未知 bundle"]];
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)applicationDiagnosticText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSMutableArray<NSString *> *lines = [NSMutableArray array];

    [lines addObject:[NSString stringWithFormat:@"%@ 应用诊断", ERBrandName]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"版本：%@ (%@)", version, build]];
    [lines addObject:[NSString stringWithFormat:@"安装位置：%@", bundle.bundlePath ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"系统：%@", NSProcessInfo.processInfo.operatingSystemVersionString]];
    [lines addObject:[NSString stringWithFormat:@"屏幕：%ld", (long)NSScreen.screens.count]];
    [lines addObject:[NSString stringWithFormat:@"眼睛：%@ · %@ · 使用 %@ · 休息 %@ · 剩余 %@",
                      self.settings.eyeEnabled ? @"开启" : @"关闭",
                      EREyeModeTitle(self.settings.eyeMode),
                      ERFormatDuration(self.settings.eyeFocusSeconds),
                      ERFormatDuration(self.settings.eyeRestSeconds),
                      ERFormatDuration([self remainingUntil:(self.eyeResting ? self.eyeRestEndsAt : self.eyeDueAt)])]];
    [lines addObject:[NSString stringWithFormat:@"站立：%@ · 每隔 %@ · 站立 %@ · %@/%@ · 剩余 %@",
                      self.settings.standEnabled ? @"开启" : @"关闭",
                      ERFormatDuration(self.settings.standIntervalSeconds),
                      ERFormatDuration(self.settings.standDurationSeconds),
                      ERStandRoutineTitle(self.settings.standRoutine),
                      ERStandIntensityTitle(self.settings.standIntensity),
                      ERFormatDuration([self remainingUntil:(self.standResting ? self.standRestEndsAt : self.standDueAt)])]];
    [lines addObject:[NSString stringWithFormat:@"提醒：通知 %@ · 全屏提醒 %@ · 置顶强提醒 %@ · 菜单栏模式 %ld · 风格 %ld",
                      self.settings.notificationsEnabled ? @"开" : @"关",
                      self.settings.showRestWindow ? @"开" : @"关",
                      self.settings.restWindowTopmost ? @"开" : @"关",
                      (long)self.settings.menuBarMode,
                      (long)self.settings.restStyle]];
    [lines addObject:[NSString stringWithFormat:@"自动化：%@ · %@", [self focusModeStatusText], [self isLightDistractionModeActive] ? @"轻打扰中" : @"正常提醒"]];
    [lines addObject:[NSString stringWithFormat:@"前台应用：%@ · %@",
                      self.frontmostAppName.length > 0 ? self.frontmostAppName : @"未知",
                      self.frontmostAppBundleIdentifier.length > 0 ? self.frontmostAppBundleIdentifier : @"未知 bundle"]];
    [lines addObject:[NSString stringWithFormat:@"今日统计：眼睛 %ld · 站立 %ld · 稍后 %ld · 跳过 %ld · 只通知 %ld · 自动暂停 %@",
                      (long)self.todayEyeDone,
                      (long)self.todayStandDone,
                      (long)self.todaySnoozed,
                      (long)self.todaySkipped,
                      (long)self.todayNotificationOnly,
                      ERFormatDuration(self.todayAutoPauseSeconds)]];
    [lines addObject:[self recoveryWindowDiagnosticLine]];
    [lines addObject:[self restOverlayViewDiagnosticLine]];
    [lines addObject:[self recoveryDiagnosticText]];
    [lines addObject:@"最近恢复事件："];
    for (NSString *line in [self recoveryHistoryLines]) {
        [lines addObject:[NSString stringWithFormat:@"- %@", line]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)displayDiagnosticText {
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 显示环境诊断", ERBrandName]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"屏幕摘要：%@", ERScreenDiagnosticSummary()]];

    NSArray<NSScreen *> *screens = NSScreen.screens;
    [lines addObject:@"displayDiagnostic=1"];
    [lines addObject:[NSString stringWithFormat:@"screenCount=%ld", (long)screens.count]];
    [lines addObject:[NSString stringWithFormat:@"currentDisplaySummary=%@", ERScreenDiagnosticSummary()]];
    if (self.lastDisplayChangeAt && self.lastDisplayChangePreviousSummary.length > 0 && self.lastDisplayChangeCurrentSummary.length > 0) {
        [lines addObject:[NSString stringWithFormat:@"上次屏幕变化：%@", ERFormatClockTime(self.lastDisplayChangeAt)]];
        [lines addObject:[NSString stringWithFormat:@"变化前：%@", self.lastDisplayChangePreviousSummary]];
        [lines addObject:[NSString stringWithFormat:@"变化后：%@", self.lastDisplayChangeCurrentSummary]];
        [lines addObject:[NSString stringWithFormat:@"displayChangeFrom=%@", self.lastDisplayChangePreviousSummary]];
        [lines addObject:[NSString stringWithFormat:@"displayChangeTo=%@", self.lastDisplayChangeCurrentSummary]];
    } else {
        [lines addObject:@"上次屏幕变化：暂无"];
        [lines addObject:@"displayChangeFrom=none"];
        [lines addObject:@"displayChangeTo=none"];
    }
    for (NSInteger index = 0; index < screens.count; index++) {
        NSScreen *screen = screens[index];
        NSRect frame = screen.frame;
        NSRect visible = screen.visibleFrame;
        CGFloat scale = screen.backingScaleFactor;
        NSDictionary<NSDeviceDescriptionKey, id> *deviceDescription = screen.deviceDescription;
        id screenNumber = deviceDescription[@"NSScreenNumber"];
        [lines addObject:[NSString stringWithFormat:@"屏幕 %ld：%@frame %.0f,%.0f %.0fx%.0f · visible %.0f,%.0f %.0fx%.0f · scale %.1f · id %@",
                          (long)index + 1,
                          screen == NSScreen.mainScreen ? @"主屏 · " : @"",
                          frame.origin.x,
                          frame.origin.y,
                          frame.size.width,
                          frame.size.height,
                          visible.origin.x,
                          visible.origin.y,
                          visible.size.width,
                          visible.size.height,
                          scale,
                          screenNumber ?: @"未知"]];
    }
    if (screens.count == 0) {
        [lines addObject:@"屏幕：未读取到 NSScreen"];
    }

    NSWindow *restWindow = self.restWindowController.window;
    [lines addObject:[NSString stringWithFormat:@"restWindow=%@", restWindow ? @"present" : @"none"]];
    if (restWindow) {
        NSRect frame = restWindow.frame;
        NSRect contentFrame = restWindow.contentView.frame;
        NSRect screenFrame = restWindow.screen ? restWindow.screen.frame : NSZeroRect;
        [lines addObject:[NSString stringWithFormat:@"休息页窗口：%@ · %@ · frame %.0f,%.0f %.0fx%.0f · content %.0fx%.0f · level %ld · behavior %lu · %@ · %@",
                          restWindow.visible ? @"可见" : @"不可见",
                          restWindow.screen ? @"有屏幕" : @"无屏幕",
                          frame.origin.x,
                          frame.origin.y,
                          frame.size.width,
                          frame.size.height,
                          contentFrame.size.width,
                          contentFrame.size.height,
                          (long)restWindow.level,
                          (unsigned long)restWindow.collectionBehavior,
                          restWindow.screen ? (NSEqualRects(NSIntegralRect(frame), NSIntegralRect(screenFrame)) ? @"贴合屏幕" : @"未贴合屏幕") : @"无法判断贴合",
                          [self.restWindowController hasHealthyActionBindings] ? @"按钮正常" : @"按钮异常"]];
    } else {
        [lines addObject:@"休息页窗口：无"];
    }

    NSWindow *settingsWindow = self.settingsWindowController.window;
    [lines addObject:[NSString stringWithFormat:@"settingsWindow=%@", settingsWindow ? @"present" : @"none"]];
    if (settingsWindow) {
        NSRect frame = settingsWindow.frame;
        [lines addObject:[NSString stringWithFormat:@"设置窗口：%@ · %@ · frame %.0f,%.0f %.0fx%.0f · level %ld",
                          settingsWindow.visible ? @"可见" : @"不可见",
                          settingsWindow.screen ? @"有屏幕" : @"无屏幕",
                          frame.origin.x,
                          frame.origin.y,
                          frame.size.width,
                          frame.size.height,
                          (long)settingsWindow.level]];
    } else {
        [lines addObject:@"设置窗口：无"];
    }

    [lines addObject:[self recoveryWindowDiagnosticLine]];
    [lines addObject:[self restOverlayViewDiagnosticLine]];
    [lines addObject:[self recoveryDiagnosticText]];
    [lines addObject:[NSString stringWithFormat:@"状态：eyeResting=%@ standResting=%@ yielded=%@ topmost=%@ showWindow=%@ lightDistraction=%@ presentation=%@",
                      self.eyeResting ? @"YES" : @"NO",
                      self.standResting ? @"YES" : @"NO",
                      self.restOverlayYielded ? @"YES" : @"NO",
                      self.settings.restWindowTopmost ? @"YES" : @"NO",
                      self.settings.showRestWindow ? @"YES" : @"NO",
                      [self isLightDistractionModeActive] ? @"YES" : @"NO",
                      self.presentationFocusActive ? @"YES" : @"NO"]];
    return [lines componentsJoinedByString:@"\n"];
}

- (NSArray<NSDictionary<NSString *, id> *> *)recoveryScenarioDefinitions {
    return @[
        @{
            @"id": @"base-window",
            @"title": @"基础休息页恢复",
            @"url": ERAutomationURLString(@"diagnostics/recovery-stress"),
            @"evidence": @"完成 5 轮窗口复查",
            @"needles": @[@"恢复压测", @"休息页状态已校准", @"休息页二次校准完成"]
        },
        @{
            @"id": @"lunch-return",
            @"title": @"午休/离开后站立过期",
            @"url": ERAutomationURLString(@"diagnostics/lunch-recovery"),
            @"evidence": @"站立过期后自动结算并重新排期",
            @"needles": @[@"午休恢复压测", @"站立过期已结算"]
        },
        @{
            @"id": @"sleep-hidden",
            @"title": @"锁屏/睡眠后隐藏休息页",
            @"url": ERAutomationURLString(@"diagnostics/sleep-hidden-recovery"),
            @"evidence": @"未过期隐藏页恢复，已让开窗口保持隐藏",
            @"needles": @[@"睡眠隐藏恢复压测", @"隐藏休息页已恢复", @"已让开休息页保持隐藏"]
        },
        @{
            @"id": @"long-away",
            @"title": @"长时间离开后双提醒过期",
            @"url": ERAutomationURLString(@"diagnostics/long-away-recovery"),
            @"evidence": @"眼睛和站立过期均结算，无残留休息页",
            @"needles": @[@"长离开恢复压测", @"眼睛过期已结算", @"站立过期已结算"]
        },
        @{
            @"id": @"display-offscreen",
            @"title": @"外接屏/合盖后休息页跑到屏幕外",
            @"url": ERAutomationURLString(@"diagnostics/display-recovery"),
            @"evidence": @"窗口回到屏幕内",
            @"needles": @[@"显示恢复压测", @"窗口回到屏幕内"]
        },
        @{
            @"id": @"display-bounds",
            @"title": @"分辨率变化后休息页尺寸不匹配",
            @"url": ERAutomationURLString(@"diagnostics/display-bounds"),
            @"evidence": @"窗口贴合屏幕，内容已重排",
            @"needles": @[@"显示边界压测", @"窗口已贴合屏幕", @"内容已重排"]
        },
        @{
            @"id": @"settings-offscreen",
            @"title": @"外接屏变化后设置窗口不可见",
            @"url": ERAutomationURLString(@"diagnostics/settings-window"),
            @"evidence": @"设置页回到屏幕内并保持可见",
            @"needles": @[@"设置窗口恢复压测", @"设置页回到屏幕内", @"设置页可见"]
        },
        @{
            @"id": @"display-trace",
            @"title": @"显示变化追踪",
            @"url": ERAutomationURLString(@"diagnostics/display-change-trace"),
            @"evidence": @"记录变化前后屏幕摘要",
            @"needles": @[@"显示变化追踪自检", @"已记录屏幕变化"]
        },
        @{
            @"id": @"real-display",
            @"title": @"真实当前显示环境",
            @"url": ERAutomationURLString(@"diagnostics/display-live"),
            @"evidence": @"真实窗口在屏幕内、贴合屏幕、内容重排",
            @"needles": @[@"真实显示环境自检", @"真实窗口在屏幕内", @"真实窗口贴合屏幕"]
        },
        @{
            @"id": @"overlay-yield",
            @"title": @"用户切走后休息页让开",
            @"url": ERAutomationURLString(@"diagnostics/overlay-yield"),
            @"evidence": @"休息页让开，设置页保留，休息计时继续",
            @"needles": @[@"窗口让开压测", @"休息页已让开", @"设置页保留", @"休息计时继续"]
        },
        @{
            @"id": @"window-layer",
            @"title": @"窗口层级/置顶策略",
            @"url": ERAutomationURLString(@"diagnostics/window-layer"),
            @"evidence": @"设置页普通层级，普通休息页不置顶，让开后不弹回",
            @"needles": @[@"窗口层级压测", @"设置页普通层级", @"普通休息页未置顶", @"让开后未弹回"]
        }
    ];
}

- (NSString *)recoveryMatrixDiagnosticText {
    NSArray<NSDictionary<NSString *, id> *> *scenarios = [self recoveryScenarioDefinitions];
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 恢复场景矩阵", ERBrandName]];
    [lines addObject:@"recoveryMatrix=1"];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"屏幕摘要：%@", ERScreenDiagnosticSummary()]];
    [lines addObject:[NSString stringWithFormat:@"一键套件：%@", ERAutomationURLString(@"diagnostics/recovery-matrix-suite")]];
    [lines addObject:[self recoveryWindowDiagnosticLine]];
    [lines addObject:[NSString stringWithFormat:@"最近恢复事件数量：%ld", (long)self.recoveryEventHistory.count]];
    [lines addObject:@"场景覆盖："];
    for (NSDictionary<NSString *, id> *scenario in scenarios) {
        NSString *identifier = [scenario[@"id"] isKindOfClass:NSString.class] ? scenario[@"id"] : @"unknown";
        NSString *title = [scenario[@"title"] isKindOfClass:NSString.class] ? scenario[@"title"] : identifier;
        NSString *url = [scenario[@"url"] isKindOfClass:NSString.class] ? scenario[@"url"] : @"";
        NSString *evidence = [scenario[@"evidence"] isKindOfClass:NSString.class] ? scenario[@"evidence"] : @"";
        NSArray<NSString *> *needles = [scenario[@"needles"] isKindOfClass:NSArray.class] ? scenario[@"needles"] : @[];
        BOOL recorded = [self recoveryHistoryContainsAny:needles];
        [lines addObject:[NSString stringWithFormat:@"scenario=%@ status=%@ url=%@ evidence=%@ title=%@",
                          identifier,
                          recorded ? @"recorded" : @"not-recorded",
                          url,
                          evidence,
                          title]];
    }
    [lines addObject:@"最近事件："];
    for (NSString *line in [self recoveryHistoryLines]) {
        [lines addObject:[NSString stringWithFormat:@"- %@", line]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)recoveryReportDiagnosticText {
    NSArray<NSDictionary<NSString *, id> *> *scenarios = [self recoveryScenarioDefinitions];
    NSMutableArray<NSString *> *recordedTitles = [NSMutableArray array];
    NSMutableArray<NSString *> *missingTitles = [NSMutableArray array];
    NSMutableArray<NSString *> *recordedIdentifiers = [NSMutableArray array];
    NSMutableArray<NSString *> *missingIdentifiers = [NSMutableArray array];
    NSMutableArray<NSString *> *suggestions = [NSMutableArray array];
    for (NSDictionary<NSString *, id> *scenario in scenarios) {
        NSString *identifier = [scenario[@"id"] isKindOfClass:NSString.class] ? scenario[@"id"] : @"unknown";
        NSString *title = [scenario[@"title"] isKindOfClass:NSString.class] ? scenario[@"title"] : @"恢复场景";
        NSString *url = [scenario[@"url"] isKindOfClass:NSString.class] ? scenario[@"url"] : @"";
        NSArray<NSString *> *needles = [scenario[@"needles"] isKindOfClass:NSArray.class] ? scenario[@"needles"] : @[];
        BOOL recorded = [self recoveryHistoryContainsAny:needles];
        if (recorded) {
            [recordedTitles addObject:title];
            [recordedIdentifiers addObject:identifier];
        } else {
            [missingTitles addObject:title];
            [missingIdentifiers addObject:identifier];
            if (suggestions.count < 4 && url.length > 0) {
                [suggestions addObject:[NSString stringWithFormat:@"%@：%@", title, url]];
            }
        }
    }

    NSInteger orphaned = 0;
    for (NSWindow *window in NSApp.windows) {
        if ([window.identifier isEqualToString:ERRestOverlayWindowIdentifier] && window != self.restWindowController.window) {
            orphaned += 1;
        }
    }
    NSWindow *restWindow = self.restWindowController.window;
    NSWindow *settingsWindow = self.settingsWindowController.window;
    BOOL restWindowProblem = restWindow && (!restWindow.screen || ![self.restWindowController hasHealthyActionBindings]);
    BOOL settingsWindowProblem = settingsWindow && !settingsWindow.screen;
    BOOL activeDistraction = [self isLightDistractionModeActive] || self.paused;
    BOOL attentionNeeded = restWindowProblem || settingsWindowProblem || orphaned > 0 || missingTitles.count > 0;

    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 恢复问题报告", ERBrandName]];
    [lines addObject:@"recoveryReport=1"];
    [lines addObject:[NSString stringWithFormat:@"summary=%@", attentionNeeded ? @"attention-needed" : @"healthy"]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"屏幕摘要：%@", ERScreenDiagnosticSummary()]];
    [lines addObject:[NSString stringWithFormat:@"当前状态：休息页 %@ · 设置页 %@ · 残留休息页 %ld · %@",
                      restWindow ? (restWindow.visible ? @"可见" : @"存在但不可见") : @"无",
                      settingsWindow ? (settingsWindow.visible ? @"可见" : @"存在但不可见") : @"无",
                      (long)orphaned,
                      activeDistraction ? @"轻打扰/暂停中" : @"正常提醒"]];
    [lines addObject:[NSString stringWithFormat:@"覆盖结论：已记录 %ld/%ld 个恢复场景",
                      (long)recordedTitles.count,
                      (long)scenarios.count]];
    [lines addObject:[NSString stringWithFormat:@"coverage=%ld/%ld", (long)recordedTitles.count, (long)scenarios.count]];
    [lines addObject:[NSString stringWithFormat:@"recordedScenarios=%@", recordedIdentifiers.count > 0 ? [recordedIdentifiers componentsJoinedByString:@","] : @"none"]];
    [lines addObject:[NSString stringWithFormat:@"missingScenarios=%@", missingIdentifiers.count > 0 ? [missingIdentifiers componentsJoinedByString:@","] : @"none"]];
    [lines addObject:[NSString stringWithFormat:@"suggestionCount=%ld", (long)suggestions.count]];
    [lines addObject:[NSString stringWithFormat:@"已记录场景：%@", recordedTitles.count > 0 ? [recordedTitles componentsJoinedByString:@"、"] : @"暂无"]];
    [lines addObject:[NSString stringWithFormat:@"待补场景：%@", missingTitles.count > 0 ? [missingTitles componentsJoinedByString:@"、"] : @"无"]];
    [lines addObject:@"建议下一步："];
    if (orphaned > 0) {
        [lines addObject:[NSString stringWithFormat:@"- 先运行应急关闭或恢复自检，当前有 %ld 个残留休息页。", (long)orphaned]];
    }
    if (restWindowProblem) {
        [lines addObject:@"- 休息页当前屏幕或按钮链路异常，优先运行显示恢复、显示边界和窗口层级压测。"];
    }
    if (settingsWindowProblem) {
        [lines addObject:@"- 设置页当前不在有效屏幕上，优先运行设置窗口恢复压测。"];
    }
    if (suggestions.count > 0) {
        for (NSString *suggestion in suggestions) {
            [lines addObject:[NSString stringWithFormat:@"- 补跑 %@", suggestion]];
        }
    } else if (!restWindowProblem && !settingsWindowProblem && orphaned == 0) {
        [lines addObject:@"- 最近恢复场景覆盖完整，若仍复现问题，直接复制完整排查包反馈。"];
    }
    [lines addObject:[NSString stringWithFormat:@"一键恢复矩阵套件：%@", ERAutomationURLString(@"diagnostics/recovery-matrix-suite")]];
    [lines addObject:[NSString stringWithFormat:@"完整排查包：%@", ERAutomationURLString(@"diagnostics/support-bundle")]];
    [lines addObject:@"最近事件："];
    for (NSString *line in [self recoveryHistoryLines]) {
        [lines addObject:[NSString stringWithFormat:@"- %@", line]];
    }
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)supportBundleDiagnosticText {
    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    [sections addObject:[NSString stringWithFormat:@"%@ 完整排查包", ERBrandName]];
    [sections addObject:@"supportBundle=1"];
    [sections addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [sections addObject:[NSString stringWithFormat:@"URL Scheme：%@", ERAutomationURLScheme]];
    [sections addObject:@"排查入口："];
    [sections addObject:[NSString stringWithFormat:@"- 问题反馈包：%@", ERAutomationURLString(@"diagnostics/issue-bundle")]];
    [sections addObject:[NSString stringWithFormat:@"- 显示环境诊断：%@", ERAutomationURLString(@"diagnostics/display-real")]];
    [sections addObject:[NSString stringWithFormat:@"- 恢复场景矩阵：%@", ERAutomationURLString(@"diagnostics/recovery-matrix")]];
    [sections addObject:[NSString stringWithFormat:@"- 恢复问题报告：%@", ERAutomationURLString(@"diagnostics/recovery-report")]];
    [sections addObject:[NSString stringWithFormat:@"- 恢复矩阵套件：%@", ERAutomationURLString(@"diagnostics/recovery-matrix-suite")]];
    [sections addObject:[NSString stringWithFormat:@"- 设置窗口恢复压测：%@", ERAutomationURLString(@"diagnostics/settings-window")]];
    [sections addObject:[NSString stringWithFormat:@"- 自动化诊断：%@", ERAutomationURLString(@"automation/diagnostic")]];
    [sections addObject:[NSString stringWithFormat:@"- 真实日历诊断：%@", ERAutomationURLString(@"diagnostics/calendar-real")]];
    [sections addObject:[NSString stringWithFormat:@"- 路线图状态：%@", ERAutomationURLString(@"diagnostics/roadmap-status")]];
    [sections addObject:[NSString stringWithFormat:@"- 自动更新评估：%@", ERAutomationURLString(@"diagnostics/auto-update-readiness")]];
    [sections addObject:@""];
    [sections addObject:@"--- 应用诊断 ---"];
    [sections addObject:@"section=application"];
    [sections addObject:[self applicationDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 恢复诊断 ---"];
    [sections addObject:@"section=recovery"];
    [sections addObject:[self detailedRecoveryDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 显示环境诊断 ---"];
    [sections addObject:@"section=display"];
    [sections addObject:[self displayDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 恢复场景矩阵 ---"];
    [sections addObject:@"section=recovery-matrix"];
    [sections addObject:[self recoveryMatrixDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 恢复问题报告 ---"];
    [sections addObject:@"section=recovery-report"];
    [sections addObject:[self recoveryReportDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 自动化诊断 ---"];
    [sections addObject:@"section=automation"];
    [sections addObject:[self automationDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 日历诊断 ---"];
    [sections addObject:@"section=calendar"];
    [sections addObject:[self calendarDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"--- 路线图状态 ---"];
    [sections addObject:@"section=roadmap-status"];
    [sections addObject:[self roadmapStatusText]];
    [sections addObject:@""];
    [sections addObject:@"--- 自动更新评估 ---"];
    [sections addObject:@"section=auto-update-readiness"];
    [sections addObject:[self autoUpdateReadinessText]];
    return [sections componentsJoinedByString:@"\n"];
}

- (NSString *)issueBundleDiagnosticText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";

    NSMutableArray<NSString *> *sections = [NSMutableArray array];
    [sections addObject:[NSString stringWithFormat:@"%@ 问题反馈包", ERBrandName]];
    [sections addObject:@"issueBundle=1"];
    [sections addObject:@"issueTemplate=1"];
    [sections addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [sections addObject:[NSString stringWithFormat:@"版本：%@ (%@)", version, build]];
    [sections addObject:[NSString stringWithFormat:@"系统：%@", NSProcessInfo.processInfo.operatingSystemVersionString]];
    [sections addObject:[NSString stringWithFormat:@"安装位置：%@", bundle.bundlePath ?: @"未知"]];
    [sections addObject:@""];
    [sections addObject:@"section=issue-template"];
    [sections addObject:@"## 发生了什么？"];
    [sections addObject:@"请在这里写现象，比如休息页卡住、按钮点不了、置顶异常、外接屏后不见了。"];
    [sections addObject:@""];
    [sections addObject:@"## 怎么复现？"];
    [sections addObject:@"1. "];
    [sections addObject:@"2. "];
    [sections addObject:@"3. "];
    [sections addObject:@""];
    [sections addObject:@"## 期望行为"];
    [sections addObject:@"请在这里写你希望它怎么表现。"];
    [sections addObject:@""];
    [sections addObject:@"## 快速结论"];
    [sections addObject:@"section=recovery-report"];
    [sections addObject:[self recoveryReportDiagnosticText]];
    [sections addObject:@""];
    [sections addObject:@"## 自动化策略结论"];
    [sections addObject:@"section=automation-policy"];
    [sections addObject:[self automationPolicyExplanation][@"diagnostic"] ?: @"暂无自动化策略结论。"];
    [sections addObject:@""];
    [sections addObject:@"## 路线图状态"];
    [sections addObject:@"section=roadmap-status"];
    [sections addObject:[self roadmapStatusText]];
    [sections addObject:@""];
    [sections addObject:@"## 完整排查信息"];
    [sections addObject:@"section=support-bundle"];
    [sections addObject:[self supportBundleDiagnosticText]];
    return [sections componentsJoinedByString:@"\n"];
}

- (NSString *)productSupportSummaryText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSString *bundlePath = bundle.bundlePath ?: @"未知";
    return [NSString stringWithFormat:
            @"%@ %@ (%@)\n系统：%@\n安装位置：%@\n下载页：%@\n源码：%@\n反馈包：%@",
            ERBrandName,
            version,
            build,
            NSProcessInfo.processInfo.operatingSystemVersionString ?: @"未知",
            bundlePath,
            ERLatestReleaseURLString,
            ERGitHubURLString,
            ERAutomationURLString(@"diagnostics/issue-bundle")];
}

- (NSString *)installGuideText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSString *bundlePath = bundle.bundlePath ?: @"/Applications/松一下.app";
    return [NSString stringWithFormat:
            @"%@ 安装/更新说明\n\n"
            @"当前版本：%@ (%@)\n"
            @"当前安装位置：%@\n"
            @"下载页：%@\n\n"
            @"1. 打开下载页，下载最新 songyixia-<version>-<build>.zip。\n"
            @"2. 解压得到 %@.app，拖入 /Applications 覆盖旧版本。\n"
            @"3. 打开菜单栏「关于 %@...」确认版本。\n"
            @"4. 遇到问题时，先点「排查中心」->「复制问题反馈包」，再点「反馈问题...」。\n\n"
            @"源码：%@",
            ERBrandName,
            version,
            build,
            bundlePath,
            ERLatestReleaseURLString,
            ERBrandName,
            ERBrandName,
            ERGitHubURLString];
}

- (NSString *)distributionPlanText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSString *bundlePath = bundle.bundlePath ?: @"/Applications/松一下.app";
    NSString *installState = [bundlePath isEqualToString:@"/Applications/松一下.app"]
        ? @"已在 /Applications 标准位置运行"
        : @"当前不在 /Applications 标准位置，发布给普通用户前建议用安装脚本覆盖到 /Applications";
    return [NSString stringWithFormat:
            @"%@ 分发维护方案\n\n"
            @"当前状态：%@ (%@)，%@\n"
            @"安装位置：%@\n"
            @"下载页：%@\n"
            @"源码：%@\n\n"
            @"当前发布方式\n"
            @"- GitHub Actions 在 tag 上运行发布前检查，并上传 dist/songyixia-<version>-<build>.zip。\n"
            @"- 本地和 CI 都使用 scripts/preflight_release.sh 校验构建、签名、打包、诊断和文档守卫。\n"
            @"- 普通用户更新路径保持简单：下载 zip，解压，把 %@.app 拖入 /Applications 覆盖，再用「检查更新...」确认版本。\n\n"
            @"签名和公证方案\n"
            @"- 当前默认使用 ad-hoc 签名，适合开发、内测和 GitHub artifact 完整性校验。\n"
            @"- 进入公开分发前，准备 Developer ID Application 证书，把 CODESIGN_IDENTITY 配成正式证书后复用现有构建脚本。\n"
            @"- 正式 zip 发布前新增 notarytool 公证和 stapler 固化，验证命令应覆盖 spctl、codesign 和解压后的 app。\n\n"
            @"自动更新方案\n"
            @"- 短期继续使用 GitHub Release API 的手动检查更新，风险低、依赖少。\n"
            @"- 如果用户规模扩大，再评估 Sparkle：需要 appcast、ed25519 签名、版本迁移策略和回滚说明。\n"
            @"- 在未完成正式签名/公证前，不建议启用自动后台替换，避免 Gatekeeper 和权限问题。\n\n"
            @"下一步清单\n"
            @"1. 保持 Release zip、安装说明、反馈包和检查更新链路稳定。\n"
            @"2. 准备 Developer ID 证书和 notarytool 密钥，先在 CI secret 里 dry-run。\n"
            @"3. 增加公证后的 Gatekeeper 验证，再决定是否接 Sparkle 自动更新。\n"
            @"4. 每次发布前保留 preflight 输出和 diagnose 输出，方便回溯。",
            ERBrandName,
            version,
            build,
            installState,
            bundlePath,
            ERLatestReleaseURLString,
            ERGitHubURLString,
            ERBrandName];
}

- (NSString *)roadmapStatusText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSString *bundlePath = bundle.bundlePath ?: @"未知";
    NSDictionary<NSString *, NSString *> *automationPolicy = [self automationPolicyExplanation];
    NSString *automationDiagnostic = automationPolicy[@"diagnostic"] ?: @"暂无自动化策略结论。";
    NSString *installState = [bundlePath isEqualToString:@"/Applications/松一下.app"]
        ? @"standard-applications"
        : @"nonstandard-location";
    NSString *restOverlayState = self.restWindowController.window
        ? (self.restWindowController.window.visible ? @"visible" : @"hidden")
        : @"none";
    return [NSString stringWithFormat:
            @"%@ 后续路线图状态\n"
            @"roadmapStatus=1\n"
            @"version=%@(%@)\n"
            @"installState=%@\n"
            @"generatedAt=%@\n"
            @"installPath=%@\n"
            @"releasePage=%@\n"
            @"issueBundle=%@\n\n"
            @"v0.1.45 自动化真实体验补强\n"
            @"status=implemented-with-diagnostics\n"
            @"evidence=automationPolicyExplanation,automationLastActionLabel,automationDiagnosticText,section=automation-policy,automation_policy_readiness.sh\n"
            @"currentPolicy=%@\n"
            @"nextCheck=运行 automation_policy_readiness.sh --strict，或复制自动化诊断/问题反馈包，确认最终动作、命中原因、最近动作和建议下一步都能读懂。\n\n"
            @"v0.1.46 设置页继续打磨\n"
            @"status=implemented-polish-pass\n"
            @"evidence=944x592-settings-window,sidebarDividerView,overviewActionButtonShells,pageIconBadgeViews,stylePreviewMotif\n"
            @"currentWindow=设置页使用左侧导航、节奏摘要、右侧图标标题、浅阴影主卡片和轻按钮概览操作条。\n"
            @"nextCheck=必要时只打开设置页截图，不跑全屏冒烟，重点看夜间/像素/玩具风格文字是否清楚。\n\n"
            @"v0.1.47 分发和长期维护\n"
            @"status=implemented-release-readiness\n"
            @"evidence=release_readiness.sh,notarize_release.sh,auto_update_readiness.sh,swiftui_migration_readiness.sh,zip.sha256,generate_release_notes.sh\n"
            @"currentDistribution=GitHub Release zip + SHA256 + 手动检查更新；Developer ID/公证/Sparkle 仍按方案推进。\n"
            @"nextCheck=发布前保留 preflight、release_readiness、diagnose_app 输出。\n\n"
            @"当前运行状态\n"
            @"eye=%@ stand=%@ pause=%@ restOverlay=%@ topmost=%@ lightDistraction=%@\n"
            @"automation=%@\n\n"
            @"推荐下一步\n"
            @"- 若继续做产品体验：优先做设置页截图和具体页面微调。\n"
            @"- 若准备发版：跑 scripts/preflight_release.sh，再用 scripts/release_readiness.sh --strict 留存快照。\n"
            @"- 若准备公开分发：先补 Developer ID 签名和 notarytool 公证，再评估 Sparkle。",
            ERBrandName,
            version,
            build,
            installState,
            ERFormatClockTime(NSDate.date),
            bundlePath,
            ERLatestReleaseURLString,
            ERAutomationURLString(@"diagnostics/issue-bundle"),
            automationDiagnostic,
            self.settings.eyeEnabled ? @"on" : @"off",
            self.settings.standEnabled ? @"on" : @"off",
            self.paused ? @"on" : @"off",
            restOverlayState,
            self.settings.restWindowTopmost ? @"on" : @"off",
            [self isLightDistractionModeActive] ? @"on" : @"off",
            [self focusModeStatusText]];
}

- (NSString *)autoUpdateReadinessText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSString *bundlePath = bundle.bundlePath ?: @"未知";
    NSString *sparklePath = [bundle.privateFrameworksPath stringByAppendingPathComponent:@"Sparkle.framework"] ?: @"";
    BOOL sparkleBundled = sparklePath.length > 0 && [NSFileManager.defaultManager fileExistsAtPath:sparklePath];
    NSString *feedURL = [info[@"SUFeedURL"] isKindOfClass:NSString.class] ? info[@"SUFeedURL"] : @"";
    NSString *publicKey = [info[@"SUPublicEDKey"] isKindOfClass:NSString.class] ? info[@"SUPublicEDKey"] : @"";
    return [NSString stringWithFormat:
            @"%@ 自动更新评估\n"
            @"autoUpdateReadiness=1\n"
            @"version=%@(%@)\n"
            @"generatedAt=%@\n"
            @"installPath=%@\n"
            @"currentStatus=manual-github-release\n\n"
            @"当前更新链路\n"
            @"- 「检查更新...」读取 GitHub Release API，优先打开 songyixia-*.zip 下载资源。\n"
            @"- Release workflow 上传 zip 和 zip.sha256，发布说明包含安装步骤和 SHA256。\n"
            @"- 用户仍然手动下载、解压、拖入 /Applications 覆盖旧版本。\n\n"
            @"Sparkle 准备度\n"
            @"sparkleFramework=%@\n"
            @"SUFeedURL=%@\n"
            @"SUPublicEDKey=%@\n"
            @"appcast=not-configured\n\n"
            @"签名/公证前置条件\n"
            @"- 当前默认 ad-hoc 签名；公开自动更新前需要 Developer ID Application 证书。\n"
            @"- zip 公证和 stapler 固化需要先通过 notarytool 流程。\n"
            @"- 在未完成正式签名/公证前，不建议启用自动后台替换，避免 Gatekeeper 和权限问题。\n\n"
            @"建议下一步\n"
            @"1. 继续保留当前手动 GitHub Release 更新链路。\n"
            @"2. 准备 Developer ID 与 notarytool 凭据，先跑 scripts/notarize_release.sh dry-run/submit。\n"
            @"3. 若用户规模扩大，再引入 Sparkle.framework、SUFeedURL、SUPublicEDKey、appcast、ed25519 签名和回滚说明。\n"
            @"4. 每次发布前运行 scripts/auto_update_readiness.sh --strict、scripts/release_readiness.sh --strict 和 scripts/preflight_release.sh。",
            ERBrandName,
            version,
            build,
            ERFormatClockTime(NSDate.date),
            bundlePath,
            sparkleBundled ? @"bundled" : @"missing",
            feedURL.length > 0 ? feedURL : @"missing",
            publicKey.length > 0 ? @"configured" : @"missing"];
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
    self.restOverlayYielded = NO;
    if (kind == ERReminderKindEye) {
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:duration];
    } else {
        self.standResting = YES;
        self.standRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:duration];
    }

    [self showNotificationForKind:kind duration:duration];
    if (self.settings.showRestWindow && ![self isLightDistractionModeActive]) {
        [self.restWindowController close];
        self.restWindowController = nil;
        self.restWindowController = [[ERRestWindowController alloc] initWithAppDelegate:self];
        [self.restWindowController configureForKind:kind settings:self.settings duration:duration];
        [self.restWindowController updateRemaining:duration];
        [self.restWindowController presentOverlay];
    } else if ([self isLightDistractionModeActive]) {
        self.todayNotificationOnly += 1;
        [self saveTodayStats];
        NSDictionary<NSString *, NSString *> *policy = [self automationPolicyExplanation];
        NSString *kindTitle = kind == ERReminderKindEye ? @"眼睛提醒" : @"站立提醒";
        [self recordAutomationAction:[NSString stringWithFormat:@"%@只发通知", kindTitle] reason:policy[@"reason"]];
    }
}

- (void)finishRestForKind:(ERReminderKind)kind manually:(BOOL)manually {
    BOOL countedDone = NO;
    if (kind == ERReminderKindEye && self.eyeResting) {
        self.todayEyeDone += 1;
        countedDone = YES;
    }
    if (kind == ERReminderKindStand && self.standResting) {
        self.todayStandDone += 1;
        self.todayStandSeconds += self.settings.standDurationSeconds;
        self.lastStandCompletedAt = NSDate.date;
        NSString *standCompletionName = ERStandCustomStageEntriesFromText(self.settings.standCustomStagesText).count > 0
            ? @"自定义阶段"
            : ERStandRoutineTitle(self.settings.standRoutine);
        self.lastStandCompletionText = [NSString stringWithFormat:@"%@ · %@ · %@",
                                        standCompletionName,
                                        ERStandIntensityTitle(self.settings.standIntensity),
                                        ERFormatShortMinutes(self.settings.standDurationSeconds)];
        self.lastStandCompletionAdvice = [standCompletionName isEqualToString:@"自定义阶段"]
            ? @"下一轮继续按自己的节奏微调动作。"
            : ERStandCompletionAdvice(self.settings.standRoutine, self.settings.standIntensity);
        countedDone = YES;
    }
    if (manually && countedDone) {
        self.todayManualDone += 1;
    }
    [self saveTodayStats];

    if (kind == ERReminderKindEye) {
        [self resetEyeTimer];
    } else {
        [self resetStandTimer];
    }

    self.restOverlayYielded = NO;
    if (self.restWindowController && self.restWindowController.kind == kind) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self.settingsWindowController refreshStats];
    [self publishState];
}

- (void)finishRestForKind:(ERReminderKind)kind {
    [self finishRestForKind:kind manually:NO];
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
    self.restOverlayYielded = NO;
    if (self.restWindowController && self.restWindowController.kind == kind) {
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
    self.restOverlayYielded = NO;
    if (self.restWindowController && self.restWindowController.kind == kind) {
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
        content.body = [NSString stringWithFormat:@"跟着起身、肩颈、走动、补水几个小阶段活动 %@。", ERFormatDuration(duration)];
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
    if (self.settingsWindowController.window.visible) {
        [self.settingsWindowController refreshOverview];
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
    } else if (self.autoPauseActive) {
        title = self.settings.menuBarMode == ERMenuBarModeCompact ? @"" : (self.calendarAutoPauseActive && !self.appAutoPauseActive ? @" 日程暂停" : @" 自动暂停");
    } else if ([self isLightDistractionModeActive] && self.settings.menuBarMode == ERMenuBarModeCompact) {
        title = @"";
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
    if ([self isLightDistractionModeActive] && title.length > 0) {
        NSString *prefix = self.focusModeEnabled ? @" 工作" : (self.quietHoursActive ? @" 安静" : (self.presentationFocusActive ? @" 演示" : (self.calendarFocusActive ? @" 会议" : @" 自动")));
        title = [NSString stringWithFormat:@"%@%@", prefix, title];
    }
    self.statusItem.button.title = title;
}

- (void)refreshMenuOnly {
    NSMenuItem *status = [self.menu itemWithTag:100];
    if (self.pausedUntil) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateFormat = @"HH:mm";
        status.title = [NSString stringWithFormat:@"暂停到 %@", [formatter stringFromDate:self.pausedUntil]];
    } else if (self.paused) {
        status.title = @"已暂停";
    } else if (self.autoPauseActive) {
        if (self.calendarAutoPauseActive && !self.appAutoPauseActive) {
            NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前日程";
            status.title = [NSString stringWithFormat:@"日程暂停：%@", eventTitle];
        } else {
            NSString *name = self.frontmostAppName.length > 0 ? self.frontmostAppName : @"前台应用";
            status.title = [NSString stringWithFormat:@"自动暂停：%@", name];
        }
    } else if (self.focusModeEnabled) {
        status.title = @"工作模式：轻打扰";
    } else if (self.presentationFocusActive) {
        status.title = @"全屏/演示：轻打扰";
    } else if (self.quietHoursActive) {
        status.title = [NSString stringWithFormat:@"安静时段：%@-%@",
                        ERFormatClockMinute(self.settings.quietHoursStartMinute),
                        ERFormatClockMinute(self.settings.quietHoursEndMinute)];
    } else if (self.calendarFocusActive) {
        NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前会议";
        status.title = [NSString stringWithFormat:@"日历会议：%@", eventTitle];
    } else if (self.autoFocusActive) {
        NSString *name = self.frontmostAppName.length > 0 ? self.frontmostAppName : @"前台应用";
        status.title = [NSString stringWithFormat:@"自动轻打扰：%@", name];
    } else {
        status.title = @"节奏运行中";
    }

    NSMenuItem *eyeStatus = [self.menu itemWithTag:101];
    eyeStatus.title = self.settings.eyeEnabled
        ? [NSString stringWithFormat:@"眼睛：%@ %@", self.eyeResting ? @"休息中" : EREyeModeTitle(self.settings.eyeMode), ERFormatDuration([self remainingUntil:(self.eyeResting ? self.eyeRestEndsAt : self.eyeDueAt)])]
        : @"眼睛：已关闭";

    NSMenuItem *standStatus = [self.menu itemWithTag:102];
    NSMenuItem *standAdvice = [self.menu itemWithTag:109];
    BOOL shouldShowStandAdvice = NO;
    if (!self.settings.standEnabled) {
        standStatus.title = @"站立：已关闭";
    } else if (self.lastStandCompletedAt && [NSDate.date timeIntervalSinceDate:self.lastStandCompletedAt] < 90) {
        NSString *feedback = self.lastStandCompletionText.length > 0 ? self.lastStandCompletionText : ERStandRoutineTitle(self.settings.standRoutine);
        standStatus.title = [NSString stringWithFormat:@"站立：刚完成 %@", feedback];
        shouldShowStandAdvice = self.lastStandCompletionAdvice.length > 0;
    } else {
        standStatus.title = [NSString stringWithFormat:@"站立：%@ %@", self.standResting ? @"站立中" : @"下次提醒", ERFormatDuration([self remainingUntil:(self.standResting ? self.standRestEndsAt : self.standDueAt)])];
    }
    standAdvice.hidden = !shouldShowStandAdvice;
    standAdvice.title = shouldShowStandAdvice ? [NSString stringWithFormat:@"建议：%@", self.lastStandCompletionAdvice] : @"";

    NSMenuItem *todayStats = [self.menu itemWithTag:106];
    todayStats.title = [NSString stringWithFormat:@"今天：眼睛 %ld 次 · 站立 %ld 次 · 稍后 %ld · 跳过 %ld",
                        (long)self.todayEyeDone,
                        (long)self.todayStandDone,
                        (long)self.todaySnoozed,
                        (long)self.todaySkipped];

    NSMenuItem *recoveryStatus = [self.menu itemWithTag:108];
    recoveryStatus.title = [self recoveryDiagnosticText];

    NSMenuItem *pause = [self.menu itemWithTag:103];
    pause.title = self.paused ? @"继续" : @"暂停";

    NSMenuItem *focusMode = [self.menu itemWithTag:107];
    focusMode.state = self.focusModeEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *notifications = [self.menu itemWithTag:104];
    notifications.state = self.settings.notificationsEnabled ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *window = [self.menu itemWithTag:105];
    window.state = self.settings.showRestWindow ? NSControlStateValueOn : NSControlStateValueOff;

    NSMenuItem *topmostWindow = [self.menu itemWithTag:110];
    topmostWindow.state = self.settings.restWindowTopmost ? NSControlStateValueOn : NSControlStateValueOff;
    topmostWindow.enabled = self.settings.showRestWindow;

    NSMenuItem *quickRhythmGroup = [self.menu itemWithTag:111];
    for (NSMenuItem *item in quickRhythmGroup.submenu.itemArray) {
        NSArray *itemInfo = [item.representedObject isKindOfClass:NSArray.class] ? item.representedObject : nil;
        item.state = [self quickRhythmMatchesItemInfo:itemInfo] ? NSControlStateValueOn : NSControlStateValueOff;
    }
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

- (void)toggleFocusMode:(id)sender {
    self.focusModeEnabled = !self.focusModeEnabled;
    [self recordAutomationAction:(self.focusModeEnabled ? @"手动轻打扰开启" : @"手动轻打扰关闭")
                          reason:@"菜单栏切换"];
    if (self.focusModeEnabled && self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    if (!self.focusModeEnabled) {
        [self repairRestStateIfNeeded];
    }
    [self publishState];
}

- (void)pauseFor:(NSMenuItem *)sender {
    NSTimeInterval seconds = [sender.representedObject doubleValue];
    [self pauseForSeconds:seconds];
}

- (void)pauseForSeconds:(NSTimeInterval)seconds {
    if (seconds <= 0) return;
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

- (BOOL)quickRhythmMatchesItemInfo:(NSArray *)itemInfo {
    if (itemInfo.count < 4) return NO;
    return self.settings.eyeEnabled &&
        self.settings.eyeFocusSeconds == [itemInfo[1] integerValue] &&
        self.settings.eyeRestSeconds == [itemInfo[2] integerValue] &&
        self.settings.eyeMode == EREyeModeFromObject(itemInfo[3], EREyeModeCustom);
}

- (BOOL)applyQuickRhythmToken:(NSString *)token detail:(NSString **)detail {
    NSString *rhythm = token.lowercaseString ?: @"";
    NSArray *itemInfo = nil;
    if ([rhythm isEqualToString:@"202020"] || [rhythm isEqualToString:@"20-20-20"] || [rhythm isEqualToString:@"default"]) {
        itemInfo = @[@"20-20-20", @(20 * 60), @20, @(EREyeMode202020)];
    } else if ([rhythm isEqualToString:@"pomodoro"] || [rhythm isEqualToString:@"tomato"]) {
        itemInfo = @[@"番茄 25/5", @(25 * 60), @(5 * 60), @(EREyeModePomodoro)];
    } else if ([rhythm isEqualToString:@"debug"] || [rhythm isEqualToString:@"10s"]) {
        itemInfo = @[@"调试 10 秒", @10, @10, @(EREyeModeCustom)];
    } else {
        return NO;
    }

    self.settings.eyeEnabled = YES;
    self.settings.eyeFocusSeconds = ERClampInteger([itemInfo[1] integerValue], 10, 8 * 60 * 60);
    self.settings.eyeRestSeconds = ERClampInteger([itemInfo[2] integerValue], 10, 60 * 60);
    self.settings.eyeMode = EREyeModeFromObject(itemInfo[3], EREyeModeCustom);
    [self.settings save];
    [self.settingsWindowController refreshControls];
    if (detail) *detail = [NSString stringWithFormat:@"快速节奏 %@", itemInfo[0]];
    [self settingsDidChangeShouldReset:YES];
    return YES;
}

- (void)applyQuickRhythm:(NSMenuItem *)sender {
    NSArray *itemInfo = [sender.representedObject isKindOfClass:NSArray.class] ? sender.representedObject : nil;
    if (itemInfo.count < 4) return;
    NSString *detail = nil;
    if ([self applyQuickRhythmToken:[itemInfo[0] isEqualToString:@"20-20-20"] ? @"202020" : ([itemInfo[0] hasPrefix:@"番茄"] ? @"pomodoro" : @"debug") detail:&detail]) {
        [self noteRecoveryEventTitle:@"快速节奏" detail:[NSString stringWithFormat:@"已切换为 %@", itemInfo[0]]];
        [self publishState];
    }
}

- (void)applyQuickSetupProfile:(NSString *)profile {
    NSString *token = profile.lowercaseString ?: @"";
    NSString *profileTitle = @"均衡护眼";

    self.settings.eyeEnabled = YES;
    self.settings.standEnabled = YES;
    self.settings.showRestWindow = YES;
    self.settings.restWindowTopmost = NO;
    self.settings.notificationsEnabled = YES;
    self.settings.menuBarMode = ERMenuBarModeBoth;
    self.settings.standCustomStagesText = @"";

    if ([token isEqualToString:@"pomodoro"] || [token isEqualToString:@"focus"]) {
        profileTitle = @"番茄专注";
        self.settings.eyeMode = EREyeModePomodoro;
        self.settings.eyeFocusSeconds = 25 * 60;
        self.settings.eyeRestSeconds = 5 * 60;
        self.settings.standIntervalSeconds = 2 * 60 * 60;
        self.settings.standDurationSeconds = 20 * 60;
        self.settings.standRoutine = ERStandRoutineReset;
        self.settings.standIntensity = ERStandIntensityGentle;
        self.settings.restStyle = ERRestStyleNight;
    } else if ([token isEqualToString:@"stand"] || [token isEqualToString:@"active"]) {
        profileTitle = @"久坐打断";
        self.settings.eyeMode = EREyeMode202020;
        self.settings.eyeFocusSeconds = 20 * 60;
        self.settings.eyeRestSeconds = 20;
        self.settings.standIntervalSeconds = 60 * 60;
        self.settings.standDurationSeconds = 10 * 60;
        self.settings.standRoutine = ERStandRoutineWalk;
        self.settings.standIntensity = ERStandIntensityActive;
        self.settings.restStyle = ERRestStyleToy;
    } else if ([token isEqualToString:@"debug"] || [token isEqualToString:@"10s"]) {
        profileTitle = @"调试 10 秒";
        self.settings.eyeMode = EREyeModeCustom;
        self.settings.eyeFocusSeconds = 10;
        self.settings.eyeRestSeconds = 10;
        self.settings.standIntervalSeconds = 10;
        self.settings.standDurationSeconds = 10;
        self.settings.standRoutine = ERStandRoutineBalanced;
        self.settings.standIntensity = ERStandIntensityStandard;
        self.settings.restStyle = ERRestStylePixel;
    } else {
        profileTitle = @"均衡护眼";
        self.settings.eyeMode = EREyeMode202020;
        self.settings.eyeFocusSeconds = 20 * 60;
        self.settings.eyeRestSeconds = 20;
        self.settings.standIntervalSeconds = 2 * 60 * 60;
        self.settings.standDurationSeconds = 20 * 60;
        self.settings.standRoutine = ERStandRoutineBalanced;
        self.settings.standIntensity = ERStandIntensityStandard;
        self.settings.restStyle = ERRestStyleBreath;
    }

    [NSUserDefaults.standardUserDefaults setBool:YES forKey:ERSettingsQuickSetupSeenKey];
    [self.settings save];
    [self.settingsWindowController refreshControls];
    [self settingsDidChangeShouldReset:YES];
    [self noteRecoveryEventTitle:@"快速配置" detail:[NSString stringWithFormat:@"已应用 %@", profileTitle]];
    [self publishState];
}

- (void)showQuickSetup:(id)sender {
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:ERSettingsQuickSetupSeenKey];
    [NSUserDefaults.standardUserDefaults synchronize];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.icon = [NSImage imageWithSystemSymbolName:@"slider.horizontal.3" accessibilityDescription:@"快速配置"];
    alert.messageText = @"快速配置";
    alert.informativeText = @"选一个接近现在状态的节奏，之后仍可在设置里细调。";
    [alert addButtonWithTitle:@"应用"];
    [alert addButtonWithTitle:@"取消"];

    NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 460, 168)];
    NSPopUpButton *profilePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(0, 136, 220, 26) pullsDown:NO];
    NSArray<NSDictionary<NSString *, NSString *> *> *profiles = @[
        @{@"title": @"均衡护眼", @"token": @"balanced", @"detail": @"20-20-20 + 站立 2 小时 / 20 分钟"},
        @{@"title": @"番茄专注", @"token": @"pomodoro", @"detail": @"25 分钟专注 / 5 分钟离屏，站立保持 2 小时"},
        @{@"title": @"久坐打断", @"token": @"stand", @"detail": @"眼睛保持 20-20-20，站立改为 60 分钟 / 10 分钟"},
        @{@"title": @"调试 10 秒", @"token": @"debug", @"detail": @"眼睛和站立都用 10 秒节奏，方便快速验证"}
    ];
    for (NSDictionary<NSString *, NSString *> *profileInfo in profiles) {
        [profilePopup addItemWithTitle:profileInfo[@"title"]];
        NSMenuItem *item = profilePopup.lastItem;
        item.representedObject = profileInfo[@"token"];
    }
    [profilePopup selectItemAtIndex:0];
    [panel addSubview:profilePopup];

    NSTextField *detailLabel = [NSTextField wrappingLabelWithString:profiles.firstObject[@"detail"]];
    detailLabel.frame = NSMakeRect(0, 90, 460, 38);
    detailLabel.font = [NSFont systemFontOfSize:13];
    detailLabel.textColor = NSColor.secondaryLabelColor;
    detailLabel.maximumNumberOfLines = 2;
    [panel addSubview:detailLabel];

    NSArray<NSString *> *rows = @[
        @"眼睛、站立会分别重置下一次提醒时间。",
        @"提醒窗口会保持非置顶，避免休息页长期压住主屏幕。",
        @"选择调试节奏后，记得再切回日常节奏。"
    ];
    for (NSInteger index = 0; index < rows.count; index++) {
        NSTextField *row = [NSTextField labelWithString:rows[index]];
        row.frame = NSMakeRect(0, 58 - index * 22, 460, 20);
        row.font = [NSFont systemFontOfSize:12];
        row.textColor = NSColor.tertiaryLabelColor;
        [panel addSubview:row];
    }

    objc_setAssociatedObject(profilePopup, "quickSetupProfiles", profiles, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(profilePopup, "quickSetupDetailLabel", detailLabel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    profilePopup.target = self;
    profilePopup.action = @selector(quickSetupProfileChanged:);

    alert.accessoryView = panel;

    void (^applyResponse)(NSModalResponse) = ^(NSModalResponse response) {
        if (response == NSAlertFirstButtonReturn) {
            NSString *selectedProfile = [profilePopup.selectedItem.representedObject isKindOfClass:NSString.class]
                ? profilePopup.selectedItem.representedObject
                : @"balanced";
            [self applyQuickSetupProfile:selectedProfile];
        }
    };

    NSWindow *settingsWindow = self.settingsWindowController.window;
    [NSApp activateIgnoringOtherApps:YES];
    if (settingsWindow.visible) {
        [alert beginSheetModalForWindow:settingsWindow completionHandler:applyResponse];
    } else {
        applyResponse([alert runModal]);
    }
}

- (void)quickSetupProfileChanged:(id)sender {
    NSPopUpButton *profilePopup = [sender isKindOfClass:NSPopUpButton.class] ? sender : nil;
    NSArray<NSDictionary<NSString *, NSString *> *> *profiles = objc_getAssociatedObject(profilePopup, "quickSetupProfiles");
    NSTextField *detailLabel = objc_getAssociatedObject(profilePopup, "quickSetupDetailLabel");
    NSInteger index = profilePopup.indexOfSelectedItem;
    if (index >= 0 && index < profiles.count) {
        detailLabel.stringValue = profiles[index][@"detail"] ?: @"";
    }
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

- (void)emergencyCloseRestOverlay:(id)sender {
    BOOL hasActiveRest = self.eyeResting || self.standResting;
    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    NSInteger orphaned = [self closeOrphanRestWindows];
    if (hasActiveRest) {
        self.todaySkipped += 1;
        [self saveTodayStats];
    }
    [self resetAllTimers];
    [self noteRecoveryEventTitle:@"手动应急" detail:[NSString stringWithFormat:@"已关闭休息页%@",
                                                 orphaned > 0 ? [NSString stringWithFormat:@"，清理残留 %ld 个", (long)orphaned] : @""]];
    [self publishState];
}

- (void)copyRecoveryDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self detailedRecoveryDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制恢复诊断"];
    [self publishState];
}

- (void)copyApplicationDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self applicationDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制应用诊断"];
    [self publishState];
}

- (void)copyDisplayDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self displayDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制显示环境诊断"];
    [self publishState];
}

- (void)copyRecoveryMatrixDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self recoveryMatrixDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制恢复场景矩阵"];
    [self publishState];
}

- (void)copyRecoveryReportDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self recoveryReportDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制恢复问题报告"];
    [self publishState];
}

- (void)copySupportBundleDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self supportBundleDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制完整排查包"];
    [self publishState];
}

- (void)copyIssueBundleDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self issueBundleDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"诊断" detail:@"已复制问题反馈包"];
    [self publishState];
}

- (void)copyInstallGuide:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self installGuideText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"安装更新" detail:@"已复制安装更新说明"];
    [self publishState];
}

- (void)copyDistributionPlan:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self distributionPlanText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"分发维护" detail:@"已复制分发维护方案"];
    [self publishState];
}

- (void)copyRoadmapStatus:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self roadmapStatusText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"路线图" detail:@"已复制路线图状态"];
    [self publishState];
}

- (void)copyAutoUpdateReadiness:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self autoUpdateReadinessText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"自动更新" detail:@"已复制自动更新评估"];
    [self publishState];
}

- (void)runRecoverySelfCheck:(id)sender {
    [self repairRestOverlayAfterSystemEvent:nil];
    [self noteRecoveryEventTitle:@"手动自检" detail:self.restWindowController ? @"休息页状态已校准" : @"状态正常"];
    [self publishState];
}

- (void)runRecoveryStressTest:(id)sender {
    self.recoveryStressTestGeneration += 1;
    NSUInteger generation = self.recoveryStressTestGeneration;
    NSDate *previousEyeDueAt = self.eyeDueAt;
    NSDate *previousEyeRestEndsAt = self.eyeRestEndsAt;
    BOOL previousEyeResting = self.eyeResting;
    NSDate *previousStandDueAt = self.standDueAt;
    NSDate *previousStandRestEndsAt = self.standRestEndsAt;
    BOOL previousStandResting = self.standResting;
    BOOL previousRestOverlayYielded = self.restOverlayYielded;
    BOOL diagnosticRestStarted = !self.eyeResting && !self.standResting && self.settings.eyeEnabled && self.settings.showRestWindow && !self.paused && ![self isLightDistractionModeActive];
    NSArray<NSNumber *> *delays = @[@0.0, @0.4, @1.0, @2.0, @4.0];
    NSInteger total = delays.count;

    if (diagnosticRestStarted) {
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(45, self.settings.eyeRestSeconds)];
        self.restOverlayYielded = NO;
        [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
    }
    if (self.restWindowController) {
        self.restWindowController.finishButton.target = nil;
        [self noteRecoveryEventTitle:@"恢复压测" detail:@"已模拟休息页按钮链路异常"];
    }

    [self noteRecoveryEventTitle:@"恢复压测" detail:[NSString stringWithFormat:@"开始 %ld 轮窗口复查", (long)total]];
    [self publishState];

    for (NSInteger index = 0; index < total; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runRecoveryStressTestPass:index + 1
                                      total:total
                                 generation:generation
                           previousEyeDueAt:previousEyeDueAt
                        previousEyeRestEndsAt:previousEyeRestEndsAt
                         previousEyeResting:previousEyeResting
                         previousStandDueAt:previousStandDueAt
                      previousStandRestEndsAt:previousStandRestEndsAt
                       previousStandResting:previousStandResting
                  previousRestOverlayYielded:previousRestOverlayYielded
                       diagnosticRestStarted:diagnosticRestStarted];
        });
    }
}

- (void)runRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting previousStandDueAt:(NSDate *)previousStandDueAt previousStandRestEndsAt:(NSDate *)previousStandRestEndsAt previousStandResting:(BOOL)previousStandResting previousRestOverlayYielded:(BOOL)previousRestOverlayYielded diagnosticRestStarted:(BOOL)diagnosticRestStarted {
    if (generation != self.recoveryStressTestGeneration) return;

    BOOL hadBrokenButtons = self.restWindowController && ![self.restWindowController hasHealthyActionBindings];
    [self refreshFocusModeState];
    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];
    if (self.restWindowController) {
        [self.restWindowController refreshActionBindings];
        if (!self.restOverlayYielded || self.settings.restWindowTopmost) {
            [self.restWindowController presentOverlay];
        }
    }

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    if (self.paused) {
        [details addObject:@"暂停中"];
    } else if ([self isLightDistractionModeActive]) {
        [details addObject:@"轻打扰中"];
    }
    if (self.restWindowController) {
        [details addObject:[self.restWindowController hasHealthyActionBindings] ? @"按钮正常" : @"按钮异常"];
        [details addObject:self.restWindowController.window.screen ? @"窗口在屏幕上" : @"窗口丢屏幕"];
    } else {
        [details addObject:@"无休息页"];
    }
    if (hadBrokenButtons && self.restWindowController && [self.restWindowController hasHealthyActionBindings]) {
        [details addObject:@"按钮链路已修复"];
    }
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }
    [details addObject:[NSString stringWithFormat:@"屏幕 %ld", (long)NSScreen.screens.count]];

    if (pass == total && diagnosticRestStarted) {
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.eyeRestEndsAt = previousEyeRestEndsAt;
        self.eyeResting = previousEyeResting;
        self.standDueAt = previousStandDueAt ?: (self.settings.standEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.standIntervalSeconds] : nil);
        self.standRestEndsAt = previousStandRestEndsAt;
        self.standResting = previousStandResting;
        self.restOverlayYielded = previousRestOverlayYielded;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [details addObject:@"恢复压测状态已还原"];
    }

    [self noteRecoveryEventTitle:@"恢复压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runLunchRecoveryStressTest:(id)sender {
    self.lunchRecoveryStressTestGeneration += 1;
    NSUInteger generation = self.lunchRecoveryStressTestGeneration;
    NSInteger total = 3;

    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.standResting = YES;
    self.standRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:-90];
    self.standDueAt = nil;
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.restOverlayYielded = NO;

    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];

    [self noteRecoveryEventTitle:@"午休恢复压测" detail:@"已模拟站立休息过期，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.5];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runLunchRecoveryStressTestPass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runLunchRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.lunchRecoveryStressTestGeneration) return;

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];

    BOOL resolved = !self.standResting && self.standRestEndsAt == nil && self.standDueAt != nil && self.restWindowController == nil;
    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:resolved ? @"站立过期已结算" : @"站立仍需复查"];
    [details addObject:self.restWindowController ? @"仍有休息页" : @"无休息页"];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }
    [details addObject:[NSString stringWithFormat:@"下次站立 %@",
                        self.standDueAt ? ERFormatDuration([self remainingUntil:self.standDueAt]) : @"未设置"]];

    [self noteRecoveryEventTitle:@"午休恢复压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runSleepHiddenRecoveryStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"睡眠隐藏恢复压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.sleepHiddenRecoveryStressTestGeneration += 1;
    NSUInteger generation = self.sleepHiddenRecoveryStressTestGeneration;
    NSInteger total = 4;
    BOOL previousTopmost = self.settings.restWindowTopmost;

    self.settings.restWindowTopmost = NO;
    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(45, self.settings.eyeRestSeconds)];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.restOverlayYielded = NO;

    [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
    if (self.restWindowController) {
        [self.restWindowController.window orderOut:nil];
    }

    [self noteRecoveryEventTitle:@"睡眠隐藏恢复压测" detail:@"已模拟睡眠时隐藏但眼睛休息未过期，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.1, @1.8];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.sleepHiddenRecoveryStressTestGeneration) return;
            [self runSleepHiddenRecoveryStressTestPass:index + 1 total:total generation:generation previousTopmost:previousTopmost];
        });
    }
}

- (void)runSleepHiddenRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost {
    if (generation != self.sleepHiddenRecoveryStressTestGeneration) return;

    if (pass == 1) {
        [self repairRestOverlayAfterSystemEvent:nil];
    } else if (pass == 2) {
        [self yieldRestOverlayForUserFocusChange];
        [self repairRestOverlayAfterSystemEvent:nil];
    } else {
        [self settleExpiredRests];
        [self repairRestStateIfNeeded];
    }
    NSInteger orphaned = [self closeOrphanRestWindows];

    BOOL restContinues = self.eyeResting && self.eyeRestEndsAt && [self.eyeRestEndsAt timeIntervalSinceNow] > 0;
    BOOL windowVisible = self.restWindowController && self.restWindowController.window.visible;
    BOOL yielded = self.restOverlayYielded;
    BOOL restoredFirstPass = pass == 1 && windowVisible && !yielded;
    BOOL yieldedStillHidden = pass >= 2 && yielded && !windowVisible;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    if (pass == 1) {
        [details addObject:restoredFirstPass ? @"隐藏休息页已恢复" : @"隐藏休息页未恢复"];
    } else {
        [details addObject:yieldedStillHidden ? @"已让开休息页保持隐藏" : @"已让开休息页异常弹回"];
    }
    [details addObject:restContinues ? @"休息计时继续" : @"休息计时异常"];
    [details addObject:windowVisible ? @"窗口可见" : @"窗口隐藏"];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.restWindowTopmost = previousTopmost;
        [self.settings save];
        [self cleanupDiagnosticEyeRest];
        [details addObject:@"测试状态已还原"];
    }

    [self noteRecoveryEventTitle:@"睡眠隐藏恢复压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runLongAwayRecoveryStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.standEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"长离开恢复压测" detail:@"眼睛、站立或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.longAwayRecoveryStressTestGeneration += 1;
    NSUInteger generation = self.longAwayRecoveryStressTestGeneration;
    NSInteger total = 3;

    self.longAwayRecoveryStatsSnapshot = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:-8 * 60];
    self.eyeDueAt = nil;
    self.standResting = YES;
    self.standRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:-15 * 60];
    self.standDueAt = nil;
    self.restOverlayYielded = NO;

    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];
    [self ensureRestWindowForKind:ERReminderKindStand remaining:MAX(30, self.settings.standDurationSeconds)];
    if (self.restWindowController) {
        [self.restWindowController.window orderOut:nil];
    }

    [self noteRecoveryEventTitle:@"长离开恢复压测" detail:@"已模拟眼睛和站立休息均过期，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.5];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runLongAwayRecoveryStressTestPass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runLongAwayRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.longAwayRecoveryStressTestGeneration) return;

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];

    BOOL eyeResolved = !self.eyeResting && self.eyeRestEndsAt == nil && self.eyeDueAt != nil;
    BOOL standResolved = !self.standResting && self.standRestEndsAt == nil && self.standDueAt != nil;
    BOOL windowCleared = self.restWindowController == nil;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:eyeResolved ? @"眼睛过期已结算" : @"眼睛仍需复查"];
    [details addObject:standResolved ? @"站立过期已结算" : @"站立仍需复查"];
    [details addObject:windowCleared ? @"无休息页" : @"仍有休息页"];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }
    [details addObject:[NSString stringWithFormat:@"下次眼睛 %@",
                        self.eyeDueAt ? ERFormatDuration([self remainingUntil:self.eyeDueAt]) : @"未设置"]];
    [details addObject:[NSString stringWithFormat:@"下次站立 %@",
                        self.standDueAt ? ERFormatDuration([self remainingUntil:self.standDueAt]) : @"未设置"]];

    if (pass == total && eyeResolved && standResolved) {
        NSDictionary<NSString *, NSNumber *> *snapshot = self.longAwayRecoveryStatsSnapshot;
        if (snapshot) {
            self.todayEyeDone = snapshot[@"eye"].integerValue;
            self.todayStandDone = snapshot[@"stand"].integerValue;
            self.todayStandSeconds = snapshot[@"standSeconds"].integerValue;
            self.todaySnoozed = snapshot[@"snoozed"].integerValue;
            self.todaySkipped = snapshot[@"skipped"].integerValue;
            self.todayManualDone = snapshot[@"manualDone"].integerValue;
            self.todayNotificationOnly = snapshot[@"notificationOnly"].integerValue;
            self.todayAutoPauseSessions = snapshot[@"autoPauseSessions"].integerValue;
            self.todayAutoPauseSeconds = snapshot[@"autoPauseSeconds"].integerValue;
            [self saveTodayStats];
            self.longAwayRecoveryStatsSnapshot = nil;
            [details addObject:@"统计已还原"];
        }
    }

    [self noteRecoveryEventTitle:@"长离开恢复压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runDisplayRecoveryStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"显示恢复压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.displayRecoveryStressTestGeneration += 1;
    NSUInteger generation = self.displayRecoveryStressTestGeneration;
    NSInteger total = 3;

    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.restOverlayYielded = NO;

    [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
    if (self.restWindowController) {
        NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
        NSRect frame = self.restWindowController.window.frame;
        NSRect screenFrame = screen ? screen.frame : NSMakeRect(0, 0, 1280, 800);
        frame.origin.x = NSMaxX(screenFrame) + 240;
        frame.origin.y = NSMaxY(screenFrame) + 240;
        [self.restWindowController.window setFrame:frame display:NO animate:NO];
        [self.restWindowController.window orderOut:nil];
    }

    [self noteRecoveryEventTitle:@"显示恢复压测" detail:@"已模拟休息页位于屏幕外，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.5];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runDisplayRecoveryStressTestPass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runDisplayRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.displayRecoveryStressTestGeneration) return;

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];

    NSWindow *window = self.restWindowController.window;
    NSScreen *screen = window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    BOOL onScreen = window && screen && NSIntersectsRect(window.frame, screen.frame);

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:onScreen ? @"窗口回到屏幕内" : @"窗口仍在屏幕外"];
    if (window) {
        [details addObject:[NSString stringWithFormat:@"frame %.0f,%.0f %.0fx%.0f",
                            window.frame.origin.x,
                            window.frame.origin.y,
                            window.frame.size.width,
                            window.frame.size.height]];
    } else {
        [details addObject:@"无休息页"];
    }
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }
    [details addObject:[NSString stringWithFormat:@"屏幕 %ld", (long)NSScreen.screens.count]];

    if (pass == total) {
        [self skipRestForKind:ERReminderKindEye];
    }
    [self noteRecoveryEventTitle:@"显示恢复压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runDisplayBoundsStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"显示边界压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.displayBoundsStressTestGeneration += 1;
    NSUInteger generation = self.displayBoundsStressTestGeneration;
    NSInteger total = 3;

    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.restOverlayYielded = NO;

    [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
    if (self.restWindowController) {
        NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
        NSRect screenFrame = screen ? screen.frame : NSMakeRect(0, 0, 1280, 800);
        NSRect staleFrame = NSInsetRect(screenFrame, MAX(80, screenFrame.size.width * 0.12), MAX(70, screenFrame.size.height * 0.10));
        [self.restWindowController.window setFrame:staleFrame display:YES animate:NO];
        self.restWindowController.window.contentView.frame = NSMakeRect(0, 0, staleFrame.size.width, staleFrame.size.height);
    }

    [self noteRecoveryEventTitle:@"显示边界压测" detail:@"已模拟休息页仍在屏幕内但尺寸不匹配，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.5];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runDisplayBoundsStressTestPass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runDisplayBoundsStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.displayBoundsStressTestGeneration) return;

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];

    NSWindow *window = self.restWindowController.window;
    NSScreen *screen = window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSRect expectedFrame = screen ? screen.frame : NSMakeRect(0, 0, 1280, 800);
    BOOL refit = window && NSEqualRects(NSIntegralRect(window.frame), NSIntegralRect(expectedFrame));
    BOOL contentRefit = window && NSEqualRects(NSIntegralRect(window.contentView.frame), NSIntegralRect(NSMakeRect(0, 0, expectedFrame.size.width, expectedFrame.size.height)));

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:refit ? @"窗口已贴合屏幕" : @"窗口尺寸仍异常"];
    [details addObject:contentRefit ? @"内容已重排" : @"内容仍需重排"];
    if (window) {
        [details addObject:[NSString stringWithFormat:@"frame %.0f,%.0f %.0fx%.0f",
                            window.frame.origin.x,
                            window.frame.origin.y,
                            window.frame.size.width,
                            window.frame.size.height]];
    } else {
        [details addObject:@"无休息页"];
    }
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        [self cleanupDiagnosticEyeRest];
    }
    [self noteRecoveryEventTitle:@"显示边界压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runSettingsWindowRecoveryStressTest:(id)sender {
    self.settingsWindowRecoveryStressTestGeneration += 1;
    NSUInteger generation = self.settingsWindowRecoveryStressTestGeneration;
    NSInteger total = 3;

    [self presentSettingsWindow];
    NSWindow *settingsWindow = self.settingsWindowController.window;
    if (settingsWindow) {
        NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
        NSRect visibleFrame = screen ? screen.visibleFrame : NSMakeRect(0, 0, 1280, 800);
        NSRect frame = settingsWindow.frame;
        frame.origin.x = NSMaxX(visibleFrame) + 280;
        frame.origin.y = NSMaxY(visibleFrame) + 180;
        [settingsWindow setFrame:frame display:NO animate:NO];
    }

    [self noteRecoveryEventTitle:@"设置窗口恢复压测" detail:@"已模拟设置窗口位于屏幕外，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.5];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runSettingsWindowRecoveryStressTestPass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runSettingsWindowRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.settingsWindowRecoveryStressTestGeneration) return;

    BOOL repaired = [self repairSettingsWindowAfterDisplayChange];
    NSWindow *settingsWindow = self.settingsWindowController.window;
    BOOL onScreen = NO;
    for (NSScreen *screen in NSScreen.screens) {
        if (settingsWindow && NSIntersectsRect(settingsWindow.frame, screen.visibleFrame)) {
            onScreen = YES;
            break;
        }
    }

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:onScreen ? @"设置页回到屏幕内" : @"设置页仍在屏幕外"];
    [details addObject:repaired ? @"已重新定位" : @"位置已正常"];
    if (settingsWindow) {
        [details addObject:[NSString stringWithFormat:@"frame %.0f,%.0f %.0fx%.0f",
                            settingsWindow.frame.origin.x,
                            settingsWindow.frame.origin.y,
                            settingsWindow.frame.size.width,
                            settingsWindow.frame.size.height]];
        [details addObject:settingsWindow.visible ? @"设置页可见" : @"设置页隐藏"];
    } else {
        [details addObject:@"无设置页"];
    }

    [self noteRecoveryEventTitle:@"设置窗口恢复压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runDisplayChangeTraceSelfCheck:(id)sender {
    NSString *previousSummary = self.lastScreenDiagnosticSummary.length > 0 ? self.lastScreenDiagnosticSummary : @"自检前无基线";
    NSString *currentSummary = ERScreenDiagnosticSummary();
    self.lastDisplayChangePreviousSummary = previousSummary;
    self.lastDisplayChangeCurrentSummary = currentSummary;
    self.lastDisplayChangeAt = NSDate.date;
    self.lastScreenDiagnosticSummary = currentSummary;
    [self noteRecoveryEventTitle:@"显示变化追踪自检"
                          detail:[NSString stringWithFormat:@"已记录屏幕变化 %@ -> %@", previousSummary, currentSummary]];
    [self publishState];
}

- (void)runRealDisplayCheck:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"真实显示环境自检" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.realDisplayCheckGeneration += 1;
    NSUInteger generation = self.realDisplayCheckGeneration;
    NSInteger total = 3;
    NSDate *previousEyeDueAt = self.eyeDueAt;
    NSDate *previousEyeRestEndsAt = self.eyeRestEndsAt;
    BOOL previousEyeResting = self.eyeResting;
    NSDate *previousStandDueAt = self.standDueAt;
    NSDate *previousStandRestEndsAt = self.standRestEndsAt;
    BOOL previousStandResting = self.standResting;
    BOOL previousRestOverlayYielded = self.restOverlayYielded;

    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.restOverlayYielded = NO;
    [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];

    [self noteRecoveryEventTitle:@"真实显示环境自检" detail:[NSString stringWithFormat:@"%@，开始复查", ERScreenDiagnosticSummary()]];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.5, @1.4];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runRealDisplayCheckPass:index + 1
                                    total:total
                               generation:generation
                         previousEyeDueAt:previousEyeDueAt
                    previousEyeRestEndsAt:previousEyeRestEndsAt
                       previousEyeResting:previousEyeResting
                        previousStandDueAt:previousStandDueAt
                   previousStandRestEndsAt:previousStandRestEndsAt
                      previousStandResting:previousStandResting
                 previousRestOverlayYielded:previousRestOverlayYielded];
        });
    }
}

- (void)runRealDisplayCheckPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting previousStandDueAt:(NSDate *)previousStandDueAt previousStandRestEndsAt:(NSDate *)previousStandRestEndsAt previousStandResting:(BOOL)previousStandResting previousRestOverlayYielded:(BOOL)previousRestOverlayYielded {
    if (generation != self.realDisplayCheckGeneration) return;

    [self repairRestOverlayAfterSystemEvent:nil];
    NSInteger orphaned = [self closeOrphanRestWindows];

    NSWindow *window = self.restWindowController.window;
    NSScreen *screen = window.screen ?: NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    NSRect expectedFrame = screen ? screen.frame : NSMakeRect(0, 0, 1280, 800);
    BOOL frameMatches = window && NSEqualRects(NSIntegralRect(window.frame), NSIntegralRect(expectedFrame));
    BOOL contentMatches = window && NSEqualRects(NSIntegralRect(window.contentView.frame), NSIntegralRect(NSMakeRect(0, 0, expectedFrame.size.width, expectedFrame.size.height)));
    BOOL actionBindings = self.restWindowController && [self.restWindowController hasHealthyActionBindings];
    BOOL onScreen = window && screen && NSIntersectsRect(window.frame, screen.frame);

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:onScreen ? @"真实窗口在屏幕内" : @"真实窗口不在屏幕内"];
    [details addObject:frameMatches ? @"真实窗口贴合屏幕" : @"真实窗口尺寸异常"];
    [details addObject:contentMatches ? @"真实内容已重排" : @"真实内容仍需重排"];
    [details addObject:actionBindings ? @"按钮正常" : @"按钮异常"];
    [details addObject:ERScreenDiagnosticSummary()];
    if (window) {
        [details addObject:[NSString stringWithFormat:@"frame %.0f,%.0f %.0fx%.0f",
                            window.frame.origin.x,
                            window.frame.origin.y,
                            window.frame.size.width,
                            window.frame.size.height]];
    } else {
        [details addObject:@"无休息页"];
    }
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.eyeRestEndsAt = previousEyeRestEndsAt;
        self.eyeResting = previousEyeResting;
        self.standDueAt = previousStandDueAt ?: (self.settings.standEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.standIntervalSeconds] : nil);
        self.standRestEndsAt = previousStandRestEndsAt;
        self.standResting = previousStandResting;
        self.restOverlayYielded = previousRestOverlayYielded;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [details addObject:@"测试状态已还原"];
        [details addObject:@"真实显示状态已还原"];
    }

    [self noteRecoveryEventTitle:@"真实显示环境自检" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runOverlayYieldStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"窗口让开压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.overlayYieldStressTestGeneration += 1;
    NSUInteger generation = self.overlayYieldStressTestGeneration;
    NSInteger total = 3;

    BOOL previousTopmost = self.settings.restWindowTopmost;
    self.settings.restWindowTopmost = NO;
    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.restOverlayYielded = NO;

    [self presentSettingsWindow];
    [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];

    [self noteRecoveryEventTitle:@"窗口让开压测" detail:@"已模拟非置顶休息页和设置页并存，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.45, @1.2];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.overlayYieldStressTestGeneration) return;
            if (index == 0) {
                [self yieldRestOverlayForUserFocusChange];
            }
            [self runOverlayYieldStressTestPass:index + 1 total:total generation:generation previousTopmost:previousTopmost];
        });
    }
}

- (void)runOverlayYieldStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost {
    if (generation != self.overlayYieldStressTestGeneration) return;

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    NSInteger orphaned = [self closeOrphanRestWindows];

    BOOL yielded = self.restOverlayYielded;
    BOOL hidden = !self.restWindowController || !self.restWindowController.window.visible;
    BOOL settingsAlive = self.settingsWindowController && self.settingsWindowController.window.visible;
    BOOL restContinues = self.eyeResting && self.eyeRestEndsAt && [self.eyeRestEndsAt timeIntervalSinceNow] > 0;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:yielded ? @"休息页已让开" : @"休息页未让开"];
    [details addObject:hidden ? @"窗口已隐藏" : @"窗口仍可见"];
    [details addObject:settingsAlive ? @"设置页保留" : @"设置页丢失"];
    [details addObject:restContinues ? @"休息计时继续" : @"休息计时异常"];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.restWindowTopmost = previousTopmost;
        [self.settings save];
        self.eyeResting = NO;
        self.eyeRestEndsAt = nil;
        self.eyeDueAt = self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil;
        self.restOverlayYielded = NO;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [self.settingsWindowController close];
        [details addObject:@"测试状态已还原"];
        [details addObject:@"窗口让开状态已还原"];
    }

    [self noteRecoveryEventTitle:@"窗口让开压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runWindowLayerPolicyStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"窗口层级压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.windowLayerPolicyStressTestGeneration += 1;
    NSUInteger generation = self.windowLayerPolicyStressTestGeneration;
    NSInteger total = 4;
    BOOL previousTopmost = self.settings.restWindowTopmost;

    self.settings.restWindowTopmost = NO;
    self.paused = NO;
    self.pausedUntil = nil;
    self.autoPauseActive = NO;
    self.focusModeEnabled = NO;
    self.eyeResting = YES;
    self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(45, self.settings.eyeRestSeconds)];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    self.restOverlayYielded = NO;

    [self presentSettingsWindow];
    [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
    [self noteRecoveryEventTitle:@"窗口层级压测" detail:@"已模拟设置页、普通休息页和置顶强提醒切换"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.45, @1.0, @1.6];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.windowLayerPolicyStressTestGeneration) return;
            if (index == 1) {
                [self yieldRestOverlayForUserFocusChange];
                [self repairRestOverlayAfterSystemEvent:nil];
            } else if (index == 2) {
                self.settings.restWindowTopmost = YES;
                self.restOverlayYielded = NO;
                [self normalizeWindowLevelsForCurrentSettings];
                [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
            }
            [self runWindowLayerPolicyStressTestPass:index + 1 total:total generation:generation previousTopmost:previousTopmost];
        });
    }
}

- (void)runWindowLayerPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost {
    if (generation != self.windowLayerPolicyStressTestGeneration) return;

    [self settleExpiredRests];
    [self repairRestStateIfNeeded];
    [self normalizeWindowLevelsForCurrentSettings];
    NSInteger orphaned = [self closeOrphanRestWindows];

    NSWindow *settingsWindow = self.settingsWindowController.window;
    NSWindow *restWindow = self.restWindowController.window;
    BOOL settingsNormal = !settingsWindow || (settingsWindow.level == NSNormalWindowLevel && settingsWindow.collectionBehavior == NSWindowCollectionBehaviorManaged);
    BOOL restNormal = !restWindow || restWindow.level == NSNormalWindowLevel;
    BOOL restTopmost = restWindow && restWindow.level == NSStatusWindowLevel;
    BOOL yieldedHidden = self.restOverlayYielded && (!restWindow || !restWindow.visible);
    BOOL settingsAlive = settingsWindow && settingsWindow.visible;
    BOOL restContinues = self.eyeResting && self.eyeRestEndsAt && [self.eyeRestEndsAt timeIntervalSinceNow] > 0;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];
    [details addObject:settingsNormal ? @"设置页普通层级" : @"设置页层级异常"];
    if (pass <= 2) {
        [details addObject:restNormal ? @"普通休息页未置顶" : @"普通休息页层级异常"];
    } else {
        [details addObject:restTopmost ? @"强提醒才置顶" : @"强提醒层级异常"];
    }
    if (pass >= 2) {
        [details addObject:yieldedHidden || self.settings.restWindowTopmost ? @"让开后未弹回" : @"让开后异常弹回"];
    }
    [details addObject:settingsAlive ? @"设置页保留" : @"设置页已关闭"];
    [details addObject:restContinues ? @"休息计时继续" : @"休息计时异常"];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.restWindowTopmost = previousTopmost;
        [self.settings save];
        [self cleanupDiagnosticEyeRest];
        [self.settingsWindowController close];
        [details addObject:@"测试状态已还原"];
        [details addObject:@"窗口层级状态已还原"];
    }

    [self noteRecoveryEventTitle:@"窗口层级压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runRecoveryMatrixSuite:(id)sender {
    self.recoveryMatrixSuiteGeneration += 1;
    NSUInteger generation = self.recoveryMatrixSuiteGeneration;
    NSArray<NSDictionary<NSString *, NSString *> *> *steps = @[
        @{@"title": @"基础休息页恢复", @"action": @"recovery-stress"},
        @{@"title": @"午休/离开后站立过期", @"action": @"lunch-recovery"},
        @{@"title": @"锁屏/睡眠后隐藏休息页", @"action": @"sleep-hidden-recovery"},
        @{@"title": @"长时间离开后双提醒过期", @"action": @"long-away-recovery"},
        @{@"title": @"外接屏/合盖后休息页跑到屏幕外", @"action": @"display-recovery"},
        @{@"title": @"外接屏变化后设置窗口不可见", @"action": @"settings-window"},
        @{@"title": @"分辨率变化后休息页尺寸不匹配", @"action": @"display-bounds"},
        @{@"title": @"用户切走后休息页让开", @"action": @"overlay-yield"},
        @{@"title": @"窗口层级/置顶策略", @"action": @"window-layer"}
    ];

    [self noteRecoveryEventTitle:@"恢复矩阵套件" detail:[NSString stringWithFormat:@"开始 %ld 个场景顺序压测", (long)steps.count]];
    [self publishState];

    NSTimeInterval offset = 0;
    NSTimeInterval gap = 6.0;
    for (NSInteger index = 0; index < steps.count; index++) {
        NSDictionary<NSString *, NSString *> *step = steps[index];
        NSString *title = [step[@"title"] isKindOfClass:NSString.class] ? step[@"title"] : @"恢复场景";
        NSString *action = [step[@"action"] isKindOfClass:NSString.class] ? step[@"action"] : @"";
        NSTimeInterval delay = offset;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runRecoveryMatrixSuiteStep:index + 1 total:steps.count title:title action:action generation:generation];
        });
        offset += gap;
    }

    NSTimeInterval finishDelay = offset + 2.0;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(finishDelay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self finishRecoveryMatrixSuiteWithTotal:steps.count generation:generation];
    });
}

- (void)runRecoveryMatrixSuiteStep:(NSInteger)index total:(NSInteger)total title:(NSString *)title action:(NSString *)action generation:(NSUInteger)generation {
    if (generation != self.recoveryMatrixSuiteGeneration) return;

    [self noteRecoveryEventTitle:@"恢复矩阵套件"
                          detail:[NSString stringWithFormat:@"运行 %ld/%ld：%@ · %@",
                                  (long)index,
                                  (long)total,
                                  title,
                                  ERAutomationURLString([NSString stringWithFormat:@"diagnostics/%@", action])]];

    if ([action isEqualToString:@"recovery-stress"]) {
        [self runRecoveryStressTest:nil];
    } else if ([action isEqualToString:@"lunch-recovery"]) {
        [self runLunchRecoveryStressTest:nil];
    } else if ([action isEqualToString:@"sleep-hidden-recovery"]) {
        [self runSleepHiddenRecoveryStressTest:nil];
    } else if ([action isEqualToString:@"long-away-recovery"]) {
        [self runLongAwayRecoveryStressTest:nil];
    } else if ([action isEqualToString:@"display-recovery"]) {
        [self runDisplayRecoveryStressTest:nil];
    } else if ([action isEqualToString:@"settings-window"]) {
        [self runSettingsWindowRecoveryStressTest:nil];
    } else if ([action isEqualToString:@"display-bounds"]) {
        [self runDisplayBoundsStressTest:nil];
    } else if ([action isEqualToString:@"overlay-yield"]) {
        [self runOverlayYieldStressTest:nil];
    } else if ([action isEqualToString:@"window-layer"]) {
        [self runWindowLayerPolicyStressTest:nil];
    } else {
        [self noteRecoveryEventTitle:@"恢复矩阵套件" detail:[NSString stringWithFormat:@"跳过未知场景：%@", action]];
    }
    [self publishState];
}

- (void)finishRecoveryMatrixSuiteWithTotal:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.recoveryMatrixSuiteGeneration) return;
    [self noteRecoveryEventTitle:@"恢复矩阵套件"
                          detail:[NSString stringWithFormat:@"完成 %ld/%ld，已顺序触发全部恢复场景，可复制恢复场景矩阵查看记录",
                                  (long)total,
                                  (long)total]];
    [self publishState];
}

- (void)runAutomationPolicyStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"自动化策略压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.automationPolicyStressTestGeneration += 1;
    NSUInteger generation = self.automationPolicyStressTestGeneration;
    NSInteger total = 4;
    NSDictionary<NSString *, id> *previousSettings = @{
        @"autoFocusModeEnabled": @(self.settings.autoFocusModeEnabled),
        @"quietHoursEnabled": @(self.settings.quietHoursEnabled),
        @"quietHoursStartMinute": @(self.settings.quietHoursStartMinute),
        @"quietHoursEndMinute": @(self.settings.quietHoursEndMinute),
        @"autoPauseAppTokens": self.settings.autoPauseAppTokens ?: @[],
        @"focusAppTokens": self.settings.focusAppTokens ?: @[],
        @"ignoreAppTokens": self.settings.ignoreAppTokens ?: @[]
    };
    NSDate *previousEyeDueAt = self.eyeDueAt;
    self.automationPolicyStatsSnapshot = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    self.paused = NO;
    self.pausedUntil = nil;
    self.focusModeEnabled = NO;
    self.autoPauseActive = NO;
    self.autoPauseSessionActive = NO;
    self.autoIgnoreActive = NO;
    self.appAutoPauseActive = NO;
    self.calendarFocusActive = NO;
    self.calendarAutoPauseActive = NO;
    self.presentationFocusActive = NO;
    self.quietHoursActive = NO;
    self.autoFocusActive = NO;
    self.restOverlayYielded = NO;
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
    self.standResting = NO;
    self.standRestEndsAt = nil;

    self.settings.autoFocusModeEnabled = YES;
    self.settings.quietHoursEnabled = YES;
    self.settings.quietHoursStartMinute = ERCurrentMinuteOfDay();
    self.settings.quietHoursEndMinute = ERSanitizedMinuteOfDay(self.settings.quietHoursStartMinute + 1);
    self.settings.autoPauseAppTokens = @[];
    self.settings.focusAppTokens = @[];
    self.settings.ignoreAppTokens = @[];
    [self.settings save];
    [self.settingsWindowController refreshControls];
    [self closeOrphanRestWindows];
    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }

    [self noteRecoveryEventTitle:@"自动化策略压测" detail:@"已模拟安静时段和自动暂停策略，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.6, @1.4, @2.3];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.automationPolicyStressTestGeneration) return;
            [self runAutomationPolicyStressTestPass:index + 1 total:total generation:generation previousSettings:previousSettings previousEyeDueAt:previousEyeDueAt];
        });
    }
}

- (void)runAutomationPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt {
    if (generation != self.automationPolicyStressTestGeneration) return;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];

    if (pass == 1) {
        [self refreshFocusModeState];
        self.autoPauseActive = NO;
        self.appAutoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
        [self evaluateReminderKind:ERReminderKindEye];
        [self repairRestStateIfNeeded];
        BOOL notificationOnly = self.restWindowController == nil && self.todayNotificationOnly > self.automationPolicyStatsSnapshot[@"notificationOnly"].integerValue;
        [details addObject:notificationOnly ? @"安静时段只发通知" : @"安静时段仍弹窗"];
        [details addObject:self.quietHoursActive ? @"安静命中" : @"安静未命中"];
    } else if (pass == 2) {
        self.settings.quietHoursEnabled = NO;
        self.settings.autoPauseAppTokens = @[@"com.songyixia.diagnostic.autopause"];
        [self.settings save];
        self.autoPauseActive = NO;
        self.appAutoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
        self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeFocusSeconds)];
        [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
        BOOL windowVisible = self.restWindowController && self.restWindowController.window.visible;
        [details addObject:windowVisible ? @"自动暂停前休息页已显示" : @"自动暂停前休息页未显示"];
    } else {
        NSDate *beforeDue = self.eyeDueAt;
        self.frontmostAppBundleIdentifier = @"com.songyixia.diagnostic.autopause";
        self.frontmostAppName = @"诊断自动暂停";
        self.autoPauseActive = YES;
        self.appAutoPauseActive = YES;
        self.autoFocusActive = NO;
        if (!self.autoPauseSessionActive) {
            self.todayAutoPauseSessions += 1;
            self.autoPauseSessionActive = YES;
        }
        [self shiftReminderDatesBySeconds:1];
        self.todayAutoPauseSeconds += 1;
        [self saveTodayStats];
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        BOOL shifted = beforeDue && self.eyeDueAt && [self.eyeDueAt timeIntervalSinceDate:beforeDue] >= 0.5;
        BOOL windowClosed = self.restWindowController == nil;
        [details addObject:self.autoPauseActive ? @"自动暂停命中" : @"自动暂停未命中"];
        [details addObject:windowClosed ? @"自动暂停已关闭休息页" : @"自动暂停仍有休息页"];
        [details addObject:shifted ? @"提醒时间已顺延" : @"提醒时间未顺延"];
    }

    NSInteger orphaned = [self closeOrphanRestWindows];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.quietHoursEnabled = [previousSettings[@"quietHoursEnabled"] boolValue];
        self.settings.quietHoursStartMinute = [previousSettings[@"quietHoursStartMinute"] integerValue];
        self.settings.quietHoursEndMinute = [previousSettings[@"quietHoursEndMinute"] integerValue];
        self.settings.autoPauseAppTokens = previousSettings[@"autoPauseAppTokens"] ?: ERDefaultAutoPauseAppTokens();
        self.settings.focusAppTokens = previousSettings[@"focusAppTokens"] ?: ERDefaultFocusAppTokens();
        self.settings.ignoreAppTokens = previousSettings[@"ignoreAppTokens"] ?: ERDefaultIgnoreAppTokens();
        [self.settings save];
        NSDictionary<NSString *, NSNumber *> *snapshot = self.automationPolicyStatsSnapshot;
        if (snapshot) {
            self.todayEyeDone = snapshot[@"eye"].integerValue;
            self.todayStandDone = snapshot[@"stand"].integerValue;
            self.todayStandSeconds = snapshot[@"standSeconds"].integerValue;
            self.todaySnoozed = snapshot[@"snoozed"].integerValue;
            self.todaySkipped = snapshot[@"skipped"].integerValue;
            self.todayManualDone = snapshot[@"manualDone"].integerValue;
            self.todayNotificationOnly = snapshot[@"notificationOnly"].integerValue;
            self.todayAutoPauseSessions = snapshot[@"autoPauseSessions"].integerValue;
            self.todayAutoPauseSeconds = snapshot[@"autoPauseSeconds"].integerValue;
            [self saveTodayStats];
        }
        self.automationPolicyStatsSnapshot = nil;
        self.paused = NO;
        self.pausedUntil = nil;
        self.autoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.appAutoPauseActive = NO;
        self.autoFocusActive = NO;
        self.quietHoursActive = NO;
        self.eyeResting = NO;
        self.eyeRestEndsAt = nil;
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.restOverlayYielded = NO;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [self.settingsWindowController refreshControls];
        [details addObject:@"测试状态已还原"];
        [details addObject:@"自动化策略状态已还原"];
    }

    [self noteRecoveryEventTitle:@"自动化策略压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runPresentationPolicyStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"演示策略压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.presentationPolicyStressTestGeneration += 1;
    NSUInteger generation = self.presentationPolicyStressTestGeneration;
    NSInteger total = 3;
    NSDictionary<NSString *, id> *previousSettings = @{
        @"autoFocusModeEnabled": @(self.settings.autoFocusModeEnabled),
        @"presentationFocusModeEnabled": @(self.settings.presentationFocusModeEnabled)
    };
    NSDate *previousEyeDueAt = self.eyeDueAt;
    self.presentationPolicyStatsSnapshot = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    self.settings.autoFocusModeEnabled = YES;
    self.settings.presentationFocusModeEnabled = YES;
    [self.settings save];
    self.paused = NO;
    self.pausedUntil = nil;
    self.focusModeEnabled = NO;
    self.autoPauseActive = NO;
    self.autoPauseSessionActive = NO;
    self.autoIgnoreActive = NO;
    self.appAutoPauseActive = NO;
    self.calendarFocusActive = NO;
    self.calendarAutoPauseActive = NO;
    self.quietHoursActive = NO;
    self.presentationFocusActive = YES;
    self.autoFocusActive = YES;
    self.restOverlayYielded = NO;
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];
    [self.settingsWindowController refreshControls];

    [self noteRecoveryEventTitle:@"演示策略压测" detail:@"已模拟全屏/演示轻打扰，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.7, @1.4];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.presentationPolicyStressTestGeneration) return;
            [self runPresentationPolicyStressTestPass:index + 1 total:total generation:generation previousSettings:previousSettings previousEyeDueAt:previousEyeDueAt];
        });
    }
}

- (void)runPresentationPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt {
    if (generation != self.presentationPolicyStressTestGeneration) return;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];

    if (pass == 1) {
        self.presentationFocusActive = YES;
        self.autoFocusActive = YES;
        self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
        [self evaluateReminderKind:ERReminderKindEye];
        [self repairRestStateIfNeeded];
        BOOL notificationOnly = self.restWindowController == nil && self.todayNotificationOnly > self.presentationPolicyStatsSnapshot[@"notificationOnly"].integerValue;
        [details addObject:notificationOnly ? @"演示模式只发通知" : @"演示模式仍弹窗"];
        [details addObject:(self.presentationFocusActive && self.autoFocusActive) ? @"演示命中" : @"演示未命中"];
    } else if (pass == 2) {
        self.presentationFocusActive = NO;
        self.autoFocusActive = NO;
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
        self.restOverlayYielded = NO;
        [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
        BOOL windowVisible = self.restWindowController && self.restWindowController.window.visible;
        self.presentationFocusActive = YES;
        self.autoFocusActive = YES;
        [self repairRestStateIfNeeded];
        BOOL windowClosed = self.restWindowController == nil;
        [details addObject:windowVisible ? @"演示前休息页已显示" : @"演示前休息页未显示"];
        [details addObject:windowClosed ? @"演示命中已关闭休息页" : @"演示命中仍有休息页"];
    } else {
        self.presentationFocusActive = YES;
        self.autoFocusActive = YES;
        [self repairRestOverlayAfterSystemEvent:nil];
        BOOL windowClosed = self.restWindowController == nil;
        [details addObject:windowClosed ? @"恢复自检不弹休息页" : @"恢复自检异常弹窗"];
    }

    NSInteger orphaned = [self closeOrphanRestWindows];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.presentationFocusModeEnabled = [previousSettings[@"presentationFocusModeEnabled"] boolValue];
        [self.settings save];
        NSDictionary<NSString *, NSNumber *> *snapshot = self.presentationPolicyStatsSnapshot;
        if (snapshot) {
            self.todayEyeDone = snapshot[@"eye"].integerValue;
            self.todayStandDone = snapshot[@"stand"].integerValue;
            self.todayStandSeconds = snapshot[@"standSeconds"].integerValue;
            self.todaySnoozed = snapshot[@"snoozed"].integerValue;
            self.todaySkipped = snapshot[@"skipped"].integerValue;
            self.todayManualDone = snapshot[@"manualDone"].integerValue;
            self.todayNotificationOnly = snapshot[@"notificationOnly"].integerValue;
            self.todayAutoPauseSessions = snapshot[@"autoPauseSessions"].integerValue;
            self.todayAutoPauseSeconds = snapshot[@"autoPauseSeconds"].integerValue;
            [self saveTodayStats];
        }
        self.presentationPolicyStatsSnapshot = nil;
        self.paused = NO;
        self.pausedUntil = nil;
        self.autoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.appAutoPauseActive = NO;
        self.autoFocusActive = NO;
        self.presentationFocusActive = NO;
        self.eyeResting = NO;
        self.eyeRestEndsAt = nil;
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.restOverlayYielded = NO;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [self.settingsWindowController refreshControls];
        [details addObject:@"测试状态已还原"];
        [details addObject:@"演示策略状态已还原"];
    }

    [self noteRecoveryEventTitle:@"演示策略压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runRealPresentationPolicyCheck:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"真实演示联动自检" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }
    if (!ERPresentationModeDetected()) {
        [self noteRecoveryEventTitle:@"真实演示联动自检" detail:@"当前未检测到全屏/演示状态，跳过"];
        [self publishState];
        return;
    }

    self.realPresentationPolicyCheckGeneration += 1;
    NSUInteger generation = self.realPresentationPolicyCheckGeneration;
    NSInteger total = 3;
    NSDictionary<NSString *, id> *previousSettings = @{
        @"autoFocusModeEnabled": @(self.settings.autoFocusModeEnabled),
        @"presentationFocusModeEnabled": @(self.settings.presentationFocusModeEnabled)
    };
    NSDate *previousEyeDueAt = self.eyeDueAt;
    NSDate *previousEyeRestEndsAt = self.eyeRestEndsAt;
    BOOL previousEyeResting = self.eyeResting;
    self.realPresentationPolicyStatsSnapshot = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    self.settings.autoFocusModeEnabled = YES;
    self.settings.presentationFocusModeEnabled = YES;
    [self.settings save];
    self.paused = NO;
    self.pausedUntil = nil;
    self.focusModeEnabled = NO;
    self.restOverlayYielded = NO;
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];
    [self refreshFocusModeState];
    [self.settingsWindowController refreshControls];

    if (!self.presentationFocusActive) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.presentationFocusModeEnabled = [previousSettings[@"presentationFocusModeEnabled"] boolValue];
        [self.settings save];
        self.eyeDueAt = previousEyeDueAt;
        self.eyeRestEndsAt = previousEyeRestEndsAt;
        self.eyeResting = previousEyeResting;
        self.realPresentationPolicyStatsSnapshot = nil;
        [self noteRecoveryEventTitle:@"真实演示联动自检" detail:@"全屏/演示状态已变化，跳过"];
        [self publishState];
        return;
    }

    [self noteRecoveryEventTitle:@"真实演示联动自检" detail:@"已命中真实全屏/演示状态，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.7, @1.4];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.realPresentationPolicyCheckGeneration) return;
            [self runRealPresentationPolicyCheckPass:index + 1
                                               total:total
                                          generation:generation
                                    previousSettings:previousSettings
                                    previousEyeDueAt:previousEyeDueAt
                               previousEyeRestEndsAt:previousEyeRestEndsAt
                                  previousEyeResting:previousEyeResting];
        });
    }
}

- (void)runRealPresentationPolicyCheckPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting {
    if (generation != self.realPresentationPolicyCheckGeneration) return;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];

    if (pass == 1) {
        [self refreshFocusModeState];
        [details addObject:self.presentationFocusActive ? @"真实演示命中" : @"真实演示未命中"];
        [details addObject:self.autoFocusActive ? @"真实演示轻打扰" : @"真实演示未轻打扰"];
    } else if (pass == 2) {
        [self refreshFocusModeState];
        NSInteger beforeNotificationOnly = self.todayNotificationOnly;
        if (self.presentationFocusActive) {
            [self beginRestForKind:ERReminderKindEye];
        }
        BOOL notificationOnly = self.presentationFocusActive && self.todayNotificationOnly > beforeNotificationOnly;
        BOOL windowClosed = self.restWindowController == nil;
        [details addObject:notificationOnly ? @"真实演示只发通知" : @"真实演示通知未记录"];
        [details addObject:windowClosed ? @"真实演示未弹休息页" : @"真实演示仍弹休息页"];
    } else {
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
        [self refreshFocusModeState];
        [self repairRestOverlayAfterSystemEvent:nil];
        BOOL windowClosed = self.restWindowController == nil;
        [details addObject:windowClosed ? @"真实演示恢复自检不弹窗" : @"真实演示恢复自检异常弹窗"];
    }

    NSInteger orphaned = [self closeOrphanRestWindows];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.presentationFocusModeEnabled = [previousSettings[@"presentationFocusModeEnabled"] boolValue];
        [self.settings save];
        NSDictionary<NSString *, NSNumber *> *snapshot = self.realPresentationPolicyStatsSnapshot;
        if (snapshot) {
            self.todayEyeDone = snapshot[@"eye"].integerValue;
            self.todayStandDone = snapshot[@"stand"].integerValue;
            self.todayStandSeconds = snapshot[@"standSeconds"].integerValue;
            self.todaySnoozed = snapshot[@"snoozed"].integerValue;
            self.todaySkipped = snapshot[@"skipped"].integerValue;
            self.todayManualDone = snapshot[@"manualDone"].integerValue;
            self.todayNotificationOnly = snapshot[@"notificationOnly"].integerValue;
            self.todayAutoPauseSessions = snapshot[@"autoPauseSessions"].integerValue;
            self.todayAutoPauseSeconds = snapshot[@"autoPauseSeconds"].integerValue;
            [self saveTodayStats];
        }
        self.realPresentationPolicyStatsSnapshot = nil;
        self.paused = NO;
        self.pausedUntil = nil;
        self.autoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.appAutoPauseActive = NO;
        self.autoFocusActive = NO;
        self.presentationFocusActive = NO;
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.eyeRestEndsAt = previousEyeRestEndsAt;
        self.eyeResting = previousEyeResting;
        self.restOverlayYielded = NO;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [self.settingsWindowController refreshControls];
        BOOL restoredStats = snapshot && self.todayNotificationOnly == snapshot[@"notificationOnly"].integerValue;
        [details addObject:restoredStats ? @"统计已还原" : @"统计仍需还原"];
        [details addObject:@"测试状态已还原"];
    }

    [self noteRecoveryEventTitle:@"真实演示联动自检" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runCalendarPolicyStressTest:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"日历策略压测" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }

    self.calendarPolicyStressTestGeneration += 1;
    NSUInteger generation = self.calendarPolicyStressTestGeneration;
    NSInteger total = 3;
    NSDictionary<NSString *, id> *previousSettings = @{
        @"autoFocusModeEnabled": @(self.settings.autoFocusModeEnabled),
        @"calendarFocusModeEnabled": @(self.settings.calendarFocusModeEnabled)
    };
    NSDate *previousEyeDueAt = self.eyeDueAt;
    self.calendarPolicyStatsSnapshot = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    self.settings.autoFocusModeEnabled = YES;
    self.settings.calendarFocusModeEnabled = YES;
    [self.settings save];
    self.paused = NO;
    self.pausedUntil = nil;
    self.focusModeEnabled = NO;
    self.autoPauseActive = NO;
    self.autoPauseSessionActive = NO;
    self.autoIgnoreActive = NO;
    self.appAutoPauseActive = NO;
    self.presentationFocusActive = NO;
    self.quietHoursActive = NO;
    self.calendarFocusActive = YES;
    self.calendarAutoPauseActive = NO;
    self.autoFocusActive = YES;
    self.currentCalendarEventTitle = @"诊断会议";
    self.restOverlayYielded = NO;
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
    self.standResting = NO;
    self.standRestEndsAt = nil;
    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];
    [self.settingsWindowController refreshControls];

    [self noteRecoveryEventTitle:@"日历策略压测" detail:@"已模拟日历会议和日程暂停，开始复查"];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.8, @1.7];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.calendarPolicyStressTestGeneration) return;
            [self runCalendarPolicyStressTestPass:index + 1 total:total generation:generation previousSettings:previousSettings previousEyeDueAt:previousEyeDueAt];
        });
    }
}

- (void)runCalendarPolicyStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt {
    if (generation != self.calendarPolicyStressTestGeneration) return;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];

    if (pass == 1) {
        self.calendarFocusActive = YES;
        self.calendarAutoPauseActive = NO;
        self.autoPauseActive = NO;
        self.autoFocusActive = YES;
        self.currentCalendarEventTitle = @"诊断会议";
        self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
        [self evaluateReminderKind:ERReminderKindEye];
        [self repairRestStateIfNeeded];
        BOOL notificationOnly = self.restWindowController == nil && self.todayNotificationOnly > self.calendarPolicyStatsSnapshot[@"notificationOnly"].integerValue;
        [details addObject:notificationOnly ? @"日历会议只发通知" : @"日历会议仍弹窗"];
        [details addObject:self.calendarFocusActive ? @"会议命中" : @"会议未命中"];
    } else if (pass == 2) {
        self.calendarFocusActive = NO;
        self.calendarAutoPauseActive = NO;
        self.autoFocusActive = NO;
        self.autoPauseActive = NO;
        self.eyeResting = YES;
        self.eyeRestEndsAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeRestSeconds)];
        self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:MAX(30, self.settings.eyeFocusSeconds)];
        self.restOverlayYielded = NO;
        [self ensureRestWindowForKind:ERReminderKindEye remaining:[self remainingUntil:self.eyeRestEndsAt]];
        BOOL windowVisible = self.restWindowController && self.restWindowController.window.visible;
        self.calendarAutoPauseActive = YES;
        self.calendarFocusActive = NO;
        self.autoPauseActive = YES;
        self.autoFocusActive = NO;
        self.currentCalendarEventTitle = @"诊断录制";
        NSDate *beforeDue = self.eyeDueAt;
        [self shiftReminderDatesBySeconds:1];
        self.todayAutoPauseSeconds += 1;
        [self saveTodayStats];
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        BOOL shifted = beforeDue && self.eyeDueAt && [self.eyeDueAt timeIntervalSinceDate:beforeDue] >= 0.5;
        BOOL windowClosed = self.restWindowController == nil;
        [details addObject:windowVisible ? @"日程暂停前休息页已显示" : @"日程暂停前休息页未显示"];
        [details addObject:self.autoPauseActive ? @"日程暂停命中" : @"日程暂停未命中"];
        [details addObject:windowClosed ? @"日程暂停已关闭休息页" : @"日程暂停仍有休息页"];
        [details addObject:shifted ? @"提醒时间已顺延" : @"提醒时间未顺延"];
    } else {
        [details addObject:@"等待还原统计"];
    }

    NSInteger orphaned = [self closeOrphanRestWindows];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.calendarFocusModeEnabled = [previousSettings[@"calendarFocusModeEnabled"] boolValue];
        [self.settings save];
        NSDictionary<NSString *, NSNumber *> *snapshot = self.calendarPolicyStatsSnapshot;
        if (snapshot) {
            self.todayEyeDone = snapshot[@"eye"].integerValue;
            self.todayStandDone = snapshot[@"stand"].integerValue;
            self.todayStandSeconds = snapshot[@"standSeconds"].integerValue;
            self.todaySnoozed = snapshot[@"snoozed"].integerValue;
            self.todaySkipped = snapshot[@"skipped"].integerValue;
            self.todayManualDone = snapshot[@"manualDone"].integerValue;
            self.todayNotificationOnly = snapshot[@"notificationOnly"].integerValue;
            self.todayAutoPauseSessions = snapshot[@"autoPauseSessions"].integerValue;
            self.todayAutoPauseSeconds = snapshot[@"autoPauseSeconds"].integerValue;
            [self saveTodayStats];
        }
        self.calendarPolicyStatsSnapshot = nil;
        self.paused = NO;
        self.pausedUntil = nil;
        self.autoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.appAutoPauseActive = NO;
        self.calendarFocusActive = NO;
        self.calendarAutoPauseActive = NO;
        self.autoFocusActive = NO;
        self.currentCalendarEventTitle = nil;
        self.eyeResting = NO;
        self.eyeRestEndsAt = nil;
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.restOverlayYielded = NO;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [self.settingsWindowController refreshControls];
        BOOL restoredNotification = snapshot && self.todayNotificationOnly == snapshot[@"notificationOnly"].integerValue;
        BOOL restoredAutoPauseSeconds = snapshot && self.todayAutoPauseSeconds == snapshot[@"autoPauseSeconds"].integerValue;
        [details addObject:(restoredNotification && restoredAutoPauseSeconds) ? @"统计已还原" : @"统计仍需还原"];
        [details addObject:@"测试状态已还原"];
        [details addObject:@"日历策略状态已还原"];
    }

    [self noteRecoveryEventTitle:@"日历策略压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)runRealCalendarPolicyCheck:(id)sender {
    if (!self.settings.eyeEnabled || !self.settings.showRestWindow) {
        [self noteRecoveryEventTitle:@"真实日历联动自检" detail:@"眼睛提醒或休息页已关闭，跳过"];
        [self publishState];
        return;
    }
    if (!ERCalendarAccessGranted()) {
        [self noteRecoveryEventTitle:@"真实日历联动自检" detail:@"日历未授权，跳过真实事件自检"];
        [self publishState];
        return;
    }

    self.realCalendarPolicyCheckGeneration += 1;
    NSUInteger generation = self.realCalendarPolicyCheckGeneration;
    NSInteger total = 3;
    NSDictionary<NSString *, id> *previousSettings = @{
        @"autoFocusModeEnabled": @(self.settings.autoFocusModeEnabled),
        @"calendarFocusModeEnabled": @(self.settings.calendarFocusModeEnabled)
    };
    NSDate *previousEyeDueAt = self.eyeDueAt;
    NSDate *previousEyeRestEndsAt = self.eyeRestEndsAt;
    BOOL previousEyeResting = self.eyeResting;
    self.realCalendarPolicyStatsSnapshot = @{
        @"eye": @(self.todayEyeDone),
        @"stand": @(self.todayStandDone),
        @"standSeconds": @(self.todayStandSeconds),
        @"snoozed": @(self.todaySnoozed),
        @"skipped": @(self.todaySkipped),
        @"manualDone": @(self.todayManualDone),
        @"notificationOnly": @(self.todayNotificationOnly),
        @"autoPauseSessions": @(self.todayAutoPauseSessions),
        @"autoPauseSeconds": @(self.todayAutoPauseSeconds)
    };

    self.settings.autoFocusModeEnabled = YES;
    self.settings.calendarFocusModeEnabled = YES;
    [self.settings save];
    self.paused = NO;
    self.pausedUntil = nil;
    self.focusModeEnabled = NO;
    self.restOverlayYielded = NO;
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = [NSDate dateWithTimeIntervalSinceNow:-1];
    if (self.restWindowController) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];
    [self refreshCalendarFocusStateIfNeeded:YES];
    [self refreshFocusModeState];
    [self.settingsWindowController refreshControls];

    if (!self.calendarFocusActive && !self.calendarAutoPauseActive) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.calendarFocusModeEnabled = [previousSettings[@"calendarFocusModeEnabled"] boolValue];
        [self.settings save];
        self.eyeDueAt = previousEyeDueAt;
        self.eyeRestEndsAt = previousEyeRestEndsAt;
        self.eyeResting = previousEyeResting;
        self.realCalendarPolicyStatsSnapshot = nil;
        [self noteRecoveryEventTitle:@"真实日历联动自检" detail:@"当前没有进行中的真实日历事件，跳过"];
        [self publishState];
        return;
    }

    NSString *eventTitle = self.currentCalendarEventTitle.length > 0 ? self.currentCalendarEventTitle : @"当前日程";
    NSString *mode = self.calendarAutoPauseActive ? @"日程暂停" : @"会议只通知";
    [self noteRecoveryEventTitle:@"真实日历联动自检" detail:[NSString stringWithFormat:@"已命中真实%@：%@，开始复查", mode, eventTitle]];
    [self publishState];

    NSArray<NSNumber *> *delays = @[@0.0, @0.8, @1.6];
    for (NSInteger index = 0; index < delays.count; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (generation != self.realCalendarPolicyCheckGeneration) return;
            [self runRealCalendarPolicyCheckPass:index + 1
                                           total:total
                                      generation:generation
                                previousSettings:previousSettings
                                previousEyeDueAt:previousEyeDueAt
                           previousEyeRestEndsAt:previousEyeRestEndsAt
                              previousEyeResting:previousEyeResting];
        });
    }
}

- (void)runRealCalendarPolicyCheckPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousSettings:(NSDictionary<NSString *, id> *)previousSettings previousEyeDueAt:(NSDate *)previousEyeDueAt previousEyeRestEndsAt:(NSDate *)previousEyeRestEndsAt previousEyeResting:(BOOL)previousEyeResting {
    if (generation != self.realCalendarPolicyCheckGeneration) return;

    NSMutableArray<NSString *> *details = [NSMutableArray arrayWithObject:[NSString stringWithFormat:@"%@ %ld/%ld",
                                                                           pass == total ? @"完成" : @"复查",
                                                                           (long)pass,
                                                                           (long)total]];

    if (pass == 1) {
        [self refreshCalendarFocusStateIfNeeded:YES];
        [self refreshFocusModeState];
        BOOL hasRealPolicy = self.calendarFocusActive || self.calendarAutoPauseActive;
        [details addObject:hasRealPolicy ? @"真实日历命中" : @"真实日历未命中"];
        [details addObject:self.calendarAutoPauseActive ? @"真实日程暂停" : (self.calendarFocusActive ? @"真实会议只通知" : @"无真实策略")];
    } else if (pass == 2) {
        [self refreshCalendarFocusStateIfNeeded:YES];
        [self refreshFocusModeState];
        NSDate *beforeDue = self.eyeDueAt;
        NSInteger beforeNotificationOnly = self.todayNotificationOnly;
        NSInteger beforeAutoPauseSeconds = self.todayAutoPauseSeconds;
        if (self.calendarAutoPauseActive) {
            [self tick:nil];
        } else if (self.calendarFocusActive) {
            [self beginRestForKind:ERReminderKindEye];
        }
        BOOL windowClosed = self.restWindowController == nil;
        BOOL notificationOnly = self.calendarFocusActive && self.todayNotificationOnly > beforeNotificationOnly;
        BOOL shifted = self.calendarAutoPauseActive && beforeDue && self.eyeDueAt && [self.eyeDueAt timeIntervalSinceDate:beforeDue] >= 0.5;
        BOOL autoPauseSecondsAdded = self.calendarAutoPauseActive && self.todayAutoPauseSeconds > beforeAutoPauseSeconds;
        if (self.calendarAutoPauseActive) {
            [details addObject:@"真实日程暂停命中"];
            [details addObject:windowClosed ? @"真实日程暂停未弹休息页" : @"真实日程暂停仍有休息页"];
            [details addObject:(shifted || autoPauseSecondsAdded) ? @"真实提醒时间已顺延" : @"真实提醒时间未顺延"];
        } else if (self.calendarFocusActive) {
            [details addObject:notificationOnly ? @"真实会议只发通知" : @"真实会议通知未记录"];
            [details addObject:windowClosed ? @"真实会议未弹休息页" : @"真实会议仍弹休息页"];
        } else {
            [details addObject:@"真实日历状态已变化"];
        }
    } else {
        [details addObject:@"等待还原统计"];
    }

    NSInteger orphaned = [self closeOrphanRestWindows];
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }

    if (pass == total) {
        self.settings.autoFocusModeEnabled = [previousSettings[@"autoFocusModeEnabled"] boolValue];
        self.settings.calendarFocusModeEnabled = [previousSettings[@"calendarFocusModeEnabled"] boolValue];
        [self.settings save];
        NSDictionary<NSString *, NSNumber *> *snapshot = self.realCalendarPolicyStatsSnapshot;
        if (snapshot) {
            self.todayEyeDone = snapshot[@"eye"].integerValue;
            self.todayStandDone = snapshot[@"stand"].integerValue;
            self.todayStandSeconds = snapshot[@"standSeconds"].integerValue;
            self.todaySnoozed = snapshot[@"snoozed"].integerValue;
            self.todaySkipped = snapshot[@"skipped"].integerValue;
            self.todayManualDone = snapshot[@"manualDone"].integerValue;
            self.todayNotificationOnly = snapshot[@"notificationOnly"].integerValue;
            self.todayAutoPauseSessions = snapshot[@"autoPauseSessions"].integerValue;
            self.todayAutoPauseSeconds = snapshot[@"autoPauseSeconds"].integerValue;
            [self saveTodayStats];
        }
        self.realCalendarPolicyStatsSnapshot = nil;
        self.paused = NO;
        self.pausedUntil = nil;
        self.autoPauseActive = NO;
        self.autoPauseSessionActive = NO;
        self.appAutoPauseActive = NO;
        self.autoFocusActive = NO;
        self.calendarFocusActive = NO;
        self.calendarAutoPauseActive = NO;
        self.currentCalendarEventTitle = nil;
        self.eyeDueAt = previousEyeDueAt ?: (self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil);
        self.eyeRestEndsAt = previousEyeRestEndsAt;
        self.eyeResting = previousEyeResting;
        self.restOverlayYielded = NO;
        if (self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        [self closeOrphanRestWindows];
        [self.settingsWindowController refreshControls];
        BOOL restoredStats = snapshot && self.todayNotificationOnly == snapshot[@"notificationOnly"].integerValue && self.todayAutoPauseSeconds == snapshot[@"autoPauseSeconds"].integerValue;
        [details addObject:restoredStats ? @"统计已还原" : @"统计仍需还原"];
        [details addObject:@"测试状态已还原"];
    }

    [self noteRecoveryEventTitle:@"真实日历联动自检" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)yieldRestOverlayForUserFocusChange {
    if (!self.restWindowController || self.settings.restWindowTopmost) return;
    BOOL alreadyYieldedAndHidden = self.restOverlayYielded && !self.restWindowController.window.visible;
    self.restOverlayYielded = YES;
    [self.restWindowController.window orderOut:nil];
    if (!alreadyYieldedAndHidden) {
        [self noteRecoveryEventTitle:@"窗口让开" detail:@"用户切到其他窗口，非置顶休息页已隐藏，本轮计时继续"];
    }
    [self publishState];
}

- (void)cleanupDiagnosticEyeRest {
    self.eyeResting = NO;
    self.eyeRestEndsAt = nil;
    self.eyeDueAt = self.settings.eyeEnabled ? [NSDate dateWithTimeIntervalSinceNow:self.settings.eyeFocusSeconds] : nil;
    self.restOverlayYielded = NO;
    if (self.restWindowController && self.restWindowController.kind == ERReminderKindEye) {
        [self.restWindowController close];
        self.restWindowController = nil;
    }
    [self closeOrphanRestWindows];
}

- (void)showAbout:(id)sender {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"0.1.0";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"1";
    NSString *bundlePath = bundle.bundlePath ?: @"";
    NSString *message = [NSString stringWithFormat:@"版本 %@ (%@)\n\n眼睛休息、站立提醒和番茄休息都在一个轻量菜单栏里。\n\n安装位置：%@\n下载页：%@\n源码：%@", version, build, bundlePath, ERLatestReleaseURLString, ERGitHubURLString];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = ERBrandName;
    alert.informativeText = message;
    alert.icon = [NSImage imageNamed:NSImageNameInfo];
    [alert addButtonWithTitle:@"好"];
    [alert addButtonWithTitle:@"打开 GitHub"];
    [alert addButtonWithTitle:@"打开下载页"];
    [alert addButtonWithTitle:@"复制版本信息"];

    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        NSURL *url = [NSURL URLWithString:ERGitHubURLString];
        if (url) {
            [NSWorkspace.sharedWorkspace openURL:url];
        }
    } else if (response == NSAlertThirdButtonReturn) {
        NSURL *url = [NSURL URLWithString:ERLatestReleaseURLString];
        if (url) {
            [NSWorkspace.sharedWorkspace openURL:url];
        }
    } else if (response == NSAlertThirdButtonReturn + 1) {
        NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
        [pasteboard clearContents];
        [pasteboard setString:[self productSupportSummaryText] forType:NSPasteboardTypeString];
        [self noteRecoveryEventTitle:@"关于" detail:@"已复制版本信息"];
        [self publishState];
    }
}

- (void)openIssueFeedback:(id)sender {
    NSBundle *bundle = NSBundle.mainBundle;
    NSDictionary *info = bundle.infoDictionary;
    NSString *version = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"未知";
    NSString *build = [info[@"CFBundleVersion"] isKindOfClass:NSString.class] ? info[@"CFBundleVersion"] : @"未知";
    NSString *bundlePath = bundle.bundlePath ?: @"未知";
    NSString *systemVersion = NSProcessInfo.processInfo.operatingSystemVersionString ?: @"未知";
    NSString *title = [NSString stringWithFormat:@"%@ 反馈：", ERBrandName];
    NSString *body = [NSString stringWithFormat:
        @"## 发生了什么？\n\n\n\n## 期望行为\n\n\n\n## 诊断信息\n\n- 版本：%@ (%@)\n- 系统：%@\n- 安装位置：%@\n- 下载页：%@\n- 反馈包链接：%@\n\n请先在菜单栏选择「排查中心」->「复制问题反馈包」，再把剪贴板内容粘贴到这里。\n",
        version,
        build,
        systemVersion,
        bundlePath,
        ERLatestReleaseURLString,
        ERAutomationURLString(@"diagnostics/issue-bundle")];

    NSURLComponents *components = [NSURLComponents componentsWithString:ERNewIssueURLString];
    components.queryItems = @[
        [NSURLQueryItem queryItemWithName:@"title" value:title],
        [NSURLQueryItem queryItemWithName:@"body" value:body]
    ];

    NSURL *url = components.URL ?: [NSURL URLWithString:ERNewIssueURLString];
    if (url) {
        [NSWorkspace.sharedWorkspace openURL:url];
        [self noteRecoveryEventTitle:@"反馈" detail:@"已打开 GitHub Issues"];
        [self publishState];
    }
}

- (void)checkForUpdates:(id)sender {
    NSURL *apiURL = [NSURL URLWithString:ERLatestReleaseAPIURLString];
    if (!apiURL) return;

    NSURLSessionConfiguration *configuration = NSURLSessionConfiguration.ephemeralSessionConfiguration;
    configuration.timeoutIntervalForRequest = 12;
    NSURLSession *session = [NSURLSession sessionWithConfiguration:configuration];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:apiURL];
    [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
    [request setValue:@"SongYiXia" forHTTPHeaderField:@"User-Agent"];

    [self noteRecoveryEventTitle:@"更新" detail:@"正在检查最新版本"];
    [self publishState];

    NSURLSessionDataTask *task = [session dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSBundle *bundle = NSBundle.mainBundle;
            NSDictionary *info = bundle.infoDictionary;
            NSString *currentVersion = [info[@"CFBundleShortVersionString"] isKindOfClass:NSString.class] ? info[@"CFBundleShortVersionString"] : @"0.0.0";
            NSString *latestVersion = nil;
            NSString *releaseName = nil;
            NSString *releaseURLString = ERLatestReleaseURLString;
            NSString *downloadURLString = nil;
            NSString *downloadAssetName = nil;

            if (!error && data.length > 0) {
                id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([object isKindOfClass:NSDictionary.class]) {
                    NSDictionary *release = (NSDictionary *)object;
                    NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : nil;
                    latestVersion = [[tag ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"vV"]];
                    releaseName = [release[@"name"] isKindOfClass:NSString.class] ? release[@"name"] : nil;
                    releaseURLString = [release[@"html_url"] isKindOfClass:NSString.class] ? release[@"html_url"] : ERLatestReleaseURLString;
                    NSArray *assets = [release[@"assets"] isKindOfClass:NSArray.class] ? release[@"assets"] : @[];
                    for (id item in assets) {
                        if (![item isKindOfClass:NSDictionary.class]) continue;
                        NSDictionary *asset = (NSDictionary *)item;
                        NSString *name = [asset[@"name"] isKindOfClass:NSString.class] ? asset[@"name"] : @"";
                        NSString *url = [asset[@"browser_download_url"] isKindOfClass:NSString.class] ? asset[@"browser_download_url"] : nil;
                        if (url.length == 0) continue;
                        NSString *lowerName = name.lowercaseString;
                        if ([lowerName hasPrefix:@"songyixia-"] && [lowerName hasSuffix:@".zip"]) {
                            downloadURLString = url;
                            downloadAssetName = name;
                            break;
                        }
                        if (!downloadURLString && [lowerName hasSuffix:@".zip"]) {
                            downloadURLString = url;
                            downloadAssetName = name.length > 0 ? name : @"zip";
                        }
                    }
                }
            }

            NSAlert *alert = [[NSAlert alloc] init];
            alert.icon = [NSImage imageNamed:NSImageNameInfo];
            [NSApp activateIgnoringOtherApps:YES];

            if (latestVersion.length == 0) {
                alert.messageText = @"暂时无法检查更新";
                alert.informativeText = error.localizedDescription.length > 0
                    ? error.localizedDescription
                    : @"没有拿到 GitHub 最新版本信息。";
                [alert addButtonWithTitle:@"打开下载页"];
                [alert addButtonWithTitle:@"好"];
                if ([alert runModal] == NSAlertFirstButtonReturn) {
                    NSURL *url = [NSURL URLWithString:ERLatestReleaseURLString];
                    if (url) [NSWorkspace.sharedWorkspace openURL:url];
                }
                [self noteRecoveryEventTitle:@"更新" detail:@"检查失败"];
                [self publishState];
                return;
            }

            NSInteger compare = ERCompareVersionStrings(currentVersion, latestVersion);
            if (compare < 0) {
                alert.messageText = @"发现新版本";
                NSString *assetText = downloadAssetName.length > 0 ? [NSString stringWithFormat:@"\n可直接下载：%@", downloadAssetName] : @"";
                alert.informativeText = [NSString stringWithFormat:@"当前版本 %@，最新版本 %@%@。%@", currentVersion, latestVersion, releaseName.length > 0 ? [NSString stringWithFormat:@"（%@）", releaseName] : @"", assetText];
                [alert addButtonWithTitle:downloadURLString.length > 0 ? @"下载 zip" : @"打开下载页"];
                [alert addButtonWithTitle:@"打开发布页"];
                [alert addButtonWithTitle:@"稍后"];
                NSModalResponse response = [alert runModal];
                if (response == NSAlertFirstButtonReturn) {
                    NSURL *url = [NSURL URLWithString:downloadURLString.length > 0 ? downloadURLString : releaseURLString];
                    if (url) [NSWorkspace.sharedWorkspace openURL:url];
                } else if (response == NSAlertSecondButtonReturn) {
                    NSURL *url = [NSURL URLWithString:releaseURLString];
                    if (url) [NSWorkspace.sharedWorkspace openURL:url];
                }
                [self noteRecoveryEventTitle:@"更新" detail:[NSString stringWithFormat:@"发现 %@%@", latestVersion, downloadAssetName.length > 0 ? [NSString stringWithFormat:@" · %@", downloadAssetName] : @""]];
            } else {
                alert.messageText = @"已经是最新版本";
                alert.informativeText = [NSString stringWithFormat:@"当前版本 %@，GitHub 最新版本 %@。", currentVersion, latestVersion];
                [alert addButtonWithTitle:@"好"];
                [alert addButtonWithTitle:@"打开发布页"];
                if ([alert runModal] == NSAlertSecondButtonReturn) {
                    NSURL *url = [NSURL URLWithString:releaseURLString];
                    if (url) [NSWorkspace.sharedWorkspace openURL:url];
                }
                [self noteRecoveryEventTitle:@"更新" detail:[NSString stringWithFormat:@"已是最新 %@", latestVersion]];
            }
            [self publishState];
        });
    }];
    [task resume];
}

- (void)handleRecoveryStressTestRequest:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self runRecoveryStressTest:nil];
    });
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    NSString *urlString = [[event paramDescriptorForKeyword:keyDirectObject] stringValue];
    NSURL *url = [NSURL URLWithString:urlString ?: @""];
    if (![self handleAutomationURL:url]) {
        [self noteRecoveryEventTitle:@"外部自动化" detail:[NSString stringWithFormat:@"无法识别链接 %@", urlString ?: @""]];
        [self publishState];
    }
}

- (BOOL)handleAutomationURL:(NSURL *)url {
    if (!url || ![url.scheme.lowercaseString isEqualToString:ERAutomationURLScheme]) return NO;

    NSArray<NSString *> *parts = ERAutomationURLPathParts(url);
    NSString *command = parts.count > 0 ? parts[0] : @"settings";
    NSString *argument = parts.count > 1 ? parts[1] : @"";
    NSString *detail = nil;

    if ([command isEqualToString:@"settings"] || [command isEqualToString:@"open-settings"]) {
        if (argument.length > 0) {
            [self presentSettingsPage:argument];
            detail = [NSString stringWithFormat:@"打开设置 %@", argument];
        } else {
            [self presentSettingsWindow];
            detail = @"打开设置";
        }
    } else if ([command isEqualToString:@"setup"] || [command isEqualToString:@"quick-setup"]) {
        NSString *profile = argument.length > 0 ? argument : @"balanced";
        [self applyQuickSetupProfile:profile];
        detail = [NSString stringWithFormat:@"快速配置 %@", profile];
    } else if ([command isEqualToString:@"focus"] || [command isEqualToString:@"work"] || [command isEqualToString:@"quiet"]) {
        BOOL desired = YES;
        if ([argument isEqualToString:@"off"] || [argument isEqualToString:@"false"] || [argument isEqualToString:@"0"] || [argument isEqualToString:@"disable"]) {
            desired = NO;
        } else if ([argument isEqualToString:@"toggle"]) {
            desired = !self.focusModeEnabled;
        }
        self.focusModeEnabled = desired;
        if (self.focusModeEnabled && self.restWindowController) {
            [self.restWindowController close];
            self.restWindowController = nil;
        }
        if (!self.focusModeEnabled) {
            [self repairRestStateIfNeeded];
        }
        detail = self.focusModeEnabled ? @"轻打扰开启" : @"轻打扰关闭";
    } else if ([command isEqualToString:@"pause"]) {
        if ([argument isEqualToString:@"today"]) {
            [self pauseToday:nil];
            detail = @"暂停到明天";
        } else if ([argument isEqualToString:@"off"] || [argument isEqualToString:@"resume"]) {
            if (self.paused) {
                [self resumeFromPause];
            }
            detail = @"继续提醒";
        } else {
            NSTimeInterval seconds = ERAutomationDurationSecondsFromToken(argument);
            if (seconds <= 0) return NO;
            [self pauseForSeconds:seconds];
            detail = [NSString stringWithFormat:@"暂停 %@", ERFormatDuration(seconds)];
        }
    } else if ([command isEqualToString:@"resume"]) {
        if (self.paused) {
            [self resumeFromPause];
        }
        detail = @"继续提醒";
    } else if ([command isEqualToString:@"rest"]) {
        if ([argument isEqualToString:@"eye"]) {
            if (!self.settings.eyeEnabled) return NO;
            [self beginRestForKind:ERReminderKindEye];
            detail = @"立即眼睛休息";
        } else if ([argument isEqualToString:@"stand"]) {
            if (!self.settings.standEnabled) return NO;
            [self beginRestForKind:ERReminderKindStand];
            detail = @"立即站立";
        } else {
            return NO;
        }
    } else if ([command isEqualToString:@"rhythm"] || [command isEqualToString:@"preset"]) {
        if (![self applyQuickRhythmToken:argument detail:&detail]) return NO;
    } else if ([command isEqualToString:@"diagnostics"] || [command isEqualToString:@"diagnostic"] || [command isEqualToString:@"recovery"]) {
        if ([argument isEqualToString:@"recovery-stress"] || [argument isEqualToString:@"stress"]) {
            [self runRecoveryStressTest:nil];
            detail = @"运行恢复压测";
        } else if ([argument isEqualToString:@"lunch-recovery"] || [argument isEqualToString:@"lunch"] || [argument isEqualToString:@"stand-expired"]) {
            [self runLunchRecoveryStressTest:nil];
            detail = @"运行午休恢复压测";
        } else if ([argument isEqualToString:@"sleep-hidden-recovery"] || [argument isEqualToString:@"sleep-hidden"] || [argument isEqualToString:@"hidden-recovery"]) {
            [self runSleepHiddenRecoveryStressTest:nil];
            detail = @"运行睡眠隐藏恢复压测";
        } else if ([argument isEqualToString:@"long-away-recovery"] || [argument isEqualToString:@"long-away"] || [argument isEqualToString:@"both-expired"]) {
            [self runLongAwayRecoveryStressTest:nil];
            detail = @"运行长离开恢复压测";
        } else if ([argument isEqualToString:@"display-recovery"] || [argument isEqualToString:@"display"] || [argument isEqualToString:@"screen"]) {
            [self runDisplayRecoveryStressTest:nil];
            detail = @"运行显示恢复压测";
        } else if ([argument isEqualToString:@"settings-window"] || [argument isEqualToString:@"settings-recovery"] || [argument isEqualToString:@"settings-display"]) {
            [self runSettingsWindowRecoveryStressTest:nil];
            detail = @"运行设置窗口恢复压测";
        } else if ([argument isEqualToString:@"display-bounds"] || [argument isEqualToString:@"bounds"] || [argument isEqualToString:@"screen-bounds"]) {
            [self runDisplayBoundsStressTest:nil];
            detail = @"运行显示边界压测";
        } else if ([argument isEqualToString:@"display-live"] || [argument isEqualToString:@"screen-live"]) {
            [self runRealDisplayCheck:nil];
            detail = @"运行真实显示环境自检";
        } else if ([argument isEqualToString:@"display-real"] || [argument isEqualToString:@"display-diagnostic"] || [argument isEqualToString:@"screen-diagnostic"] || [argument isEqualToString:@"screen-real"]) {
            [self copyDisplayDiagnostic:nil];
            detail = @"复制显示环境诊断";
        } else if ([argument isEqualToString:@"recovery-matrix"] || [argument isEqualToString:@"matrix"] || [argument isEqualToString:@"recovery-plan"] || [argument isEqualToString:@"scenario-matrix"]) {
            [self copyRecoveryMatrixDiagnostic:nil];
            detail = @"复制恢复场景矩阵";
        } else if ([argument isEqualToString:@"recovery-report"] || [argument isEqualToString:@"report"] || [argument isEqualToString:@"issue-report"] || [argument isEqualToString:@"summary-report"]) {
            [self copyRecoveryReportDiagnostic:nil];
            detail = @"复制恢复问题报告";
        } else if ([argument isEqualToString:@"issue-bundle"] || [argument isEqualToString:@"feedback-bundle"] || [argument isEqualToString:@"issue"] || [argument isEqualToString:@"feedback"]) {
            [self copyIssueBundleDiagnostic:nil];
            detail = @"复制问题反馈包";
        } else if ([argument isEqualToString:@"support-bundle"] || [argument isEqualToString:@"support"] || [argument isEqualToString:@"bundle"] || [argument isEqualToString:@"full"]) {
            [self copySupportBundleDiagnostic:nil];
            detail = @"复制完整排查包";
        } else if ([argument isEqualToString:@"roadmap-status"] || [argument isEqualToString:@"roadmap"] || [argument isEqualToString:@"todo"]) {
            [self copyRoadmapStatus:nil];
            detail = @"复制路线图状态";
        } else if ([argument isEqualToString:@"auto-update-readiness"] || [argument isEqualToString:@"auto-update"] || [argument isEqualToString:@"sparkle-readiness"]) {
            [self copyAutoUpdateReadiness:nil];
            detail = @"复制自动更新评估";
        } else if ([argument isEqualToString:@"display-change-trace"] || [argument isEqualToString:@"display-trace"] || [argument isEqualToString:@"screen-change-trace"]) {
            [self runDisplayChangeTraceSelfCheck:nil];
            detail = @"运行显示变化追踪自检";
        } else if ([argument isEqualToString:@"overlay-yield"] || [argument isEqualToString:@"yield"] || [argument isEqualToString:@"window-yield"]) {
            [self runOverlayYieldStressTest:nil];
            detail = @"运行窗口让开压测";
        } else if ([argument isEqualToString:@"window-layer"] || [argument isEqualToString:@"layer"] || [argument isEqualToString:@"topmost-policy"]) {
            [self runWindowLayerPolicyStressTest:nil];
            detail = @"运行窗口层级压测";
        } else if ([argument isEqualToString:@"recovery-matrix-suite"] || [argument isEqualToString:@"matrix-suite"] || [argument isEqualToString:@"recovery-suite"] || [argument isEqualToString:@"suite"]) {
            [self runRecoveryMatrixSuite:nil];
            detail = @"运行恢复矩阵套件";
        } else if ([argument isEqualToString:@"automation-policy"] || [argument isEqualToString:@"automation"] || [argument isEqualToString:@"policy"]) {
            [self runAutomationPolicyStressTest:nil];
            detail = @"运行自动化策略压测";
        } else if ([argument isEqualToString:@"presentation-policy"] || [argument isEqualToString:@"presentation"] || [argument isEqualToString:@"fullscreen-policy"]) {
            [self runPresentationPolicyStressTest:nil];
            detail = @"运行演示策略压测";
        } else if ([argument isEqualToString:@"presentation-live"] || [argument isEqualToString:@"presentation-real"] || [argument isEqualToString:@"fullscreen-live"]) {
            [self runRealPresentationPolicyCheck:nil];
            detail = @"运行真实演示联动自检";
        } else if ([argument isEqualToString:@"calendar-policy"] || [argument isEqualToString:@"calendar"] || [argument isEqualToString:@"calendar-focus"]) {
            [self runCalendarPolicyStressTest:nil];
            detail = @"运行日历策略压测";
        } else if ([argument isEqualToString:@"calendar-live"] || [argument isEqualToString:@"calendar-real-policy"] || [argument isEqualToString:@"calendar-e2e"]) {
            [self runRealCalendarPolicyCheck:nil];
            detail = @"运行真实日历联动自检";
        } else if ([argument isEqualToString:@"calendar-real"] || [argument isEqualToString:@"calendar-diagnostic"] || [argument isEqualToString:@"calendar-status"]) {
            [self copyCalendarDiagnostic:nil];
            detail = @"复制真实日历诊断";
        } else {
            [self copyRecoveryDiagnostic:nil];
            detail = @"复制恢复诊断";
        }
    } else if ([command isEqualToString:@"automation"] || [command isEqualToString:@"shortcut"] || [command isEqualToString:@"template"]) {
        if ([argument isEqualToString:@"focus-template"] || [argument isEqualToString:@"focus"] || [argument isEqualToString:@"script"]) {
            [self copyFocusAutomationTemplate:nil];
            detail = @"复制专注联动脚本";
        } else if ([argument isEqualToString:@"diagnostic"] || [argument isEqualToString:@"diagnostics"] || [argument isEqualToString:@"status"]) {
            [self copyAutomationDiagnostic:nil];
            detail = @"复制自动化诊断";
        } else {
            return NO;
        }
    } else if ([command isEqualToString:@"backup"]) {
        if ([argument isEqualToString:@"import"] || [argument isEqualToString:@"restore"]) {
            [self presentSettingsWindow];
            [self.settingsWindowController importBackupJSON:nil];
            detail = @"打开 JSON 恢复";
        } else {
            return NO;
        }
    } else if ([command isEqualToString:@"emergency"]) {
        [self emergencyCloseRestOverlay:nil];
        detail = @"应急关闭休息页";
    } else {
        return NO;
    }

    if (detail.length > 0) {
        [self noteRecoveryEventTitle:@"外部自动化" detail:detail];
    }
    [self publishState];
    return YES;
}

- (NSString *)automationDiagnosticText {
    NSBundle *bundle = NSBundle.mainBundle;
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 自动化诊断", ERBrandName]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"URL Scheme：%@", ERAutomationURLScheme]];
    [lines addObject:[NSString stringWithFormat:@"Bundle ID：%@", bundle.bundleIdentifier ?: @"未知"]];
    [lines addObject:[NSString stringWithFormat:@"安装位置：%@", bundle.bundlePath ?: @"未知"]];
    [lines addObject:@"常用链接："];
    [lines addObject:[NSString stringWithFormat:@"- 专注开始：%@", ERAutomationURLString(@"focus/on")]];
    [lines addObject:[NSString stringWithFormat:@"- 专注结束：%@", ERAutomationURLString(@"focus/off")]];
    [lines addObject:[NSString stringWithFormat:@"- 切换轻打扰：%@", ERAutomationURLString(@"focus/toggle")]];
    [lines addObject:[NSString stringWithFormat:@"- 专注联动模板：%@", ERAutomationURLString(@"automation/focus-template")]];
    [lines addObject:[NSString stringWithFormat:@"- 暂停 30 分钟：%@", ERAutomationURLString(@"pause/30m")]];
    [lines addObject:[NSString stringWithFormat:@"- 继续提醒：%@", ERAutomationURLString(@"resume")]];
    [lines addObject:[NSString stringWithFormat:@"- 设置窗口恢复压测：%@", ERAutomationURLString(@"diagnostics/settings-window")]];
    [lines addObject:[NSString stringWithFormat:@"- 问题反馈包：%@", ERAutomationURLString(@"diagnostics/issue-bundle")]];
    [lines addObject:[NSString stringWithFormat:@"- 显示环境诊断：%@", ERAutomationURLString(@"diagnostics/display-real")]];
    [lines addObject:[NSString stringWithFormat:@"- 恢复场景矩阵：%@", ERAutomationURLString(@"diagnostics/recovery-matrix")]];
    [lines addObject:[NSString stringWithFormat:@"- 恢复问题报告：%@", ERAutomationURLString(@"diagnostics/recovery-report")]];
    [lines addObject:[NSString stringWithFormat:@"- 恢复矩阵套件：%@", ERAutomationURLString(@"diagnostics/recovery-matrix-suite")]];
    [lines addObject:[NSString stringWithFormat:@"- 完整排查包：%@", ERAutomationURLString(@"diagnostics/support-bundle")]];
    [lines addObject:[NSString stringWithFormat:@"- 路线图状态：%@", ERAutomationURLString(@"diagnostics/roadmap-status")]];
    [lines addObject:[NSString stringWithFormat:@"- 显示变化追踪自检：%@", ERAutomationURLString(@"diagnostics/display-change-trace")]];
    [lines addObject:[NSString stringWithFormat:@"- 真实显示环境自检：%@", ERAutomationURLString(@"diagnostics/display-live")]];
    [lines addObject:[NSString stringWithFormat:@"- 真实演示联动自检：%@", ERAutomationURLString(@"diagnostics/presentation-live")]];
    [lines addObject:[NSString stringWithFormat:@"- 真实日历诊断：%@", ERAutomationURLString(@"diagnostics/calendar-real")]];
    [lines addObject:[NSString stringWithFormat:@"- 真实日历联动自检：%@", ERAutomationURLString(@"diagnostics/calendar-live")]];
    [lines addObject:[NSString stringWithFormat:@"自动化状态：%@", [self focusModeStatusText]]];
    [lines addObject:@"策略结论："];
    [lines addObject:[self automationPolicyExplanation][@"diagnostic"] ?: @"暂无自动化策略结论。"];
    [lines addObject:[NSString stringWithFormat:@"轻打扰：manual=%@ auto=%@ autoPause=%@ ignored=%@ presentation=%@ quiet=%@ calendar=%@ calendarPause=%@",
                      self.focusModeEnabled ? @"YES" : @"NO",
                      self.autoFocusActive ? @"YES" : @"NO",
                      self.autoPauseActive ? @"YES" : @"NO",
                      self.autoIgnoreActive ? @"YES" : @"NO",
                      self.presentationFocusActive ? @"YES" : @"NO",
                      self.quietHoursActive ? @"YES" : @"NO",
                      self.calendarFocusActive ? @"YES" : @"NO",
                      self.calendarAutoPauseActive ? @"YES" : @"NO"]];
    [lines addObject:[NSString stringWithFormat:@"前台应用：%@ · %@",
                      self.frontmostAppName.length > 0 ? self.frontmostAppName : @"未知",
                      self.frontmostAppBundleIdentifier.length > 0 ? self.frontmostAppBundleIdentifier : @"未知 bundle"]];
    [lines addObject:[NSString stringWithFormat:@"安静时段：%@ %@-%@",
                      self.settings.quietHoursEnabled ? @"开" : @"关",
                      ERFormatClockMinute(self.settings.quietHoursStartMinute),
                      ERFormatClockMinute(self.settings.quietHoursEndMinute)]];
    [lines addObject:[NSString stringWithFormat:@"自动策略：%@ · 日历 %@ · 演示 %@",
                      self.settings.autoFocusModeEnabled ? @"开" : @"关",
                      self.settings.calendarFocusModeEnabled ? @"开" : @"关",
                      self.settings.presentationFocusModeEnabled ? @"开" : @"关"]];
    [lines addObject:[NSString stringWithFormat:@"应用策略数量：轻打扰 %ld · 自动暂停 %ld · 忽略 %ld",
                      (long)self.settings.focusAppTokens.count,
                      (long)self.settings.autoPauseAppTokens.count,
                      (long)self.settings.ignoreAppTokens.count]];
    [lines addObject:[NSString stringWithFormat:@"日程策略数量：只通知 %ld · 自动暂停 %ld",
                      (long)self.settings.calendarFocusTokens.count,
                      (long)self.settings.calendarAutoPauseTokens.count]];
    [lines addObject:[self recoveryDiagnosticText]];
    return [lines componentsJoinedByString:@"\n"];
}

- (NSString *)focusAutomationTemplateText {
    NSString *focusOn = ERAutomationURLString(@"focus/on");
    NSString *focusOff = ERAutomationURLString(@"focus/off");
    NSString *focusToggle = ERAutomationURLString(@"focus/toggle");
    NSString *pause30 = ERAutomationURLString(@"pause/30m");
    NSString *resume = ERAutomationURLString(@"resume");
    NSString *settings = ERAutomationURLString(@"settings");
    return [NSString stringWithFormat:
        @"# 松一下 · 专注/勿扰联动模板\n"
        @"\n"
        @"## 常用链接\n"
        @"- 专注开始：%@\n"
        @"- 专注结束：%@\n"
        @"- 切换轻打扰：%@\n"
        @"- 暂停 30 分钟：%@\n"
        @"- 继续提醒：%@\n"
        @"- 打开设置：%@\n"
        @"\n"
        @"## macOS 快捷指令\n"
        @"1. 新建快捷指令，添加“打开 URL”。\n"
        @"2. 专注开始时打开 %@。\n"
        @"3. 专注结束时打开 %@。\n"
        @"\n"
        @"## Hammerspoon 示例\n"
        @"local function openSongYiXia(path)\n"
        @"  hs.urlevent.openURL('songyixia://' .. path)\n"
        @"end\n"
        @"\n"
        @"hs.hotkey.bind({'cmd', 'alt', 'ctrl'}, 'F', function()\n"
        @"  openSongYiXia('focus/toggle')\n"
        @"end)\n"
        @"\n"
        @"hs.hotkey.bind({'cmd', 'alt', 'ctrl'}, 'P', function()\n"
        @"  openSongYiXia('pause/30m')\n"
        @"end)\n"
        @"\n"
        @"hs.hotkey.bind({'cmd', 'alt', 'ctrl'}, 'R', function()\n"
        @"  openSongYiXia('resume')\n"
        @"end)\n"
        @"\n"
        @"## Raycast Script Command 示例\n"
        @"#!/bin/bash\n"
        @"# @raycast.schemaVersion 1\n"
        @"# @raycast.title 松一下 · 切换轻打扰\n"
        @"# @raycast.mode silent\n"
        @"open 'songyixia://focus/toggle'\n"
        @"\n"
        @"#!/bin/bash\n"
        @"# @raycast.schemaVersion 1\n"
        @"# @raycast.title 松一下 · 暂停 30 分钟\n"
        @"# @raycast.mode silent\n"
        @"open 'songyixia://pause/30m'\n",
        focusOn,
        focusOff,
        focusToggle,
        pause30,
        resume,
        settings,
        focusOn,
        focusOff];
}

- (void)copyAutomationURL:(NSMenuItem *)sender {
    NSString *urlString = [sender.representedObject isKindOfClass:NSString.class] ? sender.representedObject : @"";
    if (urlString.length == 0) return;
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:urlString forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"外部自动化" detail:[NSString stringWithFormat:@"已复制 %@", urlString]];
    [self publishState];
}

- (void)copyFocusAutomationTemplate:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self focusAutomationTemplateText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"外部自动化" detail:@"已复制专注联动脚本"];
    [self publishState];
}

- (void)copyAutomationDiagnostic:(id)sender {
    NSPasteboard *pasteboard = NSPasteboard.generalPasteboard;
    [pasteboard clearContents];
    [pasteboard setString:[self automationDiagnosticText] forType:NSPasteboardTypeString];
    [self noteRecoveryEventTitle:@"外部自动化" detail:@"已复制自动化诊断"];
    [self publishState];
}

- (void)handleOpenSettingsRequest:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentSettingsWindow];
    });
}

- (void)presentSettingsPage:(NSString *)pageToken {
    [self presentSettingsWindow];
    NSString *token = pageToken.lowercaseString ?: @"";
    NSInteger pageIndex = 0;
    if ([token isEqualToString:@"eye"] || [token isEqualToString:@"eyes"] || [token containsString:@"眼"]) {
        pageIndex = 1;
    } else if ([token isEqualToString:@"stand"] || [token containsString:@"站"]) {
        pageIndex = 2;
    } else if ([token isEqualToString:@"display"] || [token isEqualToString:@"style"] || [token containsString:@"显示"]) {
        pageIndex = 3;
    } else if ([token isEqualToString:@"automation"] || [token isEqualToString:@"auto"] || [token containsString:@"自动"]) {
        pageIndex = 4;
    } else if ([token isEqualToString:@"stats"] || [token isEqualToString:@"statistics"] || [token containsString:@"统计"]) {
        pageIndex = 5;
    }
    [self.settingsWindowController setSelectedPageIndex:pageIndex];
}

- (void)openSettings:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self presentSettingsWindow];
    });
}

- (void)presentSettingsWindow {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyRegular];
    if (!self.settingsWindowController) {
        self.settingsWindowController = [[ERSettingsWindowController alloc] initWithSettings:self.settings appDelegate:self];
    }
    BOOL shouldShowQuickSetup = ![NSUserDefaults.standardUserDefaults boolForKey:ERSettingsQuickSetupSeenKey];
    [self.settingsWindowController refreshControls];
    NSWindow *settingsWindow = self.settingsWindowController.window;
    settingsWindow.level = NSNormalWindowLevel;
    settingsWindow.collectionBehavior = NSWindowCollectionBehaviorManaged;
    [self repairSettingsWindowAfterDisplayChange];
    [self.settingsWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [settingsWindow makeKeyAndOrderFront:nil];
    if (shouldShowQuickSetup) {
        [NSUserDefaults.standardUserDefaults setBool:YES forKey:ERSettingsQuickSetupSeenKey];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            if (settingsWindow.visible) {
                [self showQuickSetup:nil];
            }
        });
    }
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
    [self.restWindowController applyWindowLevelForSettings:self.settings];
    [self publishState];
}

- (void)toggleRestWindowTopmost:(id)sender {
    self.settings.restWindowTopmost = !self.settings.restWindowTopmost;
    if (self.settings.restWindowTopmost) {
        self.restOverlayYielded = NO;
    }
    [self.settings save];
    [self.settingsWindowController refreshControls];
    [self.restWindowController applyWindowLevelForSettings:self.settings];
    if (self.restWindowController && self.settings.restWindowTopmost) {
        [self.restWindowController presentOverlay];
    }
    [self publishState];
}

@end

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        if (!ERAcquireSingleInstanceLock()) {
            ERPostOpenSettingsRequest();
            return 0;
        }
        NSApplication *application = NSApplication.sharedApplication;
        ERAppDelegate *delegate = [[ERAppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}
