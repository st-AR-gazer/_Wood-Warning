auto fidFile;

bool isMapLoaded = false;
bool conditionForIce1 = false;
bool conditionForIce2 = false;
bool conditionForWood = false;
bool hasPlayedOnThisMap = false;

void Update(float dt) {
    time(dt);
}

void Main() {
    loadTextures();
    while (true) {
        MapCheck();
        sleep(500);
    }
}


void MapCheck() {
    CTrackMania@ app = cast<CTrackMania>(GetApp());
    if (app is null) return;

    auto playground = cast<CSmArenaClient>(app.CurrentPlayground);
    if (playground is null || playground.Arena.Players.Length == 0) {
        isMapLoaded = false;
        conditionForIce1 = false;
        conditionForIce2 = false;
        conditionForWood = false;
        hasPlayedOnThisMap = false;
        return;
    }

    auto script = cast<CSmScriptPlayer>(playground.Arena.Players[0].ScriptAPI);
    if (script is null) return; 

    auto scene = cast<ISceneVis@>(app.GameScene);
    if (scene is null) return;

    CSystemFidFile@ fidFile = cast<CSystemFidFile>(app.RootMap.MapInfo.Fid);
    if (fidFile is null) { 
        // log("fidFile is null in MapCheck.", LogLevel::Warn, 44);
        isMapLoaded = false;
        conditionForIce1 = false;
        conditionForIce2 = false;
        conditionForWood = false;
        hasPlayedOnThisMap = false;
        return;
    }

    

    if (!isMapLoaded) {
        log("Map load check started...", LogLevel::Info, 56);
        OnMapLoad();
        isMapLoaded = true;
        log("Map load check completed.", LogLevel::Info, 59);
    }
}

void OnMapLoad() {
    log("OnMapLoad function started.", LogLevel::Info, 64);

    string exeBuild = GetExeBuildFromXML();
    log("Exe build: " + exeBuild, LogLevel::Info, 67);

    if (exeBuild < "2022-05-19_15_03") {
        if (doVisualImageInducator) {
            conditionForIce1 = true;
        } else {
            log("The exebuild is less than 2022-05-19_15_03. Warning ice physics-1.", LogLevel::Warn, 73);
            NotifyWarnIce("This map's exeBuild: '" + exeBuild + "' indicates that it was uploaded BEFORE the first ice update, the medal times may be affected.");
        }
    }
    if (exeBuild < "2023-04-28_17_34" && exeBuild >= "2022-05-19_15_03") {
        if (doVisualImageInducator) {
            conditionForIce2 = true;

        } else {
            log("The exebuild falls between 2023-04-28_17_34 and 2023-11-15_11_56. Warning ice physics-2.", LogLevel::Warn, 82);
            NotifyWarnIce2("This map's exeBuild: '" + exeBuild + "' falls BETWEEN the two ice updates, the medal times may be affected.");
        }
    }
    
    if (exeBuild < "2023-11-15_11_56") {
        if (doVisualImageInducator) {
            conditionForWood = true;
        } else {
            log("The exebuild is less than 2023-11-15_11_56. Warning wood physics.", LogLevel::Warn, 91);
            NotifyWarn("This map's exeBuild: '" + exeBuild + "' indicates that this map was uploaded BEFORE the wood update, all wood on this map will behave like tarmac (road).");
        }
    }
    CountdownTime = 11000;
    // very imp ^^^

    log("OnMapLoad function finished.", LogLevel::Info, 98);
    
}

class GbxHeaderChunkInfo
{
    int ChunkId;
    int ChunkSize;
}

string GetExeBuildFromXML() {
    string xmlString = "";
    string exeBuild = "";

    log("GetExeBuildFromXML function started.", LogLevel::Info, 112);

    CSystemFidFile@ fidFile = cast<CSystemFidFile>(GetApp().RootMap.MapInfo.Fid);

    if (fidFile !is null)
    {
        try
        {
            log("Opening map file.", LogLevel::Info, 120);
            IO::File mapFile(fidFile.FullFileName);
            mapFile.Open(IO::FileMode::Read);

            mapFile.SetPos(17);
            int headerChunkCount = mapFile.Read(4).ReadInt32();
            log("Header chunk count: " + headerChunkCount, LogLevel::Info, 126);

            GbxHeaderChunkInfo[] chunks = {};
            for (int i = 0; i < headerChunkCount; i++)
            {
                GbxHeaderChunkInfo newChunk;
                newChunk.ChunkId = mapFile.Read(4).ReadInt32();
                newChunk.ChunkSize = mapFile.Read(4).ReadInt32() & 0x7FFFFFFF;
                chunks.InsertLast(newChunk);
                log("Read chunk " + i + " with id " + newChunk.ChunkId + " and size " + newChunk.ChunkSize, LogLevel::Info, 135);
            }

            for (uint i = 0; i < chunks.Length; i++)
            {
                MemoryBuffer chunkBuffer = mapFile.Read(chunks[i].ChunkSize);
                if (chunks[i].ChunkId == 50606085) {
                    int stringLength = chunkBuffer.ReadInt32();
                    xmlString = chunkBuffer.ReadString(stringLength);
                    break;
                }
                log("Read chunk " + i + " of size " + chunks[i].ChunkSize, LogLevel::Info, 146);
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
                        log("Exe build not found in XML. Assuming a new map.", LogLevel::Warn, 162);
                        return "9999-99-99_99_99";
                    }
                } else {
                    log("headerNode is invalid in GetExeBuildFromXML.", LogLevel::Warn, 166);
                }

            }
            log("GetExeBuildFromXML function finished.", LogLevel::Info, 170);
        }
        catch
        {
            log("Error reading map file in GetExeBuildFromXML.", LogLevel::Error, 174);
        }
    }
    else
    {
        log("fidFile is null in GetExeBuildFromXML.", LogLevel::Warn, 179);
    }
    return exeBuild;
}