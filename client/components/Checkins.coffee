React = require('react')
moment = require('moment')

import Table from 'react-bootstrap/lib/Table'
import Button from 'react-bootstrap/lib/Button'
import Alert from 'react-bootstrap/lib/Alert'
import Panel from 'react-bootstrap/lib/Panel'

import FieldGroup from './FieldGroup'
import UserName from './UserName'

import callApi from '../lib/callApi'
import hasCapability, {CHECKINS} from '../lib/adminCapabilities'


#SESSION_TIMES = ["12:00", "13:00", "14:00", "15:00"]
#SESSION_TIMES = ["14:00", "15:30"]
SESSION_TIMES = ["14:00"]

class ResetForm extends React.Component
    constructor: (props) ->
        super(props)
        @state =
            date: moment(props.newDate).format('YYYY-MM-DD')
        @setField = @setField.bind(this)
        @reset = @reset.bind(this)

    setField: (field, value) ->
        newState = {@state...}
        newState[field] = value
        @setState(newState)

    reset: (event) ->
        event.preventDefault()
        data = await callApi "resetCheckins", {
            date: @state.date
        }
        @props.handleReload()

    render: () ->
            <form onSubmit={@reset}>
                <FieldGroup
                    id="date"
                    label="Сбросить на дату:"
                    type="text"
                    setField={@setField}
                    state={@state}/>
            </form>

export default class Checkins extends React.Component
    constructor: (props) ->
        super(props)
        @register = @register.bind this
        @state = 
            result: undefined

    register: (i, userId) ->
        () =>
            @setState
                result: undefined
            result = await callApi "checkin/#{userId}", {session: i}
            await @props.handleReload()
            @setState
                result: result

    canRegister: () ->
        @props.myUser && @props.myUser.rating > 0

    render: () ->
        wasme = [false, false]
        newDate = if @props.data.date then moment(@props.data.date).add(1, 'week').startOf('day').toDate() else new Date()
        <div>
            <h1>Регистрация на занятие {@props.data.date && moment(@props.data.date).format('DD.MM.YY')}</h1>

            <p>
            <b>Новичкам (кто не решил в курсе ни одной задачи) приходить на занятие нельзя</b> 
            {" "}(за исключением особо объявленных занятий для новичков, на которые не требуется регистрация).
            Надо начать сдавать задачи заочно — 
            если хотя бы одну решите, можете записываться и приходить уже не как новички.
            </p>

            <p>
            Можно приходить без записи, но компьютеры будут выдаваться в первую очередь тем,
            кто записался (даже если они опаздывают).</p>
            
            <p>
            Тем, кто со своими ноутбуками, записываться не надо.
            </p>

            <p>
            Не забудьте с собой паспорт (если паспорта еще нет, то свидетельство о рождении) — его могут спросить охранники на входе!                    
            </p>

            {
            if hasCapability(@props.me, CHECKINS)
                <ResetForm handleReload={@props.handleReload} newDate={newDate}/>
            }
            
            {
            if @state.result?.error
                <Alert bsStyle="danger">
                    Не удалось зарегистрироваться: {@state.result.error}
                </Alert>
            else if @state.result?.ok
                <Alert bsStyle="success">
                    Операция успешна
                </Alert>
            }
            {
            if @props.data?
                <div>
                    <Table condensed>
                        <thead><tr>
                        {
                        #for time, i in SESSION_TIMES
                        #    <th key={time}>
                        #        <h2>Занятие в {time}</h2>
                        #        <p>Всего мест: {@props.data.checkins[i].max}</p>
                        #    </th>
                        }
                        </tr></thead>
                        <tbody>
                        {
                        rows = Math.max(@props.data.checkins[0].max)
                        #rows = @props.data.checkins[0].max
                        for row in [0...rows]
                            <tr key={row}>
                                {
                                for _, i in SESSION_TIMES
                                    <td key={i}>
                                        {
                                        if @props.data.checkins[i].checkins[row]
                                            if @props.data.checkins[i].checkins[row].user == @props.myUser?._id   
                                                wasme[i] = true
                                            <div>
                                            <UserName user={@props.data.checkins[i].checkins[row].fullUser}/>
                                            {
                                            if hasCapability(@props.me, CHECKINS)
                                                <button type="button" 
                                                        className="close pull-left"
                                                        onClick={@register(null, @props.data.checkins[i].checkins[row].user)}>
                                                    <span>&times;&nbsp;</span>
                                                </button>
                                            }
                                            </div>
                                        else if row < @props.data.checkins[i].max
                                            <span>(свободно)</span>
                                        }                                            
                                    </td>
                                }
                            </tr>
                        }
                        {
                        if @canRegister()
                            <tr>
                                {
                                for _, i in SESSION_TIMES
                                    <td key={i}>
                                        {
                                        if @props.myUser?._id and !wasme[i] and @props.data.checkins[i].checkins.length < @props.data.checkins[i].max
                                            <Button bsStyle="primary" onClick={@register(i, @props.myUser?._id)}>
                                                Зарегистрироваться
                                            </Button>
                                        }                                            
                                    </td>
                                }
                            </tr>
                        }
                        </tbody>
                    </Table>
                    {
                    if wasme[0] #or wasme[1]
                        <Button bsStyle="info" onClick={@register(null, @props.myUser?._id)}>Отменить регистрацию</Button>
                    else if !@canRegister()
                        <Alert bsStyle="danger">
                            Чтобы зарегистрироваться на занятие, вам надо решить минимум одну задачу. 
                        </Alert>
                    }
                </div>
            }
        </div>
