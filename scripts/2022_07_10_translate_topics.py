#!/usr/bin/python3
import json
import os
import os.path
import re
import requests
from pprint import pprint

INDENT2 = "    "

def translate(strings):
    """
    res = ["en" + s for s in strings]
    print(">>>", strings, res)
    return res
    """
    data = {
        "folderId": os.environ["FOLDER_ID"],
        "texts": strings,
        "targetLanguageCode": "en",
        "sourceLanguageCode": "ru",
        "format": "HTML"
    }
    headers = {
        "Content-Type": "application/json",
        "Authorization": "Api-Key " + os.environ["API_KEY"]
    }
    url = "https://translate.api.cloud.yandex.net/translate/v2/translate"
    result = requests.post(url, json=data, headers=headers)
    if "translations" not in result.json():
        pprint(result.json())
    return [x["text"] for x in result.json()["translations"]]

def make_ruen(ru, en, indent=None, q='"'):
    if not indent:
        return q + en + q
        #return 'ruen(' + q + ru + q + ', ' + q + en + q + ')'
    else:
        return "\n" + indent + q + en + q
        #return 'ruen(\n' + indent + q + ru + q + ',\n' + indent + q + en + q + ')'

def replace_imports(match):
    print("------")
    imports = match.group(0).split("\n")
    imports = [i for i in imports if i]
    imports.append(r'import {ruen} from "../../lib/util"')
    imports = sorted(imports)
    return "\n".join(imports) + "\n"

def replace_topic(match):
    print("------")
    PROBLEMS_ON = "Задачи на "
    indent = match.group(1)
    head = match.group(2)
    name1 = match.group(3)
    name2 = match.group(4)
    add_problems = False
    if name2[:len(PROBLEMS_ON)] == PROBLEMS_ON:
        name2 = name2[len(PROBLEMS_ON):]
        add_problems = True
    en_name1, en_name2 = translate([name1, name2])
    if add_problems:
        en_name2 = "Problems on " + en_name2
        name2 = PROBLEMS_ON + name2
    return (indent + head + "(\n" +
        indent + INDENT2 + make_ruen(name1, en_name1) + ",\n" +
        indent + INDENT2 + make_ruen(name2, en_name2) + ",\n" +
        indent + "[")

def replace_null_topic(match):
    print("------")
    indent = match.group(1)
    head = match.group(2)
    name = match.group(3)
    null = match.group(4)
    en_name = translate([name])[0]
    return (indent + head + "(\n" +
        indent + INDENT2 + make_ruen(name, en_name) + ",\n" +
        indent + INDENT2 + null + ",\n" +
        indent + "[")

def replace_label(match):
    print("------")
    indent = match.group(1)
    head = match.group(2)
    text = match.group(3)
    to_tr = json.loads("\"" + text + "\"")
    en_text = json.dumps(translate([to_tr])[0])[1:-1]
    print(text)
    print(en_text)
    return (indent + head + make_ruen(text, en_text, " " * len(indent) + INDENT2) + ")")

def replace_page(match):
    print("------")
    global cnt
    cnt += 1
    indent = match.group(1)
    head = match.group(2)
    text = match.group(3)
    to_tr = json.loads("\"" + text + "\"")
    en_text = json.dumps(translate([to_tr])[0])[1:-1]
    print(text)
    print(en_text)
    return (indent + head + make_ruen(text, en_text, " " * len(indent) + INDENT2))

def replace_raw_string(match):
    print("------")
    indent = match.group(1)
    head = match.group(2)
    text = match.group(3).strip()
    en_text = translate([text])[0] if len(text) < 9000 else text
    print(text)
    print(en_text)
    return (indent + 
        make_ruen('String.raw"""' + text + '"""', 'String.raw"""' + en_text + '"""', " " * len(indent) + INDENT2, ""))

#path = "server/materials/data/topics"
#topics = [os.path.join(path, f) for f in os.listdir(path)]
#topics = [f for f in topics if os.path.isfile(f)]

cnt = 0
#for topic in topics:
path_about = "server/materials/data-en/level_about.coffee"
for topic in [path_about]:
    print(topic)
    with open(topic, "r") as f:
        data = f.read()
    data = re.sub(r"(^import(.*)?$\n)*", replace_imports, data, 1, re.M)
    #data = re.sub(r"^(\s+)(topic: topic)\(\"([^\"]*)\", \"([^\"]*)\", \[\n\s*", replace_topic, data, 0, re.M)
    data = re.sub(r"^(.*)(label\()\"(([^\"]*(\\\")?)*[^\\])\"\)", replace_label, data, 0, re.M)
    data = re.sub(r"^([^\n]*)(String.raw)\"\"\"(.*?)\"\"\"", replace_raw_string, data, 0, re.MULTILINE | re.DOTALL)
    data = re.sub(r"^(.*)(page\()\"(([^\"]*(\\\")?)*[^\\])\"", replace_page, data, 0, re.M)
    #data = re.sub(r"^(\s+)(topic:\s*topic)\(\"([^\"]*)\", (null), \[\n\s*", replace_null_topic, data, 0, re.M)
    #data = re.sub(r"^(\s+)(topic)\(\"([^\"]*)\", \"([^\"]*)\", \[\n\s*", replace_topic, data, 0, re.M)
    #data = re.sub(r"^(\s+)(topic)\(\"([^\"]*)\", (null), \[\n\s*", replace_null_topic, data, 0, re.M)
    #data = re.sub(r"^(.*)(contest\()\"(([^\"]*(\\\")?)*[^\\])\"", replace_page, data, 0, re.M)
    data = re.sub(r"^(.*)(labelLink\()\"(([^\"]*(\\\")?)*[^\\])\"", replace_page, data, 0, re.M)
    print(data)
    with open(topic, "w") as f:
        f.write(data)
    #break
    #cnt += 1
    #if cnt == 3:
    #    break