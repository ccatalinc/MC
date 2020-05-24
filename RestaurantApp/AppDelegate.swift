import UIKit
import Moya
import CoreLocation
import SystemConfiguration
import UserNotifications

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let window = UIWindow()
    let locationService = LocationService()
    let storyboard = UIStoryboard(name: "Main", bundle: nil)
    let service = MoyaProvider<YelpService.BusinessesProvider>()
    let jsonDecoder = JSONDecoder()
    var navigationController: UINavigationController?



    public class Reachability {

        class func isConnectedToNetwork() -> Bool {

            var zeroAddress = sockaddr_in(sin_len: 0, sin_family: 0, sin_port: 0, sin_addr: in_addr(s_addr: 0), sin_zero: (0, 0, 0, 0, 0, 0, 0, 0))
            zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
            zeroAddress.sin_family = sa_family_t(AF_INET)

            let defaultRouteReachability = withUnsafePointer(to: &zeroAddress) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {zeroSockAddress in
                    SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
                }
            }

            var flags: SCNetworkReachabilityFlags = SCNetworkReachabilityFlags(rawValue: 0)
            if SCNetworkReachabilityGetFlags(defaultRouteReachability!, &flags) == false {
                return false
            }

            let isReachable = (flags.rawValue & UInt32(kSCNetworkFlagsReachable)) != 0
            let needsConnection = (flags.rawValue & UInt32(kSCNetworkFlagsConnectionRequired)) != 0
            let ret = (isReachable && !needsConnection)

            return ret

        }
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        if Reachability.isConnectedToNetwork(){
            createAlert(title: "WIFI", message: "Great, you can use the app")
            print("Internet Connection(Wifi) is Available!")
        }else{
            createAlert(title: "Internet Error", message: "Please connect to wifi")
            print("Internet Connection(Wifi) not Available!")
        }
        
        let content = UNMutableNotificationContent()
        content.title = "RestaurantApp"
        content.body = "I found 10 restaurants that are ready for you"
        content.badge = 1
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 30, repeats: false)
        let request = UNNotificationRequest(identifier: "timerDone", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        
        
        jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

        locationService.didChangeStatus = { [weak self] success in
            if success {
                self?.locationService.getLocation()
            }
        }

        locationService.newLocation = { [weak self] result in
            switch result {
            case .success(let location):
                self?.loadBusinesses(with: location.coordinate)
            case .failure(let error):
                assertionFailure("Error getting the users location \(error)")
            }
        }

        switch locationService.status {
        case .notDetermined, .denied, .restricted:
            let locationViewController = storyboard.instantiateViewController(withIdentifier: "LocationViewController") as? LocationViewController
            locationViewController?.delegate = self
            window.rootViewController = locationViewController
        default:
            let nav = storyboard
                .instantiateViewController(withIdentifier: "RestaurantNavigationController") as? UINavigationController
            self.navigationController = nav
            window.rootViewController = nav
            locationService.getLocation()
            (nav?.topViewController as? RestaurantTableViewController)?.delegete = self
        }
        window.makeKeyAndVisible()
        
        return true
    }

    private func loadDetails(for viewController: UIViewController, withId id: String) {
        service.request(.details(id: id)) { [weak self] (result) in
            switch result {
            case .success(let response):
                guard let strongSelf = self else { return }
                if let details = try? strongSelf.jsonDecoder.decode(Details.self, from: response.data) {
                    let detailsViewModel = DetailsViewModel(details: details)
                    (viewController as? DetailsFoodViewController)?.viewModel = detailsViewModel
                }
            case .failure(let error):
                print("Failed to get details \(error)")
            }
        }
    }

    private func loadBusinesses(with coordinate: CLLocationCoordinate2D) {
        service.request(.search(lat: coordinate.latitude, long: coordinate.longitude)) { [weak self] (result) in
            guard let strongSelf = self else { return }
            switch result {
            case .success(let response):
                let root = try? strongSelf.jsonDecoder.decode(Root.self, from: response.data)
                let viewModels = root?.businesses
                    .compactMap(RestaurantListViewModel.init)
                    .sorted(by: { $0.distance < $1.distance })
                if let nav = strongSelf.window.rootViewController as? UINavigationController,
                    let restaurantListViewController = nav.topViewController as? RestaurantTableViewController {
                    restaurantListViewController.viewModels = viewModels ?? []
                } else if let nav = strongSelf.storyboard
                    .instantiateViewController(withIdentifier: "RestaurantNavigationController") as? UINavigationController {
                    strongSelf.navigationController = nav
                    strongSelf.window.rootViewController?.present(nav, animated: true) {
                        (nav.topViewController as? RestaurantTableViewController)?.delegete = self
                        (nav.topViewController as? RestaurantTableViewController)?.viewModels = viewModels ?? []
                    }
                }
            case .failure(let error):
                print("Error: \(error)")
            }
        }
    }
}

extension AppDelegate: LocationActions, ListActions {
    func didTapAllow() {
        locationService.requestLocationAuthorization()
        registerForPushNotifications()
    }

    func didTapCell(_ viewController: UIViewController, viewModel: RestaurantListViewModel) {
        loadDetails(for: viewController, withId: viewModel.id)
    }
}

func registerForPushNotifications() {
  UNUserNotificationCenter.current()
    .requestAuthorization(options: [.alert, .sound, .badge]) {
      granted, error in
      print("Permission granted: \(granted)")
  }
}

func createAlert(title:String, message:String){
    _ = UIAlertController(title: title, message: message, preferredStyle: UIAlertController.Style.alert)
}
