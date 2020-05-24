import UIKit

protocol LocationActions: class {
    func didTapAllow()
}

class LocationViewController: UIViewController {
 

    
    @IBOutlet weak var locationView: LocationView!
    weak var delegate: LocationActions?

    override func viewDidLoad() {
        super.viewDidLoad()

        locationView.didTapAllow = {
            self.delegate?.didTapAllow()
        }

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    


}
