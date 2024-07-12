seedrandom = require('seedrandom')
React = require('react')
connectEnsureLogin = require('connect-ensure-login')
passport = require('passport')
iconv = require('iconv-lite')
Entities = require('html-entities').XmlEntities
sha256 = require('sha256')
sha1 = require('sha1')
FileType = require('file-type')
deepcopy = require('deepcopy')
moment = require('moment')
XRegExp = require('xregexp')

import bodyParser from "body-parser"
import { renderToString } from 'react-dom/server';
import { Provider } from 'react-redux'
import { StaticRouter } from 'react-router'

import {UserNameRaw} from '../../client/components/UserName'
import awaitAll from '../../client/lib/awaitAll'
import ACHIEVES from '../../client/lib/achieves'
import {getGraduateYear} from '../../client/lib/graduateYearToClass'
import GROUPS from '../../client/lib/groups'
import {unpaidBlocked} from '../../client/lib/isPaid'
import hasCapability, {hasCapabilityForUserList
 CHECKINS,
 EDIT_PAGE,
 ADD_BEST_SUBMITS,
 SEE_BEST_SUBMITS,
 SEE_FIND_MISTAKES,
 SEE_START_LEVEL,
 EDIT_USER,
 SEARCH_USERS,
 VIEW_SUBMITS,
 SEE_SIMILAR_SUBMITS,
 SEE_LAST_COMMENTS,
 REVIEW,
 VIEW_RECEIPT,
 MOVE_USER,
 MOVE_UNKNOWN_USER,
 SET_DORMANT,
 ACTIVATE,
 TRANSLATE,
 RESET_YEAR,
 UPDATE_ALL,
 CREATE_TEAM,
 DOWNLOADING_STATS,
 APPROVE_FIND_MISTAKE
} from '../../client/lib/adminCapabilities'
import createStore from '../../client/redux/store'

import {getTables, getUserResult} from '../calculations/updateTableResults'

import * as downloadSubmits from "../cron/downloadSubmits"
import findSimilarSubmits from '../hashes/findSimilarSubmits'
import InformaticsUser from '../informatics/InformaticsUser'

import getCbRfRate from '../lib/cbrf'
import download, {getStats} from '../lib/download'
import normalizeCode from '../lib/normalizeCode'
import {addIncome, makeReceiptLink} from '../lib/npd'
import addUsnReceipt from '../lib/receipts'
import setDirty from '../lib/setDirty'
import sleep from '../lib/sleep'
import translate from '../lib/translate'
import translateProblems from '../lib/translateProblems'

import {allTables} from '../materials/data/tables'
import downloadMaterials from '../materials/downloadMaterials'
import {notify} from '../lib/telegramBot'

import AdminAction from '../models/AdminAction'
import BlogPost from '../models/BlogPost'
import Calendar from '../models/Calendar'
import Checkin, {MAX_CHECKIN_PER_SESSION} from '../models/Checkin'
import Config from '../models/Config'
import FindMistake from '../models/FindMistake'
import Material from '../models/Material'
import Payment from '../models/Payment'
import Problem from '../models/problem'
import RegisteredUser from '../models/registeredUser'
import Result from '../models/result'
import Submit from '../models/submit'
import SubmitComment from '../models/SubmitComment'
import Table from '../models/table'
import TableResults from '../models/TableResults'
import User from '../models/user'
import UserPrivate from '../models/UserPrivate'

import {addMongooseCallback} from '../mongo/MongooseCallbackManager'

import getTestSystem, {REGISTRY} from '../testSystems/TestSystemRegistry'
import {LoggedCodeforcesUser} from '../testSystems/Codeforces'

import logger from '../log'

import dashboard from './dashboard'
import register from './register'
import setOutcome from './setOutcome'


ensureLoggedIn = connectEnsureLogin.ensureLoggedIn("/api/forbidden")
entities = new Entities()

PASSWORD = process.env["TINKOFF_PASSWORD"]
XSOLLA_MERCHANT_ID = process.env['XSOLLA_MERCHANT_ID']
XSOLLA_PROJECT_ID = process.env['XSOLLA_PROJECT_ID']
XSOLLA_API_KEY = process.env["XSOLLA_API_KEY"]
XSOLLA_SECRET_KEY = process.env["XSOLLA_SECRET_KEY"]
UNITPAY_PUBLIC_KEY = process.env["UNITPAY_PUBLIC_KEY"]
UNITPAY_SECRET_KEY = process.env["UNITPAY_SECRET_KEY"]
UNITPAY_PUBLIC_KEY_ORG = process.env["UNITPAY_PUBLIC_KEY_ORG"]
UNITPAY_SECRET_KEY_ORG = process.env["UNITPAY_SECRET_KEY_ORG"]
EVOCA_LOGIN = process.env["EVOCA_LOGIN"]
EVOCA_PASSWORD = process.env["EVOCA_PASSWORD"]
INVOICE_PASSWORD = process.env["INVOICE_PASSWORD"]
INVOICE_IP_DATA = process.env["INVOICE_IP_DATA"]
INVOICE_IP_SIGNATURE = process.env["INVOICE_IP_SIGNATURE"]

checkAndLogAdminAction = (req, action, userList) ->
    user = req.user
    allowed = if userList then hasCapabilityForUserList(user, action, userList) else hasCapability(user, action)
    if allowed
        action = new AdminAction
            action: action
            userList: userList
            url: req.url
            userId: user.userKey()
            allowed: allowed
        action.upsert()
    return allowed

wrap = (fn) ->
    (args...) ->
        try
            await fn(args...)
        catch error
            args[2](error)

expandSubmit = (submit, lang="") ->
    submit = submit.toObject?() || submit
    MAX_SUBMIT_LENGTH = 100000

    containsBinary = (source) ->
        for ch in source
            if ch.charCodeAt(0) < 9
                return true
        return false

    submit.fullUser = await User.findById(submit.user)
    submit.fullProblem = (await Problem.findById(submit.problem))?.toObject?()
    material = (await Material.findById(submit.problem + lang)) || (await Material.findById(submit.problem))
    submit.fullProblem.name = material.title
    tableNamePromises = []
    for t in submit.fullProblem.tables
        tableNamePromises.push(Table.findById(t))
    tableNames = (await awaitAll(tableNamePromises)).map((table) -> table.name)
    submit.fullProblem.tables = tableNames
    if (submit.source.length > MAX_SUBMIT_LENGTH or containsBinary(submit.source))
        submit.source = ""
        submit.isBinary = true
    return submit

hideTests = (submit) ->
    hideOneTest = (test) ->
        res = {}
        for field in ["string_status", "status", "max_memory_used", "time", "real_time"]
            res[field] = test[field]
        return res

    if submit.results?.tests
        for key, test of submit.results.tests
            submit.results.tests[key] = hideOneTest(test)
    return submit

createSubmit = (problemId, userId, userList, language, codeRaw, draft, findMistake) ->
    logger.info("Creating submit #{userId} #{problemId}")
    codeRaw = iconv.decode(new Buffer(codeRaw), "latin1")
    codeRaw = normalizeCode(codeRaw)
    code = entities.encode(codeRaw)
    if not draft
        allSubmits = await Submit.findByUserAndProblemWithFindMistakeAny(userId, problemId)
        for s in allSubmits
            if s.outcome != "DR" and s.outcome != "PW" and s.source == code
                throw "duplicate"
    problem = await Problem.findById(problemId)
    if not problem
        throw "Unknown problem #{problemId}"
    time = new Date
    timeStr = +time
    submit = new Submit
        _id: "#{userId}r#{timeStr}#{problemId}" ,
        time: time,
        user: userId,
        userList: userList,
        problem: problemId,
        outcome: if draft then "DR" else "PS"
        source: code
        sourceRaw: codeRaw
        language: language
        comments: []
        results: []
        force: false
        testSystemData: problem.testSystemData
        findMistake: findMistake
    await submit.calculateHashes()
    await submit.upsert()

    update = () ->
        dirtyResults = {}
        await setDirty(submit, dirtyResults, {})
        await User.updateUser(submit.user, dirtyResults)
    update()  # do this async
    return undefined

