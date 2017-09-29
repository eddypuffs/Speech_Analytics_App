//
//  SpeechTableViewCell.swift
//  Speech Analytics
//
//  Created by Abdo Salem on 4/12/17.
//  Copyright © 2017 Abdo Salem. All rights reserved.
//

import UIKit

class SpeechTableViewCell: UITableViewCell, ARPieChartDelegate, ARPieChartDataSource {
    
    @IBOutlet weak var pieChart: ARPieChart!
    @IBOutlet weak var speechName: UILabel!
    @IBOutlet weak var speechDuration: UILabel!
    @IBOutlet weak var speechDate: UILabel!
    @IBOutlet weak var speechScore: UILabel!
    
    var chartDataItems: [PieChartItem] = []

    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
        
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    /**
     *   MARK: ARPieChartDataSource
          */
    func numberOfSlicesInPieChart(_ pieChart: ARPieChart) -> Int {
        return chartDataItems.count
    }

    func pieChart(_ pieChart: ARPieChart, valueForSliceAtIndex index: Int) -> CGFloat {
        let item: PieChartItem = chartDataItems[index]
        return item.value
    }

    func pieChart(_ pieChart: ARPieChart, colorForSliceAtIndex index: Int) -> UIColor {
        let item: PieChartItem = chartDataItems[index]
        return item.color
    }

    func pieChart(_ pieChart: ARPieChart, descriptionForSliceAtIndex index: Int) -> String {
        let item: PieChartItem = chartDataItems[index]
        return item.description ?? ""
    }
    /**
     *  MARK: ARPieChartDelegate
     */
    func pieChart(_ pieChart: ARPieChart, itemSelectedAtIndex index: Int) {
    }
    
    func pieChart(_ pieChart: ARPieChart, itemDeselectedAtIndex index: Int) {
    }



}
