React = require('react')

import withLang from '../lib/withLang'

_LANG = 
    news:
        "ru": "Новости"
        "en": "News"
    recent_comments:
        "ru": "Последние комментарии"
        "en": "Recent comments"
    all_comments:
        "ru": "Все комментарии"
        "en": "All comments"
    material_suffix:
        "ru": ""
        "en": "!en"
    Petr_Kalinin:
        "ru": "Петр Калинин",
        "en": "Petr Kalinin"
    about_license:
        "ru": "О лицензии на материалы сайта",
        "en": "About license for site materials"
    blog:
        "ru": "Блог"
        "en": "Blog (in Russian)"
    paid_till:
        "ru": "Занятия оплачены до"
        "en": "Paid till"
    was_paid_till:
        "ru": "Занятия были оплачены до "
        "en": "Was paid till"
    extend_payment:
        "ru": "Продлить"
        "en": "Extend"
    pay:
        "ru": "Оплатить занятия"
        "en": "Pay for the course"
    

export LangRaw = (id, lang) ->
    res = _LANG[id]?[lang]
    if not (res?) 
        throw "Unknown lang #{id} #{lang}"
    res

LangEl = withLang (props) ->
    LangRaw(props.id, props.lang)

export default Lang = (id) ->
    <LangEl id={id}/>