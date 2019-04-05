//
//  ViewController.swift
//  FlowerRecognizer
//
//  Created by Roberto Antonio Berrospe Machin on 3/27/19.
//  Copyright © 2019 Ruta Internet. All rights reserved.
//

import UIKit
import Vision
import CoreML
import Alamofire
import SwiftyJSON
import SafariServices

class ViewController: UIViewController, UIImagePickerControllerDelegate, UINavigationControllerDelegate {

    @IBOutlet weak var capturedFlowerPreview: UIImageView!
    @IBOutlet weak var lblTitle: UILabel!
    @IBOutlet weak var lblDescription: UILabel!
    @IBOutlet weak var btnReadMore: UIButton!
    var wikipediaPageID = ""
    
    lazy var sourceImageActionSheet = UIAlertController(title: "Import photo", message: "Please select source", preferredStyle: .actionSheet)
    
    let imagePicker = UIImagePickerController()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //set the sourceImageActionSheet details
        sourceImageActionSheet.addAction(UIAlertAction(title: "Camera", style: .default, handler: { (action) in
            //ImagePicker camera
            self.imagePicker.sourceType = .camera
            self.present(self.imagePicker, animated: true, completion: nil)
        }))
        sourceImageActionSheet.addAction(UIAlertAction(title: "Photo Library", style: .default, handler: { (action) in
            //ImagePicker Library
            self.imagePicker.sourceType = .photoLibrary
            self.present(self.imagePicker, animated: true, completion: nil)
        }))
        sourceImageActionSheet.addAction(UIAlertAction(title: "Canel", style: .default, handler: { (action) in
            //Do nothing
            self.sourceImageActionSheet.dismiss(animated: true, completion: nil)
        }))
        //set image picker delegate to self
        imagePicker.delegate = self
        //allow editing
        imagePicker.allowsEditing = true

    }
    
    
    @objc func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        //if original image was returned and is not nil
        if let userSelectedImage = info[UIImagePickerController.InfoKey.editedImage] as? UIImage {
            //load into preview
            capturedFlowerPreview.image = userSelectedImage
            //dismiss image picker
            imagePicker.dismiss(animated: true, completion: nil)
            //show detecting
            self.lblTitle.text = "Detecting..."
            //detect flower, async (in the background) to be able to
            ///present the preview and detecting title
            DispatchQueue.main.async() {
                self.detectFlower(image: userSelectedImage)
            }
        } else {
            print("Error importing image.")
            imagePicker.dismiss(animated: true, completion: nil)
        }
        
    }
    
    func detectFlower(image: UIImage){
        
        if let ciimage = CIImage(image: image) {
            
            
            
            //instantiate flower classifier model as coreml vision
            guard let detectorModel = try? VNCoreMLModel(for: flower_classifier().model) else {
                fatalError("Error trying to instantiate flower classifier model.")
            }
            //generate a core ml request using the detectormodel
            let detectorRequest = VNCoreMLRequest(model: detectorModel) {
                (request, error) in
                if error == nil {
                    //if there is a first detection result
                    print(request.results!)
                    if let firstDetection = request.results?.first as? VNClassificationObservation {
                        if firstDetection.confidence >= 0.5 {
                            let flowerName = firstDetection.identifier.capitalized
                            self.lblTitle.text = flowerName
                            self.lblDescription.text = "Obtaining information..."
                            let wikipediaParams: [String:String] =
                            [
                                "format": "json",
                                "action": "query",
                                "prop": "extracts",
                                "exintro": "",
                                "explaintext": "",
                                "titles": flowerName,
                                "indexpageids": "",
                                "redirects": "1"
                            ]
                            let wikiQueryURL = "https://en.wikipedia.org/w/api.php"
                            
                            //Use Alamofire to request the API server
                            Alamofire.request(wikiQueryURL, method: .get, parameters: wikipediaParams).responseJSON {
                                response in
                                //convert to JSON array
                                let resultJSON = JSON(response.result.value!)
                                print(resultJSON)
                                //if success and there's at least one page id
                                if response.result.isSuccess && resultJSON["query"]["pageids"].count > 0 && resultJSON["query"]["pageids"][0].intValue != -1 {
                                    //show description
                                    self.wikipediaPageID = resultJSON["query"]["pageids"][0].stringValue
                                    self.lblDescription.text = resultJSON["query"]["pages"][self.wikipediaPageID]["extract"].stringValue
                                    self.btnReadMore.isHidden=false
                                } else {
                                    print("Error trying to get wikipedia data")
                                    self.lblDescription.text = "No specific flower information found."
                                    self.btnReadMore.isHidden=true
                                }
                            }
                            
                            
                            
                        } else {
                            self.lblTitle.text = "Unable to recognize."
                            self.lblDescription.text = "Please try again."
                            self.btnReadMore.isHidden=true
                        }
                    }
                } else {
                    print("Error requesting Vision.")
                }
            }
            //create a vision image request handler using the passed image
            let detectorHandler = VNImageRequestHandler(ciImage: ciimage)
            
            //and perform the detect on the handler, passing the request
            do {
                try detectorHandler.perform([detectorRequest])
            } catch {
                print("Error trying to perform CoreML request. \(error)")
            }
            
        }
    }
    
    @IBAction func cameraButtonTapped(_ sender: Any) {
        //present options
        present(sourceImageActionSheet, animated: true, completion: nil)
    }
    
    @IBAction func readMoreTapped(_ sender: Any) {
        //send user to wikipedia page, opening safari in current app
        if let url = URL(string: "https://en.wikipedia.org/wiki?curid="+wikipediaPageID) {
            let svc = SFSafariViewController(url: url)
            present(svc, animated: true) {
                //finished open url
            }
        }
            
    }
    
}

