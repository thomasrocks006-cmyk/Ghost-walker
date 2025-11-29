//
//  MainViewController.m
//  Ghost Walker
//
//  Main dashboard with map, controls, verification markers, and all modes
//

#import "MainViewController.h"
#import "WalkingEngine.h"
#import "LocationSimulator.h"
#import "DestinationSearchController.h"
#import "SettingsViewController.h"

@interface MainViewController () <MKMapViewDelegate, CLLocationManagerDelegate, WalkingEngineDelegate>

// Map
@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) CLLocationManager *locationManager;

// Annotations
@property (nonatomic, strong) MKPointAnnotation *realLocationAnnotation;
@property (nonatomic, strong) MKPointAnnotation *spoofedLocationAnnotation;
@property (nonatomic, strong) MKPointAnnotation *destinationAnnotation;
@property (nonatomic, strong) MKPolyline *routePolyline;
@property (nonatomic, strong) MKPolyline *walkedPolyline;

// Verification Banner (Task 8)
@property (nonatomic, strong) UIView *verificationBanner;
@property (nonatomic, strong) UIView *statusIndicator;
@property (nonatomic, strong) UILabel *statusMainLabel;
@property (nonatomic, strong) UILabel *statusDetailLabel;
@property (nonatomic, strong) UILabel *updateCountLabel;
@property (nonatomic, strong) UILabel *accuracyLabel;
@property (nonatomic, strong) UILabel *durationLabel;

// Control Panel
@property (nonatomic, strong) UIView *controlPanel;
@property (nonatomic, strong) UISegmentedControl *modeSelector;
@property (nonatomic, strong) UIButton *holdHereButton;
@property (nonatomic, strong) UIButton *routeButton;
@property (nonatomic, strong) UIButton *stopButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *searchButton;

// Speed Section
@property (nonatomic, strong) UIView *speedSection;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;

// Engine
@property (nonatomic, strong) WalkingEngine *walkingEngine;

// State
@property (nonatomic, assign) BOOL hasInitializedMap;
@property (nonatomic, strong) NSTimer *uiUpdateTimer;

@end

@implementation MainViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    [self setupWalkingEngine];
    [self setupLocationManager];
    [self setupMapView];
    [self setupVerificationBanner];
    [self setupControlPanel];
    [self setupGestures];
    [self startUIUpdateTimer];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.locationManager requestAlwaysAuthorization];
    [self.locationManager startUpdatingLocation];
    
    // FALLBACK: If no location after 3 seconds, center on default location
    // This prevents a blank map if GPS is slow or permissions are delayed
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!self.hasInitializedMap) {
            NSLog(@"[GhostWalker] No GPS received, centering on default location (San Francisco)");
            // Default to San Francisco
            CLLocationCoordinate2D defaultLocation = CLLocationCoordinate2DMake(37.7749, -122.4194);
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(defaultLocation, 5000, 5000);
            [self.mapView setRegion:region animated:YES];
            self.hasInitializedMap = YES;
        }
    });
}

- (void)dealloc {
    [self.uiUpdateTimer invalidate];
}

#pragma mark - Setup

- (void)setupWalkingEngine {
    self.walkingEngine = [[WalkingEngine alloc] init];
    self.walkingEngine.delegate = self;
}

- (void)setupLocationManager {
    self.locationManager = [[CLLocationManager alloc] init];
    self.locationManager.delegate = self;
    self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
    self.locationManager.distanceFilter = 5;
}

- (void)setupMapView {
    self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
    self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    self.mapView.delegate = self;
    self.mapView.showsUserLocation = NO;
    self.mapView.showsCompass = YES;
    self.mapView.showsScale = YES;
    [self.view addSubview:self.mapView];
    
    // Annotations
    self.realLocationAnnotation = [[MKPointAnnotation alloc] init];
    self.realLocationAnnotation.title = @"Real Location";
    
    self.spoofedLocationAnnotation = [[MKPointAnnotation alloc] init];
    self.spoofedLocationAnnotation.title = @"Spoofed Location";
    
    self.destinationAnnotation = [[MKPointAnnotation alloc] init];
    self.destinationAnnotation.title = @"Destination";
}

