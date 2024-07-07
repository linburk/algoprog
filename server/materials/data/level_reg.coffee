import level from "../lib/level"
import level_reg2009 from "./level_reg2009"
import level_reg2010 from "./level_reg2010"
import level_reg2011 from "./level_reg2011"
import level_reg2012 from "./level_reg2012"
import level_reg2013 from "./level_reg2013"
import level_reg2014 from "./level_reg2014"
import level_reg2015 from "./level_reg2015"
import level_reg2016 from "./level_reg2016"
import level_reg2017 from "./level_reg2017"
import level_reg2018 from "./level_reg2018"
import level_reg2019 from "./level_reg2019"
import level_reg2020 from "./level_reg2020"
import level_reg2021 from "./level_reg2021"
import level_reg2022 from "./level_reg2022"
import level_reg2023 from "./level_reg2023"
import level_reg2024 from "./level_reg2024"

export default level_reg = () ->
    return level("reg", "Региональные олимпиады", [
        level_reg2009(),
        level_reg2010(),
        level_reg2011(),
        level_reg2012(),
        level_reg2013(),
        level_reg2014(),
        level_reg2015(),
        level_reg2016(),
        level_reg2017(),
        level_reg2018(),
        level_reg2019(),
        level_reg2020(),
        level_reg2021(),
        level_reg2022(),
        level_reg2023(),
        level_reg2024(),
])