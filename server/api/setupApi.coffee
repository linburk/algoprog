connectEnsureLogin = require('connect-ensure-login')

import User from '../models/user'
import Result from '../models/result'
import Problem from '../models/problem'
import Table from '../models/table'
import RegisteredUser from '../models/registeredUser'

import dashboard from './dashboard'
import table from './table'

export default setupApi = (app) ->
    app.post '/api/register', (req, res, next) ->
        user = new RegisteredUser
            username: req.body.username
            admin: false
        RegisteredUser.register user, req.body.password, (err) ->
            if (err)
                return next err
            res.redirect '/'
            
    app.get('/api/me', connectEnsureLogin.ensureLoggedIn(), (req, res) ->
        res.json req.user
    )

    app.post '/api/user/:id/set', connectEnsureLogin.ensureLoggedIn(), (req, res) ->
        if not req.user?.admin
            res.status(403).send('No permissions')
        cfLogin = req.body.cf.login
        if cfLogin == ""
            cfLogin = undefined
        User.findOne({_id: req.params.id}, (err, record) ->
            await record.setBaseLevel req.body.level.base
            await record.setCfLogin cfLogin
            res.send('OK')
        )
    
    app.get '/api/user/:id', (req, res) ->
        User.findOne({_id: req.params.id}, (err, record) ->
            res.json(record)
        )
        
    app.get '/api/dashboard', (req, res) ->
        res.json(await dashboard())

    app.get '/api/table/:userList/:table', (req, res) ->
        res.json(await table(req.params.userList, req.params.table))

    app.get '/api/users/:userList', (req, res) ->
        res.json(await User.findByList(req.params.userList))