- (void)setupVerificationBanner {
    // Main banner container
    self.verificationBanner = [[UIView alloc] init];
    self.verificationBanner.translatesAutoresizingMaskIntoConstraints = NO;
    self.verificationBanner.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.verificationBanner.layer.cornerRadius = 16;
    [self.view addSubview:self.verificationBanner];
    
    // Status indicator (pulsing dot)
    self.statusIndicator = [[UIView alloc] init];
    self.statusIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusIndicator.backgroundColor = [UIColor grayColor];
    self.statusIndicator.layer.cornerRadius = 8;
    [self.verificationBanner addSubview:self.statusIndicator];
    
    // Main status label
    self.statusMainLabel = [[UILabel alloc] init];
    self.statusMainLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusMainLabel.text = @"IDLE";
    self.statusMainLabel.textColor = [UIColor whiteColor];
    self.statusMainLabel.font = [UIFont systemFontOfSize:18 weight:UIFontWeightBold];
    [self.verificationBanner addSubview:self.statusMainLabel];
    
    // Detail label (last update)
    self.statusDetailLabel = [[UILabel alloc] init];
    self.statusDetailLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDetailLabel.text = @"Tap map to set location";
    self.statusDetailLabel.textColor = [UIColor lightGrayColor];
    self.statusDetailLabel.font = [UIFont systemFontOfSize:12];
    [self.verificationBanner addSubview:self.statusDetailLabel];
    
    // Stats row
    UIStackView *statsStack = [[UIStackView alloc] init];
    statsStack.translatesAutoresizingMaskIntoConstraints = NO;
    statsStack.axis = UILayoutConstraintAxisHorizontal;
    statsStack.distribution = UIStackViewDistributionEqualSpacing;
    statsStack.spacing = 16;
    [self.verificationBanner addSubview:statsStack];
    
    // Update count
    self.updateCountLabel = [self createStatLabel:@"Updates: 0"];
    [statsStack addArrangedSubview:self.updateCountLabel];
    
    // Accuracy
    self.accuracyLabel = [self createStatLabel:@"Accuracy: --"];
    [statsStack addArrangedSubview:self.accuracyLabel];
    
    // Duration
    self.durationLabel = [self createStatLabel:@"Duration: --"];
    [statsStack addArrangedSubview:self.durationLabel];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.verificationBanner.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.verificationBanner.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.verificationBanner.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        
        [self.statusIndicator.leadingAnchor constraintEqualToAnchor:self.verificationBanner.leadingAnchor constant:16],
        [self.statusIndicator.topAnchor constraintEqualToAnchor:self.verificationBanner.topAnchor constant:16],
        [self.statusIndicator.widthAnchor constraintEqualToConstant:16],
        [self.statusIndicator.heightAnchor constraintEqualToConstant:16],
        
        [self.statusMainLabel.leadingAnchor constraintEqualToAnchor:self.statusIndicator.trailingAnchor constant:10],
        [self.statusMainLabel.centerYAnchor constraintEqualToAnchor:self.statusIndicator.centerYAnchor],
        
        [self.statusDetailLabel.leadingAnchor constraintEqualToAnchor:self.statusIndicator.leadingAnchor],
        [self.statusDetailLabel.topAnchor constraintEqualToAnchor:self.statusIndicator.bottomAnchor constant:8],
        [self.statusDetailLabel.trailingAnchor constraintEqualToAnchor:self.verificationBanner.trailingAnchor constant:-16],
        
        [statsStack.leadingAnchor constraintEqualToAnchor:self.verificationBanner.leadingAnchor constant:16],
        [statsStack.trailingAnchor constraintEqualToAnchor:self.verificationBanner.trailingAnchor constant:-16],
        [statsStack.topAnchor constraintEqualToAnchor:self.statusDetailLabel.bottomAnchor constant:10],
        [statsStack.bottomAnchor constraintEqualToAnchor:self.verificationBanner.bottomAnchor constant:-12],
    ]];
}

