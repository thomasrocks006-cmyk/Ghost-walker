//
//  SettingsViewController.m
//  Ghost Walker
//
//  Settings for walk simulation parameters
//

#import "SettingsViewController.h"

@interface SettingsViewController () <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) WalkingEngine *walkingEngine;
@property (nonatomic, strong) UITableView *tableView;

// Sliders
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UISlider *driftSlider;
@property (nonatomic, strong) UISlider *minAccuracySlider;
@property (nonatomic, strong) UISlider *maxAccuracySlider;

// Labels
@property (nonatomic, strong) UILabel *speedValueLabel;
@property (nonatomic, strong) UILabel *driftValueLabel;
@property (nonatomic, strong) UILabel *minAccuracyValueLabel;
@property (nonatomic, strong) UILabel *maxAccuracyValueLabel;

@end

@implementation SettingsViewController

- (instancetype)initWithWalkingEngine:(WalkingEngine *)engine {
    self = [super init];
    if (self) {
        _walkingEngine = engine;
    }
    return self;
}

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Settings";
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];
    
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                           target:self 
                                                                                           action:@selector(doneTapped)];
    
    [self setupTableView];
    [self createSliders];
}

#pragma mark - Setup

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStyleInsetGrouped];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)createSliders {
    // Speed slider
    self.speedSlider = [[UISlider alloc] init];
    self.speedSlider.minimumValue = 0.5;
    self.speedSlider.maximumValue = 8.0;
    self.speedSlider.value = self.walkingEngine.walkingSpeed;
    [self.speedSlider addTarget:self action:@selector(speedChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.speedValueLabel = [[UILabel alloc] init];
    self.speedValueLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.speedValueLabel.textColor = [UIColor secondaryLabelColor];
    [self updateSpeedLabel];
    
    // Drift slider
    self.driftSlider = [[UISlider alloc] init];
    self.driftSlider.minimumValue = 0;
    self.driftSlider.maximumValue = 10;
    self.driftSlider.value = self.walkingEngine.driftAmount;
    [self.driftSlider addTarget:self action:@selector(driftChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.driftValueLabel = [[UILabel alloc] init];
    self.driftValueLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.driftValueLabel.textColor = [UIColor secondaryLabelColor];
    [self updateDriftLabel];
    
    // Min accuracy slider
    self.minAccuracySlider = [[UISlider alloc] init];
    self.minAccuracySlider.minimumValue = 5;
    self.minAccuracySlider.maximumValue = 30;
    self.minAccuracySlider.value = self.walkingEngine.accuracyMin;
    [self.minAccuracySlider addTarget:self action:@selector(minAccuracyChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.minAccuracyValueLabel = [[UILabel alloc] init];
    self.minAccuracyValueLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.minAccuracyValueLabel.textColor = [UIColor secondaryLabelColor];
    [self updateMinAccuracyLabel];
    
    // Max accuracy slider
    self.maxAccuracySlider = [[UISlider alloc] init];
    self.maxAccuracySlider.minimumValue = 30;
    self.maxAccuracySlider.maximumValue = 100;
    self.maxAccuracySlider.value = self.walkingEngine.accuracyMax;
    [self.maxAccuracySlider addTarget:self action:@selector(maxAccuracyChanged:) forControlEvents:UIControlEventValueChanged];
    
    self.maxAccuracyValueLabel = [[UILabel alloc] init];
    self.maxAccuracyValueLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightRegular];
    self.maxAccuracyValueLabel.textColor = [UIColor secondaryLabelColor];
    [self updateMaxAccuracyLabel];
}

#pragma mark - Actions

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)speedChanged:(UISlider *)slider {
    self.walkingEngine.walkingSpeed = slider.value;
    [self updateSpeedLabel];
}

- (void)driftChanged:(UISlider *)slider {
    self.walkingEngine.driftAmount = slider.value;
    [self updateDriftLabel];
}

- (void)minAccuracyChanged:(UISlider *)slider {
    self.walkingEngine.accuracyMin = slider.value;
    [self updateMinAccuracyLabel];
}

- (void)maxAccuracyChanged:(UISlider *)slider {
    self.walkingEngine.accuracyMax = slider.value;
    [self updateMaxAccuracyLabel];
}

- (void)presetTapped:(UIButton *)button {
    double speed = button.tag / 10.0;
    self.walkingEngine.walkingSpeed = speed;
    self.speedSlider.value = speed;
    [self updateSpeedLabel];
}

- (void)resetTapped {
    [self.walkingEngine resetAll];
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Label Updates

- (void)updateSpeedLabel {
    float speed = self.speedSlider.value;
    NSString *description;
    
    if (speed <= 1.0) {
        description = @"Slow Walk";
    } else if (speed <= 1.5) {
        description = @"Walk";
    } else if (speed <= 2.5) {
        description = @"Fast Walk";
    } else if (speed <= 4.0) {
        description = @"Jog";
    } else {
        description = @"Run";
    }
    
    self.speedValueLabel.text = [NSString stringWithFormat:@"%.1f m/s (%@)", speed, description];
}

- (void)updateDriftLabel {
    self.driftValueLabel.text = [NSString stringWithFormat:@"%.1f m", self.driftSlider.value];
}

- (void)updateMinAccuracyLabel {
    self.minAccuracyValueLabel.text = [NSString stringWithFormat:@"%.0f m", self.minAccuracySlider.value];
}

- (void)updateMaxAccuracyLabel {
    self.maxAccuracyValueLabel.text = [NSString stringWithFormat:@"%.0f m", self.maxAccuracySlider.value];
}

#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 4; // Movement, Accuracy, Presets, Actions
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    switch (section) {
        case 0: return 2; // Speed, Drift
        case 1: return 2; // Min/Max accuracy
        case 2: return 5; // Presets
        case 3: return 1; // Reset
        default: return 0;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Movement";
        case 1: return @"GPS Accuracy Pulse";
        case 2: return @"Speed Presets";
        case 3: return @"Actions";
        default: return nil;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    switch (section) {
        case 0: return @"Drift adds random movement to simulate human walking patterns.";
        case 1: return @"Simulates the GPS 'blue circle' resizing that happens naturally.";
        default: return nil;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        // Movement settings (sliders)
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UIStackView *stack = [[UIStackView alloc] init];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 8;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:stack];
        
        UIStackView *headerStack = [[UIStackView alloc] init];
        headerStack.axis = UILayoutConstraintAxisHorizontal;
        headerStack.distribution = UIStackViewDistributionEqualSpacing;
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont systemFontOfSize:17];
        
        UISlider *slider;
        UILabel *valueLabel;
        
        if (indexPath.row == 0) {
            titleLabel.text = @"Walking Speed";
            slider = self.speedSlider;
            valueLabel = self.speedValueLabel;
        } else {
            titleLabel.text = @"GPS Drift";
            slider = self.driftSlider;
            valueLabel = self.driftValueLabel;
        }
        
        [headerStack addArrangedSubview:titleLabel];
        [headerStack addArrangedSubview:valueLabel];
        [stack addArrangedSubview:headerStack];
        [stack addArrangedSubview:slider];
        
        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        ]];
        
        return cell;
        
    } else if (indexPath.section == 1) {
        // Accuracy settings
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UIStackView *stack = [[UIStackView alloc] init];
        stack.axis = UILayoutConstraintAxisVertical;
        stack.spacing = 8;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        [cell.contentView addSubview:stack];
        
        UIStackView *headerStack = [[UIStackView alloc] init];
        headerStack.axis = UILayoutConstraintAxisHorizontal;
        headerStack.distribution = UIStackViewDistributionEqualSpacing;
        
        UILabel *titleLabel = [[UILabel alloc] init];
        titleLabel.font = [UIFont systemFontOfSize:17];
        
        UISlider *slider;
        UILabel *valueLabel;
        
        if (indexPath.row == 0) {
            titleLabel.text = @"Minimum Accuracy";
            slider = self.minAccuracySlider;
            valueLabel = self.minAccuracyValueLabel;
        } else {
            titleLabel.text = @"Maximum Accuracy";
            slider = self.maxAccuracySlider;
            valueLabel = self.maxAccuracyValueLabel;
        }
        
        [headerStack addArrangedSubview:titleLabel];
        [headerStack addArrangedSubview:valueLabel];
        [stack addArrangedSubview:headerStack];
        [stack addArrangedSubview:slider];
        
        [NSLayoutConstraint activateConstraints:@[
            [stack.topAnchor constraintEqualToAnchor:cell.contentView.topAnchor constant:12],
            [stack.leadingAnchor constraintEqualToAnchor:cell.contentView.leadingAnchor constant:16],
            [stack.trailingAnchor constraintEqualToAnchor:cell.contentView.trailingAnchor constant:-16],
            [stack.bottomAnchor constraintEqualToAnchor:cell.contentView.bottomAnchor constant:-12],
        ]];
        
        return cell;
        
    } else if (indexPath.section == 2) {
        // Presets
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
        
        NSArray *presets = @[
            @{@"emoji": @"🚶", @"name": @"Slow Walk", @"speed": @10},
            @{@"emoji": @"🚶‍♂️", @"name": @"Normal Walk", @"speed": @14},
            @{@"emoji": @"🚶‍♀️", @"name": @"Fast Walk", @"speed": @20},
            @{@"emoji": @"🏃", @"name": @"Jog", @"speed": @35},
            @{@"emoji": @"🏃‍♂️", @"name": @"Run", @"speed": @60}
        ];
        
        NSDictionary *preset = presets[indexPath.row];
        cell.textLabel.text = [NSString stringWithFormat:@"%@ %@", preset[@"emoji"], preset[@"name"]];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%.1f m/s", [preset[@"speed"] floatValue] / 10.0];
        cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
        cell.tag = [preset[@"speed"] integerValue];
        
        return cell;
        
    } else {
        // Reset
        UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
        cell.textLabel.text = @"Reset All";
        cell.textLabel.textColor = [UIColor systemRedColor];
        cell.textLabel.textAlignment = NSTextAlignmentCenter;
        return cell;
    }
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    if (indexPath.section == 2) {
        // Preset selected
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        double speed = cell.tag / 10.0;
        self.walkingEngine.walkingSpeed = speed;
        self.speedSlider.value = speed;
        [self updateSpeedLabel];
        [tableView reloadSections:[NSIndexSet indexSetWithIndex:0] withRowAnimation:UITableViewRowAnimationNone];
    } else if (indexPath.section == 3) {
        // Reset
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Reset All?" 
                                                                       message:@"This will stop walking and clear all destinations." 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
        [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
            [self resetTapped];
        }]];
        [self presentViewController:alert animated:YES completion:nil];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0 || indexPath.section == 1) {
        return 80; // Slider cells
    }
    return UITableViewAutomaticDimension;
}

@end
