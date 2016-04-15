//
//  ImageSourceScreen.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 21.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

class ImageSourceViewController: UITableViewController {
    
    @IBOutlet weak var delegate: SelectionToolPopOverDelegate?
    
    private var cellReuseIdentifier: String {
        return "\(self.classForCoder)_cell"
    }
    
    override init(style: UITableViewStyle) {
        super.init(style: style)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        self.tableView.registerClass(UITableViewCell.classForCoder(), forCellReuseIdentifier: self.cellReuseIdentifier)
        self.tableView.delegate = self
        self.tableView.dataSource = self
        self.tableView.scrollEnabled = false
    }
    
    //MARK: - TableView data source
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return (UIImagePickerController.availableMediaTypesForSourceType(UIImagePickerControllerSourceType.Camera) != nil) ? 3 : 2
    }
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(cellReuseIdentifier)
        switch indexPath.row {
        case 0:
            cell?.textLabel?.text = NSLocalizedString("iCloud Drive", comment: "")
        case 1:
            cell?.textLabel?.text = NSLocalizedString("Camera Roll", comment: "")
        case 2:
            cell?.textLabel?.text = NSLocalizedString("Take a Photo", comment: "")
        default:
            break
        }
        cell?.textLabel?.textAlignment = .Center
        return cell!
    }
    
    //MARK: - TableView delegate
    
    override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 0
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 50
    }
    
    override func tableView(tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return 0.01
    }
    
    override func tableView(tableView: UITableView, viewForFooterInSection section: Int) -> UIView? {
        return nil
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        self.delegate?.tablePopOver?(self, didSelectItemAtIndex: indexPath.row)
    }
}
