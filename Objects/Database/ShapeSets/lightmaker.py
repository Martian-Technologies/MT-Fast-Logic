import uuid
import json

lightData = json.load(
    open(
        r"E:\Program Files (x86)\Steam\steamapps\common\Scrap Mechanic\Survival\Objects\Database\ShapeSets\lights.json"
    )
)
partList: list = lightData["partList"]
partList.extend(
    json.load(
        open(
            r"E:\Program Files (x86)\Steam\steamapps\common\Scrap Mechanic\Data\Objects\Database\ShapeSets\lights.json"
        )
    )["partList"]
)


inventoryDescriptions: dict = json.load(
    open(
        r"E:\Program Files (x86)\Steam\steamapps\common\Scrap Mechanic\Survival\Gui\Language\English\inventoryDescriptions.json"
    )
)

inventoryDescriptions.update(
    json.load(
        open(
            r"E:\Program Files (x86)\Steam\steamapps\common\Scrap Mechanic\Data\Gui\Language\English\InventoryItemDescriptions.json"
        )
    )
)

uuids = {
    "obj_light_factorylamp": "f36e03b4-eea7-4c0a-842d-225ed50e5635",
    "obj_light_packingtablelamp": "da2a1835-8ef3-4bef-a16c-c3d38ffe3b34",
    "obj_light_fluorescentlamp": "767a4a08-7471-465a-9dda-6e3c246fe3b1",
    "obj_light_arealight": "dcb72c88-76cc-4fb2-87b7-b8a6b83f898b",
    "obj_light_posterspotlight": "e5b00d9a-e27f-4aff-ae74-612ac9edae07",
    "obj_light_posterspotlight2": "6efc9636-e380-4c6e-ad95-79f1919ac1dc",
    "obj_light_headlight": "31eac728-a2db-420a-8034-835229f42d4c",
    "obj_light_beamframelight": "85caeefe-9935-42ae-83a4-8c1df6528758",
}

nameUuidPairs = {}
oldUuidToNewUuid = {}

for light in partList:
    name = light["name"]
    _uuid = light["uuid"]
    light["name"] = "Fast " + inventoryDescriptions[light["uuid"]]["title"]
    if name in uuids:
        light["uuid"] = uuids[name]
    else:
        light["uuid"] = str(uuid.uuid4())
    nameUuidPairs[name] = light["uuid"]
    light["scripted"] = {
        "classname": "FastLight",
        "filename": "$CONTENT_DATA/Scripts/fastLogicBlocks/FastLight.lua",
    }
    light:dict
    del light["spotlight"]
    oldUuidToNewUuid[_uuid] = light["uuid"]

json.dump(
    lightData,
    open(
        r"C:\Users\Ben H\AppData\Roaming\Axolot Games\Scrap Mechanic\User\User_76561197985454940\Mods\MT Fast Logic\Objects\Database\ShapeSets\fastlogiclights.shapeset",
        "w",
    ),
    indent=4,
)
print(json.dumps(oldUuidToNewUuid, indent=4))
