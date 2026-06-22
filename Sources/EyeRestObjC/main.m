#import <Cocoa/Cocoa.h>
#import <UserNotifications/UserNotifications.h>
#import <EventKit/EventKit.h>
#import <QuartzCore/QuartzCore.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import <Carbon/Carbon.h>
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
static const NSUInteger ERRecoveryHistoryLimit = 20;
static int ERSingleInstanceLockFD = -1;

static NSInteger ERClampInteger(NSInteger value, NSInteger minimum, NSInteger maximum);
static NSInteger ERCompareVersionStrings(NSString *left, NSString *right);

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
@property(nonatomic, strong) NSArray<NSString *> *actionStageTitles;
@property(nonatomic, strong) NSArray<NSString *> *actionStageMessages;
@property(nonatomic, strong) NSArray<NSString *> *actionSuggestions;
@property(nonatomic, strong) NSArray<NSString *> *actionSuggestionSymbols;
@property(nonatomic) NSInteger activeSuggestionIndex;
@property(nonatomic) NSTimeInterval totalDuration;
@property(nonatomic) ERRestStyle currentStyle;
- (instancetype)initWithAppDelegate:(ERAppDelegate *)appDelegate;
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
@property(nonatomic, strong) NSButton *standEnabledSwitch;
@property(nonatomic, strong) ERTimeInput *standIntervalInput;
@property(nonatomic, strong) ERTimeInput *standDurationInput;
@property(nonatomic, strong) NSPopUpButton *standRoutinePopup;
@property(nonatomic, strong) NSTextField *standRoutineHintLabel;
@property(nonatomic, strong) NSPopUpButton *standIntensityPopup;
@property(nonatomic, strong) NSTextField *standIntensityHintLabel;
@property(nonatomic, strong) NSButton *standCustomStagesButton;
@property(nonatomic, strong) NSTextField *standCustomStagesSummaryLabel;
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
@property(nonatomic, strong) NSButton *focusAppResetButton;
@property(nonatomic, strong) NSPopUpButton *menuBarModePopup;
@property(nonatomic, strong) NSPopUpButton *restStylePopup;
@property(nonatomic, strong) NSTextField *summaryLabel;
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
@property(nonatomic, strong) NSView *eyeCard;
@property(nonatomic, strong) NSView *standCard;
@property(nonatomic, strong) NSView *alertCard;
@property(nonatomic, strong) NSView *automationCard;
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
- (void)refreshAutomationStatus;
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
@property(nonatomic, strong) NSDate *lastStandCompletedAt;
@property(nonatomic, copy) NSString *lastStandCompletionText;
@property(nonatomic, copy) NSString *lastStandCompletionAdvice;
@property(nonatomic, strong) NSDate *lastSystemEventAt;
@property(nonatomic, copy) NSString *lastSystemEventTitle;
@property(nonatomic, copy) NSString *lastRecoveryDetail;
@property(nonatomic, strong) NSMutableArray<NSDictionary<NSString *, id> *> *recoveryEventHistory;
@property(nonatomic) NSUInteger recoveryFollowUpGeneration;
@property(nonatomic) NSUInteger recoveryStressTestGeneration;
@property(nonatomic) NSUInteger lunchRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger sleepHiddenRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger displayRecoveryStressTestGeneration;
@property(nonatomic) NSUInteger displayBoundsStressTestGeneration;
@property(nonatomic) NSUInteger overlayYieldStressTestGeneration;
@property(nonatomic) NSUInteger longAwayRecoveryStressTestGeneration;
@property(nonatomic, strong) NSDictionary<NSString *, NSNumber *> *longAwayRecoveryStatsSnapshot;
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
- (void)repairRestOverlayAfterSystemEvent:(NSNotification *)notification;
- (void)scheduleRecoveryFollowUpChecksWithTitle:(NSString *)eventTitle;
- (void)runRecoveryFollowUpCheckWithTitle:(NSString *)eventTitle pass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)applicationDidResignActive:(NSNotification *)notification;
- (void)frontmostApplicationDidChange:(NSNotification *)notification;
- (void)activeSpaceDidChange:(NSNotification *)notification;
- (void)repairRestStateIfNeeded;
- (NSInteger)closeOrphanRestWindows;
- (void)noteRecoveryEventTitle:(NSString *)title detail:(NSString *)detail;
- (NSString *)recoveryDiagnosticText;
- (NSArray<NSString *> *)recoveryHistoryLines;
- (NSString *)detailedRecoveryDiagnosticText;
- (NSString *)applicationDiagnosticText;
- (void)copyRecoveryDiagnostic:(id)sender;
- (void)copyApplicationDiagnostic:(id)sender;
- (void)runRecoverySelfCheck:(id)sender;
- (void)runRecoveryStressTest:(id)sender;
- (void)handleRecoveryStressTestRequest:(NSNotification *)notification;
- (void)runRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runLunchRecoveryStressTest:(id)sender;
- (void)runLunchRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runSleepHiddenRecoveryStressTest:(id)sender;
- (void)runSleepHiddenRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation previousTopmost:(BOOL)previousTopmost;
- (void)runDisplayRecoveryStressTest:(id)sender;
- (void)runDisplayRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runDisplayBoundsStressTest:(id)sender;
- (void)runDisplayBoundsStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
- (void)runOverlayYieldStressTest:(id)sender;
- (void)runOverlayYieldStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation;
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
- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent;
- (BOOL)handleAutomationURL:(NSURL *)url;
- (void)copyAutomationURL:(NSMenuItem *)sender;
- (NSString *)focusAutomationTemplateText;
- (void)copyFocusAutomationTemplate:(id)sender;
- (NSString *)automationDiagnosticText;
- (void)copyAutomationDiagnostic:(id)sender;
- (void)presentSettingsWindow;
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
- (void)shiftReminderDatesBySeconds:(NSTimeInterval)seconds;
- (BOOL)isQuietHoursActiveNow;
- (BOOL)isLightDistractionModeActive;
- (NSString *)focusModeStatusText;
- (void)updateStatusItemAppearance;
- (NSDictionary *)statsHistoryIncludingToday;
@end