- (UILabel *)createStatLabel:(NSString *)text {
    UILabel *label = [[UILabel alloc] init];
    label.text = text;
    label.textColor = [UIColor lightGrayColor];
    label.font = [UIFont monospacedSystemFontOfSize:11 weight:UIFontWeightMedium];
    return label;
}

- (void)setupControlPanel {
    // Container
    self.controlPanel = [[UIView alloc] init];
    self.controlPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.controlPanel.layer.cornerRadius = 20;
    [self.view addSubview:self.controlPanel];
    
    // Mode selector (Static Hold / Walk / Drive)
    self.modeSelector = [[UISegmentedControl alloc] initWithItems:@[@"Hold", @"Walk", @"Drive"]];
    self.modeSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.modeSelector.selectedSegmentIndex = 0;
    self.modeSelector.selectedSegmentTintColor = [UIColor systemBlueColor];
    [self.modeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor whiteColor]} forState:UIControlStateSelected];
    [self.modeSelector setTitleTextAttributes:@{NSForegroundColorAttributeName: [UIColor lightGrayColor]} forState:UIControlStateNormal];
    [self.modeSelector addTarget:self action:@selector(modeSelectorChanged:) forControlEvents:UIControlEventValueChanged];
    [self.controlPanel addSubview:self.modeSelector];
    
    // Speed section (hidden when in Hold mode)
    self.speedSection = [[UIView alloc] init];
    self.speedSection.translatesAutoresizingMaskIntoConstraints = NO;
    self.speedSection.hidden = YES;
    [self.controlPanel addSubview:self.speedSection];
    
    UILabel *speedTitle = [[UILabel alloc] init];
    speedTitle.translatesAutoresizingMaskIntoConstraints = NO;
    speedTitle.text = @"Speed";
    speedTitle.textColor = [UIColor grayColor];
    speedTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [self.speedSection addSubview:speedTitle];
    
    self.speedLabel = [[UILabel alloc] init];
    self.speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.speedLabel.text = @"1.4 m/s";
    self.speedLabel.textColor = [UIColor whiteColor];
    self.speedLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
    [self.speedSection addSubview:self.speedLabel];
    
    self.speedSlider = [[UISlider alloc] init];
    self.speedSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.speedSlider.minimumValue = 0.5;
    self.speedSlider.maximumValue = 8.0;
    self.speedSlider.value = 1.4;
    self.speedSlider.tintColor = [UIColor systemGreenColor];
    [self.speedSlider addTarget:self action:@selector(speedSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [self.speedSection addSubview:self.speedSlider];
    
    // Button row
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 12;
    buttonStack.alignment = UIStackViewAlignmentCenter;
    [self.controlPanel addSubview:buttonStack];
    
    // Settings button
    self.settingsButton = [self createCircleButton:@"gearshape.fill" color:[UIColor darkGrayColor]];
    [self.settingsButton addTarget:self action:@selector(settingsButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.settingsButton];
    
    // Hold Here button (for static mode)
    self.holdHereButton = [self createMainButton:@"Hold Here" icon:@"location.fill" color:[UIColor systemBlueColor]];
    [self.holdHereButton addTarget:self action:@selector(holdHereButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.holdHereButton];
    
    // Route button (for walk/drive mode)
    self.routeButton = [self createMainButton:@"Start Route" icon:@"figure.walk" color:[UIColor systemGreenColor]];
    self.routeButton.hidden = YES;
    [self.routeButton addTarget:self action:@selector(routeButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.routeButton];
    
    // Stop button
    self.stopButton = [self createMainButton:@"Stop" icon:@"stop.fill" color:[UIColor systemRedColor]];
    self.stopButton.hidden = YES;
    [self.stopButton addTarget:self action:@selector(stopButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.stopButton];
    
    // Search button
    self.searchButton = [self createCircleButton:@"magnifyingglass" color:[UIColor systemBlueColor]];
    [self.searchButton addTarget:self action:@selector(searchButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.searchButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.controlPanel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-12],
        [self.controlPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:12],
        [self.controlPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-12],
        
        [self.modeSelector.topAnchor constraintEqualToAnchor:self.controlPanel.topAnchor constant:16],
        [self.modeSelector.leadingAnchor constraintEqualToAnchor:self.controlPanel.leadingAnchor constant:16],
        [self.modeSelector.trailingAnchor constraintEqualToAnchor:self.controlPanel.trailingAnchor constant:-16],
        
        [self.speedSection.topAnchor constraintEqualToAnchor:self.modeSelector.bottomAnchor constant:12],
        [self.speedSection.leadingAnchor constraintEqualToAnchor:self.controlPanel.leadingAnchor constant:16],
        [self.speedSection.trailingAnchor constraintEqualToAnchor:self.controlPanel.trailingAnchor constant:-16],
        [self.speedSection.heightAnchor constraintEqualToConstant:50],
        
        [speedTitle.topAnchor constraintEqualToAnchor:self.speedSection.topAnchor],
        [speedTitle.leadingAnchor constraintEqualToAnchor:self.speedSection.leadingAnchor],
        
        [self.speedLabel.topAnchor constraintEqualToAnchor:self.speedSection.topAnchor],
        [self.speedLabel.trailingAnchor constraintEqualToAnchor:self.speedSection.trailingAnchor],
        
        [self.speedSlider.topAnchor constraintEqualToAnchor:speedTitle.bottomAnchor constant:4],
        [self.speedSlider.leadingAnchor constraintEqualToAnchor:self.speedSection.leadingAnchor],
        [self.speedSlider.trailingAnchor constraintEqualToAnchor:self.speedSection.trailingAnchor],
        
        [buttonStack.topAnchor constraintEqualToAnchor:self.speedSection.bottomAnchor constant:12],
        [buttonStack.centerXAnchor constraintEqualToAnchor:self.controlPanel.centerXAnchor],
        [buttonStack.bottomAnchor constraintEqualToAnchor:self.controlPanel.bottomAnchor constant:-16],
        
        [self.settingsButton.widthAnchor constraintEqualToConstant:44],
        [self.settingsButton.heightAnchor constraintEqualToConstant:44],
        
        [self.holdHereButton.widthAnchor constraintEqualToConstant:140],
        [self.holdHereButton.heightAnchor constraintEqualToConstant:44],
        
        [self.routeButton.widthAnchor constraintEqualToConstant:140],
        [self.routeButton.heightAnchor constraintEqualToConstant:44],
        
        [self.stopButton.widthAnchor constraintEqualToConstant:100],
        [self.stopButton.heightAnchor constraintEqualToConstant:44],
        
        [self.searchButton.widthAnchor constraintEqualToConstant:44],
        [self.searchButton.heightAnchor constraintEqualToConstant:44],
    ]];
}

- (UIButton *)createCircleButton:(NSString *)iconName color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    [button setImage:[UIImage systemImageNamed:iconName] forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    button.backgroundColor = color;
    button.layer.cornerRadius = 22;
    return button;
}

- (UIButton *)createMainButton:(NSString *)title icon:(NSString *)iconName color:(UIColor *)color {
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImage *icon = [UIImage systemImageNamed:iconName];
    [button setImage:icon forState:UIControlStateNormal];
    [button setTitle:[NSString stringWithFormat:@" %@", title] forState:UIControlStateNormal];
    button.tintColor = [UIColor whiteColor];
    button.titleLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold];
    button.backgroundColor = color;
    button.layer.cornerRadius = 22;
    
    return button;
}

- (void)setupGestures {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.mapView addGestureRecognizer:longPress];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap:)];
    [self.mapView addGestureRecognizer:tap];
}

