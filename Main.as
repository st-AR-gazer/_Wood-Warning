auto fidFile;

bool isMapLoaded = false;

void Main() {
    NotifyWarn("a");
    NotifyWarnIce("b");
    NotifyWarnIce2("c");
    while (true) {
        Update();
        sleep(500);
    }
}

void Update() {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null) return;

    auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
    if (playground is null || playground.Arena.Players.Length == 0) {
        isMapLoaded = false;
        return;
    }

    auto script = cast<CSmScriptPlayer>(playground.Arena.Players[0].ScriptAPI);
    if (script is null) return; 

    auto scene = cast<ISceneVis@>(app.GameScene);
    if (scene is null) return;

    CSystemFidFile@ fidFile = cast<CSystemFidFile>(app.RootMap.MapInfo.Fid);
    if (fidFile is null) { 
        isMapLoaded = false;
        return;
    }

    if (!isMapLoaded) {
        log("Map load check started...", LogLevel::Info);
        OnMapLoad();
        isMapLoaded = true;
        log("Map load check completed.", LogLevel::Info);
    }
}

void OnMapLoad() {
    log("OnMapLoad function started.", LogLevel::Info);

    string exeBuild = GetExeBuildFromXML();
    log("Exe build: " + exeBuild, LogLevel::Info);

    if (exeBuild < "2022-05-19_15_03") {
        log("The exebuild is less than 2022-05-19_15_03. Warning ice physics-1.", LogLevel::Warn);
        NotifyWarnIce("This map's exeBuild: '" + exeBuild + "' indicates that it was uploaded BEFORE the first ice update, the medal times may be affected.");
    } else if (exeBuild < "2023-04-28_17_34" && exeBuild >= "2022-05-19_15_03") {
        log("The exebuild falls between 2023-04-28_17_34 and 2023-11-15_11_56. Warning ice physics-2.", LogLevel::Warn);
        NotifyWarnIce2("This map's exeBuild: '" + exeBuild + "' falls BETWEEN the two ice updates, the medal times may be affected.");
    }
    
    if (exeBuild < "2023-11-15_11_56")
    {
        log("The exebuild is less than 2023-11-15_11_56. Warning wood physics.", LogLevel::Warn);
        NotifyWarn("This maps exeVer: '" + exeBuild + "' indicates that this map was uploaded BEFORE the wood update, all wood on this map will behave like tarmac (road).");
    }
    log("OnMapLoad function finished.", LogLevel::Info);
}

class GbxHeaderChunkInfo
{
    int ChunkId;
    int ChunkSize;
}

string GetExeBuildFromXML() {
    string xmlString = "";
    string exeBuild = "";

    log("GetExeBuildFromXML function started.", LogLevel::Info);

    CSystemFidFile@ fidFile = cast<CSystemFidFile>(GetApp().RootMap.MapInfo.Fid);

    if (fidFile !is null)
    {
        try
        {
            log("Opening map file.", LogLevel::Info);
            IO::File mapFile(fidFile.FullFileName);
            mapFile.Open(IO::FileMode::Read);

            mapFile.SetPos(17);
            int headerChunkCount = mapFile.Read(4).ReadInt32();
            log("Header chunk count: " + headerChunkCount, LogLevel::Info);

            GbxHeaderChunkInfo[] chunks = {};
            for (int i = 0; i < headerChunkCount; i++)
            {
                GbxHeaderChunkInfo newChunk;
                newChunk.ChunkId = mapFile.Read(4).ReadInt32();
                newChunk.ChunkSize = mapFile.Read(4).ReadInt32() & 0x7FFFFFFF;
                chunks.InsertLast(newChunk);
                log("Read chunk " + i + " with id " + newChunk.ChunkId + " and size " + newChunk.ChunkSize, LogLevel::Info);
            }

            for (uint i = 0; i < chunks.Length; i++)
            {
                MemoryBuffer chunkBuffer = mapFile.Read(chunks[i].ChunkSize);
                if (chunks[i].ChunkId == 50606085) {
                    int stringLength = chunkBuffer.ReadInt32();
                    xmlString = chunkBuffer.ReadString(stringLength);
                    break;
                }
                log("Read chunk " + i + " of size " + chunks[i].ChunkSize, LogLevel::Info);
            }

            mapFile.Close();


            if (xmlString != "") {
                XML::Document doc;
                doc.LoadString(xmlString);
                XML::Node headerNode = doc.Root().FirstChild();
                
                if (headerNode) {
                    string potentialExeBuild = headerNode.Attribute("exebuild");
                    if (potentialExeBuild != "") {
                        exeBuild = potentialExeBuild;
                    } else {
                        log("Exe build not found in XML. Assuming a new map.", LogLevel::Warn);
                        return "9999-99-99_99_99";
                    }
                } else {
                    log("headerNode is invalid in GetExeBuildFromXML.", LogLevel::Warn);
                }

            }


            log("GetExeBuildFromXML function finished.", LogLevel::Info);
        }
        catch
        {
            log("Error reading map file in GetExeBuildFromXML.", LogLevel::Error);
        }
    }
    else
    {
        log("fidFile is null in GetExeBuildFromXML.", LogLevel::Warn);
    }
    return exeBuild;
}