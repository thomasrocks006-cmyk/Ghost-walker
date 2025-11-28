//
//  SettingsViewController.h
//  Ghost Walker
//
//  Settings for walk simulation parameters
//

#import <UIKit/UIKit.h>
#import "WalkingEngine.h"

@interface SettingsViewController : UIViewController

- (instancetype)initWithWalkingEngine:(WalkingEngine *)engine;

@end
