package
{
    import flash.events.Event;
    import flash.events.HTTPStatusEvent;
    import flash.filesystem.File;
    import flash.filesystem.FileMode;
    import flash.filesystem.FileStream;
    import flash.net.URLLoader;
    import flash.net.URLLoaderDataFormat;
    import flash.net.URLRequest;
    import flash.net.URLRequestHeader;

    public class SmartAssetLoader
    {
        private static var _instance:SmartAssetLoader;

        private var assetDirectory:File = File.applicationStorageDirectory.resolvePath("assets");
        private var callback:Function;

        public function SmartAssetLoader()
        {
            if (_instance)
                throw new Error("Singleton; Use getInstance() instead");
            _instance = this;
        }

        public static function getInstance():SmartAssetLoader
        {
            if (!_instance)
                new SmartAssetLoader();
            return _instance;
        }

        public function start(clientAssetList:Array, callback:Function):void
        {
            this.callback = callback;

            // Add any new assets from the newAssetList (from the client) to the asset version list
            var localAssetVersions:Object = loadCurrentAssetVersions();
            for each (var key:String in clientAssetList)
                if (!localAssetVersions[key])
                    localAssetVersions[key] = -1;

            var assetsToDownload:Array = [];

            var keys:Array = [];
            for (key in localAssetVersions)
                keys.push(key);

            var loader:URLLoader = new URLLoader();
            loader.addEventListener(HTTPStatusEvent.HTTP_RESPONSE_STATUS, onLoaderHTTPStatusEvent);
            var index:int = 0;
            next();

            function onLoaderHTTPStatusEvent(event:HTTPStatusEvent):void
            {
                if (event.responseHeaders.length > 0)
                {
                    for each (var header:URLRequestHeader in event.responseHeaders)
                        if (header.name == "Last-Modified" && header.value != localAssetVersions[keys[index]])
                            assetsToDownload.push({key: keys[index], version: header.value});

                    loader.close();

                    index++;
                    if (index < keys.length)
                        next();
                    else
                    {
                        if (assetsToDownload.length > 0)
                            downloadAssets(localAssetVersions, assetsToDownload);
                        else
                            unpack();
                    }
                }
            }

            function next():void
            {
                var r:URLRequest = new URLRequest("https://omgforever.com/assets/" + keys[index]);
                loader.load(r);
            }
        }

        private function downloadAssets(currentAssetVersions:Object, assetsToDownload:Array):void
        {
            var loader:URLLoader = new URLLoader();
            loader.addEventListener(Event.COMPLETE, onAssetDownloadComplete);

            var index:int = 0;
            next();

            function next():void
            {
                var r:URLRequest = new URLRequest("https://omgforever.com/assets/" + assetsToDownload[index].key);
                loader.load(r);

                loader.dataFormat = URLLoaderDataFormat.BINARY;
            }

            function onAssetDownloadComplete(event:Event):void
            {
                var a:Object                = assetsToDownload[index];
                currentAssetVersions[a.key] = a.version;
                saveCurrentAssetVersions(currentAssetVersions);

                // Save the file
                var f:File            = File.applicationStorageDirectory.resolvePath(a.key);
                var stream:FileStream = new FileStream();
                stream.open(f, FileMode.WRITE);
                var l:URLLoader = event.target as URLLoader;
                stream.writeBytes(loader.data);
                stream.close();

                index++;
                if (index < assetsToDownload.length)
                    next();
                else
                    unpack();
            }
        }

        private function unpack():void
        {
            /*
            Unzip and delete all zip files in the assets directory
             */


            // Callback
            callback.apply();
        }

        public function loadCurrentAssetVersions():Object
        {
            var f:File     = File.applicationStorageDirectory.resolvePath("assetList.json");
            var obj:Object = {};
            if (f.exists)
            {
                var stream:FileStream = new FileStream();
                stream.open(f, FileMode.READ);
                obj = JSON.parse(stream.readUTFBytes(stream.bytesAvailable));
                stream.close();
            }

            trace("Loaded: " + JSON.stringify(obj));
            return obj;
        }

        public function saveCurrentAssetVersions(currentAssetVersions:Object):void
        {
            var f:File            = File.applicationStorageDirectory.resolvePath("assetList.json");
            var stream:FileStream = new FileStream();
            stream.open(f, FileMode.WRITE);
            stream.writeUTFBytes(JSON.stringify(currentAssetVersions));
            stream.close();

            trace("Saved: " + JSON.stringify(currentAssetVersions));
        }
    }
}
