React = require('react')
import { connect } from 'react-redux'
import { withRouter } from 'react-router'
import { Link } from 'react-router-dom'

import Alert from 'react-bootstrap/lib/Alert'
import Button from 'react-bootstrap/lib/Button'
import ControlLabel from 'react-bootstrap/lib/ControlLabel'
import Form from 'react-bootstrap/lib/Form'
import FormControl from 'react-bootstrap/lib/FormControl'
import FormGroup from 'react-bootstrap/lib/FormGroup'
import Grid from 'react-bootstrap/lib/Grid'
import HelpBlock from 'react-bootstrap/lib/HelpBlock'
import Modal from 'react-bootstrap/lib/Modal'
import Radio from 'react-bootstrap/lib/Radio'

import {LangRaw} from '../lang/lang'

import callApi from '../lib/callApi'
import withLang from '../lib/withLang'
import {getCurrentYearStart} from '../lib/graduateYearToClass'

import * as actions from '../redux/actions'

import FieldGroup from './FieldGroup'
import Loader from './Loader'

class Register extends React.Component
    constructor: (props) ->
        super(props)
        @state =
            username: ""
            password: ""
            password2: ""
            informaticsUsername: ""
            informaticsPassword: ""
            promo: ""
            contact: ""
            whereFrom: ""
            aboutme: ""
            cfLogin: ""
            hasInformatics: undefined
        @setField = @setField.bind(this)
        @updateInformatics = @updateInformatics.bind(this)
        @tryRegister = @tryRegister.bind(this)
        @closeModal = @closeModal.bind(this)

    setField: (field, value) ->
        console.log field, value
        newState = {@state...}
        newState[field] = value
        @setState(newState)

    updateInformatics: () ->
        if @state.informaticsUsername and @state.informaticsPassword
            newState = {
                @state...
                informaticsLoading: true
            }
            @setState(newState)
            try
                data = await callApi "informatics/userData", {
                    username: @state.informaticsUsername,
                    password: @state.informaticsPassword
                }
                if not ("name" of data)
                    throw "Can't find name"
            catch
                data =
                    error: true
            newState = {
                @state...
                informaticsLoading: false
                informaticsName: data.name
                informaticsClass: data.class
                informaticsSchool: data.school
                informaticsCity: data.city
                informaticsError: data.error
                informaticsId: data.id
            }
            @setState(newState)

    tryRegister: (event) ->
        event.preventDefault()
        newState = {
            @state...
            registered:
                loading: true
        }
        @setState(newState)
        try
            data = await callApi "register", {
                username: @state.username
                password: @state.password
                informaticsUsername: @state.hasInformatics && @state.informaticsUsername
                informaticsPassword: @state.hasInformatics && @state.informaticsPassword
                informaticsName: @state.informaticsName
                informaticsClass: @state.informaticsClass
                informaticsSchool: @state.informaticsSchool
                informaticsCity: @state.informaticsCity
                promo: @state.promo
                whereFrom: @state.whereFrom
                contact: @state.contact
                aboutme: @state.aboutme
                cfLogin: @state.cfLogin
            }
            if data.registered.success
                if window.yaCounter45895896
                    window.yaCounter45895896.hit?("/registration_done")
                await callApi "login", {
                    username: @state.username,
                    password: @state.password
                }
                @props.reloadMyData()
        catch
            data =
                registered:
                    error: true
                    message: "Неопознанная ошибка"
        newState = {
            @state...
            registered: data.registered
        }
        @setState(newState)

    closeModal: () ->
        if @state.registered.error
            newState = {@state..., registered: null}
            @setState(newState)
        else
            @props.history.push("/")

    render: () ->
        Lang = (id) -> LangRaw(id, @props.lang)
        validationState = null
        if (@state.informaticsName && @state.hasInformatics) || (not @state.hasInformatics && @state.informaticsName)
            validationState = 'success'
        else if @state.informaticsError
            validationState = 'error'
        else if @state.informaticsLoading
            validationState = 'warning'

        passwordValidationState = null
        passwordError = null
        if @state.password and @state.password == @state.password2
            if @state.password.startsWith(' ') or @state.password.endsWith(' ')
                passwordValidationState = 'error'
                passwordError = 'Пароль не может начинаться с пробела или заканчиваться на него'
            passwordValidationState = 'success'
        else if @state.password and @state.password2
            passwordValidationState = 'error'
            passwordError = 'Пароли не совпадают'

        loginValidationState = 'success'
        loginError = null
        if @state.username.length == 0
            loginValidationState = 'error'
        else if @state.username.startsWith(' ') or @state.username.endsWith(' ')
            loginValidationState = 'error'
            loginError = 'Логин не может начинаться с пробела или заканчиваться на него'

        canSubmit = (validationState == 'success' and passwordValidationState == 'success' and loginValidationState == 'success')
        hasInformatics = @state.hasInformatics
        yearStart = getCurrentYearStart()

        <Grid fluid>
            <h1>Регистрация</h1>

            <form onSubmit={@tryRegister}>
                <FieldGroup
                    id="username"
                    label="Логин"
                    type="text"
                    setField={@setField}
                    state={@state}
                    validationState={loginValidationState}
                    error={loginError}/>
                <FieldGroup
                    id="password"
                    label="Пароль"
                    type="password"
                    setField={@setField}
                    state={@state}
                    validationState={passwordValidationState}
                    error={passwordError}/>
                <FieldGroup
                    id="password2"
                    label="Подтвердите пароль"
                    type="password"
                    setField={@setField}
                    state={@state}
                    validationState={passwordValidationState}/>

                <h3>Ваш аккаунт на informatics.msk.ru</h3>
                <p>Вам надо иметь аккаунт на сайте <a href="https://informatics.msk.ru" target="_blank">informatics.msk.ru</a>;
                ваши программы будут реально проверяться именно там. </p>
                
                <p>Аккаунт вам будет создан автоматически, или, если хотите, вы можете <a href="https://informatics.msk.ru/login/signup.php" target="_blank">зарегистрироваться самостоятельно</a>,
                и указать данные вашего аккаунта ниже.</p>

                <FieldGroup
                    id="hasInformatics"
                    label=""
                    type="radio"
                    setField={@setField}
                    state={@state}
                    onBlur={@updateInformatics}
                    validationState={validationState}>
                        <Radio name="hasInformatics" onChange={(e) => @setField("hasInformatics", false)} className="lead">У меня нет аккаунта на informatics</Radio>
                        <Radio name="hasInformatics" onChange={(e) => @setField("hasInformatics", true)} className="lead">У меня есть аккаунт на informatics</Radio>
                </FieldGroup>

                {hasInformatics == true &&
                    <>
                        <p>Ниже вы должны будете указать логин и пароль от informatics. Пароль будет храниться на algoprog.ru.
                        Он нужен, чтобы отправлять решения задач от вашего имени.
                        Если вы используете этот же пароль на других сайтах, не вводите его ниже
                        — сначала смените пароль на informatics, и только потом продолжайте.
                        Если вы не хотите, чтобы я имел доступ к вашему аккаунту на informatics,
                        просто зарегистрируйте новый аккаунт там и укажите ниже именно его.</p>

                        <p>Укажите в аккаунте на informatics свои настоящие данные.
                        Если вы уже закончили школу, то не заполняйте поле "класс".</p>

                        <FieldGroup
                            id="informaticsUsername"
                            label="Ваш логин на informatics"
                            type="text"
                            setField={@setField}
                            state={@state}
                            onBlur={@updateInformatics}
                            validationState={validationState}/>
                        <FieldGroup
                            id="informaticsPassword"
                            label="Ваш пароль на informatics"
                            type="password"
                            setField={@setField}
                            state={@state}
                            onBlur={@updateInformatics}
                            validationState={validationState}/>
                    </>
                }
                {hasInformatics == false && 
                    <Alert bsStyle="danger">
                        Автоматическая регистрация аккаунта на информатиксе работает в экспериментальном режиме.
                        В случае каких-либо проблем пишите мне.
                    </Alert>
                }
                {hasInformatics? &&
                    <>
                    <h2>Личная информация</h2>
                    {hasInformatics == true && <>
                        <p><span>Она выгружается из вашего аккаунта на informatics. Если данные ниже неверны,
                        исправьте данные </span>
                        {
                        if @state.informaticsId
                            <a href={"https://informatics.msk.ru/user/edit.php?id=#{@state.informaticsId}&course=1"} target="_blank">в вашем профиле там.</a>
                        else
                            <span>в вашем профиле там.</span>
                        }
                        </p>
                        {
                        @state.informaticsLoading && <div>
                            <p>Informatics бывает подтормаживает, поэтому загрузка данных может занять некоторое время.</p>
                            <Loader />
                        </div>}
                        {
                        @state.informaticsError &&
                        <FormGroup>
                            <FormControl.Static>
                            Не удалось получить данные с informatics. Проверьте логин и пароль выше.
                            </FormControl.Static>
                        </FormGroup>
                        }
                        {@state.hasInformatics && !@state.informaticsLoading &&
                        <FormGroup>
                            <Button onClick={@updateInformatics}>
                                Обновить информацию
                            </Button>
                        </FormGroup>
                        }
                        </>
                    }
                    {(hasInformatics == false or (@state.informaticsName and not @state.informaticsLoading))&&
                    <div>
                        <FieldGroup
                            id="informaticsName"
                            label="Имя, фамилия"
                            type="text"
                            setField={@setField}
                            state={@state}
                            disabled={hasInformatics}/>
                        <FieldGroup
                            id="informaticsClass"
                            label={"Класс в #{yearStart}-#{yearStart+1} учебном году"}
                            type="text"
                            setField={@setField}
                            state={@state}
                            disabled={hasInformatics}/>
                        <FieldGroup
                            id="informaticsSchool"
                            label="Школа"
                            type="text"
                            setField={@setField}
                            state={@state}
                            disabled={hasInformatics}/>
                        <FieldGroup
                            id="informaticsCity"
                            label="Город"
                            type="text"
                            setField={@setField}
                            state={@state}
                            disabled={hasInformatics}/>
                    </div>
                    }

                    <h2>О себе (все поля ниже не обязательны)</h2>
                    <p>Напишите вкратце про себя. Как минимум — есть ли у вас опыт в программировании и какой;
                    а также участвовали ли вы в олимпиадах по программированию и по математике. Если вы уже занимались в этом курсе,
                    можете не писать ничего.</p>

                    <FormGroup controlId="aboutme">
                        <FieldGroup
                            id="aboutme"
                            label=""
                            componentClass="textarea"
                            setField={@setField}
                            state={@state}/>
                    </FormGroup>

                    <p>Откуда вы узнали про курс?</p>

                    <FormGroup controlId="whereFrom">
                        <FieldGroup
                            id="whereFrom"
                            label=""
                            componentClass="input"
                            setField={@setField}
                            state={@state}/>
                    </FormGroup>

                    <p>Укажите какие-нибудь контактные данные (email, профиль во вКонтакте и т.п., не обязательно)</p>

                    <FormGroup controlId="contact">
                        <FieldGroup
                            id="contact"
                            label=""
                            componentClass="input"
                            setField={@setField}
                            state={@state}/>
                    </FormGroup>

                    <p>Укажите свой логин на codeforces, если он у вас есть. Если вы там не зарегистрированы — не страшно,
                    просто не заполняйте поле ниже.</p>
                    <FieldGroup
                        id="cfLogin"
                        label=""
                        type="text"
                        setField={@setField}
                        state={@state}/>

                    <p>Промокод</p>

                    <FormGroup controlId="promo">
                        <FieldGroup
                            id="promo"
                            label=""
                            componentClass="input"
                            setField={@setField}
                            state={@state}/>
                    </FormGroup>

                    <Button type="submit" bsStyle="primary" disabled={!canSubmit}>
                        Зарегистрироваться
                    </Button>
                    </>
                }
            </form>
            {
            @state.registered &&
            <div className="static-modal">
                <Modal.Dialog>
                    <Modal.Header>
                        <Modal.Title>Регистрация</Modal.Title>
                    </Modal.Header>

                    <Modal.Body>
                        {@state.registered.loading && 
                            <>
                                <p>Бывает, что informatics работает медленно, регистрация может занимать до 1-2 минут. Не обновляйте страницу.</p>
                                <Loader />
                            </>
                        }
                        {@state.registered.error && "Ошибка: " + @state.registered.message}
                        {@state.registered.success &&
                            <div>
                                <p>Регистрация успешна!</p>
                                <p><b>Если вы еще не занимались в этом курсе, обязательно напишите мне о том, что вы зарегистрировались,
                                чтобы я активировал вашу учетную запись. Мои контакты — на страничке
                                {" "}<Link to="/material/about">О курсе</Link>.</b></p>
                            </div>}
                    </Modal.Body>

                    <Modal.Footer>
                        {not @state.registered.loading && <Button bsStyle="primary" onClick={@closeModal}>OK</Button>}
                    </Modal.Footer>

                </Modal.Dialog>
            </div>
            }
        </Grid>

mapStateToProps = () ->
    {}

mapDispatchToProps = (dispatch) ->
    return
        reloadMyData: () -> dispatch(actions.invalidateAllData())

export default withLang(withRouter(connect(mapStateToProps, mapDispatchToProps)(Register)))
