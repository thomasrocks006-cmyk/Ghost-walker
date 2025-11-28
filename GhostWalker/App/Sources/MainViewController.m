//
//  MainViewController.m
//  Ghost Walker
//
//  Main dashboard with map and controls
//

#import "MainViewController.h"
#import "WalkingEngine.h"
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

// UI Elements
@property (nonatomic, strong) UIView *statusBar;
@property (nonatomic, strong) UIView *statusDot;
@property (nonatomic, strong) UILabel *statusLabel;
@property (nonatomic, strong) UILabel *distanceLabel;

@property (nonatomic, strong) UIView *controlPanel;
@property (nonatomic, strong) UIButton *mainButton;
@property (nonatomic, strong) UIButton *settingsButton;
@property (nonatomic, strong) UIButton *searchButton;
@property (nonatomic, strong) UISlider *speedSlider;
@property (nonatomic, strong) UILabel *speedLabel;

// Engine
@property (nonatomic, strong) WalkingEngine *walkingEngine;

// State
@property (nonatomic, assign) BOOL hasInitializedMap;

@end

@implementation MainViewController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self setupWalkingEngine];
    [self setupLocationManager];
    [self setupMapView];
    [self setupStatusBar];
    [self setupControlPanel];
    [self setupGestures];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.locationManager requestAlwaysAuthorization];
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
    
    // Create annotations
    self.realLocationAnnotation = [[MKPointAnnotation alloc] init];
    self.realLocationAnnotation.title = @"Real Location";
    
    self.spoofedLocationAnnotation = [[MKPointAnnotation alloc] init];
    self.spoofedLocationAnnotation.title = @"Spoofed Location";
    
    self.destinationAnnotation = [[MKPointAnnotation alloc] init];
    self.destinationAnnotation.title = @"Destination";
}

- (void)setupStatusBar {
    // Container
    self.statusBar = [[UIView alloc] init];
    self.statusBar.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.statusBar];
    
    // Status indicator (left side)
    UIView *statusContainer = [[UIView alloc] init];
    statusContainer.translatesAutoresizingMaskIntoConstraints = NO;
    statusContainer.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    statusContainer.layer.cornerRadius = 16;
    [self.statusBar addSubview:statusContainer];
    
    self.statusDot = [[UIView alloc] init];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.backgroundColor = [UIColor grayColor];
    self.statusDot.layer.cornerRadius = 6;
    [statusContainer addSubview:self.statusDot];
    
    self.statusLabel = [[UILabel alloc] init];
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.text = @"Idle";
    self.statusLabel.textColor = [UIColor whiteColor];
    self.statusLabel.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    [statusContainer addSubview:self.statusLabel];
    
    // Distance label (right side)
    self.distanceLabel = [[UILabel alloc] init];
    self.distanceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.distanceLabel.textColor = [UIColor whiteColor];
    self.distanceLabel.font = [UIFont monospacedSystemFontOfSize:14 weight:UIFontWeightMedium];
    self.distanceLabel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
    self.distanceLabel.textAlignment = NSTextAlignmentCenter;
    self.distanceLabel.layer.cornerRadius = 16;
    self.distanceLabel.layer.masksToBounds = YES;
    self.distanceLabel.hidden = YES;
    [self.statusBar addSubview:self.distanceLabel];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.statusBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:8],
        [self.statusBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.statusBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        [self.statusBar.heightAnchor constraintEqualToConstant:32],
        
        [statusContainer.leadingAnchor constraintEqualToAnchor:self.statusBar.leadingAnchor],
        [statusContainer.centerYAnchor constraintEqualToAnchor:self.statusBar.centerYAnchor],
        [statusContainer.heightAnchor constraintEqualToConstant:32],
        
        [self.statusDot.leadingAnchor constraintEqualToAnchor:statusContainer.leadingAnchor constant:12],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:12],
        [self.statusDot.heightAnchor constraintEqualToConstant:12],
        
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:8],
        [self.statusLabel.trailingAnchor constraintEqualToAnchor:statusContainer.trailingAnchor constant:-12],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:statusContainer.centerYAnchor],
        
        [self.distanceLabel.trailingAnchor constraintEqualToAnchor:self.statusBar.trailingAnchor],
        [self.distanceLabel.centerYAnchor constraintEqualToAnchor:self.statusBar.centerYAnchor],
        [self.distanceLabel.heightAnchor constraintEqualToConstant:32],
        [self.distanceLabel.widthAnchor constraintGreaterThanOrEqualToConstant:80],
    ]];
}

