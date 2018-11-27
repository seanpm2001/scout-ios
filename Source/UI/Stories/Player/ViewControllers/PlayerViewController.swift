//
//  PlayerViewController.swift
//  Scout
//
//  Created by Shurupov Alex on 5/23/18.
//

import AVFoundation
import UIKit

protocol PlayerViewControllerDelegate: class {
    // maybe need send also several button states
    func backButtonTapped()
}

class PlayerViewController: UIViewController {
    weak var backButtonDelegate: PlayerViewControllerDelegate?
    var scoutClient: ScoutHTTPClient!
    var model: ScoutArticle!
    var keychainService: KeychainService!
    var isFullArticle: Bool = true
    fileprivate var audioPlayer: AVAudioPlayer!
    fileprivate var audioRate: Float = 1.0
    fileprivate var spinner: UIActivityIndicatorView?
    fileprivate var timer: Timer!
    fileprivate let loadingTextLabel = UILabel()

    @IBOutlet weak var faviconButton: UIButton!
    @IBOutlet weak var playPauseView: UIView!
    @IBOutlet weak var pauseButton: UIButton!
    @IBOutlet weak var modeButton: UIButton!
    @IBOutlet weak var mainImage: UIImageView!
    @IBOutlet weak var backwardButton: UIButton!
    @IBOutlet weak var forwardButton: UIButton!
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var startTime: UILabel!
    @IBOutlet weak var endTime: UILabel!
    @IBOutlet weak var backButton: UIButton!
    @IBOutlet weak var audioRateButton: UIButton!
    @IBOutlet weak var author: UILabel!
    @IBOutlet weak var excerpt: UITextView!

