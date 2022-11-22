import MaterialList from "./MaterialList"

class SimpleLevel extends MaterialList
    constructor: (id, title, levels) ->
        super(levels)
        @title = title
        @id = id

    build: (context, order) ->
        properties = 
            _id: "#{@id}#{context.label}"
            type: "simpleLevel"
            title: @title?(context.label) || @title

        material = await super.build(context, order, properties)

        return material

export default simpleLevel = (args...) -> () -> new SimpleLevel(args...)