- (void)startUIUpdateTimer {
    self.uiUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                          target:self
                                                        selector:@selector(updateVerificationUI)
                                                        userInfo:nil
                                                         repeats:YES];
}

#pragma mark - Actions

- (void)modeSelectorChanged:(UISegmentedControl *)sender {
    switch (sender.selectedSegmentIndex) {
        case 0: // Hold
            self.walkingEngine.movementMode = GhostMovementModeStatic;
            self.speedSection.hidden = YES;
            self.holdHereButton.hidden = NO;
            self.routeButton.hidden = YES;
            break;
        case 1: // Walk
            self.walkingEngine.movementMode = GhostMovementModeWalking;
            self.speedSection.hidden = NO;
            self.speedSlider.maximumValue = 4.0;
            self.speedSlider.value = 1.4;
            self.holdHereButton.hidden = YES;
            self.routeButton.hidden = NO;
            [self.routeButton setTitle:@" Start Walk" forState:UIControlStateNormal];
            [self.routeButton setImage:[UIImage systemImageNamed:@"figure.walk"] forState:UIControlStateNormal];
            break;
        case 2: // Drive
            self.walkingEngine.movementMode = GhostMovementModeDriving;
            self.speedSection.hidden = NO;
            self.speedSlider.maximumValue = 40.0;
            self.speedSlider.value = 13.9;
            self.holdHereButton.hidden = YES;
            self.routeButton.hidden = NO;
            [self.routeButton setTitle:@" Start Drive" forState:UIControlStateNormal];
            [self.routeButton setImage:[UIImage systemImageNamed:@"car.fill"] forState:UIControlStateNormal];
            break;
    }
    [self updateSpeedLabel];
    [self updateButtonStates];
}