@implementation ERSettingsWindowController

- (instancetype)initWithSettings:(ERSettings *)settings appDelegate:(ERAppDelegate *)appDelegate {
    NSRect frame = NSMakeRect(0, 0, 780, 540);
    ERSettingsWindow *window = [[ERSettingsWindow alloc] initWithContentRect:frame
                                                                   styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable | NSWindowStyleMaskMiniaturizable
                                                                     backing:NSBackingStoreBuffered
                                                                       defer:NO];
    self = [super initWithWindow:window];
    if (!self) return nil;

    self.settings = settings;
    self.appDelegate = appDelegate;
    window.title = [NSString stringWithFormat:@"%@ 设置", ERBrandName];
    window.delegate = self;
    window.releasedWhenClosed = NO;
    window.level = NSNormalWindowLevel;
    window.collectionBehavior = NSWindowCollectionBehaviorManaged;
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
    self.paneControl.segmentCount = 5;
    [self.paneControl setLabel:@"眼睛" forSegment:0];
    [self.paneControl setLabel:@"站立" forSegment:1];
    [self.paneControl setLabel:@"显示" forSegment:2];
    [self.paneControl setLabel:@"自动" forSegment:3];
    [self.paneControl setLabel:@"统计" forSegment:4];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"eye" accessibilityDescription:@"眼睛"] forSegment:0];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"figure.stand" accessibilityDescription:@"站立"] forSegment:1];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"bell" accessibilityDescription:@"显示"] forSegment:2];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"wand.and.stars" accessibilityDescription:@"自动"] forSegment:3];
    [self.paneControl setImage:[NSImage imageWithSystemSymbolName:@"chart.bar" accessibilityDescription:@"统计"] forSegment:4];
    self.paneControl.segmentStyle = NSSegmentStyleSeparated;
    self.paneControl.target = self;
    self.paneControl.action = @selector(selectPane:);

    NSArray<NSString *> *navTitles = @[@"眼睛休息", @"站立提醒", @"显示方式", @"自动化", @"休息统计"];
    NSArray<NSString *> *navIcons = @[@"eye", @"figure.stand", @"bell", @"wand.and.stars", @"chart.bar"];
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

    NSView *automationPage = [self pageViewWithTitle:@"自动化" subtitle:@"会议、演示、视频或游戏时自动切到轻打扰：继续计时和通知，不弹全屏休息页。"];
    self.automationCard = automationPage.subviews.lastObject;
    [self buildAutomationSectionInView:automationPage];
    [content addSubview:automationPage];

    NSView *statsPage = [self pageViewWithTitle:@"休息统计" subtitle:@"看看最近 7 天有没有真的把休息做起来。统计只保存在本机。"];
    self.statsCard = statsPage.subviews.lastObject;
    [self buildStatsSectionInView:statsPage];
    [content addSubview:statsPage];

    self.pages = @[eyePage, standPage, alertPage, automationPage, statsPage];
    self.pageTitleLabels = @[
        [eyePage.subviews objectAtIndex:0],
        [standPage.subviews objectAtIndex:0],
        [alertPage.subviews objectAtIndex:0],
        [automationPage.subviews objectAtIndex:0],
        [statsPage.subviews objectAtIndex:0]
    ];
    self.pageSubtitleLabels = @[
        [eyePage.subviews objectAtIndex:1],
        [standPage.subviews objectAtIndex:1],
        [alertPage.subviews objectAtIndex:1],
        [automationPage.subviews objectAtIndex:1],
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

- (void)windowWillClose:(NSNotification *)notification {
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];
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

    NSView *card = ERRoundedView(NSMakeRect(0, 0, 528, 236), NSColor.whiteColor, 16);
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
        [NSValue valueWithRect:NSMakeRect(14, 164, 500, 46)],
        [NSValue valueWithRect:NSMakeRect(14, 126, 500, 36)],
        [NSValue valueWithRect:NSMakeRect(14, 88, 500, 36)],
        [NSValue valueWithRect:NSMakeRect(14, 50, 500, 36)],
        [NSValue valueWithRect:NSMakeRect(14, 12, 500, 36)]
    ] dividerX:136 dividerWidth:354];

    self.standEnabledSwitch = [NSButton checkboxWithTitle:@"启用站立提醒" target:self action:@selector(toggleOnly:)];
    self.standEnabledSwitch.frame = NSMakeRect(24, 175, 160, 24);
    [card addSubview:self.standEnabledSwitch];

    self.standCustomStagesSummaryLabel = [NSTextField labelWithString:@""];
    self.standCustomStagesSummaryLabel.frame = NSMakeRect(210, 176, 132, 22);
    self.standCustomStagesSummaryLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.standCustomStagesSummaryLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.standCustomStagesSummaryLabel];

    self.standCustomStagesButton = [NSButton buttonWithTitle:@"编辑阶段..." target:self action:@selector(editStandCustomStages:)];
    self.standCustomStagesButton.frame = NSMakeRect(360, 170, 132, 30);
    self.standCustomStagesButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:self.standCustomStagesButton];

    [card addSubview:[self fieldLabel:@"每隔：" frame:NSMakeRect(24, 133, 96, 22)]];
    self.standIntervalInput = [self addTimeFieldsToView:card x:140 y:129];

    [card addSubview:[self fieldLabel:@"站立：" frame:NSMakeRect(24, 95, 96, 22)]];
    self.standDurationInput = [self addTimeFieldsToView:card x:140 y:91];

    [card addSubview:[self fieldLabel:@"动作组合：" frame:NSMakeRect(24, 57, 96, 22)]];
    self.standRoutinePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 53, 178, 30) pullsDown:NO];
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
    self.standRoutineHintLabel.frame = NSMakeRect(330, 50, 170, 36);
    self.standRoutineHintLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    self.standRoutineHintLabel.maximumNumberOfLines = 2;
    self.standRoutineHintLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.standRoutineHintLabel];

    [card addSubview:[self fieldLabel:@"强度：" frame:NSMakeRect(24, 19, 96, 22)]];
    self.standIntensityPopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 15, 178, 30) pullsDown:NO];
    [self.standIntensityPopup addItemsWithTitles:@[
        ERStandIntensityTitle(ERStandIntensityGentle),
        ERStandIntensityTitle(ERStandIntensityStandard),
        ERStandIntensityTitle(ERStandIntensityActive),
    ]];
    self.standIntensityPopup.target = self;
    self.standIntensityPopup.action = @selector(toggleOnly:);
    [card addSubview:self.standIntensityPopup];

    self.standIntensityHintLabel = [NSTextField wrappingLabelWithString:@""];
    self.standIntensityHintLabel.frame = NSMakeRect(330, 12, 170, 36);
    self.standIntensityHintLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    self.standIntensityHintLabel.maximumNumberOfLines = 2;
    self.standIntensityHintLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.standIntensityHintLabel];
}

