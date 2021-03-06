//
//  GlucoseMetersViewController.swift
//  CCBluetooth
//
//  Created by Kevin Tallevi on 7/28/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit
import CCBluetooth
import CCGlucose
import CoreBluetooth

class GlucoseMetersViewController: UITableViewController, GlucoseMeterDiscoveryProtocol {
    let cellIdentifier = "GlucoseMetersCellIdentifier"
    var discoveredGlucoseMeters: Array<CBPeripheral> = Array<CBPeripheral>()
    var previouslySelectedGlucoseMeters: Array<CBPeripheral> = Array<CBPeripheral>()
    var peripheral : CBPeripheral!
    let rc = UIRefreshControl()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("GlucoseMetersViewController#viewDidLoad")
        
        refreshControl = UIRefreshControl()
        refreshControl?.attributedTitle = NSAttributedString(string: "Pull to refresh")
        refreshControl?.addTarget(self, action: #selector(onRefresh), for: .valueChanged)
        
        Glucose.sharedInstance().glucoseMeterDiscoveryDelegate = self
    }
    
    @objc func onRefresh() {
        refreshControl?.endRefreshing()
        discoveredGlucoseMeters.removeAll()

        self.refreshTable()
        
        Glucose.sharedInstance().glucoseMeterDiscoveryDelegate = self
        Glucose.sharedInstance().scanForGlucoseMeters()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        self.refreshTable()
    }
    
    override func viewWillAppear(_ animated: Bool) {
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let gmvc =  segue.destination as! GlucoseMeterViewController
        gmvc.selectedMeter = self.peripheral
    }
    
    func glucoseMeterDiscovered(glucoseMeter:CBPeripheral) {
        print("GlucoseMeterViewControllers#glucoseMeterDiscovered")
        discoveredGlucoseMeters.append(glucoseMeter)
        print("glucose meter: \(String(describing: glucoseMeter.name))")
        
        self.refreshTable()
    }
    
    // MARK: Table data source methods
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if (section == 0) {
            return discoveredGlucoseMeters.count
        } else {
            return previouslySelectedGlucoseMeters.count
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: cellIdentifier, for: indexPath as IndexPath) as UITableViewCell
        
        if (indexPath.section == 0) {
            let peripheral = Array(self.discoveredGlucoseMeters)[indexPath.row]
            cell.textLabel!.text = peripheral.name
            cell.detailTextLabel!.text = peripheral.identifier.uuidString
        } else {
            let peripheral = Array(self.previouslySelectedGlucoseMeters)[indexPath.row]
            cell.textLabel!.text = peripheral.name
            cell.detailTextLabel!.text = peripheral.identifier.uuidString
        }
        
        return cell
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 75
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if (section == 0) {
            return "Discovered Glucose Meters"
        } else {
            return "Previously Connected Glucose Meters"
        }
    }
    
    //MARK: table delegate methods
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if (indexPath.section == 0) {
            let glucoseMeter = Array(discoveredGlucoseMeters)[indexPath.row]
            self.peripheral = glucoseMeter
            self.addPreviouslySelectedGlucoseMeter(self.peripheral)
            self.didSelectDiscoveredGlucoseMeter(Array(self.discoveredGlucoseMeters)[indexPath.row])
        } else {
            let glucoseMeter = Array(previouslySelectedGlucoseMeters)[indexPath.row]
            self.peripheral = glucoseMeter
            self.didSelectPreviouslySelectedGlucoseMeter(Array(self.previouslySelectedGlucoseMeters)[indexPath.row])
        }
        
        tableView.deselectRow(at: indexPath, animated: true)
        performSegue(withIdentifier: "segueToGlucoseMeter", sender: self)
    }
    
    func didSelectDiscoveredGlucoseMeter(_ peripheral:CBPeripheral) {
        print("ViewController#didSelectDiscoveredPeripheral \(String(describing: peripheral.name))")
        Bluetooth.sharedInstance().connectPeripheral(peripheral)
    }
    
    func didSelectPreviouslySelectedGlucoseMeter(_ peripheral:CBPeripheral) {
        print("ViewController#didSelectPreviouslyConnectedPeripheral \(String(describing: peripheral.name))")
        Bluetooth.sharedInstance().reconnectPeripheral(peripheral.identifier.uuidString)
    }
    
    func addPreviouslySelectedGlucoseMeter(_ cbPeripheral:CBPeripheral) {
        var peripheralAlreadyExists: Bool = false
        
        for aPeripheral in self.previouslySelectedGlucoseMeters {
            if (aPeripheral.identifier.uuidString == cbPeripheral.identifier.uuidString) {
                peripheralAlreadyExists = true
            }
        }
        
        if (!peripheralAlreadyExists) {
            self.previouslySelectedGlucoseMeters.append(cbPeripheral)
        }
    }

    func refreshTable() {
        DispatchQueue.main.async(execute: {
            self.tableView.reloadData()
        })
    }

}
