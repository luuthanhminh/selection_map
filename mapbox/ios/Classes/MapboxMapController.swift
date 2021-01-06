import Flutter
import UIKit
import Mapbox
import MapboxAnnotationExtension

class MapboxMapController: NSObject, FlutterPlatformView, MGLMapViewDelegate, MapboxMapOptionsSink, MGLAnnotationControllerDelegate {
    
    private var registrar: FlutterPluginRegistrar
    private var channel: FlutterMethodChannel?
    
    private var mapView: MGLMapView
    private var isMapReady = false
    private var mapReadyResult: FlutterResult?
    
    private var initialTilt: CGFloat?
    private var cameraTargetBounds: MGLCoordinateBounds?
    private var trackCameraPosition = false
    private var myLocationEnabled = false
    
    private var symbolAnnotationController: MGLSymbolAnnotationController?
    private var circleAnnotationController: MGLCircleAnnotationController?
    private var lineAnnotationController: MGLLineAnnotationController?
    private var fillAnnotationController: MGLPolygonAnnotationController?
    
    func view() -> UIView {
        return mapView
    }
    
    init(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?, registrar: FlutterPluginRegistrar) {
        if let args = args as? [String: Any] {
            if let token = args["accessToken"] as? NSString{
                MGLAccountManager.accessToken = token
            }
        }
        mapView = MGLMapView(frame: frame)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.registrar = registrar
        
        super.init()
        
        channel = FlutterMethodChannel(name: "plugins.flutter.io/mapbox_maps_\(viewId)", binaryMessenger: registrar.messenger())
        channel!.setMethodCallHandler{ [weak self] in self?.onMethodCall(methodCall: $0, result: $1) }
        print("hello123")
        mapView.delegate = self
        
        //        let tappedMap = UITapGestureRecognizer(target: self, action: #selector(tappedMap(sender:)))
        //        for recognizer in mapView.gestureRecognizers! where recognizer is UITapGestureRecognizer {
        //            tappedMap.require(toFail: recognizer)
        //        }
        //        mapView.addGestureRecognizer(tappedMap)
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleMapTap(sender:)))
        for recognizer in mapView.gestureRecognizers! where recognizer is UITapGestureRecognizer {
            singleTap.require(toFail: recognizer)
        }
        mapView.addGestureRecognizer(singleTap)
        
        
        
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleMapLongPress(sender:)))
        for recognizer in mapView.gestureRecognizers! where recognizer is UILongPressGestureRecognizer {
            longPress.require(toFail: recognizer)
        }
        mapView.addGestureRecognizer(longPress)
        
        if let args = args as? [String: Any] {
            Convert.interpretMapboxMapOptions(options: args["options"], delegate: self)
            if let initialCameraPosition = args["initialCameraPosition"] as? [String: Any],
               let camera = MGLMapCamera.fromDict(initialCameraPosition, mapView: mapView),
               let zoom = initialCameraPosition["zoom"] as? Double {
                mapView.setCenter(camera.centerCoordinate, zoomLevel: zoom, direction: camera.heading, animated: false)
                initialTilt = camera.pitch
            }
        }
    }
    
    func onMethodCall(methodCall: FlutterMethodCall, result: @escaping FlutterResult) {
        switch(methodCall.method) {
        case "map#waitForMap":
            if isMapReady {
                result(nil)
            } else {
                mapReadyResult = result
            }
        case "map#update":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            Convert.interpretMapboxMapOptions(options: arguments["options"], delegate: self)
            if let camera = getCamera() {
                result(camera.toDict(mapView: mapView))
            } else {
                result(nil)
            }
        case "map#invalidateAmbientCache":
            MGLOfflineStorage.shared.invalidateAmbientCache{
                (error) in
                if let error = error {
                    result(error)
                } else{
                    result(nil)
                }
            }
        case "map#updateMyLocationTrackingMode":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let myLocationTrackingMode = arguments["mode"] as? UInt, let trackingMode = MGLUserTrackingMode(rawValue: myLocationTrackingMode) {
                setMyLocationTrackingMode(myLocationTrackingMode: trackingMode)
            }
            result(nil)
        case "map#matchMapLanguageWithDeviceDefault":
            if let style = mapView.style {
                style.localizeLabels(into: nil)
            }
            result(nil)
        case "map#updateContentInsets":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            
            if let bounds = arguments["bounds"] as? [String: Any],
               let top = bounds["top"] as? CGFloat,
               let left = bounds["left"]  as? CGFloat,
               let bottom = bounds["bottom"] as? CGFloat,
               let right = bounds["right"] as? CGFloat,
               let animated = arguments["animated"] as? Bool {
                mapView.setContentInset(UIEdgeInsets(top: top, left: left, bottom: bottom, right: right), animated: animated) {
                    result(nil)
                }
            } else {
                result(nil)
            }
        case "map#setMapLanguage":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            if let localIdentifier = arguments["language"] as? String, let style = mapView.style {
                let locale = Locale(identifier: localIdentifier)
                style.localizeLabels(into: locale)
            }
            result(nil)
        case "map#queryRenderedFeatures":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            let layerIds = arguments["layerIds"] as? Set<String>
            var filterExpression: NSPredicate?
            if let filter = arguments["filter"] as? [Any] {
                filterExpression = NSPredicate(mglJSONObject: filter)
            }
            var reply = [String: NSObject]()
            var features:[MGLFeature] = []
            if let x = arguments["x"] as? Double, let y = arguments["y"] as? Double {
                features = mapView.visibleFeatures(at: CGPoint(x: x, y: y), styleLayerIdentifiers: layerIds, predicate: filterExpression)
            }
            if  let top = arguments["top"] as? Double,
                let bottom = arguments["bottom"] as? Double,
                let left = arguments["left"] as? Double,
                let right = arguments["right"] as? Double {
                features = mapView.visibleFeatures(in: CGRect(x: left, y: top, width: right, height: bottom), styleLayerIdentifiers: layerIds, predicate: filterExpression)
            }
            var featuresJson = [String]()
            for feature in features {
                let dictionary = feature.geoJSONDictionary()
                if  let theJSONData = try? JSONSerialization.data(withJSONObject: dictionary, options: []),
                    let theJSONText = String(data: theJSONData, encoding: .ascii) {
                    featuresJson.append(theJSONText)
                }
            }
            reply["features"] = featuresJson as NSObject
            result(reply)
        case "map#setTelemetryEnabled":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            let telemetryEnabled = arguments["enabled"] as? Bool
            UserDefaults.standard.set(telemetryEnabled, forKey: "MGLMapboxMetricsEnabled")
            result(nil)
        case "map#getTelemetryEnabled":
            let telemetryEnabled = UserDefaults.standard.bool(forKey: "MGLMapboxMetricsEnabled")
            result(telemetryEnabled)
        case "map#getVisibleRegion":
            var reply = [String: NSObject]()
            let visibleRegion = mapView.visibleCoordinateBounds
            reply["sw"] = [visibleRegion.sw.latitude, visibleRegion.sw.longitude] as NSObject
            reply["ne"] = [visibleRegion.ne.latitude, visibleRegion.ne.longitude] as NSObject
            result(reply)
        case "map#toScreenLocation":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let latitude = arguments["latitude"] as? Double else { return }
            guard let longitude = arguments["longitude"] as? Double else { return }
            let latlng = CLLocationCoordinate2DMake(latitude, longitude)
            let returnVal = mapView.convert(latlng, toPointTo: mapView)
            var reply = [String: NSObject]()
            reply["x"] = returnVal.x as NSObject
            reply["y"] = returnVal.y as NSObject
            result(reply)
        case "map#getMetersPerPixelAtLatitude":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            var reply = [String: NSObject]()
            guard let latitude = arguments["latitude"] as? Double else { return }
            let returnVal = mapView.metersPerPoint(atLatitude:latitude)
            reply["metersperpixel"] = returnVal as NSObject
            result(reply)
        case "map#toLatLng":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let x = arguments["x"] as? Double else { return }
            guard let y = arguments["y"] as? Double else { return }
            let screenPoint: CGPoint = CGPoint(x: y, y:y)
            let coordinates: CLLocationCoordinate2D = mapView.convert(screenPoint, toCoordinateFrom: mapView)
            var reply = [String: NSObject]()
            reply["latitude"] = coordinates.latitude as NSObject
            reply["longitude"] = coordinates.longitude as NSObject
            result(reply)
        case "camera#move":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                mapView.setCamera(camera, animated: false)
            }
            result(nil)
        case "camera#animate":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let cameraUpdate = arguments["cameraUpdate"] as? [Any] else { return }
            if let camera = Convert.parseCameraUpdate(cameraUpdate: cameraUpdate, mapView: mapView) {
                if let duration = arguments["duration"] as? TimeInterval {
                    mapView.setCamera(camera, withDuration: TimeInterval(duration / 1000),
                                      animationTimingFunction: CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut))
                    result(nil)
                }
                mapView.setCamera(camera, animated: true)
            }
            result(nil)
        case "symbols#addAll":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            
            if let options = arguments["options"] as? [[String: Any]] {
                var symbols: [MGLSymbolStyleAnnotation] = [];
                for o in options {
                    if let symbol = getSymbolForOptions(options: o)  {
                        symbols.append(symbol)
                    }
                }
                if !symbols.isEmpty {
                    symbolAnnotationController.addStyleAnnotations(symbols)
                }
                
                result(symbols.map { $0.identifier })
            } else {
                result(nil)
            }
        case "symbol#update":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let symbolId = arguments["symbol"] as? String else { return }
            
            for symbol in symbolAnnotationController.styleAnnotations(){
                if symbol.identifier == symbolId {
                    Convert.interpretSymbolOptions(options: arguments["options"], delegate: symbol as! MGLSymbolStyleAnnotation)
                    // Load (updated) icon image from asset if an icon name is supplied.
                    if let options = arguments["options"] as? [String: Any],
                       let iconImage = options["iconImage"] as? String {
                        addIconImageToMap(iconImageName: iconImage)
                    }
                    symbolAnnotationController.updateStyleAnnotation(symbol)
                    break;
                }
            }
            result(nil)
        case "symbols#removeAll":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let symbolIds = arguments["symbols"] as? [String] else { return }
            var symbols: [MGLSymbolStyleAnnotation] = [];
            
            for symbol in symbolAnnotationController.styleAnnotations(){
                if symbolIds.contains(symbol.identifier) {
                    symbols.append(symbol as! MGLSymbolStyleAnnotation)
                }
            }
            symbolAnnotationController.removeStyleAnnotations(symbols)
            result(nil)
        case "symbol#getGeometry":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let symbolId = arguments["symbol"] as? String else { return }
            
            var reply: [String:Double]? = nil
            for symbol in symbolAnnotationController.styleAnnotations(){
                if symbol.identifier == symbolId {
                    if let geometry = symbol.geoJSONDictionary["geometry"] as? [String: Any],
                       let coordinates = geometry["coordinates"] as? [Double] {
                        reply = ["latitude": coordinates[1], "longitude": coordinates[0]]
                    }
                    break;
                }
            }
            result(reply)
        case "symbolManager#iconAllowOverlap":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let iconAllowOverlap = arguments["iconAllowOverlap"] as? Bool else { return }
            
            symbolAnnotationController.iconAllowsOverlap = iconAllowOverlap
            result(nil)
        case "symbolManager#iconIgnorePlacement":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let iconIgnorePlacement = arguments["iconIgnorePlacement"] as? Bool else { return }
            
            symbolAnnotationController.iconIgnoresPlacement = iconIgnorePlacement
            result(nil)
        case "symbolManager#textAllowOverlap":
            guard let symbolAnnotationController = symbolAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let textAllowOverlap = arguments["textAllowOverlap"] as? Bool else { return }
            
            symbolAnnotationController.textAllowsOverlap = textAllowOverlap
            result(nil)
        case "symbolManager#textIgnorePlacement":
            result(FlutterMethodNotImplemented)
        case "map#drawPolygon":
            guard let arguments = methodCall.arguments as? [String: AnyObject] else { return }
            //            let jsonData =  convertToData(dic: arguments)
            guard let geoJson = arguments["geoJson"] as? [String: AnyObject] else {
                return
            }
            DispatchQueue.main.async {
                self.drawPolyline(mapView: self.mapView, geoJson: geoJson)
            }
            
        case "circle#add":
            guard let circleAnnotationController = circleAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            // Parse geometry
            if let options = arguments["options"] as? [String: Any],
               let geometry = options["geometry"] as? [Double] {
                // Convert geometry to coordinate and create circle.
                let coordinate = CLLocationCoordinate2DMake(geometry[0], geometry[1])
                let circle = MGLCircleStyleAnnotation(center: coordinate)
                Convert.interpretCircleOptions(options: arguments["options"], delegate: circle)
                circleAnnotationController.addStyleAnnotation(circle)
                result(circle.identifier)
            } else {
                result(nil)
            }
        case "circle#update":
            guard let circleAnnotationController = circleAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let circleId = arguments["circle"] as? String else { return }
            
            for circle in circleAnnotationController.styleAnnotations() {
                if circle.identifier == circleId {
                    Convert.interpretCircleOptions(options: arguments["options"], delegate: circle as! MGLCircleStyleAnnotation)
                    circleAnnotationController.updateStyleAnnotation(circle)
                    break;
                }
            }
            result(nil)
        case "circle#remove":
            guard let circleAnnotationController = circleAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let circleId = arguments["circle"] as? String else { return }
            
            for circle in circleAnnotationController.styleAnnotations() {
                if circle.identifier == circleId {
                    circleAnnotationController.removeStyleAnnotation(circle)
                    break;
                }
            }
            result(nil)
        case "line#add":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            // Parse geometry
            if let options = arguments["options"] as? [String: Any],
               let geometry = options["geometry"] as? [[Double]] {
                // Convert geometry to coordinate and create a line.
                var lineCoordinates: [CLLocationCoordinate2D] = []
                for coordinate in geometry {
                    lineCoordinates.append(CLLocationCoordinate2DMake(coordinate[0], coordinate[1]))
                }
                let line = MGLLineStyleAnnotation(coordinates: lineCoordinates, count: UInt(lineCoordinates.count))
                Convert.interpretLineOptions(options: arguments["options"], delegate: line)
                lineAnnotationController.addStyleAnnotation(line)
                result(line.identifier)
            } else {
                result(nil)
            }
        case "line#update":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let lineId = arguments["line"] as? String else { return }
            
            for line in lineAnnotationController.styleAnnotations() {
                if line.identifier == lineId {
                    Convert.interpretLineOptions(options: arguments["options"], delegate: line as! MGLLineStyleAnnotation)
                    lineAnnotationController.updateStyleAnnotation(line)
                    break;
                }
            }
            result(nil)
        case "line#remove":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let lineId = arguments["line"] as? String else { return }
            
            for line in lineAnnotationController.styleAnnotations() {
                if line.identifier == lineId {
                    lineAnnotationController.removeStyleAnnotation(line)
                    break;
                }
            }
            result(nil)
        case "line#getGeometry":
            guard let lineAnnotationController = lineAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let lineId = arguments["line"] as? String else { return }
            
            var reply: [Any]? = nil
            for line in lineAnnotationController.styleAnnotations() {
                if line.identifier == lineId {
                    if let geometry = line.geoJSONDictionary["geometry"] as? [String: Any],
                       let coordinates = geometry["coordinates"] as? [[Double]] {
                        reply = coordinates.map { [ "latitude": $0[1], "longitude": $0[0] ] }
                    }
                    break;
                }
            }
            result(reply)
        case "fill#add":
            guard let fillAnnotationController = fillAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            // Parse geometry
            var identifier: String? = nil
            if let options = arguments["options"] as? [String: Any],
               let geometry = options["geometry"] as? [[[Double]]] {
                guard geometry.count > 0 else { break }
                // Convert geometry to coordinate and interior polygonc.
                var fillCoordinates: [CLLocationCoordinate2D] = []
                for coordinate in geometry[0] {
                    fillCoordinates.append(CLLocationCoordinate2DMake(coordinate[0], coordinate[1]))
                }
                let polygons = Convert.toPolygons(geometry: geometry.tail)
                let fill = MGLPolygonStyleAnnotation(coordinates: fillCoordinates, count: UInt(fillCoordinates.count), interiorPolygons: polygons)
                Convert.interpretFillOptions(options: arguments["options"], delegate: fill)
                fillAnnotationController.addStyleAnnotation(fill)
                identifier = fill.identifier
            }
            result(identifier)
        case "fill#update":
            guard let fillAnnotationController = fillAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let fillId = arguments["fill"] as? String else { return }
            
            for fill in fillAnnotationController.styleAnnotations() {
                if fill.identifier == fillId {
                    Convert.interpretFillOptions(options: arguments["options"], delegate: fill as! MGLPolygonStyleAnnotation)
                    fillAnnotationController.updateStyleAnnotation(fill)
                    break;
                }
            }
            result(nil)
        case "fill#remove":
            guard let fillAnnotationController = fillAnnotationController else { return }
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let fillId = arguments["fill"] as? String else { return }
            
            for fill in fillAnnotationController.styleAnnotations() {
                if fill.identifier == fillId {
                    fillAnnotationController.removeStyleAnnotation(fill)
                    break;
                }
            }
            result(nil)
        case "style#addImage":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let name = arguments["name"] as? String else { return }
            //guard let length = arguments["length"] as? NSNumber else { return }
            guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else { return }
            guard let sdf = arguments["sdf"] as? Bool else { return }
            guard let data = bytes.data as? Data else{ return }
            guard let image = UIImage(data: data) else { return }
            if (sdf) {
                self.mapView.style?.setImage(image.withRenderingMode(.alwaysTemplate), forName: name)
            } else {
                self.mapView.style?.setImage(image, forName: name)
            }
            result(nil)
        case "style#addImageSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let name = arguments["name"] as? String else { return }
            guard let bytes = arguments["bytes"] as? FlutterStandardTypedData else { return }
            guard let data = bytes.data as? Data else { return }
            guard let image = UIImage(data: data) else { return }
            
            guard let coordinates = arguments["coordinates"] as? [[Double]] else { return };
            let quad = MGLCoordinateQuad(
                topLeft: CLLocationCoordinate2D(latitude: coordinates[0][0], longitude: coordinates[0][1]),
                bottomLeft: CLLocationCoordinate2D(latitude: coordinates[3][0], longitude: coordinates[3][1]),
                bottomRight: CLLocationCoordinate2D(latitude: coordinates[2][0], longitude: coordinates[2][1]),
                topRight: CLLocationCoordinate2D(latitude: coordinates[1][0], longitude: coordinates[1][1])
            )
            
            let source = MGLImageSource(identifier: name, coordinateQuad: quad, image: image)
            self.mapView.style?.addSource(source)
            
            result(nil)
        case "style#removeImageSource":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let name = arguments["name"] as? String else { return }
            guard let source = self.mapView.style?.source(withIdentifier: name) else { return }
            self.mapView.style?.removeSource(source)
            result(nil)
        case "style#addLayer":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let name = arguments["name"] as? String else { return }
            guard let sourceId = arguments["sourceId"] as? String else { return }
            
            guard let source = self.mapView.style?.source(withIdentifier: sourceId) else { return }
            let layer = MGLRasterStyleLayer(identifier: name, source: source)
            self.mapView.style?.addLayer(layer)
            result(nil)
        case "style#removeLayer":
            guard let arguments = methodCall.arguments as? [String: Any] else { return }
            guard let name = arguments["name"] as? String else { return }
            guard let layer = self.mapView.style?.layer(withIdentifier: name) else { return }
            self.mapView.style?.removeLayer(layer)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func getSymbolForOptions(options: [String: Any]) -> MGLSymbolStyleAnnotation? {
        // Parse geometry
        if let geometry = options["geometry"] as? [Double] {
            // Convert geometry to coordinate and create symbol.
            let coordinate = CLLocationCoordinate2DMake(geometry[0], geometry[1])
            let symbol = MGLSymbolStyleAnnotation(coordinate: coordinate)
            Convert.interpretSymbolOptions(options: options, delegate: symbol)
            // Load icon image from asset if an icon name is supplied.
            if let iconImage = options["iconImage"] as? String {
                addIconImageToMap(iconImageName: iconImage)
            }
            return symbol
        }
        return nil
    }
    
    private func addIconImageToMap(iconImageName: String) {
        // Check if the image has already been added to the map.
        if self.mapView.style?.image(forName: iconImageName) == nil {
            // Build up the full path of the asset.
            // First find the last '/' ans split the image name in the asset directory and the image file name.
            if let range = iconImageName.range(of: "/", options: [.backwards]) {
                let directory = String(iconImageName[..<range.lowerBound])
                let assetPath = registrar.lookupKey(forAsset: "\(directory)/")
                let fileName = String(iconImageName[range.upperBound...])
                // If we can load the image from file then add it to the map.
                if let imageFromAsset = UIImage.loadFromFile(imagePath: assetPath, imageName: fileName) {
                    self.mapView.style?.setImage(imageFromAsset, forName: iconImageName)
                }
            }
        }
    }
    
    private func updateMyLocationEnabled() {
        mapView.showsUserLocation = self.myLocationEnabled
    }
    
    private func getCamera() -> MGLMapCamera? {
        return trackCameraPosition ? mapView.camera : nil
        
    }
    
    /*
     *  UITapGestureRecognizer
     *  On tap invoke the map#onMapClick callback.
     */
    @objc @IBAction func handleMapTap(sender: UITapGestureRecognizer) {
        //        // Get the CGPoint where the user tapped.
        //        let point = sender.location(in: mapView)
        //        let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
        //        channel?.invokeMethod("map#onMapClick", arguments: [
        //                      "x": point.x,
        //                      "y": point.y,
        //                      "lng": coordinate.longitude,
        //                      "lat": coordinate.latitude,
        //                  ])
        // Get the CGPoint where the user tapped.
        let spot = sender.location(in: mapView)
        
        // Access the features at that point within the state layer.
        let features = mapView.visibleFeatures(at: spot, styleLayerIdentifiers: Set([layerIdentifier]))
        
        // Get the name of the selected state.
        if let feature = features.first, let state = feature.attribute(forKey: "name") as? String {
            changeOpacity(name: state)
        } else {
            changeOpacity(name: "")
        }
    }
    
    /*
     *  UILongPressGestureRecognizer
     *  After a long press invoke the map#onMapLongClick callback.
     */
    @objc @IBAction func handleMapLongPress(sender: UILongPressGestureRecognizer) {
        //Fire when the long press starts
        if (sender.state == .began) {
            // Get the CGPoint where the user tapped.
            let point = sender.location(in: mapView)
            let coordinate = mapView.convert(point, toCoordinateFrom: mapView)
            channel?.invokeMethod("map#onMapLongClick", arguments: [
                "x": point.x,
                "y": point.y,
                "lng": coordinate.longitude,
                "lat": coordinate.latitude,
            ])
        }
        
    }
    
    
    
    /*
     *  MGLAnnotationControllerDelegate
     */
    func annotationController(_ annotationController: MGLAnnotationController, didSelect styleAnnotation: MGLStyleAnnotation) {
        annotationController.deselectStyleAnnotation(styleAnnotation)
        guard let channel = channel else {
            return
        }
        
        if let symbol = styleAnnotation as? MGLSymbolStyleAnnotation {
            channel.invokeMethod("symbol#onTap", arguments: ["symbol" : "\(symbol.identifier)"])
        } else if let circle = styleAnnotation as? MGLCircleStyleAnnotation {
            channel.invokeMethod("circle#onTap", arguments: ["circle" : "\(circle.identifier)"])
        } else if let line = styleAnnotation as? MGLLineStyleAnnotation {
            channel.invokeMethod("line#onTap", arguments: ["line" : "\(line.identifier)"])
        } else if let fill = styleAnnotation as? MGLPolygonStyleAnnotation {
            channel.invokeMethod("fill#onTap", arguments: ["fill" : "\(fill.identifier)"])
        }
    }
    
    // This is required in order to hide the default Maps SDK pin
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        if annotation is MGLUserLocation {
            return nil
        }
        return MGLAnnotationView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
    }
    
    /*
     *  MGLMapViewDelegate
     */
    func mapView(_ mapView: MGLMapView, didFinishLoading style: MGLStyle) {
        isMapReady = true
        updateMyLocationEnabled()
        
        if let initialTilt = initialTilt {
            let camera = mapView.camera
            camera.pitch = initialTilt
            mapView.setCamera(camera, animated: false)
        }
        
        lineAnnotationController = MGLLineAnnotationController(mapView: self.mapView)
        lineAnnotationController!.annotationsInteractionEnabled = true
        lineAnnotationController?.delegate = self
        
        symbolAnnotationController = MGLSymbolAnnotationController(mapView: self.mapView)
        symbolAnnotationController!.annotationsInteractionEnabled = true
        symbolAnnotationController?.delegate = self
        
        circleAnnotationController = MGLCircleAnnotationController(mapView: self.mapView)
        circleAnnotationController!.annotationsInteractionEnabled = true
        circleAnnotationController?.delegate = self
        
        fillAnnotationController = MGLPolygonAnnotationController(mapView: self.mapView)
        fillAnnotationController!.annotationsInteractionEnabled = true
        fillAnnotationController?.delegate = self
        
        
        mapReadyResult?(nil)
        if let channel = channel {
            channel.invokeMethod("map#onStyleLoaded", arguments: nil)
        }
    }
    
    
    func mapView(_ mapView: MGLMapView, shouldChangeFrom oldCamera: MGLMapCamera, to newCamera: MGLMapCamera) -> Bool {
        guard let bbox = cameraTargetBounds else { return true }
        
        // Get the current camera to restore it after.
        let currentCamera = mapView.camera
        
        // From the new camera obtain the center to test if it’s inside the boundaries.
        let newCameraCenter = newCamera.centerCoordinate
        
        // Set the map’s visible bounds to newCamera.
        mapView.camera = newCamera
        let newVisibleCoordinates = mapView.visibleCoordinateBounds
        
        // Revert the camera.
        mapView.camera = currentCamera
        
        // Test if the newCameraCenter and newVisibleCoordinates are inside bbox.
        let inside = MGLCoordinateInCoordinateBounds(newCameraCenter, bbox)
        let intersects = MGLCoordinateInCoordinateBounds(newVisibleCoordinates.ne, bbox) && MGLCoordinateInCoordinateBounds(newVisibleCoordinates.sw, bbox)
        
        return inside && intersects
    }
    
    func mapView(_ mapView: MGLMapView, imageFor annotation: MGLAnnotation) -> MGLAnnotationImage? {
        // Only for Symbols images should loaded.
        guard let symbol = annotation as? Symbol,
              let iconImageFullPath = symbol.iconImage else {
            return nil
        }
        // Reuse existing annotations for better performance.
        var annotationImage = mapView.dequeueReusableAnnotationImage(withIdentifier: iconImageFullPath)
        if annotationImage == nil {
            // Initialize the annotation image (from predefined assets symbol folder).
            if let range = iconImageFullPath.range(of: "/", options: [.backwards]) {
                let directory = String(iconImageFullPath[..<range.lowerBound])
                let assetPath = registrar.lookupKey(forAsset: "\(directory)/")
                let iconImageName = String(iconImageFullPath[range.upperBound...])
                let image = UIImage.loadFromFile(imagePath: assetPath, imageName: iconImageName)
                if let image = image {
                    annotationImage = MGLAnnotationImage(image: image, reuseIdentifier: iconImageFullPath)
                }
            }
        }
        return annotationImage
    }
    
    // On tap invoke the symbol#onTap callback.
    func mapView(_ mapView: MGLMapView, didSelect annotation: MGLAnnotation) {
        
        if let symbol = annotation as? Symbol {
            channel?.invokeMethod("symbol#onTap", arguments: ["symbol" : "\(symbol.id)"])
        }
    }
    
    func convertLatlg(geoJson: [String: AnyObject], mapView: MGLMapView?) {
        guard let featuresJson = geoJson["features"] as? [[String: AnyObject]] else {return}
        
        let geoJson:[[String: AnyObject]] = featuresJson.filter({
            $0["properties"]?["STATE"] as! String == "06"
            
        })
        var coordinates: [CLLocationCoordinate2D] = []
        geoJson.forEach { e in
            var coordinatess: [CLLocationCoordinate2D] = []
            var geometires: [AnyObject]
            if (e["geometry"]?["type"] as! String == "MultiPolygon") {
                let aa:[[[ AnyObject]]] = e["geometry"]?["coordinates"] as! [[[AnyObject]]]
                geometires = (aa[0][0] as AnyObject) as! [AnyObject]
            } else {
                let aa:[[[ AnyObject]]] = e["geometry"]?["coordinates"] as! [[[AnyObject]]]
                geometires = (aa[0] as AnyObject) as! [AnyObject]
            }
            geometires.enumerated().forEach { ii,vv in
                let latlg:[Double] = geometires[ii] as! [Double]
                coordinates.append(CLLocationCoordinate2D(latitude: latlg[1], longitude:  latlg[0]))
            }
            //            coordinates.append(contentsOf: coordinatess)
        }
        let polygonFeature: MGLPolyline = MGLPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
        let source = MGLShapeSource(identifier: "polygonFeature", shape: polygonFeature, options: nil)
        mapView?.style!.addSource(source)
        //        let layer = MGLLineStyleLayer(identifier: "polygonFeature-layer", source: source)
        //        mapView?.style!.addLayer(layer)
        
        // Create new layer for the line.
        let layer = MGLLineStyleLayer(identifier: "polyline", source: source)
        
        // Set the line join and cap to a rounded end.
        layer.lineJoin = NSExpression(forConstantValue: "round")
        layer.lineCap = NSExpression(forConstantValue: "round")
        
        // Set the line color to a constant blue color.
        layer.lineColor = NSExpression(forConstantValue: UIColor(red: 59/255, green: 178/255, blue: 208/255, alpha: 1))
        
        // Use `NSExpression` to smoothly adjust the line width from 2pt to 20pt between zoom levels 14 and 18. The `interpolationBase` parameter allows the values to interpolate along an exponential curve.
        layer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)",
                                       [14: 2, 18: 20])
        
        // We can also add a second layer that will draw a stroke around the original line.
        let casingLayer = MGLLineStyleLayer(identifier: "polyline-case", source: source)
        // Copy these attributes from the main line layer.
        casingLayer.lineJoin = layer.lineJoin
        casingLayer.lineCap = layer.lineCap
        // Line gap width represents the space before the outline begins, so should match the main line’s line width exactly.
        casingLayer.lineGapWidth = layer.lineWidth
        // Stroke color slightly darker than the line color.
        casingLayer.lineColor = NSExpression(forConstantValue: UIColor(red: 41/255, green: 145/255, blue: 171/255, alpha: 1))
        // Use `NSExpression` to gradually increase the stroke width between zoom levels 14 and 18.
        casingLayer.lineWidth = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:($zoomLevel, 'linear', nil, %@)", [14: 1, 18: 4])
        
        // Just for fun, let’s add another copy of the line with a dash pattern.
        let dashedLayer = MGLLineStyleLayer(identifier: "polyline-dash", source: source)
        dashedLayer.lineJoin = layer.lineJoin
        dashedLayer.lineCap = layer.lineCap
        dashedLayer.lineColor = NSExpression(forConstantValue: UIColor.white)
        dashedLayer.lineOpacity = NSExpression(forConstantValue: 0.5)
        dashedLayer.lineWidth = layer.lineWidth
        // Dash pattern in the format [dash, gap, dash, gap, ...]. You’ll want to adjust these values based on the line cap style.
        dashedLayer.lineDashPattern = NSExpression(forConstantValue: [0, 1.5])
        
        mapView?.style!.addLayer(layer)
        mapView?.style!.addLayer(dashedLayer)
        mapView?.style!.insertLayer(casingLayer, below: layer)
        
    }
    let layerIdentifier = "state-layer"
    func drawPolyline(mapView: MGLMapView,geoJson: [String: AnyObject]) {
        var shape = MGLShape()
        guard let _geoJson = geoJson["geoJson"] as? [String: AnyObject] else {return}
        //
        //        convertLatlg(geoJson: _geoJson, mapView: mapView)
        
        //////
        do {
            let geoJsonData = try JSONSerialization.data(withJSONObject: _geoJson)
            
            shape = try MGLShape(data: geoJsonData, encoding: String.Encoding.utf8.rawValue)
        } catch {
            print("\(#function): \(error)")
        }
        
        
        let source = MGLShapeSource(identifier: "GEO_ID", shape: shape)
        mapView.style?.addSource(source)
        
        //        let source = MGLShapeSource(identifier: "transit", shape: shape, options: nil)
        
        
        //
        let layer = MGLFillStyleLayer(identifier: layerIdentifier, source: source)
        
        // Access the tileset layer.
        //        layer.sourceLayerIdentifier = "stateData_2-dx853g"
        
        // Create a stops dictionary. This defines the relationship between population density and a UIColor.
        let stops = [0: UIColor.yellow,
                     600: UIColor.red,
                     1200: UIColor.blue]
        
        // Style the fill color using the stops dictionary, exponential interpolation mode, and the feature attribute name.
        layer.fillColor = NSExpression(format: "mgl_interpolate:withCurveType:parameters:stops:(density, 'linear', nil, %@)", stops)
        
        // Insert the new layer below the Mapbox Streets layer that contains state border lines. See the layer reference for more information about layer names: https://www.mapbox.com/vector-tiles/mapbox-streets-v8/
        // admin-1-boundary is available starting in mapbox-streets-v8, while admin-3-4-boundaries is provided here as a fallback for styles using older data sources.
        if let symbolLayer = mapView.style!.layer(withIdentifier: "admin-1-boundary") ?? mapView.style!.layer(withIdentifier: "admin-3-4-boundaries") {
            mapView.style!.insertLayer(layer, below: symbolLayer)
        } else {
            fatalError("Layer with specified identifier not found in current style")
        }
        
    }
    
    @objc @IBAction func tappedMap(sender: UITapGestureRecognizer) {
        // Get the CGPoint where the user tapped.
        let spot = sender.location(in: mapView)
        
        // Access the features at that point within the state layer.
        let features = mapView.visibleFeatures(at: spot, styleLayerIdentifiers: Set([layerIdentifier]))
        
        // Get the name of the selected state.
        if let feature = features.first, let state = feature.attribute(forKey: "name") as? String {
            changeOpacity(name: state)
        } else {
            changeOpacity(name: "")
        }
    }
    
    func changeOpacity(name: String) {
        guard let layer = mapView.style?.layer(withIdentifier: layerIdentifier) as? MGLFillStyleLayer else {
            fatalError("Could not cast to specified MGLFillStyleLayer")
        }
        // Check if a state was selected, then change the opacity of the states that were not selected.
        if !name.isEmpty {
            layer.fillOpacity = NSExpression(format: "TERNARY(name = %@, 1, 0)", name)
        
        } else {
            // Reset the opacity for all states if the user did not tap on a state.
            layer.fillOpacity = NSExpression(forConstantValue: 1)
        }
    }
    
    
    // Allow callout view to appear when an annotation is tapped.
    func mapView(_ mapView: MGLMapView, annotationCanShowCallout annotation: MGLAnnotation) -> Bool {
        return true
    }
    
    func mapView(_ mapView: MGLMapView, didUpdate userLocation: MGLUserLocation?) {
        if let channel = channel, let userLocation = userLocation, let location = userLocation.location {
            channel.invokeMethod("map#onUserLocationUpdated", arguments: [
                "userLocation": location.toDict()
            ]);
        }
    }
    
    func mapView(_ mapView: MGLMapView, didChange mode: MGLUserTrackingMode, animated: Bool) {
        if let channel = channel {
            channel.invokeMethod("map#onCameraTrackingChanged", arguments: ["mode": mode.rawValue])
            if mode == .none {
                channel.invokeMethod("map#onCameraTrackingDismissed", arguments: [])
            }
        }
    }
    
    func mapViewDidBecomeIdle(_ mapView: MGLMapView) {
        if let channel = channel {
            channel.invokeMethod("map#onIdle", arguments: []);
        }
    }
    
    func mapView(_ mapView: MGLMapView, regionWillChangeAnimated animated: Bool) {
        if let channel = channel {
            channel.invokeMethod("camera#onMoveStarted", arguments: []);
        }
    }
    
    func mapViewRegionIsChanging(_ mapView: MGLMapView) {
        if !trackCameraPosition { return };
        if let channel = channel {
            channel.invokeMethod("camera#onMove", arguments: [
                "position": getCamera()?.toDict(mapView: mapView)
            ]);
        }
    }
    
    func mapView(_ mapView: MGLMapView, regionDidChangeAnimated animated: Bool) {
        if let channel = channel {
            channel.invokeMethod("camera#onIdle", arguments: []);
        }
    }
    
    /*
     *  MapboxMapOptionsSink
     */
    func setCameraTargetBounds(bounds: MGLCoordinateBounds?) {
        cameraTargetBounds = bounds
    }
    func setCompassEnabled(compassEnabled: Bool) {
        mapView.compassView.isHidden = compassEnabled
        mapView.compassView.isHidden = !compassEnabled
    }
    func setMinMaxZoomPreference(min: Double, max: Double) {
        mapView.minimumZoomLevel = min
        mapView.maximumZoomLevel = max
    }
    func setStyleString(styleString: String) {
        // Check if json, url or plain string:
        if styleString.isEmpty {
            NSLog("setStyleString - string empty")
        } else if (styleString.hasPrefix("{") || styleString.hasPrefix("[")) {
            // Currently the iOS Mapbox SDK does not have a builder for json.
            NSLog("setStyleString - JSON style currently not supported")
        } else if (
                    !styleString.hasPrefix("http://") &&
                        !styleString.hasPrefix("https://") &&
                        !styleString.hasPrefix("mapbox://")) {
            // We are assuming that the style will be loaded from an asset here.
            let assetPath = registrar.lookupKey(forAsset: styleString)
            mapView.styleURL = URL(string: assetPath, relativeTo: Bundle.main.resourceURL)
        } else {
            mapView.styleURL = URL(string: styleString)
        }
    }
    func setRotateGesturesEnabled(rotateGesturesEnabled: Bool) {
        mapView.allowsRotating = rotateGesturesEnabled
    }
    func setScrollGesturesEnabled(scrollGesturesEnabled: Bool) {
        mapView.allowsScrolling = scrollGesturesEnabled
    }
    func setTiltGesturesEnabled(tiltGesturesEnabled: Bool) {
        mapView.allowsTilting = tiltGesturesEnabled
    }
    func setTrackCameraPosition(trackCameraPosition: Bool) {
        self.trackCameraPosition = trackCameraPosition
    }
    func setZoomGesturesEnabled(zoomGesturesEnabled: Bool) {
        mapView.allowsZooming = zoomGesturesEnabled
    }
    func setMyLocationEnabled(myLocationEnabled: Bool) {
        if (self.myLocationEnabled == myLocationEnabled) {
            return
        }
        self.myLocationEnabled = myLocationEnabled
        updateMyLocationEnabled()
    }
    func setMyLocationTrackingMode(myLocationTrackingMode: MGLUserTrackingMode) {
        mapView.userTrackingMode = myLocationTrackingMode
    }
    func setMyLocationRenderMode(myLocationRenderMode: MyLocationRenderMode) {
        switch myLocationRenderMode {
        case .Normal:
            mapView.showsUserHeadingIndicator = false
        case .Compass:
            mapView.showsUserHeadingIndicator = true
        case .Gps:
            NSLog("RenderMode.GPS currently not supported")
        }
    }
    func setLogoViewMargins(x: Double, y: Double) {
        mapView.logoViewMargins = CGPoint(x: x, y: y)
    }
    func setCompassViewPosition(position: MGLOrnamentPosition) {
        mapView.compassViewPosition = position
    }
    func setCompassViewMargins(x: Double, y: Double) {
        mapView.compassViewMargins = CGPoint(x: x, y: y)
    }
    func setAttributionButtonMargins(x: Double, y: Double) {
        mapView.attributionButtonMargins = CGPoint(x: x, y: y)
    }
}