- (void)buildAlertSectionInView:(NSView *)view {
    NSView *card = self.alertCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(14, 174, 316, 32)],
        [NSValue valueWithRect:NSMakeRect(14, 140, 316, 32)],
        [NSValue valueWithRect:NSMakeRect(14, 106, 316, 32)],
        [NSValue valueWithRect:NSMakeRect(14, 72, 316, 32)],
        [NSValue valueWithRect:NSMakeRect(14, 38, 316, 32)],
        [NSValue valueWithRect:NSMakeRect(14, 4, 316, 32)]
    ] dividerX:136 dividerWidth:180];

    self.notificationSwitch = [NSButton checkboxWithTitle:@"系统通知" target:self action:@selector(toggleOnly:)];
    self.notificationSwitch.frame = NSMakeRect(24, 178, 160, 24);
    [card addSubview:self.notificationSwitch];

    self.restWindowSwitch = [NSButton checkboxWithTitle:@"提醒窗口" target:self action:@selector(toggleOnly:)];
    self.restWindowSwitch.frame = NSMakeRect(24, 144, 160, 24);
    [card addSubview:self.restWindowSwitch];

    self.restWindowTopmostSwitch = [NSButton checkboxWithTitle:@"置顶强提醒" target:self action:@selector(toggleOnly:)];
    self.restWindowTopmostSwitch.frame = NSMakeRect(24, 110, 160, 24);
    [card addSubview:self.restWindowTopmostSwitch];

    self.launchAtLoginSwitch = [NSButton checkboxWithTitle:@"登录时自动启动" target:self action:@selector(toggleOnly:)];
    self.launchAtLoginSwitch.frame = NSMakeRect(24, 76, 180, 24);
    [card addSubview:self.launchAtLoginSwitch];

    [card addSubview:[self fieldLabel:@"菜单栏：" frame:NSMakeRect(24, 44, 96, 22)]];
    self.menuBarModePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 39, 190, 30) pullsDown:NO];
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

    [card addSubview:[self fieldLabel:@"画面风格：" frame:NSMakeRect(24, 10, 96, 22)]];
    self.restStylePopup = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(140, 5, 190, 30) pullsDown:NO];
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

