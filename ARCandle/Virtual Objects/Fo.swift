import Foundation

class Fo: VirtualObject {

    override init() {
        super.init(modelName: "fo", fileExtension: "dae", thumbImageFilename: "flower", title: "佛像")
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
