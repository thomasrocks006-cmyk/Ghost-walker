//
//  SettingsViewController.m
//  GhostWalker
//
//  Complete settings for all spoofing modes
//

#import "SettingsViewController.h"

// Settings Keys
NSString * const kSettingsDefaultMode = @"defaultMode";
NSString * const kSettingsWalkingSpeed = @"walkingSpeed";
NSString * const kSettingsDrivingSpeed = @"drivingSpeed";
NSString * const kSettingsDriftMin = @"driftMin";
NSString * const kSettingsDriftMax = @"driftMax";
NSString * const kSettingsAccuracyMin = @"accuracyMin";
NSString * const kSettingsAccuracyMax = @"accuracyMax";
NSString * const kSettingsAccuracyUpdateInterval = @"accuracyUpdateInterval";
NSString * const kSettingsBackgroundEnabled = @"backgroundEnabled";
NSString * const kSettingsJetsamProtection = @"jetsamProtection";
NSString * const kSettingsFailsafeEnabled = @"failsafeEnabled";
NSString * const kSettingsFailsafeThreshold = @"failsafeThreshold";
NSString * const kSettingsVerificationEnabled = @"verificationEnabled";
NSString * const kSettingsHapticFeedback = @"hapticFeedback";
NSString * const kSettingsRouteProvider = @"routeProvider";
NSString * const kSettingsAutoStartLastLocation = @"autoStartLastLocation";

// Section indices
typedef NS_ENUM(NSInteger, SettingsSection) {
    SettingsSectionMode = 0,
    SettingsSectionSpeed,
    SettingsSectionDrift,
    SettingsSectionAccuracy,
    SettingsSectionBackground,
    SettingsSectionFailsafe,
    SettingsSectionUI,
    SettingsSectionRouting,
    SettingsSectionReset,
    SettingsSectionCount
};

@interface SettingsViewController ()

// Speed
@property (nonatomic, strong) UISlider *walkingSpeedSlider;
@property (nonatomic, strong) UILabel *walkingSpeedLabel;
@property (nonatomic, strong) UISlider *drivingSpeedSlider;
@property (nonatomic, strong) UILabel *drivingSpeedLabel;

// Drift
@property (nonatomic, strong) UISlider *driftMinSlider;
@property (nonatomic, strong) UILabel *driftMinLabel;
@property (nonatomic, strong) UISlider *driftMaxSlider;
@property (nonatomic, strong) UILabel *driftMaxLabel;

// Accuracy
@property (nonatomic, strong) UISlider *accuracyMinSlider;
@property (nonatomic, strong) UILabel *accuracyMinLabel;
@property (nonatomic, strong) UISlider *accuracyMaxSlider;
@property (nonatomic, strong) UILabel *accuracyMaxLabel;
@property (nonatomic, strong) UISlider *accuracyIntervalSlider;
@property (nonatomic, strong) UILabel *accuracyIntervalLabel;

// Background
@property (nonatomic, strong) UISwitch *backgroundSwitch;
@property (nonatomic, strong) UISwitch *jetsamSwitch;

// Failsafe
@property (nonatomic, strong) UISwitch *failsafeSwitch;
@property (nonatomic, strong) UISlider *failsafeThresholdSlider;
@property (nonatomic, strong) UILabel *failsafeThresholdLabel;

// UI
@property (nonatomic, strong) UISwitch *verificationSwitch;
@property (nonatomic, strong) UISwitch *hapticSwitch;

// Routing
@property (nonatomic, strong) UISegmentedControl *modeSegment;
@property (nonatomic, strong) UISwitch *autoStartSwitch;

@end

@implementation SettingsViewController

#pragma mark - Class Methods for Settings Access

+ (NSUserDefaults *)defaults {
    return [NSUserDefaults standardUserDefaults];
}

