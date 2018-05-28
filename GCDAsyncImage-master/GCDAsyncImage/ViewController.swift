//
//  ViewController.swift
//  GCDAsyncImage
//
//  Created by Chase Wang on 2/23/17.
//  Copyright © 2017 Make School. All rights reserved.
//

import UIKit
class ViewController: UIViewController {
    
    let numberOfCells = 20_000
    var imageWithFilter: UIImage?
    let imageURLArray = Unsplash.defaultImageURLs
    
    var photos = [PhotoRecord]()
    let pendingOperations = PendingOperations()
    @IBOutlet weak var tableView: UITableView!
    // MARK: - VC Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
//         let url = imageURLArray[indexPath.row % imageURLArray.count]
//        map all img urls to customized model
        for url in imageURLArray {
            let photoRecord = PhotoRecord(url: url)
            self.photos.append(photoRecord)
        }
        
    }
   
    func startDownload(photoRecord: PhotoRecord, indexPath: IndexPath) {
        if let downloadOperation = pendingOperations.downloadsInProgress[indexPath] {
            return
        }
        
        let downloader = ImageDownloader(photoRecord: photoRecord)
        
        downloader.completionBlock = {
            if downloader.isCancelled {
                return
            }
//            if finish download, remove inprogress value from dict
            DispatchQueue.main.async {
                self.pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
//        add operation queue
        pendingOperations.downloadsInProgress[indexPath] = downloader
        pendingOperations.downloadQueue.addOperation(downloader)
        
    }
    
    func startFilter(photoRecord: PhotoRecord, indexPath: IndexPath) {
        if let filterOperation = pendingOperations.filtrationsInProgress[indexPath] {
            return
        }
        let filter = ImageFilter(photoRecord: photoRecord)
        filter.completionBlock = {
            if filter.isCancelled {
                return
            }
            DispatchQueue.main.async {
                self.pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
                self.tableView.reloadRows(at: [indexPath], with: .fade)
            }
        }
        
        pendingOperations.filtrationsInProgress[indexPath] = filter
        pendingOperations.filtrationQueue.addOperation(filter)
    }
    
//    the main driver for download and filter tasks
    func startOperationsForPhotoRecord(photoRecord: PhotoRecord, indexPath: IndexPath) {
        switch(photoRecord.state){
        case .New:
            startDownload(photoRecord: photoRecord, indexPath: indexPath)
        case .Downloaded:
            startFilter(photoRecord: photoRecord, indexPath: indexPath)
        default:
            NSLog("do nothing")
        }
    }
    
//    handle suspend and resume operations
    func suspendAllOperations() {
        pendingOperations.downloadQueue.isSuspended = true
        pendingOperations.filtrationQueue.isSuspended = true
    }
    
    func resumeAllOperations() {
        pendingOperations.downloadQueue.isSuspended = false
        pendingOperations.filtrationQueue.isSuspended = false
    }
    
//    load img for cell
    func loadImagesForOnscreenCell() {
        if let pathsArr = tableView.indexPathsForVisibleRows {
//            combine download & filter pending operation index together
            var allPendingOperations = Set(pendingOperations.downloadsInProgress.keys)
            allPendingOperations.union(pendingOperations.filtrationsInProgress.keys)
            
//            get all non-onscreen indexpath (to be cancel)
            var toBeCancelled = allPendingOperations
            let visiblePaths = Set(pathsArr)
            toBeCancelled.subtract(visiblePaths)
            
//            get all indexpath of not yet started but visible cell
            var toBeStarted = visiblePaths
            toBeStarted.subtract(allPendingOperations)
            
            //  terminate all pending download & filter operation + remove them from pendingOperation
            for indexPath in toBeCancelled {
                if let pendingDownload = pendingOperations.downloadsInProgress[indexPath] {
                    pendingDownload.cancel()
                }
                pendingOperations.downloadsInProgress.removeValue(forKey: indexPath)
                
                if let pendingFilter = pendingOperations.filtrationsInProgress[indexPath] {
                    pendingFilter.cancel()
                }
                pendingOperations.filtrationsInProgress.removeValue(forKey: indexPath)
            }
            
//            start operation
            for indexPath in toBeStarted {
                let photoRecord = self.photos[indexPath.row]
                startOperationsForPhotoRecord(photoRecord: photoRecord, indexPath: indexPath)
            }
        }
    }
}

// MARK: - UITableViewDataSource
extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return numberOfCells
    }
    
    func scrollViewWillBeginDragging(scrollView: UIScrollView) {
        //1
        suspendAllOperations()
    }
    
    func scrollViewDidEndDragging(scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 2
        if !decelerate {
//            loadImagesForOnscreenCells()
            resumeAllOperations()
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ImageCell", for: indexPath) as! ImageTableViewCell
        
        let photoRecord = self.photos[indexPath.row]
        
        if (!tableView.isDragging && !tableView.isDecelerating) {
            self.startOperationsForPhotoRecord(photoRecord: photoRecord, indexPath: indexPath)
        }
        
//        let url = imageURLArray[indexPath.row % imageURLArray.count]
        if cell.accessoryView == nil {
            let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
            cell.accessoryView = indicator
        }
        
        let indicator = cell.accessoryView as! UIActivityIndicatorView
        cell.imageView?.image = photoRecord.image
        switch(photoRecord.state) {
        case .Filtered:
            indicator.stopAnimating()
        case .Failed:
            indicator.stopAnimating()
        case .New, .Downloaded:
            indicator.startAnimating()
            self.startOperationsForPhotoRecord(photoRecord: photoRecord, indexPath: indexPath)
        }
        
        return cell
    }
    
}