extension MGLStyle {
    func addLines(from source: MGLShapeSource) {
        /**
         Configure a line style layer to represent a rail line, filtering out all data from the
         source that is not of `Rail line` type. The `TYPE` is an attribute of the source data
         that can be seen by inspecting the GeoJSON source file, for example:
         
         {
         "type": "Feature",
         "properties": {
         "NAME": "Dupont Circle",
         "TYPE": "metro-station"
         },
         "geometry": {
         "type": "Point",
         "coordinates": [
         -77.043416,
         38.909605
         ]
         },
         "id": "994446c244acadeb15d3f9fc18278c73"
         }
         */
        let lineLayer = MGLLineStyleLayer(identifier: "rail-line", source: source)
        lineLayer.predicate = NSPredicate(format: "TYPE = 'Rail line'")
        lineLayer.lineColor = NSExpression(forConstantValue: UIColor.red)
        lineLayer.lineWidth = NSExpression(forConstantValue: 2)
        
        self.addLayer(lineLayer)
    }
    
    func addPoints(from source: MGLShapeSource) {
        // Configure a circle style layer to represent rail stations, filtering out all data from
        // the source that is not of `metro-station` type.
        let circleLayer = MGLCircleStyleLayer(identifier: "stations", source: source)
        circleLayer.predicate = NSPredicate(format: "TYPE = 'metro-station'")
        circleLayer.circleColor = NSExpression(forConstantValue: UIColor.red)
        circleLayer.circleRadius = NSExpression(forConstantValue: 6)
        circleLayer.circleStrokeWidth = NSExpression(forConstantValue: 2)
        circleLayer.circleStrokeColor = NSExpression(forConstantValue: UIColor.black)
        
        self.addLayer(circleLayer)
    }
    
    func addPolygons(from source: MGLShapeSource) {
        // Configure a fill style layer to represent polygon regions in Washington, D.C.
        // Source data that is not of `neighborhood-region` type will be excluded.
        let polygonLayer = MGLFillStyleLayer(identifier: "DC-regions", source: source)
        polygonLayer.predicate = NSPredicate(format: "TYPE = 'neighborhood-region'")
        polygonLayer.fillColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.41, blue: 0.97, alpha: 0.3))
        polygonLayer.fillOutlineColor = NSExpression(forConstantValue: UIColor(red: 1, green: 0.41, blue: 0.97, alpha: 1.0))
        
        self.addLayer(polygonLayer)
    }
}
