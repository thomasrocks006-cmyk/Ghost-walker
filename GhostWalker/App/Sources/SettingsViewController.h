//
//  SettingsViewController.h
//  GhostWalker
//
//  Complete settings for all spoofing modes
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Settings Keys for NSUserDefaults
extern NSString * const kSettingsDefaultMode;
extern NSString * const kSettingsWalkingSpeed;
extern NSString * const kSettingsDrivingSpeed;
extern NSString * const kSettingsDriftMin;
extern NSString * const kSettingsDriftMax;
extern NSString * const kSettingsAccuracyMin;
extern NSString * const kSettingsAccuracyMax;
extern NSString * const kSettingsAccuracyUpdateInterval;
extern NSString * const kSettingsBackgroundEnabled;
extern NSString * const kSettingsJetsamProtection;
extern NSString * const kSettingsFailsafeEnabled;
extern NSString * const kSettingsFailsafeThreshold;
extern NSString * const kSettingsVerificationEnabled;
extern NSString * const kSettingsHapticFeedback;
extern NSString * const kSettingsRouteProvider;
extern NSString * const kSettingsAutoStartLastLocation;
extern NSString * const kSettingsAltitude;
extern NSString * const kSettingsAltitudeEnabled;

@protocol SettingsViewControllerDelegate <NSObject>
- (void)settingsDidChange;
@end

@interface SettingsViewController : UITableViewController

@property (nonatomic, weak) id<SettingsViewControllerDelegate> delegate;

// Convenience class methods for reading settings
+ (NSInteger)defaultMode;
+ (double)walkingSpeed;
+ (double)drivingSpeed;
+ (double)driftMin;
+ (double)driftMax;
+ (double)accuracyMin;
+ (double)accuracyMax;
+ (NSTimeInterval)accuracyUpdateInterval;
+ (BOOL)backgroundEnabled;
+ (BOOL)jetsamProtectionEnabled;
+ (BOOL)failsafeEnabled;
+ (double)failsafeThreshold;
+ (BOOL)verificationEnabled;
+ (BOOL)hapticFeedbackEnabled;
+ (NSString *)routeProvider;
+ (BOOL)autoStartLastLocation;
+ (double)altitude;
+ (BOOL)altitudeEnabled;

// Reset to defaults
+ (void)resetToDefaults;

@end

NS_ASSUME_NONNULL_END
