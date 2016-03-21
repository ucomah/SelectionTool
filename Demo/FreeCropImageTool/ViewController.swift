//
//  ViewController.swift
//  FreeCropImageTool
//
//  Created by Evgeniy Melkov on 21.03.16.
//  Copyright © 2016 Evgeniy Melkov. All rights reserved.
//

import UIKit

class ViewController: RootViewController {
    

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("Selection Tool", comment: "")
        
        //Navigation bar setup
        let btnAdd: UIBarButtonItem = UIBarButtonItem.init(barButtonSystemItem: UIBarButtonSystemItem.Add, target: self, action: "doAddItemAction")
        self.titleItem?.leftBarButtonItem = btnAdd
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    //MARK: - Actions

    internal func doAddItemAction() {
        
    }

}

