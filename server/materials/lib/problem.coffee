import { JSDOM } from 'jsdom'

import {downloadLimited} from '../../lib/download'
import Material from '../../models/Material'

import getTestSystem from '../../testSystems/TestSystemRegistry'

class Problem
    constructor: (options) ->
        if typeof options == "number"
            # informatics problem
            options = {id: options}
        @options = options
        {testSystem = "informatics", id} = options
        @testSystem = testSystem
        testSystemObject = getTestSystem(@testSystem)
        if not id
            id = testSystemObject.getProblemId(@options)
        @id = id
        @testSystemData = testSystemObject.getProblemData(@options)
        @testSystemData.system = @testSystem

    download: (label) ->
        testSystem = getTestSystem(@testSystem)
        return await testSystem.downloadProblem(@options, label)

    build: (context, order) ->
        if @options.onlyForLabel and not (context.label in @options.onlyForLabel)
            return null
        id = "p#{@id}#{context.label}"
        material = await Material.findById(id)
        if not material
            {name, text} = await @download(context.label)
        else
            name = material.title
            text = material.content
        data = 
            _id: id,
            type: "problem",
            title: name,
            content: text,
            testSystemData: @testSystemData
            order: order

        await context.process(data)
        
        delete data.content
        return data

export default problem = (args...) -> () -> new Problem(args...)