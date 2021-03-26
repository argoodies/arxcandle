import Foundation
import SceneKit

class FlowerCandle: VirtualObject {

    override init() {
        super.init(modelName: "flower_candle", fileExtension: "scn", thumbImageFilename: "flower", title: "樱花蜡烛")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