- (void)buildAutomationSectionInView:(NSView *)view {
    NSView *card = self.automationCard;
    [self addSettingRowsToCard:card frames:@[
        [NSValue valueWithRect:NSMakeRect(14, 170, 500, 52)],
        [NSValue valueWithRect:NSMakeRect(14, 112, 500, 52)],
        [NSValue valueWithRect:NSMakeRect(14, 58, 500, 48)],
        [NSValue valueWithRect:NSMakeRect(14, 14, 500, 38)]
    ] dividerX:24 dividerWidth:480];

    [card addSubview:[self captionLabel:@"当前状态" frame:NSMakeRect(24, 199, 100, 16)]];
    self.autoFocusSwitch = [NSButton checkboxWithTitle:@"启用自动策略" target:self action:@selector(toggleOnly:)];
    self.autoFocusSwitch.frame = NSMakeRect(24, 179, 126, 22);
    [card addSubview:self.autoFocusSwitch];

    self.focusAppMatchLabel = [NSTextField wrappingLabelWithString:@""];
    self.focusAppMatchLabel.frame = NSMakeRect(176, 177, 318, 34);
    self.focusAppMatchLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.focusAppMatchLabel.maximumNumberOfLines = 2;
    self.focusAppMatchLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.focusAppMatchLabel];

    [card addSubview:[self captionLabel:@"场景模式" frame:NSMakeRect(24, 142, 100, 16)]];
    self.calendarFocusSwitch = [NSButton checkboxWithTitle:@"日历会议" target:self action:@selector(toggleOnly:)];
    self.calendarFocusSwitch.frame = NSMakeRect(24, 120, 100, 22);
    [card addSubview:self.calendarFocusSwitch];

    self.presentationFocusSwitch = [NSButton checkboxWithTitle:@"全屏/演示" target:self action:@selector(toggleOnly:)];
    self.presentationFocusSwitch.frame = NSMakeRect(128, 120, 120, 22);
    [card addSubview:self.presentationFocusSwitch];

    self.calendarStatusLabel = [NSTextField wrappingLabelWithString:@""];
    self.calendarStatusLabel.frame = NSMakeRect(266, 116, 228, 34);
    self.calendarStatusLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.calendarStatusLabel.maximumNumberOfLines = 2;
    self.calendarStatusLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.calendarStatusLabel];

    [card addSubview:[self captionLabel:@"固定时段" frame:NSMakeRect(24, 88, 100, 16)]];
    self.quietHoursSwitch = [NSButton checkboxWithTitle:@"安静时段" target:self action:@selector(toggleOnly:)];
    self.quietHoursSwitch.frame = NSMakeRect(24, 66, 108, 22);
    [card addSubview:self.quietHoursSwitch];

    self.quietHoursStartField = [[NSTextField alloc] initWithFrame:NSMakeRect(140, 65, 64, 24)];
    self.quietHoursStartField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.quietHoursStartField.bezelStyle = NSTextFieldRoundedBezel;
    self.quietHoursStartField.alignment = NSTextAlignmentCenter;
    self.quietHoursStartField.placeholderString = @"22:00";
    self.quietHoursStartField.target = self;
    self.quietHoursStartField.action = @selector(applySettings:);
    [card addSubview:self.quietHoursStartField];

    NSTextField *quietHoursToLabel = [NSTextField labelWithString:@"到"];
    quietHoursToLabel.frame = NSMakeRect(212, 68, 20, 18);
    quietHoursToLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:quietHoursToLabel];

    self.quietHoursEndField = [[NSTextField alloc] initWithFrame:NSMakeRect(238, 65, 64, 24)];
    self.quietHoursEndField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.quietHoursEndField.bezelStyle = NSTextFieldRoundedBezel;
    self.quietHoursEndField.alignment = NSTextAlignmentCenter;
    self.quietHoursEndField.placeholderString = @"07:00";
    self.quietHoursEndField.target = self;
    self.quietHoursEndField.action = @selector(applySettings:);
    [card addSubview:self.quietHoursEndField];

    self.quietHoursStatusLabel = [NSTextField wrappingLabelWithString:@""];
    self.quietHoursStatusLabel.frame = NSMakeRect(316, 60, 176, 34);
    self.quietHoursStatusLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    self.quietHoursStatusLabel.maximumNumberOfLines = 2;
    self.quietHoursStatusLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.quietHoursStatusLabel];

    [card addSubview:[self captionLabel:@"高级策略" frame:NSMakeRect(24, 35, 100, 16)]];
    NSButton *editKeywordsButton = [NSButton buttonWithTitle:@"编辑策略关键词..." target:self action:@selector(editAutomationKeywords:)];
    editKeywordsButton.frame = NSMakeRect(120, 19, 136, 28);
    editKeywordsButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:editKeywordsButton];

    self.focusAppResetButton = [NSButton buttonWithTitle:@"默认" target:self action:@selector(resetFocusApps:)];
    self.focusAppResetButton.frame = NSMakeRect(418, 19, 72, 28);
    self.focusAppResetButton.bezelStyle = NSBezelStyleRounded;
    [card addSubview:self.focusAppResetButton];

    self.focusAppHintLabel = [NSTextField wrappingLabelWithString:@"自动策略按忽略、暂停、轻打扰顺序处理。"];
    self.focusAppHintLabel.frame = NSMakeRect(268, 17, 140, 32);
    self.focusAppHintLabel.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    self.focusAppHintLabel.maximumNumberOfLines = 2;
    self.focusAppHintLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.focusAppHintLabel];
}

