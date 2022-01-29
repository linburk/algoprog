mongoose = require('mongoose')
import logger from '../log'

import Result from './result'


APPROVED = 2
DISPROVED = 1
UNKNOWN = 0
BAD = -1

findMistakeSchema = new mongoose.Schema
    _id: String
    source: String
    submit: String
    correctSubmit: String
    user: {type: String, select: false}
    problem: String
    language: String
    approved: { type: Number, default: UNKNOWN },
    order: String

findMistakeSchema.methods.upsert = () ->
    # https://jira.mongodb.org/browse/SERVER-14322
    try
        @update(this, {upsert: true})
    catch
        logger.info "Could not upsert a findMistake"

findMistakeSchema.methods.setApprove = (approve) ->
    logger.info "Approve findMistake #{@_id} -> #{approve}"
    @approved = if approve then APPROVED else DISPROVED
    @update(this)

findMistakeSchema.methods.setBad = () ->
    logger.info "Bad findMistake #{@_id}"
    @approved = BAD
    @update(this)

findMistakeSchema.methods.isAllowedForUser = (userKey, admin) ->
    allowed = false
    if admin 
        allowed = true
    else if userKey
        result = await Result.findByUserAndTable(userKey, @problem)
        allowed = result && result.solved > 0    
    return allowed

findMistakeSchema.statics.findApprovedByProblemAndNotUser = (problem, user) ->
    FindMistake.find
        approved: APPROVED
        problem: problem
        user: {$ne: user}

findMistakeSchema.statics.findOneNotApproved = () ->
    FindMistake.findOne
        approved: UNKNOWN

findMistakeSchema.statics.findNotApprovedCount = () ->
    FindMistake.find({approved: UNKNOWN}).countDocuments()

findMistakeSchema.index({ problem : 1, user: 1, order: 1 })
findMistakeSchema.index({ approved : 1 })

FindMistake = mongoose.model('FindMistake', findMistakeSchema);

export default FindMistake
