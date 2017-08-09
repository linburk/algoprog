mongoose = require('mongoose')

import calculateChocos from '../calculations/calculateChocos'
import calculateRatingEtc from '../calculations/calculateRatingEtc'
import calculateLevel from '../calculations/calculateLevel'
import calculateCfRating from '../calculations/calculateCfRating'

import logger from '../log'

SEMESTER_START = "2016-06-01"

usersSchema = new mongoose.Schema
    _id: String,
    name: String,
    userList: String,
    chocos: [Number],
    level:
        current: String,
        start: String,
        base: String,
    active: Boolean,
    ratingSort: Number,
    byWeek: {solved: mongoose.Schema.Types.Mixed, ok: mongoose.Schema.Types.Mixed},
    rating: Number,
    activity: Number,
    cf:
        login: String,
        rating: Number,
        color: String,
        activity: Number,
        progress: Number
        
usersSchema.methods.upsert = () ->
    @update(this, {upsert: true})
    
usersSchema.methods.updateChocos = ->
    @chocos = await calculateChocos @_id
    logger.debug "calculated chocos", @name, @chocos
    @update({$set: {chocos: @chocos}})
        
usersSchema.methods.updateRatingEtc = ->
    res = await calculateRatingEtc this
    logger.debug "updateRatingEtc", @name, res
    @update({$set: res})
    
usersSchema.methods.updateLevel = ->
    @level.current = await calculateLevel @_id, @level.base, new Date("2100-01-01")
    @level.start = await calculateLevel @_id, @level.base, new Date(SEMESTER_START)
    @update({$set: {level: @level}})
    
usersSchema.methods.updateCfRating = ->
    logger.debug "Updating cf rating ", @name
    res = await calculateCfRating this
    logger.debug "Updated cf rating ", @name, res
    if not res
        return
    res.login = @cf.login
    @update({$set: {cf: res}})

usersSchema.methods.setBaseLevel = (level) ->
    await @update({$set: {"level.base": level}})
    @level.base = level
    await @updateLevel()
    @updateRatingEtc()

usersSchema.methods.setCfLogin = (cfLogin) ->
    logger.info "setting cf login ", @_id, cfLogin
    await @update({$set: {"cf.login": cfLogin}})
    @cf.login = cfLogin
    @updateCfRating()
    

usersSchema.statics.findByList = (list) ->
    User.find({userList: list}).sort({active: -1, level: -1, ratingSort: -1})

usersSchema.statics.findAll = (list) ->
    User.find {}


usersSchema.index
    userList: 1
    active: -1
    level: -1
    ratingSort: -1

User = mongoose.model('Users', usersSchema);

export default User