+ (void)registerDefaults {
    [[self defaults] registerDefaults:@{
        kSettingsDefaultMode: @0,
        kSettingsWalkingSpeed: @1.4,      // m/s (walking)
        kSettingsDrivingSpeed: @13.4,     // m/s (~30 mph)
        kSettingsDriftMin: @2.0,          // meters
        kSettingsDriftMax: @8.0,          // meters
        kSettingsAccuracyMin: @10.0,      // meters
        kSettingsAccuracyMax: @25.0,      // meters
        kSettingsAccuracyUpdateInterval: @10.0, // seconds
        kSettingsBackgroundEnabled: @YES,
        kSettingsJetsamProtection: @YES,
        kSettingsFailsafeEnabled: @YES,
        kSettingsFailsafeThreshold: @500.0, // meters
        kSettingsVerificationEnabled: @YES,
        kSettingsHapticFeedback: @YES,
        kSettingsRouteProvider: @"osrm",
        kSettingsAutoStartLastLocation: @NO
    }];
}

+ (NSInteger)defaultMode {
    [self registerDefaults];
    return [[self defaults] integerForKey:kSettingsDefaultMode];
}

+ (double)walkingSpeed {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsWalkingSpeed];
}

+ (double)drivingSpeed {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsDrivingSpeed];
}

+ (double)driftMin {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsDriftMin];
}

+ (double)driftMax {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsDriftMax];
}

+ (double)accuracyMin {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsAccuracyMin];
}

+ (double)accuracyMax {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsAccuracyMax];
}

+ (NSTimeInterval)accuracyUpdateInterval {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsAccuracyUpdateInterval];
}

+ (BOOL)backgroundEnabled {
    [self registerDefaults];
    return [[self defaults] boolForKey:kSettingsBackgroundEnabled];
}

+ (BOOL)jetsamProtectionEnabled {
    [self registerDefaults];
    return [[self defaults] boolForKey:kSettingsJetsamProtection];
}

+ (BOOL)failsafeEnabled {
    [self registerDefaults];
    return [[self defaults] boolForKey:kSettingsFailsafeEnabled];
}

+ (double)failsafeThreshold {
    [self registerDefaults];
    return [[self defaults] doubleForKey:kSettingsFailsafeThreshold];
}

+ (BOOL)verificationEnabled {
    [self registerDefaults];
    return [[self defaults] boolForKey:kSettingsVerificationEnabled];
}

+ (BOOL)hapticFeedbackEnabled {
    [self registerDefaults];
    return [[self defaults] boolForKey:kSettingsHapticFeedback];
}

+ (NSString *)routeProvider {
    [self registerDefaults];
    return [[self defaults] stringForKey:kSettingsRouteProvider];
}

+ (BOOL)autoStartLastLocation {
    [self registerDefaults];
    return [[self defaults] boolForKey:kSettingsAutoStartLastLocation];
}

+ (void)resetToDefaults {
    NSUserDefaults *defaults = [self defaults];
    NSArray *keys = @[
        kSettingsDefaultMode, kSettingsWalkingSpeed, kSettingsDrivingSpeed,
        kSettingsDriftMin, kSettingsDriftMax, kSettingsAccuracyMin,
        kSettingsAccuracyMax, kSettingsAccuracyUpdateInterval,
        kSettingsBackgroundEnabled, kSettingsJetsamProtection,
        kSettingsFailsafeEnabled, kSettingsFailsafeThreshold,
        kSettingsVerificationEnabled, kSettingsHapticFeedback,
        kSettingsRouteProvider, kSettingsAutoStartLastLocation
    ];
    
    for (NSString *key in keys) {
        [defaults removeObjectForKey:key];
    }
    [defaults synchronize];
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Settings";
    self.navigationItem.largeTitleDisplayMode = UINavigationItemLargeTitleDisplayModeNever;
    
    self.tableView.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                target:self
                                                                                action:@selector(dismissSettings)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    [[self class] registerDefaults];
    [self setupControls];
}