- (void)holdHereButtonTapped {
    CLLocationCoordinate2D center = self.mapView.centerCoordinate;
    [self.walkingEngine startStaticSpoofAtLocation:center];
    [self updateUI];
    [self updateAnnotations];
    
    // Haptic feedback
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
}

- (void)routeButtonTapped {
    if (self.walkingEngine.destination.latitude == 0) {
        // No destination set
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"No Destination"
                                                                       message:@"Long-press on the map or use search to set a destination first."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }
    
    CLLocation *currentLocation = self.locationManager.location;
    CLLocationCoordinate2D startPoint = currentLocation ? currentLocation.coordinate : self.mapView.centerCoordinate;
    
    [self.walkingEngine startMovingFrom:startPoint];
    [self updateUI];
}

- (void)stopButtonTapped {
    [self.walkingEngine stopAllSpoofing];
    [self updateUI];
    [self updateAnnotations];
}

- (void)settingsButtonTapped {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithStyle:UITableViewStyleGrouped];
    settingsVC.delegate = self;
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)searchButtonTapped {
    DestinationSearchController *searchVC = [[DestinationSearchController alloc] init];
    searchVC.completionHandler = ^(CLLocationCoordinate2D coordinate) {
        [self.walkingEngine setDestination:coordinate];
        [self updateUI];
        [self updateAnnotations];
        
        // Center map on destination
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(coordinate, 1000, 1000);
        [self.mapView setRegion:region animated:YES];
    };
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:searchVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)speedSliderChanged:(UISlider *)slider {
    if (self.walkingEngine.movementMode == GhostMovementModeDriving) {
        self.walkingEngine.drivingSpeed = slider.value;
    } else {
        self.walkingEngine.walkingSpeed = slider.value;
    }
    [self updateSpeedLabel];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    
    if (self.modeSelector.selectedSegmentIndex == 0) {
        // Hold mode - start holding at this location
        [self.walkingEngine startStaticSpoofAtLocation:coordinate];
    } else {
        // Route mode - set as destination
        [self.walkingEngine setDestination:coordinate];
    }
    
    [self updateUI];
    [self updateAnnotations];
    
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
}