    private var userDefaults = UserDefaults()

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        spinner = self.addSpinner()
        playPauseView.layer.cornerRadius = CGFloat(30.0)
        playPauseView.layer.borderWidth = 1
        playPauseView.layer.borderColor = UIColor.black.cgColor
    }

    fileprivate func configureView() {
        /*
        let width = self.mainImage.bounds.size.width
        let constraint = NSLayoutConstraint.init(item: self.mainImage,
                                                 attribute: .height,
                                                 relatedBy: .equal,
                                                 toItem: nil,
                                                 attribute: .notAnAttribute,
                                                 multiplier: 1,
                                                 constant: width)
        self.mainImage.addConstraint(constraint)
         */

        slider.minimumTrackTintColor = UIColor(rgb: 0x6BB4FF)
        slider.maximumTrackTintColor = UIColor(rgb: 0xD7D7DB)
        slider.setThumbImage(UIImage(named: "knob"), for: .normal)
        if let url = model.articleImageURL {
            self.mainImage.downloadImageFrom(link: (url.absoluteString), contentMode: .scaleAspectFill)
        }
        self.author.text = model.author
        if let url = model.iconURL {
            do {
                try self.faviconButton.setImage(UIImage(data: Data(contentsOf: url)), for: .normal)
            } catch {
            }
        }
        self.titleLabel.text = model.title
        self.excerpt.text = model.excerpt

        if isFullArticle {
            modeButton.setTitle("Summary", for: .normal)
            modeButton.setImage(UIImage(named: "summary"), for: .normal)
        } else {
            modeButton.setTitle("Full Article", for: .normal)
            modeButton.setImage(UIImage(named: "reader_blue"), for: .normal)
        }
        self.downloadfile(url: model.url)
    }

    func downloadfile(url: String) {
        self.showHUD()

        if let audioUrl = URL(string: url) {
            // then lets create your document folder url
            let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

            // lets create your destination file url
            let destinationUrl = documentsDirectoryURL.appendingPathComponent(audioUrl.lastPathComponent)
            print(destinationUrl)

            // to check if it exists before downloading it
            if FileManager.default.fileExists(atPath: destinationUrl.path) {
                print("The file already exists at path")
                self.playDownloadedFile(url: audioUrl.absoluteString)
                self.hideHUD()
                // if the file doesn't exist
            } else {
                // you can use NSURLSession.sharedSession to download the data asynchronously
                URLSession.shared.downloadTask(with: audioUrl, completionHandler: { (location, _, error) -> Void in
                    guard let location = location, error == nil else { return }
                    do {
                        // after downloading your file you need to move it to your destination url
                        try FileManager.default.moveItem(at: location, to: destinationUrl)
                        print("File moved to documents folder")
                        self.playDownloadedFile(url: audioUrl.absoluteString)
                        self.hideHUD()
                    } catch let error as NSError {
                        print(error.localizedDescription)
                    }
                }).resume()
            }
        }
    }

    func playDownloadedFile(url: String) {
        if let audioUrl = URL(string: url) {
            // then lets create your document folder url
            let documentsDirectoryURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!

            // lets create your destination file url
            let destinationUrl = documentsDirectoryURL.appendingPathComponent(audioUrl.lastPathComponent)

            do {
                audioPlayer = try AVAudioPlayer(contentsOf: destinationUrl)

                DispatchQueue.main.async {
                    self.slider.value = 0.0
                    self.slider.maximumValue = Float(self.audioPlayer.duration)
                    self.timer = Timer.scheduledTimer(timeInterval: 0.0001,
                                                      target: self,
                                                      selector: #selector(self.updateSlider),
                                                      userInfo: nil,
                                                      repeats: true)
                }

                self.setAudioRate(self.userDefaults.float(forKey: "articlePlaybackSpeed"))
                self.play()
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }

    var playing: Bool {
        return !self.pauseButton.isSelected
    }

    @IBAction func pauseButtonTapped(_ sender: Any) {
        self.pauseButton.isSelected = !pauseButton.isSelected
        updatePausePlayButton()
    }

    @IBAction func forwardButtonAction(_ sender: Any) {
        self.skip(30)
    }

    @IBAction func backwardButtonAction(_ sender: Any) {
        self.skip(-30)
    }

    internal func skip(_ seconds: Int) {
        var time: TimeInterval = self.audioPlayer.currentTime
        time += TimeInterval(seconds)
        time = max(time, 0.0)

        if time >= self.audioPlayer.duration {
            self.audioPlayer.stop()
            self.audioPlayer.currentTime = 0.0
            DispatchQueue.main.async {
                self.pauseButton.isSelected = true
            }
        } else {
            self.audioPlayer.currentTime = time
        }
    }

    @IBAction func changeAudioTime(_ sender: Any) {
        slider.maximumValue = Float(audioPlayer.duration)
        audioPlayer.stop()
        audioPlayer.currentTime = TimeInterval(slider.value)

        if self.pauseButton.isSelected == false {
            audioPlayer.play()
        }
    }

    internal func updatePausePlayButton() {
        if self.pauseButton.isSelected {
            audioPlayer.pause()
        } else {
            audioPlayer.play()
        }
    }

    internal func play() {
        audioPlayer.enableRate = true
        audioPlayer.play()
    }

    internal func pause() {
        audioPlayer.pause()
    }

    internal func increaseVolume() {
        if audioPlayer.volume <= 0.9 {
            audioPlayer.volume += 0.1
        } else {
            audioPlayer.volume = 1
        }
    }

    internal func decreaseVolume() {
        if audioPlayer.volume >= 0.1 {
            audioPlayer.volume -= 0.1
        } else {
            audioPlayer.volume = 0
        }
    }

    internal func setVolume(_ volume: Float) -> (Float, Float)? {
        let newVolume = max(0, min(volume, 1))
        let oldVolume = audioPlayer.volume
        audioPlayer.volume = newVolume
        return (oldVolume, newVolume)
    }

    @objc internal func updateSlider() {
        slider.value = Float(audioPlayer.currentTime)

        let currentTime = Int(audioPlayer.currentTime)
        let duration = Int(audioPlayer.duration)
        let total = duration - currentTime

        let minutes = currentTime / 60
        var seconds = currentTime - minutes / 60

        let minutesLeft = total / 60
        var secondsLeft = total - minutesLeft / 60

        if minutes > 0 {
            seconds -= 60 * minutes
        }

        if minutesLeft > 0 {
            secondsLeft -= 60 * minutesLeft
        }

        startTime.text = NSString(format: "%02d:%02d", minutes, seconds) as String
        endTime.text = NSString(format: "%02d:%02d", minutesLeft, secondsLeft) as String
    }

    @IBAction func backButtonTapped(_ sender: Any) {
        self.audioPlayer.stop()
        DispatchQueue.main.async {
            if let navigationController = self.navigationController {
                var viewControllers = navigationController.viewControllers
                for (index, element) in viewControllers.enumerated() where element as? PlayerViewController != nil {
                    viewControllers.remove(at: index)
                    navigationController.setViewControllers(viewControllers, animated: true)
                    break
                }
            }
        }
    }

    @IBAction func modeButtonTapped(_ sender: Any) {
        audioPlayer.stop()

        if modeButton.currentTitle == "Summary" {
            self.playSummary()
        } else {
            self.playFullArticle()
        }
    }

    private func playSummary() {
        modeButton.setTitle("Full Article", for: .normal)
        modeButton.setImage(UIImage(named: "reader_blue"), for: .normal)

        self.showHUD()
        _ = self.scoutClient.getSummaryLink(userid: keychainService.value(for: "userID")!,
                                            url: (model.resolvedURL?.absoluteString)!,
                                            successBlock: { (scoutArticle) in
                                                if scoutArticle.url != "" {
                                                    self.downloadfile(url: scoutArticle.url)
                                                    DispatchQueue.main.async {
                                                        self.pauseButton.isSelected = false
                                                    }
                                                } else {
                                                    DispatchQueue.main.async {
                                                        self.showAlert(errorMessage: "Skim version is not available")
                                                        self.playFullArticle()
                                                    }
                                                }
                                            }, failureBlock: { (_, _, _) in
                                                self.showAlert(errorMessage: """
                                                               Unable to get your articles at this time, please check \
                                                               back later
                                                               """)
                                                self.hideHUD()
                                            })
    }

    private func playFullArticle() {
        modeButton.setTitle("Summary", for: .normal)
        modeButton.setImage(UIImage(named: "summary"), for: .normal)

        self.showHUD()
        _ = self.scoutClient.getArticleLink(userid: keychainService.value(for: "userID")!,
                                            url: (model.resolvedURL?.absoluteString)!,
                                            successBlock: { (scoutArticle) in
                                                self.downloadfile(url: scoutArticle.url)
                                                DispatchQueue.main.async {
                                                    self.pauseButton.isSelected = false
                                                }
                                            }, failureBlock: { (_, _, _) in
                                                self.showAlert(errorMessage: """
                                                               Unable to get your articles at this time, please check \
                                                               back later
                                                               """)
                                                self.hideHUD()
                                            })
    }

    @IBAction func audioRateButtonTapped(_ sender: Any) {
        if self.audioRate >= 3.0 {
            self.setAudioRate(0.5)
        } else {
            self.setAudioRate(self.audioRate + 0.25)
        }
    }

    private func setAudioRate(_ rate: Float) {
        self.audioRate = max(0.5, min(3.0, rate))
        DispatchQueue.main.async {
            self.audioRateButton.setTitle(String(format: "%.2fx", self.audioRate), for: .normal)
            self.audioPlayer.rate = self.audioRate
        }
    }

    internal func increaseSpeed() {
        self.setAudioRate(self.audioRate + 0.25)
    }

    internal func decreaseSpeed() {
        self.setAudioRate(self.audioRate - 0.25)
    }

    @IBAction func faviconButtonTapped(_ sender: Any) {
        if #available(iOS 10.0, *) {
            UIApplication.shared.open(
                model.resolvedURL!,
                options: convertToUIApplicationOpenExternalURLOptionsKeyDictionary([:]),
                completionHandler: nil)
        } else {
            UIApplication.shared.openURL(model.resolvedURL!)
        }
    }

    func addSpinner() -> UIActivityIndicatorView {
        // Adding spinner over launch screen
        let spinner = UIActivityIndicatorView.init()
        spinner.style = UIActivityIndicatorView.Style.white
        spinner.color = UIColor.black
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.hidesWhenStopped = true
        self.view.addSubview(spinner)

        loadingTextLabel.textColor = UIColor.black
        loadingTextLabel.text = "Preparing your article..."
        loadingTextLabel.font = UIFont(name: "Avenir Light", size: 14)
        loadingTextLabel.sizeToFit()
        loadingTextLabel.textAlignment = .center

        self.view.addSubview(loadingTextLabel)
        loadingTextLabel.translatesAutoresizingMaskIntoConstraints = false
        loadingTextLabel.heightAnchor.constraint(equalToConstant: 50).isActive = true
        loadingTextLabel.widthAnchor.constraint(equalToConstant: 175).isActive = true
        loadingTextLabel.centerXAnchor.constraint(equalTo: loadingTextLabel.superview!.centerXAnchor).isActive = true
        loadingTextLabel.centerYAnchor.constraint(equalTo: slider.bottomAnchor).isActive = true

        let xConstraint = NSLayoutConstraint(item: spinner,
                                             attribute: .centerX,
                                             relatedBy: .equal,
                                             toItem: loadingTextLabel,
                                             attribute: .leading,
                                             multiplier: 1,
                                             constant: 0)
        let yConstraint = NSLayoutConstraint(item: spinner,
                                             attribute: .centerY,
                                             relatedBy: .equal,
                                             toItem: loadingTextLabel,
                                             attribute: .centerY,
                                             multiplier: 1,
                                             constant: 0)

        NSLayoutConstraint.activate([xConstraint, yConstraint])

        self.loadingTextLabel.isHidden = true

        return spinner
    }

    func showHUD() {
        DispatchQueue.main.async {
            self.spinner?.startAnimating()
            self.backButton.isEnabled = false
            self.pauseButton.isEnabled = false
            self.forwardButton.isEnabled = false
            self.backwardButton.isEnabled = false
            self.loadingTextLabel.isHidden = false
            self.modeButton.isEnabled = false
            self.slider.isHidden = true
            self.startTime.isHidden = true
            self.endTime.isHidden = true
        }
    }

    func hideHUD() {
        DispatchQueue.main.async {
            self.backButton.isEnabled = true
            self.spinner?.stopAnimating()
            self.pauseButton.isEnabled = true
            self.forwardButton.isEnabled = true
            self.backwardButton.isEnabled = true
            self.modeButton.isEnabled = true
            self.loadingTextLabel.isHidden = true
            self.slider.isHidden = false
            self.startTime.isHidden = false
            self.endTime.isHidden = false
        }
    }

    private func showAlert(errorMessage: String) {
        let alert = UIAlertController(title: "", message: errorMessage, preferredStyle: UIAlertController.Style.alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            switch action.style {
		case .default:
		    print("ok")

		case .cancel:
		    print("cancel")

		case .destructive:
		    print("destructive")
            }}))
        self.present(alert, animated: true, completion: nil)
    }
}

// Helper function inserted by Swift 4.2 migrator.
private func convertToUIApplicationOpenExternalURLOptionsKeyDictionary(
    _ input: [String: Any]) -> [UIApplication.OpenExternalURLOptionsKey: Any] {
    return Dictionary(
        uniqueKeysWithValues: input.map { key, value in
            (UIApplication.OpenExternalURLOptionsKey(rawValue: key), value)
        }
    )
}