- (void)setupControlPanel {
    // Container
    self.controlPanel = [[UIView alloc] init];
    self.controlPanel.translatesAutoresizingMaskIntoConstraints = NO;
    self.controlPanel.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.85];
    self.controlPanel.layer.cornerRadius = 20;
    [self.view addSubview:self.controlPanel];
    
    // Speed slider section
    UIView *speedSection = [[UIView alloc] init];
    speedSection.translatesAutoresizingMaskIntoConstraints = NO;
    speedSection.hidden = YES;
    speedSection.tag = 100; // Tag for later access
    [self.controlPanel addSubview:speedSection];
    
    UILabel *speedTitle = [[UILabel alloc] init];
    speedTitle.translatesAutoresizingMaskIntoConstraints = NO;
    speedTitle.text = @"Speed";
    speedTitle.textColor = [UIColor grayColor];
    speedTitle.font = [UIFont systemFontOfSize:12 weight:UIFontWeightMedium];
    [speedSection addSubview:speedTitle];
    
    self.speedLabel = [[UILabel alloc] init];
    self.speedLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.speedLabel.text = @"1.4 m/s";
    self.speedLabel.textColor = [UIColor whiteColor];
    self.speedLabel.font = [UIFont monospacedSystemFontOfSize:12 weight:UIFontWeightMedium];
    [speedSection addSubview:self.speedLabel];
    
    self.speedSlider = [[UISlider alloc] init];
    self.speedSlider.translatesAutoresizingMaskIntoConstraints = NO;
    self.speedSlider.minimumValue = 0.5;
    self.speedSlider.maximumValue = 8.0;
    self.speedSlider.value = 1.4;
    self.speedSlider.tintColor = [UIColor systemGreenColor];
    [self.speedSlider addTarget:self action:@selector(speedSliderChanged:) forControlEvents:UIControlEventValueChanged];
    [speedSection addSubview:self.speedSlider];
    
    // Buttons row
    UIStackView *buttonStack = [[UIStackView alloc] init];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.axis = UILayoutConstraintAxisHorizontal;
    buttonStack.spacing = 16;
    buttonStack.alignment = UIStackViewAlignmentCenter;
    [self.controlPanel addSubview:buttonStack];
    
    // Settings button
    self.settingsButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.settingsButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.settingsButton setImage:[UIImage systemImageNamed:@"gearshape.fill"] forState:UIControlStateNormal];
    self.settingsButton.tintColor = [UIColor whiteColor];
    self.settingsButton.backgroundColor = [[UIColor grayColor] colorWithAlphaComponent:0.8];
    self.settingsButton.layer.cornerRadius = 25;
    [self.settingsButton addTarget:self action:@selector(settingsButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.settingsButton];
    
    // Main button
    self.mainButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.mainButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.mainButton.backgroundColor = [UIColor systemBlueColor];
    self.mainButton.layer.cornerRadius = 25;
    self.mainButton.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    [self.mainButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [self.mainButton addTarget:self action:@selector(mainButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.mainButton];
    
    // Search button
    self.searchButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.searchButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.searchButton setImage:[UIImage systemImageNamed:@"mappin.circle.fill"] forState:UIControlStateNormal];
    self.searchButton.tintColor = [UIColor whiteColor];
    self.searchButton.backgroundColor = [[UIColor systemBlueColor] colorWithAlphaComponent:0.8];
    self.searchButton.layer.cornerRadius = 25;
    [self.searchButton addTarget:self action:@selector(searchButtonTapped) forControlEvents:UIControlEventTouchUpInside];
    [buttonStack addArrangedSubview:self.searchButton];
    
    [self updateMainButton];
    
    // Constraints
    [NSLayoutConstraint activateConstraints:@[
        [self.controlPanel.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-16],
        [self.controlPanel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:16],
        [self.controlPanel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-16],
        
        [speedSection.topAnchor constraintEqualToAnchor:self.controlPanel.topAnchor constant:16],
        [speedSection.leadingAnchor constraintEqualToAnchor:self.controlPanel.leadingAnchor constant:16],
        [speedSection.trailingAnchor constraintEqualToAnchor:self.controlPanel.trailingAnchor constant:-16],
        
        [speedTitle.topAnchor constraintEqualToAnchor:speedSection.topAnchor],
        [speedTitle.leadingAnchor constraintEqualToAnchor:speedSection.leadingAnchor],
        
        [self.speedLabel.topAnchor constraintEqualToAnchor:speedSection.topAnchor],
        [self.speedLabel.trailingAnchor constraintEqualToAnchor:speedSection.trailingAnchor],
        
        [self.speedSlider.topAnchor constraintEqualToAnchor:speedTitle.bottomAnchor constant:8],
        [self.speedSlider.leadingAnchor constraintEqualToAnchor:speedSection.leadingAnchor],
        [self.speedSlider.trailingAnchor constraintEqualToAnchor:speedSection.trailingAnchor],
        [self.speedSlider.bottomAnchor constraintEqualToAnchor:speedSection.bottomAnchor],
        
        [buttonStack.topAnchor constraintEqualToAnchor:speedSection.bottomAnchor constant:16],
        [buttonStack.centerXAnchor constraintEqualToAnchor:self.controlPanel.centerXAnchor],
        [buttonStack.bottomAnchor constraintEqualToAnchor:self.controlPanel.bottomAnchor constant:-16],
        
        [self.settingsButton.widthAnchor constraintEqualToConstant:50],
        [self.settingsButton.heightAnchor constraintEqualToConstant:50],
        
        [self.mainButton.widthAnchor constraintEqualToConstant:180],
        [self.mainButton.heightAnchor constraintEqualToConstant:50],
        
        [self.searchButton.widthAnchor constraintEqualToConstant:50],
        [self.searchButton.heightAnchor constraintEqualToConstant:50],
    ]];
}

- (void)setupGestures {
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
    longPress.minimumPressDuration = 0.5;
    [self.mapView addGestureRecognizer:longPress];
}

#pragma mark - Actions

- (void)mainButtonTapped {
    if (self.walkingEngine.isWalking) {
        [self.walkingEngine stopWalking];
    } else if (self.walkingEngine.destination.latitude != 0) {
        CLLocation *currentLocation = self.locationManager.location;
        if (currentLocation) {
            [self.walkingEngine startWalkingFrom:currentLocation.coordinate];
        }
    }
    [self updateUI];
}

- (void)settingsButtonTapped {
    SettingsViewController *settingsVC = [[SettingsViewController alloc] initWithWalkingEngine:self.walkingEngine];
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settingsVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)searchButtonTapped {
    DestinationSearchController *searchVC = [[DestinationSearchController alloc] init];
    searchVC.completionHandler = ^(CLLocationCoordinate2D coordinate) {
        [self.walkingEngine setDestination:coordinate];
        [self updateUI];
        [self updateAnnotations];
    };
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:searchVC];
    [self presentViewController:navController animated:YES completion:nil];
}