- (void)handleTap:(UITapGestureRecognizer *)gesture {
    // Optional: could use tap for quick actions
}

#pragma mark - UI Updates

- (void)updateUI {
    [self updateButtonStates];
    [self updateVerificationUI];
}

- (void)updateButtonStates {
    BOOL isActive = self.walkingEngine.isActive;
    
    self.holdHereButton.hidden = isActive || self.modeSelector.selectedSegmentIndex != 0;
    self.routeButton.hidden = isActive || self.modeSelector.selectedSegmentIndex == 0;
    self.stopButton.hidden = !isActive;
    
    self.modeSelector.enabled = !isActive;
}

- (void)updateVerificationUI {
    GhostSpoofStatus status = self.walkingEngine.status;
    
    // Status indicator color and text
    switch (status) {
        case GhostSpoofStatusIdle:
            self.statusIndicator.backgroundColor = [UIColor grayColor];
            self.statusMainLabel.text = @"IDLE";
            self.statusDetailLabel.text = @"Tap and hold map to set location";
            break;
            
        case GhostSpoofStatusActive:
            self.statusIndicator.backgroundColor = [UIColor systemGreenColor];
            self.statusMainLabel.text = @"🟢 SPOOFING ACTIVE";
            self.statusDetailLabel.text = [NSString stringWithFormat:@"Holding at %.6f, %.6f",
                                           self.walkingEngine.currentSpoofedLocation.latitude,
                                           self.walkingEngine.currentSpoofedLocation.longitude];
            [self pulseStatusIndicator];
            break;
            
        case GhostSpoofStatusMoving:
            self.statusIndicator.backgroundColor = [UIColor systemBlueColor];
            self.statusMainLabel.text = self.walkingEngine.movementMode == GhostMovementModeDriving ? @"🚗 DRIVING" : @"🚶 WALKING";
            self.statusDetailLabel.text = [NSString stringWithFormat:@"%.0f meters remaining",
                                           self.walkingEngine.remainingDistance];
            [self pulseStatusIndicator];
            break;
            
        case GhostSpoofStatusError:
            self.statusIndicator.backgroundColor = [UIColor systemOrangeColor];
            self.statusMainLabel.text = @"⚠️ FAILSAFE ACTIVE";
            self.statusDetailLabel.text = @"Rubber-band detected, holding last position";
            break;
    }
    
    // Stats
    self.updateCountLabel.text = [NSString stringWithFormat:@"Updates: %lu", (unsigned long)self.walkingEngine.updateCount];
    
    if (self.walkingEngine.isActive) {
        // Get current accuracy from engine (we'll need to expose this)
        self.accuracyLabel.text = [NSString stringWithFormat:@"Range: %.0f-%.0fm",
                                   self.walkingEngine.accuracyMin, self.walkingEngine.accuracyMax];
        
        // Duration
        if (self.walkingEngine.spoofStartTime) {
            NSTimeInterval duration = [[NSDate date] timeIntervalSinceDate:self.walkingEngine.spoofStartTime];
            int hours = (int)duration / 3600;
            int minutes = ((int)duration % 3600) / 60;
            int seconds = (int)duration % 60;
            
            if (hours > 0) {
                self.durationLabel.text = [NSString stringWithFormat:@"Duration: %dh %dm", hours, minutes];
            } else if (minutes > 0) {
                self.durationLabel.text = [NSString stringWithFormat:@"Duration: %dm %ds", minutes, seconds];
            } else {
                self.durationLabel.text = [NSString stringWithFormat:@"Duration: %ds", seconds];
            }
        }
    } else {
        self.accuracyLabel.text = @"Accuracy: --";
        self.durationLabel.text = @"Duration: --";
    }
}

- (void)pulseStatusIndicator {
    [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionAutoreverse | UIViewAnimationOptionRepeat animations:^{
        self.statusIndicator.alpha = 0.5;
    } completion:nil];
}