- (void)buildStatsSectionInView:(NSView *)view {
    NSView *card = self.statsCard;
    self.statsOverviewLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsOverviewLabel.frame = NSMakeRect(24, 204, 300, 22);
    self.statsOverviewLabel.font = [NSFont systemFontOfSize:14 weight:NSFontWeightMedium];
    self.statsOverviewLabel.textColor = NSColor.labelColor;
    [card addSubview:self.statsOverviewLabel];

    self.exportStatsButton = [NSButton buttonWithTitle:@"导出 CSV" target:self action:@selector(exportStatsCSV:)];
    self.exportStatsButton.frame = NSMakeRect(292, 200, 72, 30);
    self.exportStatsButton.bezelStyle = NSBezelStyleRounded;
    self.exportStatsButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.exportStatsButton];

    self.exportBackupButton = [NSButton buttonWithTitle:@"备份 JSON" target:self action:@selector(exportStatsJSON:)];
    self.exportBackupButton.frame = NSMakeRect(370, 200, 72, 30);
    self.exportBackupButton.bezelStyle = NSBezelStyleRounded;
    self.exportBackupButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.exportBackupButton];

    self.importBackupButton = [NSButton buttonWithTitle:@"恢复 JSON" target:self action:@selector(importBackupJSON:)];
    self.importBackupButton.frame = NSMakeRect(448, 200, 72, 30);
    self.importBackupButton.bezelStyle = NSBezelStyleRounded;
    self.importBackupButton.font = [NSFont systemFontOfSize:13 weight:NSFontWeightMedium];
    [card addSubview:self.importBackupButton];

    self.statsMonthLabel = [NSTextField labelWithString:@""];
    self.statsMonthLabel.frame = NSMakeRect(24, 176, 480, 20);
    self.statsMonthLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.statsMonthLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsMonthLabel];

    self.statsStrategyLabel = [NSTextField labelWithString:@""];
    self.statsStrategyLabel.frame = NSMakeRect(24, 154, 480, 20);
    self.statsStrategyLabel.font = [NSFont systemFontOfSize:12 weight:NSFontWeightMedium];
    self.statsStrategyLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsStrategyLabel];

    self.statsInsightLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsInsightLabel.frame = NSMakeRect(24, 128, 480, 24);
    self.statsInsightLabel.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    self.statsInsightLabel.maximumNumberOfLines = 2;
    self.statsInsightLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsInsightLabel];

    self.statsQualityLabel = [self metricLabelWithFrame:NSMakeRect(24, 104, 150, 24)];
    [card addSubview:self.statsQualityLabel];
    self.statsStandLabel = [self metricLabelWithFrame:NSMakeRect(190, 104, 150, 24)];
    [card addSubview:self.statsStandLabel];
    self.statsStreakLabel = [self metricLabelWithFrame:NSMakeRect(356, 104, 150, 24)];
    [card addSubview:self.statsStreakLabel];

    NSArray<NSString *> *dayTitles = @[@"周一", @"周二", @"周三", @"周四", @"周五", @"周六", @"周日"];
    NSMutableArray *bars = [NSMutableArray array];
    NSMutableArray *labels = [NSMutableArray array];
    CGFloat startX = 24;
    CGFloat gap = 8;
    CGFloat barWidth = 28;
    CGFloat baseY = 28;
    for (NSInteger index = 0; index < 7; index++) {
        CGFloat x = startX + index * (barWidth + gap);
        NSView *slot = ERRoundedView(NSMakeRect(x, baseY, barWidth, 72), ERColor(0.93, 0.94, 0.97, 1), 12);
        [card addSubview:slot];
        [bars addObject:slot];

        NSTextField *label = [NSTextField labelWithString:dayTitles[index]];
        label.frame = NSMakeRect(x - 10, 4, 48, 22);
        label.alignment = NSTextAlignmentCenter;
        label.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
        label.textColor = NSColor.secondaryLabelColor;
        [card addSubview:label];
        [labels addObject:label];
    }
    self.statsBars = bars;
    self.statsBarLabels = labels;

    NSTextField *heatmapTitle = [NSTextField labelWithString:@"近 30 天热力"];
    heatmapTitle.frame = NSMakeRect(320, 82, 160, 18);
    heatmapTitle.font = [NSFont systemFontOfSize:11 weight:NSFontWeightMedium];
    heatmapTitle.textColor = NSColor.secondaryLabelColor;
    [card addSubview:heatmapTitle];

    self.statsMonthDetailLabel = [NSTextField wrappingLabelWithString:@""];
    self.statsMonthDetailLabel.frame = NSMakeRect(320, 58, 188, 22);
    self.statsMonthDetailLabel.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    self.statsMonthDetailLabel.maximumNumberOfLines = 2;
    self.statsMonthDetailLabel.textColor = NSColor.secondaryLabelColor;
    [card addSubview:self.statsMonthDetailLabel];

    NSMutableArray *cells = [NSMutableArray array];
    CGFloat cell = 14;
    CGFloat cellGap = 4;
    CGFloat originX = 320;
    CGFloat originY = 12;
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
    self.summaryLabel.stringValue = [NSString stringWithFormat:@"眼睛：%@ %@ / %@ · 站立：每 %@ 站 %@",
                                     self.settings.eyeEnabled ? @"开启" : @"关闭",
                                     ERFormatDuration(self.settings.eyeFocusSeconds),
                                     ERFormatDuration(self.settings.eyeRestSeconds),
                                     ERFormatDuration(self.settings.standIntervalSeconds),
                                     ERFormatDuration(self.settings.standDurationSeconds)];
    [self applySettingsTheme];
    [self refreshStats];
}

