import Problem from './problem'
import logger from '../log'

mongoose = require('mongoose')

tablesSchema = new mongoose.Schema
    _id: String
    name: String
    tables: [String]
    problems: [String]
    parent: String
    # order: String
    order: Number
 
 
parentFromParent = (level) ->
    if level == Table.main
        return undefined
    p = parseLevel(level)
    if p.minor
        return p.major
    else
        return Table.main


tablesSchema.methods.addTable = (id) ->
    if id in @tables
        return
    @update({$push: { tables: id }})

tablesSchema.methods.setOrder = (order) ->
    await @update({$set: { order: order }})
    @order = order
    if @parent
        p = await Table.findById(@parent)
        if p.order > @order - 1
            await p.setOrder(@order - 1)    


tablesSchema.methods.upsert = () ->
    await @update(this, {upsert: true}).exec()
    for prob in @problems
        (await Problem.findById(prob)).addTable(@_id)
    if @parent
        if not await Table.findById(@parent)
            pp = parentFromParent(@parent)
            await new Table(
                _id: @parent
                name: @parent
                parent: pp
                order: @order - 1
            ).upsert()
        p = await Table.findById(@parent)
        await p.addTable(@_id)
        if p.order > @order - 1
            await p.setOrder(@order - 1)

tablesSchema.methods.height = () ->
        if @tables.length > 0
            return await (await Table.findById(@tables[0])).height() + 1
        else
            return 1

tablesSchema.methods.expand = () ->
        expandedTables = []
        for table in @tables
            subTable = await Table.findById(table)
            await subTable.expand()
            expandedTables.push(subTable)
        @tables = expandedTables
        expandedProblems = []
        for problem in @problems
            expandedProblem = await Problem.findById(problem)
            expandedProblems.push(expandedProblem)
        @problems = expandedProblems
        return this

tablesSchema.methods.descendandTables = () ->
        result = [@_id]
        for table in @table
            subTable = await Table.findById(table)
            result = result.concat(await subTable.descendandTables())
        for problem in @problems
            result.push(problem)
        result

tablesSchema.statics.removeDuplicateChildren = () ->
        tables = await Table.findAll()
        for table in tables
            wasTables = {}
            newTables = []
            for subTable in table.tables
                if not (subTable of wasTables)
                    wasTables[subTable] = 1
                    # await
                    newTables.push
                        _id: subTable
                        order: (await Table.findById(subTable)).order  # noawait
            newTables.sort((a, b) -> a.order - b.order)
            newTables = (t._id for t in newTables)
            logger.trace "removing duplicate from ", table._id, " new tables=", newTables
            table.tables = newTables
            await table.update(table)

tablesSchema.statics.main = "main"        


tablesSchema.statics.findAll = ->
    @find {}

Table = mongoose.model('Tables', tablesSchema);

export default Table
