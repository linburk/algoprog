import label from "../lib/label"
import level from "../lib/level"

export default level_about = () ->
    return level("about", "О курсе", [
        label("<div><div class=\"mod-indent-outer w-100\"><div><div class=\"contentwithoutlink \"><div class=\"no-overflow\"><div class=\"no-overflow\"></div></div></div></div></div></div>"),
    ])