expandFindMistakeResult = (result, admin, userKey, lang="") ->
    mistake = await FindMistake.findById(result.findMistake)
    if not mistake
        return null
    allowed = await mistake.isAllowedForUser(userKey, admin)
    mistake = mistake.toObject()
    mistake.allowed = allowed
    mistake.result = result.toObject()
    if not allowed
        mistake.allowed = false
        mistake.source = ""
    mistake.fullProblem = await Problem.findById(mistake.problem)
    material = (await Material.findById(mistake.problem + lang)) || (await Material.findById(mistake.problem))
    mistake.problemName = material.title
    mistake.hash = sha256(mistake._id).substring(0, 4)
    return mistake

processPayment = (orderId, success, amount, payload, options={}) ->
    {isTest, system} = options
    payment = await Payment.findSuccessfulByOrderId(orderId)
    if payment
        logger.info("paymentNotify #{orderId}: already exists")
        return
    if amount.amount?
        {amount, taxAmount} = amount
    else
        taxAmount = amount
    taxAmount = Math.ceil(taxAmount)
    [userId, paidTillInOrder] = orderId.split(":")

    payment = new Payment
        user: userId
        orderId: orderId
        success: success
        processed: false
        payload: payload
    await payment.upsert()
    if not success
        logger.info("paymentNotify #{orderId}: unsuccessfull")
        return
    user = await User.findById(userId)
    if not user
        logger.warn("paymentNotify #{orderId}: unknown user")
        return

    userPrivate = await UserPrivate.findById(userId)
    payment.oldPaidTill = userPrivate.paidTill
    expectedPaidTill = moment(userPrivate.paidTill).format("YYYYMMDD")
    if expectedPaidTill != paidTillInOrder
        logger.warn("paymentNotify #{orderId}: wrong paid till (current is #{expectedPaidTill}, found #{paidTillInOrder})")
        return
    if amount and Math.abs(+userPrivate.price - amount) > 0.5
        logger.warn("paymentNotify #{orderId}: wrong amount (price is #{userPrivate.price}, paid #{amount})")
        return
    if not userPrivate.paidTill or new Date() - userPrivate.paidTill > 5 * 24 * 60 * 60 * 1000
        newPaidTill = new Date()
    else
        newPaidTill = userPrivate.paidTill
    newPaidTill = moment(newPaidTill).add(1, 'months').startOf('day').toDate()
    userPrivate.paidTill = newPaidTill
    await userPrivate.upsert()
    ###
    if not isTest
        try
            receipt = await addIncome("Оплата занятий на algoprog.ru", taxAmount)
            notify "Добавлен чек (#{orderId}, #{userPrivate.price}р. / #{taxAmount}р.):\n#{user.name}: http://algoprog.ru/user/#{userId}\n" + makeReceiptLink(receipt)
        catch e
            notify "Ошибка добавления чека (#{orderId}, #{userPrivate.price}р. / #{taxAmount}р.):\n#{user.name}: http://algoprog.ru/user/#{userId}\n" + e
            receipt = "---"
    else
        notify "Тестовый чек (#{orderId}, #{userPrivate.price}р. / #{taxAmount}р.):\n#{user.name}: http://algoprog.ru/user/#{userId}\n"
        receipt = "---"
    ###
    if not isTest
        try
            receiptUsn = await addUsnReceipt({service: "Оплата занятий на algoprog.ru", amount: taxAmount, contact: userPrivate.email, orderId: orderId})
            notify "Добавлен чек (#{orderId}, #{userPrivate.price}р. / #{taxAmount}р.):\n#{user.name}: receipt_id=" + receiptUsn
        catch e
            notify "Ошибка добавления чека (#{orderId}, #{userPrivate.price}р. / #{taxAmount}р.):\n#{user.name}: http://algoprog.ru/user/#{userId}\n" + e
            receiptUsn = "---"
    else
        notify "Тестовый чек (#{orderId}, #{userPrivate.price}р. / #{taxAmount}р.):\n#{user.name}: http://algoprog.ru/user/#{userId}\n"
        receiptUsn = "---"
    if not isTest
        notify "Invoice #{system}: http://algoprog.ru/invoice/#{orderId}?password=#{INVOICE_PASSWORD}"
    logger.info("paymentNotify #{orderId}: ok, new paidTill: #{newPaidTill}, receiptUsn: #{receiptUsn}")
    payment.processed = true
    payment.newPaidTill = newPaidTill
    payment.receipt = receipt
    await payment.upsert()