- (void)updateSpeedLabel {
    float speed = self.speedSlider.value;
    NSString *description;
    NSString *unit;
    
    if (self.walkingEngine.movementMode == GhostMovementModeDriving) {
        // Convert m/s to km/h for driving
        float kmh = speed * 3.6;
        if (kmh < 30) {
            description = @"Slow";
        } else if (kmh < 60) {
            description = @"City";
        } else if (kmh < 100) {
            description = @"Highway";
        } else {
            description = @"Fast";
        }
        unit = [NSString stringWithFormat:@"%.0f km/h (%@)", kmh, description];
    } else {
        if (speed <= 1.0) {
            description = @"Slow Walk";
        } else if (speed <= 1.5) {
            description = @"Walk";
        } else if (speed <= 2.5) {
            description = @"Fast Walk";
        } else {
            description = @"Jog";
        }
        unit = [NSString stringWithFormat:@"%.1f m/s (%@)", speed, description];
    }
    
    self.speedLabel.text = unit;
}

- (void)updateAnnotations {
    // Remove existing
    NSMutableArray *toRemove = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if (![annotation isKindOfClass:[MKUserLocation class]]) {
            [toRemove addObject:annotation];
        }
    }
    [self.mapView removeAnnotations:toRemove];
    [self.mapView removeOverlays:self.mapView.overlays];
    
    // Real location (gray)
    CLLocation *realLocation = self.locationManager.location;
    if (realLocation) {
        self.realLocationAnnotation.coordinate = realLocation.coordinate;
        [self.mapView addAnnotation:self.realLocationAnnotation];
    }
    
    // Spoofed location (green)
    if (self.walkingEngine.currentSpoofedLocation.latitude != 0) {
        self.spoofedLocationAnnotation.coordinate = self.walkingEngine.currentSpoofedLocation;
        [self.mapView addAnnotation:self.spoofedLocationAnnotation];
    }
    
    // Destination (red) - only for route mode
    if (self.walkingEngine.destination.latitude != 0 && self.modeSelector.selectedSegmentIndex != 0) {
        self.destinationAnnotation.coordinate = self.walkingEngine.destination;
        [self.mapView addAnnotation:self.destinationAnnotation];
    }
    
    // Route polyline
    NSArray *route = self.walkingEngine.currentRoute;
    if (route.count > 1) {
        CLLocationCoordinate2D *coords = malloc(sizeof(CLLocationCoordinate2D) * route.count);
        for (NSUInteger i = 0; i < route.count; i++) {
            CLLocation *loc = route[i];
            coords[i] = loc.coordinate;
        }
        self.routePolyline = [MKPolyline polylineWithCoordinates:coords count:route.count];
        [self.mapView addOverlay:self.routePolyline];
        free(coords);
    }
    
    // Walked path
    NSArray *walkedPath = self.walkingEngine.walkedPath;
    if (walkedPath.count > 1) {
        CLLocationCoordinate2D *coords = malloc(sizeof(CLLocationCoordinate2D) * walkedPath.count);
        for (NSUInteger i = 0; i < walkedPath.count; i++) {
            CLLocation *loc = walkedPath[i];
            coords[i] = loc.coordinate;
        }
        self.walkedPolyline = [MKPolyline polylineWithCoordinates:coords count:walkedPath.count];
        [self.mapView addOverlay:self.walkedPolyline];
        free(coords);
    }
}

