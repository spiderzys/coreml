//
//  ViewController.swift
//  ML Test
//
//  Created by Yangsheng Zou on 2018-10-24.
//  Copyright © 2018 Yangsheng Zou. All rights reserved.
//

import UIKit
import CoreML
import Vision
import VisualRecognition

struct CoreMLModel {
    var model:MLModel
    var name:String
}


struct ObservationResult {
    static let threshold:Float = 0.05
    var modelName:String
    var observations: [Observation]
    init(modelName:String, observations:[Observation]) {
        self.modelName = modelName
        self.observations = observations.filter {
            $0.score > ObservationResult.threshold
        }
    }
}

struct Observation {
    var identifier:String
    var score:Float
}

class ViewController: UIViewController,UIImagePickerControllerDelegate,UINavigationControllerDelegate,UICollectionViewDataSource,UICollectionViewDelegate {
    
    @IBOutlet weak var loadingActivityView: UIActivityIndicatorView!
    var observationsCollection:[ObservationResult] = []
    let sliceColorList:[UIColor] = [.blue,.red,.brown,.darkGray ,.purple]
    let visualRecognition = VisualRecognition(version: "2018-10-31", apiKey: "ttnToGio52YFbk07LTU05LF7J6IyqOllMhNPP3fHhCCG")
    let modelNameList = ["MobileNet","SqueezeNet"]
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return observationsCollection.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "observation", for: indexPath) as! ObservationCell
        let result = observationsCollection[indexPath.row]
        cell.modelNameLabel.text = result.modelName
        cell.pieChartView.segments = []
        cell.pieChartView.segmentLabelFont = .systemFont(ofSize: 8)
        var index = 0
        var remaining:CGFloat = 100.0
        for obsservation in result.observations {
            let color = sliceColorList[index%sliceColorList.count]
            
            let score =  CGFloat(Double(String(format: "%.1f", 100 * Float(obsservation.score)))!)
            let segment = LabelledSegment(color: color, name: obsservation.identifier, value: score)
            cell.pieChartView.segments.append(segment)
            index = index + 1
            remaining = remaining - score
        }
        var color = sliceColorList[index%sliceColorList.count]
        if color == sliceColorList.first {
            color = sliceColorList[1]
        }
        cell.pieChartView.segments.append(LabelledSegment(color: color, name: "other", value: remaining))
        
        return cell
    }
    
    
    
    @IBOutlet weak var resultCollectionView: UICollectionView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        loadingActivityView.stopAnimating()
        // Do any additional setup after loading the view, typically from a nib.
    }
    @IBOutlet weak var imageView: UIImageView!
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    
    
    
    @IBAction func takePhoto(_ sender: Any) {
        let alertontroller = UIAlertController(title: "choose the source", message: nil, preferredStyle: .actionSheet)
        let sheet1 = UIAlertAction(title: "From Photo Library", style: .default) { (action) in
            self.pickImage(source: .photoLibrary)
        }
        let sheet2 = UIAlertAction(title: "From camera", style: .default) { (action)in
            self.pickImage(source: .camera)
        }
        alertontroller.addAction(sheet1)
        alertontroller.addAction(sheet2)
        present(alertontroller, animated: true, completion: nil)
    }
    
    func pickImage(source:UIImagePickerControllerSourceType) {
        let imagePicker = UIImagePickerController()
        imagePicker.delegate = self
        imagePicker.sourceType = source
        present(imagePicker, animated: true, completion: nil)
    }
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [String : Any]) {
        
        if let image = info[UIImagePickerControllerOriginalImage] as? UIImage {
            imageView.image = image
            picker.dismiss(animated: true) {
              
            }
            self.analyzeBegin(image: image)
         
        } else{
            
            picker.dismiss(animated: true) {
                self.showWarning(message:"Something went wrong in image")
            }
        }
        
    }
    
    func analyzeBegin(image:UIImage) {
        loadingActivityView.startAnimating()
        watsonVisualRecognize(image: image)
        guard let ciImage = CIImage(image: image) else {
            showWarning(message: "cannot process the image")
            analyzeEnd()
            return
        }
        
        view.isUserInteractionEnabled = false
        observationsCollection = []
        detect(image: ciImage)
        watsonVisualRecognize(image: image)
    }
    
    func analyzeEnd() {
        view.isUserInteractionEnabled = true
        loadingActivityView.stopAnimating()
    }
   
    func watsonVisualRecognize(image:UIImage) {
        visualRecognition.classify(image: image) { (classfiedImage) in
            print(classfiedImage.images.count)
            let classes = classfiedImage.images[0].classifiers[0].classes.filter {
                $0.score != nil
            }
            let totalScore = classes.reduce(0) {
                $0 + $1.score!
            }
            let observations = classes.map {
                Observation(identifier: $0.className, score: Float($0.score!/totalScore))
            }
            DispatchQueue.main.async {
                self.observationsCollection.append(ObservationResult(modelName: "Watson", observations: observations))
                self.showAnalysisResult()
            }
            
        }
        
        
    }
    
    func showAnalysisResult(){
        
        if observationsCollection.count == modelNameList.count + 1 {
           analyzeEnd()
           resultCollectionView.reloadData()
        }
    }
    
    func detect(image:CIImage){
        
        let models:[CoreMLModel] = [CoreMLModel(model: MobileNet().model, name: "MobileNet"),CoreMLModel(model: SqueezeNet().model, name: "SqueezeNet") ]
        var requestSet:[VNCoreMLRequest] = []
        
        for model in models {
            
                guard let coreML = try? VNCoreMLModel(for: model.model) else {
                    showWarning(message: "cannot create MobileNet model")
                    return
                }
                let request = VNCoreMLRequest(model: coreML) { (request, error) in
                    guard error == nil else {
                        self.showWarning(message: "something wrong")
                        return
                    }
                    guard let result = request.results as? [VNClassificationObservation] else {
                        self.showWarning(message: "fail to process")
                        return
                    }
                   
                    
                    
                    let observations = result.map({
                        Observation(identifier: $0.identifier, score: Float($0.confidence))
                    })
                    DispatchQueue.main.async {
                        self.observationsCollection.append(ObservationResult(modelName: model.name, observations: observations))
                        self.showAnalysisResult()
                    }
                }
                requestSet.append(request)
            
            
        }
        let handler = VNImageRequestHandler(ciImage: image, options: [:])
        
        try? handler.perform(requestSet)
    }
    
    func showAlert(title:String?, message:String?){
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        present(alertController, animated: true, completion: nil)
    }
    
    func showWarning(message:String?){
        let alertController = UIAlertController(title: "Warning", message: message, preferredStyle: .alert)
        present(alertController, animated: true, completion: nil)
    }
    
    
    
    
    
}


class MLObject{
    var model:MLModel
    init(contentsOf url: URL) throws {
        self.model = try MLModel(contentsOf: url)
    }
    required convenience init() {
        let bundle = Bundle(for: SqueezeNet.self)
        let assetPath = bundle.url(forResource: "SqueezeNet", withExtension:"mlmodelc")
        try! self.init(contentsOf: assetPath!)
    }
}

class ObservationCell: UICollectionViewCell {
    
    @IBOutlet weak var pieChartView: PieChartView!
    
    @IBOutlet weak var modelNameLabel: UILabel!
}
