import Foundation
import Moya


private let apiKey = "0BM9-MHFvdmX8YJGjC2XnebZ__4MBJ5zlDSRzIQhU3sufh9KKD2GYsGVAFEdq9qtcuOCApr-OUCSpaaOJBxWRQKZ2mDo81GbSiCovMzjJ52EMcFzo4eamGCCCuihXnYx"

enum YelpService {
    enum BusinessesProvider: TargetType {
        case search(lat: Double, long: Double)
        case details(id: String)
        
        var baseURL: URL {
            return URL(string: "https://api.yelp.com/v3/businesses")!
        }

        var path: String {
            switch self {
            case .search:
                return "/search"
            case let .details(id):
                return "/\(id)"
            }
        }

        var method: Moya.Method {
            return .get
        }

        var sampleData: Data {
            return Data()
        }

        var task: Task {
            switch self {
            case let .search(lat, long):
                return .requestParameters(
                    parameters: ["latitude": 48.864716, "longitude": 2.349014, "limit": 10], encoding: URLEncoding.queryString)
            case .details:
                return .requestPlain
            }
            
        }

        var headers: [String : String]? {
            return ["Authorization": "Bearer \(apiKey)"]
        }
    }
}
