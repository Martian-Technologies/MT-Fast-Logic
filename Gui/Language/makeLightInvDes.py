import json

lights:list = json.load(open(r"Objects\Database\ShapeSets\fastlogiclights.shapeset"))["partList"]
invDes = open(r"Gui\Language\English\inventoryDescriptions.json").read()

for light in lights:
    invDes +=\
    ",\n\
    \"" + light["uuid"] + "\" : {\n\
    \"description\" : \"Speed Up: Any creation made with Fast Logic can be speed up by pressing 'u' on a Fast Logic block.\",\n\
    \"title\" : \"" + light["name"] + "\"\n\
    }"

open(r"Gui\Language\English\inventoryDescriptions2.json", "w").write(invDes)