- (void)refreshAutomationStatus {
    if (!self.focusAppMatchLabel) return;
    self.focusAppMatchLabel.stringValue = [self.appDelegate focusModeStatusText];
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
    self.contentView.layer.backgroundColor = theme.settingsBackground.CGColor;
    self.headerView.wantsLayer = YES;
    self.headerView.layer.backgroundColor = theme.settingsHeader.CGColor;
    self.eyeCard.layer.backgroundColor = theme.card.CGColor;
    self.standCard.layer.backgroundColor = theme.card.CGColor;
    self.alertCard.layer.backgroundColor = theme.card.CGColor;
    self.automationCard.layer.backgroundColor = theme.card.CGColor;
    self.statsCard.layer.backgroundColor = theme.card.CGColor;
    self.eyeCard.layer.borderColor = theme.cardBorder.CGColor;
    self.standCard.layer.borderColor = theme.cardBorder.CGColor;
    self.alertCard.layer.borderColor = theme.cardBorder.CGColor;
    self.automationCard.layer.borderColor = theme.cardBorder.CGColor;
    self.statsCard.layer.borderColor = theme.cardBorder.CGColor;
    self.eyeCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.standCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.alertCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.automationCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.statsCard.layer.cornerRadius = theme.cornerRadius == 6 ? 8 : 16;
    self.titleLabel.textColor = theme.foreground == NSColor.whiteColor ? NSColor.whiteColor : NSColor.labelColor;
    self.summaryLabel.textColor = theme.secondary;
    self.focusAppMatchLabel.textColor = theme.secondary;
    self.calendarStatusLabel.textColor = theme.secondary;
    self.quietHoursStatusLabel.textColor = theme.secondary;
    self.focusAppHintLabel.textColor = theme.secondary;
    self.standRoutineHintLabel.textColor = theme.secondary;
    self.standIntensityHintLabel.textColor = theme.secondary;
    self.standCustomStagesSummaryLabel.textColor = theme.secondary;
    self.standCustomStagesButton.contentTintColor = theme.accent;
    self.statsOverviewLabel.textColor = theme.foreground == NSColor.whiteColor ? NSColor.whiteColor : NSColor.labelColor;
    self.statsMonthLabel.textColor = theme.secondary;
    self.statsStrategyLabel.textColor = theme.secondary;
    self.statsInsightLabel.textColor = theme.secondary;
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
    alert.informativeText = @"多个关键词用逗号、分号或换行分隔。优先级：忽略 > 暂停 > 只发通知。";
    [alert addButtonWithTitle:@"保存"];
    [alert addButtonWithTitle:@"恢复默认"];
    [alert addButtonWithTitle:@"取消"];

    NSView *panel = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 520, 220)];
    NSArray<NSString *> *labels = @[@"应用通知", @"应用暂停", @"应用忽略", @"日程通知", @"日程暂停"];
    NSArray<NSString *> *values = @[
        [self.settings.focusAppTokens componentsJoinedByString:@", "],
        [self.settings.autoPauseAppTokens componentsJoinedByString:@", "],
        [self.settings.ignoreAppTokens componentsJoinedByString:@", "],
        [self.settings.calendarFocusTokens componentsJoinedByString:@", "],
        [self.settings.calendarAutoPauseTokens componentsJoinedByString:@", "]
    ];
    NSArray<NSString *> *placeholders = @[
        @"会议/演示类应用：只发通知",
        @"视频/游戏类应用：暂停计时",
        @"误命中兜底：照常提醒",
        @"会议/站会：只发通知",
        @"录制/直播/面试：暂停计时"
    ];
    NSMutableArray<NSTextField *> *fields = [NSMutableArray arrayWithCapacity:labels.count];
    for (NSInteger index = 0; index < labels.count; index++) {
        CGFloat y = 176 - index * 40;
        NSTextField *label = [NSTextField labelWithString:[NSString stringWithFormat:@"%@：", labels[index]]];
        label.frame = NSMakeRect(0, y + 4, 86, 22);
        label.alignment = NSTextAlignmentRight;
        label.textColor = NSColor.secondaryLabelColor;
        [panel addSubview:label];

        NSTextField *field = [[NSTextField alloc] initWithFrame:NSMakeRect(100, y, 400, 26)];
        field.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
        field.bezelStyle = NSTextFieldRoundedBezel;
        field.placeholderString = placeholders[index];
        field.stringValue = values[index];
        [panel addSubview:field];
        [fields addObject:field];
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
    [self refreshActionBindings];
    [self layoutRestContent];
    return self;
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
        self.finishButton.target == self &&
        self.finishButton.action == @selector(finish:) &&
        self.finishButton.enabled &&
        self.snoozeButton.target == self &&
        self.snoozeButton.action == @selector(snooze:) &&
        self.snoozeButton.enabled &&
        self.skipButton.target == self &&
        self.skipButton.action == @selector(skip:) &&
        self.skipButton.enabled &&
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
    NSString *stageTitle = index < self.actionStageTitles.count ? self.actionStageTitles[index] : @"建议";
    self.actionSuggestionLabel.stringValue = [NSString stringWithFormat:@"阶段 %ld/%ld · %@ · %@",
                                              (long)index + 1,
                                              (long)count,
                                              stageTitle,
                                              suggestion];
    if (index < self.actionStageMessages.count) {
        self.messageLabel.stringValue = self.actionStageMessages[index];
    }

    NSString *symbolName = index < self.actionSuggestionSymbols.count ? self.actionSuggestionSymbols[index] : @"sparkles";
    self.actionSuggestionIcon.image = [NSImage imageWithSystemSymbolName:symbolName accessibilityDescription:@"动作建议"];
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

- (void)refreshFocusModeState {
    NSRunningApplication *frontmost = NSWorkspace.sharedWorkspace.frontmostApplication;
    self.frontmostAppBundleIdentifier = frontmost.bundleIdentifier;
    self.frontmostAppName = frontmost.localizedName;
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
    if (paused && !self.paused && !self.autoPauseActive && !self.autoPauseSessionActive) {
        self.todayAutoPauseSessions += 1;
        self.autoPauseSessionActive = YES;
        [self saveTodayStats];
    } else if (!paused && self.autoPauseActive) {
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
    if (self.restWindowController && self.restWindowController.window.visible && !self.settings.restWindowTopmost) {
        [self yieldRestOverlayForUserFocusChange];
    }
}

- (void)repairRestOverlayAfterDisplayChange {
    [self repairRestOverlayAfterSystemEvent:nil];
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

    NSMenuItem *copyRecovery = [[NSMenuItem alloc] initWithTitle:@"复制恢复诊断" action:@selector(copyRecoveryDiagnostic:) keyEquivalent:@""];
    copyRecovery.target = self;
    [self.menu addItem:copyRecovery];

    NSMenuItem *copyAppDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制应用诊断" action:@selector(copyApplicationDiagnostic:) keyEquivalent:@""];
    copyAppDiagnostic.target = self;
    [self.menu addItem:copyAppDiagnostic];

    NSMenuItem *recoverySelfCheck = [[NSMenuItem alloc] initWithTitle:@"运行恢复自检" action:@selector(runRecoverySelfCheck:) keyEquivalent:@""];
    recoverySelfCheck.target = self;
    [self.menu addItem:recoverySelfCheck];

    NSMenuItem *recoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行恢复压测" action:@selector(runRecoveryStressTest:) keyEquivalent:@""];
    recoveryStressTest.target = self;
    [self.menu addItem:recoveryStressTest];

    NSMenuItem *lunchRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行午休恢复压测" action:@selector(runLunchRecoveryStressTest:) keyEquivalent:@""];
    lunchRecoveryStressTest.target = self;
    [self.menu addItem:lunchRecoveryStressTest];

    NSMenuItem *sleepHiddenRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行睡眠隐藏恢复压测" action:@selector(runSleepHiddenRecoveryStressTest:) keyEquivalent:@""];
    sleepHiddenRecoveryStressTest.target = self;
    [self.menu addItem:sleepHiddenRecoveryStressTest];

    NSMenuItem *longAwayRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行长离开恢复压测" action:@selector(runLongAwayRecoveryStressTest:) keyEquivalent:@""];
    longAwayRecoveryStressTest.target = self;
    [self.menu addItem:longAwayRecoveryStressTest];

    NSMenuItem *displayRecoveryStressTest = [[NSMenuItem alloc] initWithTitle:@"运行显示恢复压测" action:@selector(runDisplayRecoveryStressTest:) keyEquivalent:@""];
    displayRecoveryStressTest.target = self;
    [self.menu addItem:displayRecoveryStressTest];

    NSMenuItem *displayBoundsStressTest = [[NSMenuItem alloc] initWithTitle:@"运行显示边界压测" action:@selector(runDisplayBoundsStressTest:) keyEquivalent:@""];
    displayBoundsStressTest.target = self;
    [self.menu addItem:displayBoundsStressTest];

    NSMenuItem *overlayYieldStressTest = [[NSMenuItem alloc] initWithTitle:@"运行窗口让开压测" action:@selector(runOverlayYieldStressTest:) keyEquivalent:@""];
    overlayYieldStressTest.target = self;
    [self.menu addItem:overlayYieldStressTest];

    [self.menu addItem:NSMenuItem.separatorItem];
    NSMenuItem *settings = [[NSMenuItem alloc] initWithTitle:@"打开设置..." action:@selector(openSettings:) keyEquivalent:@","];
    settings.target = self;
    [self.menu addItem:settings];

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
        @[@"运行显示边界压测", ERAutomationURLString(@"diagnostics/display-bounds")],
        @[@"运行窗口让开压测", ERAutomationURLString(@"diagnostics/overlay-yield")]
    ];
    for (NSArray<NSString *> *itemInfo in automationURLs) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"复制%@", itemInfo[0]]
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

    NSMenuItem *automationDiagnostic = [[NSMenuItem alloc] initWithTitle:@"复制自动化诊断" action:@selector(copyAutomationDiagnostic:) keyEquivalent:@""];
    automationDiagnostic.target = self;
    [self.menu addItem:automationDiagnostic];

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
    [lines addObject:[self recoveryDiagnosticText]];
    [lines addObject:@"最近恢复事件："];
    for (NSString *line in [self recoveryHistoryLines]) {
        [lines addObject:[NSString stringWithFormat:@"- %@", line]];
    }
    return [lines componentsJoinedByString:@"\n"];
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

- (void)runRecoverySelfCheck:(id)sender {
    [self repairRestOverlayAfterSystemEvent:nil];
    [self noteRecoveryEventTitle:@"手动自检" detail:self.restWindowController ? @"休息页状态已校准" : @"状态正常"];
    [self publishState];
}

- (void)runRecoveryStressTest:(id)sender {
    self.recoveryStressTestGeneration += 1;
    NSUInteger generation = self.recoveryStressTestGeneration;
    NSArray<NSNumber *> *delays = @[@0.0, @0.4, @1.0, @2.0, @4.0];
    NSInteger total = delays.count;

    [self noteRecoveryEventTitle:@"恢复压测" detail:[NSString stringWithFormat:@"开始 %ld 轮窗口复查", (long)total]];
    [self publishState];

    for (NSInteger index = 0; index < total; index++) {
        NSTimeInterval delay = delays[index].doubleValue;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self runRecoveryStressTestPass:index + 1 total:total generation:generation];
        });
    }
}