- (void)speedSliderChanged:(UISlider *)slider {
    self.walkingEngine.walkingSpeed = slider.value;
    [self updateSpeedLabel];
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) return;
    
    CGPoint point = [gesture locationInView:self.mapView];
    CLLocationCoordinate2D coordinate = [self.mapView convertPoint:point toCoordinateFromView:self.mapView];
    
    [self.walkingEngine setDestination:coordinate];
    [self updateUI];
    [self updateAnnotations];
    
    // Haptic feedback
    UIImpactFeedbackGenerator *feedback = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [feedback impactOccurred];
}

#pragma mark - UI Updates

- (void)updateUI {
    [self updateMainButton];
    [self updateStatusBar];
    [self updateSpeedSection];
}

- (void)updateMainButton {
    NSString *title;
    NSString *iconName;
    UIColor *color;
    
    if (self.walkingEngine.isWalking) {
        title = @"  Stop";
        iconName = @"stop.fill";
        color = [UIColor systemRedColor];
    } else if (self.walkingEngine.destination.latitude != 0) {
        title = @"  Start Walking";
        iconName = @"figure.walk";
        color = [UIColor systemGreenColor];
    } else {
        title = @"  Set Destination";
        iconName = @"location.fill";
        color = [UIColor systemBlueColor];
    }
    
    UIImage *icon = [UIImage systemImageNamed:iconName];
    [self.mainButton setImage:icon forState:UIControlStateNormal];
    [self.mainButton setTitle:title forState:UIControlStateNormal];
    self.mainButton.tintColor = [UIColor whiteColor];
    self.mainButton.backgroundColor = color;
}