- (void)setupControls {
    // Speed sliders
    self.walkingSpeedSlider = [[UISlider alloc] init];
    self.walkingSpeedSlider.minimumValue = 0.5;
    self.walkingSpeedSlider.maximumValue = 3.0;
    self.walkingSpeedSlider.value = [[self class] walkingSpeed];
    [self.walkingSpeedSlider addTarget:self action:@selector(walkingSpeedChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.walkingSpeedLabel = [[UILabel alloc] init];
    [self updateWalkingSpeedLabel];
    
    self.drivingSpeedSlider = [[UISlider alloc] init];
    self.drivingSpeedSlider.minimumValue = 5.0;
    self.drivingSpeedSlider.maximumValue = 40.0;
    self.drivingSpeedSlider.value = [[self class] drivingSpeed];
    [self.drivingSpeedSlider addTarget:self action:@selector(drivingSpeedChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.drivingSpeedLabel = [[UILabel alloc] init];
    [self updateDrivingSpeedLabel];
    
    // Drift sliders
    self.driftMinSlider = [[UISlider alloc] init];
    self.driftMinSlider.minimumValue = 1.0;
    self.driftMinSlider.maximumValue = 10.0;
    self.driftMinSlider.value = [[self class] driftMin];
    [self.driftMinSlider addTarget:self action:@selector(driftMinChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.driftMinLabel = [[UILabel alloc] init];
    [self updateDriftMinLabel];
    
    self.driftMaxSlider = [[UISlider alloc] init];
    self.driftMaxSlider.minimumValue = 5.0;
    self.driftMaxSlider.maximumValue = 25.0;
    self.driftMaxSlider.value = [[self class] driftMax];
    [self.driftMaxSlider addTarget:self action:@selector(driftMaxChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.driftMaxLabel = [[UILabel alloc] init];
    [self updateDriftMaxLabel];
    
    // Accuracy sliders
    self.accuracyMinSlider = [[UISlider alloc] init];
    self.accuracyMinSlider.minimumValue = 5.0;
    self.accuracyMinSlider.maximumValue = 30.0;
    self.accuracyMinSlider.value = [[self class] accuracyMin];
    [self.accuracyMinSlider addTarget:self action:@selector(accuracyMinChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.accuracyMinLabel = [[UILabel alloc] init];
    [self updateAccuracyMinLabel];
    
    self.accuracyMaxSlider = [[UISlider alloc] init];
    self.accuracyMaxSlider.minimumValue = 15.0;
    self.accuracyMaxSlider.maximumValue = 100.0;
    self.accuracyMaxSlider.value = [[self class] accuracyMax];
    [self.accuracyMaxSlider addTarget:self action:@selector(accuracyMaxChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.accuracyMaxLabel = [[UILabel alloc] init];
    [self updateAccuracyMaxLabel];
    
    self.accuracyIntervalSlider = [[UISlider alloc] init];
    self.accuracyIntervalSlider.minimumValue = 5.0;
    self.accuracyIntervalSlider.maximumValue = 30.0;
    self.accuracyIntervalSlider.value = [[self class] accuracyUpdateInterval];
    [self.accuracyIntervalSlider addTarget:self action:@selector(accuracyIntervalChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.accuracyIntervalLabel = [[UILabel alloc] init];
    [self updateAccuracyIntervalLabel];
    
    // Background switches
    self.backgroundSwitch = [[UISwitch alloc] init];
    self.backgroundSwitch.on = [[self class] backgroundEnabled];
    [self.backgroundSwitch addTarget:self action:@selector(backgroundSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.jetsamSwitch = [[UISwitch alloc] init];
    self.jetsamSwitch.on = [[self class] jetsamProtectionEnabled];
    [self.jetsamSwitch addTarget:self action:@selector(jetsamSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Failsafe
    self.failsafeSwitch = [[UISwitch alloc] init];
    self.failsafeSwitch.on = [[self class] failsafeEnabled];
    [self.failsafeSwitch addTarget:self action:@selector(failsafeSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.failsafeThresholdSlider = [[UISlider alloc] init];
    self.failsafeThresholdSlider.minimumValue = 100.0;
    self.failsafeThresholdSlider.maximumValue = 1000.0;
    self.failsafeThresholdSlider.value = [[self class] failsafeThreshold];
    [self.failsafeThresholdSlider addTarget:self action:@selector(failsafeThresholdChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.failsafeThresholdLabel = [[UILabel alloc] init];
    [self updateFailsafeThresholdLabel];
    
    // UI switches
    self.verificationSwitch = [[UISwitch alloc] init];
    self.verificationSwitch.on = [[self class] verificationEnabled];
    [self.verificationSwitch addTarget:self action:@selector(verificationSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.hapticSwitch = [[UISwitch alloc] init];
    self.hapticSwitch.on = [[self class] hapticFeedbackEnabled];
    [self.hapticSwitch addTarget:self action:@selector(hapticSwitchChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Mode segment
    self.modeSegment = [[UISegmentedControl alloc] initWithItems:@[@"Hold", @"Walk", @"Drive"]];
    self.modeSegment.selectedSegmentIndex = [[self class] defaultMode];
    [self.modeSegment addTarget:self action:@selector(modeChanged:) forControlEvents:UIControlEventValueChanged];
    
    // Auto start
    self.autoStartSwitch = [[UISwitch alloc] init];
    self.autoStartSwitch.on = [[self class] autoStartLastLocation];
    [self.autoStartSwitch addTarget:self action:@selector(autoStartSwitchChanged:) forControlEvents:UIControlEventValueChanged];
}

#pragma mark - Actions

- (void)dismissSettings {
    [self.delegate settingsDidChange];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)walkingSpeedChanged:(UISlider *)slider {
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsWalkingSpeed];
    [self updateWalkingSpeedLabel];
}

- (void)drivingSpeedChanged:(UISlider *)slider {
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsDrivingSpeed];
    [self updateDrivingSpeedLabel];
}

- (void)driftMinChanged:(UISlider *)slider {
    // Ensure min <= max
    if (slider.value > self.driftMaxSlider.value) {
        slider.value = self.driftMaxSlider.value;
    }
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsDriftMin];
    [self updateDriftMinLabel];
}

- (void)driftMaxChanged:(UISlider *)slider {
    // Ensure max >= min
    if (slider.value < self.driftMinSlider.value) {
        slider.value = self.driftMinSlider.value;
    }
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsDriftMax];
    [self updateDriftMaxLabel];
}

- (void)accuracyMinChanged:(UISlider *)slider {
    // Ensure min <= max
    if (slider.value > self.accuracyMaxSlider.value) {
        slider.value = self.accuracyMaxSlider.value;
    }
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsAccuracyMin];
    [self updateAccuracyMinLabel];
}

- (void)accuracyMaxChanged:(UISlider *)slider {
    // Ensure max >= min
    if (slider.value < self.accuracyMinSlider.value) {
        slider.value = self.accuracyMinSlider.value;
    }
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsAccuracyMax];
    [self updateAccuracyMaxLabel];
}

- (void)accuracyIntervalChanged:(UISlider *)slider {
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsAccuracyUpdateInterval];
    [self updateAccuracyIntervalLabel];
}

- (void)backgroundSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSettingsBackgroundEnabled];
}

- (void)jetsamSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSettingsJetsamProtection];
}

- (void)failsafeSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSettingsFailsafeEnabled];
    [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:SettingsSectionFailsafe] withRowAnimation:UITableViewRowAnimationAutomatic];
}

- (void)failsafeThresholdChanged:(UISlider *)slider {
    [[NSUserDefaults standardUserDefaults] setDouble:slider.value forKey:kSettingsFailsafeThreshold];
    [self updateFailsafeThresholdLabel];
}

- (void)verificationSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSettingsVerificationEnabled];
}

- (void)hapticSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSettingsHapticFeedback];
}

- (void)modeChanged:(UISegmentedControl *)segment {
    [[NSUserDefaults standardUserDefaults] setInteger:segment.selectedSegmentIndex forKey:kSettingsDefaultMode];
}

- (void)autoStartSwitchChanged:(UISwitch *)sw {
    [[NSUserDefaults standardUserDefaults] setBool:sw.on forKey:kSettingsAutoStartLastLocation];
}

#pragma mark - Label Updates

- (void)updateWalkingSpeedLabel {
    double mps = self.walkingSpeedSlider.value;
    double mph = mps * 2.237;
    self.walkingSpeedLabel.text = [NSString stringWithFormat:@"%.1f m/s (%.1f mph)", mps, mph];
    self.walkingSpeedLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateDrivingSpeedLabel {
    double mps = self.drivingSpeedSlider.value;
    double mph = mps * 2.237;
    self.drivingSpeedLabel.text = [NSString stringWithFormat:@"%.0f m/s (%.0f mph)", mps, mph];
    self.drivingSpeedLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateDriftMinLabel {
    self.driftMinLabel.text = [NSString stringWithFormat:@"%.0f m", self.driftMinSlider.value];
    self.driftMinLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateDriftMaxLabel {
    self.driftMaxLabel.text = [NSString stringWithFormat:@"%.0f m", self.driftMaxSlider.value];
    self.driftMaxLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateAccuracyMinLabel {
    self.accuracyMinLabel.text = [NSString stringWithFormat:@"%.0f m", self.accuracyMinSlider.value];
    self.accuracyMinLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateAccuracyMaxLabel {
    self.accuracyMaxLabel.text = [NSString stringWithFormat:@"%.0f m", self.accuracyMaxSlider.value];
    self.accuracyMaxLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateAccuracyIntervalLabel {
    self.accuracyIntervalLabel.text = [NSString stringWithFormat:@"%.0f sec", self.accuracyIntervalSlider.value];
    self.accuracyIntervalLabel.textColor = [UIColor secondaryLabelColor];
}

- (void)updateFailsafeThresholdLabel {
    self.failsafeThresholdLabel.text = [NSString stringWithFormat:@"%.0f m", self.failsafeThresholdSlider.value];
    self.failsafeThresholdLabel.textColor = [UIColor secondaryLabelColor];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return SettingsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionMode: return 1;
        case SettingsSectionSpeed: return 2;
        case SettingsSectionDrift: return 2;
        case SettingsSectionAccuracy: return 3;
        case SettingsSectionBackground: return 2;
        case SettingsSectionFailsafe: return self.failsafeSwitch.on ? 2 : 1;
        case SettingsSectionUI: return 2;
        case SettingsSectionRouting: return 1;
        case SettingsSectionReset: return 1;
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionMode: return @"Default Mode";
        case SettingsSectionSpeed: return @"Speed Settings";
        case SettingsSectionDrift: return @"Drift Settings";
        case SettingsSectionAccuracy: return @"Accuracy Simulation";
        case SettingsSectionBackground: return @"Background & Persistence";
        case SettingsSectionFailsafe: return @"Rubber-Band Failsafe";
        case SettingsSectionUI: return @"User Interface";
        case SettingsSectionRouting: return @"Auto Start";
        case SettingsSectionReset: return nil;
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case SettingsSectionMode:
            return @"The mode to use when app starts.";
        case SettingsSectionSpeed:
            return @"Walking: typical human pace. Driving: car speeds for route mode.";
        case SettingsSectionDrift:
            return @"Random drift range applied to position. Simulates real GPS behavior.";
        case SettingsSectionAccuracy:
            return @"Accuracy circle changes randomly every interval to mimic real iPhone GPS.";
        case SettingsSectionBackground:
            return @"Keep spoofing active when app is closed. Jetsam protection prevents iOS from killing the process.";
        case SettingsSectionFailsafe:
            return @"Detects if real location 'rubber-bands' back and alerts you. Threshold is distance in meters.";
        case SettingsSectionUI:
            return @"Visual and haptic feedback options.";
        case SettingsSectionRouting:
            return @"Automatically resume spoofing last location on app launch.";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.textLabel.font = [UIFont systemFontOfSize:16];
    
    switch (indexPath.section) {
        case SettingsSectionMode: {
            cell.textLabel.text = @"Default Mode";
            cell.accessoryView = self.modeSegment;
            break;
        }
            
        case SettingsSectionSpeed: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Walking Speed";
                UIStackView *stack = [self sliderStackWithSlider:self.walkingSpeedSlider label:self.walkingSpeedLabel];
                cell.accessoryView = stack;
            } else {
                cell.textLabel.text = @"Driving Speed";
                UIStackView *stack = [self sliderStackWithSlider:self.drivingSpeedSlider label:self.drivingSpeedLabel];
                cell.accessoryView = stack;
            }
            break;
        }
            
        case SettingsSectionDrift: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Minimum Drift";
                UIStackView *stack = [self sliderStackWithSlider:self.driftMinSlider label:self.driftMinLabel];
                cell.accessoryView = stack;
            } else {
                cell.textLabel.text = @"Maximum Drift";
                UIStackView *stack = [self sliderStackWithSlider:self.driftMaxSlider label:self.driftMaxLabel];
                cell.accessoryView = stack;
            }
            break;
        }
            
        case SettingsSectionAccuracy: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Min Accuracy";
                UIStackView *stack = [self sliderStackWithSlider:self.accuracyMinSlider label:self.accuracyMinLabel];
                cell.accessoryView = stack;
            } else if (indexPath.row == 1) {
                cell.textLabel.text = @"Max Accuracy";
                UIStackView *stack = [self sliderStackWithSlider:self.accuracyMaxSlider label:self.accuracyMaxLabel];
                cell.accessoryView = stack;
            } else {
                cell.textLabel.text = @"Update Interval";
                UIStackView *stack = [self sliderStackWithSlider:self.accuracyIntervalSlider label:self.accuracyIntervalLabel];
                cell.accessoryView = stack;
            }
            break;
        }
            
        case SettingsSectionBackground: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Background Spoofing";
                cell.accessoryView = self.backgroundSwitch;
            } else {
                cell.textLabel.text = @"Jetsam Protection";
                cell.accessoryView = self.jetsamSwitch;
            }
            break;
        }
            
        case SettingsSectionFailsafe: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Enable Failsafe";
                cell.accessoryView = self.failsafeSwitch;
            } else {
                cell.textLabel.text = @"Threshold";
                UIStackView *stack = [self sliderStackWithSlider:self.failsafeThresholdSlider label:self.failsafeThresholdLabel];
                cell.accessoryView = stack;
            }
            break;
        }
            
        case SettingsSectionUI: {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Verification Banner";
                cell.accessoryView = self.verificationSwitch;
            } else {
                cell.textLabel.text = @"Haptic Feedback";
                cell.accessoryView = self.hapticSwitch;
            }
            break;
        }
            
        case SettingsSectionRouting: {
            cell.textLabel.text = @"Resume Last Location";
            cell.accessoryView = self.autoStartSwitch;
            break;
        }
            
        case SettingsSectionReset: {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = @"Reset to Defaults";
            cell.textLabel.textColor = [UIColor systemRedColor];
            cell.textLabel.textAlignment = NSTextAlignmentCenter;
            cell.selectionStyle = UITableViewCellSelectionStyleDefault;
            break;
        }
    }
    
    return cell;
}

- (UIStackView *)sliderStackWithSlider:(UISlider *)slider label:(UILabel *)label {
    label.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightRegular];
    label.textAlignment = NSTextAlignmentRight;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [label setContentHuggingPriority:UILayoutPriorityRequired forAxis:UILayoutConstraintAxisHorizontal];
    [label.widthAnchor constraintGreaterThanOrEqualToConstant:80].active = YES;
    
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    [slider.widthAnchor constraintEqualToConstant:120].active = YES;
    
    UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[slider, label]];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.spacing = 8;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.frame = CGRectMake(0, 0, 220, 44);
    
    return stack;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == SettingsSectionReset) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset Settings"
                                                                       message:@"This will reset all settings to their default values."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [[self class] resetToDefaults];
            [self setupControls];
            [self.tableView reloadData];
        }]];
        
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 52;
}

@end