- (void)runRecoveryStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
    if (generation != self.recoveryStressTestGeneration) return;

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
    if (orphaned > 0) {
        [details addObject:[NSString stringWithFormat:@"清理残留 %ld 个", (long)orphaned]];
    }
    [details addObject:[NSString stringWithFormat:@"屏幕 %ld", (long)NSScreen.screens.count]];

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
            [self runOverlayYieldStressTestPass:index + 1 total:total generation:generation];
            if (index + 1 == total) {
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
                [self publishState];
            }
        });
    }
}

- (void)runOverlayYieldStressTestPass:(NSInteger)pass total:(NSInteger)total generation:(NSUInteger)generation {
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

    [self noteRecoveryEventTitle:@"窗口让开压测" detail:[details componentsJoinedByString:@"，"]];
    [self publishState];
}

- (void)yieldRestOverlayForUserFocusChange {
    if (!self.restWindowController || self.settings.restWindowTopmost) return;
    self.restOverlayYielded = YES;
    [self.restWindowController.window orderOut:nil];
    [self noteRecoveryEventTitle:@"窗口让开" detail:@"用户切到其他窗口，非置顶休息页已隐藏，本轮计时继续"];
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
    NSString *message = [NSString stringWithFormat:@"版本 %@ (%@)\n\n眼睛休息、站立提醒和番茄休息都在一个轻量菜单栏里。\n\n安装位置：%@\n源码：%@", version, build, bundlePath, ERGitHubURLString];

    NSAlert *alert = [[NSAlert alloc] init];
    alert.messageText = ERBrandName;
    alert.informativeText = message;
    alert.icon = [NSImage imageNamed:NSImageNameInfo];
    [alert addButtonWithTitle:@"好"];
    [alert addButtonWithTitle:@"打开 GitHub"];

    [NSApp activateIgnoringOtherApps:YES];
    NSModalResponse response = [alert runModal];
    if (response == NSAlertSecondButtonReturn) {
        NSURL *url = [NSURL URLWithString:ERGitHubURLString];
        if (url) {
            [NSWorkspace.sharedWorkspace openURL:url];
        }
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
        @"## 发生了什么？\n\n\n\n## 期望行为\n\n\n\n## 诊断信息\n\n- 版本：%@ (%@)\n- 系统：%@\n- 安装位置：%@\n\n请先在菜单栏选择「复制应用诊断」，再把剪贴板内容粘贴到这里。\n",
        version,
        build,
        systemVersion,
        bundlePath];

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

            if (!error && data.length > 0) {
                id object = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([object isKindOfClass:NSDictionary.class]) {
                    NSDictionary *release = (NSDictionary *)object;
                    NSString *tag = [release[@"tag_name"] isKindOfClass:NSString.class] ? release[@"tag_name"] : nil;
                    latestVersion = [[tag ?: @"" stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet] stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"vV"]];
                    releaseName = [release[@"name"] isKindOfClass:NSString.class] ? release[@"name"] : nil;
                    releaseURLString = [release[@"html_url"] isKindOfClass:NSString.class] ? release[@"html_url"] : ERLatestReleaseURLString;
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
                alert.informativeText = [NSString stringWithFormat:@"当前版本 %@，最新版本 %@%@。", currentVersion, latestVersion, releaseName.length > 0 ? [NSString stringWithFormat:@"（%@）", releaseName] : @""];
                [alert addButtonWithTitle:@"打开下载页"];
                [alert addButtonWithTitle:@"稍后"];
                if ([alert runModal] == NSAlertFirstButtonReturn) {
                    NSURL *url = [NSURL URLWithString:releaseURLString];
                    if (url) [NSWorkspace.sharedWorkspace openURL:url];
                }
                [self noteRecoveryEventTitle:@"更新" detail:[NSString stringWithFormat:@"发现 %@", latestVersion]];
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
        [self presentSettingsWindow];
        detail = @"打开设置";
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
            self.paused = YES;
            self.pauseStartedAt = NSDate.date;
            self.pausedUntil = [NSDate dateWithTimeIntervalSinceNow:seconds];
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
        } else if ([argument isEqualToString:@"display-bounds"] || [argument isEqualToString:@"bounds"] || [argument isEqualToString:@"screen-bounds"]) {
            [self runDisplayBoundsStressTest:nil];
            detail = @"运行显示边界压测";
        } else if ([argument isEqualToString:@"overlay-yield"] || [argument isEqualToString:@"yield"] || [argument isEqualToString:@"window-yield"]) {
            [self runOverlayYieldStressTest:nil];
            detail = @"运行窗口让开压测";
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
    NSMutableArray<NSString *> *lines = [NSMutableArray array];
    [lines addObject:[NSString stringWithFormat:@"%@ 自动化诊断", ERBrandName]];
    [lines addObject:[NSString stringWithFormat:@"生成时间：%@", ERFormatClockTime(NSDate.date)]];
    [lines addObject:[NSString stringWithFormat:@"URL Scheme：%@", ERAutomationURLScheme]];
    [lines addObject:@"常用链接："];
    [lines addObject:[NSString stringWithFormat:@"- 专注开始：%@", ERAutomationURLString(@"focus/on")]];
    [lines addObject:[NSString stringWithFormat:@"- 专注结束：%@", ERAutomationURLString(@"focus/off")]];
    [lines addObject:[NSString stringWithFormat:@"- 切换轻打扰：%@", ERAutomationURLString(@"focus/toggle")]];
    [lines addObject:[NSString stringWithFormat:@"- 专注联动模板：%@", ERAutomationURLString(@"automation/focus-template")]];
    [lines addObject:[NSString stringWithFormat:@"- 暂停 30 分钟：%@", ERAutomationURLString(@"pause/30m")]];
    [lines addObject:[NSString stringWithFormat:@"- 继续提醒：%@", ERAutomationURLString(@"resume")]];
    [lines addObject:[NSString stringWithFormat:@"自动化状态：%@", [self focusModeStatusText]]];
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
    [self.settingsWindowController refreshControls];
    NSWindow *settingsWindow = self.settingsWindowController.window;
    NSScreen *screen = NSScreen.mainScreen ?: NSScreen.screens.firstObject;
    if (screen) {
        NSRect visibleFrame = screen.visibleFrame;
        NSRect windowFrame = settingsWindow.frame;
        CGFloat x = NSMidX(visibleFrame) - windowFrame.size.width / 2.0;
        CGFloat y = NSMidY(visibleFrame) - windowFrame.size.height / 2.0;
        x = MIN(NSMaxX(visibleFrame) - windowFrame.size.width, MAX(NSMinX(visibleFrame), x));
        y = MIN(NSMaxY(visibleFrame) - windowFrame.size.height, MAX(NSMinY(visibleFrame), y));
        [settingsWindow setFrameOrigin:NSMakePoint(x, y)];
    }
    [self.settingsWindowController showWindow:nil];
    [NSApp activateIgnoringOtherApps:YES];
    [settingsWindow makeKeyAndOrderFront:nil];
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