- (void)updateStatusBar {
    UIColor *dotColor;
    NSString *statusText;
    
    if (self.walkingEngine.isWalking) {
        dotColor = [UIColor systemGreenColor];
        statusText = @"Walking";
        self.distanceLabel.hidden = NO;
    } else if (self.walkingEngine.currentSpoofedLocation.latitude != 0) {
        dotColor = [UIColor systemOrangeColor];
        statusText = @"Spoofing";
        self.distanceLabel.hidden = YES;
    } else {
        dotColor = [UIColor grayColor];
        statusText = @"Idle";
        self.distanceLabel.hidden = YES;
    }
    
    self.statusDot.backgroundColor = dotColor;
    self.statusLabel.text = statusText;
    
    // Update distance label
    double distance = self.walkingEngine.remainingDistance;
    if (distance >= 1000) {
        self.distanceLabel.text = [NSString stringWithFormat:@"  %.1f km  ", distance / 1000];
    } else {
        self.distanceLabel.text = [NSString stringWithFormat:@"  %.0f m  ", distance];
    }
}

- (void)updateSpeedSection {
    UIView *speedSection = [self.controlPanel viewWithTag:100];
    speedSection.hidden = !self.walkingEngine.isWalking;
}

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
    
    self.speedLabel.text = [NSString stringWithFormat:@"%.1f m/s (%@)", speed, description];
}

- (void)updateAnnotations {
    // Remove existing annotations (except user location)
    NSMutableArray *toRemove = [NSMutableArray array];
    for (id<MKAnnotation> annotation in self.mapView.annotations) {
        if (![annotation isKindOfClass:[MKUserLocation class]]) {
            [toRemove addObject:annotation];
        }
    }
    [self.mapView removeAnnotations:toRemove];
    
    // Remove overlays
    [self.mapView removeOverlays:self.mapView.overlays];
    
    // Add real location
    CLLocation *realLocation = self.locationManager.location;
    if (realLocation) {
        self.realLocationAnnotation.coordinate = realLocation.coordinate;
        [self.mapView addAnnotation:self.realLocationAnnotation];
    }
    
    // Add spoofed location
    if (self.walkingEngine.currentSpoofedLocation.latitude != 0) {
        self.spoofedLocationAnnotation.coordinate = self.walkingEngine.currentSpoofedLocation;
        [self.mapView addAnnotation:self.spoofedLocationAnnotation];
    }
    
    // Add destination
    if (self.walkingEngine.destination.latitude != 0) {
        self.destinationAnnotation.coordinate = self.walkingEngine.destination;
        [self.mapView addAnnotation:self.destinationAnnotation];
    }
    
    // Add route polyline
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
    
    // Add walked path polyline
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
    
    // Initial map centering
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
        markerView.glyphImage = [UIImage systemImageNamed:@"figure.walk"];
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
        [self updateUI];
        [self updateAnnotations];
        
        // Center map on spoofed location
        if (engine.currentSpoofedLocation.latitude != 0) {
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
                                                                       message:@"You have reached your destination." 
                                                                preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

@end
