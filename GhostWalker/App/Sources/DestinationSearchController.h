//
//  DestinationSearchController.h
//  Ghost Walker
//
//  Location search UI
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

typedef void (^DestinationSelectedHandler)(CLLocationCoordinate2D coordinate);

@interface DestinationSearchController : UIViewController

@property (nonatomic, copy) DestinationSelectedHandler completionHandler;

@end