export default setupApi = (app) ->
    app.get '/api/ping', wrap (req, res) ->
        res.send('OK')

    app.get '/api/forbidden', wrap (req, res) ->
        res.status(403).send('No permissions')

    app.post '/api/register', wrap register
    
    app.post '/api/login', passport.authenticate('local'), wrap (req, res) ->
        res.json({logged: true})

    app.get '/api/logout', wrap (req, res) ->
        req.logout()
        res.json({loggedOut: true})

    app.post '/api/submit/:problemId', ensureLoggedIn, wrap (req, res) ->
        userPrivate = (await UserPrivate.findById(req.user.userKey()))?.toObject() || {}
        user = await User.findById(req.user.userKey())
        userObj = user?.toObject() || {}
        if unpaidBlocked({userObj..., userPrivate...})
            res.json({unpaid: true})
            return
        if user.dormant
            res.json({dormant: true})
            return
        try
            await createSubmit(req.params.problemId, req.user.userKey(), user.userList, req.body.language, req.body.code, req.body.draft, req.body.findMistake)
        catch e
            res.json({error: e})
            return
        if req.body.editorOn?
            await user.setEditorOn(req.body.editorOn)
        await user.setLanguage(req.body.language)
        res.json({submit: true})

    app.get '/api/me', ensureLoggedIn, wrap (req, res) ->
        user = JSON.parse(JSON.stringify(req.user))
        res.json user

    app.get '/api/myUser', ensureLoggedIn, wrap (req, res) ->
        id = req.user.informaticsId
        user = (await User.findById(id))?.toObject() || {}
        userPrivate = (await UserPrivate.findById(id))?.toObject() || {}
        memberHasCf = false
        for m in user.members
            member = await RegisteredUser.findByKey(m)
            memberHasCf = memberHasCf or (member.codeforcesUsername?)
        res.json({user..., userPrivate..., memberHasCf})

    app.get '/api/registeredUser/:id', wrap (req, res) ->
        registeredUser = await RegisteredUser.findByKey(req.params.id)
        result = {
            codeforcesUsername: registeredUser?.codeforcesUsername
        }
        res.json(result)

    app.post '/api/user/:id/set', ensureLoggedIn, wrap (req, res) ->
        # can't allow admins as we use req.user.* below
        if ""+req.user?.userKey() != ""+req.params.id
            res.status(403).send('No permissions')
            return
        password = req.body.password
        newPassword = req.body.newPassword
        try
            if newPassword != ""
                logger.info "Set user password", req.user.userKey()
                await req.user.changePassword(password, newPassword)
                await req.user.save()
            else
                if !(await req.user.authenticate(password)).user
                    throw err
        catch e
            res.json({passError:true})
            return
        registeredUsers = await RegisteredUser.findAllByKey(req.params.id)
        newInformaticsPassword = req.body.informaticsPassword
        informaticsUsername = req.user.informaticsUsername
        if newInformaticsPassword != ""
            try
                userq = await InformaticsUser.getUser(informaticsUsername, newInformaticsPassword)
                result = await userq.getData()
                if not ("name" of result)
                    throw "Can't find name"
                for registeredUser in registeredUsers
                        await registeredUser.updateInformaticPassword(newInformaticsPassword)
            catch
                # TODO: return error to user
        cfLogin = req.body.cf.login
        if cfLogin == ""
            cfLogin = undefined
        newName = req.body.newName
        user = await User.findById(req.params.id)
        await user.setCfLogin cfLogin
        if(req.body.clas !='' and req.body.clas!=null)
            await user.setGraduateYear getGraduateYear(+req.body.clas)
        else
            await user.setGraduateYear(undefined)
        await user.updateName newName
        if req.body.telegram
            await user.setTelegram req.body.telegram
        if req.body.codeforcesPassword
            cfUser = await LoggedCodeforcesUser.getUser(req.body.codeforcesUsername, req.body.codeforcesPassword)
            for registeredUser in registeredUsers
                    await registeredUser.setCodeforces(cfUser.handle, req.body.codeforcesPassword)
        if not req.body.codeforcesUsername
            req.user.setCodeforces(undefined, undefined)
        await User.updateUser(user._id, {})
        res.send('OK')

    app.post '/api/user/:id/setAdmin', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.id)
        if not checkAndLogAdminAction(req, EDIT_USER, user?.userList)
            res.status(403).send('No permissions')
            return
        cfLogin = req.body.cf.login
        if cfLogin == ""
            cfLogin = undefined
        paidTill = new Date(req.body.paidTill)
        if isNaN(paidTill)
            paidTill = undefined
        price = req.body.price
        if price == ""
            price = undefined
        else
            price = +price
        password = req.body.password
        achieves = if req.body.achieves.length then req.body.achieves.split(" ") else []
        members = if req.body.members.length then req.body.members.split(" ") else []
        registeredUsers = await RegisteredUser.findAllByKey(req.params.id)
        await user.updateName(await User.makeTeamName(req.body.name, members))
        await user.setGraduateYear req.body.graduateYear
        await user.setBaseLevel req.body.level.base
        await user.setCfLogin cfLogin
        await user.setAchieves achieves
        await user.setMembers members
        userPrivate = await UserPrivate.findById(req.params.id)
        if not userPrivate
            userPrivate = new UserPrivate({_id: req.params.id})
            await userPrivate.upsert()
            userPrivate = await UserPrivate.findById(req.params.id)
        await userPrivate.setPaidTill paidTill
        await userPrivate.setPrice price
        if password != ""
            for registeredUser in registeredUsers
                logger.info "Set user password", registeredUser.userKey()
                await registeredUser.setPassword(password)
                await registeredUser.save()
        await User.updateUser(user._id, {})
        res.send('OK')

    app.post '/api/user/:id/setChocosGot', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.id)
        if not checkAndLogAdminAction(req, EDIT_USER, user?.userList)
            res.status(403).send('No permissions')
            return
        chocosGot = req.body.chocosGot
        await user.setChocosGot chocosGot
        res.send('OK')

    app.post '/api/user/:id/setTShirtsGot', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.id)
        if not checkAndLogAdminAction(req, EDIT_USER, user?.userList)
            res.status(403).send('No permissions')
            return
        cnt = req.body.TShirts
        user = await User.findById(req.params.id)
        await user.setTShirtsGot cnt
        res.send('OK')

    app.get '/api/user/:id', wrap (req, res) ->
        id = req.params.id
        user = (await User.findById(id))?.toObject() || {}
        userPrivate = {}
        if checkAndLogAdminAction(req, EDIT_USER, user?.userList) or ""+req.user?.userKey() == ""+req.params.id
            userPrivate = (await UserPrivate.findById(id))?.toObject() || {}
        res.json({user..., userPrivate...})

    app.get '/api/dashboard', wrap (req, res) ->
        res.json(await dashboard(req.user))

    app.get '/api/table/:userList/:table', wrap (req, res) ->
        sortBySolved = (a, b) ->
            if a.user.active != b.user.active
                return if a.user.active then -1 else 1
            if a.total.solved != b.total.solved
                return b.total.solved - a.total.solved
            if a.total.attempts != b.total.attempts
                return a.total.attempts - b.total.attempts
            return 0

        sortByLevelAndRating = (a, b) ->
            return User.sortByLevelAndRating(a.user, b.user)

        userList = req.params.userList
        table = req.params.table
        data = []
        users = await User.findByList(userList)
        tables = await getTables(table)
        #[users, tables] = await awaitAll([users, tables])
        getTableResults = (user, tableName, tables) ->
            sumTable = await TableResults.findByUserAndTable(user._id, tableName)
            if sumTable
                return
                    results: sumTable?.data?.results
                    total : sumTable?.data?.total
            else
                return getUserResult(user._id, tables, 1)
        for user in users
            data.push getTableResults user, table, tables
        results = await awaitAll(data)
        results = ({r..., user: users[i]} for r, i in results when r)
        results = results.sort(if table == "main" then sortByLevelAndRating else sortBySolved)
        res.json(results)

    app.get '/api/fullUser/:id', wrap (req, res) ->
        userId = req.params.id
        tables = []
        for t in allTables when t != 'main'
          tables.push(getTables(t))
        tables = await awaitAll(tables)

        user = await User.findById(userId)
        calendar = await Calendar.findById(userId)
        if not user
            return null
        results = []
        for t in tables
            results.push(getUserResult(user._id, t, 1))
        results = await awaitAll(results)
        results = (r.results for r in results when r)
        result =
            user: user.toObject()
            results: results
            calendar: calendar?.toObject()

        userPrivate = {}
        tg = {}
        if checkAndLogAdminAction(req, EDIT_USER, user?.userList) or ""+req.user?.userKey() == ""+userId
            userPrivate = (await UserPrivate.findById(userId))?.toObject() || {}
            tg = (await User.findTelegram(userId))?.toObject() || {}
        result.user = {result.user..., userPrivate..., tg...}
        res.json(result)

    app.get '/api/users/:userList', wrap (req, res) ->
        res.json(await User.findByList(req.params.userList))

    app.get '/api/users/withAchieve/:achieve', wrap (req, res) ->
        achieve = req.params.achieve
        if not (achieve of ACHIEVES)
            res.status(400).send('Unknown achieve')
            return
        users = await User.findByAchieve(achieve)
        res.json(users)

    app.post '/api/searchUser', ensureLoggedIn, wrap (req, res) ->
        addUserName = (user) ->
            fullUser = await User.findById(user.informaticsId)
            user.fullName = fullUser?.name
            user.registerDate = fullUser?.registerDate
            user.userList = fullUser?.userList
            user.dormant = fullUser?.dormant
            user.activated = fullUser?.activated

        if not checkAndLogAdminAction(req, SEARCH_USERS)
            res.status(403).send('No permissions')
            return
        promises = []
        result = []
        users = []
        for user in await User.search(req.body.searchString)
            user = user.toObject()
            users = users.concat(await RegisteredUser.findAllByKey(user._id))
        registeredUsers = await RegisteredUser.search(req.body.searchString)
        users = users.concat(registeredUsers)
        for user in users
            user = user.toObject()
            promises.push(addUserName(user))
            result.push(user)
        await awaitAll(promises)
        result.sort((a, b) -> (a.registerDate || new Date(0)) - (b.registerDate || new Date(0)))
        res.json(result)

    app.get '/api/registeredUsers', ensureLoggedIn, wrap (req, res) ->
        addUserName = (user) ->
            fullUser = await User.findById(user.informaticsId)
            user.fullName = fullUser?.name
            user.dormant = fullUser?.dormant
            user.registerDate = fullUser?.registerDate
            user.userList = fullUser?.userList
            user.dormant = fullUser?.dormant
            user.activated = fullUser?.activated

        if not checkAndLogAdminAction(req, SEARCH_USERS)
            res.status(403).send('No permissions')
            return
        result = []
        promises = []
        for user in await RegisteredUser.find({})
            user = user.toObject()
            delete user.informaticsPassword
            promises.push(addUserName(user))
            result.push(user)
        await awaitAll(promises)
        result = result.filter((user) -> (not user.dormant) and (user.registerDate > new Date() - 1000 * 60 * 60 * 24 * 100))
        result.sort((a, b) -> (a.registerDate || new Date(0)) - (b.registerDate || new Date(0)))
        res.json(result)

    app.get '/api/submits/:user/:problem', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, VIEW_SUBMITS, user.userList)
        if not admin and ""+req.user?.userKey() != ""+req.params.user
            res.status(403).send('No permissions')
            return
        submits = await Submit.findByUserAndProblem(req.params.user, req.params.problem)
        submits = submits.map((submit) -> submit.toObject())
        if not admin
            submits = submits.map(hideTests)
        submits = submits.map((s) -> expandSubmit(s))
        submits = await awaitAll(submits)
        res.json(submits)

    app.ws '/wsapi/submits/:user/:problem', (ws, req, next) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, VIEW_SUBMITS, user.userList)
        addMongooseCallback ws, 'update_submit', req.user?.userKey(), ->
            if not admin and ""+req.user?.userKey() != ""+req.params.user
                return
            submits = await Submit.findByUserAndProblem(req.params.user, req.params.problem)
            submits = submits.map((submit) -> submit.toObject())
            if not admin
                submits = submits.map(hideTests)
            submits = submits.map((s) -> expandSubmit(s))
            submits = await awaitAll(submits)
            ws.send JSON.stringify submits

    app.get '/api/submitsForFindMistake/:user/:findMistake', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, SEE_FIND_MISTAKES, user.userList)
        if not admin and ""+req.user?.userKey() != ""+req.params.user
            res.status(403).send('No permissions')
            return
        fm = await FindMistake.findById(req.params.findMistake)
        allowed = false
        if admin 
            allowed = true
        else 
            result = await Result.findByUserAndTable(req.params.user, fm.problem)
            allowed = result && result.solved > 0
        if not allowed
            res.status(403).send('No permissions')
            return
        submits = await Submit.findByUserAndFindMistake(req.params.user, req.params.findMistake)
        submit0 = (await Submit.findById(fm.submit)).toObject()
        submit0 =
            _id: submit0._id
            time: "_orig"
            problem: submit0.problem
            outcome: submit0.outcome
            source: submit0.source
            sourceRaw: submit0.sourceRaw
            language: submit0.language
            comments: []
            results: submit0.results
        submits = submits.map((submit) -> submit.toObject())
        submits.splice(0, 0, submit0)
        if not admin
            submits = submits.map(hideTests)
        submits = submits.map((s) -> expandSubmit(s))
        submits = await awaitAll(submits)
        res.json(submits)

    app.ws '/wsapi/submitsForFindMistake/:user/:findMistake', (ws, req, next) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, SEE_FIND_MISTAKES, user.userList)
        addMongooseCallback ws, 'update_submit', req.user?.userKey(), ->
            if not admin and ""+req.user?.userKey() != ""+req.params.user
                return
            fm = await FindMistake.findById(req.params.findMistake)
            allowed = false
            if admin 
                allowed = true
            else 
                result = await Result.findByUserAndTable(req.params.user, fm.problem)
                allowed = result && result.solved > 0
            if not allowed
                return
            submits = await Submit.findByUserAndFindMistake(req.params.user, req.params.findMistake)
            submit0 = (await Submit.findById(fm.submit)).toObject()
            submit0 =
                _id: submit0._id
                time: "_orig"
                problem: submit0.problem
                outcome: submit0.outcome
                source: submit0.source
                sourceRaw: submit0.sourceRaw
                language: submit0.language
                comments: []
                results: submit0.results
            submits = submits.map((submit) -> submit.toObject())
            submits.splice(0, 0, submit0)
            if not admin
                submits = submits.map(hideTests)
            submits = submits.map((s) -> expandSubmit(s))
            submits = await awaitAll(submits)
            ws.send JSON.stringify(submits)

    app.get '/api/submitsByDay/:user/:day', wrap (req, res) ->
        submits = await Submit.findByUserAndDayWithFindMistakeAny(req.params.user, req.params?.day)
        lang = req.query.lang || ""
        submits = submits.map((submit) -> submit.toObject())
        submits = submits.map(hideTests)
        submits = submits.map((s) -> expandSubmit(s, lang))
        submits = await awaitAll(submits)
        submits = submits.map((submit) ->
              _id: submit._id
              problem: submit.problem
              user: submit.user
              time: submit.time
              outcome: submit.outcome
              language: submit.language
              fullProblem: submit.fullProblem
        )
        res.json(submits)

    app.get '/api/material/:id', wrap (req, res) ->
        material = await Material.findById(req.params.id)
        if not material
            material = new Material
                content: "<h1>404 Not found</h1>Unknown material"
                type: "page"
        res.json(material)

    app.get '/api/lastBlogPosts', wrap (req, res) ->
        res.json(await BlogPost.findLast(5))

    app.get '/api/result/:id', wrap (req, res) ->
        result = (await Result.findById(req.params.id))?.toObject()
        if not result
            res.json({})
            return
        result.fullUser = await User.findById(result.user)
        result.fullTable = await Problem.findById(result.table)
        res.json(result)

    app.ws '/wsapi/result/:id', (ws, req, next) ->
        addMongooseCallback ws, 'update_result', req.user?.userKey(), ->
            result = (await Result.findById(req.params.id))?.toObject()
            if not result then return
            result.fullUser = await User.findById(result.user)
            result.fullTable = await Problem.findById(result.table)
            ws.send JSON.stringify result

    app.get '/api/userResults/:userId', wrap (req, res) ->
        results = (await Result.findByUser(req.params.userId))
        json = {}
        for r in results
            r = r.toObject()
            json[r._id] = r
        res.json(json)

    app.get '/api/submit/:id', ensureLoggedIn, wrap (req, res) ->
        res.status(404).send("Not found")
        return

    app.get '/api/similarSubmits/:id', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, SEE_SIMILAR_SUBMITS)
            res.status(403).send('No permissions')
            return
        submit = (await Submit.findById(req.params.id)).toObject()
        similar = await findSimilarSubmits(submit, 5)
        similar = similar.map((submit) -> submit.toObject())
        similar = similar.map((s) -> expandSubmit(s))
        similar = await awaitAll(similar)
        similar = similar.map (submit) ->
            return
                _id: submit._id
                time: submit.time
                user: submit.user
                problem: submit.problem
                source: submit.source
                sourceRaw: submit.sourceRaw
                fullUser: submit.fullUser
                fullProblem: submit.fullProblem
                outcome: submit.outcome
                language: submit.language
        res.json(similar)

    app.get '/api/submitSource/:id', ensureLoggedIn, wrap (req, res) ->
        submit = await Submit.findById(req.params.id)
        user = await User.findById(submit.user)
        admin = checkAndLogAdminAction(req, VIEW_SUBMITS, user.userList)
        if not admin and ""+req.user?.userKey() != ""+submit.user
            if submit.quality == 0
                res.status(403).send('No permissions')
                return
            result = await Result.findByUserAndTable(req.user?.userKey(), submit.problem)
            if not result or result.solved <= 0
                res.status(403).send('No permissions')
                return
        source = submit.sourceRaw || entities.decode(submit.source)
        mimeType = FileType.fromBuffer(Buffer.from(source))?.mime || "text/plain"
        res.contentType(mimeType)
        res.send(source)

    app.get '/api/lastComments', ensureLoggedIn, wrap (req, res) ->
        if not req.user?.userKey()
            res.status(403).send('No permissions')
            return
        res.json(await SubmitComment.findLastNotViewedByUser(req.user?.userKey()))

    app.get '/api/comments/:page', ensureLoggedIn, wrap (req, res) ->
        if not req.user?.userKey()
            res.status(403).send('No permissions')
            return
        page = req.params.page
        res.json(await SubmitComment.findByUserAndPage(req.user?.userKey(), page))

    app.get '/api/commentPages', ensureLoggedIn, wrap (req, res) ->
        if not req.user?.userKey()
            res.status(403).send('No permissions')
            return
        res.json(await SubmitComment.findPagesCountByUser(req.user?.userKey()))

    app.get '/api/lastCommentsByProblem/:problem', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, SEE_LAST_COMMENTS)
            res.status(403).send('No permissions')
            return
        res.json(await SubmitComment.findLastByProblem(req.params.problem))

    app.get '/api/bestSubmits/:problem', ensureLoggedIn, wrap (req, res) ->
        allowed = false
        if checkAndLogAdminAction(req, SEE_BEST_SUBMITS)
            allowed = true
        else if req.user?.userKey()
            result = await Result.findByUserAndTable(req.user?.userKey(), req.params.problem)
            allowed = result && result.solved > 0
        if not allowed
            res.status(403).send('No permissions')
            return
        res.json(await Submit.findBestByProblem(req.params.problem, 5))

    app.post '/api/setOutcome/:submitId', ensureLoggedIn, wrap (req, res) ->
        submit = await Submit.findById(req.params.submitId)
        user = await User.findById(submit.user)
        if not checkAndLogAdminAction(req, REVIEW, user.userList)
            res.status(403).send('No permissions')
            return
        await setOutcome(req, res)
        res.send('OK')

    app.post '/api/setQuality/:submitId/:quality', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, ADD_BEST_SUBMITS)
            res.status(403).send('No permissions')
            return
        submit = await Submit.findById(req.params.submitId)
        if not submit
            res.status(404).send('Submit not found')
            return
        submit.quality = req.params.quality
        await submit.save()
        res.send('OK')

    app.post '/api/setLang/:lang', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.user.userKey())
        
        await user.setInterfaceLanguage(req.params.lang)
        res.send('OK')

    app.post '/api/setCommentViewed/:commentId', ensureLoggedIn, wrap (req, res) ->
        comment = await SubmitComment.findById(req.params.commentId)
        if ""+req.user?.userKey() != "" + comment?.userId
            res.status(403).send('No permissions')
            return
        comment.viewed = true
        await comment.save()
        res.send('OK')

    app.get '/api/checkins', wrap (req, res) ->
        checkins = (
            { 
                checkins: await Checkin.findBySession(i)
                max: MAX_CHECKIN_PER_SESSION[i]
            } for i in [0..1])
        for sessionCheckins in checkins
            sessionCheckins.checkins = await awaitAll(sessionCheckins.checkins.map((checkin) ->
                checkin = checkin.toObject()
                checkin.fullUser = await User.findById(checkin.user)
                return checkin
            ))
        result = {
            checkins: checkins
            date: await Config.get("checkinDate")
        }
        res.json(result)

    app.post '/api/checkin/:user', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, CHECKINS) and ""+req.user?.informaticsId != ""+req.params.user
            res.status(403).json({error: 'No permissions'})
            return
        session = req.body.session
        if session?
            session = +session
        user = ""+req.params.user
        logger.info "User #{user} checkin for session #{session}"
        if (session? and session != 0 and session != 1)
            res.status(400).json({error: "Strange session"})
            return
        if session?
            sessionCheckins = await Checkin.findBySession(session)
            if sessionCheckins.length >= MAX_CHECKIN_PER_SESSION[session]        
                res.status(403).json({error: "Нет мест"})
                return
        userCheckins = await Checkin.findByUser(user)
        for checkin in userCheckins
            await checkin.markDeleted()
        if session?
            checkin = new Checkin
                user: user
                session: session
            await checkin.upsert()
        res.json({ok: "OK"})

    app.post '/api/resetCheckins', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, CHECKINS)
            res.status(403).json({error: 'No permissions'})
            return
        date = new Date(req.body.date)
        logger.info "Reset checkins to date #{date}"
        oldCheckins = await Checkin.findNotDeleted()
        for checkin in oldCheckins
            await checkin.markDeleted()
        await Config.set("checkinDate", date)
        res.json({ok: "OK"})

    app.get '/api/recentReceipt/:user', wrap (req, res) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, VIEW_RECEIPT, user.userList)
        if not admin and ""+req.user?.informaticsId != ""+req.params.user
            res.status(403).json({error: 'No permissions'})
            return
        for i in [1..10]
            payment = await Payment.findLastReceiptByUserId(req.params.user)
            if payment and new Date() - payment.time < 24 * 60 * 60 * 1000
                res.json({receipt: makeReceiptLink(payment.receipt)})
                return
            await sleep(1000)
        res.json({})

    app.post '/api/moveUserToGroup/:userId/:groupName', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.userId)
        admin = checkAndLogAdminAction(req, MOVE_USER, user.userList) || (user.userList == "unknown" && checkAndLogAdminAction(req, MOVE_UNKNOWN_USER))
        if not admin
            res.status(403).send('No permissions')
            return
        if not user
            res.status(400).send("User not found")
            return
        newGroup = req.params.groupName
        if newGroup != "none"
            await user.setUserList(newGroup)
        res.send('OK')

    app.post '/api/forceSetUserList/:userId/:groupName', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.userId)
        admin = checkAndLogAdminAction(req, MOVE_USER, user.userList) || (user.userList == "unknown" && checkAndLogAdminAction(req, MOVE_UNKNOWN_USER))
        if not admin
            res.status(403).send('No permissions')
            return
        if not user
            res.status(400).send("User not found")
            return
        newGroup = req.params.groupName
        if newGroup != "none"
            await user.forceSetUserList(newGroup)
        res.send('OK')

    app.post '/api/setDormant/:userId', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.userId)
        if not checkAndLogAdminAction(req, SET_DORMANT, user.userList)
            res.status(403).send('No permissions')
            return
        if not user
            res.status(400).send("User not found")
            return
        await user.setDormant(true)
        res.send('OK')

    app.post '/api/setActivated/:userId', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.userId)
        if not checkAndLogAdminAction(req, ACTIVATE, user.userList)
            res.status(403).send('No permissions')
            return
        if not user
            res.status(400).send("User not found")
            return
        await user.setActivated(req.body?.value)
        if req.body?.value then await user.setDormant(false)
        res.send('OK')

    app.post '/api/editMaterial/:id', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, EDIT_PAGE)
            res.status(403).send('No permissions')
            return
        material = await Material.findById(req.params.id)
        logger.info("Updating material #{material._id}")
        material.content = req.body.content
        material.title = req.body.title
        material.force = true
        await material.upsert()
        res.send('OK')

    app.post '/api/translateProblems', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, EDIT_PAGE)
            res.status(403).send('No permissions')
            return
        translateProblems()
        res.send('OK')

    app.post '/api/translate', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, TRANSLATE)
            res.status(403).send('No permissions')
            return
        text = req.body.text
        result = (await translate([text]))[0]
        res.json({text: result})

    app.post '/api/resetYear', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, RESET_YEAR)
            res.status(403).send('No permissions')
            return

        runForUser = (user) ->
            userPrivate = await UserPrivate.findById(user._id)
            registeredUser = await RegisteredUser.findByKey(user._id)
            if registeredUser.admin or (not GROUPS[user.userList]?.canResetYear and userPrivate.paidTill > new Date())
                logger.info("Will not move user #{user._id} to unknown group")
                return
            await user.setActivated(false)
            logger.info("Deactivate user #{user._id}")

        users = await User.findAll()
        for user in users
            runForUser(user)
        res.send('OK')

    app.get '/api/updateResults/:user', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.userId)
        if not checkAndLogAdminAction(req, REVIEW, user.userList)
            res.status(403).send('No permissions')
            return
        await User.updateUser(req.params.user)
        res.send('OK')

    app.get '/api/updateAllResults', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, UPDATE_ALL)
            res.status(403).send('No permissions')
            return
        User.updateAllUsers()
        res.send('OK')

    app.get '/api/updateAllAllResults', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, UPDATE_ALL)
            res.status(403).send('No permissions')
            return
        User.updateAllUsers(undefined, true)
        res.send('OK')

    app.get '/api/updateAllCf', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, UPDATE_ALL)
            res.status(403).send('No permissions')
            return
        User.updateAllCf()
        res.send('OK')

    app.get '/api/updateAllGraduateYears', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, UPDATE_ALL)
            res.status(403).send('No permissions')
            return
        User.updateAllGraduateYears()
        res.send('OK')

    app.get '/api/randomizeEjudgePasswords', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, UPDATE_ALL)
            res.status(403).send('No permissions')
            return
        User.randomizeEjudgePasswords()
        res.send('OK')

    app.get '/api/downloadSubmits/:user', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.user)
        if not checkAndLogAdminAction(req, REVIEW, user.userList)
            res.status(403).send('No permissions')
            return
        await downloadSubmits.runForUser(req.params.user, 100, 1e9)
        res.send('OK')

    app.get '/api/downloadSubmitsForUserAndProblem/:user/:problem', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.user)
        if not checkAndLogAdminAction(req, REVIEW, user.userList)
            res.status(403).send('No permissions')
            return
        await downloadSubmits.runForUserAndProblem(req.params.user, req.params.problem, undefined, true)
        res.send('OK')

    ###
    app.get '/api/calculateAllHashes', ensureLoggedIn, wrap (req, res) ->
        if not req.user?.admin
            res.status(403).send('No permissions')
            return
        Submit.calculateAllHashes()
        res.send('OK')
    ###

    app.get '/api/createTeam', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, CREATE_TEAM)
            res.status(403).send('No permissions')
            return
        logger.info("Try create new user user", username)
        username = -Math.random().toString().substr(2)
        password = Math.random().toString(36).substr(2)

        logger.info "Register new Table User", username
        newUser = new User(
            _id: username
            name: "???"
            graduateYear: null
            userList: "team",
            activated: true,
            lastActivated: new Date()
            registerDate: new Date()
        )
        await newUser.upsert()
        await newUser.updateLevel()
        await newUser.updateRatingEtc()

        # do not await, this can happen asynchronously
        for _, system of REGISTRY
            system.registerUser(newUser)

        newRegisteredUser = new RegisteredUser({
            username,
            informaticsId: username,
            informaticsUsername: null,
            informaticsPassword: null,
            aboutme: "",
            promo: "",
            contact: "",
            whereFrom: ""
            admin: false
        })
        RegisteredUser.register newRegisteredUser, password, (err) ->
            if (err)
                logger.error("Cant register user", err)
                res.json
                    registered:
                        error: true
                        message: if err.name == "UserExistsError" then "Пользователь с таким логином уже сущестует" else "Неопознанная ошибка"
            else
                logger.info("Registered user")
                res.redirect("/user/#{username}")

    app.post '/api/informatics/userData', wrap (req, res) ->
        username = req.body.username
        password = req.body.password
        user = await InformaticsUser.getUser(username, password)
        result = await user.getData()
        res.json(result)

    app.post '/api/codeforces/userData', wrap (req, res) ->
        username = req.body.username
        password = req.body.password
        try
            user = await LoggedCodeforcesUser.getUser(username, password)
            res.json({status: true})
        catch
            res.json({status: false})

    app.get '/api/findMistakePages/:user', wrap (req, res) ->
        user = await User.findById(req.params.user)
        if not checkAndLogAdminAction(req, SEE_FIND_MISTAKES, user.userList) and ""+req.user?.informaticsId != ""+req.params.user
            res.status(403).json({error: 'No permissions'})
            return
        user = req.params.user
        res.json(await Result.findPagesCountByUserWithFindMistakeSet(user))

    app.get '/api/findMistakeList/:user/:page', wrap (req, res) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, SEE_FIND_MISTAKES, user.userList)
        if not admin and ""+req.user?.informaticsId != ""+req.params.user
            res.status(403).json({error: 'No permissions'})
            return
        user = req.params.user
        order = req.query.order
        lang = req.query.lang || ""
        mistakes = await Result.findPageByUserWithFindMistakeSet(user, req.params.page, order)
        mistakes = mistakes.map (mistake) -> 
            expandFindMistakeResult(mistake, admin, user, lang)
        mistakes = await awaitAll(mistakes)
        mistakes = (m for m in mistakes when m)
        res.json(mistakes)

    app.get '/api/findMistakeProblemPages/:user/:problem', ensureLoggedIn, wrap (req, res) ->
        if not req.user?.userKey()
            res.status(403).send('No permissions')
            return
        user = req.params.user
        res.json(await Result.findPagesCountByUserAndTableWithFindMistakeSet(req.params.user, req.params.problem))

    app.get '/api/findMistakeProblemList/:user/:problem/:page', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, SEE_FIND_MISTAKES, user.userList)
        if not admin and ""+req.user?.informaticsId != ""+req.params.user
            res.status(403).json({error: 'No permissions'})
            return
        user = req.params.user
        lang = req.query.lang || ""
        mistakes = await Result.findPageByUserAndTableWithFindMistakeSet(req.params.user, req.params.problem, req.params.page)
        mistakes = mistakes.map (mistake) -> 
            expandFindMistakeResult(mistake, admin, req.params.user, lang)
        mistakes = await awaitAll(mistakes)
        mistakes = (m for m in mistakes when m)
        res.json(mistakes)

    app.get '/api/findMistake/:id/:user', ensureLoggedIn, wrap (req, res) ->
        user = await User.findById(req.params.user)
        admin = checkAndLogAdminAction(req, SEE_FIND_MISTAKES, user.userList)
        if not admin and ""+req.user?.informaticsId != ""+req.params.user
            res.status(403).json({error: 'No permissions'})
            return
        user = req.params.user
        lang = req.query.lang || ""
        mistake = await Result.findByUserAndFindMistake(user, req.params.id)
        mistake = await expandFindMistakeResult(mistake, admin, user, lang)
        res.json(mistake)

    app.get '/api/downloadingStats', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, DOWNLOADING_STATS)
            res.status(403).send('No permissions')
            return
        stats = getStats()
        stats.ip = JSON.parse(await download 'https://api.ipify.org/?format=json')["ip"]
        res.json(stats)

    app.get '/api/approveFindMistake', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, APPROVE_FIND_MISTAKE)
            res.status(403).send('No permissions')
            return
        while true
            mistake = (await FindMistake.findOneNotApproved())[0]
            if not mistake
                res.json({})
                return
            submits = [await Submit.findById(mistake.submit), await Submit.findById(mistake.correctSubmit)]
            if not submits[0] || not submits[1]
                console.log "Bad findmistake ", mistake._id, mistake.submit, mistake.correctSubmit
                await mistake.setBad()
                continue
            submits = submits.map((s) -> expandSubmit(s))
            submits = await awaitAll(submits)
            count = await FindMistake.findNotApprovedCount()
            res.json({mistake, submits, count})
            return

    app.post '/api/setApproveFindMistake/:id', ensureLoggedIn, wrap (req, res) ->
        if not checkAndLogAdminAction(req, APPROVE_FIND_MISTAKE)
            res.status(403).send('No permissions')
            return
        approve = req.body.approve
        mistake = await FindMistake.findById(req.params.id)
        await mistake.setApprove(approve)
        res.send('OK')

    app.get '/api/markUsers', ensureLoggedIn, wrap (req, res) ->
        url = req.query.url
        if not req.user?.admin
            res.status(403).send('No permissions')
            return
        text = await download url    
        store = createStore({lang: "ru"})
        users = await User.find({})
        for user in users
            console.log(user.name, user._id)
            if user.name.length <= 4
                continue
            name = user.name.replaceAll("е", "[е`]").replaceAll("ё", "[е`]").replaceAll("`","ё").replaceAll("?", "\\?").replaceAll("(", "\\(").replaceAll(")", "\\)")
            name1 = name
            name2 = name.split(' ').reverse().join(' ')
            console.log(name1, name2)
            re = XRegExp("(^|[^\\p{L}])((#{name1})|(#{name2}))($|[^\\p{L}])", "iug")
            context = {}
            el = <Provider store={store}><StaticRouter context={context}><UserNameRaw user={user} theme={"light"}/></StaticRouter></Provider>
            html = renderToString(el)
            html = html.replace("/user/", "https://algoprog.ru/user/")
            text = text.replace(re, "$1#{html}$5")
        # assume that if page contains <head>, then it is html
        text = text.replace("<head>", '<head><link rel="stylesheet" href="https://algoprog.ru/bundle.css"/><base href="' + url + '"/>')
        res.send(text)

    app.post '/api/tinkoffPrePayment', wrap (req, res) ->
        if not req.user
            res.status(403).send('No permissions')
            return
        userId = req.user.userKey()
        userPrivate = await UserPrivate.findById(userId)
        userPrivate.setEmail(req.body.email)
        res.json({})

    app.post '/api/xsollaToken', wrap (req, res) ->
        if not req.user
            res.status(403).send('No permissions')
            return
        order = req.body.order
        name = req.body.name
        email = req.body.email
        address = req.body.address
        userId = req.user.userKey()
        userPrivate = await UserPrivate.findById(userId)
        if not userPrivate?.price
            res.status(403).send('No price set')
            return
        url = "https://api.xsolla.com/merchant/v2/merchants/#{XSOLLA_MERCHANT_ID}/token"
        data =
            user:
                id: 
                    value: ""+req.user.userKey()
                email:
                    value: email
                name:
                    value: name
                attributes:
                    address: address
            settings:
                project_id: +XSOLLA_PROJECT_ID
                mode: "sandbox"
                external_id: order
            purchase:
                checkout:
                    amount: userPrivate.price
                    currency: "RUB"
                description:
                    value: "Payment for access to algoprog.ru for one month"
        try
            result = await download(url, undefined, {
                json: data
                method: 'POST'
                headers:
                    'Content-Type': 'application/json',
                    Authorization: 'Basic ' + Buffer.from("#{XSOLLA_MERCHANT_ID}:#{XSOLLA_API_KEY}").toString('base64')
            })
        catch e
            throw "Can't download xsolla api"
        res.json({token: result.token})

    app.post '/api/unitpaySignature', wrap (req, res) ->
        if not req.user
            res.status(403).send('No permissions')
            return
        order = req.body.order
        name = req.body.name
        email = req.body.email
        address = req.body.address
        userId = req.user.userKey()
        userPrivate = await UserPrivate.findById(userId)
        if not userPrivate?.price
            res.status(403).send('No price set')
            return
        currency = 'RUB'
        fee = 0.1
        desc = req.body.desc
        sum = Math.floor(userPrivate.price * (1 + fee))
        is_org = req.host.endsWith(".org")
        if UNITPAY_PUBLIC_KEY_ORG && is_org
            logger.info("Payment form opened on org domain")
            publicKey = UNITPAY_PUBLIC_KEY_ORG
            secretKey = UNITPAY_SECRET_KEY_ORG
        else
            logger.info("Payment form opened on ru domain")
            publicKey = UNITPAY_PUBLIC_KEY
            secretKey = UNITPAY_SECRET_KEY
        hashStr = "#{order}{up}#{currency}{up}#{desc}{up}#{sum}{up}#{secretKey}"
        res.json
            signature: sha256(hashStr)
            desc: desc
            order: order
            currency: currency
            sum: sum
            publicKey: publicKey
            is_org: is_org

    app.get '/api/evocaPreData', wrap (req, res) ->
        if not req.user
            res.status(403).send('No permissions')
            return
        userId = req.user.userKey()
        userPrivate = await UserPrivate.findById(userId)
        if not userPrivate?.price
            res.status(403).send('No price set')
            return
        currency = "AMD"
        try
            amdToRub = await getCbRfRate(currency)
        catch e
            notify "Can't download cbrf rates", e
            throw e
        amountRub = userPrivate.price || 2000
        fee = 0.1
        sum = Math.floor(amountRub / amdToRub * (1 + fee))
        res.json
            amount: sum
            currency: currency
            amountRub: amountRub

    app.post '/api/evocaData', wrap (req, res) ->
        if not req.user
            res.status(403).send('No permissions')
            return
        order = req.body.order + ":" + Math.random().toString(36).substr(2, 4)
        name = req.body.name
        email = req.body.email
        address = req.body.address
        desc = req.body.desc
        userId = req.user.userKey()
        userPrivate = await UserPrivate.findById(userId)
        if not userPrivate?.price
            res.status(403).send('No price set')
            return
        currency = "AMD"
        try
            amdToRub = await getCbRfRate(currency)
        catch e
            notify "Can't download cbrf rates", e
            throw e
        fee = 0.1
        desc = req.body.desc
        sum = Math.floor(userPrivate.price / amdToRub * 100 * (1 + fee))
        returnUrl = encodeURIComponent("#{req.protocol}://#{req.get('host')}/evocaPaymentSuccess")
        req.user.setPaymentEmail(email)    
        jsonParams = encodeURIComponent(JSON.stringify({email, address}))
        url = "https://ipay.arca.am/payment/rest/register.do?userName=#{EVOCA_LOGIN}&password=#{EVOCA_PASSWORD}&orderNumber=#{order}&amount=#{sum}&description=#{desc}&returnUrl=#{returnUrl}&jsonParams=#{jsonParams}"
        result = JSON.parse(await download(url))
        logger.info "Evoca register request answer", result, result.errorCode
        if result.errorCode == 1
            url = "https://ipay.arca.am/payment/rest/getOrderStatusExtended.do?userName=#{EVOCA_LOGIN}&password=#{EVOCA_PASSWORD}&orderNumber=#{order}"
            result = JSON.parse(await download(url))
            console.log "Evoca getOrderStatusExtended answer", result
        res.json
            formUrl: result.formUrl

    app.post '/xsollaHook', bodyParser.raw({type: "*/*"}), wrap (req, res) ->
        hash = sha1(req.body.toString() + XSOLLA_SECRET_KEY)
        signature = req.get("Authorization")
        if signature != "Signature " + hash
            logger.error("xsollaHook: wrong hash")
            res.status(400).json
                error:
                    code: "INVALID_SIGNATURE",
                    message: "Invalid signature"
            return
        data = JSON.parse(req.body)
        if data.notification_type == "user_validation"
            userId = data.user.id
            user = await User.findById(userId)
            if user
                logger.error("xsollaHook: ok user " + userId)
                res.status(204).send('')
            else
                logger.error("xsollaHook: bad user " + userId)
                res.status(400).json
                    error:
                        code: "INVALID_USER",
                        message: "Invalid user"
            return
        if data.notification_type == "refund"
            logger.error("xsollaHook: refund")
            res.status(204).send('')
            return
        if data.notification_type != "payment"
            logger.error("xsollaHook: unsupported notification type")
            res.status(400).json
                error:
                    code: "INVALID_PARAMETER",
                    message: "Unsupported notification type"
            return
        logger.error("xsollaHook: payment success")
        success = true
        orderId = data.transaction.external_id
        amount = data.purchase.checkout.amount
        await processPayment(orderId, success, amount, req.body, {isTest: true})
        res.status(204).send('')

    app.get '/api/unitpayNotify', wrap (req, res) ->
        fee = 0.1
        order = req.query.params.account
        logger.info("unitpayNotify #{order} #{req.host}")
        data = deepcopy(req.query.params)
        signature = data.signature
        method = req.query.method
        delete data.signature
        keys = (key for own key, value of data)
        keys.sort()
        str = ""
        for key in keys
            str += data[key] + "{up}"
        is_org = req.host.endsWith(".org")
        if UNITPAY_PUBLIC_KEY_ORG && is_org
            str += UNITPAY_SECRET_KEY_ORG
        else
            str += UNITPAY_SECRET_KEY
        str = method + "{up}" + str
        hash = sha256(str)
        if hash != signature
            logger.warn("unitpayNotify #{order}: wrong signature")
            res.status(403).send('Wrong signature')
            return

        if method != "pay"
            logger.info("unitpayNotify #{order}: method #{method}")
            res.json({result: {message: "OK"}})
            return

        success = true
        amount = data.orderSum
        await processPayment(order, success, {amount: amount / (1 + fee), taxAmount: amount}, req.query, {system: "unitpay"})
        res.json({result: {message: "OK"}})

    app.post '/api/paymentNotify', wrap (req, res) ->
        logger.info("paymentNotify #{req.body.OrderId}")
        data = deepcopy(req.body)
        token = data.Token
        delete data.Token
        data.Password = PASSWORD
        keys = (key for own key, value of data)
        keys.sort()
        str = ""
        for key in keys
            str += data[key]
        hash = sha256(str)
        if hash != token
            logger.warn("paymentNotify #{req.body.OrderId}: wrong token")
            res.status(403).send('Wrong token')
            return

        success = data.Status == "CONFIRMED"
        amount = Math.floor(req.body.Amount/100)
        await processPayment(req.body.OrderId, success, amount, req.body, {system: "tinkoff"})
        res.send('OK')

    app.get '/api/evocaStatus/:orderId', wrap (req, res) ->
        orderId = req.params.orderId
        if not orderId
            res.status(400).send('No orderId')
            return
        url = "https://ipay.arca.am/payment/rest/getOrderStatusExtended.do?userName=#{EVOCA_LOGIN}&password=#{EVOCA_PASSWORD}&orderId=#{orderId}"
        data = await download(url)
        result = JSON.parse(data)

        currency = "AMD"
        try
            amdToRub = await getCbRfRate(currency)
        catch e
            notify "Can't download cbrf rates", e
            throw e
        fee = 0.1
        desc = req.body.desc

        success = result.actionCode == 0
        await processPayment(result.orderNumber, result.actionCode == 0, {amount: result.amount * amdToRub / 100 / (1 + fee), taxAmount: result.amount * amdToRub / 100}, result, {system: "evoca"})
        res.json
            status: success

    app.get '/api/invoice/:orderId', wrap (req, res) ->
        if req.query.password != INVOICE_PASSWORD or not INVOICE_PASSWORD
            res.status(403).send('No permission')
            return
        orderId = req.params.orderId
        if not orderId
            res.status(400).send('No orderId')
            return
        payment = await Payment.findSuccessfulByOrderId(orderId)
        if not payment
            res.status(400).send('Wrong orderId')
            return
        currency = payment.payload?.currency
        if currency == "051"
            currency = "֏"
        else
            currency = " ?#{currency}? "
        email = ""
        address = ""
        for el in payment.payload?.merchantOrderParams || []
            if el.name == "email"
                email = el.value
            if el.name == "address"
                address = el.value
        res.json
            ip_data: INVOICE_IP_DATA
            orderId: orderId
            date: payment.time
            userName: payment.payload?.cardAuthInfo?.cardholderName
            userEmail: email
            userAddress: address
            amount: payment.payload?.amount / 100
            currency: currency
            signature: INVOICE_IP_SIGNATURE

    ###
    app.get '/api/makeFakeUsers', ensureLoggedIn, wrap (req, res) ->
        if not req.user?.admin
            res.status(403).send('No permissions')
            return
        for i in [0..14]
            console.log "User #{i}"
            newUser = new User(
                _id: "fake#{i}",
                name: "Fake Fake",
                userList: "zaoch",
                activated: true,
                lastActivated: new Date()
                registerDate: new Date()
            )
            await newUser.upsert()
            newRegisteredUser = new RegisteredUser({
                "fake#{i}",
                informaticsId: "fake#{i}",
                "fake#{i}",
                "fake#{i}",
                "fake",
                "",
                "",
                ""
                admin: false
            })
            RegisteredUser.register newRegisteredUser, req.body.password, (err) -> 

            problems = await Problem.find {}
            for problem in problems
                #console.log "Problem #{problem._id} level #{problem.level}"
                level = problem.level
                version = levelVersion(problem.level)
                #console.log "Problem #{problem._id} version #{version.major} #{version.minor}"
                solved = true
                if problem._id == "p2938"
                    solved = true
                else if level.slice(0,3) in ["sch", "nnoi", "reg", "roi"]
                    solved = false
                else if version.major > i
                    solved = false
                else if version.minor in ['В', 'Г']
                    p = 1 - Math.pow(0.5, i - version.major + 1)
                    if version.minor == 'Г'
                        p *= 2.0/3
                    rng = seedrandom("#{problem._id}")
                    #console.log "Problem #{problem._id} p=#{p}"
                    if rng() > p
                        solved = false
                #console.log "Solved= #{solved}"
                submit = new Submit
                    _id: "fake#{i}r#{problem._id}" ,
                    time: new Date(),
                    user: "fake#{i}",
                    userList: "zaoch",
                    problem: problem._id,
                    outcome: if solved then "AC" else "IG"
                    source: "fake"
                    sourceRaw: "fake"
                    language: "fake"
                    comments: []
                    results: []
                    force: false
                    testSystemData: []
                await submit.upsert()
            
            await User.updateUser(newUser._id)
        res.send('OK')
    ###