#pragma mark - CLLocationManagerDelegate

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
    if (status == kCLAuthorizationStatusAuthorizedAlways || status == kCLAuthorizationStatusAuthorizedWhenInUse) {
        [self.locationManager startUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations {
    CLLocation *location = locations.lastObject;
    if (!location) return;
    
    if (!self.hasInitializedMap) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(location.coordinate, 1000, 1000);
        [self.mapView setRegion:region animated:YES];
        self.hasInitializedMap = YES;
    }
    
    [self updateAnnotations];
}

#pragma mark - MKMapViewDelegate

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    }
    
    MKMarkerAnnotationView *markerView = (MKMarkerAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:@"marker"];
    if (!markerView) {
        markerView = [[MKMarkerAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:@"marker"];
        markerView.canShowCallout = YES;
    } else {
        markerView.annotation = annotation;
    }
    
    if (annotation == self.realLocationAnnotation) {
        markerView.markerTintColor = [UIColor grayColor];
        markerView.glyphImage = [UIImage systemImageNamed:@"location.fill"];
    } else if (annotation == self.spoofedLocationAnnotation) {
        markerView.markerTintColor = [UIColor systemGreenColor];
        markerView.glyphImage = [UIImage systemImageNamed:@"figure.stand"];
    } else if (annotation == self.destinationAnnotation) {
        markerView.markerTintColor = [UIColor systemRedColor];
        markerView.glyphImage = [UIImage systemImageNamed:@"flag.fill"];
    }
    
    return markerView;
}

- (MKOverlayRenderer *)mapView:(MKMapView *)mapView rendererForOverlay:(id<MKOverlay>)overlay {
    if ([overlay isKindOfClass:[MKPolyline class]]) {
        MKPolylineRenderer *renderer = [[MKPolylineRenderer alloc] initWithPolyline:(MKPolyline *)overlay];
        
        if (overlay == self.walkedPolyline) {
            renderer.strokeColor = [[UIColor systemGreenColor] colorWithAlphaComponent:0.8];
            renderer.lineWidth = 4;
        } else {
            renderer.strokeColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.6];
            renderer.lineWidth = 3;
            renderer.lineDashPattern = @[@10, @5];
        }
        
        return renderer;
    }
    return [[MKOverlayRenderer alloc] initWithOverlay:overlay];
}

#pragma mark - WalkingEngineDelegate

- (void)walkingEngineDidUpdateLocation:(WalkingEngine *)engine {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateAnnotations];
        
        // Center map on spoofed location when moving
        if (engine.isMoving && engine.currentSpoofedLocation.latitude != 0) {
            MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(engine.currentSpoofedLocation, 500, 500);
            [self.mapView setRegion:region animated:YES];
        }
    });
}

- (void)walkingEngineDidFinish:(WalkingEngine *)engine {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
        [self updateAnnotations];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Arrived!"
                                                                       message:@"You have reached your destination. Location will continue to be spoofed here."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)walkingEngineDidDetectRubberBand:(WalkingEngine *)engine {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
        
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"⚠️ Failsafe Activated"
                                                                       message:@"A sudden location jump was detected. Freezing at last known good location to prevent rubber-banding."
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)walkingEngineStatusDidChange:(WalkingEngine *)engine {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateUI];
    });
}

#pragma mark - SettingsViewControllerDelegate

- (void)settingsDidChange {
    // Reload settings into walking engine
    self.walkingEngine.walkingSpeed = [SettingsViewController walkingSpeed];
    self.walkingEngine.drivingSpeed = [SettingsViewController drivingSpeed];
    self.walkingEngine.driftMin = [SettingsViewController driftMin];
    self.walkingEngine.driftMax = [SettingsViewController driftMax];
    self.walkingEngine.accuracyMin = [SettingsViewController accuracyMin];
    self.walkingEngine.accuracyMax = [SettingsViewController accuracyMax];
    self.walkingEngine.accuracyUpdateInterval = [SettingsViewController accuracyUpdateInterval];
    self.walkingEngine.maxJumpDistance = [SettingsViewController failsafeThreshold];
    
    // Altitude settings - applied to LocationSimulator
    LocationSimulator *sim = [LocationSimulator sharedSimulator];
    sim.altitude = [SettingsViewController altitude];
    sim.altitudeEnabled = [SettingsViewController altitudeEnabled];
    
    [self updateUI];
}

@end
