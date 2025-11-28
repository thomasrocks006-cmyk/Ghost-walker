//
//  DestinationSearchController.m
//  Ghost Walker
//
//  Location search UI
//

#import "DestinationSearchController.h"

@interface DestinationSearchController () <UISearchBarDelegate, UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, strong) UISearchBar *searchBar;
@property (nonatomic, strong) UITableView *tableView;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, strong) UILabel *emptyLabel;

@property (nonatomic, strong) NSArray<MKMapItem *> *searchResults;
@property (nonatomic, strong) MKLocalSearch *currentSearch;

@end

@implementation DestinationSearchController

#pragma mark - Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"Set Destination";
    self.view.backgroundColor = [UIColor systemBackgroundColor];
    
    // Navigation bar
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel 
                                                                                          target:self 
                                                                                          action:@selector(cancelTapped)];
    
    [self setupSearchBar];
    [self setupTableView];
    [self setupEmptyState];
    [self setupActivityIndicator];
    
    self.searchResults = @[];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.searchBar becomeFirstResponder];
}

#pragma mark - Setup

- (void)setupSearchBar {
    self.searchBar = [[UISearchBar alloc] init];
    self.searchBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.searchBar.placeholder = @"Search for a place";
    self.searchBar.delegate = self;
    self.searchBar.searchBarStyle = UISearchBarStyleMinimal;
    [self.view addSubview:self.searchBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.searchBar.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
        [self.searchBar.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:8],
        [self.searchBar.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-8],
    ]];
}

- (void)setupTableView {
    self.tableView = [[UITableView alloc] initWithFrame:CGRectZero style:UITableViewStylePlain];
    self.tableView.translatesAutoresizingMaskIntoConstraints = NO;
    self.tableView.dataSource = self;
    self.tableView.delegate = self;
    self.tableView.keyboardDismissMode = UIScrollViewKeyboardDismissModeOnDrag;
    // Don't register class - we'll create cells with subtitle style manually
    [self.view addSubview:self.tableView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.tableView.topAnchor constraintEqualToAnchor:self.searchBar.bottomAnchor constant:8],
        [self.tableView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.tableView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.tableView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
    ]];
}

- (void)setupEmptyState {
    self.emptyLabel = [[UILabel alloc] init];
    self.emptyLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.emptyLabel.text = @"Search for a destination";
    self.emptyLabel.textColor = [UIColor secondaryLabelColor];
    self.emptyLabel.textAlignment = NSTextAlignmentCenter;
    self.emptyLabel.font = [UIFont systemFontOfSize:17];
    [self.view addSubview:self.emptyLabel];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

- (void)setupActivityIndicator {
    self.activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    self.activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    self.activityIndicator.hidesWhenStopped = YES;
    [self.view addSubview:self.activityIndicator];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.activityIndicator.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.activityIndicator.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
    ]];
}

#pragma mark - Actions

- (void)cancelTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)performSearch:(NSString *)query {
    // Cancel previous search
    [self.currentSearch cancel];
    
    if (query.length == 0) {
        self.searchResults = @[];
        [self.tableView reloadData];
        self.emptyLabel.text = @"Search for a destination";
        self.emptyLabel.hidden = NO;
        return;
    }
    
    self.emptyLabel.hidden = YES;
    [self.activityIndicator startAnimating];
    
    MKLocalSearchRequest *request = [[MKLocalSearchRequest alloc] init];
    request.naturalLanguageQuery = query;
    
    self.currentSearch = [[MKLocalSearch alloc] initWithRequest:request];
    
    __weak typeof(self) weakSelf = self;
    [self.currentSearch startWithCompletionHandler:^(MKLocalSearchResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf.activityIndicator stopAnimating];
            
            if (error) {
                weakSelf.searchResults = @[];
                weakSelf.emptyLabel.text = @"No results found";
                weakSelf.emptyLabel.hidden = NO;
            } else {
                weakSelf.searchResults = response.mapItems;
                weakSelf.emptyLabel.hidden = weakSelf.searchResults.count > 0;
                if (weakSelf.searchResults.count == 0) {
                    weakSelf.emptyLabel.text = @"No results found";
                }
            }
            
            [weakSelf.tableView reloadData];
        });
    }];
}

- (NSString *)iconForCategory:(MKPointOfInterestCategory)category {
    if (!category) return @"mappin";
    
    if ([category isEqualToString:MKPointOfInterestCategoryRestaurant] ||
        [category isEqualToString:MKPointOfInterestCategoryCafe] ||
        [category isEqualToString:MKPointOfInterestCategoryBakery]) {
        return @"fork.knife";
    } else if ([category isEqualToString:MKPointOfInterestCategoryStore]) {
        return @"bag";
    } else if ([category isEqualToString:MKPointOfInterestCategoryPark] ||
               [category isEqualToString:MKPointOfInterestCategoryNationalPark]) {
        return @"leaf";
    } else if ([category isEqualToString:MKPointOfInterestCategoryHotel]) {
        return @"bed.double";
    } else if ([category isEqualToString:MKPointOfInterestCategoryAirport]) {
        return @"airplane";
    } else if ([category isEqualToString:MKPointOfInterestCategoryHospital]) {
        return @"cross.case";
    } else if ([category isEqualToString:MKPointOfInterestCategorySchool] ||
               [category isEqualToString:MKPointOfInterestCategoryUniversity]) {
        return @"graduationcap";
    } else if ([category isEqualToString:MKPointOfInterestCategoryMuseum]) {
        return @"building.columns";
    }
    
    return @"mappin";
}

#pragma mark - UISearchBarDelegate

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    // Debounce search
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(performDelayedSearch) object:nil];
    [self performSelector:@selector(performDelayedSearch) withObject:nil afterDelay:0.3];
}

- (void)performDelayedSearch {
    [self performSearch:self.searchBar.text];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    [self performSearch:searchBar.text];
}

#pragma mark - UITableViewDataSource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.searchResults.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId = @"cell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellId];
    }
    
    MKMapItem *item = self.searchResults[indexPath.row];
    
    // Configure cell using older API (iOS 13 compatible)
    cell.textLabel.text = item.name ?: @"Unknown";
    cell.detailTextLabel.text = item.placemark.title;
    cell.detailTextLabel.textColor = [UIColor secondaryLabelColor];
    
    NSString *iconName = [self iconForCategory:item.pointOfInterestCategory];
    cell.imageView.image = [UIImage systemImageNamed:iconName];
    cell.imageView.tintColor = [UIColor systemBlueColor];
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    MKMapItem *item = self.searchResults[indexPath.row];
    CLLocationCoordinate2D coordinate = item.placemark.coordinate;
    
    if (self.completionHandler) {
        self.completionHandler(coordinate);
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
