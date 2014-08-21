#import "MJGeneralTabController.h"
#import "MJAutoLaunch.h"
#import "core.h"
#import "MJLinkTextField.h"
#import "MJUpdateChecker.h"
#import "MJDockIcon.h"
#import "MJMenuIcon.h"
#import "variables.h"

extern Boolean AXIsProcessTrustedWithOptions(CFDictionaryRef options) __attribute__((weak_import));
extern CFStringRef kAXTrustedCheckOptionPrompt __attribute__((weak_import));

@interface MJGeneralTabController ()

@property (weak) IBOutlet NSButton* openAtLoginCheckbox;
@property (weak) IBOutlet NSButton* showDockIconCheckbox;
@property (weak) IBOutlet NSButton* showMenuIconCheckbox;
@property (weak) IBOutlet NSButton* checkForUpdatesCheckbox;
@property (weak) IBOutlet NSButton* showWindowAtLaunchCheckbox;

@property (weak) IBOutlet MJLinkTextField* dashField;

@property BOOL isAccessibilityEnabled;

@end


@implementation MJGeneralTabController

@synthesize initialFirstResponder;
- (NSString*) nibName { return @"GeneralTab"; }
- (NSString*) title   { return @"General"; }
- (NSImage*)  icon    { return [NSImage imageNamed:@"Settings"]; }

- (void) awakeFromNib {
    [self linkifyDashLabel];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self cacheIsAccessibilityEnabled];
    });
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(accessibilityChanged:) name:@"com.apple.accessibility.api" object:nil];
    
    [self.openAtLoginCheckbox setState:MJAutoLaunchGet() ? NSOnState : NSOffState];
    [self.showDockIconCheckbox setState: MJDockIconVisible() ? NSOnState : NSOffState];
    [self.showMenuIconCheckbox setState: MJMenuIconVisible() ? NSOnState : NSOffState];
    [self.checkForUpdatesCheckbox setState: MJUpdateCheckerEnabled() ? NSOnState : NSOffState];
    [self.showWindowAtLaunchCheckbox setState: [[NSUserDefaults standardUserDefaults] boolForKey:MJShowWindowAtLaunchKey] ? NSOnState : NSOffState];
}

- (void) linkifyDashLabel {
    MJLinkTextFieldAddLink(self.dashField, MJDashURL, [[self.dashField stringValue] rangeOfString:@"Dash"]);
}

- (void) accessibilityChanged:(NSNotification*)note {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.15 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self cacheIsAccessibilityEnabled];
    });
}

- (void) cacheIsAccessibilityEnabled {
    if (AXIsProcessTrustedWithOptions != NULL)
        self.isAccessibilityEnabled = AXIsProcessTrustedWithOptions(NULL);
    else
        self.isAccessibilityEnabled = AXAPIEnabled();
}

- (NSString*) maybeEnableAccessibilityString {
    if (self.isAccessibilityEnabled)
        return @"Accessibility is enabled. You're all set!";
    else
        return @"Enable Accessibility for best results.";
}

- (NSImage*) isAccessibilityEnabledImage {
    if (self.isAccessibilityEnabled)
        return [NSImage imageNamed:NSImageNameStatusAvailable];
    else
        return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
}

+ (NSSet*) keyPathsForValuesAffectingMaybeEnableAccessibilityString {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

+ (NSSet*) keyPathsForValuesAffectingIsAccessibilityEnabledImage {
    return [NSSet setWithArray:@[@"isAccessibilityEnabled"]];
}

- (IBAction) openAccessibility:(id)sender {
    if (AXIsProcessTrustedWithOptions != NULL) {
        AXIsProcessTrustedWithOptions((__bridge CFDictionaryRef)@{(__bridge id)kAXTrustedCheckOptionPrompt: @YES});
    }
    else {
        static NSString* script = @"tell application \"System Preferences\"\nactivate\nset current pane to pane \"com.apple.preference.universalaccess\"\nend tell";
        [[[NSAppleScript alloc] initWithSource:script] executeAndReturnError:nil];
    }
}

- (IBAction) toggleOpensAtLogin:(NSButton*)sender {
    BOOL enabled = [sender state] == NSOnState;
    MJAutoLaunchSet(enabled);
}

- (IBAction) toggleShowDockIcon:(NSButton*)sender {
    BOOL enabled = [sender state] == NSOnState;
    if (!enabled && !MJMenuIconVisible()) {
        [sender setState: NSOnState];
        [self warnAboutDockMenuProblem];
        return;
    }
    
    MJDockIconSetVisible(enabled);
}

- (IBAction) toggleMenuDockIcon:(NSButton*)sender {
    BOOL enabled = [sender state] == NSOnState;
    if (!enabled && !MJDockIconVisible()) {
        [sender setState: NSOnState];
        [self warnAboutDockMenuProblem];
        return;
    }
    
    MJMenuIconSetVisible(enabled);
}

- (IBAction) toggleCheckForUpdates:(NSButton*)sender {
    MJUpdateCheckerSetEnabled([sender state] == NSOnState);
    if (MJUpdateCheckerEnabled())
        MJUpdateCheckerCheckSilently();
}

- (void) warnAboutDockMenuProblem {
    NSAlert* alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSWarningAlertStyle];
    [alert setMessageText:@"Can't have both disabled"];
    [alert setInformativeText:@"Either the dock icon or menu icon need to be enabled. Otherwise you'd have no way of getting back to this window ever!"];
    [alert beginSheetModalForWindow:[[self view] window]
                      modalDelegate:nil
                     didEndSelector:NULL
                        contextInfo:NULL];
}

- (IBAction) reloadConfig:(id)sender {
    MJReloadConfig();
}

- (IBAction) toggleShowWindowAtLaunch:(NSButton*)sender {
    [[NSUserDefaults standardUserDefaults] setBool:[sender state] == NSOnState
                                            forKey:MJShowWindowAtLaunchKey];
}

@end
